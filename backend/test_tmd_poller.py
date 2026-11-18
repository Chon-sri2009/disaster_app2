import json
import os
import unittest
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

import tmd_cap
import tmd_poller

FIX = Path(__file__).with_name("fixtures") / "cap"
FEED_EN = "https://www.tmd.go.th/en/api/xml/CAP"
FEED_TH = "https://www.tmd.go.th/api/xml/CAP"


def _at(text):
    return datetime.fromisoformat(text.replace("Z", "+00:00"))


def _rss(*links):
    items = "".join(f"<item><title>x</title><link>{u}</link></item>" for u in links)
    return f'<?xml version="1.0"?><rss version="2.0"><channel>{items}</channel></rss>'


def _cap(ident, sent="2026-11-18T10:00:00+07:00", expires="2026-11-18T20:00:00+07:00",
         msg_type="Alert", refs="", lang="en-US", headline="Heavy Rain",
         polygon="13.0,100.0 13.0,101.0 14.0,101.0 13.0,100.0", status="Actual"):
    ref_xml = f"<references>{refs}</references>" if refs else ""
    exp_xml = f"<expires>{expires}</expires>" if expires else ""
    poly_xml = f"<polygon>{polygon}</polygon>" if polygon else ""
    return (
        '<alert xmlns="urn:oasis:names:tc:emergency:cap:1.2">'
        f"<identifier>{ident}</identifier><sender>TMD</sender><sent>{sent}</sent>"
        f"<status>{status}</status><msgType>{msg_type}</msgType><scope>Public</scope>{ref_xml}"
        f"<info><language>{lang}</language><severity>Severe</severity>"
        f"<headline>{headline}</headline>{exp_xml}"
        f"<area><areaDesc>x</areaDesc>{poly_xml}</area></info></alert>"
    )


class FakeGet:
    """Serves bodies by URL; an Exception value is raised. Records every call."""

    def __init__(self, pages):
        self.pages = dict(pages)
        self.calls = []

    def __call__(self, url):
        self.calls.append(url)
        body = self.pages.get(url, OSError("404"))
        if isinstance(body, Exception):
            raise body
        return body


class Clock:
    def __init__(self, t):
        self.t = _at(t)

    def __call__(self):
        return self.t


def _snap(poller):
    return json.loads(poller.snapshot_json())


def _alert(ident, sent, expires=None, msg_type="Alert", refs=(), polygons=None,
           area_codes=None):
    a = {
        "id": ident, "sender": "TMD", "status": "Actual", "msgType": msg_type,
        "level": "warning", "headline": {"en": ident}, "sent": sent, "expires": expires,
        "references": list(refs),
        "polygons": [[[100.0, 13.0], [101.0, 13.0], [101.0, 14.0], [100.0, 13.0]]]
        if polygons is None else polygons,
    }
    if area_codes is not None:
        a["areaCodes"] = list(area_codes)
    return a


NOW = "2026-11-18T05:00:00Z"


class PollerTest(unittest.TestCase):
    def _poller(self, pages, now=NOW, feeds=(FEED_EN,)):
        get = FakeGet(pages)
        return tmd_poller.Poller(list(feeds), get, Clock(now)), get

    def test_poll_builds_snapshot_from_feed_and_files(self):
        p, _ = self._poller({FEED_EN: _rss("https://x.test/a.xml"),
                             "https://x.test/a.xml": _cap("TMD1_2-en")})
        p.poll_once()
        snap = _snap(p)
        self.assertEqual(snap["generatedAt"], NOW)
        self.assertEqual([a["id"] for a in snap["alerts"]], ["TMD1_2"])
        self.assertEqual(snap["noPolygon"], 0)

    def test_one_bad_file_is_skipped(self):
        p, _ = self._poller({
            FEED_EN: _rss("https://x.test/a.xml", "https://x.test/b.xml", "https://x.test/c.xml"),
            "https://x.test/a.xml": "<<garbage",
            "https://x.test/b.xml": TimeoutError("slow"),
            "https://x.test/c.xml": _cap("TMD3_2-en"),
        })
        p.poll_once()
        self.assertEqual([a["id"] for a in _snap(p)["alerts"]], ["TMD3_2"])

    def test_feed_down_keeps_last_good_and_old_generated_at(self):
        p, get = self._poller({FEED_EN: _rss("https://x.test/a.xml"),
                               "https://x.test/a.xml": _cap("TMD1_2-en")})
        p.poll_once()
        first = p.snapshot_json()
        get.pages[FEED_EN] = OSError("down")
        p._clock.t = _at("2026-11-18T05:02:00Z")
        p.poll_once()
        self.assertEqual(p.snapshot_json(), first)
        self.assertEqual(_snap(p)["generatedAt"], NOW)

    def test_first_poll_failure_serves_empty_with_no_generated_at(self):
        p, _ = self._poller({FEED_EN: OSError("down")})
        p.poll_once()
        self.assertEqual(_snap(p), {"alerts": []})

    def test_snapshot_before_any_poll_is_empty(self):
        p, _ = self._poller({})
        self.assertEqual(_snap(p), {"alerts": []})

    def test_clean_poll_reports_zero_skipped_files(self):
        p, _ = self._poller({FEED_EN: _rss("https://x.test/a.xml"),
                             "https://x.test/a.xml": _cap("TMD1_2-en")})
        p.poll_once()
        self.assertEqual(_snap(p)["skippedFiles"], 0)

    def test_persistently_failing_listed_file_is_counted_while_others_are_served(self):
        # Without the count a live warning that cannot be read looks like "no alerts".
        p, get = self._poller({
            FEED_EN: _rss("https://x.test/a.xml", "https://x.test/b.xml"),
            "https://x.test/a.xml": _cap("TMD1_2-en"),
            "https://x.test/b.xml": OSError("404"),
        })
        for minute in ("05:00", "05:02"):
            p._clock.t = _at(f"2026-11-18T{minute}:00Z")
            p.poll_once()
            snap = _snap(p)
            self.assertEqual(snap["skippedFiles"], 1)
            self.assertEqual(snap["generatedAt"], f"2026-11-18T{minute}:00Z")
            self.assertEqual([a["id"] for a in snap["alerts"]], ["TMD1_2"])
        get.pages["https://x.test/b.xml"] = _cap("TMD2_2-en")
        p.poll_once()
        snap = _snap(p)
        self.assertEqual(snap["skippedFiles"], 0)
        self.assertEqual(sorted(a["id"] for a in snap["alerts"]), ["TMD1_2", "TMD2_2"])

    def test_cached_files_do_not_count_as_skipped(self):
        p, get = self._poller({FEED_EN: _rss("https://x.test/a.xml"),
                               "https://x.test/a.xml": _cap("TMD1_2-en")})
        p.poll_once()
        get.pages["https://x.test/a.xml"] = OSError("gone")  # cached, never refetched
        p.poll_once()
        self.assertEqual(_snap(p)["skippedFiles"], 0)

    def test_oversize_file_skipped(self):
        # A valid alert padded past MAX_CAP_SIZE (and past the brief's 256 KB): the size
        # check, not a parse failure, is what must reject it.
        big = _cap("TMD9_2-en").replace("<scope>", "<!--" + " " * 300001 + "--><scope>")
        self.assertIsNotNone(tmd_cap.parse_cap(_cap("TMD9_2-en")))
        p, _ = self._poller({
            FEED_EN: _rss("https://x.test/big.xml", "https://x.test/ok.xml"),
            "https://x.test/big.xml": big,
            "https://x.test/ok.xml": _cap("TMD1_2-en"),
        })
        p.poll_once()
        self.assertEqual([a["id"] for a in _snap(p)["alerts"]], ["TMD1_2"])

    def test_no_polygon_alert_counted(self):
        p, _ = self._poller({
            FEED_EN: _rss("https://x.test/a.xml", "https://x.test/b.xml"),
            "https://x.test/a.xml": _cap("TMD1_2-en", polygon=""),
            "https://x.test/b.xml": _cap("TMD2_2-en"),
        })
        p.poll_once()
        self.assertEqual(_snap(p)["noPolygon"], 1)

    def test_geocode_only_alert_counts_in_no_polygon_not_no_area(self):
        geo = (FIX / "synthetic" / "synthetic_geocode_only.xml").read_bytes().decode("utf-8")
        p, _ = self._poller({
            FEED_EN: _rss("https://x.test/a.xml", "https://x.test/b.xml"),
            "https://x.test/a.xml": geo,
            "https://x.test/b.xml": _cap("TMD2_2-en", polygon=""),
        }, now="2026-11-18T03:00:00Z")
        p.poll_once()
        snap = _snap(p)
        self.assertEqual(len(snap["alerts"]), 2)
        self.assertEqual(snap["noPolygon"], 2)
        self.assertEqual(snap["noArea"], 1)
        codes = {a["id"]: a["areaCodes"] for a in snap["alerts"]}
        self.assertEqual(codes, {"TMDSYNTH_GEO_1": ["TH-90", "TH-91"], "TMD2_2": []})

    def test_languages_merged(self):
        p, _ = self._poller({
            FEED_EN: _rss("https://x.test/en/a.xml"),
            FEED_TH: _rss("https://x.test/a.xml"),
            "https://x.test/en/a.xml": _cap("TMD1_2-en"),
            "https://x.test/a.xml": _cap("TMD1_2", lang="th-TH", headline="ฝนตกหนัก"),
        }, feeds=(FEED_EN, FEED_TH))
        p.poll_once()
        alerts = _snap(p)["alerts"]
        self.assertEqual(len(alerts), 1)
        self.assertEqual(alerts[0]["headline"], {"en": "Heavy Rain", "th": "ฝนตกหนัก"})

    def test_doctype_only_feed_rejected(self):
        p, _ = self._poller({FEED_EN: "<!DOCTYPE rss>"})
        p.poll_once()
        self.assertEqual(_snap(p), {"alerts": []})

    def test_doctype_feed_links_never_fetched(self):
        body = '<!doctype rss [<!ENTITY e "x">]>' + _rss("https://x.test/a.xml")
        p, get = self._poller({FEED_EN: body, "https://x.test/a.xml": _cap("TMD1_2-en")})
        p.poll_once()
        self.assertEqual(get.calls, [FEED_EN])
        self.assertEqual(_snap(p), {"alerts": []})

    def test_oversize_feed_rejected(self):
        body = _rss("https://x.test/a.xml").replace("<channel>", "<channel>" + " " * 300001)
        p, get = self._poller({FEED_EN: body, "https://x.test/a.xml": _cap("TMD1_2-en")})
        p.poll_once()
        self.assertEqual(get.calls, [FEED_EN])
        self.assertEqual(_snap(p), {"alerts": []})

    def test_non_rss_feed_is_an_error_not_an_empty_success(self):
        # A total format change must not look like "no alerts right now".
        p, get = self._poller({FEED_EN: _rss("https://x.test/a.xml"),
                               "https://x.test/a.xml": _cap("TMD1_2-en")})
        p.poll_once()
        first = p.snapshot_json()
        get.pages[FEED_EN] = "<html><body>maintenance</body></html>"
        p._clock.t = _at("2026-11-18T05:02:00Z")
        p.poll_once()
        self.assertEqual(p.snapshot_json(), first)

    def test_empty_feed_is_a_success(self):
        p, get = self._poller({FEED_EN: _rss("https://x.test/a.xml"),
                               "https://x.test/a.xml": _cap("TMD1_2-en")})
        p.poll_once()
        get.pages[FEED_EN] = _rss()
        p._clock.t = _at("2026-11-18T05:02:00Z")
        p.poll_once()
        self.assertEqual(_snap(p), {"generatedAt": "2026-11-18T05:02:00Z",
                                    "alerts": [], "noPolygon": 0, "noArea": 0,
                                    "skippedFiles": 0})

    def test_one_feed_down_other_fine_succeeds(self):
        p, _ = self._poller({
            FEED_EN: OSError("down"),
            FEED_TH: _rss("https://x.test/a.xml"),
            "https://x.test/a.xml": _cap("TMD1_2", lang="th-TH"),
        }, feeds=(FEED_EN, FEED_TH))
        p.poll_once()
        snap = _snap(p)
        self.assertEqual(snap["generatedAt"], NOW)
        self.assertEqual([a["id"] for a in snap["alerts"]], ["TMD1_2"])

    def test_one_feed_down_later_keeps_its_cached_alerts(self):
        p, get = self._poller({
            FEED_EN: _rss("https://x.test/en/a.xml"),
            FEED_TH: _rss("https://x.test/b.xml"),
            "https://x.test/en/a.xml": _cap("TMD1_2-en"),
            "https://x.test/b.xml": _cap("TMD2_2", lang="th-TH"),
        }, feeds=(FEED_EN, FEED_TH))
        p.poll_once()
        get.pages[FEED_EN] = OSError("down")
        get.calls.clear()
        p._clock.t = _at("2026-11-18T05:02:00Z")
        p.poll_once()
        snap = _snap(p)
        self.assertEqual(snap["generatedAt"], "2026-11-18T05:02:00Z")
        self.assertEqual(sorted(a["id"] for a in snap["alerts"]), ["TMD1_2", "TMD2_2"])
        self.assertEqual(get.calls, [FEED_EN, FEED_TH])  # nothing refetched

    def test_all_files_fail_counts_as_failed_poll(self):
        p, get = self._poller({FEED_EN: _rss("https://x.test/a.xml"),
                               "https://x.test/a.xml": _cap("TMD1_2-en")})
        p.poll_once()
        first = p.snapshot_json()
        get.pages[FEED_EN] = _rss("https://x.test/z.xml")
        get.pages["https://x.test/z.xml"] = "garbage"
        p._clock.t = _at("2026-11-18T05:02:00Z")
        p.poll_once()
        self.assertEqual(p.snapshot_json(), first)

    def test_success_after_failure_replaces_snapshot(self):
        p, get = self._poller({FEED_EN: _rss("https://x.test/a.xml"),
                               "https://x.test/a.xml": _cap("TMD1_2-en")})
        p.poll_once()
        get.pages[FEED_EN] = OSError("down")
        p._clock.t = _at("2026-11-18T05:02:00Z")
        p.poll_once()
        get.pages[FEED_EN] = _rss("https://x.test/b.xml")
        get.pages["https://x.test/b.xml"] = _cap("TMD2_2-en")
        p._clock.t = _at("2026-11-18T05:04:00Z")
        p.poll_once()
        snap = _snap(p)
        self.assertEqual(snap["generatedAt"], "2026-11-18T05:04:00Z")
        self.assertEqual([a["id"] for a in snap["alerts"]], ["TMD2_2"])

    def test_parsed_files_are_not_refetched_and_cache_forgets_old_urls(self):
        p, get = self._poller({FEED_EN: _rss("https://x.test/a.xml"),
                               "https://x.test/a.xml": _cap("TMD1_2-en")})
        p.poll_once()
        p.poll_once()
        self.assertEqual(get.calls.count("https://x.test/a.xml"), 1)
        get.pages[FEED_EN] = _rss("https://x.test/b.xml")
        get.pages["https://x.test/b.xml"] = _cap("TMD2_2-en")
        p.poll_once()
        self.assertNotIn("https://x.test/a.xml", p._cache)

    def test_poll_crash_does_not_kill_run_forever(self):
        p, _ = self._poller({})
        calls = []

        def boom():
            calls.append(1)
            raise RuntimeError("bug")

        def sleep(_):
            if len(calls) >= 3:
                raise KeyboardInterrupt  # the only way out of the loop in this test
        p.poll_once = boom
        with self.assertRaises(KeyboardInterrupt):
            p.run_forever(every_s=0, sleep=sleep)
        self.assertEqual(len(calls), 3)


class FetchTextTest(unittest.TestCase):
    def test_refuses_non_http_scheme_without_network(self):
        with self.assertRaises(ValueError):
            tmd_poller.fetch_text("file:///etc/passwd")


class RealFixtureTest(unittest.TestCase):
    def _fixture_get(self):
        def get(url):
            if url == FEED_EN:
                return (FIX / "feed_en.rss.xml").read_bytes().decode("utf-8-sig")
            if url == FEED_TH:
                return (FIX / "feed_th.rss.xml").read_bytes().decode("utf-8-sig")
            path = urlparse(url).path
            name = Path(path).name
            prefix = "en_" if path.startswith("/uploads/CAP/en/") else "th_"
            return (FIX / (prefix + name)).read_bytes().decode("utf-8-sig")
        return get

    def test_merge_languages_on_real_pair(self):
        en = tmd_cap.parse_cap((FIX / "en_CAPTMD20261118155021_2.xml").read_bytes())
        th = tmd_cap.parse_cap((FIX / "th_CAPTMD20261118155021_2.xml").read_bytes())
        merged = tmd_cap.merge_languages([en, th])
        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]["id"], "TMD20261118155021_2")
        self.assertEqual(set(merged[0]["headline"]), {"en", "th"})
        self.assertEqual(merged[0]["polygons"], en["polygons"])

    def test_real_full_pass(self):
        # Newest fixture was sent 2026-11-18T10:45Z. At 10:50Z the 24 h cutoff is
        # 2026-11-17T10:50Z: the alerts expiring 11-16 11:00Z and 11-17 01:00Z (and the
        # Update whose referenced alert is absent) are pruned; 4 remain.
        p = tmd_poller.Poller([FEED_EN, FEED_TH], self._fixture_get(),
                              Clock("2026-11-18T10:50:00Z"))
        p.poll_once()
        snap = _snap(p)
        self.assertEqual(snap["generatedAt"], "2026-11-18T10:50:00Z")
        self.assertEqual(len(snap["alerts"]), 4)
        first = snap["alerts"][0]
        self.assertEqual(first["id"], "TMD20261118155021_2")
        self.assertEqual(set(first["headline"]), {"en", "th"})
        self.assertEqual(first["polygons"][0][0], [99.968294, 9.311178])
        self.assertEqual(snap["noPolygon"], 0)
        self.assertEqual(snap["noArea"], 0)
        self.assertEqual(first["areaCodes"],
                         ["TH-80", "TH-84", "TH-90", "TH-93", "TH-94", "TH-95", "TH-96"])
        for a in snap["alerts"]:
            self.assertTrue(a["areaCodes"])


CONTRACT = Path(__file__).resolve().parent.parent / "test" / "fixtures" / "alerts_snapshot.json"
CONTRACT_NOW = "2026-11-18T10:50:00Z"


def _ref(ident):
    return f"TMD,{ident}-en,2026-11-18T10:00:00+07:00"


def _contract_snapshot_text():
    """Real fixtures plus synthetic Alert/Update/Cancel cases, at a fixed clock."""
    synthetic = {
        "syn_alert": _cap("SYN_ALERT-en", headline="Synthetic alert"),
        "syn_target": _cap("SYN_TARGET-en", headline="Cancelled one"),
        "syn_cancel": _cap("SYN_CANCEL-en", msg_type="Cancel", refs=_ref("SYN_TARGET"),
                           polygon="", expires="2026-11-18T22:00:00+07:00"),
        "syn_live": _cap("SYN_LIVE-en", headline="Survives a test cancel"),
        "syn_test_cancel": _cap("SYN_TESTCANCEL-en", msg_type="Cancel", status="Test",
                                refs=_ref("SYN_LIVE"), polygon=""),
        "syn_old": _cap("SYN_OLD-en", headline="Replaced one"),
        "syn_update": _cap("SYN_UPDATE-en", msg_type="Update", refs=_ref("SYN_OLD"),
                           headline="Replacement"),
        "syn_nohead": _cap("SYN_NOHEAD-en", headline=""),
        "syn_noexp": _cap("SYN_NOEXP-en", expires=None, headline="No expiry",
                         sent="2026-11-18T17:00:00+07:00"),
    }
    real = RealFixtureTest()._fixture_get()
    extra = {f"https://x.test/{k}.xml": v for k, v in synthetic.items()}

    def get(url):
        if url == FEED_EN:
            return real(url).replace("</channel>", "".join(
                f"<item><title>x</title><link>{u}</link></item>" for u in extra) + "</channel>")
        return extra[url] if url in extra else real(url)

    p = tmd_poller.Poller([FEED_EN, FEED_TH], get, Clock(CONTRACT_NOW))
    p.poll_once()
    return json.dumps(json.loads(p.snapshot_json()), ensure_ascii=False, indent=2) + "\n"


class ContractTest(unittest.TestCase):
    """The app's parser reads test/fixtures/alerts_snapshot.json (test/alert_contract_test.dart),
    so a change to the snapshot shape fails here until the file is regenerated."""

    def test_snapshot_matches_checked_in_contract_file(self):
        text = _contract_snapshot_text()
        if os.environ.get("UPDATE_CONTRACT") == "1":
            CONTRACT.parent.mkdir(parents=True, exist_ok=True)
            CONTRACT.write_text(text, encoding="utf-8", newline="\n")
        self.assertTrue(CONTRACT.exists(), "missing contract file; run with UPDATE_CONTRACT=1")
        expected = CONTRACT.read_bytes().decode("utf-8").replace("\r\n", "\n")
        self.assertEqual(
            text, expected,
            "snapshot shape changed: regenerate test/fixtures/alerts_snapshot.json with "
            "`cd backend && UPDATE_CONTRACT=1 python -m unittest test_tmd_poller` "
            "and commit it (the Dart contract test then checks the app still reads it)")


class MergeLanguagesTest(unittest.TestCase):
    def test_merge_rules(self):
        a = _alert("X", "2026-11-18T03:00:00Z", "2026-11-18T09:00:00Z", refs=["R1"])
        b = dict(_alert("X", "2026-11-18T02:00:00Z", "2026-11-18T12:00:00Z", refs=["R2", "R1"]),
                 headline={"th": "t", "en": "other"}, level="danger",
                 polygons=a["polygons"] + [[[1.0, 1.0], [2.0, 1.0], [2.0, 2.0], [1.0, 1.0]]])
        c = _alert("Y", "2026-11-18T01:00:00Z")
        out = tmd_cap.merge_languages([a, c, b])
        self.assertEqual([m["id"] for m in out], ["X", "Y"])
        x = out[0]
        self.assertEqual(x["headline"], {"en": "X", "th": "t"})
        self.assertEqual(x["level"], "danger")
        self.assertEqual(x["sent"], "2026-11-18T02:00:00Z")
        self.assertEqual(x["expires"], "2026-11-18T12:00:00Z")
        self.assertEqual(x["references"], ["R1", "R2"])
        self.assertEqual(len(x["polygons"]), 2)

    def test_merge_does_not_mutate_inputs(self):
        a = _alert("X", "2026-11-18T03:00:00Z")
        b = dict(_alert("X", "2026-11-18T03:00:00Z"), headline={"th": "t"})
        tmd_cap.merge_languages([a, b])
        self.assertEqual(a["headline"], {"en": "X"})

    def test_expires_none_only_if_all_none(self):
        a = _alert("X", "2026-11-18T03:00:00Z", None)
        b = _alert("X", "2026-11-18T03:00:00Z", "2026-11-18T05:00:00Z")
        self.assertEqual(tmd_cap.merge_languages([a, b])[0]["expires"], "2026-11-18T05:00:00Z")
        self.assertIsNone(tmd_cap.merge_languages([a, dict(a)])[0]["expires"])


class BuildSnapshotTest(unittest.TestCase):
    NOW = _at("2026-11-18T12:00:00Z")  # 24 h cutoff: 2026-11-17T12:00:00Z

    def _ids(self, alerts):
        return [a["id"] for a in tmd_cap.build_snapshot(alerts, self.NOW)["alerts"]]

    def test_sorted_newest_first_and_counts_no_polygon(self):
        snap = tmd_cap.build_snapshot([
            _alert("OLD", "2026-11-18T01:00:00Z", "2026-11-18T20:00:00Z"),
            _alert("NEW", "2026-11-18T09:00:00Z", "2026-11-18T20:00:00Z", polygons=[]),
        ], self.NOW)
        self.assertEqual(snap["generatedAt"], "2026-11-18T12:00:00Z")
        self.assertEqual([a["id"] for a in snap["alerts"]], ["NEW", "OLD"])
        self.assertEqual(snap["noPolygon"], 1)

    def test_no_area_counts_only_alerts_with_neither_polygons_nor_codes(self):
        snap = tmd_cap.build_snapshot([
            _alert("POLY", "2026-11-18T01:00:00Z", "2026-11-18T20:00:00Z", area_codes=[]),
            _alert("CODES", "2026-11-18T02:00:00Z", "2026-11-18T20:00:00Z", polygons=[],
                   area_codes=["TH-90"]),
            _alert("BOTH", "2026-11-18T03:00:00Z", "2026-11-18T20:00:00Z",
                   area_codes=["TH-10"]),
            _alert("NONE", "2026-11-18T04:00:00Z", "2026-11-18T20:00:00Z", polygons=[],
                   area_codes=[]),
            _alert("LEGACY", "2026-11-18T05:00:00Z", "2026-11-18T20:00:00Z", polygons=[]),
            # Pruned alerts are not counted.
            _alert("GONE", "2026-11-15T00:00:00Z", "2026-11-15T01:00:00Z", polygons=[],
                   area_codes=[]),
        ], self.NOW)
        self.assertEqual(snap["noPolygon"], 3)  # meaning unchanged: CODES, NONE, LEGACY
        self.assertEqual(snap["noArea"], 2)     # NONE, LEGACY
        self.assertEqual(list(snap), ["generatedAt", "alerts", "noPolygon", "noArea",
                                      "skippedFiles"])

    def test_area_codes_do_not_change_pruning(self):
        # Codes on a Cancel or its target must not resurrect or drop anything.
        ids = self._ids([
            _alert("ORIG", "2026-11-16T00:00:00Z", "2026-11-18T20:00:00Z",
                   area_codes=["TH-90"]),
            _alert("CANCEL", "2026-11-16T01:00:00Z", "2026-11-16T02:00:00Z",
                   msg_type="Cancel", refs=["ORIG"], polygons=[], area_codes=["TH-90"]),
            _alert("OLD", "2026-11-15T00:00:00Z", "2026-11-16T00:00:00Z",
                   area_codes=["TH-10"]),
            _alert("OLDCANCEL", "2026-11-15T01:00:00Z", "2026-11-15T02:00:00Z",
                   msg_type="Cancel", refs=["OLD"], polygons=[], area_codes=["TH-10"]),
        ])
        self.assertEqual(sorted(ids), ["CANCEL", "ORIG"])

    def test_area_less_cancel_counts_in_no_area_and_is_kept(self):
        snap = tmd_cap.build_snapshot([
            _alert("ORIG", "2026-11-16T00:00:00Z", "2026-11-18T20:00:00Z",
                   area_codes=["TH-90"]),
            _alert("CANCEL", "2026-11-16T01:00:00Z", "2026-11-16T02:00:00Z",
                   msg_type="Cancel", refs=["ORIG"], polygons=[], area_codes=[]),
        ], self.NOW)
        self.assertEqual(sorted(a["id"] for a in snap["alerts"]), ["CANCEL", "ORIG"])
        self.assertEqual(snap["noArea"], 1)

    def test_prunes_alerts_expired_over_24h(self):
        self.assertEqual(self._ids([
            _alert("GONE", "2026-11-16T00:00:00Z", "2026-11-17T11:00:00Z"),
            _alert("RECENT", "2026-11-16T00:00:00Z", "2026-11-17T13:00:00Z"),
        ]), ["RECENT"])

    def test_no_expiry_kept_24h_after_sent(self):
        self.assertEqual(self._ids([
            _alert("GONE", "2026-11-17T11:00:00Z"),
            _alert("KEPT", "2026-11-17T13:00:00Z"),
        ]), ["KEPT"])

    def test_expired_cancel_kept_while_original_is_in_snapshot(self):
        # Pruning the Cancel would resurrect the original in the app: AlertRules hides an
        # alert only while the Cancel that references it is still in the snapshot.
        ids = self._ids([
            _alert("ORIG", "2026-11-16T00:00:00Z", "2026-11-18T20:00:00Z"),
            _alert("CANCEL", "2026-11-16T01:00:00Z", "2026-11-16T02:00:00Z",
                   msg_type="Cancel", refs=["ORIG"], polygons=[]),
        ])
        self.assertEqual(sorted(ids), ["CANCEL", "ORIG"])

    def test_expired_update_chain_kept(self):
        ids = self._ids([
            _alert("A", "2026-11-16T00:00:00Z", "2026-11-18T20:00:00Z"),
            _alert("B", "2026-11-16T01:00:00Z", "2026-11-16T02:00:00Z",
                   msg_type="Update", refs=["A"]),
            _alert("C", "2026-11-16T03:00:00Z", "2026-11-16T04:00:00Z",
                   msg_type="Cancel", refs=["B"]),
        ])
        self.assertEqual(sorted(ids), ["A", "B", "C"])

    def test_expired_cancel_dropped_once_original_gone(self):
        self.assertEqual(self._ids([
            _alert("ORIG", "2026-11-15T00:00:00Z", "2026-11-16T00:00:00Z"),
            _alert("CANCEL", "2026-11-15T01:00:00Z", "2026-11-15T02:00:00Z",
                   msg_type="Cancel", refs=["ORIG", "NEVER_SEEN"]),
        ]), [])


if __name__ == "__main__":
    unittest.main()
