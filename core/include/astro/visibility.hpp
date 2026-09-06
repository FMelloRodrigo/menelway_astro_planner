#pragma once

#include "astro/coordinates.hpp"
#include "astro/horizon.hpp"
#include "astro/time.hpp"
#include "astro/units.hpp"
#include <optional>
#include <vector>

namespace astro::visibility {

struct AltitudePoint {
    time::JulianDate jd{0.0};
    std::int64_t timestamp_utc{0};
    units::Degrees altitude{0.0};
    units::Degrees azimuth{0.0};
    units::Degrees moon_separation{0.0};
    bool meets_instant_criteria{false};
};

struct VisibilityCriteria {
    units::Degrees min_altitude{30.0};
    double min_duration_hours{2.0};
    time::JulianDate window_start{0.0};
    time::JulianDate window_end{0.0};
    units::Degrees min_moon_separation{0.0};
    horizon::AzimuthRange azimuth_range{units::Degrees{0.0}, units::Degrees{360.0}};
    horizon::Quadrant quadrant{horizon::Quadrant::All};
    std::optional<horizon::HorizonProfile> custom_horizon{std::nullopt};
};

struct TargetVisibilityResult {
    bool meets_criteria{false};
    units::Degrees peak_altitude{0.0};
    time::JulianDate peak_time{0.0};
    time::JulianDate transit_time{0.0};
    double max_continuous_hours{0.0};
    double total_visible_hours{0.0};
    units::Degrees min_moon_separation_during_visibility{180.0};
    time::JulianDate visible_start{0.0};
    time::JulianDate visible_end{0.0};
    std::vector<AltitudePoint> samples;
};

/**
 * @brief Evaluates target visibility over a specified window against criteria.
 * @param target Equatorial coordinates of the target.
 * @param obs Observer geographical coordinates.
 * @param criteria Filter constraints (min alt, min duration, azimuth, moon separation).
 * @param step_minutes Step size for sampling the altitude curve (typically 5-10 min).
 * @param include_samples If true, populates samples vector for plotting curves.
 */
TargetVisibilityResult evaluate_visibility(
    const coordinates::EquatorialCoordinates& target,
    const coordinates::ObserverLocation& obs,
    const VisibilityCriteria& criteria,
    int step_minutes = 5,
    bool include_samples = false
);

/**
 * @brief Generates high-density altitude curve samples for charting.
 */
std::vector<AltitudePoint> generate_altitude_curve(
    const coordinates::EquatorialCoordinates& target,
    const coordinates::ObserverLocation& obs,
    time::JulianDate start_jd,
    time::JulianDate end_jd,
    int step_minutes = 5
);

struct MonthVisibility {
    int month{1};                 // 1 = Jan, 12 = Dec
    std::string month_name;       // "Jan", "Feb", etc.
    double hours_observable{0.0}; // continuous hours meeting criteria during darkness
    double peak_altitude_deg{0.0};// peak altitude reached during darkness
    bool is_observable{false};    // true if hours_observable >= min_duration
};

struct YearlyVisibilityResult {
    double theoretical_max_altitude_deg{0.0}; // 90 - |lat - dec|
    bool can_ever_reach_min_alt{true};
    std::vector<MonthVisibility> months;      // 12 elements
    int peak_month{0};                        // 1-12
    int best_window_start{0};                 // 1-12
    int best_window_end{0};                   // 1-12
    double max_hours_in_peak{0.0};
    std::string best_window_summary;          // e.g. "October – February (Peak: December)"
};

/**
 * @brief Computes 12-month visibility simulation for a target given observer & criteria.
 */
YearlyVisibilityResult calculate_yearly_visibility(
    const coordinates::EquatorialCoordinates& target,
    const coordinates::ObserverLocation& obs,
    const VisibilityCriteria& criteria,
    int year = 2026
);

} // namespace astro::visibility

