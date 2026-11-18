import tempfile
import unittest
from pathlib import Path

import capture_cap
import tmd_cap

FIX = Path(__file__).with_name("fixtures") / "cap"

RSS = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"><channel>
<link>https://example.test/feed</link>
<item><title>A</title><link>https://example.test/CAP/a.xml</link></item>
<item><title>B</title><link>https://example.test/CAP/b.xml</link></item>
<item><title>A again</title><link>https://example.test/CAP/a.xml</link></item>
</channel></rss>"""


class FeedLinksTest(unittest.TestCase):
    def test_feed_links_returns_cap_urls_in_order(self):
        self.assertEqual(
            tmd_cap.feed_links(RSS),
            ["https://example.test/CAP/a.xml", "https://example.test/CAP/b.xml"],
        )

    def test_feed_links_ignores_garbage(self):
        self.assertEqual(tmd_cap.feed_links("not xml"), [])

    def test_feed_links_on_real_english_feed(self):
        text = (FIX / "feed_en.rss.xml").read_bytes().decode("utf-8-sig")
        self.assertEqual(len(tmd_cap.feed_links(text)), 6)


class FixtureBytesTest(unittest.TestCase):
    def test_fixture_is_stored_as_served_bom_and_crlf(self):
        raw = (FIX / "en_CAPTMD20261116051107_2.xml").read_bytes()
        self.assertTrue(raw.startswith(b"\xef\xbb\xbf"))
        self.assertIn(b"\r\n", raw)


class CaptureSchemeTest(unittest.TestCase):
    FEED = (
        "<rss><channel>"
        "<item><link>file:///etc/a.xml</link></item>"
        "<item><link>ftp://example.test/b.xml</link></item>"
        "<item><link>https://example.test/c.xml</link></item>"
        "</channel></rss>"
    )

    def fake_get(self, url):
        capture_cap.check_scheme(url)
        return self.FEED.encode() if url == "https://example.test/feed" else b"<alert/>"

    def test_only_http_links_are_written(self):
        with tempfile.TemporaryDirectory() as d:
            written = capture_cap.capture("https://example.test/feed", d, get=self.fake_get)
            self.assertEqual(written, ["c.xml"])
            self.assertEqual([p.name for p in Path(d).iterdir()], ["c.xml"])

    def test_check_scheme(self):
        for bad in ("file:///etc/passwd", "ftp://example.test/x"):
            with self.assertRaises(ValueError):
                capture_cap.check_scheme(bad)
        capture_cap.check_scheme("http://example.test/x")
        capture_cap.check_scheme("https://example.test/x")


SYN = FIX / "synthetic"
UPDATE_EN = "en_CAPTMD20261116051107_2.xml"  # the one real Update, has references
# Polygon counts per real English file, counted from the raw XML (all distinct, all
# closed rings of at least 4 points), so the parser must keep every one.
REAL_POLYGON_COUNTS = {
    "CAPTMD20261116051107_2.xml": 68,
    "CAPTMD20261116155515_2.xml": 44,
    "CAPTMD20261117053453_2.xml": 10,
    "CAPTMD20261117161100_2.xml": 17,
    "CAPTMD20261118060419_2.xml": 17,
    "CAPTMD20261118155021_2.xml": 36,
}


def real(name):
    # Plain utf-8 on purpose: the U+FEFF BOM stays in the text, as a caller would hand it.
    return (FIX / name).read_bytes().decode("utf-8")


def synthetic(name):
    return (SYN / name).read_bytes().decode("utf-8")


def cap(info="", head_extra="", sent="2026-11-18T09:00:00+07:00", ident="X_1-en"):
    """A minimal inline CAP alert for single-behaviour tests."""
    return (
        '<alert xmlns="urn:oasis:names:tc:emergency:cap:1.2">'
        f"<identifier>{ident}</identifier><sender>TMD</sender><sent>{sent}</sent>"
        f"<status>Actual</status><msgType>Alert</msgType><scope>Public</scope>"
        f"{head_extra}{info}</alert>"
    )


def info(severity=None, lang="en-US", polygons=(), expires=None, headline="H"):
    sev = f"<severity>{severity}</severity>" if severity is not None else ""
    exp = f"<expires>{expires}</expires>" if expires is not None else ""
    lng = f"<language>{lang}</language>" if lang is not None else ""
    polys = "".join(f"<polygon>{p}</polygon>" for p in polygons)
    return (
        f"<info>{lng}<event>E</event>{sev}{exp}<headline>{headline}</headline>"
        f"<area><areaDesc>A</areaDesc>{polys}</area></info>"
    )


class BaseIdTest(unittest.TestCase):
    def test_strips_language_suffix_only(self):
        self.assertEqual(tmd_cap.base_id("TMD20261117053453_2-en"), "TMD20261117053453_2")
        self.assertEqual(tmd_cap.base_id("TMD20261117053453_2-th"), "TMD20261117053453_2")
        self.assertEqual(tmd_cap.base_id("TMD20261117053453_2"), "TMD20261117053453_2")
        # Not a suffix strip by characters: "-en" chars inside or other suffixes stay.
        self.assertEqual(tmd_cap.base_id("TMD_open"), "TMD_open")
        self.assertEqual(tmd_cap.base_id("TMD_1-de"), "TMD_1-de")
        self.assertEqual(tmd_cap.base_id("TMD_1-en-en"), "TMD_1-en")


class ParseCapRealTest(unittest.TestCase):
    def test_real_update_file(self):
        a = tmd_cap.parse_cap(real(UPDATE_EN))
        self.assertEqual(a["id"], "TMD20261116051107_2")
        self.assertEqual(a["sender"], "TMD")
        self.assertEqual(a["status"], "Actual")
        self.assertEqual(a["msgType"], "Update")
        self.assertEqual(a["level"], "warning")  # Severe -> warning
        self.assertEqual(a["headline"], {"en": "Heavy Rain Risk Area"})
        self.assertEqual(a["references"], ["TMD20261115160447_2"])
        self.assertEqual(len(a["polygons"]), 68)
        self.assertEqual(
            set(a),
            {"id", "sender", "status", "msgType", "level", "headline", "sent",
             "expires", "references", "polygons"},
        )

    def test_times_are_utc(self):
        # 2026-11-16T05:04:00+07:00 crosses midnight into the previous UTC day.
        a = tmd_cap.parse_cap(real(UPDATE_EN))
        self.assertEqual(a["sent"], "2026-11-15T22:04:00Z")
        self.assertEqual(a["expires"], "2026-11-16T11:00:00Z")

    def test_real_polygon_axis_order(self):
        # First real ring starts "9.311178,99.968294" (lat,lon) and is closed.
        ring = tmd_cap.parse_cap(real(UPDATE_EN))["polygons"][0]
        self.assertEqual(ring[0], [99.968294, 9.311178])
        self.assertEqual(ring[-1], [99.968294, 9.311178])
        self.assertEqual(len(ring), 5)

    def test_bom_text_parses(self):
        text = real(UPDATE_EN)
        self.assertTrue(text.startswith("﻿"))
        self.assertIsNotNone(tmd_cap.parse_cap(text))
        self.assertIsNotNone(tmd_cap.parse_cap(text.lstrip("﻿")))

    def test_thai_headline_and_id(self):
        a = tmd_cap.parse_cap(real("th_" + UPDATE_EN[3:]))
        self.assertEqual(a["id"], "TMD20261116051107_2")
        self.assertEqual(list(a["headline"]), ["th"])
        self.assertTrue(a["headline"]["th"].startswith("พื้นที่เสี่ยงภัย"))

    def test_all_real_fixtures_parse_and_twins_match(self):
        for name, count in REAL_POLYGON_COUNTS.items():
            with self.subTest(name=name):
                en = tmd_cap.parse_cap(real("en_" + name))
                th = tmd_cap.parse_cap(real("th_" + name))
                self.assertIsNotNone(en)
                self.assertIsNotNone(th)
                self.assertEqual(en["id"], th["id"])
                self.assertFalse(en["id"].endswith("-en"))
                self.assertEqual(en["sent"], th["sent"])
                self.assertEqual(en["expires"], th["expires"])
                self.assertEqual(en["level"], th["level"])
                self.assertEqual(en["polygons"], th["polygons"])
                self.assertEqual(len(en["polygons"]), count)
                self.assertTrue(en["sent"].endswith("Z"))
                self.assertEqual(list(en["headline"]), ["en"])
                self.assertEqual(list(th["headline"]), ["th"])


class ParseCapBehaviourTest(unittest.TestCase):
    def test_polygon_axis_order(self):
        a = tmd_cap.parse_cap(cap(info("Severe", polygons=["13.7,100.5 13.7,100.6 13.8,100.6"])))
        self.assertEqual(a["polygons"], [[[100.5, 13.7], [100.6, 13.7], [100.6, 13.8]]])

    def test_times_are_utc_inline(self):
        a = tmd_cap.parse_cap(cap(info("Severe"), sent="2026-11-12T06:28:45+07:00"))
        self.assertEqual(a["sent"], "2026-11-11T23:28:45Z")

    def test_naive_or_bad_sent_returns_none(self):
        for sent in ("2026-11-12T06:28:45", "2026-11-12", "yesterday", ""):
            with self.subTest(sent=sent):
                self.assertIsNone(tmd_cap.parse_cap(cap(info("Severe"), sent=sent)))

    def test_naive_expires_is_null(self):
        a = tmd_cap.parse_cap(cap(info("Severe", expires="2026-11-12T18:00:00")))
        self.assertIsNone(a["expires"])

    def test_missing_expires_is_null(self):
        a = tmd_cap.parse_cap(synthetic("synthetic_no_expires.xml"))
        self.assertIsNotNone(a)
        self.assertIsNone(a["expires"])
        self.assertIn("expires", a)

    def test_unparseable_expires_is_null(self):
        a = tmd_cap.parse_cap(synthetic("synthetic_bad_expires.xml"))
        self.assertIsNotNone(a)
        self.assertIsNone(a["expires"])

    def test_severity_mapping(self):
        self.assertEqual(
            tmd_cap.SEVERITY_TO_LEVEL,
            {"Minor": "watch", "Moderate": "warning", "Severe": "warning", "Extreme": "danger"},
        )
        cases = {"Minor": "watch", "Moderate": "warning", "Severe": "warning",
                 "Extreme": "danger", None: "watch", "Unknown": "watch", "bogus": "watch"}
        for sev, level in cases.items():
            with self.subTest(severity=sev):
                self.assertEqual(tmd_cap.parse_cap(cap(info(sev)))["level"], level)

    def test_synthetic_extreme_and_minor(self):
        self.assertEqual(tmd_cap.parse_cap(synthetic("synthetic_no_expires.xml"))["level"], "danger")
        self.assertEqual(tmd_cap.parse_cap(synthetic("synthetic_test_status.xml"))["level"], "watch")

    def test_references_become_plain_ids(self):
        refs = "<references>TMD,TMD2026X_1-en,2026-11-12T06:00:00+07:00</references>"
        a = tmd_cap.parse_cap(cap(info("Severe"), head_extra=refs))
        self.assertEqual(a["references"], ["TMD2026X_1"])

    def test_no_references_is_empty_list(self):
        self.assertEqual(tmd_cap.parse_cap(cap(info("Severe")))["references"], [])

    def test_status_and_msgtype_pass_through(self):
        t = tmd_cap.parse_cap(synthetic("synthetic_test_status.xml"))
        self.assertEqual((t["status"], t["msgType"]), ("Test", "Alert"))
        c = tmd_cap.parse_cap(synthetic("synthetic_cancel_no_info.xml"))
        self.assertEqual((c["status"], c["msgType"]), ("Actual", "Cancel"))

    def test_cancel_without_info_is_kept(self):
        c = tmd_cap.parse_cap(synthetic("synthetic_cancel_no_info.xml"))
        self.assertEqual(c["id"], "TMD20261118180000_2")
        self.assertEqual(c["references"], ["TMD20261118155021_2"])
        self.assertEqual(c["level"], "watch")
        self.assertEqual(c["headline"], {})
        self.assertEqual(c["polygons"], [])
        self.assertIsNone(c["expires"])

    def test_headline_keyed_by_language(self):
        a = tmd_cap.parse_cap(cap(info("Severe", headline="Heavy Rain Risk Area")))
        self.assertEqual(a["headline"], {"en": "Heavy Rain Risk Area"})

    def test_missing_language_defaults_to_english(self):
        # CAP 1.2: language defaults to en-US.
        a = tmd_cap.parse_cap(cap(info("Severe", lang=None, headline="X")))
        self.assertEqual(a["headline"], {"en": "X"})

    def test_no_polygon_alert_is_kept(self):
        a = tmd_cap.parse_cap(synthetic("synthetic_geocode_only.xml"))
        self.assertIsNotNone(a)
        self.assertEqual(a["polygons"], [])

    def test_multi_info(self):
        a = tmd_cap.parse_cap(synthetic("synthetic_multi_info.xml"))
        self.assertEqual(a["id"], "TMDSYNTH_MULTI_1")
        self.assertEqual(a["level"], "danger")  # highest across infos (Extreme in th)
        self.assertEqual(a["headline"], {"en": "Rain Watch", "th": "พื้นที่เสี่ยงภัย"})
        self.assertEqual(a["references"], ["TMDSYNTH_OLD_1", "TMDSYNTH_OLD_2"])
        # Duplicate ring kept once; 2-point ring and the ring with "abc" skipped.
        self.assertEqual(
            a["polygons"],
            [
                [[100.5, 13.7], [100.6, 13.7], [100.6, 13.8], [100.5, 13.7]],
                [[101.0, 14.0], [101.1, 14.0], [101.1, 14.1], [101.0, 14.0]],
            ],
        )

    def test_bad_points_skip_only_that_ring(self):
        good = "13.7,100.5 13.7,100.6 13.8,100.6"
        for bad in ("nan,100.5 13.7,100.6 13.8,100.6", "inf,100.5 13.7,100.6 13.8,100.6",
                    "13.7,100.5,0 13.7,100.6 13.8,100.6", "13.7 100.5 13.7,100.6 13.8,100.6",
                    "13.7,100.5 13.7,100.6", "",
                    # axis-swapped (lon,lat) ring: "latitude" 100.5 is out of range
                    "100.5,13.7 100.6,13.7 100.6,13.8",
                    "13.7,180.5 13.7,100.6 13.8,100.6"):
            with self.subTest(bad=bad):
                a = tmd_cap.parse_cap(cap(info("Severe", polygons=[bad, good])))
                self.assertEqual(a["polygons"], [[[100.5, 13.7], [100.6, 13.7], [100.6, 13.8]]])

    def test_missing_required_header_returns_none(self):
        base = cap(info("Severe"))
        for tag in ("identifier", "sent", "sender", "status", "msgType"):
            with self.subTest(tag=tag):
                start = base.index(f"<{tag}>")
                end = base.index(f"</{tag}>") + len(f"</{tag}>")
                self.assertIsNone(tmd_cap.parse_cap(base[:start] + base[end:]))
        self.assertIsNone(tmd_cap.parse_cap(cap(info("Severe"), ident="  ")))


class ParseCapGarbageTest(unittest.TestCase):
    def test_garbage_returns_none(self):
        for junk in ("", "   ", "not xml", "<alert>", "<rss><channel/></rss>",
                     "<alert><identifier>a</identifier></alert>",  # no CAP namespace
                     '<x xmlns="urn:oasis:names:tc:emergency:cap:1.2"/>',
                     None, 42, b"\xff\xfe"):
            with self.subTest(junk=junk):
                self.assertIsNone(tmd_cap.parse_cap(junk))

    def test_doctype_and_entity_rejected(self):
        body = cap(info("Severe"))
        for prefix in ('<!DOCTYPE alert>', '<!doctype alert [<!ENTITY x "y">]>',
                       '<!DoCtYpE alert>'):
            with self.subTest(prefix=prefix):
                self.assertIsNone(tmd_cap.parse_cap(prefix + body))
        self.assertIsNone(tmd_cap.parse_cap(body.replace("<scope>", "<!-- <!ENTITY --><scope>")))

    def test_oversize_rejected(self):
        body = cap(info("Severe"))
        pad = "<!--" + "x" * 300000 + "-->"
        self.assertIsNone(tmd_cap.parse_cap(body + pad))
        # Thai text is 3 bytes per char in UTF-8: the byte limit applies too.
        thai_pad = "<!--" + "ก" * 110000 + "-->"
        self.assertIsNone(tmd_cap.parse_cap(body + thai_pad))

    def test_bytes_input_accepted(self):
        raw = (FIX / UPDATE_EN).read_bytes()
        self.assertEqual(tmd_cap.parse_cap(raw)["id"], "TMD20261116051107_2")


if __name__ == "__main__":
    unittest.main()
