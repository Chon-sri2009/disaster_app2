"""Download a TMD CAP feed and every file it links to, as-is (standard library only).

    python capture_cap.py <feed_url> <out_dir>

Writes <out_dir>/<name>.xml for each linked file. A file that fails, or is larger than
MAX_BYTES, is skipped with a printed warning and the run goes on. The XML is untrusted
data and is written byte for byte, never parsed or executed here.
"""
import sys
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

import tmd_cap

USER_AGENT = "disaster-app-capture/1.0"
TIMEOUT_S = 20
MAX_BYTES = 300_000


def check_scheme(url):
    """Links in the feed are untrusted: only http and https may be fetched."""
    if urlparse(url).scheme.lower() not in ("http", "https"):
        raise ValueError(f"refusing non-http(s) URL scheme: {urlparse(url).scheme or '(none)'}")


class _SchemeCheckedRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        check_scheme(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


_opener = urllib.request.build_opener(_SchemeCheckedRedirects)


def _get(url):
    check_scheme(url)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with _opener.open(req, timeout=TIMEOUT_S) as r:
        return r.read(MAX_BYTES + 1)


def capture(feed_url, out_dir, get=_get):
    """Returns the list of file names written."""
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    feed = get(feed_url)
    written = []
    for url in tmd_cap.feed_links(feed.decode("utf-8", errors="replace")):
        name = Path(urlparse(url).path).name
        if not name.endswith(".xml"):
            print(f"warning: skipping {url} (not an .xml name)")
            continue
        try:
            data = get(url)
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
            print(f"warning: skipping {name}: {type(e).__name__}")
            continue
        if len(data) > MAX_BYTES:
            print(f"warning: skipping {name}: larger than {MAX_BYTES} bytes")
            continue
        (out / name).write_bytes(data)
        written.append(name)
        print(f"saved {name} ({len(data)} bytes)")
    return written


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    try:
        capture(sys.argv[1], sys.argv[2])
    except ValueError as e:
        sys.exit(f"error: {e}")
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        sys.exit(f"error: could not fetch the feed: {type(e).__name__}")
