#pragma once

#include "astro/units.hpp"
#include "astro/time.hpp"

namespace astro::coordinates {

struct ObserverLocation {
    units::Degrees latitude{0.0};
    units::Degrees longitude{0.0}; // East positive, West negative
    double elevation_meters{0.0};
};

struct EquatorialCoordinates {
    units::Hours ra{0.0};        // Right Ascension [0, 24h)
    units::Degrees dec{0.0};     // Declination [-90, +90]
};

struct HorizontalCoordinates {
    units::Degrees altitude{0.0}; // Altitude [-90, +90] above horizon
    units::Degrees azimuth{0.0};  // Azimuth [0, 360), 0=North, 90=East, 180=South, 270=West
};

/**
 * @brief Converts Equatorial J2000 coordinates to topocentric Horizontal coordinates.
 * @param eq Target Equatorial coordinates (RA, Dec).
 * @param obs Observer geographical location.
 * @param jd Time of observation as Julian Date.
 * @param apply_refraction Whether to add atmospheric refraction correction.
 */
HorizontalCoordinates equatorial_to_horizontal(
    const EquatorialCoordinates& eq,
    const ObserverLocation& obs,
    time::JulianDate jd,
    bool apply_refraction = true
);

/**
 * @brief Atmospheric refraction correction in degrees (Saemundsson formula).
 * @param true_alt Geometric / true altitude in degrees.
 * @return Refraction angle to add to true altitude (0 if deeply below horizon).
 */
units::Degrees atmospheric_refraction(units::Degrees true_alt);

/**
 * @brief Angular distance between two points on the celestial sphere.
 */
units::Degrees angular_separation(
    const EquatorialCoordinates& c1,
    const EquatorialCoordinates& c2
);

} // namespace astro::coordinates
