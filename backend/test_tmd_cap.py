import unittest

import tmd_cap

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


if __name__ == "__main__":
    unittest.main()
