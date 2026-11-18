"""Polls the TMD CAP feeds and keeps the last good alert snapshot (standard library only).

The phone app ages alerts from the snapshot's generatedAt, so a failed poll must leave the
old snapshot AND its old generatedAt in place: a dead poller then shows as stale data,
never as fresh "no alerts". Everything fetched is untrusted text: it is parsed, never
executed, and anything odd is skipped and counted on stderr so a feed format change is
visible rather than a silent outage.
"""
import json
import sys
import threading
import time
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import PurePosixPath
from urllib.parse import urlparse

import capture_cap
import tmd_cap

# English first: its index was seen to lead the Thai one (docs/CAP_FIELDS.md).
FEED_URLS = ["https://www.tmd.go.th/en/api/xml/CAP", "https://www.tmd.go.th/api/xml/CAP"]
MAX_FEED_SIZE = 300000
_EMPTY = json.dumps({"alerts": []})  # no generatedAt: the app treats it as no snapshot


def fetch_text(url):
    """Default `get`: scheme-checked fetch (redirects re-checked) decoded as UTF-8."""
    data = capture_cap._get(url)  # reads at most MAX_BYTES + 1 bytes
    if len(data) > capture_cap.MAX_BYTES:
        raise ValueError(f"response larger than {capture_cap.MAX_BYTES} bytes")
    return data.decode("utf-8-sig")  # real CAP files start with a BOM


def _utc_now():
    return datetime.now(timezone.utc)


def _name(url):
    """Short label for log lines: the file name only, never query strings."""
    return PurePosixPath(urlparse(url).path).name or "(feed)"


def _log(message):
    print(f"tmd_poller: {message}", file=sys.stderr, flush=True)


def _feed_links_checked(body):
    """Feed text -> CAP links, or None if the body is not an RSS feed we trust.
    None (an error) is distinct from [] (an RSS feed listing no alerts right now)."""
    if not isinstance(body, str) or len(body) > MAX_FEED_SIZE:
        return None
    # Checked before any XML parser sees the body: no DTDs, so no entity expansion.
    if tmd_cap._DANGEROUS.search(body):
        return None
    try:
        root = ET.fromstring(body.lstrip("﻿"))
    except ET.ParseError:
        return None
    # An HTML error page or a new format would otherwise read as "no alerts".
    if root.tag != "rss" or root.find("channel") is None:
        return None
    return tmd_cap.feed_links(body.lstrip("﻿"))


class Poller:
    def __init__(self, feed_urls, get=fetch_text, clock=_utc_now):
        self._feed_urls = list(feed_urls)
        self._get = get
        self._clock = clock
        self._lock = threading.Lock()
        self._json = _EMPTY
        self._cache = {}  # CAP file URL -> parsed alert (files never change once published)
        self._last_links = {}  # feed URL -> its links from its last good answer

    def snapshot_json(self):
        with self._lock:
            return self._json

    def poll_once(self):
        errors = 0
        answered = []
        for feed in self._feed_urls:
            links = self._read_feed(feed)
            if links is None:
                errors += 1
                continue
            self._last_links[feed] = links
            answered.append(feed)

        # A feed that is down this time still contributes its last known links, so one
        # outage does not drop its alerts (or force a refetch of everything later).
        urls = list(dict.fromkeys(u for f in self._feed_urls for u in self._last_links.get(f, [])))
        skipped = 0
        for url in urls:
            if url not in self._cache:
                alert = self._read_file(url)
                if alert is None:
                    skipped += 1
                    continue
                self._cache[url] = alert
        # Bounded cache: forget files no feed lists any more.
        self._cache = {u: self._cache[u] for u in urls if u in self._cache}

        live = {u for f in answered for u in self._last_links[f]}
        obtained = sum(1 for u in live if u in self._cache)
        errors += skipped
        if obtained == 0 and errors > 0:
            _log(f"poll FAILED ({len(answered)}/{len(self._feed_urls)} feeds answered, "
                 f"{skipped} files skipped); keeping the previous snapshot")
            return

        alerts = tmd_cap.merge_languages([self._cache[u] for u in urls if u in self._cache])
        snapshot = tmd_cap.build_snapshot(alerts, self._clock())
        text = json.dumps(snapshot, ensure_ascii=False)
        with self._lock:
            self._json = text
        _log(f"poll ok: {len(snapshot['alerts'])} alerts, {snapshot['noPolygon']} without "
             f"polygon, {errors - skipped} feeds rejected, {skipped} files skipped")

    def run_forever(self, every_s=120, sleep=time.sleep):
        while True:
            try:
                self.poll_once()
            except Exception as e:  # a bug in one poll must not stop alerts for good
                _log(f"poll crashed: {type(e).__name__}; will retry")
            sleep(every_s)

    def _read_feed(self, url):
        try:
            body = self._get(url)
        except Exception as e:  # any network or decode failure: this feed only
            _log(f"feed rejected {url}: {type(e).__name__}")
            return None
        links = _feed_links_checked(body)
        if links is None:
            _log(f"feed rejected {url}: not a trusted RSS body")
        return links

    def _read_file(self, url):
        name = _name(url)
        try:
            body = self._get(url)
        except Exception as e:  # one bad file must not hide the others
            _log(f"skipping {name}: {type(e).__name__}")
            return None
        if not isinstance(body, str) or len(body) > tmd_cap.MAX_CAP_SIZE:
            _log(f"skipping {name}: not text or larger than {tmd_cap.MAX_CAP_SIZE}")
            return None
        alert = tmd_cap.parse_cap(body)
        if alert is None:
            _log(f"skipping {name}: not a usable CAP alert")
        return alert
