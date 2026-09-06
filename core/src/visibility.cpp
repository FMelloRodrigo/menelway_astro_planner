#include "astro/visibility.hpp"
#include "astro/ephemeris.hpp"
#include <algorithm>
#include <cmath>
#include <cstdio>

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

YearlyVisibilityResult calculate_yearly_visibility(
    const coordinates::EquatorialCoordinates& target,
    const coordinates::ObserverLocation& obs,
    const VisibilityCriteria& criteria,
    int year
) {
    YearlyVisibilityResult result;
    result.theoretical_max_altitude_deg = 90.0 - std::abs(obs.latitude.value - target.dec.value);
    result.can_ever_reach_min_alt = (result.theoretical_max_altitude_deg >= criteria.min_altitude.value);

    static const char* kMonthNames[12] = {
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    };

    static const char* kFullMonthNames[12] = {
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    };

    result.months.resize(12);
    int peak_m = 0;
    double max_h = -1.0;

    for (int m = 1; m <= 12; ++m) {
        MonthVisibility mv;
        mv.month = m;
        mv.month_name = kMonthNames[m - 1];

        // Construct 15th of the month at 12:00:00 UTC
        int y = year;
        int mo = m;
        if (mo <= 2) {
            y -= 1;
            mo += 12;
        }
        int a = y / 100;
        int b = 2 - a + (a / 4);
        double jd_noon = static_cast<int>(365.25 * (y + 4716)) +
                         static_cast<int>(30.6001 * (mo + 1)) +
                         15 + b - 1524.5;

        time::JulianDate jd_mid{jd_noon};
        auto night = ephemeris::calculate_night_window(jd_mid, obs);

        if (night.sun_never_sets) {
            mv.hours_observable = 0.0;
            mv.peak_altitude_deg = -90.0;
            mv.is_observable = false;
        } else {
            time::JulianDate win_start = night.astronomical_dusk;
            time::JulianDate win_end = night.astronomical_dawn;

            // If no astronomical night, fallback to nautical twilight
            if (!night.has_astronomical_night) {
                win_start = night.nautical_dusk;
                win_end = night.nautical_dawn;
            }

            if (win_start.value >= win_end.value) {
                mv.hours_observable = 0.0;
                mv.peak_altitude_deg = -90.0;
                mv.is_observable = false;
            } else {
                VisibilityCriteria month_crit = criteria;
                month_crit.window_start = win_start;
                month_crit.window_end = win_end;

                auto vis = evaluate_visibility(target, obs, month_crit, /*step_minutes=*/15, /*include_samples=*/false);
                mv.hours_observable = vis.max_continuous_hours;
                mv.peak_altitude_deg = vis.peak_altitude.value;
                mv.is_observable = (vis.max_continuous_hours >= criteria.min_duration_hours) &&
                                   (vis.peak_altitude.value >= criteria.min_altitude.value);
            }
        }

        if (mv.hours_observable > max_h) {
            max_h = mv.hours_observable;
            peak_m = m;
        }

        result.months[m - 1] = mv;
    }

    result.peak_month = peak_m > 0 ? peak_m : 1;
    result.max_hours_in_peak = max_h > 0.0 ? max_h : 0.0;

    // Check if target can ever clear min_alt
    if (!result.can_ever_reach_min_alt) {
        char buf[128];
        snprintf(buf, sizeof(buf), "Never reaches %.0f° at this latitude (Max: %.1f°)",
                 criteria.min_altitude.value, result.theoretical_max_altitude_deg);
        result.best_window_summary = buf;
        result.best_window_start = 0;
        result.best_window_end = 0;
        return result;
    }

    // Count observable months
    int obs_count = 0;
    for (int i = 0; i < 12; ++i) {
        if (result.months[i].is_observable) obs_count++;
    }

    if (obs_count == 12) {
        result.best_window_start = 1;
        result.best_window_end = 12;
        result.best_window_summary = "Year-Round (Circumpolar)";
        return result;
    }

    if (obs_count == 0) {
        if (result.max_hours_in_peak > 0.0) {
            char buf[128];
            snprintf(buf, sizeof(buf), "Peak in %s (%.1fh, below %.1fh limit)",
                     kFullMonthNames[result.peak_month - 1], result.max_hours_in_peak, criteria.min_duration_hours);
            result.best_window_summary = buf;
        } else {
            result.best_window_summary = "Not observable with current filters";
        }
        result.best_window_start = result.peak_month;
        result.best_window_end = result.peak_month;
        return result;
    }

    // Find contiguous span containing peak_month (handling wrap-around, e.g. Oct-Feb)
    int p_idx = result.peak_month - 1;
    int start_idx = p_idx;
    int end_idx = p_idx;

    // Backward from peak
    for (int step = 1; step < 12; ++step) {
        int prev = (p_idx - step + 12) % 12;
        if (result.months[prev].is_observable) {
            start_idx = prev;
        } else {
            break;
        }
    }

    // Forward from peak
    for (int step = 1; step < 12; ++step) {
        int next = (p_idx + step) % 12;
        if (result.months[next].is_observable) {
            end_idx = next;
        } else {
            break;
        }
    }

    result.best_window_start = start_idx + 1; // 1-indexed
    result.best_window_end = end_idx + 1;     // 1-indexed

    if (start_idx == end_idx) {
        char buf[128];
        snprintf(buf, sizeof(buf), "%s only (Peak month)", kFullMonthNames[start_idx]);
        result.best_window_summary = buf;
    } else {
        char buf[128];
        snprintf(buf, sizeof(buf), "%s – %s (Peak: %s)",
                 kFullMonthNames[start_idx], kFullMonthNames[end_idx], kFullMonthNames[p_idx]);
        result.best_window_summary = buf;
    }

    return result;
}

} // namespace astro::visibility
