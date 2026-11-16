"""Fake water-level node: posts signed readings to sensor_ingest.py.

Mimics the firmware: newest reading first, older ones backdated with ageMs.

  python simulate.py --key KEY --scenario flood
Scenarios: flood, calm, stuck, dropout, badsig, replay
"""
import argparse
import hashlib
import hmac
import json
import urllib.error
import urllib.request


def sign(key, raw):
    return hmac.new(key.encode(), raw, hashlib.sha256).hexdigest()


def body(station, seq, age_ms, dist, fault="ok", rssi=-60):
    return json.dumps(
        {"id": station, "seq": seq, "ageMs": age_ms, "dist": dist, "fault": fault, "rssi": rssi}
    ).encode()


def post(url, station, key, raw, signature=None):
    req = urllib.request.Request(
        url + "/ingest", data=raw, method="POST",
        headers={"Content-Type": "application/json", "X-Device": station,
                 "X-Signature": signature if signature is not None else sign(key, raw)},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code


def series(scenario, height):
    """(age_ms, dist, fault), newest first."""
    step = 30_000
    if scenario == "flood":      # 60 -> 190 cm over 60 min
        n = 120
        # i = 0 is the newest (190 cm); older readings are lower and backdated.
        return [(i * step, height - (190 - i * 130 / (n - 1)), "ok") for i in range(n)]
    if scenario == "calm":
        return [(i * step, height - 60 - (i % 3) * 0.2, "ok") for i in range(20)]
    if scenario == "stuck":
        return [(i * step, height - 100.0, "ok") for i in range(100)]
    if scenario == "dropout":
        return [(0, None, "noecho")] + [((i + 1) * step, height - 100, "ok") for i in range(10)]
    return [(0, height - 100, "ok")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://127.0.0.1:8080")
    ap.add_argument("--station", default="station-1")
    ap.add_argument("--key", required=True)
    ap.add_argument("--height", type=float, default=300)
    ap.add_argument("--scenario", default="flood")
    ap.add_argument("--seq", type=int, default=1000)
    a = ap.parse_args()

    if a.scenario == "badsig":
        raw = body(a.station, a.seq, 0, a.height - 100)
        print("bad signature ->", post(a.url, a.station, a.key, raw, signature="0" * 64))
        return
    if a.scenario == "replay":
        raw = body(a.station, a.seq, 0, a.height - 100)
        print("first  ->", post(a.url, a.station, a.key, raw))
        print("replay ->", post(a.url, a.station, a.key, raw))
        return
    seq = a.seq
    codes = {}
    for age, dist, fault in series(a.scenario, a.height):
        seq += 1
        c = post(a.url, a.station, a.key, body(a.station, seq, age, dist, fault))
        codes[c] = codes.get(c, 0) + 1
    print("sent:", codes, "-> GET", a.url + "/snapshot")


if __name__ == "__main__":
    main()
