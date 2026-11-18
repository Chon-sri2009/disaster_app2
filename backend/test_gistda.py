"""Run:  python -m unittest test_gistda   (from the backend folder)"""
import unittest
import urllib.error

import gistda


class FloodRecurrence(unittest.TestCase):
    def test_not_found_is_none(self):
        self.assertIsNone(gistda.flood_recurrence(1, 2, key="k", get=lambda u: {"result": "not found"}))

    def test_data_passes_through_and_url_is_built(self):
        seen = []
        data = gistda.flood_recurrence(13.5, 100.25, key="k", get=lambda u: seen.append(u) or {"a": 1})
        self.assertEqual(data, {"a": 1})
        self.assertIn("/v1.1/disasters/flood-recurrence?lat=13.5&lon=100.25&api_key=k", seen[0])

    def test_http_error_hides_key(self):
        def boom(url):
            raise urllib.error.HTTPError(url, 404, "nf", {}, None)
        with self.assertRaises(gistda.GistdaError) as c:
            gistda.flood_recurrence(1, 2, key="SECRET", get=boom)
        self.assertNotIn("SECRET", str(c.exception))
        self.assertIn("404", str(c.exception))

    def test_missing_key(self):
        import os
        old, os.environ["GISTDA_API_KEY"] = os.environ.get("GISTDA_API_KEY"), ""
        try:
            gistda.Path = lambda *_: type("P", (), {"with_name": lambda s, n: type("E", (), {"exists": lambda s: False})()})()
            with self.assertRaises(gistda.GistdaError):
                gistda.load_key()
        finally:
            from pathlib import Path
            gistda.Path = Path
            if old is None:
                del os.environ["GISTDA_API_KEY"]
            else:
                os.environ["GISTDA_API_KEY"] = old


class FloodHistoryEndpoint(unittest.TestCase):
    ROW = {"subdistrict_name": "A", "district_name": "B", "province_name": "C", "total": 1,
           "detail": [{"year": "2023", "freq": 0}, {"year": "2011", "freq": 2}]}

    def call(self, query, lookup):
        from sensor_ingest import flood_history
        return flood_history(query, lookup)

    def test_found_sorts_years(self):
        code, body = self.call({"lat": ["14"], "lng": ["100"]}, lambda a, b: [self.ROW])
        self.assertEqual(code, 200)
        self.assertEqual([y["year"] for y in body["years"]], [2011, 2023])
        self.assertEqual(body["province"], "C")

    def test_no_record(self):
        self.assertEqual(self.call({"lat": ["1"], "lng": ["2"]}, lambda a, b: None), (200, {"found": False, "source": "GISTDA"}))

    def test_bad_input(self):
        for q in ({}, {"lat": ["x"], "lng": ["1"]}, {"lat": ["91"], "lng": ["1"]}, {"lat": ["nan"], "lng": ["1"]}):
            self.assertEqual(self.call(q, lambda a, b: None)[0], 400)

    def test_gateway_failure_is_503(self):
        def boom(a, b):
            raise gistda.GistdaError("x")
        self.assertEqual(self.call({"lat": ["1"], "lng": ["2"]}, boom)[0], 503)


if __name__ == "__main__":
    unittest.main()
