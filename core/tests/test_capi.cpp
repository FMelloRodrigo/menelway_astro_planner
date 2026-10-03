#include "astro_capi.h"
#include "test_helpers.hpp"

#include <iostream>
#include <cstring>
#include <filesystem>
#include <string>
#include <vector>

static std::string find_catalog_db() {
    const std::vector<std::string> candidates = {
        "core/data/catalogs.db",
        "../data/catalogs.db",
        "../../data/catalogs.db",
        "data/catalogs.db",
        "catalogs.db"
    };
    for (const auto& p : candidates) {
        if (std::filesystem::exists(p)) return p;
    }
    return "core/data/catalogs.db";
}

int main() {
    std::cout << "========================================\n";
    std::cout << "  RUNNING C-ABI / FFI INTEGRATION TESTS \n";
    std::cout << "========================================\n";

    std::string original_db = find_catalog_db();
    std::string temp_db = std::filesystem::path(original_db).parent_path().string() + "/catalogs_capi_test_temp.db";
    
    std::error_code ec;
    std::filesystem::copy_file(original_db, temp_db, std::filesystem::copy_options::overwrite_existing, ec);
    if (ec) {
        std::cerr << "Failed to copy test database for CAPI tests: " << ec.message() << "\n";
        return 1;
    }

    AstroEngine* engine = astro_engine_create(temp_db.c_str());
    if (!engine) {
        std::cerr << "Failed to create AstroEngine\n";
        std::filesystem::remove(temp_db, ec);
        return 1;
    }

    AstroObserver obs{40.0, -74.0, 10.0};
    int64_t sept_21_2026_utc = 1790035200; // ~ 2026-09-21 00:00:00 UTC

    // Test 1: Night Summary
    AstroNightSummary night{};
    int32_t ok = astro_get_night_summary(engine, &obs, sept_21_2026_utc, &night);
    ASTRO_CHECK(ok == 1);
    std::cout << "  Night Summary: Sunset UTC=" << night.sunset_utc
              << ", Astro Dusk UTC=" << night.astronomical_dusk_utc
              << ", Moon Illum=" << night.moon_illumination * 100.0 << "%\n";
    ASTRO_CHECK(night.astronomical_dusk_utc > 0);
    ASTRO_CHECK(night.astronomical_dawn_utc > night.astronomical_dusk_utc);

    // Test 1b: Night Summary with non-midnight timestamp (afternoon time, e.g. +15 hours)
    AstroNightSummary night_afternoon{};
    int64_t sept_21_afternoon_utc = sept_21_2026_utc + 15 * 3600 + 42 * 60; // 15:42 UTC
    int32_t ok_afternoon = astro_get_night_summary(engine, &obs, sept_21_afternoon_utc, &night_afternoon);
    ASTRO_CHECK(ok_afternoon == 1);
    ASTRO_CHECK(night_afternoon.astronomical_dusk_utc > 0);
    ASTRO_CHECK(night_afternoon.astronomical_dawn_utc > night_afternoon.astronomical_dusk_utc);
    ASTRO_CHECK(night_afternoon.astronomical_dusk_utc == night.astronomical_dusk_utc);
    ASTRO_CHECK(night_afternoon.astronomical_dawn_utc == night.astronomical_dawn_utc);
    std::cout << "  ✓ Non-midnight timestamp normalized correctly to identical night window.\n";

    // Test 2: Filter Targets
    AstroFilterCriteria crit{};
    crit.min_altitude_deg = 30.0;
    crit.min_duration_hours = 2.0;
    crit.window_start_utc = night.astronomical_dusk_utc;
    crit.window_end_utc = night.astronomical_dawn_utc;
    crit.min_moon_separation_deg = 15.0;
    crit.min_azimuth_deg = 0.0;
    crit.max_azimuth_deg = 360.0;
    crit.quadrant = 0; // All
    crit.max_magnitude = 999.0;
    crit.min_magnitude = -999.0;
    crit.min_size_arcmin = 0.0;
    crit.max_size_arcmin = 99999.0;
    crit.catalogs_csv = "Messier";
    crit.object_types_csv = "Galaxy";
    crit.limit = 50;

    AstroTargetList* targets = astro_filter_targets(engine, &obs, &crit, 10);
    ASTRO_CHECK(targets != nullptr);
    std::cout << "  Filtered " << targets->count << " visible Messier galaxies\n";
    ASTRO_CHECK(targets->count > 0);

    for (size_t i = 0; i < targets->count; ++i) {
        const auto& t = targets->items[i];
        ASTRO_CHECK(t.name != nullptr && std::strlen(t.name) > 0);
        ASTRO_CHECK(t.catalog != nullptr && std::strlen(t.catalog) > 0);
        ASTRO_CHECK(t.object_type != nullptr && std::strlen(t.object_type) > 0);
        ASTRO_CHECK(t.constellation != nullptr && std::strlen(t.constellation) > 0);
        if (i < 3) {
            std::cout << "    [" << t.id << "] " << t.name << " (" << t.messier << ", " << t.common_name << ")"
                      << " PeakAlt: " << t.peak_altitude_deg << " deg, Visible: " << t.visible_duration_hours << " hrs\n";
        }
    }

    int64_t first_target_id = targets->items[0].id;
    astro_free_target_list(targets);

    // Test 2b: Search specifically for M33 to verify all catalog identifiers & common names are preserved
    AstroFilterCriteria m33_crit{};
    m33_crit.search_query = "m33";
    m33_crit.limit = 10;
    AstroTargetList* m33_targets = astro_filter_targets(engine, &obs, &m33_crit, 10);
    ASTRO_CHECK(m33_targets != nullptr);
    ASTRO_CHECK(m33_targets->count >= 1);
    const auto& m33 = m33_targets->items[0];
    std::cout << "  ✓ M33 Search Result: Name=" << m33.name 
              << ", Messier=" << m33.messier 
              << ", Catalog=" << m33.catalog 
              << ", Type=" << m33.object_type 
              << ", Herschel=" << m33.herschel 
              << ", Common=" << m33.common_name << "\n";
    ASTRO_CHECK(std::strcmp(m33.name, "NGC 598") == 0);
    ASTRO_CHECK(std::strcmp(m33.messier, "M 33") == 0);
    ASTRO_CHECK(std::strcmp(m33.catalog, "NGC") == 0);
    ASTRO_CHECK(std::strcmp(m33.object_type, "Galaxy") == 0);
    ASTRO_CHECK(std::strcmp(m33.herschel, "H 17-5") == 0);
    ASTRO_CHECK(std::strstr(m33.common_name, "Triangulum") != nullptr);
    astro_free_target_list(m33_targets);

    // Test 3: Generate altitude curve for the first target
    AstroCurveData* curve = astro_generate_curve(
        engine,
        first_target_id,
        &obs,
        night.astronomical_dusk_utc,
        night.astronomical_dawn_utc,
        15
    );
    ASTRO_CHECK(curve != nullptr);
    std::cout << "  Generated altitude curve with " << curve->count << " sample points\n";
    ASTRO_CHECK(curve->count > 0);
    astro_free_curve_data(curve);

    // Test 4: Observing lists JSON
    int64_t list_id = astro_create_observing_list(engine, "FFI Test Session", "Created from C-ABI", "2026-09-21");
    ASTRO_CHECK(list_id > 0);
    int32_t add_ok = astro_add_to_observing_list(engine, list_id, first_target_id, "Filter H-alpha");
    ASTRO_CHECK(add_ok == 1);

    const char* json_str = astro_get_observing_lists_json(engine);
    ASTRO_CHECK(json_str != nullptr);
    std::cout << "  Observing Lists JSON: " << json_str << "\n";
    ASTRO_CHECK(std::strstr(json_str, "FFI Test Session") != nullptr);
    astro_free_string(json_str);

    astro_delete_observing_list(engine, list_id);

    astro_engine_destroy(engine);
    std::filesystem::remove(temp_db, ec);

    std::cout << "\n>>> ALL C-ABI / FFI TESTS PASSED! <<<\n";
    return 0;
}
