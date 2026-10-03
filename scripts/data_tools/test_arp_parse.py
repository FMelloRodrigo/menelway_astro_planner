import re

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
    except:
        return None, None

print("Coordinate parser ready")
