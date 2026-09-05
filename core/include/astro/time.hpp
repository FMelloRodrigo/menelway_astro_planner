#pragma once

#include "astro/units.hpp"
#include <chrono>
#include <cstdint>
#include <string>

namespace astro::time {

struct DateTimeUtc {
    int year{2000};
    int month{1};       // 1-12
    int day{1};         // 1-31
    int hour{0};        // 0-23
    int minute{0};      // 0-59
    double second{0.0}; // 0-59.999...
};

/**
 * @brief Represents a Julian Date (fractional days since noon Jan 1, 4713 BC).
 */
struct JulianDate {
    double value{2451545.0}; // Default: J2000.0 epoch

    constexpr JulianDate() = default;
    constexpr explicit JulianDate(double v) : value(v) {}

    constexpr auto operator<=>(const JulianDate&) const = default;

    constexpr JulianDate operator+(double days) const { return JulianDate{value + days}; }
    constexpr JulianDate operator-(double days) const { return JulianDate{value - days}; }
    constexpr double operator-(JulianDate o) const { return value - o.value; }

    constexpr JulianDate& operator+=(double days) { value += days; return *this; }
    constexpr JulianDate& operator-=(double days) { value -= days; return *this; }
};

// Conversions
JulianDate datetime_to_julian_date(const DateTimeUtc& dt);
DateTimeUtc julian_date_to_datetime(JulianDate jd);

JulianDate unix_to_julian_date(std::int64_t unix_timestamp_seconds);
std::int64_t julian_date_to_unix(JulianDate jd);

/**
 * @brief Number of Julian centuries of 36525 ephemeris days since J2000.0.
 */
constexpr double julian_centuries_j2000(JulianDate jd) {
    return (jd.value - 2451545.0) / 36525.0;
}

/**
 * @brief Greenwich Mean Sidereal Time (GMST) at Julian Date.
 */
units::Hours greenwich_mean_sidereal_time(JulianDate jd);

/**
 * @brief Local Mean Sidereal Time (LMST) at Julian Date for observer longitude.
 * @param longitude Observer longitude (East positive, West negative).
 */
units::Hours local_mean_sidereal_time(JulianDate jd, units::Degrees longitude);

} // namespace astro::time
