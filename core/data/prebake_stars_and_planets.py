import sqlite3
import urllib.request
import urllib.parse
import json
import time
import os
import concurrent.futures

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(SCRIPT_DIR, "catalogs.db")

HEADERS = {
    'User-Agent': 'AstroTargetsTool/1.0 (Astrophotography Planner; mailto:info@astrotargets.app)'
}

# Special overrides where simple name search might hit disambiguation or non-star/planet articles
SPECIAL_CANDIDATES = {
    'Castor': ['Castor (star)', 'Alpha Geminorum'],
    'Pollux': ['Pollux (star)', 'Beta Geminorum'],
    'Peacock': ['Alpha Pavonis', 'Peacock (star)'],
    'Mimosa': ['Beta Crucis', 'Mimosa (star)', 'Becrux'],
    'Alcyone': ['Alcyone (star)', 'Eta Tauri'],
    'Navi': ['Gamma Cassiopeiae'],
    'Rigil Kentaurus': ['Alpha Centauri', 'Rigil Kentaurus', 'Toliman'],
    'Etamin': ['Eltanin', 'Gamma Draconis'],
    'Mercury': ['Mercury (planet)'],
    'Mars': ['Mars'],
    'Moon': ['Moon'],
    'Sun': ['Sun'],
    'Pluto': ['Pluto'],
    'Uranus': ['Uranus'],
    'Neptune': ['Neptune'],
    'Jupiter': ['Jupiter'],
    'Saturn': ['Saturn'],
    'Venus': ['Venus'],
}

def fetch_wiki_summary(title):
    """Fetches Wikipedia page summary JSON for a given article title."""
    if not title: return None
    clean_title = title.strip().replace(' ', '_')
    encoded_title = urllib.parse.quote(clean_title)
    url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{encoded_title}"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode('utf-8'))
                if data.get('type') == 'disambiguation':
                    return None
                extract = data.get('extract', '').strip()
                if extract:
                    page_url = data.get('content_urls', {}).get('desktop', {}).get('page', f"https://en.wikipedia.org/wiki/{encoded_title}")
                    thumb_url = data.get('thumbnail', {}).get('source', '')
                    return {
                        'title': data.get('title', title),
                        'description': data.get('description', ''),
                        'extract': extract,
                        'thumbnail_url': thumb_url,
                        'page_url': page_url,
                        'source': 'Wikipedia',
                    }
    except Exception as e:
        pass
    return None

def main():
    print(f"Connecting to database: {DB_PATH}")
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute("""
    CREATE TABLE IF NOT EXISTS target_descriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        extract TEXT NOT NULL,
        thumbnail_url TEXT,
        page_url TEXT,
        source TEXT DEFAULT 'Wikipedia',
        created_at INTEGER
    );
    """)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS target_description_aliases (
        target_name TEXT PRIMARY KEY,
        description_id INTEGER NOT NULL,
        FOREIGN KEY (description_id) REFERENCES target_descriptions(id) ON DELETE CASCADE
    );
    """)
    cur.execute("CREATE INDEX IF NOT EXISTS idx_tda_name ON target_description_aliases(target_name COLLATE NOCASE);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_td_title ON target_descriptions(title COLLATE NOCASE);")
    conn.commit()

    # Query all Stars and Solar System bodies
    cur.execute("SELECT id, name, catalog_number, constellation, common_names, identifiers FROM dso_objects WHERE catalog in ('Stars', 'Solar System') ORDER BY id")
    items = cur.fetchall()
    print(f"Found {len(items)} stars and solar system objects to process.")

    targets_to_fetch = []
    for row in items:
        obj_id, name, cat_num, constel, common_names, identifiers = row
        keys = [name]
        if cat_num:
            keys.append(cat_num)
        if common_names:
            for cn in common_names.split(','):
                cn = cn.strip()
                if cn: keys.append(cn)
        if identifiers:
            for ident in identifiers.split(','):
                ident = ident.strip()
                if ident: keys.append(ident)

        candidates = []
        if name in SPECIAL_CANDIDATES:
            candidates.extend(SPECIAL_CANDIDATES[name])
        
        candidates.append(name)
        candidates.append(f"{name} (star)")
        if common_names:
            for cn in common_names.split(','):
                cn = cn.strip()
                if cn and cn not in candidates:
                    candidates.append(cn)
        if cat_num and cat_num not in candidates:
            candidates.append(cat_num)

        targets_to_fetch.append((name, keys, candidates))

    def process_item(item):
        name, keys, candidates = item
        for cand in candidates:
            res = fetch_wiki_summary(cand)
            if res:
                return (name, keys, res)
            time.sleep(0.05)
        return (name, keys, None)

    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        futures = {executor.submit(process_item, item): item for item in targets_to_fetch}
        for future in concurrent.futures.as_completed(futures):
            results.append(future.result())

    now = int(time.time())
    success_count = 0
    missing = []

    for name, keys, res in results:
        if not res:
            missing.append(name)
            continue

        success_count += 1
        cur.execute("SELECT id FROM target_descriptions WHERE title = ? COLLATE NOCASE LIMIT 1", (res['title'],))
        row = cur.fetchone()
        if row:
            desc_id = row[0]
            # Update extract if needed
            cur.execute("""
            UPDATE target_descriptions 
            SET description = ?, extract = ?, thumbnail_url = ?, page_url = ?
            WHERE id = ?
            """, (res['description'], res['extract'], res['thumbnail_url'], res['page_url'], desc_id))
        else:
            cur.execute("""
            INSERT INTO target_descriptions (title, description, extract, thumbnail_url, page_url, source, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (res['title'], res['description'], res['extract'], res['thumbnail_url'], res['page_url'], res['source'], now))
            desc_id = cur.lastrowid

        for k in keys:
            cur.execute("INSERT OR REPLACE INTO target_description_aliases (target_name, description_id) VALUES (?, ?)", (k, desc_id))
        cur.execute("INSERT OR REPLACE INTO target_description_aliases (target_name, description_id) VALUES (?, ?)", (name, desc_id))
        cur.execute("INSERT OR REPLACE INTO target_description_aliases (target_name, description_id) VALUES (?, ?)", (res['title'], desc_id))

    conn.commit()
    print(f"\nSuccessfully stored descriptions for {success_count} / {len(targets_to_fetch)} targets.")
    if missing:
        print(f"Failed to fetch descriptions for ({len(missing)}): {missing}")

    cur.execute("SELECT count(*) FROM target_descriptions")
    total_descs = cur.fetchone()[0]
    cur.execute("SELECT count(*) FROM target_description_aliases")
    total_aliases = cur.fetchone()[0]
    print(f"Total unique target descriptions in database: {total_descs}")
    print(f"Total alias mappings in database: {total_aliases}")

    conn.close()

if __name__ == '__main__':
    main()
