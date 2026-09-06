import urllib.request
import re
import os
import sqlite3

ARPORD_URL = "https://cdsarc.cds.unistra.fr/ftp/VII/192/arpord.dat"
ARPLIST_URL = "https://cdsarc.cds.unistra.fr/ftp/VII/192/arplist.dat"
H400_URL = "https://raw.githubusercontent.com/maphilli14/NINACatalogs/main/Herschel400_NINA_SingleEntry.csv"

def build_arp_map():
    print("Downloading Arp catalog from VizieR...")
    req_ord = urllib.request.Request(ARPORD_URL, headers={'User-Agent': 'Mozilla/5.0'})
    arpord = urllib.request.urlopen(req_ord).read().decode('ascii', errors='replace')

    req_list = urllib.request.Request(ARPLIST_URL, headers={'User-Agent': 'Mozilla/5.0'})
    arplist = urllib.request.urlopen(req_list).read().decode('ascii', errors='replace')

    # key -> list of arp numbers
    # Also keep standalone views
    arp_by_name = {} # e.g. "NGC 2857": "Arp 1", "M 66": "Arp 16"
    arp_views = {} # int arp_num -> dict(name, ra, dec, mag, maj_ax, min_ax, type)

    for line in arpord.splitlines():
        if len(line) >= 21:
            num_str = line[0:3].strip()
            name_str = line[4:21].strip()
            if num_str.isdigit():
                num = int(num_str)
                m = re.match(r'^(NGC|IC|MESSIER|M)\s*(\d+)', name_str, re.IGNORECASE)
                if m:
                    p = m.group(1).upper()
                    n = int(m.group(2))
                    k = f"M {n}" if p.startswith("M") else f"{p} {n}"
                    arp_by_name[k] = f"Arp {num}"

    for line in arplist.splitlines():
        if len(line) >= 78:
            num_str = line[0:3].strip()
            name_str = line[4:20].strip()
            if num_str.isdigit():
                num = int(num_str)
                m = re.match(r'^(NGC|IC|MESSIER|M)\s*(\d+)', name_str, re.IGNORECASE)
                if m:
                    p = m.group(1).upper()
                    n = int(m.group(2))
                    k = f"M {n}" if p.startswith("M") else f"{p} {n}"
                    if k not in arp_by_name:
                        arp_by_name[k] = f"Arp {num}"

                # Parse view details in case standalone
                if num not in arp_views:
                    try:
                        v_mag_str = line[20:24].strip()
                        v_mag = float(v_mag_str) if v_mag_str else None
                        dim_str = line[26:35].strip()
                        dim_m = re.match(r'([0-9.]+)(?:X\s*([0-9.]+))?', dim_str)
                        maj = float(dim_m.group(1)) if dim_m and dim_m.group(1) else None
                        minor = float(dim_m.group(2)) if dim_m and dim_m.group(2) else None
                        mtype = line[38:52].strip()

                        rah = float(line[57:59].strip())
                        ram = float(line[60:62].strip())
                        ras = float(line[63:67].strip())
                        ra_deg = (rah + ram/60.0 + ras/3600.0) * 15.0

                        de_sign = -1.0 if line[68] == '-' else 1.0
                        ded = float(line[69:71].strip())
                        dem = float(line[72:74].strip())
                        des = float(line[75:77].strip())
                        dec_deg = de_sign * (ded + dem/60.0 + des/3600.0)

                        arp_views[num] = {
                            "name": f"Arp {num}",
                            "raw_name": name_str,
                            "ra_deg": ra_deg,
                            "dec_deg": dec_deg,
                            "mag": v_mag,
                            "maj": maj,
                            "min": minor,
                            "type": "Galaxy"
                        }
                    except Exception:
                        pass

    print(f"  Parsed {len(arp_by_name)} Arp cross-references and {len(arp_views)} Arp views")
    return arp_by_name, arp_views

def build_h400_map():
    print("Downloading Herschel 400 catalog...")
    req = urllib.request.Request(H400_URL, headers={'User-Agent': 'Mozilla/5.0'})
    h400_txt = urllib.request.urlopen(req).read().decode('utf-8')

    h400_by_name = {}
    for line in h400_txt.splitlines()[1:]:
        parts = line.split(',')
        if len(parts) >= 3:
            cat_entry = parts[0].strip()
            alt = parts[2].strip()
            m = re.match(r'^NGC\s*(\d+)', cat_entry, re.IGNORECASE)
            if m:
                n = int(m.group(1))
                name = f"NGC {n}"
                desig = f"H {alt}" if alt else "Herschel 400"
                h400_by_name[name] = desig

    print(f"  Parsed {len(h400_by_name)} Herschel 400 objects")
    return h400_by_name

if __name__ == "__main__":
    arp_names, arp_views = build_arp_map()
    h400_names = build_h400_map()
    print("Ready to integrate into build_catalogs.py!")
