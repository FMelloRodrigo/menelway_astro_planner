#pragma once

#include "astro/coordinates.hpp"
#include "astro/ephemeris.hpp"
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
    units::Degrees max_altitude{90.0};
    double min_duration_hours{2.0};
    time::JulianDate window_start{0.0};
    time::JulianDate window_end{0.0};
    units::Degrees min_moon_separation{0.0};
    horizon::AzimuthRange azimuth_range{units::Degrees{0.0}, units::Degrees{360.0}};
    horizon::Quadrant quadrant{horizon::Quadrant::All};
    std::optional<horizon::HorizonProfile> custom_horizon{std::nullopt};

    // Custom observing session window (if enabled, overrides full dusk-to-dawn window in simulations)
    bool use_custom_time_window{false};
    int custom_start_hour{21};
    int custom_start_minute{0};
    int custom_end_hour{23};
    int custom_end_minute{0};
    int utc_offset_minutes{0};
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
    double hours_observable{0.0}; // peak continuous hours during this month
    double peak_altitude_deg{0.0};// peak altitude reached during darkness
    bool is_observable{false};    // true if any day in month is observable
    int observable_days_count{0}; // number of days meeting criteria in this month
    int start_day{0};             // first observable day in this month (1-31, 0 if none)
    int end_day{0};               // last observable day in this month (1-31, 0 if none)
    int total_days_in_month{31};  // 28, 29, 30, or 31
};

struct YearlyVisibilityResult {
    double theoretical_max_altitude_deg{0.0}; // 90 - |lat - dec|
    bool can_ever_reach_min_alt{true};
    std::vector<MonthVisibility> months;      // 12 elements
    int peak_month{0};                        // 1-12
    int peak_day{0};                          // 1-31
    int start_month{0};                       // 1-12
    int start_day{0};                         // 1-31
    int end_month{0};                         // 1-12
    int end_day{0};                           // 1-31
    int best_window_start{0};                 // 1-12 (for backward compatibility)
    int best_window_end{0};                   // 1-12 (for backward compatibility)
    int total_observable_days{0};             // 0-366
    double max_hours_in_peak{0.0};
    std::string best_window_summary;          // e.g. "Sep 27 – Mar 22 (Peak: Dec 21)"
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

/**
 * @brief Computes 12-month visibility simulation for a planet given observer & criteria.
 */
YearlyVisibilityResult calculate_planet_yearly_visibility(
    ephemeris::PlanetId planet,
    const coordinates::ObserverLocation& obs,
    const VisibilityCriteria& criteria,
    int year = 2026
);

/**
 * @brief Generates high-density altitude curve samples for a Solar System planet.
 */
std::vector<AltitudePoint> generate_planet_altitude_curve(
    ephemeris::PlanetId planet,
    const coordinates::ObserverLocation& obs,
    time::JulianDate start_jd,
    time::JulianDate end_jd,
    int step_minutes = 5
);

struct PeriodVisibilityResult {

    bool is_observable{false};
    int total_observable_days{0};
    int total_period_days{0};
    time::JulianDate peak_date{0.0};
    double peak_altitude_deg{-90.0};
    double max_hours_observable{0.0};
    int start_month{0};
    int start_day{0};
    int end_month{0};
    int end_day{0};
};

struct PeriodNightData {
    time::JulianDate jd_midnight_utc{0.0};
    int month{0};
    int day{0};
    time::JulianDate win_start{0.0};
    time::JulianDate win_end{0.0};
    bool valid{false};

    struct StepPoint {
        time::JulianDate jd;
        double lmst_rad{0.0};
    };
    std::vector<StepPoint> steps;
};

struct PeriodEvaluationContext {
    int total_days{0};
    std::vector<PeriodNightData> nights;
    double sin_lat{0.0};
    double cos_lat{0.0};
    double lat_deg{0.0};
};

/**
 * @brief Precomputes solar ephemeris, night windows, and sidereal time steps for a period.
 * Reusable across thousands of candidate targets for massive speedups.
 */
PeriodEvaluationContext prepare_period_context(
    const coordinates::ObserverLocation& obs,
    const VisibilityCriteria& criteria,
    time::JulianDate start_jd,
    time::JulianDate end_jd,
    int step_minutes = 10
);

/**
 * @brief Fast evaluation of target visibility across a period using a precomputed context.
 */
PeriodVisibilityResult evaluate_period_visibility_fast(
    const coordinates::EquatorialCoordinates& target,
    const coordinates::ObserverLocation& obs,
    const VisibilityCriteria& criteria,
    const PeriodEvaluationContext& context,
    int step_minutes = 10
);

/**
 * @brief Computes visibility metrics for a target across a specific Julian Date range [start_jd, end_jd].
 */
PeriodVisibilityResult evaluate_period_visibility(
    const coordinates::EquatorialCoordinates& target,
    const coordinates::ObserverLocation& obs,
    const VisibilityCriteria& criteria,
    time::JulianDate start_jd,
    time::JulianDate end_jd,
    int step_minutes = 10
);

} // namespace astro::visibility

