#!/usr/bin/env python3
import os
import sqlite3

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(SCRIPT_DIR, "catalogs.db")

PLANETS_DATA = [
    # (id, name, catalog_number, obj_type, const, ra_deg, dec_deg, mag, maj_ax, common_names, identifiers)
    (90001, "Mercury", "1", "Planet", None, 0.0, 0.0, -0.4, 0.15, "Hermes", "Mercury,Planet"),
    (90002, "Venus", "2", "Planet", None, 0.0, 0.0, -4.4, 0.5, "Evening Star,Morning Star,Aphrodite", "Venus,Planet"),
    (90003, "Mars", "3", "Planet", None, 0.0, 0.0, -1.5, 0.25, "Red Planet,Ares", "Mars,Planet"),
    (90004, "Jupiter", "4", "Planet", None, 0.0, 0.0, -2.5, 0.75, "Gas Giant,Zeus,King of Planets", "Jupiter,Planet"),
    (90005, "Saturn", "5", "Planet", None, 0.0, 0.0, 0.5, 0.65, "Ringed Planet,Cronus", "Saturn,Planet"),
    (90006, "Uranus", "6", "Planet", None, 0.0, 0.0, 5.7, 0.06, "Ice Giant,Caelus", "Uranus,Planet"),
    (90007, "Neptune", "7", "Planet", None, 0.0, 0.0, 7.8, 0.04, "Ice Giant,Poseidon", "Neptune,Planet"),
    (90008, "Moon", "8", "Planet", None, 0.0, 0.0, -12.7, 31.2, "Luna,Selene", "Moon,Luna,Satellite"),
    (90009, "Sun", "9", "Star", None, 0.0, 0.0, -26.7, 32.0, "Sol,Helios", "Sun,Sol,Star"),
    (90010, "Pluto", "10", "Planet", None, 0.0, 0.0, 14.5, 0.005, "Dwarf Planet,Hades", "Pluto,Planet,Dwarf Planet"),
]

BRIGHT_STARS_DATA = [
    # (id, name, catalog_number, obj_type, const, ra_deg, dec_deg, mag, b_mag, common_names, identifiers)
    (91001, "Sirius", "Alpha CMa", "Star", "CMa", 101.287, -16.716, -1.46, -1.46, "Dog Star,Alpha Canis Majoris", "Sirius,Alpha CMa,HR 2491,HD 48915"),
    (91002, "Canopus", "Alpha Car", "Star", "Car", 95.988, -52.696, -0.74, -0.59, "Alpha Carinae", "Canopus,Alpha Car,HR 2326,HD 45348"),
    (91003, "Rigil Kentaurus", "Alpha Cen", "Star", "Cen", 219.902, -60.834, -0.27, 0.44, "Alpha Centauri,Toliman", "Rigil Kentaurus,Alpha Cen,HR 5459,HD 128620"),
    (91004, "Arcturus", "Alpha Boo", "Star", "Boo", 213.915, 19.182, -0.05, 1.18, "Alpha Boötis", "Arcturus,Alpha Boo,HR 5340,HD 124897"),
    (91005, "Vega", "Alpha Lyr", "Star", "Lyr", 279.235, 38.784, 0.03, 0.03, "Alpha Lyrae,Summer Triangle", "Vega,Alpha Lyr,HR 7001,HD 172167"),
    (91006, "Capella", "Alpha Aur", "Star", "Aur", 79.172, 45.998, 0.08, 0.88, "Alpha Aurigae", "Capella,Alpha Aur,HR 1708,HD 34029"),
    (91007, "Rigel", "Beta Ori", "Star", "Ori", 78.634, -8.202, 0.13, 0.10, "Beta Orionis", "Rigel,Beta Ori,HR 1713,HD 34085"),
    (91008, "Procyon", "Alpha CMi", "Star", "CMi", 114.825, 5.225, 0.34, 0.76, "Alpha Canis Minoris", "Procyon,Alpha CMi,HR 2943,HD 61421"),
    (91009, "Achernar", "Alpha Eri", "Star", "Eri", 24.428, -57.237, 0.46, 0.30, "Alpha Eridani", "Achernar,Alpha Eri,HR 472,HD 10144"),
    (91010, "Betelgeuse", "Alpha Ori", "Star", "Ori", 88.793, 7.407, 0.50, 2.35, "Alpha Orionis,Winter Triangle", "Betelgeuse,Alpha Ori,HR 2061,HD 39801"),
    (91011, "Hadar", "Beta Cen", "Star", "Cen", 210.956, -60.373, 0.61, 0.38, "Beta Centauri,Agena", "Hadar,Beta Cen,HR 5267,HD 122451"),
    (91012, "Altair", "Alpha Aql", "Star", "Aql", 297.696, 8.868, 0.76, 0.98, "Alpha Aquilae,Summer Triangle", "Altair,Alpha Aql,HR 7557,HD 187642"),
    (91013, "Acrux", "Alpha Cru", "Star", "Cru", 186.649, -63.099, 0.76, 0.50, "Alpha Crucis,Southern Cross", "Acrux,Alpha Cru,HR 4730,HD 108248"),
    (91014, "Aldebaran", "Alpha Tau", "Star", "Tau", 68.980, 16.509, 0.86, 2.40, "Alpha Tauri,Eye of Taurus", "Aldebaran,Alpha Tau,HR 1457,HD 29139"),
    (91015, "Antares", "Alpha Sco", "Star", "Sco", 247.352, -26.432, 0.96, 2.79, "Alpha Scorpii,Heart of Scorpion", "Antares,Alpha Sco,HR 6134,HD 148478"),
    (91016, "Spica", "Alpha Vir", "Star", "Vir", 201.298, -11.161, 0.97, 0.74, "Alpha Virginis", "Spica,Alpha Vir,HR 5056,HD 116658"),
    (91017, "Pollux", "Beta Gem", "Star", "Gem", 116.329, 28.026, 1.14, 2.14, "Beta Geminorum", "Pollux,Beta Gem,HR 2990,HD 62509"),
    (91018, "Fomalhaut", "Alpha PsA", "Star", "PsA", 344.413, -29.622, 1.16, 1.25, "Alpha Piscis Austrini", "Fomalhaut,Alpha PsA,HR 8728,HD 216956"),
    (91019, "Deneb", "Alpha Cyg", "Star", "Cyg", 310.358, 45.280, 1.25, 1.34, "Alpha Cygni,Summer Triangle", "Deneb,Alpha Cyg,HR 7924,HD 197345"),
    (91020, "Mimosa", "Beta Cru", "Star", "Cru", 191.930, -59.689, 1.25, 1.02, "Beta Crucis,Becrux", "Mimosa,Becrux,Beta Cru,HR 4853,HD 111123"),
    (91021, "Regulus", "Alpha Leo", "Star", "Leo", 152.093, 11.967, 1.35, 1.24, "Alpha Leonis,Heart of Lion", "Regulus,Alpha Leo,HR 3982,HD 87901"),
    (91022, "Adhara", "Epsilon CMa", "Star", "CMa", 104.656, -28.972, 1.50, 1.29, "Epsilon Canis Majoris", "Adhara,Epsilon CMa,HR 2618,HD 52089"),
    (91023, "Castor", "Alpha Gem", "Double Star", "Gem", 113.650, 31.888, 1.58, 1.62, "Alpha Geminorum", "Castor,Alpha Gem,HR 2891,HD 60179"),
    (91024, "Gacrux", "Gamma Cru", "Star", "Cru", 187.792, -57.113, 1.63, 3.22, "Gamma Crucis", "Gacrux,Gamma Cru,HR 4763,HD 108903"),
    (91025, "Shaula", "Lambda Sco", "Star", "Sco", 263.402, -37.104, 1.63, 1.40, "Lambda Scorpii", "Shaula,Lambda Sco,HR 6527,HD 158926"),
    (91026, "Bellatrix", "Gamma Ori", "Star", "Ori", 81.283, 6.350, 1.64, 1.42, "Gamma Orionis,Amazon Star", "Bellatrix,Gamma Ori,HR 1790,HD 35468"),
    (91027, "Elnath", "Beta Tau", "Star", "Tau", 81.573, 28.608, 1.65, 1.52, "Beta Tauri", "Elnath,Beta Tau,HR 1791,HD 35497"),
    (91028, "Miaplacidus", "Beta Car", "Star", "Car", 138.300, -69.717, 1.68, 1.68, "Beta Carinae", "Miaplacidus,Beta Car,HR 3685,HD 80007"),
    (91029, "Alnilam", "Epsilon Ori", "Star", "Ori", 84.053, -1.202, 1.69, 1.50, "Epsilon Orionis,Orion's Belt", "Alnilam,Epsilon Ori,HR 1903,HD 37128"),
    (91030, "Alnitak", "Zeta Ori", "Star", "Ori", 85.190, -1.943, 1.77, 1.57, "Zeta Orionis,Orion's Belt", "Alnitak,Zeta Ori,HR 1948,HD 37742"),
    (91031, "Alioth", "Epsilon UMa", "Star", "UMa", 193.507, 55.960, 1.77, 1.75, "Epsilon Ursae Majoris,Big Dipper", "Alioth,Epsilon UMa,HR 4905,HD 112185"),
    (91032, "Dubhe", "Alpha UMa", "Star", "UMa", 165.932, 61.751, 1.79, 2.86, "Alpha Ursae Majoris,Big Dipper Pointer", "Dubhe,Alpha UMa,HR 4301,HD 95689"),
    (91033, "Mirfak", "Alpha Per", "Star", "Per", 51.081, 49.861, 1.80, 2.28, "Alpha Persei", "Mirfak,Alpha Per,HR 1017,HD 20902"),
    (91034, "Wezen", "Delta CMa", "Star", "CMa", 107.098, -26.393, 1.82, 2.48, "Delta Canis Majoris", "Wezen,Delta CMa,HR 2693,HD 54605"),
    (91035, "Sargas", "Theta Sco", "Star", "Sco", 264.330, -42.998, 1.87, 2.27, "Theta Scorpii", "Sargas,Theta Sco,HR 6553,HD 159532"),
    (91036, "Kaus Australis", "Epsilon Sgr", "Star", "Sgr", 276.043, -34.385, 1.85, 1.82, "Epsilon Sagittarii,Teapot", "Kaus Australis,Epsilon Sgr,HR 6879,HD 169022"),
    (91037, "Avior", "Epsilon Car", "Star", "Car", 125.628, -59.509, 1.86, 3.06, "Epsilon Carinae", "Avior,Epsilon Car,HR 3307,HD 71129"),
    (91038, "Alkaid", "Eta UMa", "Star", "UMa", 206.885, 49.313, 1.86, 1.67, "Eta Ursae Majoris,Big Dipper Tip", "Alkaid,Eta UMa,HR 5191,HD 120315"),
    (91039, "Menkalinan", "Beta Aur", "Star", "Aur", 89.882, 44.948, 1.90, 1.93, "Beta Aurigae", "Menkalinan,Beta Aur,HR 2088,HD 40183"),
    (91040, "Atria", "Alpha TrA", "Star", "TrA", 252.166, -69.028, 1.92, 3.36, "Alpha Trianguli Australis", "Atria,Alpha TrA,HR 6217,HD 150798"),
    (91041, "Alhena", "Gamma Gem", "Star", "Gem", 99.428, 16.399, 1.93, 1.93, "Gamma Geminorum", "Alhena,Gamma Gem,HR 2421,HD 47105"),
    (91042, "Peacock", "Alpha Pav", "Star", "Pav", 306.412, -56.735, 1.94, 1.74, "Alpha Pavonis", "Peacock,Alpha Pav,HR 7790,HD 193924"),
    (91043, "Polaris", "Alpha UMi", "Star", "UMi", 37.954, 89.264, 1.98, 2.58, "North Star,Pole Star,Alpha Ursae Minoris", "Polaris,Alpha UMi,HR 424,HD 8890"),
    (91044, "Mirzam", "Beta CMa", "Star", "CMa", 95.675, -17.956, 1.98, 1.75, "Beta Canis Majoris", "Mirzam,Beta CMa,HR 2294,HD 44743"),
    (91045, "Alphard", "Alpha Hya", "Star", "Hya", 141.897, -8.659, 1.98, 3.42, "Alpha Hydrae,Heart of Hydra", "Alphard,Alpha Hya,HR 3748,HD 81797"),
    (91046, "Hamal", "Alpha Ari", "Star", "Ari", 31.793, 23.463, 2.00, 3.15, "Alpha Arietis", "Hamal,Alpha Ari,HR 617,HD 12929"),
    (91047, "Algol", "Beta Per", "Star", "Per", 47.042, 40.956, 2.12, 2.07, "Demon Star,Beta Persei", "Algol,Beta Per,HR 936,HD 19356"),
    (91048, "Diphda", "Beta Cet", "Star", "Cet", 10.897, -17.987, 2.04, 3.06, "Beta Ceti,Deneb Kaitos", "Diphda,Deneb Kaitos,Beta Cet,HR 188,HD 4128"),
    (91049, "Nunki", "Sigma Sgr", "Star", "Sgr", 283.816, -26.297, 2.05, 1.83, "Sigma Sagittarii,Teapot Handle", "Nunki,Sigma Sgr,HR 7121,HD 175191"),
    (91050, "Menkent", "Theta Cen", "Star", "Cen", 211.671, -36.370, 2.06, 3.07, "Theta Centauri", "Menkent,Theta Cen,HR 5288,HD 123139"),
    (91051, "Mirach", "Beta And", "Star", "And", 17.433, 35.621, 2.06, 3.64, "Beta Andromedae,Guide to M31", "Mirach,Beta And,HR 337,HD 6860"),
    (91052, "Alpheratz", "Alpha And", "Star", "And", 2.097, 29.091, 2.06, 1.95, "Alpha Andromedae,Great Square of Pegasus", "Alpheratz,Alpha And,HR 15,HD 358"),
    (91053, "Saiph", "Kappa Ori", "Star", "Ori", 86.939, -9.670, 2.07, 1.89, "Kappa Orionis", "Saiph,Kappa Ori,HR 2004,HD 38771"),
    (91054, "Rasalhague", "Alpha Oph", "Star", "Oph", 263.734, 12.560, 2.08, 2.23, "Alpha Ophiuchi", "Rasalhague,Alpha Oph,HR 6556,HD 159561"),
    (91055, "Kochab", "Beta UMi", "Star", "UMi", 222.676, 74.156, 2.08, 3.55, "Beta Ursae Minoris,Guardian of Pole", "Kochab,Beta UMi,HR 5563,HD 131873"),
    (91056, "Almach", "Gamma And", "Double Star", "And", 30.975, 42.330, 2.10, 3.47, "Gamma Andromedae,Colorful Double", "Almach,Gamma And,HR 603,HD 12533"),
    (91057, "Denebola", "Beta Leo", "Star", "Leo", 177.265, 14.572, 2.14, 2.23, "Beta Leonis,Tail of Lion", "Denebola,Beta Leo,HR 4534,HD 102647"),
    (91058, "Schedar", "Alpha Cas", "Star", "Cas", 10.127, 56.537, 2.23, 3.40, "Alpha Cassiopeiae", "Schedar,Alpha Cas,HR 168,HD 3712"),
    (91059, "Caph", "Beta Cas", "Star", "Cas", 2.295, 59.150, 2.27, 2.61, "Beta Cassiopeiae", "Caph,Beta Cas,HR 21,HD 432"),
    (91060, "Mintaka", "Delta Ori", "Star", "Ori", 83.002, -0.299, 2.23, 2.05, "Delta Orionis,Orion's Belt", "Mintaka,Delta Ori,HR 1852,HD 36486"),
    (91061, "Enif", "Epsilon Peg", "Star", "Peg", 326.046, 9.875, 2.39, 3.92, "Epsilon Pegasi,Nose of Pegasus", "Enif,Epsilon Peg,HR 8308,HD 206778"),
    (91062, "Scheat", "Beta Peg", "Star", "Peg", 345.944, 28.083, 2.42, 4.09, "Beta Pegasi,Great Square", "Scheat,Beta Peg,HR 8775,HD 217906"),
    (91063, "Markab", "Alpha Peg", "Star", "Peg", 346.190, 15.205, 2.49, 2.45, "Alpha Pegasi,Great Square", "Markab,Alpha Peg,HR 8781,HD 218045"),
    (91064, "Alphecca", "Alpha CrB", "Star", "CrB", 233.672, 26.715, 2.23, 2.30, "Alpha Coronae Borealis,Gemma", "Alphecca,Gemma,Alpha CrB,HR 5793,HD 139006"),
    (91065, "Mizar", "Zeta UMa", "Double Star", "UMa", 200.981, 54.925, 2.23, 2.25, "Zeta Ursae Majoris,Mizar and Alcor", "Mizar,Zeta UMa,HR 5054,HD 116656"),
    (91066, "Albireo", "Beta Cyg", "Double Star", "Cyg", 292.680, 27.960, 3.08, 4.17, "Beta Cygni,Gold and Blue Double", "Albireo,Beta Cyg,HR 7417,HD 183912"),
    (91067, "Sadr", "Gamma Cyg", "Star", "Cyg", 305.557, 40.257, 2.23, 2.90, "Gamma Cygni,Chest of Swan", "Sadr,Gamma Cyg,HR 7796,HD 194093"),
    (91068, "Gienah", "Gamma Crv", "Star", "Crv", 183.952, -17.542, 2.59, 2.48, "Gamma Corvi", "Gienah,Gamma Crv,HR 4662,HD 106625"),
    (91069, "Algieba", "Gamma Leo", "Double Star", "Leo", 154.993, 19.842, 2.61, 3.75, "Gamma Leonis,Golden Double", "Algieba,Gamma Leo,HR 4057,HD 89484"),
    (91070, "Etamin", "Gamma Dra", "Star", "Dra", 269.152, 51.489, 2.23, 3.76, "Gamma Draconis,Head of Dragon", "Etamin,Gamma Dra,HR 6705,HD 164058"),
    (91071, "Alcyone", "Eta Tau", "Star", "Tau", 56.871, 24.105, 2.87, 2.81, "Eta Tauri,Central Pleiades", "Alcyone,Eta Tau,HR 1165,HD 23630"),
    (91072, "Sabik", "Eta Oph", "Star", "Oph", 257.595, -15.725, 2.43, 2.51, "Eta Ophiuchi", "Sabik,Eta Oph,HR 6378,HD 155125"),
    (91073, "Alderamin", "Alpha Cep", "Star", "Cep", 319.645, 62.586, 2.45, 2.68, "Alpha Cephei", "Alderamin,Alpha Cep,HR 8162,HD 203280"),
    (91074, "Navi", "Gamma Cas", "Star", "Cas", 14.177, 60.717, 2.47, 2.27, "Gamma Cassiopeiae,Central 'W'", "Navi,Gamma Cas,HR 264,HD 5394"),
    (91075, "Alsephina", "Delta Vel", "Star", "Vel", 131.176, -54.708, 1.96, 2.00, "Delta Velorum,False Cross", "Alsephina,Delta Vel,HR 3485,HD 74956"),
    (91076, "Suhail", "Lambda Vel", "Star", "Vel", 136.999, -43.433, 2.21, 3.90, "Lambda Velorum", "Suhail,Lambda Vel,HR 3634,HD 78647"),
    (91077, "Muhlifain", "Gamma Cen", "Star", "Cen", 190.379, -48.960, 2.17, 2.19, "Gamma Centauri", "Muhlifain,Gamma Cen,HR 4819,HD 110304"),
    (91078, "Dschubba", "Delta Sco", "Star", "Sco", 240.083, -22.622, 2.29, 2.16, "Delta Scorpii,Crown of Scorpion", "Dschubba,Delta Sco,HR 5953,HD 143275"),
    (91079, "Wei", "Epsilon Sco", "Star", "Sco", 252.541, -34.293, 2.29, 3.44, "Epsilon Scorpii", "Wei,Epsilon Sco,HR 6241,HD 151680"),
    (91080, "Graffias", "Beta Sco", "Double Star", "Sco", 241.359, -19.805, 2.56, 2.50, "Beta Scorpii,Acrab", "Graffias,Acrab,Beta Sco,HR 5984,HD 144217"),
]

def seed():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    # Clear previous seed if exists
    cur.execute("DELETE FROM dso_objects WHERE id >= 90000 AND id <= 92000;")

    # Insert planets
    for p in PLANETS_DATA:
        cur.execute("""
            INSERT INTO dso_objects (
                id, name, messier, caldwell, arp, herschel, ngc_ic,
                catalog, catalog_number, object_type, constellation,
                ra_deg, dec_deg, magnitude, b_mag,
                major_axis_arcmin, minor_axis_arcmin, position_angle_deg, surface_brightness,
                common_names, identifiers
            ) VALUES (?, ?, NULL, NULL, NULL, NULL, ?, 'Solar System', ?, ?, ?, ?, ?, ?, NULL, ?, NULL, NULL, NULL, ?, ?)
        """, (
            p[0], p[1], p[1], p[2], p[3], p[4],
            p[5], p[6], p[7], p[8], p[9], p[10]
        ))

    # Insert bright stars
    for s in BRIGHT_STARS_DATA:
        cur.execute("""
            INSERT INTO dso_objects (
                id, name, messier, caldwell, arp, herschel, ngc_ic,
                catalog, catalog_number, object_type, constellation,
                ra_deg, dec_deg, magnitude, b_mag,
                major_axis_arcmin, minor_axis_arcmin, position_angle_deg, surface_brightness,
                common_names, identifiers
            ) VALUES (?, ?, NULL, NULL, NULL, NULL, ?, 'Stars', ?, ?, ?, ?, ?, ?, ?, 0.1, NULL, NULL, NULL, ?, ?)
        """, (
            s[0], s[1], s[1], s[2], s[3], s[4],
            s[5], s[6], s[7], s[8], s[9], s[10]
        ))

    # Rebuild FTS5 index safely from external content table
    cur.execute("INSERT INTO dso_fts(dso_fts) VALUES('rebuild');")

    conn.commit()
    print(f"Successfully seeded {len(PLANETS_DATA)} planets and {len(BRIGHT_STARS_DATA)} bright stars into {DB_PATH}")

    total_count = cur.execute("SELECT COUNT(*) FROM dso_objects;").fetchone()[0]
    print(f"Total DSO objects now: {total_count}")
    conn.close()

if __name__ == "__main__":
    seed()
