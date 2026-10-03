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

SunInfo get_sun_info(time::JulianDate jd, const coordinates::ObserverLocation& obs, bool apply_refraction) {
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
        eq, obs, jd, apply_refraction
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
        SunInfo sun = get_sun_info(time::JulianDate{mid}, obs, /*apply_refraction=*/false);
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
    double prev_alt = get_sun_info(time::JulianDate{prev_t}, obs, /*apply_refraction=*/false).horizontal.altitude.value;

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
        double cur_alt = get_sun_info(time::JulianDate{t}, obs, /*apply_refraction=*/false).horizontal.altitude.value;

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

namespace {

inline double solve_kepler(double M_deg, double e) {
    double M_rad = deg_to_rad(norm360(M_deg));
    double E = M_rad + e * std::sin(M_rad) * (1.0 + e * std::cos(M_rad));
    for (int iter = 0; iter < 15; ++iter) {
        double dE = (E - e * std::sin(E) - M_rad) / (1.0 - e * std::cos(E));
        E -= dE;
        if (std::abs(dE) < 1e-12) break;
    }
    return E;
}

} // namespace

PlanetInfo get_planet_info(
    PlanetId planet,
    time::JulianDate jd,
    const coordinates::ObserverLocation& obs
) {
    if (planet == PlanetId::Sun) {
        auto sun = get_sun_info(jd, obs);
        return PlanetInfo{
            PlanetId::Sun,
            "Sun",
            sun.coords,
            sun.horizontal,
            -26.74,
            1919.0,
            0.0,
            1.0,
            1.0,
            0.0
        };
    }

    if (planet == PlanetId::Moon) {
        auto moon = get_moon_info(jd, obs);
        double k = std::clamp(moon.illuminated_fraction, 0.005, 1.0);
        double moon_mag = -12.74 + 2.5 * std::log10(1.0 / k);
        return PlanetInfo{
            PlanetId::Moon,
            "Moon",
            moon.coords,
            moon.horizontal,
            moon_mag,
            1870.0,
            (1.0 - k) * 180.0,
            moon.illuminated_fraction,
            0.00257, // ~384,400 km in AU
            1.0
        };
    }

    double d = jd.value - 2451543.5;

    // Earth heliocentric position from solar orbital elements
    double w_sun = norm360(282.9404 + 4.70935e-5 * d);
    double a_sun = 1.000000;
    double e_sun = 0.016709 - 1.151e-9 * d;
    double M_sun = norm360(356.0470 + 0.9856002585 * d);

    double E_sun = solve_kepler(M_sun, e_sun);
    double xv_sun = a_sun * (std::cos(E_sun) - e_sun);
    double yv_sun = a_sun * (std::sqrt(1.0 - e_sun * e_sun) * std::sin(E_sun));
    double v_sun = std::atan2(yv_sun, xv_sun);
    double r_sun = std::sqrt(xv_sun * xv_sun + yv_sun * yv_sun);
    double lon_sun = norm360(rad_to_deg(v_sun) + w_sun);

    double x_e = r_sun * std::cos(deg_to_rad(lon_sun + 180.0));
    double y_e = r_sun * std::sin(deg_to_rad(lon_sun + 180.0));
    double z_e = 0.0;

    // Planet orbital parameters
    std::string name;
    double N0 = 0, Nd = 0, i0 = 0, id_val = 0, w0 = 0, wd = 0, a0 = 0, ad = 0, e0 = 0, ed = 0, M0 = 0, Md = 0;
    double diam0 = 0.0;

    switch (planet) {
        case PlanetId::Mercury:
            name = "Mercury";
            N0 = 48.3313; Nd = 3.24587e-5; i0 = 7.0047; id_val = 5.00e-8;
            w0 = 29.1241; wd = 1.01444e-5; a0 = 0.387098; ad = 0.0;
            e0 = 0.205635; ed = 5.59e-10; M0 = 168.6562; Md = 4.0923344368;
            diam0 = 6.74;
            break;
        case PlanetId::Venus:
            name = "Venus";
            N0 = 76.6799; Nd = 2.46590e-5; i0 = 3.3946; id_val = 2.75e-8;
            w0 = 54.8910; wd = 1.38374e-5; a0 = 0.723330; ad = 0.0;
            e0 = 0.006773; ed = -1.302e-9; M0 = 48.0052; Md = 1.6021302244;
            diam0 = 16.92;
            break;
        case PlanetId::Mars:
            name = "Mars";
            N0 = 49.5574; Nd = 2.11081e-5; i0 = 1.8497; id_val = -1.78e-8;
            w0 = 286.5016; wd = 2.92961e-5; a0 = 1.523688; ad = 0.0;
            e0 = 0.093405; ed = 2.516e-9; M0 = 18.6021; Md = 0.5240207766;
            diam0 = 9.36;
            break;
        case PlanetId::Jupiter:
            name = "Jupiter";
            N0 = 100.4542; Nd = 2.76854e-5; i0 = 1.3030; id_val = -1.557e-7;
            w0 = 273.8777; wd = 1.64505e-5; a0 = 5.20256; ad = 0.0;
            e0 = 0.048498; ed = 4.469e-9; M0 = 19.8950; Md = 0.0830853001;
            diam0 = 196.9;
            break;
        case PlanetId::Saturn:
            name = "Saturn";
            N0 = 113.6634; Nd = 2.38980e-5; i0 = 2.4886; id_val = -1.081e-7;
            w0 = 339.3939; wd = 2.97661e-5; a0 = 9.55475; ad = 0.0;
            e0 = 0.055546; ed = -9.499e-9; M0 = 316.9670; Md = 0.0334442282;
            diam0 = 165.6;
            break;
        case PlanetId::Uranus:
            name = "Uranus";
            N0 = 74.0005; Nd = 1.3978e-5; i0 = 0.7733; id_val = 1.9e-8;
            w0 = 96.6612; wd = 3.0565e-5; a0 = 19.18171; ad = -1.55e-8;
            e0 = 0.047318; ed = 7.45e-9; M0 = 142.5905; Md = 0.011725806;
            diam0 = 65.8;
            break;
        case PlanetId::Neptune:
            name = "Neptune";
            N0 = 131.7806; Nd = 3.0173e-5; i0 = 1.7700; id_val = -2.55e-7;
            w0 = 272.8461; wd = -6.027e-6; a0 = 30.05826; ad = 3.313e-8;
            e0 = 0.008606; ed = 2.15e-9; M0 = 260.2471; Md = 0.005995147;
            diam0 = 62.2;
            break;
        case PlanetId::Pluto:
        default:
            name = "Pluto";
            N0 = 110.30347; Nd = 0.0; i0 = 17.14175; id_val = 0.0;
            w0 = 113.76329; wd = 0.0; a0 = 39.48168677; ad = 0.0;
            e0 = 0.24880766; ed = 0.0; M0 = 14.53; Md = 0.00396;
            diam0 = 3.3;
            break;
    }

    double N = norm360(N0 + Nd * d);
    double i = deg_to_rad(i0 + id_val * d);
    double w = norm360(w0 + wd * d);
    double a = a0 + ad * d;
    double e = e0 + ed * d;
    double M = norm360(M0 + Md * d);

    double E = solve_kepler(M, e);
    double xv = a * (std::cos(E) - e);
    double yv = a * (std::sqrt(1.0 - e * e) * std::sin(E));
    double v = std::atan2(yv, xv);
    double r = std::sqrt(xv * xv + yv * yv);

    double u = norm360(rad_to_deg(v) + w);
    double N_rad = deg_to_rad(N);
    double u_rad = deg_to_rad(u);

    double xh = r * (std::cos(N_rad) * std::cos(u_rad) - std::sin(N_rad) * std::sin(u_rad) * std::cos(i));
    double yh = r * (std::sin(N_rad) * std::cos(u_rad) + std::cos(N_rad) * std::sin(u_rad) * std::cos(i));
    double zh = r * (std::sin(u_rad) * std::sin(i));

    double lon_h = norm360(rad_to_deg(std::atan2(yh, xh)));
    double lat_h = rad_to_deg(std::atan2(zh, std::sqrt(xh * xh + yh * yh)));

    // Planetary Perturbations for Jupiter, Saturn, Uranus
    double M_j = norm360(19.8950 + 0.0830853001 * d);
    double M_s = norm360(316.9670 + 0.0334442282 * d);
    double M_u = norm360(142.5905 + 0.011725806 * d);

    if (planet == PlanetId::Jupiter) {
        lon_h += (-0.332 * std::sin(deg_to_rad(2 * M_j - 5 * M_s - 67.6))
                  - 0.056 * std::sin(deg_to_rad(2 * M_j - 2 * M_s + 21.0))
                  + 0.042 * std::sin(deg_to_rad(3 * M_j - 5 * M_s + 21.0))
                  - 0.036 * std::sin(deg_to_rad(M_j - 2 * M_s))
                  + 0.022 * std::cos(deg_to_rad(M_j - M_s)));
    } else if (planet == PlanetId::Saturn) {
        lon_h += (0.812 * std::sin(deg_to_rad(2 * M_j - 5 * M_s - 67.6))
                  - 0.229 * std::cos(deg_to_rad(2 * M_j - 4 * M_s - 2.0))
                  + 0.119 * std::sin(deg_to_rad(M_j - 2 * M_s - 3.0)));
        lat_h += -0.020 * std::cos(deg_to_rad(2 * M_j - 4 * M_s - 2.0))
                 + 0.018 * std::sin(deg_to_rad(2 * M_j - 5 * M_s - 166.0));
    } else if (planet == PlanetId::Uranus) {
        lon_h += 0.040 * std::sin(deg_to_rad(M_s - 2 * M_u + 6.0))
                 + 0.035 * std::sin(deg_to_rad(M_s - 3 * M_u + 33.0));
    }

    xh = r * std::cos(deg_to_rad(lat_h)) * std::cos(deg_to_rad(lon_h));
    yh = r * std::cos(deg_to_rad(lat_h)) * std::sin(deg_to_rad(lon_h));
    zh = r * std::sin(deg_to_rad(lat_h));

    // Geocentric vector
    double X = xh - x_e;
    double Y = yh - y_e;
    double Z = zh - z_e;
    double dist = std::sqrt(X * X + Y * Y + Z * Z);

    // Obliquity of ecliptic
    double T_cent = (jd.value - 2451545.0) / 36525.0;
    double eps = deg_to_rad(obliquity_of_ecliptic(T_cent));

    double X_eq = X;
    double Y_eq = Y * std::cos(eps) - Z * std::sin(eps);
    double Z_eq = Y * std::sin(eps) + Z * std::cos(eps);

    double ra_deg = norm360(rad_to_deg(std::atan2(Y_eq, X_eq)));
    double dec_deg = rad_to_deg(std::atan2(Z_eq, std::sqrt(X_eq * X_eq + Y_eq * Y_eq)));

    // Phase angle and illuminated fraction
    double cos_fv = std::clamp((r * r + dist * dist - r_sun * r_sun) / (2.0 * r * dist), -1.0, 1.0);
    double fv = rad_to_deg(std::acos(cos_fv));
    double k = (1.0 + std::cos(deg_to_rad(fv))) / 2.0;

    // Visual magnitude
    double v_mag = 0.0;
    if (planet == PlanetId::Mercury) {
        v_mag = -0.42 + 5.0 * std::log10(r * dist) + 0.0380 * fv - 0.000273 * fv * fv + 0.000002 * fv * fv * fv;
    } else if (planet == PlanetId::Venus) {
        v_mag = -4.40 + 5.0 * std::log10(r * dist) + 0.0009 * fv + 0.000239 * fv * fv - 0.00000065 * fv * fv * fv;
    } else if (planet == PlanetId::Mars) {
        v_mag = -1.52 + 5.0 * std::log10(r * dist) + 0.016 * fv;
    } else if (planet == PlanetId::Jupiter) {
        v_mag = -9.40 + 5.0 * std::log10(r * dist) + 0.005 * fv;
    } else if (planet == PlanetId::Saturn) {
        // Saturn ring tilt contribution
        double B = std::asin(std::sin(deg_to_rad(28.06)) * std::cos(deg_to_rad(lat_h)) * std::sin(deg_to_rad(lon_h - 169.5))
                   - std::cos(deg_to_rad(28.06)) * std::sin(deg_to_rad(lat_h)));
        double ring_mag = -2.6 * std::sin(std::abs(B)) + 1.2 * std::sin(std::abs(B)) * std::sin(std::abs(B));
        v_mag = -8.88 + 5.0 * std::log10(r * dist) + 0.044 * fv + ring_mag;
    } else if (planet == PlanetId::Uranus) {
        v_mag = -7.19 + 5.0 * std::log10(r * dist);
    } else if (planet == PlanetId::Neptune) {
        v_mag = -6.87 + 5.0 * std::log10(r * dist);
    } else {
        v_mag = -1.0 + 5.0 * std::log10(r * dist);
    }

    double size_arcsec = (dist > 0.001) ? (diam0 / dist) : diam0;

    coordinates::EquatorialCoordinates eq_coords{
        units::degrees_to_hours(units::Degrees{ra_deg}),
        units::Degrees{dec_deg}
    };

    coordinates::HorizontalCoordinates horiz = coordinates::equatorial_to_horizontal(
        eq_coords, obs, jd, /*apply_refraction=*/true
    );

    return PlanetInfo{
        planet,
        name,
        eq_coords,
        horiz,
        v_mag,
        size_arcsec,
        fv,
        k,
        dist,
        r
    };
}

} // namespace astro::ephemeris

