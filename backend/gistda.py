"""GISTDA API Gateway client (Python standard library only). The key stays on the server.

    python gistda.py 14.35 100.57        flood recurrence at a point

Reads GISTDA_API_KEY from the environment or backend/.env.
flood_recurrence() returns the gateway's JSON for a recurring-flood area, or None when the
point is not in one. "None" means GISTDA has no recurrence record there. It does NOT mean
the place is safe, and callers must not present it that way.
The gateway puts the key inside response links, so never log a raw response or the request URL.
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

BASE = "https://api-gateway.gistda.or.th/api/2.0/resources/gi-service/v1.1/disasters"
TIMEOUT_S = 20


class GistdaError(Exception):
    """Gateway or network failure. The message never contains the key."""


def load_key():
    key = os.environ.get("GISTDA_API_KEY", "").strip()
    env = Path(__file__).with_name(".env")
    if not key and env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            name, _, value = line.partition("=")
            if name.strip() == "GISTDA_API_KEY":
                key = value.strip()
    if not key:
        raise GistdaError("GISTDA_API_KEY is not set (environment or backend/.env)")
    return key


def _get(url):
    with urllib.request.urlopen(url, timeout=TIMEOUT_S) as r:
        return json.load(r)


def flood_recurrence(lat, lng, key=None, get=_get):
    key = key or load_key()
    query = urllib.parse.urlencode({"lat": lat, "lon": lng, "api_key": key})
    try:
        data = get(f"{BASE}/flood-recurrence?{query}")
    except urllib.error.HTTPError as e:
        raise GistdaError(f"gateway returned HTTP {e.code}") from None
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
        raise GistdaError(f"request failed: {type(e).__name__}") from None
    if isinstance(data, dict) and data.get("result") == "not found":
        return None
    return data


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.stdout.reconfigure(encoding="utf-8")  # Thai place names on a Windows console
    try:
        found = flood_recurrence(float(sys.argv[1]), float(sys.argv[2]))
    except GistdaError as e:
        sys.exit(f"error: {e}")
    if found is None:
        print("No recurring-flood record at this point (not a safety statement).")
    else:
        print(json.dumps(found, ensure_ascii=False, indent=2).replace(load_key(), "<KEY>"))
