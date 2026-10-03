import sqlite3
import os
import unittest

class TestCatalogsQuery(unittest.TestCase):
    def setUp(self):
        db_path = 'app/assets/catalogs.db'
        if not os.path.exists(db_path):
            db_path = 'core/data/catalogs.db'
        self.skipTest_if_no_db = not os.path.exists(db_path)
        if self.skipTest_if_no_db:
            self.skipTest("catalogs.db not found")
        self.conn = sqlite3.connect(db_path)
        self.cur = self.conn.cursor()

    def tearDown(self):
        if hasattr(self, 'conn') and self.conn:
            self.conn.close()

    def test_arp_and_herschel_objects_exist(self):
        self.cur.execute("SELECT count(*) FROM dso_objects WHERE identifiers LIKE '%Arp%' OR common_names LIKE '%Arp%'")
        arp_count = self.cur.fetchone()[0]
        self.assertGreater(arp_count, 0, "Expected Arp objects in catalog")

        self.cur.execute("SELECT count(*) FROM dso_objects WHERE identifiers LIKE '%Herschel%' OR common_names LIKE '%Herschel%'")
        herschel_count = self.cur.fetchone()[0]
        self.assertGreater(herschel_count, 0, "Expected Herschel objects in catalog")

if __name__ == "__main__":
    unittest.main()
