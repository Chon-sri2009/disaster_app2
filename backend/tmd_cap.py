"""TMD (Thai Meteorological Department) CAP feed reader (Python standard library only).

The feed is an RSS index of CAP XML files, public domain per its copyright element:
    https://www.tmd.go.th/en/api/xml/CAP     English files under /uploads/CAP/en/
    https://www.tmd.go.th/api/xml/CAP        Thai files under /uploads/CAP/
feed_links() returns the CAP file URLs in feed order, de-duplicated. Downloaded XML is
untrusted data: parse it, never execute it. Bad input yields an empty list, not an error.

parse_cap() turns one CAP 1.2 file into one alert in the snapshot shape the app reads
(lib/models/official_alert.dart). It returns None for anything it cannot trust, and never
raises. Field quirks of the real feed are recorded in docs/CAP_FIELDS.md.
"""
import math
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

CAP_NS = "urn:oasis:names:tc:emergency:cap:1.2"
_NS = {"cap": CAP_NS}
MAX_CAP_SIZE = 300000  # real files are 42-70 KB; anything far bigger is not a TMD alert

# Owner's proposal in docs/INPUTS_NEEDED.md section 1, pending owner confirmation.
# A missing or unknown severity falls back to DEFAULT_LEVEL.
SEVERITY_TO_LEVEL = {
    "Minor": "watch",
    "Moderate": "warning",
    "Severe": "warning",
    "Extreme": "danger",
}
DEFAULT_LEVEL = "watch"
# Lookup keyed by casefolded severity: CAP enums are case-sensitive, but a publisher's
# case slip ("SEVERE") must not silently drop a warning to watch.
_SEVERITY_LOOKUP = {k.casefold(): v for k, v in SEVERITY_TO_LEVEL.items()}
_LEVEL_RANK = {"safe": 0, "watch": 1, "warning": 2, "danger": 3}

# CAP 1.2 dateTime: seconds precision and an explicit offset. A time without an offset
# is rejected: guessing the zone could shift an alert by hours.
_CAP_TIME = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[+-]\d{2}:\d{2}|Z)")
_DANGEROUS = re.compile(r"<!\s*(doctype|entity)", re.IGNORECASE)


def base_id(identifier):
    """The alert id shared by the English and Thai twins: drop a trailing -en/-th only."""
    for suffix in ("-en", "-th"):
        if identifier.endswith(suffix):
            return identifier[: -len(suffix)]
    return identifier


def _utc(text):
    """CAP time text -> 'YYYY-MM-DDTHH:MM:SSZ', or None when absent or not trustworthy."""
    text = (text or "").strip()
    if not _CAP_TIME.fullmatch(text):
        return None
    try:
        t = datetime.fromisoformat(text)
    except ValueError:
        return None
    if t.tzinfo is None:
        return None
    return t.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _ring(text):
    """'lat,lon lat,lon ...' -> [[lon, lat], ...] (GeoJSON order), or None if any point
    is bad or there are fewer than 3 points. The ring is otherwise kept as sent."""
    ring = []
    for point in (text or "").split():
        parts = point.split(",")
        if len(parts) != 2:
            return None
        try:
            lat, lon = float(parts[0]), float(parts[1])
        except ValueError:
            return None
        # NaN/inf parse as floats but are not places (and not valid JSON).
        if not (math.isfinite(lat) and math.isfinite(lon)):
            return None
        # Out of range means not a place. Thai longitudes (97-106) exceed 90, so this
        # also catches a ring sent as lon,lat instead of lat,lon.
        if abs(lat) > 90 or abs(lon) > 180:
            return None
        ring.append([lon, lat])
    return ring if len(ring) >= 3 else None


def _references(text):
    """CAP references: space-separated 'sender,identifier,sent' triples -> plain ids."""
    ids = []
    for triple in (text or "").split():
        parts = triple.split(",")
        if len(parts) != 3 or not parts[1]:
            continue  # malformed triple: ignore it, keep the alert
        rid = base_id(parts[1])
        if rid not in ids:
            ids.append(rid)
    return ids


def _text(element, path):
    return (element.findtext(path, namespaces=_NS) or "").strip()


def _decode(xml_text):
    if isinstance(xml_text, bytes):
        if len(xml_text) > MAX_CAP_SIZE:
            return None
        try:
            return xml_text.decode("utf-8-sig")
        except UnicodeDecodeError:
            return None
    if isinstance(xml_text, str):
        return xml_text
    return None


def parse_cap(xml_text):
    """One CAP 1.2 alert (text; bytes also accepted) -> snapshot alert dict, or None."""
    try:
        return _parse_cap(xml_text)
    except Exception:  # untrusted input: any surprise means "not an alert", never a crash
        return None


def _parse_cap(xml_text):
    text = _decode(xml_text)
    if text is None or len(text) > MAX_CAP_SIZE or len(text.encode("utf-8")) > MAX_CAP_SIZE:
        return None
    # No DTDs at all: blocks entity-expansion attacks before the parser sees them.
    if _DANGEROUS.search(text):
        return None
    text = text.lstrip("﻿")  # real files start with a UTF-8 BOM
    if not text.strip():
        return None
    try:
        root = ET.fromstring(text)
    except ET.ParseError:
        return None
    if root.tag != "{%s}alert" % CAP_NS:
        return None

    identifier = _text(root, "cap:identifier")
    sent = _utc(root.findtext("cap:sent", namespaces=_NS))
    sender = _text(root, "cap:sender")
    status = _text(root, "cap:status")
    msg_type = _text(root, "cap:msgType")
    # The app casts these as non-null strings; CAP requires them, so a file without
    # them is not an alert we can show or act on.
    if not (identifier and sent and sender and status and msg_type):
        return None

    level = DEFAULT_LEVEL
    headline = {}
    expires = None
    polygons = []
    seen_rings = set()
    for info in root.findall("cap:info", _NS):
        candidate = _SEVERITY_LOOKUP.get(_text(info, "cap:severity").casefold(), DEFAULT_LEVEL)
        if _LEVEL_RANK[candidate] > _LEVEL_RANK[level]:
            level = candidate
        # CAP 1.2: a missing <language> means en-US.
        lang = (_text(info, "cap:language") or "en-US").split("-")[0].lower()
        title = _text(info, "cap:headline")
        if title and lang and lang not in headline:
            headline[lang] = title
        # Several infos: keep the latest expiry, so the alert stays up while any part of
        # it is still in force. Same-format UTC strings compare correctly as text.
        info_expires = _utc(info.findtext("cap:expires", namespaces=_NS))
        if info_expires and (expires is None or info_expires > expires):
            expires = info_expires
        for poly in info.findall("cap:area/cap:polygon", _NS):
            ring = _ring(poly.text)
            if ring is None:
                continue  # one bad ring must not hide the rest of the alert
            key = tuple(tuple(p) for p in ring)
            if key not in seen_rings:
                seen_rings.add(key)
                polygons.append(ring)

    return {
        "id": base_id(identifier),
        "sender": sender,
        "status": status,
        "msgType": msg_type,
        "level": level,
        "headline": headline,
        "sent": sent,
        "expires": expires,
        "references": _references(root.findtext("cap:references", namespaces=_NS)),
        "polygons": polygons,
    }


def feed_links(rss_xml):
    try:
        root = ET.fromstring(rss_xml)
    except ET.ParseError:
        return []
    links = []
    for item in root.iter("item"):
        url = (item.findtext("link") or "").strip()
        if url and url not in links:
            links.append(url)
    return links
