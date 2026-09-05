#pragma once

#include "astro/coordinates.hpp"
#include "astro/time.hpp"
#include "astro/units.hpp"
#include <optional>
#include <string>

namespace astro::ephemeris {

struct SunInfo {
    coordinates::EquatorialCoordinates coords;
    coordinates::HorizontalCoordinates horizontal;
};

enum class MoonPhaseType {
    NewMoon,
    WaxingCrescent,
    FirstQuarter,
    WaxingGibbous,
    FullMoon,
    WaningGibbous,
    ThirdQuarter,
    WaningCrescent
};

struct MoonInfo {
    coordinates::EquatorialCoordinates coords;
    coordinates::HorizontalCoordinates horizontal;
    double illuminated_fraction{0.0}; // 0.0 (New) to 1.0 (Full)
    MoonPhaseType phase_type{MoonPhaseType::NewMoon};
    std::string phase_name;
};

/**
 * @brief Astronomical night transitions for an observer on a given evening.
 */
struct NightWindow {
    time::JulianDate sunset{0.0};
    time::JulianDate civil_dusk{0.0};
    time::JulianDate nautical_dusk{0.0};
    time::JulianDate astronomical_dusk{0.0};

    time::JulianDate solar_midnight{0.0};

    time::JulianDate astronomical_dawn{0.0};
    time::JulianDate nautical_dawn{0.0};
    time::JulianDate civil_dawn{0.0};
    time::JulianDate sunrise{0.0};

    bool has_astronomical_night{true};
    bool sun_never_sets{false};
    bool sun_never_rises{false};
};

/**
 * @brief Computes Equatorial and Horizontal coordinates of the Sun.
 */
SunInfo get_sun_info(
    time::JulianDate jd,
    const coordinates::ObserverLocation& obs
);

/**
 * @brief Computes Equatorial coordinates, Horizontal coordinates, and phase of the Moon.
 */
MoonInfo get_moon_info(
    time::JulianDate jd,
    const coordinates::ObserverLocation& obs
);

/**
 * @brief Computes the twilight transition times for the night starting on the given UTC date.
 * @param date_midnight_utc Start of the local calendar day (or noon).
 * @param obs Observer coordinates.
 */
NightWindow calculate_night_window(
    time::JulianDate date_midnight_utc,
    const coordinates::ObserverLocation& obs
);

} // namespace astro::ephemeris
