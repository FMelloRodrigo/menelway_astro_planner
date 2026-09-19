#include "astro/ephemeris.hpp"
#include <algorithm>
#include <cmath>
#include <functional>

namespace astro::ephemeris {

namespace {

inline double deg_to_rad(double deg) {
    return deg * (std::numbers::pi / 180.0);
}

inline double rad_to_deg(double rad) {
    return rad * (180.0 / std::numbers::pi);
}

inline double norm360(double deg) {
    double v = std::fmod(deg, 360.0);
    if (v < 0.0) v += 360.0;
    return v;
}

double obliquity_of_ecliptic(double T) {
    // Mean obliquity (Meeus Ch. 22)
    return 23.439291 - 0.0130042 * T - 0.00000016 * T * T + 0.000000504 * T * T * T;
}

} // namespace

SunInfo get_sun_info(time::JulianDate jd, const coordinates::ObserverLocation& obs) {
    double T = time::julian_centuries_j2000(jd);

    // Geometric mean longitude of the Sun (degrees)
    double L0 = norm360(280.46646 + 36000.76983 * T + 0.0003032 * T * T);

    // Mean anomaly of the Sun (degrees)
    double M = norm360(357.52911 + 35999.05029 * T - 0.0001537 * T * T);
    double M_rad = deg_to_rad(M);

    // Equation of the center (degrees)
    double C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * std::sin(M_rad) +
               (0.019993 - 0.000101 * T) * std::sin(2.0 * M_rad) +
               0.000289 * std::sin(3.0 * M_rad);

    // Sun's true longitude (degrees)
    double sun_true_lon = L0 + C;

    // Apparent longitude (accounting for aberration and nutation)
    double omega = norm360(125.04 - 1934.136 * T);
    double lambda = norm360(sun_true_lon - 0.00569 - 0.00478 * std::sin(deg_to_rad(omega)));
    double lambda_rad = deg_to_rad(lambda);

    // Obliquity
    double eps = deg_to_rad(obliquity_of_ecliptic(T) + 0.00256 * std::cos(deg_to_rad(omega)));

    // Right Ascension and Declination
    double sin_dec = std::sin(eps) * std::sin(lambda_rad);
    double dec_rad = std::asin(std::clamp(sin_dec, -1.0, 1.0));
    double dec_deg = rad_to_deg(dec_rad);

    double y = std::cos(eps) * std::sin(lambda_rad);
    double x = std::cos(lambda_rad);
    double ra_deg = norm360(rad_to_deg(std::atan2(y, x)));
    units::Hours ra_hours = units::degrees_to_hours(units::Degrees{ra_deg});

    coordinates::EquatorialCoordinates eq{ra_hours, units::Degrees{dec_deg}};
    coordinates::HorizontalCoordinates horiz = coordinates::equatorial_to_horizontal(
        eq, obs, jd, /*apply_refraction=*/true
    );

    return SunInfo{eq, horiz};
}

MoonInfo get_moon_info(time::JulianDate jd, const coordinates::ObserverLocation& obs) {
    double T = time::julian_centuries_j2000(jd);

    // Meeus Ch. 47 approximate lunar coordinates
    double L_prime = norm360(218.3164477 + 481267.881277 * T);
    double D = norm360(297.8501921 + 445267.1114034 * T);
    double M = norm360(357.5291092 + 35999.0502909 * T);
    double M_prime = norm360(134.9633964 + 477198.8675055 * T);
    double F = norm360(93.2720950 + 483202.0175233 * T);

    double D_rad = deg_to_rad(D);
    double M_rad = deg_to_rad(M);
    double Mp_rad = deg_to_rad(M_prime);
    double F_rad = deg_to_rad(F);

    // Periodic terms in longitude (degrees)
    double d_lambda = 6.288774 * std::sin(Mp_rad) +
                      1.274027 * std::sin(2.0 * D_rad - Mp_rad) +
                      0.658314 * std::sin(2.0 * D_rad) +
                      0.213618 * std::sin(2.0 * Mp_rad) -
                      0.185116 * std::sin(M_rad) -
                      0.114332 * std::sin(2.0 * F_rad) +
                      0.058793 * std::sin(2.0 * D_rad - 2.0 * Mp_rad) +
                      0.057066 * std::sin(2.0 * D_rad - M_rad - Mp_rad) +
                      0.053322 * std::sin(2.0 * D_rad + Mp_rad) +
                      0.045758 * std::sin(2.0 * D_rad - M_rad);

    // Periodic terms in latitude (degrees)
    double beta = 5.128154 * std::sin(F_rad) +
                  0.280606 * std::sin(Mp_rad + F_rad) +
                  0.277693 * std::sin(Mp_rad - F_rad) +
                  0.173237 * std::sin(2.0 * D_rad - F_rad) +
                  0.055413 * std::sin(2.0 * D_rad - Mp_rad + F_rad) +
                  0.046271 * std::sin(2.0 * D_rad - Mp_rad - F_rad);

    double lambda = norm360(L_prime + d_lambda);
    double lambda_rad = deg_to_rad(lambda);
    double beta_rad = deg_to_rad(beta);
    double eps_rad = deg_to_rad(obliquity_of_ecliptic(T));

    // Convert Ecliptic to Equatorial
    double sin_dec = std::sin(beta_rad) * std::cos(eps_rad) +
                     std::cos(beta_rad) * std::sin(eps_rad) * std::sin(lambda_rad);
    double dec_rad = std::asin(std::clamp(sin_dec, -1.0, 1.0));
    double dec_deg = rad_to_deg(dec_rad);

    double y = std::cos(beta_rad) * std::cos(eps_rad) * std::sin(lambda_rad) -
               std::sin(beta_rad) * std::sin(eps_rad);
    double x = std::cos(beta_rad) * std::cos(lambda_rad);
    double ra_deg = norm360(rad_to_deg(std::atan2(y, x)));
    units::Hours ra_hours = units::degrees_to_hours(units::Degrees{ra_deg});

    coordinates::EquatorialCoordinates moon_eq{ra_hours, units::Degrees{dec_deg}};
    coordinates::HorizontalCoordinates moon_horiz = coordinates::equatorial_to_horizontal(
        moon_eq, obs, jd, /*apply_refraction=*/true
    );

    // Phase angle and illuminated fraction
    SunInfo sun = get_sun_info(jd, obs);
    units::Degrees sun_moon_sep = coordinates::angular_separation(sun.coords, moon_eq);
    double psi_rad = deg_to_rad(sun_moon_sep.value);
    // Phase angle i ~ 180 - psi
    double phase_angle_rad = std::numbers::pi - psi_rad;
    double k = (1.0 + std::cos(phase_angle_rad)) / 2.0;
    k = std::clamp(k, 0.0, 1.0);

    // Phase classification based on elongation D
    MoonPhaseType phase_type;
    std::string phase_name;

    if (D < 22.5 || D >= 337.5) {
        phase_type = MoonPhaseType::NewMoon;
        phase_name = "New Moon";
    } else if (D < 67.5) {
        phase_type = MoonPhaseType::WaxingCrescent;
        phase_name = "Waxing Crescent";
    } else if (D < 112.5) {
        phase_type = MoonPhaseType::FirstQuarter;
        phase_name = "First Quarter";
    } else if (D < 157.5) {
        phase_type = MoonPhaseType::WaxingGibbous;
        phase_name = "Waxing Gibbous";
    } else if (D < 202.5) {
        phase_type = MoonPhaseType::FullMoon;
        phase_name = "Full Moon";
    } else if (D < 247.5) {
        phase_type = MoonPhaseType::WaningGibbous;
        phase_name = "Waning Gibbous";
    } else if (D < 292.5) {
        phase_type = MoonPhaseType::ThirdQuarter;
        phase_name = "Third Quarter";
    } else {
        phase_type = MoonPhaseType::WaningCrescent;
        phase_name = "Waning Crescent";
    }

    return MoonInfo{moon_eq, moon_horiz, k, phase_type, phase_name};
}

namespace {

// Finds the exact time where Sun altitude crosses target_alt
time::JulianDate find_altitude_crossing(
    time::JulianDate t_start,
    time::JulianDate t_end,
    double target_alt,
    const coordinates::ObserverLocation& obs,
    bool descending
) {
    double t0 = t_start.value;
    double t1 = t_end.value;

    for (int iter = 0; iter < 24; ++iter) {
        double mid = (t0 + t1) * 0.5;
        SunInfo sun = get_sun_info(time::JulianDate{mid}, obs);
        double diff = sun.horizontal.altitude.value - target_alt;

        if (std::abs(diff) < 1e-5) {
            return time::JulianDate{mid};
        }

        if (descending) {
            if (diff > 0.0) {
                t0 = mid;
            } else {
                t1 = mid;
            }
        } else {
            if (diff < 0.0) {
                t0 = mid;
            } else {
                t1 = mid;
            }
        }
    }
    return time::JulianDate{(t0 + t1) * 0.5};
}

} // namespace

NightWindow calculate_night_window(
    time::JulianDate date_midnight_utc,
    const coordinates::ObserverLocation& obs
) {
    NightWindow window;

    // Normalize date_midnight_utc to 00:00:00 UTC of that calendar date
    time::DateTimeUtc dt = time::julian_date_to_datetime(date_midnight_utc);
    dt.hour = 0;
    dt.minute = 0;
    dt.second = 0.0;
    time::JulianDate normalized_midnight = time::datetime_to_julian_date(dt);

    // Approximate local solar noon: UTC midnight + 0.5 day - (lon / 360)
    double lon_offset_days = obs.longitude.value / 360.0;
    double approx_noon = normalized_midnight.value + 0.5 - lon_offset_days;

    // We scan from noon to noon next day (24 hours = 1.0 day)
    double scan_start = approx_noon;
    double scan_end = approx_noon + 1.0;
    double step = 5.0 / 1440.0; // 5-minute steps

    double prev_t = scan_start;
    double prev_alt = get_sun_info(time::JulianDate{prev_t}, obs).horizontal.altitude.value;

    double min_alt = prev_alt;
    double max_alt = prev_alt;
    double min_t = scan_start;

    struct Crossing {
        double target_alt;
        time::JulianDate jd;
        bool descending;
    };
    std::vector<Crossing> crossings;

    const double targets[] = {-0.833, -6.0, -12.0, -18.0};

    for (double t = scan_start + step; t <= scan_end + 1e-6; t += step) {
        double cur_alt = get_sun_info(time::JulianDate{t}, obs).horizontal.altitude.value;

        if (cur_alt < min_alt) {
            min_alt = cur_alt;
            min_t = t;
        }
        if (cur_alt > max_alt) {
            max_alt = cur_alt;
        }

        for (double target_alt : targets) {
            if ((prev_alt >= target_alt && cur_alt < target_alt)) {
                // Descending (dusk)
                crossings.push_back({
                    target_alt,
                    find_altitude_crossing(time::JulianDate{prev_t}, time::JulianDate{t}, target_alt, obs, true),
                    true
                });
            } else if ((prev_alt <= target_alt && cur_alt > target_alt)) {
                // Ascending (dawn)
                crossings.push_back({
                    target_alt,
                    find_altitude_crossing(time::JulianDate{prev_t}, time::JulianDate{t}, target_alt, obs, false),
                    false
                });
            }
        }

        prev_t = t;
        prev_alt = cur_alt;
    }

    window.solar_midnight = time::JulianDate{min_t};

    if (min_alt > -0.833) {
        window.sun_never_sets = true;
    }
    if (max_alt < -0.833) {
        window.sun_never_rises = true;
    }
    if (min_alt > -18.0) {
        window.has_astronomical_night = false;
    }

    for (const auto& c : crossings) {
        if (c.descending) {
            if (c.jd.value <= window.solar_midnight.value) {
                if (std::abs(c.target_alt - (-0.833)) < 0.1) window.sunset = c.jd;
                else if (std::abs(c.target_alt - (-6.0)) < 0.1) window.civil_dusk = c.jd;
                else if (std::abs(c.target_alt - (-12.0)) < 0.1) window.nautical_dusk = c.jd;
                else if (std::abs(c.target_alt - (-18.0)) < 0.1) window.astronomical_dusk = c.jd;
            }
        } else {
            if (c.jd.value >= window.solar_midnight.value) {
                if (std::abs(c.target_alt - (-18.0)) < 0.1) window.astronomical_dawn = c.jd;
                else if (std::abs(c.target_alt - (-12.0)) < 0.1) window.nautical_dawn = c.jd;
                else if (std::abs(c.target_alt - (-6.0)) < 0.1) window.civil_dawn = c.jd;
                else if (std::abs(c.target_alt - (-0.833)) < 0.1) window.sunrise = c.jd;
            }
        }
    }

    // Fallbacks if astronomical night does not occur:
    if (!window.has_astronomical_night) {
        window.astronomical_dusk = (window.nautical_dusk.value > 0) ? window.nautical_dusk : window.sunset;
        window.astronomical_dawn = (window.nautical_dawn.value > 0) ? window.nautical_dawn : window.sunrise;
    }

    return window;
}

} // namespace astro::ephemeris
