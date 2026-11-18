"""Small ingest + snapshot server for water-level nodes (Python standard library only).

POST /ingest    signed reading from a node (HMAC-SHA256 of the raw body, per-device key)
GET  /snapshot  latest state of every station, for the app
GET  /health    liveness
GET  /flood-recurrence?lat=&lng=  GISTDA flood-history record for a point (needs GISTDA_API_KEY)

Rules this server enforces (the device is not trusted):
  * bad signature -> 401, counter not higher than the last one -> 409 (replay)
  * the server recomputes the water level from the raw distance and re-checks
    range, rate of change and stuck values
  * a station that is stale, offline, faulty or doubtful is reported as band
    "unknown". It is never reported as "safe".
  * a reading is an OBSERVATION from a community sensor. This server never
    raises an area alert and never says "evacuate".

No TLS here: keep it on a LAN, or put a TLS reverse proxy in front of it.
"""
import argparse
import hashlib
import hmac
import json
import math
import sqlite3
import threading
import time
import urllib.parse
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import gistda

LABEL = "Community sensor, not an official gauge"
MIN_VALID_CM, MAX_VALID_CM = 25.0, 450.0
MAX_RATE_CM_S = 2.0          # faster than this between neighbours = implausible...
MAX_STEP_CM = 30.0           # ...unless the step is within what the device itself accepts
STUCK_N, STUCK_EPS_CM = 90, 0.1
STALE_S, OFFLINE_S = 120, 600
RATE_WINDOW_S, RATE_MIN_SPAN_S = 600, 120
MAX_AGE_MS = 24 * 3600 * 1000
KEEP_S = 7 * 24 * 3600       # readings older than this are deleted; nothing reads further back
MAX_BODY = 2048
FAULTS = {"ok", "noecho", "range", "jump", "stuck"}


def band_for(water, rise, st):
    if water >= st.get("dangerCm", 185):
        band = "danger"
    elif water >= st.get("warningCm", 160):
        band = "warning"
    elif water >= st.get("watchCm", 120):
        band = "watch"
    else:
        band = "safe"
    if rise is not None and rise >= st.get("riseWatchCmH", 20) and band == "safe":
        band = "watch"
    return band


def _number(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def validate(m, device):
    if not isinstance(m, dict) or m.get("id") != device:
        return "bad id"
    seq = m.get("seq")
    if not isinstance(seq, int) or isinstance(seq, bool) or not 0 <= seq < 2**32:
        return "bad seq"
    age = m.get("ageMs")
    if not isinstance(age, int) or isinstance(age, bool) or not 0 <= age <= MAX_AGE_MS:
        return "bad ageMs"
    if m.get("fault") not in FAULTS:
        return "bad fault"
    d = m.get("dist")
    if d is not None and not (_number(d) and 0 <= d <= 2000):
        return "bad dist"
    return None


def iso(t):
    return datetime.fromtimestamp(t, timezone.utc).isoformat()


def check_config(stations):
    """A level the sensor cannot physically read would make the top band unreachable."""
    for sid, st in stations.items():
        top = st["sensorHeightCm"] - MIN_VALID_CM
        if st.get("dangerCm", 185) > top:
            raise ValueError(
                f"{sid}: dangerCm {st.get('dangerCm', 185)} is above the highest readable "
                f"level ({top} = sensorHeightCm - {MIN_VALID_CM})"
            )


class Store:
    def __init__(self, stations, db_path=":memory:", clock=time.time):
        check_config(stations)
        self.stations = stations
        self.clock = clock
        self.lock = threading.Lock()
        self.db = sqlite3.connect(db_path, check_same_thread=False)
        self.db.executescript(
            """
            CREATE TABLE IF NOT EXISTS state(
              station TEXT PRIMARY KEY, last_seq INTEGER NOT NULL,
              last_seen REAL NOT NULL, rssi INTEGER);
            CREATE TABLE IF NOT EXISTS readings(
              station TEXT NOT NULL, t REAL NOT NULL, seq INTEGER NOT NULL,
              dist REAL, water REAL, status TEXT NOT NULL);
            CREATE INDEX IF NOT EXISTS readings_st ON readings(station, t);
            """
        )

    # ------------------------------------------------------------ ingest
    def ingest(self, device, signature, raw):
        st = self.stations.get(device)
        if st is None or not signature:
            return 401, {"error": "unauthorized"}
        good = hmac.new(st["key"].encode(), raw, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(good.encode(), signature.strip().lower().encode("utf-8", "replace")):
            return 401, {"error": "unauthorized"}
        try:
            m = json.loads(raw)
        except ValueError:
            return 400, {"error": "bad json"}
        err = validate(m, device)
        if err:
            return 400, {"error": err}

        now = self.clock()
        with self.lock:
            row = self.db.execute(
                "SELECT last_seq FROM state WHERE station=?", (device,)
            ).fetchone()
            last = row[0] if row else -1
            if m["seq"] <= last:
                return 409, {"error": "replay", "lastSeq": last}
            self.db.execute(
                "INSERT INTO state VALUES(?,?,?,?) ON CONFLICT(station) DO UPDATE SET "
                "last_seq=excluded.last_seq, last_seen=excluded.last_seen, rssi=excluded.rssi",
                (device, m["seq"], now, m.get("rssi") if isinstance(m.get("rssi"), int) else None),
            )
            t = now - m["ageMs"] / 1000.0
            status, water = self._judge(st, device, t, m)
            self.db.execute(
                "INSERT INTO readings VALUES(?,?,?,?,?,?)",
                (device, t, m["seq"], m["dist"], water, status),
            )
            self.db.execute(
                "DELETE FROM readings WHERE station=? AND t<?", (device, now - KEEP_S)
            )
            self.db.commit()
        return 200, {"ok": True, "status": status}

    def _judge(self, st, device, t, m):
        if m["fault"] != "ok":
            return m["fault"], None
        d = m["dist"]
        if d is None:
            return "noecho", None
        if not MIN_VALID_CM <= d <= MAX_VALID_CM:
            return "range", None
        water = st["sensorHeightCm"] - d
        nb = self.db.execute(
            "SELECT t, water FROM readings WHERE station=? AND status='ok' "
            "AND ABS(t-?)<=600 ORDER BY ABS(t-?) LIMIT 1",
            (device, t, t),
        ).fetchone()
        if nb:
            dt = max(abs(t - nb[0]), 1.0)
            if abs(water - nb[1]) > max(MAX_STEP_CM, MAX_RATE_CM_S * dt):
                return "jump", water
        return "ok", water

    # ---------------------------------------------------------- snapshot
    def snapshot(self):
        now = self.clock()
        with self.lock:
            stations = [self._station(now, sid, st) for sid, st in self.stations.items()]
        return {"generatedAt": iso(now), "label": LABEL, "stations": stations}

    def _rise(self, sid, t_new, w_new):
        row = self.db.execute(
            "SELECT t, water FROM readings WHERE station=? AND status='ok' "
            "AND t>=? AND t<=? ORDER BY t ASC LIMIT 1",
            (sid, t_new - RATE_WINDOW_S, t_new),
        ).fetchone()
        if not row or t_new - row[0] < RATE_MIN_SPAN_S:
            return None
        return (w_new - row[1]) / ((t_new - row[0]) / 3600.0)

    def _station(self, now, sid, st):
        out = {
            "id": sid, "name": st.get("name", sid), "lat": st.get("lat"), "lng": st.get("lng"),
            "label": LABEL, "status": "offline", "band": "unknown", "waterCm": None,
            "riseCmH": None, "lastSeenS": None, "readingTime": None, "lastGood": None,
        }
        s = self.db.execute(
            "SELECT last_seen, rssi FROM state WHERE station=?", (sid,)
        ).fetchone()
        if not s:
            return out
        age = now - s[0]
        out["lastSeenS"] = round(age)
        out["rssi"] = s[1]
        last = self.db.execute(
            "SELECT t, status FROM readings WHERE station=? ORDER BY t DESC LIMIT 1", (sid,)
        ).fetchone()
        good = self.db.execute(
            "SELECT t, water FROM readings WHERE station=? AND status='ok' "
            "ORDER BY t DESC LIMIT 1", (sid,)
        ).fetchone()
        rise = band = None
        if good:
            rise = self._rise(sid, good[0], good[1])
            band = band_for(good[1], rise, st)
            out["lastGood"] = {
                "waterCm": round(good[1], 1), "readingTime": iso(good[0]),
                "riseCmH": None if rise is None else round(rise, 1), "band": band,
            }

        if age > OFFLINE_S:
            status = "offline"
        elif age > STALE_S:
            status = "stale"
        elif last is None:
            status = "offline"
        elif last[1] != "ok":
            status = last[1]
        elif self._is_stuck(sid):
            status = "stuck"
        else:
            status = "ok"
        out["status"] = status
        if status == "ok" and good:
            out["band"] = band
            out["waterCm"] = round(good[1], 1)
            out["riseCmH"] = out["lastGood"]["riseCmH"]
            out["readingTime"] = out["lastGood"]["readingTime"]
        return out

    def _is_stuck(self, sid):
        rows = self.db.execute(
            "SELECT dist FROM readings WHERE station=? AND status='ok' "
            "ORDER BY t DESC LIMIT ?", (sid, STUCK_N),
        ).fetchall()
        if len(rows) < STUCK_N:
            return False
        ds = [r[0] for r in rows]
        return max(ds) - min(ds) <= STUCK_EPS_CM


# ------------------------------------------------------------------ HTTP
def make_handler(store):
    class Handler(BaseHTTPRequestHandler):
        timeout = 10  # a client that stalls mid-request is dropped, not held forever

        def _send(self, code, obj):
            body = json.dumps(obj).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            url = urllib.parse.urlsplit(self.path)
            if url.path == "/snapshot":
                self._send(200, store.snapshot())
            elif url.path == "/flood-recurrence":
                self._send(*flood_history(urllib.parse.parse_qs(url.query)))
            elif self.path == "/health":
                self._send(200, {"ok": True})
            else:
                self._send(404, {"error": "not found"})

        def do_POST(self):
            if self.path != "/ingest":
                return self._send(404, {"error": "not found"})
            try:
                n = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                return self._send(400, {"error": "bad length"})
            if n <= 0 or n > MAX_BODY:
                return self._send(413, {"error": "bad size"})
            raw = self.rfile.read(n)
            code, obj = store.ingest(
                self.headers.get("X-Device", ""), self.headers.get("X-Signature", ""), raw
            )
            self._send(code, obj)

    return Handler


def flood_history(query, lookup=gistda.flood_recurrence):
    """(status, body) for /flood-recurrence. found=false means GISTDA has no record: not "safe"."""
    try:
        lat, lng = float(query["lat"][0]), float(query["lng"][0])
        if not (math.isfinite(lat) and math.isfinite(lng) and -90 <= lat <= 90 and -180 <= lng <= 180):
            raise ValueError
    except (KeyError, IndexError, ValueError):
        return 400, {"error": "lat and lng required"}
    try:
        rows = lookup(lat, lng)
    except gistda.GistdaError:
        return 503, {"error": "flood history unavailable"}
    if not rows:
        return 200, {"found": False, "source": "GISTDA"}
    try:
        r = rows[0]
        years = [{"year": int(d["year"]), "freq": int(d["freq"])} for d in r.get("detail", [])]
        body = {
            "found": True,
            "source": "GISTDA",
            "subdistrict": r.get("subdistrict_name"),
            "district": r.get("district_name"),
            "province": r.get("province_name"),
            "years": sorted(years, key=lambda y: y["year"]),
        }
    except (KeyError, ValueError, TypeError, IndexError, AttributeError):
        return 503, {"error": "flood history unavailable"}
    return 200, body


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--config", default="stations.json")
    ap.add_argument("--db", default="sensors.db")
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=8080)
    a = ap.parse_args()
    with open(a.config, encoding="utf-8") as f:
        stations = json.load(f)
    store = Store(stations, a.db)
    print(f"Listening on http://{a.host}:{a.port}  (no TLS: LAN only)")
    ThreadingHTTPServer((a.host, a.port), make_handler(store)).serve_forever()


if __name__ == "__main__":
    main()
