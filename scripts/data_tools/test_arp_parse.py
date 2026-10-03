import unittest

def parse_coord(ra_h, ra_m, ra_s, dec_sign, dec_d, dec_m, dec_s):
    try:
        h = float(ra_h)
        m = float(ra_m)
        s = float(ra_s)
        ra_deg = (h + m/60.0 + s/3600.0) * 15.0

        sign = -1.0 if dec_sign == '-' else 1.0
        d = float(dec_d)
        dm = float(dec_m)
        ds = float(dec_s)
        dec_deg = sign * (d + dm/60.0 + ds/3600.0)
        return ra_deg, dec_deg
    except Exception:
        return None, None

class TestArpParse(unittest.TestCase):
    def test_parse_coord_positive(self):
        ra, dec = parse_coord("12", "30", "0", "+", "45", "30", "0")
        self.assertAlmostEqual(ra, 187.5)
        self.assertAlmostEqual(dec, 45.5)

    def test_parse_coord_negative(self):
        ra, dec = parse_coord("0", "0", "0", "-", "10", "30", "0")
        self.assertAlmostEqual(ra, 0.0)
        self.assertAlmostEqual(dec, -10.5)

    def test_parse_coord_invalid(self):
        ra, dec = parse_coord("invalid", "0", "0", "+", "0", "0", "0")
        self.assertIsNone(ra)
        self.assertIsNone(dec)

if __name__ == "__main__":
    unittest.main()
