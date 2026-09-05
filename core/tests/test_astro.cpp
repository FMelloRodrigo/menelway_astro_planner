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

int main() {
    std::cout << "========================================\n";
    std::cout << "  RUNNING ASTRO CORE C++20 TESTS        \n";
    std::cout << "========================================\n";

    test_units();
    test_time();
    test_coordinates();
    test_ephemeris();
    test_horizon_and_visibility();

    std::cout << "\n>>> ALL C++20 CORE TESTS PASSED SUCCESSFULLY! <<<\n";
    return 0;
}
