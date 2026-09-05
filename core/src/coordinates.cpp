#include "astro/coordinates.hpp"
#include <algorithm>
#include <cmath>

namespace astro::coordinates {

units::Degrees atmospheric_refraction(units::Degrees true_alt) {
    double h = true_alt.value;
    if (h < -5.0) {
        return units::Degrees{0.0};
    }
    // Saemundsson (1986) formula for optical refraction in arcminutes:
    // R = 1.02 / tan(h + 10.3 / (h + 5.11))
    double term = h + 10.3 / (h + 5.11);
    double rad = term * (std::numbers::pi / 180.0);
    double r_arcmin = 1.02 / std::tan(rad);
    if (r_arcmin < 0.0) {
        r_arcmin = 0.0;
    }
    return units::Degrees{r_arcmin / 60.0};
}

HorizontalCoordinates equatorial_to_horizontal(
    const EquatorialCoordinates& eq,
    const ObserverLocation& obs,
    time::JulianDate jd,
    bool apply_refraction
) {
    // 1. Calculate Local Mean Sidereal Time
    units::Hours lmst = time::local_mean_sidereal_time(jd, obs.longitude);

    // 2. Hour Angle H = LMST - RA
    units::Hours ha = units::normalize_hours_24(lmst - eq.ra);
    units::Degrees ha_deg = units::hours_to_degrees(ha);

    // Radians
    double phi = units::to_radians(obs.latitude).value;
    double delta = units::to_radians(eq.dec).value;
    double H = units::to_radians(ha_deg).value;

    // 3. Altitude: sin(a) = sin(phi)*sin(delta) + cos(phi)*cos(delta)*cos(H)
    double sin_a = std::sin(phi) * std::sin(delta) +
                   std::cos(phi) * std::cos(delta) * std::cos(H);
    sin_a = std::clamp(sin_a, -1.0, 1.0);
    double alt_rad = std::asin(sin_a);
    units::Degrees true_alt = units::to_degrees(units::Radians{alt_rad});

    // 4. Azimuth: atan2(-sin(H), tan(delta)*cos(phi) - sin(phi)*cos(H))
    double y = -std::sin(H);
    double x = std::tan(delta) * std::cos(phi) - std::sin(phi) * std::cos(H);
    double az_rad = std::atan2(y, x);
    units::Degrees az = units::normalize_degrees_360(units::to_degrees(units::Radians{az_rad}));

    // 5. Refraction
    if (apply_refraction) {
        true_alt += atmospheric_refraction(true_alt);
    }

    return HorizontalCoordinates{true_alt, az};
}

units::Degrees angular_separation(
    const EquatorialCoordinates& c1,
    const EquatorialCoordinates& c2
) {
    double ra1 = units::to_radians(units::hours_to_degrees(c1.ra)).value;
    double dec1 = units::to_radians(c1.dec).value;
    double ra2 = units::to_radians(units::hours_to_degrees(c2.ra)).value;
    double dec2 = units::to_radians(c2.dec).value;

    double d_dec = dec2 - dec1;
    double d_ra = ra2 - ra1;

    double sin_half_ddec = std::sin(d_dec / 2.0);
    double sin_half_dra = std::sin(d_ra / 2.0);

    double u = sin_half_ddec * sin_half_ddec +
               std::cos(dec1) * std::cos(dec2) * sin_half_dra * sin_half_dra;

    u = std::clamp(u, 0.0, 1.0);
    double dist_rad = 2.0 * std::asin(std::sqrt(u));

    return units::to_degrees(units::Radians{dist_rad});
}

} // namespace astro::coordinates
