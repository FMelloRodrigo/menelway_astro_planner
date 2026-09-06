#include "astro/units.hpp"
#include "astro/time.hpp"
#include "astro/coordinates.hpp"
#include "astro/ephemeris.hpp"
#include "astro/horizon.hpp"
#include "astro/visibility.hpp"

#include <cassert>
#include <cmath>
#include <iostream>

void test_units() {
    std::cout << "[TEST] Units...\n";
    using namespace astro::units;

    constexpr Degrees d{180.0};
    constexpr Radians r = to_radians(d);
    assert(std::abs(r.value - std::numbers::pi) < 1e-10);

    constexpr Hours h{12.0};
    constexpr Degrees d_from_h = hours_to_degrees(h);
    assert(std::abs(d_from_h.value - 180.0) < 1e-10);

    Degrees norm360 = normalize_degrees_360(Degrees{370.0});
    assert(std::abs(norm360.value - 10.0) < 1e-10);

    Degrees norm_neg = normalize_degrees_360(Degrees{-30.0});
    assert(std::abs(norm_neg.value - 330.0) < 1e-10);

    std::cout << "  ✓ Units passed.\n";
}

void test_time() {
    std::cout << "[TEST] Time & Julian Date...\n";
    using namespace astro::time;

    // J2000.0 epoch: 2000-01-01 12:00:00 UTC = JD 2451545.0
    DateTimeUtc j2000_dt{2000, 1, 1, 12, 0, 0.0};
    JulianDate jd = datetime_to_julian_date(j2000_dt);
    assert(std::abs(jd.value - 2451545.0) < 1e-6);

    DateTimeUtc back = julian_date_to_datetime(jd);
    assert(back.year == 2000 && back.month == 1 && back.day == 1 && back.hour == 12);

    // GMST at J2000.0 is ~ 18.697374558 hrs (280.46061837 deg / 15 = 18.6973745 h)
    astro::units::Hours gmst = greenwich_mean_sidereal_time(jd);
    assert(std::abs(gmst.value - 18.69737) < 0.001);

    std::cout << "  ✓ Time passed.\n";
}

void test_coordinates() {
    std::cout << "[TEST] Coordinates & Transformations...\n";
    using namespace astro::coordinates;
    using namespace astro::units;

    // Observer at Greenwich (Lat 51.48 deg N, Lon 0 deg)
    ObserverLocation greenwich{Degrees{51.4769}, Degrees{0.0}, 50.0};

    // Celestial North Pole: Dec = +90 deg
    EquatorialCoordinates north_pole{Hours{0.0}, Degrees{90.0}};
    astro::time::JulianDate jd{2451545.0}; // J2000

    auto horiz = equatorial_to_horizontal(north_pole, greenwich, jd, /*apply_refraction=*/false);
    // At Greenwich, North Celestial Pole altitude must equal observer latitude (~51.48 deg)
    assert(std::abs(horiz.altitude.value - 51.4769) < 0.01);

    // Angular separation: Vega (RA 18h 36m 56s = 18.6156h, Dec +38° 47' 01" = +38.7836°)
    // and Altair (RA 19h 50m 47s = 19.8464h, Dec +08° 52' 06" = +8.8683°)
    // Expected angular distance ~ 34.19°
    EquatorialCoordinates vega{Hours{18.6156}, Degrees{38.7836}};
    EquatorialCoordinates altair{Hours{19.8464}, Degrees{8.8683}};
    Degrees dist = angular_separation(vega, altair);
    assert(std::abs(dist.value - 34.19) < 0.2);

    std::cout << "  ✓ Coordinates passed.\n";
}

void test_ephemeris() {
    std::cout << "[TEST] Solar & Lunar Ephemeris...\n";
    using namespace astro::ephemeris;
    using namespace astro::coordinates;
    using namespace astro::units;

    ObserverLocation obs{Degrees{40.0}, Degrees{-74.0}, 10.0}; // NYC area

    // Summer Solstice ~ June 21, 2026: Sun declination should be near +23.44°
    astro::time::DateTimeUtc solstice_dt{2026, 6, 21, 12, 0, 0.0};
    astro::time::JulianDate solstice_jd = astro::time::datetime_to_julian_date(solstice_dt);
    SunInfo sun = get_sun_info(solstice_jd, obs);
    assert(std::abs(sun.coords.dec.value - 23.44) < 0.3);

    // Moon check
    MoonInfo moon = get_moon_info(solstice_jd, obs);
    assert(moon.illuminated_fraction >= 0.0 && moon.illuminated_fraction <= 1.0);
    assert(!moon.phase_name.empty());

    // Night window check: verify chronological order of evening twilights
    NightWindow window = calculate_night_window(solstice_jd, obs);
    assert(window.sunset.value > 0);
    assert(window.civil_dusk.value >= window.sunset.value);
    assert(window.nautical_dusk.value >= window.civil_dusk.value);
    assert(window.astronomical_dusk.value >= window.nautical_dusk.value);
    assert(window.solar_midnight.value >= window.astronomical_dusk.value);
    assert(window.astronomical_dawn.value >= window.solar_midnight.value);
    assert(window.sunrise.value >= window.astronomical_dawn.value);

    std::cout << "  ✓ Ephemeris passed.\n";
}

void test_horizon_and_visibility() {
    std::cout << "[TEST] Horizon & Visibility Solver...\n";
    using namespace astro::coordinates;
    using namespace astro::units;
    using namespace astro::visibility;
    using namespace astro::horizon;
    using namespace astro::ephemeris;

    // Observer at Lat 40°N, Lon -75°W
    ObserverLocation obs{Degrees{40.0}, Degrees{-75.0}, 0.0};

    // Target: M31 Andromeda Galaxy (RA 0.7122h, Dec +41.27°)
    EquatorialCoordinates m31{Hours{0.7122}, Degrees{41.27}};

    // Night of Autumn equinox (M31 is high in the sky in autumn)
    astro::time::DateTimeUtc dt{2026, 9, 21, 0, 0, 0.0};
    astro::time::JulianDate jd = astro::time::datetime_to_julian_date(dt);
    auto night = calculate_night_window(jd, obs);

    VisibilityCriteria criteria;
    criteria.min_altitude = Degrees{30.0};
    criteria.min_duration_hours = 3.0;
    criteria.window_start = night.astronomical_dusk;
    criteria.window_end = night.astronomical_dawn;
    criteria.min_moon_separation = Degrees{20.0};
    criteria.quadrant = Quadrant::All;

    auto res = evaluate_visibility(m31, obs, criteria, /*step_minutes=*/5, /*include_samples=*/true);

    // M31 peak altitude at 40°N should reach ~ 90 - (41.27 - 40) = ~88.7°
    assert(res.peak_altitude.value > 85.0);
    // In late September, M31 stays above 30° for virtually the entire night (> 6 hours)
    assert(res.max_continuous_hours > 5.0);
    assert(res.meets_criteria == true);
    assert(!res.samples.empty());

    // Test custom horizon obstruction
    HorizonProfile prof;
    prof.add_point(Degrees{0.0}, Degrees{50.0});   // North has 50° high tree
    prof.add_point(Degrees{180.0}, Degrees{10.0}); // South has 10° horizon
    assert(prof.is_visible(Degrees{40.0}, Degrees{0.0}) == false);  // Obstructed by North tree
    assert(prof.is_visible(Degrees{60.0}, Degrees{0.0}) == true);   // Above North tree
    assert(prof.is_visible(Degrees{20.0}, Degrees{180.0}) == true); // Above South horizon

    std::cout << "  ✓ Horizon & Visibility passed.\n";
}

void test_yearly_visibility() {
    std::cout << "[TEST] Yearly Visibility Solver...\n";
    using namespace astro::coordinates;
    using namespace astro::units;
    using namespace astro::visibility;

    ObserverLocation nyc{Degrees{40.7}, Degrees{-74.0}, 10.0};

    // M 42 Orion Nebula (RA ~5.588h, Dec -5.39 deg)
    EquatorialCoordinates m42{Hours{5.588}, Degrees{-5.39}};

    VisibilityCriteria crit;
    crit.min_altitude = Degrees{25.0};
    crit.min_duration_hours = 2.0;

    auto yearly_m42 = calculate_yearly_visibility(m42, nyc, crit, 2026);
    assert(yearly_m42.can_ever_reach_min_alt == true);
    // Theoretical max altitude at 40.7°N: 90 - (40.7 - (-5.39)) = 90 - 46.09 = ~43.9°
    assert(yearly_m42.theoretical_max_altitude_deg > 40.0);
    // Peak month for Orion is December or January (winter)
    assert(yearly_m42.peak_month == 12 || yearly_m42.peak_month == 1);
    assert(yearly_m42.peak_day >= 1 && yearly_m42.peak_day <= 31);
    assert(yearly_m42.start_month >= 1 && yearly_m42.start_day >= 1);
    assert(yearly_m42.end_month >= 1 && yearly_m42.end_day >= 1);
    assert(yearly_m42.total_observable_days > 100);
    // In June (month 6), M 42 is behind the Sun and not observable
    assert(yearly_m42.months[5].is_observable == false);
    // In December (month 12), M 42 is observable for multiple hours
    assert(yearly_m42.months[11].is_observable == true);
    assert(yearly_m42.months[11].observable_days_count == 31);

    // Rosette Nebula / Caldwell 49 (RA ~6.53h, Dec +5.0 deg)
    // Testing precision: With 30 deg min alt & 2.0h min duration from NYC,
    // Rosette enters visibility only at the very end of September!
    EquatorialCoordinates rosette{Hours{6.53}, Degrees{5.0}};
    VisibilityCriteria rosette_crit;
    rosette_crit.min_altitude = Degrees{30.0};
    rosette_crit.min_duration_hours = 2.0;

    auto yearly_rosette = calculate_yearly_visibility(rosette, nyc, rosette_crit, 2026);
    assert(yearly_rosette.can_ever_reach_min_alt == true);
    // Rosette becomes observable in late September (day >= 20)
    assert(yearly_rosette.start_month == 9);
    assert(yearly_rosette.start_day >= 20); // Only available at the very end of September!
    // In September, only a few days are observable (< 15 days)
    assert(yearly_rosette.months[8].observable_days_count > 0);
    assert(yearly_rosette.months[8].observable_days_count < 15);
    assert(yearly_rosette.months[8].start_day >= 20);

    // Test Rosette under user's specific directional & custom time window filters:
    // NW Azimuth (270-360 deg), 30 deg min altitude, 21:00 to 23:00 window.
    // Rosette is deep below horizon in September between 21:00 and 23:00 and never enters NW at >= 30 deg.
    VisibilityCriteria rosette_user_filters;
    rosette_user_filters.min_altitude = Degrees{30.0};
    rosette_user_filters.min_duration_hours = 2.0;
    rosette_user_filters.azimuth_range = astro::horizon::AzimuthRange{Degrees{270.0}, Degrees{360.0}};
    rosette_user_filters.quadrant = astro::horizon::Quadrant::NorthWest;
    rosette_user_filters.use_custom_time_window = true;
    rosette_user_filters.custom_start_hour = 21;
    rosette_user_filters.custom_start_minute = 0;
    rosette_user_filters.custom_end_hour = 23;
    rosette_user_filters.custom_end_minute = 0;
    rosette_user_filters.utc_offset_minutes = -180; // UTC-3

    auto yearly_rosette_filtered = calculate_yearly_visibility(rosette, nyc, rosette_user_filters, 2026);
    // Must NOT be observable in September with these filters
    assert(yearly_rosette_filtered.months[8].is_observable == false);
    assert(yearly_rosette_filtered.months[8].observable_days_count == 0);
    assert(yearly_rosette_filtered.total_observable_days == 0);
    assert(yearly_rosette_filtered.best_window_summary == "Not observable with current filters");

    // Southern object: Carina Nebula (Dec -59.87 deg) from NYC (Lat 40.7 N)
    EquatorialCoordinates carina{Hours{10.75}, Degrees{-59.87}};
    auto yearly_carina = calculate_yearly_visibility(carina, nyc, crit, 2026);
    assert(yearly_carina.can_ever_reach_min_alt == false);
    assert(yearly_carina.total_observable_days == 0);

    std::cout << "  ✓ Yearly Visibility M42 passed: " << yearly_m42.best_window_summary << "\n";
    std::cout << "  ✓ Yearly Visibility Rosette (C49 Unrestricted) passed: " << yearly_rosette.best_window_summary << "\n";
    std::cout << "    (Rosette Sep Unrestricted: " << yearly_rosette.months[8].observable_days_count << " days, starting Sep "
              << yearly_rosette.months[8].start_day << ")\n";
    // Test from Southern Hemisphere (e.g. Brazil -23.55 deg Lat, UTC-3)
    ObserverLocation brazil{Degrees{-23.55}, Degrees{-46.63}, 760.0};
    auto yearly_rosette_brazil = calculate_yearly_visibility(rosette, brazil, rosette_user_filters, 2026);
    std::cout << "  ✓ Yearly Visibility Rosette from Brazil (-23.55 Lat, NW, 21-23h): "
              << yearly_rosette_brazil.best_window_summary << " (Total days: "
              << yearly_rosette_brazil.total_observable_days << ")\n";
    for (int m = 1; m <= 12; ++m) {
        const auto& md = yearly_rosette_brazil.months[m - 1];
        if (md.is_observable) {
            std::cout << "    - " << md.month_name << ": " << md.observable_days_count << " days (from day "
                      << md.start_day << " to " << md.end_day << " at max "
                      << md.peak_altitude_deg << "°)\n";
        }
    }
    // In September, Rosette is NOT visible between 21:00 and 23:00 in NW from Brazil
    assert(yearly_rosette_brazil.months[8].observable_days_count == 0);
    assert(yearly_rosette_brazil.months[8].is_observable == false);
    // In February, Rosette IS visible in NW between 21:00 and 23:00
    assert(yearly_rosette_brazil.months[1].observable_days_count > 0);
    assert(yearly_rosette_brazil.months[1].is_observable == true);
    // In March, Rosette IS visible in NW between 21:00 and 23:00
    assert(yearly_rosette_brazil.months[2].observable_days_count > 0);
    assert(yearly_rosette_brazil.months[2].is_observable == true);
    assert(yearly_rosette_brazil.total_observable_days > 0);
}

void test_period_visibility() {
    std::cout << "[TEST] Period Visibility Solver (Future Planning)...\n";
    using namespace astro::units;
    using namespace astro::coordinates;
    using namespace astro::visibility;
    using namespace astro::time;

    ObserverLocation brazil{Degrees{-23.55}, Degrees{-46.63}, 760.0};
    EquatorialCoordinates rosette{Hours{6.53}, Degrees{5.0}};

    VisibilityCriteria criteria;
    criteria.min_altitude = Degrees{30.0};
    criteria.min_duration_hours = 2.0;
    criteria.azimuth_range = astro::horizon::AzimuthRange{Degrees{270.0}, Degrees{360.0}};
    criteria.quadrant = astro::horizon::Quadrant::NorthWest;
    criteria.use_custom_time_window = true;
    criteria.custom_start_hour = 21;
    criteria.custom_start_minute = 0;
    criteria.custom_end_hour = 23;
    criteria.custom_end_minute = 0;
    criteria.utc_offset_minutes = -180; // UTC-3

    // Period 1: September 1 to September 30, 2026 (off-season for Rosette with these filters)
    auto sep_start = astro::time::datetime_to_julian_date({2026, 9, 1, 0, 0, 0.0});
    auto sep_end = astro::time::datetime_to_julian_date({2026, 9, 30, 0, 0, 0.0});
    auto sep_res = astro::visibility::evaluate_period_visibility(rosette, brazil, criteria, sep_start, sep_end);
    assert(sep_res.is_observable == false);
    assert(sep_res.total_observable_days == 0);
    assert(sep_res.total_period_days == 30);

    // Period 2: February 1 to February 28, 2026 (active season for Rosette in NW 21-23h)
    auto feb_start = astro::time::datetime_to_julian_date({2026, 2, 1, 0, 0, 0.0});
    auto feb_end = astro::time::datetime_to_julian_date({2026, 2, 28, 0, 0, 0.0});
    auto feb_res = astro::visibility::evaluate_period_visibility(rosette, brazil, criteria, feb_start, feb_end);
    assert(feb_res.is_observable == true);
    assert(feb_res.total_observable_days == 19);
    assert(feb_res.start_day == 10);
    assert(feb_res.end_day == 28);
    assert(feb_res.peak_altitude_deg > 60.0);
    std::cout << "  ✓ Period Visibility Rosette in Feb: " << feb_res.total_observable_days
              << " of " << feb_res.total_period_days << " days (from Feb "
              << feb_res.start_day << " to " << feb_res.end_day << ", peak at "
              << feb_res.peak_altitude_deg << "°)\n";
}

int main() {
    std::cout << "========================================\n";
    std::cout << "  RUNNING ASTRO CORE C++20 TESTS        \n";
    std::cout << "========================================\n";

    test_units();
    test_time();
    test_coordinates();
    test_ephemeris();
    test_horizon_and_visibility();
    test_yearly_visibility();
    test_period_visibility();

    std::cout << "\n>>> ALL C++20 CORE TESTS PASSED SUCCESSFULLY! <<<\n";
    return 0;
}
