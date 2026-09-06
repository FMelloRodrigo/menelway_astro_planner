import sqlite3

conn = sqlite3.connect('core/data/catalogs.db')
cur = conn.cursor()

cur.execute("SELECT count(*) FROM dso_objects WHERE identifiers LIKE '%Arp%' OR common_names LIKE '%Arp%'")
print('Arp matches in current DB:', cur.fetchone()[0])

cur.execute("SELECT name, identifiers, common_names FROM dso_objects WHERE identifiers LIKE '%Arp%' LIMIT 5")
for row in cur.fetchall():
    print('  Sample Arp:', row)

cur.execute("SELECT count(*) FROM dso_objects WHERE identifiers LIKE '%Herschel%' OR common_names LIKE '%Herschel%'")
print('Herschel text matches:', cur.fetchone()[0])

cur.execute("SELECT name, identifiers, common_names FROM dso_objects WHERE identifiers LIKE '%H %' OR identifiers LIKE '%H.IV%' LIMIT 5")
for row in cur.fetchall():
    print('  Sample H:', row)
