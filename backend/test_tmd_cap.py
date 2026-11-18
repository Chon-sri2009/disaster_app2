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


if __name__ == "__main__":
    unittest.main()
