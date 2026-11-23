"""Run:  python -m unittest test_ingest   (from the backend folder)"""
import json
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

import sensor_ingest as si
from simulate import body, post, series, sign

KEY = "k" * 64
CFG = {"station-1": {"key": KEY, "sensorHeightCm": 300, "name": "T", "lat": 1.0, "lng": 2.0}}
H = 300.0


class Clock:
    def __init__(self):
        self.t = 1_000_000.0

    def __call__(self):
        return self.t


class Base(unittest.TestCase):
    def setUp(self):
        self.clock = Clock()
        self.store = si.Store(CFG, clock=self.clock)
        self.seq = 0

    def send(self, age_ms, dist, fault="ok", sig=None, seq=None):
        if seq is None:
            self.seq += 1
            seq = self.seq
        raw = body("station-1", seq, age_ms, dist, fault)
        return self.store.ingest("station-1", sig or sign(KEY, raw), raw)

    def st(self):
        return self.store.snapshot()["stations"][0]


class AuthTests(Base):
    def test_bad_signature(self):
        self.assertEqual(self.send(0, 100, sig="0" * 64)[0], 401)

    def test_non_ascii_signature_is_401_not_a_crash(self):
        self.assertEqual(self.send(0, 100, sig="é" * 64)[0], 401)

    def test_unknown_device(self):
        raw = body("nope", 1, 0, 100)
        self.assertEqual(self.store.ingest("nope", sign(KEY, raw), raw)[0], 401)

    def test_replay_rejected_with_last_seq(self):
        self.assertEqual(self.send(0, 100, seq=10)[0], 200)
        code, obj = self.send(0, 100, seq=10)
        self.assertEqual((code, obj["lastSeq"]), (409, 10))
        self.assertEqual(self.send(0, 100, seq=9)[0], 409)

    def test_malformed(self):
        raw = json.dumps({"id": "station-1", "seq": "x", "ageMs": 0, "dist": 1, "fault": "ok"}).encode()
        self.assertEqual(self.store.ingest("station-1", sign(KEY, raw), raw)[0], 400)
        self.assertEqual(self.send(si.MAX_AGE_MS + 1, 100)[0], 400)
        self.assertEqual(self.send(0, 100, fault="weird")[0], 400)


class PruneTests(Base):
    def test_old_readings_are_deleted_but_state_stays(self):
        self.assertEqual(self.send(0, 100)[0], 200)
        self.clock.t += si.KEEP_S + 10
        self.assertEqual(self.send(0, 100)[0], 200)
        n = self.store.db.execute("SELECT COUNT(*) FROM readings").fetchone()[0]
        self.assertEqual(n, 1)
        self.assertEqual(self.send(0, 100, seq=1)[0], 409)  # replay guard survives pruning


class StateTests(Base):
    def test_calm_is_safe(self):
        for age, dist, f in series("calm", H):
            self.send(age, dist, f)
        s = self.st()
        self.assertEqual((s["status"], s["band"]), ("ok", "safe"))

    def test_flood_backlog_newest_first_reaches_danger(self):
        for age, dist, f in series("flood", H):
            self.assertEqual(self.send(age, dist, f)[0], 200)
        s = self.st()
        self.assertEqual((s["status"], s["band"]), ("ok", "danger"))
        self.assertGreater(s["riseCmH"], 20)

    def test_fast_rise_is_at_least_watch_even_when_low(self):
        # 40 cm -> 70 cm in 10 min = 180 cm/h, still below the watch level.
        for i in range(21):
            self.send((20 - i) * 30_000, H - (40 + i * 1.5))
        s = self.st()
        self.assertEqual(s["band"], "watch")

    def test_no_echo_is_unknown_never_safe(self):
        for age, dist, f in series("dropout", H):
            self.send(age, dist, f)
        s = self.st()
        self.assertEqual((s["status"], s["band"], s["waterCm"]), ("noecho", "unknown", None))
        self.assertEqual(s["lastGood"]["band"], "safe")  # kept for information only

    def test_out_of_range_distance(self):
        self.send(0, 10.0)
        self.assertEqual(self.st()["status"], "range")

    def test_server_rejects_implausible_jump(self):
        for i in range(10):
            self.send((10 - i) * 30_000, H - 100)
        self.send(0, H - 190)  # +90 cm in 30 s, 3 cm/s
        s = self.st()
        self.assertEqual((s["status"], s["band"]), ("jump", "unknown"))

    def test_choppy_water_at_danger_stays_ok(self):
        # 5 s readings at ~190 cm with +-12 cm chop must not be thrown away as jumps.
        import itertools
        chop = itertools.cycle([0, 12, -10, 8, -12, 5])
        for i in range(40):
            self.send((39 - i) * 5_000, H - (190 + next(chop)))
        s = self.st()
        self.assertEqual((s["status"], s["band"]), ("ok", "danger"))

    def test_device_fault_flag_is_respected(self):
        self.send(0, H - 100, fault="stuck")
        self.assertEqual((self.st()["status"], self.st()["band"]), ("stuck", "unknown"))

    def test_server_detects_stuck_values(self):
        for age, dist, f in series("stuck", H):
            self.send(age, dist, f)
        s = self.st()
        self.assertEqual((s["status"], s["band"]), ("stuck", "unknown"))

    def test_stale_then_offline_never_safe(self):
        for age, dist, f in series("calm", H):
            self.send(age, dist, f)
        self.clock.t += si.STALE_S + 5
        s = self.st()
        self.assertEqual((s["status"], s["band"]), ("stale", "unknown"))
        self.clock.t += si.OFFLINE_S
        self.assertEqual(self.st()["status"], "offline")

    def test_never_seen_station_is_offline_unknown(self):
        s = self.st()
        self.assertEqual((s["status"], s["band"]), ("offline", "unknown"))

    def test_label_always_present(self):
        snap = self.store.snapshot()
        self.assertIn("not an official gauge", snap["label"])
        self.assertIn("not an official gauge", snap["stations"][0]["label"])


class ConfigTests(unittest.TestCase):
    def test_unreachable_danger_level_is_refused(self):
        bad = {"s": {"key": KEY, "sensorHeightCm": 200, "dangerCm": 185}}
        with self.assertRaises(ValueError):
            si.Store(bad)


class HttpSmoke(unittest.TestCase):
    def test_end_to_end(self):
        store = si.Store(CFG)
        srv = ThreadingHTTPServer(("127.0.0.1", 0), si.make_handler(store))
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        url = f"http://127.0.0.1:{srv.server_address[1]}"
        try:
            self.assertEqual(post(url, "station-1", KEY, body("station-1", 1, 0, H - 100)), 200)
            self.assertEqual(post(url, "station-1", KEY, body("station-1", 1, 0, H - 100)), 409)
            self.assertEqual(post(url, "station-1", KEY, body("station-1", 2, 0, H - 100), "0" * 64), 401)
            snap = json.load(urllib.request.urlopen(url + "/snapshot"))
            self.assertEqual(snap["stations"][0]["band"], "safe")
        finally:
            srv.shutdown()


class StubPoller:
    def __init__(self, text):
        self._text = text

    def snapshot_json(self):
        return self._text


def _get(url):
    """(status, content-type, raw body) without raising on 4xx/5xx."""
    try:
        r = urllib.request.urlopen(url)
    except urllib.error.HTTPError as e:
        r = e
    with r:
        return r.status, r.headers.get("Content-Type"), r.read()


class AlertsRouteTests(unittest.TestCase):
    def serve(self, poller):
        srv = ThreadingHTTPServer(("127.0.0.1", 0), si.make_handler(si.Store(CFG), poller=poller))
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        self.addCleanup(srv.server_close)
        self.addCleanup(srv.shutdown)
        return f"http://127.0.0.1:{srv.server_address[1]}"

    def test_alerts_route_serves_poller_snapshot(self):
        text = json.dumps({"generatedAt": "2026-11-18T00:00:00Z", "alerts": []})
        status, ctype, raw = _get(self.serve(StubPoller(text)) + "/alerts")
        self.assertEqual(status, 200)
        self.assertEqual(ctype, "application/json; charset=utf-8")
        self.assertEqual(json.loads(raw), {"generatedAt": "2026-11-18T00:00:00Z", "alerts": []})

    def test_alerts_route_404_without_poller(self):
        status, _, _ = _get(self.serve(None) + "/alerts")
        self.assertEqual(status, 404)

    def test_alerts_route_503_when_poller_never_succeeded(self):
        status, ctype, raw = _get(self.serve(StubPoller(json.dumps({"alerts": []}))) + "/alerts")
        self.assertEqual(status, 503)
        self.assertEqual(ctype, "application/json; charset=utf-8")
        self.assertEqual(json.loads(raw), {"error": "no alert data yet"})

    def test_alerts_route_thai_text_round_trips(self):
        thai = "พายุฝนฟ้าคะนอง กรุงเทพมหานคร"
        text = json.dumps({"generatedAt": "2026-11-18T00:00:00Z", "alerts": [{"headline": thai}]},
                          ensure_ascii=False)
        status, ctype, raw = _get(self.serve(StubPoller(text)) + "/alerts")
        self.assertEqual(status, 200)
        self.assertIn("charset=utf-8", ctype)
        self.assertEqual(json.loads(raw.decode("utf-8"))["alerts"][0]["headline"], thai)

    def test_alerts_route_ignores_query_string(self):
        text = json.dumps({"generatedAt": "2026-11-18T00:00:00Z", "alerts": []})
        status, _, _ = _get(self.serve(StubPoller(text)) + "/alerts?x=1")
        self.assertEqual(status, 200)

    def test_other_routes_unchanged_with_poller(self):
        base = self.serve(StubPoller("{}"))
        self.assertEqual(_get(base + "/health")[0], 200)
        self.assertEqual(_get(base + "/nope")[0], 404)

    def test_tmd_feed_urls_must_be_http_or_https(self):
        self.assertEqual(si.check_feed_urls(["https://a/x", "http://b/y"]), ["https://a/x", "http://b/y"])
        with self.assertRaises(ValueError):
            si.check_feed_urls(["https://a/x", "file:///etc/passwd"])


if __name__ == "__main__":
    unittest.main()
