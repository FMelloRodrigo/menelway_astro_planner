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

    double max_alt = -999.0;
    time::JulianDate peak_t{0.0};

    time::JulianDate cur_block_start{0.0};
    time::JulianDate cur_block_end{0.0};

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

        // Moon separation (only computed if criteria filters on moon or samples are requested)
        units::Degrees moon_sep{180.0};
        if (criteria.min_moon_separation.value > 0.0 || include_samples) {
            auto moon = ephemeris::get_moon_info(cur_jd, obs);
            moon_sep = coordinates::angular_separation(target, moon.coords);
        }

        // Check criteria
        bool passes_alt = horiz.altitude.value >= criteria.min_altitude.value &&
                          horiz.altitude.value <= criteria.max_altitude.value;
        bool passes_az = criteria.azimuth_range.contains(horiz.azimuth);
        bool passes_quad = horizon::is_in_quadrant(horiz.azimuth, criteria.quadrant);
        bool passes_moon = moon_sep.value >= criteria.min_moon_separation.value;
        bool passes_custom_horizon = true;
        if (criteria.custom_horizon.has_value()) {
            passes_custom_horizon = criteria.custom_horizon->is_visible(horiz.altitude, horiz.azimuth);
        }

        bool instant_pass = passes_alt && passes_az && passes_quad && passes_moon && passes_custom_horizon;

        if (instant_pass) {
            if (cur_block_start.value == 0.0) {
                cur_block_start = cur_jd;
            }
            cur_block_end = cur_jd;
            if (moon_sep.value < min_moon_sep_while_visible) {
                min_moon_sep_while_visible = moon_sep.value;
            }

            double block_hours = (cur_block_end.value - cur_block_start.value) * 24.0;
            if (block_hours > longest_continuous_hours || best_block_start.value == 0.0) {
                longest_continuous_hours = block_hours;
                best_block_start = cur_block_start;
                best_block_end = cur_block_end;
            }
        } else {
            if (cur_block_start.value > 0.0) {
                double block_hours = (cur_block_end.value - cur_block_start.value) * 24.0;
                result.total_visible_hours += block_hours;
                cur_block_start = time::JulianDate{0.0};
                cur_block_end = time::JulianDate{0.0};
            }
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

    if (cur_block_start.value > 0.0) {
        double block_hours = (cur_block_end.value - cur_block_start.value) * 24.0;
        result.total_visible_hours += block_hours;
    }

    result.peak_altitude = units::Degrees{max_alt};
    result.peak_time = peak_t;
    result.transit_time = peak_t; // Peak altitude corresponds to meridian transit
    result.max_continuous_hours = longest_continuous_hours;
    result.visible_start = best_block_start;
    result.visible_end = best_block_end;
    result.min_moon_separation_during_visibility = units::Degrees{min_moon_sep_while_visible};
    result.meets_criteria = (best_block_start.value > 0.0) && (longest_continuous_hours >= criteria.min_duration_hours);

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

    bool is_leap = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
    int days_in_month[12] = {31, is_leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

    // Check if target can ever clear min_alt
    if (!result.can_ever_reach_min_alt) {
        char buf[128];
        snprintf(buf, sizeof(buf), "Never reaches %.0f° at this latitude (Max: %.1f°)",
                 criteria.min_altitude.value, result.theoretical_max_altitude_deg);
        result.best_window_summary = buf;
        result.best_window_start = 0;
        result.best_window_end = 0;
        result.start_month = 0;
        result.start_day = 0;
        result.end_month = 0;
        result.end_day = 0;
        result.peak_month = 0;
        result.peak_day = 0;
        result.total_observable_days = 0;
        result.months.resize(12);
        for (int m = 1; m <= 12; ++m) {
            result.months[m - 1].month = m;
            result.months[m - 1].month_name = kMonthNames[m - 1];
            result.months[m - 1].total_days_in_month = days_in_month[m - 1];
        }
        return result;
    }

    struct DayRecord {
        int month{1};
        int day{1};
        double hours{0.0};
        double peak_alt{-90.0};
        bool is_obs{false};
    };

    std::vector<DayRecord> all_days;
    all_days.reserve(366);

    // Simulate each day of the year
    for (int m = 1; m <= 12; ++m) {
        int num_days = days_in_month[m - 1];
        for (int d = 1; d <= num_days; ++d) {
            DayRecord dr;
            dr.month = m;
            dr.day = d;

            time::JulianDate jd_midnight_utc = time::datetime_to_julian_date({year, m, d, 0, 0, 0.0});
            auto night = ephemeris::calculate_night_window(jd_midnight_utc, obs);

            time::JulianDate win_start{0.0};
            time::JulianDate win_end{0.0};

            if (criteria.use_custom_time_window) {
                // Compute local Julian date of custom window start
                double local_fraction = (criteria.custom_start_hour + criteria.custom_start_minute / 60.0) / 24.0;
                if (criteria.custom_start_hour < 12) {
                    local_fraction += 1.0;
                }
                // Convert from local time to UTC
                double utc_start_jd = jd_midnight_utc.value + local_fraction - (static_cast<double>(criteria.utc_offset_minutes) / 1440.0);

                int start_mins = criteria.custom_start_hour * 60 + criteria.custom_start_minute;
                int end_mins = criteria.custom_end_hour * 60 + criteria.custom_end_minute;
                int diff_mins = end_mins - start_mins;
                if (diff_mins <= 0) diff_mins += 1440;

                double utc_end_jd = utc_start_jd + (static_cast<double>(diff_mins) / 1440.0);

                win_start = time::JulianDate{utc_start_jd};
                win_end = time::JulianDate{utc_end_jd};
            } else {
                if (!night.sun_never_sets) {
                    win_start = night.astronomical_dusk;
                    win_end = night.astronomical_dawn;
                    if (!night.has_astronomical_night) {
                        win_start = night.nautical_dusk;
                        win_end = night.nautical_dawn;
                    }
                }
            }

            if (win_start.value < win_end.value) {
                VisibilityCriteria day_crit = criteria;
                day_crit.window_start = win_start;
                day_crit.window_end = win_end;
                day_crit.min_moon_separation = units::Degrees{0.0}; // Seasonal visibility should not be masked by transient monthly moon orbits

                auto vis = evaluate_visibility(target, obs, day_crit, /*step_minutes=*/10, /*include_samples=*/false);
                dr.hours = vis.max_continuous_hours;
                dr.peak_alt = vis.peak_altitude.value;
                dr.is_obs = vis.meets_criteria;
            }

            all_days.push_back(dr);
        }
    }

    // Monthly aggregation
    result.months.resize(12);
    int total_obs_days = 0;
    int peak_day_idx = 0;
    double max_h = -1.0;

    int day_cursor = 0;
    for (int m = 1; m <= 12; ++m) {
        MonthVisibility mv;
        mv.month = m;
        mv.month_name = kMonthNames[m - 1];
        mv.total_days_in_month = days_in_month[m - 1];

        double month_max_h = 0.0;
        double month_max_alt = -90.0;
        int obs_count = 0;
        int first_obs_day = 0;
        int last_obs_day = 0;

        for (int d = 1; d <= days_in_month[m - 1]; ++d) {
            const auto& dr = all_days[day_cursor];
            if (dr.hours > month_max_h) {
                month_max_h = dr.hours;
            }
            if (dr.peak_alt > month_max_alt) {
                month_max_alt = dr.peak_alt;
            }
            if (dr.is_obs) {
                obs_count++;
                if (first_obs_day == 0) {
                    first_obs_day = d;
                }
                last_obs_day = d;
            }

            if (dr.hours > max_h) {
                max_h = dr.hours;
                peak_day_idx = day_cursor;
            }

            day_cursor++;
        }

        mv.hours_observable = month_max_h;
        mv.peak_altitude_deg = month_max_alt;
        mv.observable_days_count = obs_count;
        mv.start_day = first_obs_day;
        mv.end_day = last_obs_day;
        mv.is_observable = (obs_count > 0);

        total_obs_days += obs_count;
        result.months[m - 1] = mv;
    }

    result.total_observable_days = total_obs_days;
    result.max_hours_in_peak = max_h > 0.0 ? max_h : 0.0;
    result.peak_month = all_days[peak_day_idx].month;
    result.peak_day = all_days[peak_day_idx].day;

    int n_days = static_cast<int>(all_days.size());

    // All days observable => circumpolar / year-round
    if (total_obs_days == n_days) {
        result.start_month = 1;
        result.start_day = 1;
        result.end_month = 12;
        result.end_day = days_in_month[11];
        result.best_window_start = 1;
        result.best_window_end = 12;
        result.best_window_summary = "Year-Round (Circumpolar)";
        return result;
    }

    // No days meet criteria
    if (total_obs_days == 0) {
        if (result.max_hours_in_peak > 0.0) {
            char buf[128];
            snprintf(buf, sizeof(buf), "Peak on %s %d (%.1fh, below %.1fh limit)",
                     kMonthNames[result.peak_month - 1], result.peak_day,
                     result.max_hours_in_peak, criteria.min_duration_hours);
            result.best_window_summary = buf;
            result.start_month = result.peak_month;
            result.start_day = result.peak_day;
            result.end_month = result.peak_month;
            result.end_day = result.peak_day;
            result.best_window_start = result.peak_month;
            result.best_window_end = result.peak_month;
        } else {
            result.best_window_summary = "Not observable with current filters";
            result.start_month = 0;
            result.start_day = 0;
            result.end_month = 0;
            result.end_day = 0;
            result.peak_month = 0;
            result.peak_day = 0;
            result.best_window_start = 0;
            result.best_window_end = 0;
        }
        return result;
    }

    // Find contiguous span containing peak_day_idx (handling wrap-around across year boundary)
    int start_day_idx = peak_day_idx;
    int end_day_idx = peak_day_idx;

    // Backward from peak
    for (int step = 1; step < n_days; ++step) {
        int prev = (peak_day_idx - step + n_days) % n_days;
        if (all_days[prev].is_obs) {
            start_day_idx = prev;
        } else {
            break;
        }
    }

    // Forward from peak
    for (int step = 1; step < n_days; ++step) {
        int next = (peak_day_idx + step) % n_days;
        if (all_days[next].is_obs) {
            end_day_idx = next;
        } else {
            break;
        }
    }

    result.start_month = all_days[start_day_idx].month;
    result.start_day = all_days[start_day_idx].day;
    result.end_month = all_days[end_day_idx].month;
    result.end_day = all_days[end_day_idx].day;
    result.best_window_start = result.start_month;
    result.best_window_end = result.end_month;

    char buf[128];
    if (start_day_idx == end_day_idx) {
        snprintf(buf, sizeof(buf), "%s %d only (Peak: %.1fh)",
                 kMonthNames[result.start_month - 1], result.start_day, result.max_hours_in_peak);
    } else {
        snprintf(buf, sizeof(buf), "%s %d – %s %d (Peak: %s %d)",
                 kMonthNames[result.start_month - 1], result.start_day,
                 kMonthNames[result.end_month - 1], result.end_day,
                 kMonthNames[result.peak_month - 1], result.peak_day);
    }
    result.best_window_summary = buf;

    return result;
}

PeriodEvaluationContext prepare_period_context(
    const coordinates::ObserverLocation& obs,
    const VisibilityCriteria& criteria,
    time::JulianDate start_jd,
    time::JulianDate end_jd,
    int step_minutes
) {
    PeriodEvaluationContext ctx;
    int total_days = static_cast<int>(std::round(end_jd.value - start_jd.value)) + 1;
    if (total_days < 1) total_days = 1;
    ctx.total_days = total_days;

    double lat_rad = units::to_radians(obs.latitude).value;
    ctx.sin_lat = std::sin(lat_rad);
    ctx.cos_lat = std::cos(lat_rad);
    ctx.lat_deg = obs.latitude.value;

    int step = step_minutes > 0 ? step_minutes : 10;
    double step_days = static_cast<double>(step) / 1440.0;

    ctx.nights.resize(total_days);

    for (int i = 0; i < total_days; ++i) {
        auto& night_data = ctx.nights[i];
        double cur_jd_val = start_jd.value + static_cast<double>(i);
        auto dt = time::julian_date_to_datetime(time::JulianDate{cur_jd_val});
        time::JulianDate jd_midnight_utc = time::datetime_to_julian_date({dt.year, dt.month, dt.day, 0, 0, 0.0});
        auto night = ephemeris::calculate_night_window(jd_midnight_utc, obs);

        night_data.jd_midnight_utc = jd_midnight_utc;
        night_data.month = dt.month;
        night_data.day = dt.day;

        time::JulianDate win_start{0.0};
        time::JulianDate win_end{0.0};

        if (criteria.use_custom_time_window) {
            double local_fraction = (criteria.custom_start_hour + criteria.custom_start_minute / 60.0) / 24.0;
            if (criteria.custom_start_hour < 12) {
                local_fraction += 1.0;
            }
            double utc_start_jd = jd_midnight_utc.value + local_fraction - (static_cast<double>(criteria.utc_offset_minutes) / 1440.0);

            int start_mins = criteria.custom_start_hour * 60 + criteria.custom_start_minute;
            int end_mins = criteria.custom_end_hour * 60 + criteria.custom_end_minute;
            int diff_mins = end_mins - start_mins;
            if (diff_mins <= 0) diff_mins += 1440;

            double utc_end_jd = utc_start_jd + (static_cast<double>(diff_mins) / 1440.0);
            win_start = time::JulianDate{utc_start_jd};
            win_end = time::JulianDate{utc_end_jd};
        } else {
            if (!night.sun_never_sets) {
                win_start = night.astronomical_dusk;
                win_end = night.astronomical_dawn;
                if (!night.has_astronomical_night) {
                    win_start = night.nautical_dusk;
                    win_end = night.nautical_dawn;
                }
            }
        }

        night_data.win_start = win_start;
        night_data.win_end = win_end;

        if (win_start.value < win_end.value) {
            night_data.valid = true;
            int estimated_steps = static_cast<int>((win_end.value - win_start.value) / step_days) + 2;
            night_data.steps.reserve(estimated_steps);

            for (double t = win_start.value; t <= win_end.value + 1e-6; t += step_days) {
                time::JulianDate step_jd{t};
                units::Hours lmst = time::local_mean_sidereal_time(step_jd, obs.longitude);
                double lmst_rad = units::to_radians(units::hours_to_degrees(lmst)).value;
                night_data.steps.push_back({step_jd, lmst_rad});
            }
        } else {
            night_data.valid = false;
        }
    }

    return ctx;
}

PeriodVisibilityResult evaluate_period_visibility_fast(
    const coordinates::EquatorialCoordinates& target,
    const coordinates::ObserverLocation& obs,
    const VisibilityCriteria& criteria,
    const PeriodEvaluationContext& context,
    int step_minutes
) {
    (void)obs;
    (void)step_minutes;
    PeriodVisibilityResult result;
    result.total_period_days = context.total_days;

    double max_alt = 90.0 - std::abs(context.lat_deg - target.dec.value);
    if (max_alt < criteria.min_altitude.value) {
        return result;
    }

    double dec_rad = units::to_radians(target.dec).value;
    double sin_dec = std::sin(dec_rad);
    double cos_dec = std::cos(dec_rad);
    double ra_rad = units::to_radians(units::hours_to_degrees(target.ra)).value;

    double term_a = context.sin_lat * sin_dec;
    double term_b = context.cos_lat * cos_dec;

    if (std::abs(term_b) > 1e-7) {
        double sin_min_alt = std::sin(units::to_radians(criteria.min_altitude).value);
        double cos_H = (sin_min_alt - term_a) / term_b;
        if (cos_H > 1.0) {
            return result;
        }
        if (cos_H >= -1.0) {
            double H_max_rad = std::acos(cos_H);
            double max_possible_hours = 2.0 * H_max_rad * (12.0 / std::numbers::pi);
            if (max_possible_hours + 0.25 < criteria.min_duration_hours) {
                return result;
            }
        }
    }

    bool need_az = (criteria.azimuth_range.min_az.value > 0.0 || criteria.azimuth_range.max_az.value < 360.0) || 
                   criteria.quadrant != horizon::Quadrant::All || 
                   criteria.custom_horizon.has_value();
    double tan_dec = need_az ? std::tan(dec_rad) : 0.0;
    double az_term_c = tan_dec * context.cos_lat;
    double az_term_d = context.sin_lat;

    bool found_first = false;

    for (const auto& night : context.nights) {
        if (!night.valid || night.steps.empty()) continue;

        double night_max_alt = -999.0;
        time::JulianDate cur_block_start{0.0};
        time::JulianDate cur_block_end{0.0};
        double longest_continuous_hours = 0.0;

        for (const auto& step : night.steps) {
            double H = step.lmst_rad - ra_rad;
            double cos_H = std::cos(H);

            // sin(alt) = sin(phi)*sin(delta) + cos(phi)*cos(delta)*cos(H)
            double sin_a = term_a + term_b * cos_H;
            sin_a = std::clamp(sin_a, -1.0, 1.0);
            double alt_deg = std::asin(sin_a) * (180.0 / std::numbers::pi);

            // Saemundsson atmospheric refraction
            alt_deg += coordinates::atmospheric_refraction(units::Degrees{alt_deg}).value;

            if (alt_deg > night_max_alt) {
                night_max_alt = alt_deg;
            }

            bool passes_alt = alt_deg >= criteria.min_altitude.value &&
                              alt_deg <= criteria.max_altitude.value;

            bool instant_pass = passes_alt;
            if (instant_pass && need_az) {
                double sin_H = std::sin(H);
                double y = -sin_H;
                double x = az_term_c - az_term_d * cos_H;
                double az_rad = std::atan2(y, x);
                double az_deg = units::normalize_degrees_360(units::Degrees{az_rad * (180.0 / std::numbers::pi)}).value;
                units::Degrees az{az_deg};

                bool passes_az = criteria.azimuth_range.contains(az);
                bool passes_quad = horizon::is_in_quadrant(az, criteria.quadrant);
                bool passes_custom_horizon = true;
                if (criteria.custom_horizon.has_value()) {
                    passes_custom_horizon = criteria.custom_horizon->is_visible(units::Degrees{alt_deg}, az);
                }
                instant_pass = passes_az && passes_quad && passes_custom_horizon;
            }

            if (instant_pass) {
                if (cur_block_start.value == 0.0) {
                    cur_block_start = step.jd;
                }
                cur_block_end = step.jd;
                double block_hours = (cur_block_end.value - cur_block_start.value) * 24.0;
                if (block_hours > longest_continuous_hours) {
                    longest_continuous_hours = block_hours;
                }
            } else {
                cur_block_start = time::JulianDate{0.0};
                cur_block_end = time::JulianDate{0.0};
            }
        }

        bool meets_criteria = (longest_continuous_hours >= criteria.min_duration_hours);
        if (meets_criteria) {
            result.total_observable_days++;
            if (!found_first) {
                result.start_month = night.month;
                result.start_day = night.day;
                found_first = true;
            }
            result.end_month = night.month;
            result.end_day = night.day;

            if (longest_continuous_hours > result.max_hours_observable ||
                (longest_continuous_hours == result.max_hours_observable && night_max_alt > result.peak_altitude_deg)) {
                result.max_hours_observable = longest_continuous_hours;
                result.peak_altitude_deg = night_max_alt;
                result.peak_date = night.jd_midnight_utc;
            }
        }
    }

    if (result.total_observable_days > 0) {
        result.is_observable = true;
    }

    return result;
}

PeriodVisibilityResult evaluate_period_visibility(
    const coordinates::EquatorialCoordinates& target,
    const coordinates::ObserverLocation& obs,
    const VisibilityCriteria& criteria,
    time::JulianDate start_jd,
    time::JulianDate end_jd,
    int step_minutes
) {
    auto ctx = prepare_period_context(obs, criteria, start_jd, end_jd, step_minutes);
    return evaluate_period_visibility_fast(target, obs, criteria, ctx, step_minutes);
}

} // namespace astro::visibility
