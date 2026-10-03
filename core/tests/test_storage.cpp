#include "astro/storage.hpp"
#include "astro/target_filter_service.hpp"
#include "astro/ephemeris.hpp"
#include "astro/time.hpp"
#include "test_helpers.hpp"

#include <iostream>
#include <filesystem>
#include <string>
#include <vector>
#include <chrono>

static std::string find_catalog_db() {
    const std::vector<std::string> candidates = {
        "core/data/catalogs.db",
        "../data/catalogs.db",
        "../../data/catalogs.db",
        "data/catalogs.db",
        "catalogs.db",
        "app/assets/catalogs.db",
        "../app/assets/catalogs.db",
        "../../app/assets/catalogs.db"
    };
    for (const auto& p : candidates) {
        if (std::filesystem::exists(p)) return p;
    }
    return "app/assets/catalogs.db";
}

void test_sqlite_catalog(const std::string& db_path) {
    std::cout << "[TEST] SQLite Catalog & FTS Queries...\n";
    astro::storage::SqliteStorage storage(db_path);
    if (!storage.is_open()) {
        std::cerr << "Failed to open catalogs.db: " << storage.last_error() << "\n";
        ASTRO_CHECK(false);
    }

    // 1. Query Messier objects
    astro::catalog::DsoFilterOptions messier_opts;
    messier_opts.catalogs.push_back("Messier");
    messier_opts.limit = 200;
    auto messier_objs = storage.query_objects(messier_opts);
    std::cout << "  Found Messier objects: " << messier_objs.size() << "\n";
    ASTRO_CHECK(messier_objs.size() >= 110);

    // 1b. Query Arp objects
    astro::catalog::DsoFilterOptions arp_opts;
    arp_opts.catalogs.push_back("Arp");
    arp_opts.limit = 500;
    auto arp_objs = storage.query_objects(arp_opts);
    std::cout << "  Found Arp objects: " << arp_objs.size() << "\n";
    ASTRO_CHECK(arp_objs.size() >= 338);

    // 1c. Query Herschel objects
    astro::catalog::DsoFilterOptions herschel_opts;
    herschel_opts.catalogs.push_back("Herschel");
    herschel_opts.limit = 500;
    auto herschel_objs = storage.query_objects(herschel_opts);
    std::cout << "  Found Herschel objects: " << herschel_objs.size() << "\n";
    ASTRO_CHECK(herschel_objs.size() >= 400);

    // 2. FTS search for "Andromeda"
    astro::catalog::DsoFilterOptions fts_opts;
    fts_opts.search_query = "Andromeda";
    auto fts_objs = storage.query_objects(fts_opts);
    std::cout << "  Found objects for 'Andromeda': " << fts_objs.size() << "\n";
    ASTRO_CHECK(!fts_objs.empty());
    bool found_m31 = false;
    for (const auto& obj : fts_objs) {
        if (obj.messier.has_value() && *obj.messier == "M 31") {
            found_m31 = true;
            std::cout << "  ✓ Found " << obj.display_name() << " at RA " << obj.coordinates.ra.value 
                      << "h, Dec " << obj.coordinates.dec.value << " deg\n";
            break;
        }
    }
    ASTRO_CHECK(found_m31);

    // 2b. Test unspaced catalog search for "M42"
    astro::catalog::DsoFilterOptions m42_opts;
    m42_opts.search_query = "M42";
    auto m42_objs = storage.query_objects(m42_opts);
    ASTRO_CHECK(!m42_objs.empty());
    ASTRO_CHECK(m42_objs[0].messier.has_value() && *m42_objs[0].messier == "M 42");
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
    ASTRO_CHECK(!visible_targets.empty());

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
    ASTRO_CHECK(!m42_filter_results.empty());
    ASTRO_CHECK(m42_filter_results[0].dso.messier.has_value() && *m42_filter_results[0].dso.messier == "M 42");
    std::cout << "  ✓ filter_targets with search 'M42' successfully returned " 
              << m42_filter_results[0].dso.display_name() << " (meets_criteria = " 
              << (m42_filter_results[0].visibility.meets_criteria ? "true" : "false") << ")\n";

    // 4. Test Observing Lists
    std::cout << "[TEST] User Observing Lists...\n";
    int64_t list_id = storage.create_list("Autumn Galaxies", "Targets for Bortle 4 trip", "2026-09-21");
    ASTRO_CHECK(list_id > 0);

    bool added = storage.add_target_to_list(list_id, visible_targets[0].dso.id, "Use 2-inch CLS filter, 180s subs");
    ASTRO_CHECK(added);

    auto lists = storage.get_all_lists();
    ASTRO_CHECK(!lists.empty());
    std::cout << "  Observing list created: '" << lists[0].name << "' with " << lists[0].items.size() << " items\n";
    ASTRO_CHECK(lists[0].items.size() == 1);
    ASTRO_CHECK(lists[0].items[0].dso.id == visible_targets[0].dso.id);

    bool deleted = storage.delete_list(list_id);
    ASTRO_CHECK(deleted);
    std::cout << "  ✓ Observing list test passed.\n";
}

void test_target_descriptions(const std::string& db_path) {
    std::cout << "[TEST] Target Description Storage & Aliases...\n";
    astro::storage::SqliteStorage storage(db_path);
    ASTRO_CHECK(storage.is_open());

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
    ASTRO_CHECK(saved);

    // Query by alias 'M 31'
    auto desc1 = storage.get_target_description("M 31");
    ASTRO_CHECK(desc1.has_value());
    ASTRO_CHECK(desc1->title == "Andromeda Galaxy");
    ASTRO_CHECK(!desc1->extract.empty());

    // Query by alias 'NGC 224' (case insensitive)
    auto desc2 = storage.get_target_description("ngc 224");
    ASTRO_CHECK(desc2.has_value());
    ASTRO_CHECK(desc2->title == "Andromeda Galaxy");

    // Query non-existent
    auto desc3 = storage.get_target_description("NonExistentObject9999");
    ASTRO_CHECK(!desc3.has_value());

    std::cout << "  ✓ Target descriptions test passed.\n";
}

void test_period_performance(const std::string& db_path) {
    std::cout << "[BENCHMARK] Period Visibility Filter Performance...\n";
    astro::storage::SqliteStorage storage(db_path);
    ASTRO_CHECK(storage.is_open());

    astro::coordinates::ObserverLocation obs{
        astro::units::Degrees{51.4769},
        astro::units::Degrees{0.0},
        10.0
    };

    auto start_jd = astro::time::datetime_to_julian_date({2026, 9, 21, 0, 0, 0.0});
    auto end_jd = astro::time::datetime_to_julian_date({2026, 10, 5, 0, 0, 0.0});

    astro::visibility::VisibilityCriteria crit;
    crit.min_altitude = astro::units::Degrees{30.0};
    crit.min_duration_hours = 2.0;

    astro::catalog::DsoFilterOptions opts;
    // Test with all catalogs (comprehensive 13,000+ objects)
    opts.limit = 500;

    auto t0 = std::chrono::high_resolution_clock::now();
    auto results = storage.filter_targets_period(obs, opts, crit, start_jd, end_jd, /*step_minutes=*/10);
    auto t1 = std::chrono::high_resolution_clock::now();

    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t0).count();
    std::cout << "  filter_targets_period for 15 nights returned " << results.size() << " targets in " << ms << " ms\n";
    ASTRO_CHECK(results.size() > 0);
    ASTRO_CHECK(ms < 2500);
    std::cout << "  ✓ Period visibility filter performance benchmark passed (" << ms << " ms)\n";
}

void test_target_filter_service(const std::string& db_path) {
    std::cout << "[TEST] TargetFilterService Domain Compute & Planet Decoration...\n";
    astro::storage::SqliteStorage storage(db_path);
    ASTRO_CHECK(storage.is_open());

    astro::services::TargetFilterService service(storage);

    // Test planet decoration
    auto moon_obj = storage.get_object_by_id(90008);
    ASTRO_CHECK(moon_obj.has_value());
    ASTRO_CHECK(moon_obj->name == "Moon");

    astro::coordinates::ObserverLocation obs{
        astro::units::Degrees{-22.2819},
        astro::units::Degrees{-42.5311},
        858.0
    };
    auto jd = astro::time::datetime_to_julian_date({2026, 10, 3, 21, 0, 0.0});
    astro::services::TargetFilterService::decorate_solar_system_body(*moon_obj, jd, obs);
    ASTRO_CHECK(moon_obj->magnitude.has_value());
    ASTRO_CHECK(moon_obj->major_axis_arcmin.has_value());
    ASTRO_CHECK(*moon_obj->major_axis_arcmin > 28.0 && *moon_obj->major_axis_arcmin < 34.0);

    // Test filter_targets over service
    astro::visibility::VisibilityCriteria crit;
    crit.min_altitude = astro::units::Degrees{20.0};
    crit.min_duration_hours = 1.0;
    crit.window_start = jd;
    crit.window_end = astro::time::JulianDate{jd.value + 0.3};

    astro::catalog::DsoFilterOptions opts;
    opts.catalogs.push_back("Solar System");
    auto planet_results = service.filter_targets(obs, opts, crit, 10);
    ASTRO_CHECK(!planet_results.empty());
    std::cout << "  ✓ TargetFilterService successfully filtered " << planet_results.size() << " solar system targets\n";
}

void test_separate_user_db(const std::string& catalog_db) {
    std::cout << "[TEST] Separate User Database (Read-Only Catalog + Read-Write User DB)...\n";
    std::string user_db = std::filesystem::path(catalog_db).parent_path().string() + "/test_user_isolated.db";

    std::error_code ec;
    std::filesystem::remove(user_db, ec);

    {
        astro::storage::SqliteStorage storage(catalog_db, user_db);
        ASTRO_CHECK(storage.is_open());
        ASTRO_CHECK(storage.has_separate_user_db());

        // Create an observing list in the isolated user database
        int64_t list_id = storage.create_list("User Isolated Showcase", "Separate DB test", "2026-10-03");
        ASTRO_CHECK(list_id > 0);

        // Add M31 (id=1 or query by name)
        auto m31 = storage.query_objects([]{
            astro::catalog::DsoFilterOptions o;
            o.search_query = "M31";
            o.limit = 1;
            return o;
        }());
        ASTRO_CHECK(!m31.empty());

        bool added = storage.add_target_to_list(list_id, m31[0].id, "Target stored in user DB");
        ASTRO_CHECK(added);

        // Save description in user DB
        bool saved_desc = storage.save_target_description(
            "User Target Test",
            "Description in isolated DB",
            "Extract in isolated DB",
            "thumb",
            "page",
            "Custom",
            {"Alias1", "Alias2"}
        );
        ASTRO_CHECK(saved_desc);
    }

    // Verify user database file exists on disk independently
    ASTRO_CHECK(std::filesystem::exists(user_db));

    // Reopen with separate user DB and verify persistence
    {
        astro::storage::SqliteStorage storage(catalog_db, user_db);
        ASTRO_CHECK(storage.is_open());
        ASTRO_CHECK(storage.has_separate_user_db());

        auto lists = storage.get_all_lists();
        ASTRO_CHECK(lists.size() == 1);
        ASTRO_CHECK(lists[0].name == "User Isolated Showcase");
        ASTRO_CHECK(lists[0].items.size() == 1);

        auto desc = storage.get_target_description("Alias1");
        ASTRO_CHECK(desc.has_value());
        ASTRO_CHECK(desc->title == "User Target Test");
        std::cout << "  ✓ Isolated user database persisted lists and descriptions successfully.\n";
    }

    std::filesystem::remove(user_db, ec);
}

int main() {
    std::cout << "========================================\n";
    std::cout << "  RUNNING SQLITE STORAGE TESTS          \n";
    std::cout << "========================================\n";

    std::string original_db = find_catalog_db();
    std::string temp_db = std::filesystem::path(original_db).parent_path().string() + "/catalogs_storage_test_temp.db";
    
    std::error_code ec;
    std::filesystem::copy_file(original_db, temp_db, std::filesystem::copy_options::overwrite_existing, ec);
    if (ec) {
        std::cerr << "Failed to copy test database: " << ec.message() << "\n";
        return 1;
    }

    try {
        test_sqlite_catalog(temp_db);
        test_target_descriptions(temp_db);
        test_target_filter_service(temp_db);
        test_separate_user_db(temp_db);
        test_period_performance(temp_db);
    } catch (...) {
        std::filesystem::remove(temp_db, ec);
        throw;
    }

    std::filesystem::remove(temp_db, ec);
    std::cout << "\n>>> ALL STORAGE TESTS PASSED! <<<\n";
    return 0;
}
