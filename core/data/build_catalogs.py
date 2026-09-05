#!/usr/bin/env python3
"""
Catalog Builder for Astro Targets Planner
Downloads OpenNGC and addendum CSV files and compiles them into an indexed, FTS5-enabled SQLite database.
"""

import os
import sys
import urllib.request
import sqlite3
import re

OPENNGC_URL = "https://raw.githubusercontent.com/mattiaverga/OpenNGC/master/database_files/NGC.csv"
ADDENDUM_URL = "https://raw.githubusercontent.com/mattiaverga/OpenNGC/master/database_files/addendum.csv"

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

def map_type(t):
    if not t:
        return "Other"
    t = t.strip()
    if t in ("G", "GCl", "GTrGr", "SCG"):
        return "Galaxy"
    if t in ("PN", "pA"):
        return "Planetary Nebula"
    if t in ("EmN", "RefN", "HII", "Cl+N", "Neb"):
        return "Bright Nebula"
    if t in ("DrkN",):
        return "Dark Nebula"
    if t in ("OC", "OCl"):
        return "Open Cluster"
    if t in ("GC", "GCl"):
        return "Globular Cluster"
    if t in ("SNR",):
        return "Supernova Remnant"
    if t in ("Ast", "*", "**", "***"):
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

def main():
    print("Fetching OpenNGC datasets...")
    req_ngc = urllib.request.Request(OPENNGC_URL, headers={'User-Agent': 'Mozilla/5.0'})
    ngc_csv = urllib.request.urlopen(req_ngc).read().decode('utf-8', errors='replace')
    print(f"  Downloaded NGC.csv: {len(ngc_csv)} bytes")

    req_add = urllib.request.Request(ADDENDUM_URL, headers={'User-Agent': 'Mozilla/5.0'})
    add_csv = urllib.request.urlopen(req_add).read().decode('utf-8', errors='replace')
    print(f"  Downloaded addendum.csv: {len(add_csv)} bytes")

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
        surface_brightness REAL,
        common_names TEXT,
        identifiers TEXT
    );
    """)

    cur.execute("CREATE INDEX idx_dso_catalog ON dso_objects(catalog);")
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
        status TEXT DEFAULT 'planned', -- 'planned', 'captured', 'skipped'
        added_at INTEGER NOT NULL,
        PRIMARY KEY (list_id, dso_id),
        FOREIGN KEY (list_id) REFERENCES user_lists(id) ON DELETE CASCADE,
        FOREIGN KEY (dso_id) REFERENCES dso_objects(id)
    );
    """)

    all_lines = []
    # Parse NGC
    ngc_lines = ngc_csv.strip().split('\n')
    header = [h.strip() for h in ngc_lines[0].split(';')]
    col_idx = {h: i for i, h in enumerate(header)}

    for line in ngc_lines[1:]:
        if line.strip():
            all_lines.append(line.split(';'))

    # Parse addendum
    add_lines = add_csv.strip().split('\n')
    for line in add_lines[1:]:
        if line.strip():
            all_lines.append(line.split(';'))

    inserted_count = 0
    records = []

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

        records.append((
            formatted_name,
            messier,
            caldwell,
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
            surf_br,
            common_names,
            identifiers
        ))

    cur.executemany("""
    INSERT INTO dso_objects (
        name, messier, caldwell, ngc_ic, catalog, catalog_number,
        object_type, constellation, ra_deg, dec_deg,
        magnitude, b_mag, major_axis_arcmin, minor_axis_arcmin,
        surface_brightness, common_names, identifiers
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """, records)

    # Populate FTS
    cur.execute("""
    INSERT INTO dso_fts (rowid, name, messier, caldwell, common_names, identifiers)
    SELECT id, name, messier, caldwell, common_names, identifiers FROM dso_objects;
    """)

    conn.commit()

    cur.execute("SELECT count(*) FROM dso_objects;")
    total_objects = cur.fetchone()[0]

    cur.execute("SELECT count(*) FROM dso_objects WHERE messier IS NOT NULL;")
    total_messier = cur.fetchone()[0]

    cur.execute("SELECT count(*) FROM dso_objects WHERE caldwell IS NOT NULL;")
    total_caldwell = cur.fetchone()[0]

    cur.execute("VACUUM;")
    conn.close()

    db_size_mb = os.path.getsize(OUTPUT_DB) / (1024 * 1024)
    print("Database build complete!")
    print(f"  Total DSO objects: {total_objects}")
    print(f"  Messier objects:   {total_messier}")
    print(f"  Caldwell objects:  {total_caldwell}")
    print(f"  SQLite DB path:    {OUTPUT_DB}")
    print(f"  SQLite DB size:    {db_size_mb:.2f} MB")

if __name__ == "__main__":
    main()
