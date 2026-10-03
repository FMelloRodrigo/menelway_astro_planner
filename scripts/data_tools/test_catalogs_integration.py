import sqlite3
import urllib.request
import re

conn = sqlite3.connect('core/data/catalogs.db')
cur = conn.cursor()

# 1. Test Arp from VizieR
print("Testing Arp dataset...")
url_arpord = "https://cdsarc.cds.unistra.fr/ftp/VII/192/arpord.dat"
arpord_txt = urllib.request.urlopen(url_arpord).read().decode('ascii', errors='replace')

url_arplist = "https://cdsarc.cds.unistra.fr/ftp/VII/192/arplist.dat"
arplist_txt = urllib.request.urlopen(url_arplist).read().decode('ascii', errors='replace')

arp_map = {} # ngc_key -> arp_label e.g. "NGC 2857" -> "Arp 1"

for line in arpord_txt.splitlines():
    if len(line) >= 21:
        arp_num = line[0:3].strip()
        name = line[4:21].strip()
        if arp_num.isdigit():
            num = int(arp_num)
            # Check if name starts with NGC or IC or MESSIER
            m = re.match(r'^(NGC|IC|MESSIER|M)\s*(\d+)', name, re.IGNORECASE)
            if m:
                p = m.group(1).upper()
                n = int(m.group(2))
                if p.startswith("M"):
                    key = f"M {n}"
                else:
                    key = f"{p} {n}"
                arp_map[key] = f"Arp {num}"

for line in arplist_txt.splitlines():
    if len(line) >= 20:
        arp_num = line[0:3].strip()
        name = line[4:20].strip()
        if arp_num.isdigit():
            num = int(arp_num)
            m = re.match(r'^(NGC|IC|MESSIER|M)\s*(\d+)', name, re.IGNORECASE)
            if m:
                p = m.group(1).upper()
                n = int(m.group(2))
                if p.startswith("M"):
                    key = f"M {n}"
                else:
                    key = f"{p} {n}"
                if key not in arp_map:
                    arp_map[key] = f"Arp {num}"

print(f"Total mapped Arp targets: {len(arp_map)}")

# Check matching against DB
matched_arp = 0
for k, v in arp_map.items():
    if k.startswith("M "):
        cur.execute("SELECT id FROM dso_objects WHERE messier = ?", (k,))
    else:
        cur.execute("SELECT id FROM dso_objects WHERE name = ?", (k,))
    if cur.fetchone():
        matched_arp += 1
print(f"Matched Arp in OpenNGC DB: {matched_arp} / {len(arp_map)}")

# 2. Test Herschel 400
print("\nTesting Herschel 400 dataset...")
url_h400 = "https://raw.githubusercontent.com/maphilli14/NINACatalogs/main/Herschel400_NINA_SingleEntry.csv"
h400_txt = urllib.request.urlopen(url_h400).read().decode('utf-8')

h400_map = {} # ngc_name -> herschel_designation e.g. "NGC 205" -> "H 18-5"
for line in h400_txt.splitlines()[1:]:
    parts = line.split(',')
    if len(parts) >= 3:
        cat_entry = parts[0].strip() # e.g. NGC 205
        alt = parts[2].strip() # e.g. 18-5
        m = re.match(r'^NGC\s*(\d+)', cat_entry, re.IGNORECASE)
        if m:
            n = int(m.group(1))
            name = f"NGC {n}"
            h_desig = f"H {alt}" if alt else "H 400"
            h400_map[name] = h_desig

print(f"Total parsed Herschel 400 targets: {len(h400_map)}")
matched_h400 = 0
for name in h400_map:
    cur.execute("SELECT id FROM dso_objects WHERE name = ?", (name,))
    if cur.fetchone():
        matched_h400 += 1
print(f"Matched Herschel 400 in OpenNGC DB: {matched_h400} / {len(h400_map)}")
