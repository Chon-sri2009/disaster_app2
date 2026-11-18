import json
import re
import struct
import unittest
from pathlib import Path

import build_provinces as bp

ROOT = Path(__file__).resolve().parent.parent
ASSET = ROOT / "assets" / "boundaries" / "th_provinces.json"
CAP_FIX = Path(__file__).with_name("fixtures") / "cap"


def make_dbf(rows, encoding="utf-8"):
    """Tiny DBF with two character fields: code (8) and name (60)."""
    fields = [(b"code", 8), (b"name", 60)]
    rec_len = 1 + sum(n for _, n in fields)
    header_len = 32 + 32 * len(fields) + 1
    out = struct.pack("<BBBBIHH20x", 3, 26, 11, 18, len(rows), header_len, rec_len)
    for name, n in fields:
        out += name.ljust(11, b"\0") + b"C" + b"\0" * 4 + bytes([n, 0]) + b"\0" * 14
    out += b"\r"
    for code, name in rows:
        out += b" " + code.encode(encoding).ljust(8) + name.encode(encoding).ljust(60)
    return out + b"\x1a"


class DouglasPeuckerTest(unittest.TestCase):
    def test_keeps_endpoints_and_drops_collinear_point(self):
        pts = [(0.0, 0.0), (1.0, 0.0), (2.0, 0.0)]
        self.assertEqual(bp.douglas_peucker(pts, 0.01), [(0.0, 0.0), (2.0, 0.0)])

    def test_keeps_a_real_corner(self):
        pts = [(0.0, 0.0), (1.0, 1.0), (2.0, 0.0)]
        self.assertEqual(bp.douglas_peucker(pts, 0.1), pts)


class DbfTest(unittest.TestCase):
    def test_thai_text_survives(self):
        rows = bp.read_dbf(make_dbf([("TH10", "กรุงเทพมหานคร"), ("TH83", "ภูเก็ต")]))
        self.assertEqual(rows[0]["name"], "กรุงเทพมหานคร")
        self.assertEqual(rows[1], {"code": "TH83", "name": "ภูเก็ต"})


class ProvinceCodeTest(unittest.TestCase):
    def test_code_form(self):
        self.assertEqual(bp.province_code("TH10"), "TH-10")
        self.assertEqual(bp.province_code("TH83"), "TH-83")


def square(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)]


class SimplifyTest(unittest.TestCase):
    def test_sample_ring_round_trips(self):
        out = bp.simplify_provinces({"A": [square(0, 0, 1, 1)]}, 0.01)
        self.assertEqual(sorted(set(out["A"][0])), sorted(set(square(0, 0, 1, 1))))

    def test_shared_border_stays_identical(self):
        # Wiggly shared edge x=1; both provinces list it in opposite directions.
        wiggle = [(1.0, 0.0), (1.001, 0.25), (0.999, 0.5), (1.002, 0.75), (1.0, 1.0)]
        a = [(0.0, 0.0)] + wiggle + [(0.0, 1.0), (0.0, 0.0)]
        b = [(1.0, 0.0), (2.0, 0.0), (2.0, 1.0)] + wiggle[::-1][:]
        out = bp.simplify_provinces({"A": [a], "B": [b]}, 0.01)
        ra, rb = out["A"][0], out["B"][0]
        edge_a = [p for p in ra if 0.9 < p[0] < 1.1]
        edge_b = [p for p in rb if 0.9 < p[0] < 1.1]
        self.assertEqual(set(edge_a), set(edge_b))
        self.assertIn((1.0, 0.0), ra)
        self.assertIn((1.0, 1.0), rb)

    def test_enclave_ring_matches_surrounding_hole(self):
        outer = square(0, 0, 4, 4)
        hole = square(1, 1, 2, 2)[::-1]
        inner = square(1, 1, 2, 2)
        out = bp.simplify_provinces({"A": [outer, hole], "B": [inner]}, 0.01)
        self.assertEqual(sorted(set(out["A"][1])), sorted(set(out["B"][0])))


class PointInRingsTest(unittest.TestCase):
    def test_even_odd_hole(self):
        rings = [square(0, 0, 4, 4), square(1, 1, 2, 2)]
        self.assertTrue(bp.point_in_rings(3.0, 3.0, rings))
        self.assertFalse(bp.point_in_rings(1.5, 1.5, rings))
        self.assertFalse(bp.point_in_rings(5.0, 5.0, rings))


class BundleTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = ASSET.read_bytes()
        cls.bundle = json.loads(cls.raw)
        cls.by_code = {p["code"]: p for p in cls.bundle["provinces"]}

    def find(self, lat, lon):
        return [
            p["code"]
            for p in self.bundle["provinces"]
            if bp.point_in_rings(lon, lat, p["rings"])
        ]

    def test_77_provinces_with_good_codes_and_credit(self):
        self.assertEqual(len(self.bundle["provinces"]), 77)
        for code in self.by_code:
            self.assertRegex(code, r"^TH-\d{2}$")
        self.assertIn("CC BY-IGO", self.bundle["source"])
        self.assertIn("COD-AB", self.bundle["source"])

    def test_names_present(self):
        for p in self.bundle["provinces"]:
            self.assertTrue(p["nameTh"] and p["nameEn"])

    def test_cap_fixture_geocodes_exist(self):
        codes = set()
        for f in CAP_FIX.glob("*CAP*.xml"):
            codes |= set(re.findall(r"TH-\d{2}\b", f.read_text("utf-8", "ignore")))
        self.assertTrue(codes)
        self.assertLessEqual(codes, set(self.by_code))

    def test_known_places(self):
        self.assertEqual(self.find(13.7563, 100.5018), ["TH-10"])
        self.assertEqual(self.find(7.89, 98.39), ["TH-83"])

    def test_size_budget(self):
        self.assertLessEqual(len(self.raw), 600 * 1024)

    def test_coordinates_are_lon_lat_four_decimals(self):
        for p in self.bundle["provinces"]:
            for ring in p["rings"]:
                self.assertEqual(ring[0], ring[-1])
                for lon, lat in ring:
                    self.assertTrue(97 < lon < 106 and 5 < lat < 21)
                    self.assertEqual(lon, round(lon, 4))


if __name__ == "__main__":
    unittest.main()
