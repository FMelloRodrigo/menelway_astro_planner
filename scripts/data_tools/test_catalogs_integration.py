import sqlite3
import urllib.request
import re
import os

def run_integration_test():
    db_path = 'app/assets/catalogs.db'
    if not os.path.exists(db_path):
        db_path = 'core/data/catalogs.db'
    if not os.path.exists(db_path):
        print(f"Skipping integration test: database not found at {db_path}")
        return

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    # 1. Test Arp from VizieR
    print("Testing Arp dataset...")
    url_arpord = "https://cdsarc.cds.unistra.fr/ftp/VII/192/arpord.dat"
    req_ord = urllib.request.Request(url_arpord, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        arpord_txt = urllib.request.urlopen(req_ord, timeout=15).read().decode('ascii', errors='replace')
    except Exception as e:
        print(f"Network error accessing Arp dataset: {e}")
        return

    url_arplist = "https://cdsarc.cds.unistra.fr/ftp/VII/192/arplist.dat"
    req_list = urllib.request.Request(url_arplist, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        arplist_txt = urllib.request.urlopen(req_list, timeout=15).read().decode('ascii', errors='replace')
    except Exception as e:
        print(f"Network error accessing Arp list: {e}")
        return

    arp_map = {} # ngc_key -> arp_label e.g. "NGC 2857" -> "Arp 1"

    for line in arpord_txt.splitlines():
        if len(line) >= 21:
            arp_num = line[0:3].strip()
            name = line[4:21].strip()
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

    print(f"Built Arp map with {len(arp_map)} entries.")
    conn.close()

if __name__ == "__main__":
    run_integration_test()
