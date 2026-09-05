#include "astro/time.hpp"
#include <cmath>

namespace astro::time {

JulianDate datetime_to_julian_date(const DateTimeUtc& dt) {
    int Y = dt.year;
    int M = dt.month;
    double D = dt.day + (dt.hour + (dt.minute + dt.second / 60.0) / 60.0) / 24.0;

    if (M <= 2) {
        Y -= 1;
        M += 12;
    }

    int A = Y / 100;
    int B = 2 - A + (A / 4);

    double jd = std::floor(365.25 * (Y + 4716)) +
                std::floor(30.6001 * (M + 1)) +
                D + B - 1524.5;

    return JulianDate{jd};
}

DateTimeUtc julian_date_to_datetime(JulianDate jd) {
    double z = std::floor(jd.value + 0.5);
    double f = (jd.value + 0.5) - z;

    int alpha = static_cast<int>((z - 1867216.25) / 36524.25);
    double a = z + 1 + alpha - (alpha / 4);

    double b = a + 1524;
    double c = std::floor((b - 122.1) / 365.25);
    double d = std::floor(365.25 * c);
    double e = std::floor((b - d) / 30.6001);

    double day_fraction = b - d - std::floor(30.6001 * e) + f;
    int day = static_cast<int>(day_fraction);
    double frac = day_fraction - day;

    int month = static_cast<int>(e < 14 ? (e - 1) : (e - 13));
    int year = static_cast<int>(month > 2 ? (c - 4716) : (c - 4715));

    double total_hours = frac * 24.0;
    int hour = static_cast<int>(total_hours);
    double total_minutes = (total_hours - hour) * 60.0;
    int minute = static_cast<int>(total_minutes);
    double second = (total_minutes - minute) * 60.0;

    return DateTimeUtc{year, month, day, hour, minute, second};
}

JulianDate unix_to_julian_date(std::int64_t unix_timestamp_seconds) {
    return JulianDate{2440587.5 + (static_cast<double>(unix_timestamp_seconds) / 86400.0)};
}

std::int64_t julian_date_to_unix(JulianDate jd) {
    return static_cast<std::int64_t>(std::round((jd.value - 2440587.5) * 86400.0));
}

units::Hours greenwich_mean_sidereal_time(JulianDate jd) {
    // IAU 1982 / Meeus Astronomical Algorithms Ch. 12 formula
    double T = julian_centuries_j2000(jd);
    double theta0 = 280.46061837 +
                    360.98564736629 * (jd.value - 2451545.0) +
                    0.000387933 * T * T -
                    (T * T * T) / 38710000.0;

    units::Degrees theta_deg = units::normalize_degrees_360(units::Degrees{theta0});
    return units::degrees_to_hours(theta_deg);
}

units::Hours local_mean_sidereal_time(JulianDate jd, units::Degrees longitude) {
    units::Hours gmst = greenwich_mean_sidereal_time(jd);
    units::Hours lon_hours = units::degrees_to_hours(longitude);
    return units::normalize_hours_24(gmst + lon_hours);
}

} // namespace astro::time
