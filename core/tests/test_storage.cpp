#include "astro/storage.hpp"
#include "astro/ephemeris.hpp"
#include "astro/time.hpp"

#include <cassert>
#include <iostream>

void test_sqlite_catalog() {
    std::cout << "[TEST] SQLite Catalog & FTS Queries...\n";
    astro::storage::SqliteStorage storage("core/data/catalogs.db");
    if (!storage.is_open()) {
        std::cerr << "Failed to open catalogs.db: " << storage.last_error() << "\n";
        assert(false);
    }

    // 1. Query Messier objects
    astro::catalog::DsoFilterOptions messier_opts;
    messier_opts.catalogs.push_back("Messier");
    messier_opts.limit = 200;
    auto messier_objs = storage.query_objects(messier_opts);
    std::cout << "  Found Messier objects: " << messier_objs.size() << "\n";
    assert(messier_objs.size() >= 110);

    // 1b. Query Arp objects
    astro::catalog::DsoFilterOptions arp_opts;
    arp_opts.catalogs.push_back("Arp");
    arp_opts.limit = 500;
    auto arp_objs = storage.query_objects(arp_opts);
    std::cout << "  Found Arp objects: " << arp_objs.size() << "\n";
    assert(arp_objs.size() >= 338);

    // 1c. Query Herschel objects
    astro::catalog::DsoFilterOptions herschel_opts;
    herschel_opts.catalogs.push_back("Herschel");
    herschel_opts.limit = 500;
    auto herschel_objs = storage.query_objects(herschel_opts);
    std::cout << "  Found Herschel objects: " << herschel_objs.size() << "\n";
    assert(herschel_objs.size() >= 400);

    // 2. FTS search for "Andromeda"
    astro::catalog::DsoFilterOptions fts_opts;
    fts_opts.search_query = "Andromeda";
    auto fts_objs = storage.query_objects(fts_opts);
    std::cout << "  Found objects for 'Andromeda': " << fts_objs.size() << "\n";
    assert(!fts_objs.empty());
    bool found_m31 = false;
    for (const auto& obj : fts_objs) {
        if (obj.messier.has_value() && *obj.messier == "M 31") {
            found_m31 = true;
            std::cout << "  ✓ Found " << obj.display_name() << " at RA " << obj.coordinates.ra.value 
                      << "h, Dec " << obj.coordinates.dec.value << " deg\n";
            break;
        }
    }
    assert(found_m31);

    // 2b. Test unspaced catalog search for "M42"
    astro::catalog::DsoFilterOptions m42_opts;
    m42_opts.search_query = "M42";
    auto m42_objs = storage.query_objects(m42_opts);
    assert(!m42_objs.empty());
    assert(m42_objs[0].messier.has_value() && *m42_objs[0].messier == "M 42");
    std::cout << "  ✓ Found M42 via unspaced query 'M42': " << m42_objs[0].display_name() << "\n";

    // 3. Test filter_targets visibility solver on real database
    std::cout << "[TEST] Real-database Visibility Filter...\n";
    astro::coordinates::ObserverLocation obs{
        astro::units::Degrees{40.0},
        astro::units::Degrees{-74.0},
        10.0
    };

    // Autumn night: September 21, 2026
    auto jd = astro::time::datetime_to_julian_date({2026, 9, 21, 0, 0, 0.0});
    auto night = astro::ephemeris::calculate_night_window(jd, obs);

    astro::visibility::VisibilityCriteria crit;
    crit.min_altitude = astro::units::Degrees{30.0};
    crit.min_duration_hours = 2.0;
    crit.window_start = night.astronomical_dusk;
    crit.window_end = night.astronomical_dawn;
    crit.min_moon_separation = astro::units::Degrees{15.0};

    astro::catalog::DsoFilterOptions filter_opts;
    filter_opts.catalogs.push_back("Messier");

    auto visible_targets = storage.filter_targets(obs, filter_opts, crit, /*step_minutes=*/10);
    std::cout << "  Found visible Messier targets: " << visible_targets.size() << "\n";
    assert(!visible_targets.empty());

    for (size_t i = 0; i < std::min<size_t>(5, visible_targets.size()); ++i) {
        const auto& t = visible_targets[i];
        std::cout << "    Target: " << t.dso.display_name() 
                  << " | Peak Alt: " << t.visibility.peak_altitude.value << " deg"
                  << " | Visible: " << t.visibility.max_continuous_hours << " hrs\n";
    }

    // 3b. Test filter_targets with search_query = "M42" (off-season target is preserved)
    astro::catalog::DsoFilterOptions m42_search_opts;
    m42_search_opts.search_query = "M42";
    auto m42_filter_results = storage.filter_targets(obs, m42_search_opts, crit, 10);
    assert(!m42_filter_results.empty());
    assert(m42_filter_results[0].dso.messier.has_value() && *m42_filter_results[0].dso.messier == "M 42");
    std::cout << "  ✓ filter_targets with search 'M42' successfully returned " 
              << m42_filter_results[0].dso.display_name() << " (meets_criteria = " 
              << (m42_filter_results[0].visibility.meets_criteria ? "true" : "false") << ")\n";

    // 4. Test Observing Lists
    std::cout << "[TEST] User Observing Lists...\n";
    int64_t list_id = storage.create_list("Autumn Galaxies", "Targets for Bortle 4 trip", "2026-09-21");
    assert(list_id > 0);

    bool added = storage.add_target_to_list(list_id, visible_targets[0].dso.id, "Use 2-inch CLS filter, 180s subs");
    assert(added);

    auto lists = storage.get_all_lists();
    assert(!lists.empty());
    std::cout << "  Observing list created: '" << lists[0].name << "' with " << lists[0].items.size() << " items\n";
    assert(lists[0].items.size() == 1);
    assert(lists[0].items[0].dso.id == visible_targets[0].dso.id);

    bool deleted = storage.delete_list(list_id);
    assert(deleted);
    std::cout << "  ✓ Observing list test passed.\n";
}

void test_target_descriptions() {
    std::cout << "[TEST] Target Description Storage & Aliases...\n";
    astro::storage::SqliteStorage storage("core/data/catalogs.db");
    assert(storage.is_open());

    // Save description for M 31 with aliases
    std::vector<std::string> aliases = {"M 31", "Messier 31", "NGC 224", "Andromeda Galaxy"};
    bool saved = storage.save_target_description(
        "Andromeda Galaxy",
        "Barred spiral galaxy in the Local Group",
        "The Andromeda Galaxy is a barred spiral galaxy and is the nearest major galaxy to the Milky Way.",
        "https://upload.wikimedia.org/thumb/m31.jpg",
        "https://en.wikipedia.org/wiki/Andromeda_Galaxy",
        "Wikipedia",
        aliases
    );
    assert(saved);

    // Query by alias 'M 31'
    auto desc1 = storage.get_target_description("M 31");
    assert(desc1.has_value());
    assert(desc1->title == "Andromeda Galaxy");
    assert(!desc1->extract.empty());

    // Query by alias 'NGC 224' (case insensitive)
    auto desc2 = storage.get_target_description("ngc 224");
    assert(desc2.has_value());
    assert(desc2->title == "Andromeda Galaxy");

    // Query non-existent
    auto desc3 = storage.get_target_description("NonExistentObject9999");
    assert(!desc3.has_value());

    std::cout << "  ✓ Target descriptions test passed.\n";
}

int main() {
    std::cout << "========================================\n";
    std::cout << "  RUNNING SQLITE STORAGE TESTS          \n";
    std::cout << "========================================\n";

    test_sqlite_catalog();
    test_target_descriptions();

    std::cout << "\n>>> ALL STORAGE TESTS PASSED! <<<\n";
    return 0;
}
