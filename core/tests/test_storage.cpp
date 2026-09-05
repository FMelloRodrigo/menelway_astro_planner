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

int main() {
    std::cout << "========================================\n";
    std::cout << "  RUNNING SQLITE STORAGE TESTS          \n";
    std::cout << "========================================\n";

    test_sqlite_catalog();

    std::cout << "\n>>> ALL STORAGE TESTS PASSED! <<<\n";
    return 0;
}
