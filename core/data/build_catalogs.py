#!/usr/bin/env python3
"""
Catalog Builder for Astro Targets Planner
Downloads OpenNGC, addendum, Arp (Atlas of Peculiar Galaxies, VizieR VII/192),
and Herschel 400 datasets and compiles them into an indexed, FTS5-enabled SQLite database.
"""

import os
import sys
import urllib.request
import sqlite3
import re

OPENNGC_URL = "https://raw.githubusercontent.com/mattiaverga/OpenNGC/master/database_files/NGC.csv"
ADDENDUM_URL = "https://raw.githubusercontent.com/mattiaverga/OpenNGC/master/database_files/addendum.csv"
ARPORD_URL = "https://vizier.cds.unistra.fr/viz-bin/asu-tsv?-source=VII/192/arpord&-out.max=1000"
ARPLIST_URL = "https://vizier.cds.unistra.fr/viz-bin/asu-tsv?-source=VII/192/arplist&-out.max=1000"
H400_URL = "https://raw.githubusercontent.com/maphilli14/NINACatalogs/main/Herschel400_NINA_SingleEntry.csv"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DB = os.path.join(SCRIPT_DIR, "catalogs.db")

def parse_ra(ra_str):
    if not ra_str or not ra_str.strip():
        return None
    try:
        parts = ra_str.strip().split(':')
        h = float(parts[0])
        m = float(parts[1]) if len(parts) > 1 else 0.0
        s = float(parts[2]) if len(parts) > 2 else 0.0
        hours = h + m / 60.0 + s / 3600.0
        return hours * 15.0 # return degrees
    except Exception:
        return None

def parse_dec(dec_str):
    if not dec_str or not dec_str.strip():
        return None
    try:
        s = dec_str.strip()
        sign = -1.0 if s.startswith('-') else 1.0
        s = s.lstrip('+-')
        parts = s.split(':')
        d = float(parts[0])
        m = float(parts[1]) if len(parts) > 1 else 0.0
        sec = float(parts[2]) if len(parts) > 2 else 0.0
        return sign * (d + m / 60.0 + sec / 3600.0)
    except Exception:
        return None

def parse_tsv_ra(ra_str):
    if not ra_str or not ra_str.strip():
        return None
    try:
        parts = ra_str.strip().split()
        h = float(parts[0])
        m = float(parts[1]) if len(parts) > 1 else 0.0
        s = float(parts[2]) if len(parts) > 2 else 0.0
        return (h + m / 60.0 + s / 3600.0) * 15.0
    except Exception:
        return None

def parse_tsv_dec(dec_str):
    if not dec_str or not dec_str.strip():
        return None
    try:
        s = dec_str.strip()
        sign = -1.0 if s.startswith('-') else 1.0
        s = s.lstrip('+-')
        parts = s.split()
        d = float(parts[0])
        m = float(parts[1]) if len(parts) > 1 else 0.0
        sec = float(parts[2]) if len(parts) > 2 else 0.0
        return sign * (d + m / 60.0 + sec / 3600.0)
    except Exception:
        return None

def map_type(t):
    if not t:
        return "Other"
    t = t.strip()

    # Globular Clusters: GCl (OpenNGC Globular Cluster), GC
    if t in ("GCl", "GC"):
        return "Globular Cluster"

    # Open Clusters: OCl (OpenNGC Open Cluster), OC, *Ass (Stellar Association)
    if t in ("OCl", "OC", "*Ass"):
        return "Open Cluster"

    # Galaxies: G (Galaxy), GPair (Galaxy Pair), GTrpl (Galaxy Triplet), GGroup (Galaxy Group), GTrGr, SCG
    if t in ("G", "GPair", "GTrpl", "GGroup", "GTrGr", "SCG"):
        return "Galaxy"

    # Planetary Nebulae: PN, pA
    if t in ("PN", "pA"):
        return "Planetary Nebula"

    # Bright Nebulae: HII (HII Region), Neb (Nebula), EmN (Emission Nebula), RfN (Reflection Nebula), RefN, Cl+N (Cluster + Nebulosity)
    if t in ("EmN", "RfN", "RefN", "HII", "Cl+N", "Neb"):
        return "Bright Nebula"

    # Dark Nebulae: DrkN, DN
    if t in ("DrkN", "DN"):
        return "Dark Nebula"

    # Supernova Remnants: SNR
    if t in ("SNR",):
        return "Supernova Remnant"

    # Stars and Asterisms: *, **, ***, Ast, Nova
    if t in ("*", "**", "***", "Ast", "Nova"):
        return "Star / Asterism"

    return "Other"

def format_primary_name(name):
    name = name.strip()
    # Format NGC0224 -> NGC 224, IC0001 -> IC 1, M031 -> M 31, B033 -> B 33
    m = re.match(r'^(NGC|IC|M|B|C)(\d+)(.*)$', name, re.IGNORECASE)
    if m:
        prefix = m.group(1).upper()
        num = str(int(m.group(2))) # strip leading zeros
        suffix = m.group(3).strip()
        return f"{prefix} {num}{suffix}"
    return name

def fetch_arp_data():
    print("Fetching Arp (Atlas of Peculiar Galaxies) dataset from CDS VizieR (VII/192)...")
    try:
        req_ord = urllib.request.Request(ARPORD_URL, headers={'User-Agent': 'AstroTargetsPlanner/1.0'})
        arpord_txt = urllib.request.urlopen(req_ord).read().decode('utf-8', errors='replace')

        req_list = urllib.request.Request(ARPLIST_URL, headers={'User-Agent': 'AstroTargetsPlanner/1.0'})
        arplist_txt = urllib.request.urlopen(req_list).read().decode('utf-8', errors='replace')
    except Exception as e:
        print(f"  Warning: failed to download Arp data: {e}")
        return {}, {}

    arp_map = {} # ngc/m key -> arp string (e.g. "NGC 2857" -> "Arp 1")
    arp_views = {} # arp_num -> dict of details

    for line in arpord_txt.splitlines():
        if line.startswith('#') or not line.strip() or line.startswith('Arp\t') or line.startswith('---'):
            continue
        parts = line.split('\t')
        if len(parts) >= 5:
            num_str = parts[0].strip()
            name_str = parts[1].strip()
            if num_str.isdigit():
                num = int(num_str)
                ra_deg = parse_tsv_ra(parts[2].strip())
                dec_deg = parse_tsv_dec(parts[3].strip())
                size_str = parts[4].strip()
                size = float(size_str) if size_str else None

                arp_views[num] = {
                    "num": num,
                    "raw_name": name_str,
                    "ra_deg": ra_deg,
                    "dec_deg": dec_deg,
                    "size": size
                }

                m = re.match(r'^(NGC|IC|MESSIER|M)\s*(\d+)', name_str, re.IGNORECASE)
                if m:
                    p = m.group(1).upper()
                    n = int(m.group(2))
                    k = f"M {n}" if p.startswith("M") else f"{p} {n}"
                    arp_map[k] = f"Arp {num}"

    for line in arplist_txt.splitlines():
        if line.startswith('#') or not line.strip() or line.startswith('Arp\t') or line.startswith('---'):
            continue
        parts = line.split('\t')
        if len(parts) >= 2:
            num_str = parts[0].strip()
            name_str = parts[1].strip()
            if num_str.isdigit():
                num = int(num_str)
                m = re.match(r'^(NGC|IC|MESSIER|M)\s*(\d+)', name_str, re.IGNORECASE)
                if m:
                    p = m.group(1).upper()
                    n = int(m.group(2))
                    k = f"M {n}" if p.startswith("M") else f"{p} {n}"
                    if k not in arp_map:
                        arp_map[k] = f"Arp {num}"

    print(f"  Parsed {len(arp_map)} Arp cross-identifications across {len(arp_views)} views.")
    return arp_map, arp_views

def fetch_herschel_data():
    print("Fetching Herschel 400 catalog...")
    try:
        req = urllib.request.Request(H400_URL, headers={'User-Agent': 'Mozilla/5.0'})
        h400_txt = urllib.request.urlopen(req).read().decode('utf-8')
    except Exception as e:
        print(f"  Warning: failed to download Herschel 400 data: {e}")
        return {}

    h400_map = {}
    for line in h400_txt.splitlines()[1:]:
        parts = line.split(',')
        if len(parts) >= 3:
            cat_entry = parts[0].strip()
            alt = parts[2].strip()
            m = re.match(r'^NGC\s*(\d+)', cat_entry, re.IGNORECASE)
            if m:
                n = int(m.group(1))
                k = f"NGC {n}"
                desig = f"H {alt}" if alt else "Herschel 400"
                h400_map[k] = desig

    print(f"  Parsed {len(h400_map)} Herschel 400 objects.")
    return h400_map

def main():
    print("Fetching OpenNGC datasets...")
    req_ngc = urllib.request.Request(OPENNGC_URL, headers={'User-Agent': 'Mozilla/5.0'})
    ngc_csv = urllib.request.urlopen(req_ngc).read().decode('utf-8', errors='replace')
    print(f"  Downloaded NGC.csv: {len(ngc_csv)} bytes")

    req_add = urllib.request.Request(ADDENDUM_URL, headers={'User-Agent': 'Mozilla/5.0'})
    add_csv = urllib.request.urlopen(req_add).read().decode('utf-8', errors='replace')
    print(f"  Downloaded addendum.csv: {len(add_csv)} bytes")

    arp_map, arp_views = fetch_arp_data()
    h400_map = fetch_herschel_data()

    if os.path.exists(OUTPUT_DB):
        os.remove(OUTPUT_DB)

    conn = sqlite3.connect(OUTPUT_DB)
    cur = conn.cursor()

    # Create tables
    cur.execute("""
    CREATE TABLE dso_objects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        messier TEXT,
        caldwell TEXT,
        arp TEXT,
        herschel TEXT,
        ngc_ic TEXT,
        catalog TEXT NOT NULL,
        catalog_number TEXT,
        object_type TEXT NOT NULL,
        constellation TEXT,
        ra_deg REAL NOT NULL,
        dec_deg REAL NOT NULL,
        magnitude REAL,
        b_mag REAL,
        major_axis_arcmin REAL,
        minor_axis_arcmin REAL,
        position_angle_deg REAL,
        surface_brightness REAL,
        common_names TEXT,
        identifiers TEXT
    );
    """)

    cur.execute("CREATE INDEX idx_dso_catalog ON dso_objects(catalog);")
    cur.execute("CREATE INDEX idx_dso_arp ON dso_objects(arp);")
    cur.execute("CREATE INDEX idx_dso_herschel ON dso_objects(herschel);")
    cur.execute("CREATE INDEX idx_dso_type ON dso_objects(object_type);")
    cur.execute("CREATE INDEX idx_dso_coords ON dso_objects(ra_deg, dec_deg);")
    cur.execute("CREATE INDEX idx_dso_mag ON dso_objects(magnitude);")
    cur.execute("CREATE INDEX idx_dso_size ON dso_objects(major_axis_arcmin);")
    cur.execute("CREATE INDEX idx_dso_const ON dso_objects(constellation);")

    # FTS5 search index
    cur.execute("""
    CREATE VIRTUAL TABLE dso_fts USING fts5(
        name,
        messier,
        caldwell,
        arp,
        herschel,
        ngc_ic,
        common_names,
        identifiers,
        content='dso_objects',
        content_rowid='id'
    );
    """)

    # User observing lists table
    cur.execute("""
    CREATE TABLE user_lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        session_date TEXT, -- YYYY-MM-DD
        created_at INTEGER NOT NULL
    );
    """)

    cur.execute("""
    CREATE TABLE user_list_items (
        list_id INTEGER NOT NULL,
        dso_id INTEGER NOT NULL,
        notes TEXT,
        status TEXT DEFAULT 'planned',
        added_at INTEGER NOT NULL,
        PRIMARY KEY (list_id, dso_id),
        FOREIGN KEY (list_id) REFERENCES user_lists(id) ON DELETE CASCADE,
        FOREIGN KEY (dso_id) REFERENCES dso_objects(id)
    );
    """)

    all_lines = []
    ngc_lines = ngc_csv.strip().split('\n')
    header = [h.strip() for h in ngc_lines[0].split(';')]
    col_idx = {h: i for i, h in enumerate(header)}

    for line in ngc_lines[1:]:
        if line.strip():
            all_lines.append(line.split(';'))

    add_lines = add_csv.strip().split('\n')
    for line in add_lines[1:]:
        if line.strip():
            all_lines.append(line.split(';'))

    records = []
    mapped_arp_numbers = set()

    for parts in all_lines:
        def get_val(col):
            i = col_idx.get(col)
            if i is not None and i < len(parts):
                v = parts[i].strip()
                return v if v else None
            return None

        raw_name = get_val("Name")
        if not raw_name:
            continue

        ra_deg = parse_ra(get_val("RA"))
        dec_deg = parse_dec(get_val("Dec"))
        if ra_deg is None or dec_deg is None:
            continue

        raw_type = get_val("Type")
        obj_type = map_type(raw_type)

        v_mag_str = get_val("V-Mag")
        b_mag_str = get_val("B-Mag")
        v_mag = float(v_mag_str) if v_mag_str else None
        b_mag = float(b_mag_str) if b_mag_str else None
        mag = v_mag if v_mag is not None else b_mag

        maj_str = get_val("MajAx")
        min_str = get_val("MinAx")
        maj_ax = float(maj_str) if maj_str else None
        min_ax = float(min_str) if min_str else None

        pos_ang_str = get_val("PosAng")
        pos_ang = float(pos_ang_str) if pos_ang_str else None

        sb_str = get_val("SurfBr")
        surf_br = float(sb_str) if sb_str else None

        constellation = get_val("Const")
        common_names = get_val("Common names")
        identifiers = get_val("Identifiers")
        m_str = get_val("M")

        messier = None
        if m_str:
            m_match = re.match(r'M?(\d+)', m_str)
            if m_match:
                messier = f"M {int(m_match.group(1))}"

        caldwell = None
        if identifiers:
            c_match = re.search(r'\b(C|Caldwell)\s*(\d+)\b', identifiers, re.IGNORECASE)
            if c_match:
                caldwell = f"C {int(c_match.group(2))}"

        formatted_name = format_primary_name(raw_name)

        # Arp cross-reference
        arp = None
        if formatted_name in arp_map:
            arp = arp_map[formatted_name]
        elif messier and messier in arp_map:
            arp = arp_map[messier]

        if arp:
            num = int(arp.split()[1])
            mapped_arp_numbers.add(num)
            identifiers = f"{identifiers},{arp}" if identifiers else arp

        # Herschel 400 cross-reference
        herschel = None
        if formatted_name in h400_map:
            herschel = h400_map[formatted_name]
            h_str = f"Herschel 400,{herschel}"
            identifiers = f"{identifiers},{h_str}" if identifiers else h_str

        # Primary catalog
        catalog = "NGC"
        catalog_number = ""
        if raw_name.upper().startswith("NGC"):
            catalog = "NGC"
            num_m = re.search(r'\d+', raw_name)
            if num_m: catalog_number = str(int(num_m.group(0)))
        elif raw_name.upper().startswith("IC"):
            catalog = "IC"
            num_m = re.search(r'\d+', raw_name)
            if num_m: catalog_number = str(int(num_m.group(0)))
        elif raw_name.upper().startswith("B"):
            catalog = "Barnard"
            num_m = re.search(r'\d+', raw_name)
            if num_m: catalog_number = str(int(num_m.group(0)))
        elif raw_name.upper().startswith("SH2"):
            catalog = "Sharpless"
            num_m = re.search(r'\d+', raw_name)
            if num_m: catalog_number = str(int(num_m.group(0)))
        elif raw_name.upper().startswith("M"):
            catalog = "Messier"
            num_m = re.search(r'\d+', raw_name)
            if num_m: catalog_number = str(int(num_m.group(0)))
        else:
            catalog = "Other"

        # Add alias identifiers so both spaced and unspaced forms match (e.g. M 42 and M42)
        aliases = []
        if messier:
            aliases.append(messier.replace(" ", ""))
        if caldwell:
            aliases.append(caldwell.replace(" ", ""))
        if arp:
            aliases.append(arp.replace(" ", ""))
        if herschel:
            aliases.append(herschel.replace(" ", ""))
        if formatted_name:
            aliases.append(formatted_name.replace(" ", ""))
        if raw_name and raw_name != formatted_name:
            aliases.append(raw_name)

        if aliases:
            alias_str = ",".join(aliases)
            identifiers = f"{identifiers},{alias_str}" if identifiers else alias_str

        records.append((
            formatted_name,
            messier,
            caldwell,
            arp,
            herschel,
            raw_name,
            catalog,
            catalog_number,
            obj_type,
            constellation,
            ra_deg,
            dec_deg,
            mag,
            b_mag,
            maj_ax,
            min_ax,
            pos_ang,
            surf_br,
            common_names,
            identifiers
        ))

    # Insert standalone Arp views that were not covered by OpenNGC
    standalone_arp_count = 0
    for num, view in arp_views.items():
        if num not in mapped_arp_numbers and view["ra_deg"] is not None and view["dec_deg"] is not None:
            arp_label = f"Arp {num}"
            raw_n = view["raw_name"]
            arp_alias = f"Arp{num}"
            arp_ident = f"{arp_label},{raw_n},{arp_alias}" if raw_n else f"{arp_label},{arp_alias}"
            records.append((
                arp_label,
                None,             # messier
                None,             # caldwell
                arp_label,        # arp
                None,             # herschel
                arp_label,        # ngc_ic
                "Arp",            # catalog
                str(num),         # catalog_number
                "Galaxy",         # object_type
                None,             # constellation
                view["ra_deg"],
                view["dec_deg"],
                None,             # magnitude
                None,             # b_mag
                view["size"],     # major_axis_arcmin
                None,             # minor_axis_arcmin
                None,             # position_angle_deg
                None,             # surface_brightness
                raw_n if raw_n else None, # common_names
                arp_ident         # identifiers
            ))
            standalone_arp_count += 1
            mapped_arp_numbers.add(num)

    print(f"  Appended {standalone_arp_count} standalone Arp objects.")

    cur.executemany("""
    INSERT INTO dso_objects (
        name, messier, caldwell, arp, herschel, ngc_ic, catalog, catalog_number,
        object_type, constellation, ra_deg, dec_deg,
        magnitude, b_mag, major_axis_arcmin, minor_axis_arcmin, position_angle_deg,
        surface_brightness, common_names, identifiers
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """, records)

    # Populate FTS
    cur.execute("""
    INSERT INTO dso_fts (rowid, name, messier, caldwell, arp, herschel, ngc_ic, common_names, identifiers)
    SELECT id, name, messier, caldwell, arp, herschel, ngc_ic, common_names, identifiers FROM dso_objects;
    """)

    conn.commit()

    # Seed Solar System Planets and Bright Stars
    try:
        from seed_planets_and_stars import seed as seed_solar_and_stars
        seed_solar_and_stars()
    except Exception as e:
        print(f"Warning: could not seed planets and stars: {e}")

    cur.execute("SELECT count(*) FROM dso_objects;")
    total_objects = cur.fetchone()[0]

    cur.execute("SELECT count(*) FROM dso_objects WHERE messier IS NOT NULL;")
    total_messier = cur.fetchone()[0]

    cur.execute("SELECT count(*) FROM dso_objects WHERE caldwell IS NOT NULL;")
    total_caldwell = cur.fetchone()[0]

    cur.execute("SELECT count(*) FROM dso_objects WHERE arp IS NOT NULL;")
    total_arp = cur.fetchone()[0]

    cur.execute("SELECT count(*) FROM dso_objects WHERE herschel IS NOT NULL;")
    total_herschel = cur.fetchone()[0]

    cur.execute("VACUUM;")
    conn.close()


    db_size_mb = os.path.getsize(OUTPUT_DB) / (1024 * 1024)
    print("Database build complete!")
    print(f"  Total DSO objects:  {total_objects}")
    print(f"  Messier objects:    {total_messier}")
    print(f"  Caldwell objects:   {total_caldwell}")
    print(f"  Arp objects:        {total_arp}")
    print(f"  Herschel objects:   {total_herschel}")
    print(f"  SQLite DB path:     {OUTPUT_DB}")
    print(f"  SQLite DB size:     {db_size_mb:.2f} MB")

if __name__ == "__main__":
    main()
