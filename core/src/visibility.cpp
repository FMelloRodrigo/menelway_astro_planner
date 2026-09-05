#include "astro/visibility.hpp"
#include "astro/ephemeris.hpp"
#include <algorithm>
#include <cmath>

namespace astro::visibility {

TargetVisibilityResult evaluate_visibility(
    const coordinates::EquatorialCoordinates& target,
    const coordinates::ObserverLocation& obs,
    const VisibilityCriteria& criteria,
    int step_minutes,
    bool include_samples
) {
    TargetVisibilityResult result;

    if (criteria.window_start.value >= criteria.window_end.value) {
        return result;
    }

    double step_days = (static_cast<double>(step_minutes) / 1440.0);
    double step_hours = static_cast<double>(step_minutes) / 60.0;

    double max_alt = -999.0;
    time::JulianDate peak_t{0.0};

    double cur_continuous_hours = 0.0;
    time::JulianDate cur_block_start{0.0};

    double longest_continuous_hours = 0.0;
    time::JulianDate best_block_start{0.0};
    time::JulianDate best_block_end{0.0};

    double min_moon_sep_while_visible = 180.0;

    // Iterate through window
    for (double t = criteria.window_start.value; t <= criteria.window_end.value + 1e-6; t += step_days) {
        time::JulianDate cur_jd{t};
        auto horiz = coordinates::equatorial_to_horizontal(target, obs, cur_jd, /*apply_refraction=*/true);

        // Update peak altitude
        if (horiz.altitude.value > max_alt) {
            max_alt = horiz.altitude.value;
            peak_t = cur_jd;
        }

        // Moon separation
        auto moon = ephemeris::get_moon_info(cur_jd, obs);
        units::Degrees moon_sep = coordinates::angular_separation(target, moon.coords);

        // Check criteria
        bool passes_alt = horiz.altitude.value >= criteria.min_altitude.value;
        bool passes_az = criteria.azimuth_range.contains(horiz.azimuth);
        bool passes_quad = horizon::is_in_quadrant(horiz.azimuth, criteria.quadrant);
        bool passes_moon = moon_sep.value >= criteria.min_moon_separation.value;
        bool passes_custom_horizon = true;
        if (criteria.custom_horizon.has_value()) {
            passes_custom_horizon = criteria.custom_horizon->is_visible(horiz.altitude, horiz.azimuth);
        }

        bool instant_pass = passes_alt && passes_az && passes_quad && passes_moon && passes_custom_horizon;

        if (instant_pass) {
            if (cur_continuous_hours == 0.0) {
                cur_block_start = cur_jd;
            }
            cur_continuous_hours += step_hours;
            result.total_visible_hours += step_hours;
            if (moon_sep.value < min_moon_sep_while_visible) {
                min_moon_sep_while_visible = moon_sep.value;
            }

            if (cur_continuous_hours > longest_continuous_hours) {
                longest_continuous_hours = cur_continuous_hours;
                best_block_start = cur_block_start;
                best_block_end = cur_jd;
            }
        } else {
            cur_continuous_hours = 0.0;
        }

        if (include_samples) {
            result.samples.push_back({
                cur_jd,
                time::julian_date_to_unix(cur_jd),
                horiz.altitude,
                horiz.azimuth,
                moon_sep,
                instant_pass
            });
        }
    }

    result.peak_altitude = units::Degrees{max_alt};
    result.peak_time = peak_t;
    result.transit_time = peak_t; // Peak altitude corresponds to meridian transit
    result.max_continuous_hours = longest_continuous_hours;
    result.visible_start = best_block_start;
    result.visible_end = best_block_end;
    result.min_moon_separation_during_visibility = units::Degrees{min_moon_sep_while_visible};
    result.meets_criteria = (longest_continuous_hours >= criteria.min_duration_hours);

    return result;
}

std::vector<AltitudePoint> generate_altitude_curve(
    const coordinates::EquatorialCoordinates& target,
    const coordinates::ObserverLocation& obs,
    time::JulianDate start_jd,
    time::JulianDate end_jd,
    int step_minutes
) {
    std::vector<AltitudePoint> points;
    double step_days = (static_cast<double>(step_minutes) / 1440.0);

    for (double t = start_jd.value; t <= end_jd.value + 1e-6; t += step_days) {
        time::JulianDate cur_jd{t};
        auto horiz = coordinates::equatorial_to_horizontal(target, obs, cur_jd, /*apply_refraction=*/true);
        auto moon = ephemeris::get_moon_info(cur_jd, obs);
        units::Degrees moon_sep = coordinates::angular_separation(target, moon.coords);

        points.push_back({
            cur_jd,
            time::julian_date_to_unix(cur_jd),
            horiz.altitude,
            horiz.azimuth,
            moon_sep,
            horiz.altitude.value >= 0.0
        });
    }

    return points;
}

} // namespace astro::visibility
