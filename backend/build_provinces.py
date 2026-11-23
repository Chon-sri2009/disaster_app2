"""Builds assets/boundaries/th_provinces.json from the OCHA COD-AB Thailand shapefiles.

Offline build tool, standard library only. Run it once when the boundaries change:

    python build_provinces.py --src <folder with tha_admin1.shp/.dbf> --out ../assets/boundaries/th_provinces.json
    python build_provinces.py --src <folder> --check ../assets/boundaries/th_provinces.json

Simplification works on shared borders, not on rings: every border between two provinces is
cut into one arc, simplified once, and reused by both neighbours. Simplifying each ring on
its own would move the same border differently on each side and open gaps or overlaps,
which would make a phone report "no province" or two provinces for one point.
"""
import argparse
import json
import struct
import sys
from pathlib import Path

SOURCE = (
    "OCHA COD-AB Thailand (Royal Thai Survey Department), CC BY-IGO; "
    "simplified for the Disaster Alert & Rescue app"
)
DEFAULT_TOLERANCE = 0.003  # degrees, about 330 m
DECIMALS = 4


def read_dbf(data, encoding="utf-8"):
    """Rows of a DBF file as dicts of stripped strings. Deleted rows are skipped."""
    count, header_len, rec_len = struct.unpack_from("<IHH", data, 4)
    fields = []
    pos = 32
    while data[pos] != 0x0D:
        name = data[pos:pos + 11].split(b"\0")[0].decode("ascii")
        fields.append((name, data[pos + 16]))
        pos += 32
    rows = []
    for i in range(count):
        start = header_len + i * rec_len
        if data[start:start + 1] == b"*":
            continue
        row, off = {}, start + 1
        for name, size in fields:
            row[name] = data[off:off + size].decode(encoding, "replace").strip()
            off += size
        rows.append(row)
    return rows


def read_shp_polygons(data):
    """One list of rings per record; each ring is a closed list of (lon, lat) tuples."""
    out = []
    pos = 100
    while pos + 8 <= len(data):
        length_words = struct.unpack_from(">i", data, pos + 4)[0]
        body = pos + 8
        pos = body + length_words * 2
        shape_type = struct.unpack_from("<i", data, body)[0]
        if shape_type == 0:
            out.append([])
            continue
        if shape_type != 5:
            raise ValueError(f"expected polygon shapes, got type {shape_type}")
        n_parts, n_points = struct.unpack_from("<ii", data, body + 36)
        parts = list(struct.unpack_from(f"<{n_parts}i", data, body + 44))
        pt0 = body + 44 + 4 * n_parts
        coords = struct.unpack_from(f"<{2 * n_points}d", data, pt0)
        points = [(coords[2 * i], coords[2 * i + 1]) for i in range(n_points)]
        parts.append(n_points)
        out.append([points[parts[k]:parts[k + 1]] for k in range(n_parts)])
    return out


def province_code(pcode):
    """COD-AB 'TH10' to the CAP-style 'TH-10'."""
    return f"TH-{pcode[2:]}"


def _dist2(p, a, b):
    """Squared distance from point p to segment a-b (planar degrees, fine at this scale)."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    if dx == 0 and dy == 0:
        return (p[0] - a[0]) ** 2 + (p[1] - a[1]) ** 2
    t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)
    t = max(0.0, min(1.0, t))
    return (p[0] - a[0] - t * dx) ** 2 + (p[1] - a[1] - t * dy) ** 2


def douglas_peucker(points, tol):
    """Open polyline simplification; both endpoints are always kept."""
    if len(points) < 3:
        return list(points)
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    tol2 = tol * tol
    while stack:
        lo, hi = stack.pop()
        worst, idx = 0.0, -1
        for i in range(lo + 1, hi):
            d = _dist2(points[i], points[lo], points[hi])
            if d > worst:
                worst, idx = d, i
        if idx >= 0 and worst > tol2:
            keep[idx] = True
            stack.append((lo, idx))
            stack.append((idx, hi))
    return [p for p, k in zip(points, keep) if k]


def _open(ring):
    return ring[:-1] if len(ring) > 1 and ring[0] == ring[-1] else list(ring)


def _arcs(pts, owners):
    """Cut an open ring into arcs at nodes (vertices where the set of owners changes).

    Returns a list of arcs; the last point of each arc is the first of the next.
    A ring with no node is returned as one closed arc starting at its smallest vertex, so
    two provinces sharing an enclave ring cut it at the same place.
    """
    n = len(pts)
    node = [
        owners[pts[i]] != owners[pts[i - 1]] or owners[pts[i]] != owners[pts[(i + 1) % n]]
        for i in range(n)
    ]
    idx = [i for i in range(n) if node[i]]
    if not idx:
        s = pts.index(min(pts))
        rot = pts[s:] + pts[:s]
        return [rot + [rot[0]]]
    arcs = []
    for k, i in enumerate(idx):
        j = idx[(k + 1) % len(idx)]
        arc = pts[i:j + 1] if j > i else pts[i:] + pts[:j + 1]
        arcs.append(arc)
    return arcs


def simplify_provinces(rings_by_province, tol):
    """Simplify every province's rings so shared borders stay vertex-for-vertex identical."""
    owners = {}
    opened = {}
    for pid, rings in rings_by_province.items():
        opened[pid] = [_open(r) for r in rings]
        for ring in opened[pid]:
            for p in ring:
                owners.setdefault(p, set()).add(pid)
    owners = {p: frozenset(s) for p, s in owners.items()}

    cache = {}

    def simplified(arc):
        fwd = tuple(arc)
        rev = fwd[::-1]
        key = min(fwd, rev)
        if key not in cache:
            s = douglas_peucker(list(key), tol)
            # A small closed arc (island) must not collapse below a triangle: halve the
            # tolerance until it keeps one, rather than keeping every raw vertex.
            t = tol
            while key[0] == key[-1] and len(s) < 4 and len(key) >= 4 and t > 1e-9:
                t /= 2
                s = douglas_peucker(list(key), t)
            cache[key] = s
        s = cache[key]
        return s if fwd == key else s[::-1]

    out = {}
    for pid, rings in opened.items():
        res = []
        for ring in rings:
            if len(ring) < 3:
                continue
            pts = []
            for arc in _arcs(ring, owners):
                pts.extend(simplified(arc)[:-1])
            if len(pts) < 3:  # degenerate after simplifying: keep the original ring
                pts = ring
            res.append(pts + [pts[0]])
        out[pid] = res
    return out


def _round_ring(ring):
    out = []
    for lon, lat in ring:
        p = [round(lon, DECIMALS), round(lat, DECIMALS)]
        if not out or out[-1] != p:
            out.append(p)
    if out[0] != out[-1]:
        out.append(out[0])
    return out


def point_in_rings(lon, lat, rings):
    """Even-odd test over all rings, so holes are just extra rings."""
    inside = False
    for ring in rings:
        for i in range(len(ring) - 1):
            x1, y1 = ring[i]
            x2, y2 = ring[i + 1]
            if (y1 > lat) != (y2 > lat) and lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1:
                inside = not inside
    return inside


def build(src, tol=DEFAULT_TOLERANCE):
    src = Path(src)
    attrs = read_dbf((src / "tha_admin1.dbf").read_bytes())
    shapes = read_shp_polygons((src / "tha_admin1.shp").read_bytes())
    if len(attrs) != len(shapes):
        raise ValueError("dbf and shp record counts differ")
    raw = {}
    for a, rings in zip(attrs, shapes):
        raw[a["adm1_pcode"]] = [[(round(x, 7), round(y, 7)) for x, y in r] for r in rings]
    simple = simplify_provinces(raw, tol)
    provinces = []
    for a in sorted(attrs, key=lambda a: a["adm1_pcode"]):
        rings = [_round_ring(r) for r in simple[a["adm1_pcode"]]]
        rings = [r for r in rings if len(r) >= 4]
        provinces.append({
            "code": province_code(a["adm1_pcode"]),
            "nameTh": a["adm1_name1"],
            "nameEn": a["adm1_name"],
            "rings": rings,
        })
    return {"source": SOURCE, "provinces": provinces}


def check_centres(bundle, src):
    """Every district centre must land in exactly one province: its own parent."""
    rows = read_dbf((Path(src) / "tha_admin2.dbf").read_bytes())
    polys = [(p["code"], p["rings"]) for p in bundle["provinces"]]
    bad = []
    for r in rows:
        lon, lat = float(r["center_lon"]), float(r["center_lat"])
        hits = [c for c, rings in polys if point_in_rings(lon, lat, rings)]
        want = province_code(r["adm1_pcode"])
        if hits != [want]:
            bad.append((r.get("adm2_pcode", ""), r.get("adm2_name", ""), want, hits, lat, lon))
    return len(rows), bad


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--src", required=True, help="folder with the COD-AB shapefiles")
    ap.add_argument("--out", help="write the bundle here")
    ap.add_argument("--tolerance", type=float, default=DEFAULT_TOLERANCE)
    ap.add_argument("--check", help="check an existing bundle against the district centres")
    args = ap.parse_args(argv)
    if args.check:
        bundle = json.loads(Path(args.check).read_text("utf-8"))
    else:
        bundle = build(args.src, args.tolerance)
        if args.out:
            Path(args.out).parent.mkdir(parents=True, exist_ok=True)
            Path(args.out).write_text(
                json.dumps(bundle, ensure_ascii=False, separators=(",", ":")), "utf-8"
            )
            print(f"wrote {args.out} ({Path(args.out).stat().st_size} bytes)")
    total, bad = check_centres(bundle, args.src)
    print(f"{total - len(bad)}/{total} district centres resolve to their own province only")
    for b in bad:
        print("MISS", b)
    return 0 if not bad else 1


if __name__ == "__main__":
    sys.exit(main())
