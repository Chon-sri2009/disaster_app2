"""TMD (Thai Meteorological Department) CAP feed reader (Python standard library only).

The feed is an RSS index of CAP XML files, public domain per its copyright element:
    https://www.tmd.go.th/en/api/xml/CAP     English files under /uploads/CAP/en/
    https://www.tmd.go.th/api/xml/CAP        Thai files under /uploads/CAP/
feed_links() returns the CAP file URLs in feed order, de-duplicated. Downloaded XML is
untrusted data: parse it, never execute it. Bad input yields an empty list, not an error.
"""
import xml.etree.ElementTree as ET


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
