import sqlite3
import urllib.request
import urllib.parse
import json
import time
import os
import concurrent.futures

DB_PATH = os.path.join(os.path.dirname(__file__), 'catalogs.db')
HEADERS = {
    'User-Agent': 'AstroTargetsTool/1.0 (Astrophotography Planner; mailto:info@astrotargets.app)'
}

def fetch_wiki_summary(title):
    """Fetches Wikipedia page summary JSON for a given article title."""
    if not title: return None
    clean_title = title.strip().replace(' ', '_')
    encoded_title = urllib.parse.quote(clean_title)
    url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{encoded_title}"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=6) as resp:
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
    except Exception:
        pass
    return None

def main():
    print(f"Opening database: {DB_PATH}")
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

    targets_to_fetch = []

    # 1. Messier objects (1 to 110)
    for i in range(1, 111):
        cur.execute("SELECT name, messier, common_names FROM dso_objects WHERE messier = ? LIMIT 1", (f"M {i}",))
        row = cur.fetchone()
        keys = [f"M {i}", f"M{i}", f"Messier {i}"]
        candidates = [f"Messier {i}"]
        if row:
            name, messier, common = row
            if name:
                keys.append(name)
                candidates.append(name)
            if common:
                for c in common.split(','):
                    c = c.strip()
                    if c:
                        keys.append(c)
                        candidates.insert(0, c)
        targets_to_fetch.append((keys, candidates))

    # 2. Caldwell objects (1 to 109)
    for i in range(1, 110):
        cur.execute("SELECT name, caldwell, common_names FROM dso_objects WHERE caldwell = ? LIMIT 1", (f"C {i}",))
        row = cur.fetchone()
        keys = [f"C {i}", f"C{i}", f"Caldwell {i}"]
        candidates = []
        if row:
            name, caldwell, common = row
            if common:
                for c in common.split(','):
                    c = c.strip()
                    if c:
                        keys.append(c)
                        candidates.append(c)
            if name:
                keys.append(name)
                candidates.append(name)
        candidates.append(f"Caldwell {i}")
        targets_to_fetch.append((keys, candidates))

    # 3. Prominent Named objects in dso_objects
    cur.execute("SELECT name, common_names FROM dso_objects WHERE common_names IS NOT NULL AND length(common_names) > 0")
    for row in cur.fetchall():
        name, common = row
        keys = [name]
        candidates = []
        for c in common.split(','):
            c = c.strip()
            if c:
                keys.append(c)
                candidates.append(c)
        candidates.append(name)
        targets_to_fetch.append((keys, candidates))

    # 4. Solar system objects
    planets = ['Moon', 'Sun', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn', 'Uranus', 'Neptune']
    for p in planets:
        targets_to_fetch.append(([p], [f"{p} (astronomy)" if p in ['Sun', 'Moon'] else p, p]))

    # Deduplicate against already inserted aliases
    cur.execute("SELECT target_name FROM target_description_aliases")
    existing_aliases = set(r[0].lower() for r in cur.fetchall())

    needed = []
    for keys, candidates in targets_to_fetch:
        if not any(k.lower() in existing_aliases for k in keys):
            needed.append((keys, candidates))

    print(f"Total targets requiring fetch: {len(needed)}")

    def process_item(item):
        keys, candidates = item
        for cand in candidates:
            res = fetch_wiki_summary(cand)
            if res:
                return (keys, res)
            time.sleep(0.02)
        return (keys, None)

    saved_count = 0
    now = int(time.time())

    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        futures = {executor.submit(process_item, item): item for item in needed}
        for future in concurrent.futures.as_completed(futures):
            keys, res = future.result()
            if res:
                cur.execute("SELECT id FROM target_descriptions WHERE title = ? COLLATE NOCASE LIMIT 1", (res['title'],))
                row = cur.fetchone()
                if row:
                    desc_id = row[0]
                else:
                    cur.execute("""
                    INSERT INTO target_descriptions (title, description, extract, thumbnail_url, page_url, source, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, (res['title'], res['description'], res['extract'], res['thumbnail_url'], res['page_url'], res['source'], now))
                    desc_id = cur.lastrowid
                    saved_count += 1

                for k in keys:
                    cur.execute("INSERT OR REPLACE INTO target_description_aliases (target_name, description_id) VALUES (?, ?)", (k, desc_id))
                cur.execute("INSERT OR REPLACE INTO target_description_aliases (target_name, description_id) VALUES (?, ?)", (res['title'], desc_id))

            if saved_count > 0 and saved_count % 20 == 0:
                conn.commit()

    conn.commit()

    cur.execute("SELECT count(*) FROM target_descriptions")
    total_descs = cur.fetchone()[0]
    cur.execute("SELECT count(*) FROM target_description_aliases")
    total_aliases = cur.fetchone()[0]

    print(f"Pre-baking complete! Total unique descriptions: {total_descs}, total alias lookups: {total_aliases}")
    conn.close()

if __name__ == '__main__':
    main()
