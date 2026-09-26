#include "astro_capi.h"
#include "astro/coordinates.hpp"
#include "astro/ephemeris.hpp"
#include "astro/horizon.hpp"
#include "astro/storage.hpp"
#include "astro/time.hpp"
#include "astro/units.hpp"

#include <cstring>
#include <deque>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

struct AstroEngineContext {
    std::unique_ptr<astro::storage::SqliteStorage> storage;
    std::string last_error;
    std::string cached_moon_phase;
};

struct AstroTargetListImpl {
    AstroTargetList public_list;
    std::vector<AstroTargetItem> items;
    std::deque<std::string> string_pool;
};

struct AstroPeriodTargetListImpl {
    AstroPeriodTargetList public_list;
    std::vector<AstroPeriodTargetItem> items;
    std::deque<std::string> string_pool;
};

struct AstroCurveDataImpl {
    AstroCurveData public_curve;
    std::vector<AstroAltitudePoint> points;
};

static std::vector<std::string> split_csv(const char* csv) {
    std::vector<std::string> result;
    if (!csv || *csv == '\0') return result;
    std::stringstream ss(csv);
    std::string item;
    while (std::getline(ss, item, ',')) {
        // Trim
        size_t start = item.find_first_not_of(" \t\r\n");
        size_t end = item.find_last_not_of(" \t\r\n");
        if (start != std::string::npos && end != std::string::npos) {
            result.push_back(item.substr(start, end - start + 1));
        }
    }
    return result;
}

static char* duplicate_string(const std::string& str) {
    char* copy = static_cast<char*>(malloc(str.size() + 1));
    if (copy) {
        std::memcpy(copy, str.c_str(), str.size() + 1);
    }
    return copy;
}

static void apply_criteria_extra(const AstroFilterCriteria* criteria, astro::visibility::VisibilityCriteria& vis_crit) {
    if (!criteria) return;
    if (criteria->max_altitude_deg > 0.0) {
        vis_crit.max_altitude = astro::units::Degrees{criteria->max_altitude_deg};
    }
    if (criteria->use_custom_horizon != 0 &&
        criteria->horizon_points_count > 0 &&
        criteria->horizon_azimuths &&
        criteria->horizon_altitudes) {
        astro::horizon::HorizonProfile profile;
        for (int32_t i = 0; i < criteria->horizon_points_count; ++i) {
            profile.add_point(
                astro::units::Degrees{criteria->horizon_azimuths[i]},
                astro::units::Degrees{criteria->horizon_altitudes[i]}
            );
        }
        vis_crit.custom_horizon = std::move(profile);
    }
}

AstroEngine* astro_engine_create(const char* db_path) {
    try {
        auto ctx = std::make_unique<AstroEngineContext>();
        ctx->storage = std::make_unique<astro::storage::SqliteStorage>(db_path ? db_path : "");
        if (!ctx->storage->is_open()) {
            return nullptr;
        }
        return reinterpret_cast<AstroEngine*>(ctx.release());
    } catch (const std::exception& e) {
        return nullptr;
    }
}

void astro_engine_destroy(AstroEngine* engine) {
    if (engine) {
        delete reinterpret_cast<AstroEngineContext*>(engine);
    }
}

const char* astro_engine_get_last_error(AstroEngine* engine) {
    if (!engine) return "Engine is null";
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);
    return ctx->last_error.c_str();
}

int32_t astro_get_night_summary(
    AstroEngine* engine,
    const AstroObserver* observer,
    int64_t date_timestamp_utc,
    AstroNightSummary* out_summary
) {
    if (!engine || !observer || !out_summary) return 0;
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);

    try {
        astro::coordinates::ObserverLocation obs{
            astro::units::Degrees{observer->latitude_deg},
            astro::units::Degrees{observer->longitude_deg},
            observer->elevation_m
        };

        astro::time::JulianDate jd = astro::time::unix_to_julian_date(date_timestamp_utc);
        auto night = astro::ephemeris::calculate_night_window(jd, obs);
        auto moon = astro::ephemeris::get_moon_info(night.solar_midnight, obs);

        out_summary->sunset_utc = astro::time::julian_date_to_unix(night.sunset);
        out_summary->civil_dusk_utc = astro::time::julian_date_to_unix(night.civil_dusk);
        out_summary->nautical_dusk_utc = astro::time::julian_date_to_unix(night.nautical_dusk);
        out_summary->astronomical_dusk_utc = astro::time::julian_date_to_unix(night.astronomical_dusk);
        out_summary->solar_midnight_utc = astro::time::julian_date_to_unix(night.solar_midnight);
        out_summary->astronomical_dawn_utc = astro::time::julian_date_to_unix(night.astronomical_dawn);
        out_summary->nautical_dawn_utc = astro::time::julian_date_to_unix(night.nautical_dawn);
        out_summary->civil_dawn_utc = astro::time::julian_date_to_unix(night.civil_dawn);
        out_summary->sunrise_utc = astro::time::julian_date_to_unix(night.sunrise);

        out_summary->moon_illumination = moon.illuminated_fraction;
        ctx->cached_moon_phase = moon.phase_name;
        out_summary->moon_phase_name = ctx->cached_moon_phase.c_str();
        out_summary->has_astronomical_night = night.has_astronomical_night ? 1 : 0;

        return 1;
    } catch (const std::exception& e) {
        ctx->last_error = e.what();
        return 0;
    }
}

AstroTargetList* astro_filter_targets(
    AstroEngine* engine,
    const AstroObserver* observer,
    const AstroFilterCriteria* criteria,
    int32_t step_minutes
) {
    if (!engine || !observer || !criteria) return nullptr;
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);

    try {
        astro::coordinates::ObserverLocation obs{
            astro::units::Degrees{observer->latitude_deg},
            astro::units::Degrees{observer->longitude_deg},
            observer->elevation_m
        };

        astro::catalog::DsoFilterOptions filter_opts;
        filter_opts.catalogs = split_csv(criteria->catalogs_csv);
        filter_opts.object_types = split_csv(criteria->object_types_csv);
        if (criteria->search_query && criteria->search_query[0] != '\0') {
            filter_opts.search_query = criteria->search_query;
        }
        if (criteria->max_magnitude < 900.0) {
            filter_opts.max_magnitude = criteria->max_magnitude;
        }
        if (criteria->min_magnitude > -900.0) {
            filter_opts.min_magnitude = criteria->min_magnitude;
        }
        if (criteria->min_size_arcmin > 0.0) {
            filter_opts.min_size_arcmin = criteria->min_size_arcmin;
        }
        if (criteria->max_size_arcmin < 90000.0) {
            filter_opts.max_size_arcmin = criteria->max_size_arcmin;
        }
        filter_opts.limit = criteria->limit > 0 ? criteria->limit : 500;
        filter_opts.offset = criteria->offset;

        astro::visibility::VisibilityCriteria vis_crit;
        vis_crit.min_altitude = astro::units::Degrees{criteria->min_altitude_deg};
        vis_crit.min_duration_hours = criteria->min_duration_hours;
        vis_crit.window_start = astro::time::unix_to_julian_date(criteria->window_start_utc);
        vis_crit.window_end = astro::time::unix_to_julian_date(criteria->window_end_utc);
        vis_crit.min_moon_separation = astro::units::Degrees{criteria->min_moon_separation_deg};
        vis_crit.azimuth_range = astro::horizon::AzimuthRange{
            astro::units::Degrees{criteria->min_azimuth_deg},
            astro::units::Degrees{criteria->max_azimuth_deg}
        };
        vis_crit.quadrant = static_cast<astro::horizon::Quadrant>(criteria->quadrant);
        apply_criteria_extra(criteria, vis_crit);

        int step = step_minutes > 0 ? step_minutes : 10;
        auto results = ctx->storage->filter_targets(obs, filter_opts, vis_crit, step);

        auto impl = std::make_unique<AstroTargetListImpl>();
        impl->items.reserve(results.size());
        // String pool uses std::deque to guarantee pointer stability across push_back calls

        auto intern_str = [&](const std::string& s) -> const char* {
            if (s.empty()) return "";
            impl->string_pool.push_back(s);
            return impl->string_pool.back().c_str();
        };

        for (const auto& r : results) {
            AstroTargetItem item{};
            item.id = r.dso.id;
            item.name = intern_str(r.dso.name);
            item.messier = intern_str(r.dso.messier.value_or(""));
            item.caldwell = intern_str(r.dso.caldwell.value_or(""));
            item.arp = intern_str(r.dso.arp.value_or(""));
            item.herschel = intern_str(r.dso.herschel.value_or(""));
            item.catalog = intern_str(r.dso.catalog);
            item.object_type = intern_str(r.dso.object_type);
            item.constellation = intern_str(r.dso.constellation);
            item.ra_hours = r.dso.coordinates.ra.value;
            item.dec_degrees = r.dso.coordinates.dec.value;
            item.magnitude = r.dso.magnitude.value_or(999.0);
            item.major_axis_arcmin = r.dso.major_axis_arcmin.value_or(-1.0);
            item.position_angle_deg = r.dso.position_angle_deg.value_or(-1.0);
            item.surface_brightness = r.dso.surface_brightness.value_or(-1.0);
            item.common_name = intern_str(r.dso.common_names.value_or(""));
            item.peak_altitude_deg = r.visibility.peak_altitude.value;
            item.visible_duration_hours = r.visibility.max_continuous_hours;
            item.transit_utc = astro::time::julian_date_to_unix(r.visibility.transit_time);
            item.visible_start_utc = astro::time::julian_date_to_unix(r.visibility.visible_start);
            item.visible_end_utc = astro::time::julian_date_to_unix(r.visibility.visible_end);
            item.min_moon_sep_deg = r.visibility.min_moon_separation_during_visibility.value;
            item.meets_criteria = r.visibility.meets_criteria ? 1 : 0;

            impl->items.push_back(item);
        }

        impl->public_list.items = impl->items.data();
        impl->public_list.count = impl->items.size();

        return reinterpret_cast<AstroTargetList*>(impl.release());
    } catch (const std::exception& e) {
        ctx->last_error = e.what();
        return nullptr;
    }
}

void astro_free_target_list(AstroTargetList* list) {
    if (list) {
        delete reinterpret_cast<AstroTargetListImpl*>(list);
    }
}

AstroPeriodTargetList* astro_filter_targets_period(
    AstroEngine* engine,
    const AstroObserver* observer,
    const AstroFilterCriteria* criteria,
    int64_t period_start_utc,
    int64_t period_end_utc,
    int32_t step_minutes
) {
    if (!engine || !observer || !criteria) return nullptr;
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);

    try {
        astro::coordinates::ObserverLocation obs{
            astro::units::Degrees{observer->latitude_deg},
            astro::units::Degrees{observer->longitude_deg},
            observer->elevation_m
        };

        astro::catalog::DsoFilterOptions filter_opts;
        filter_opts.catalogs = split_csv(criteria->catalogs_csv);
        filter_opts.object_types = split_csv(criteria->object_types_csv);
        if (criteria->search_query && criteria->search_query[0] != '\0') {
            filter_opts.search_query = criteria->search_query;
        }
        if (criteria->max_magnitude < 900.0) {
            filter_opts.max_magnitude = criteria->max_magnitude;
        }
        if (criteria->min_magnitude > -900.0) {
            filter_opts.min_magnitude = criteria->min_magnitude;
        }
        if (criteria->min_size_arcmin > 0.0) {
            filter_opts.min_size_arcmin = criteria->min_size_arcmin;
        }
        if (criteria->max_size_arcmin < 90000.0) {
            filter_opts.max_size_arcmin = criteria->max_size_arcmin;
        }
        filter_opts.limit = criteria->limit > 0 ? criteria->limit : 500;
        filter_opts.offset = criteria->offset;

        astro::visibility::VisibilityCriteria vis_crit;
        vis_crit.min_altitude = astro::units::Degrees{criteria->min_altitude_deg};
        vis_crit.min_duration_hours = criteria->min_duration_hours;
        vis_crit.min_moon_separation = astro::units::Degrees{criteria->min_moon_separation_deg};
        vis_crit.azimuth_range = astro::horizon::AzimuthRange{
            astro::units::Degrees{criteria->min_azimuth_deg},
            astro::units::Degrees{criteria->max_azimuth_deg}
        };
        vis_crit.quadrant = static_cast<astro::horizon::Quadrant>(criteria->quadrant);
        vis_crit.use_custom_time_window = criteria->use_custom_time_window != 0;
        vis_crit.custom_start_hour = criteria->custom_start_hour;
        vis_crit.custom_start_minute = criteria->custom_start_minute;
        vis_crit.custom_end_hour = criteria->custom_end_hour;
        vis_crit.custom_end_minute = criteria->custom_end_minute;
        vis_crit.utc_offset_minutes = criteria->utc_offset_minutes;
        apply_criteria_extra(criteria, vis_crit);

        astro::time::JulianDate start_jd = astro::time::unix_to_julian_date(period_start_utc);
        astro::time::JulianDate end_jd = astro::time::unix_to_julian_date(period_end_utc);

        int step = step_minutes > 0 ? step_minutes : 10;
        auto results = ctx->storage->filter_targets_period(obs, filter_opts, vis_crit, start_jd, end_jd, step);

        auto impl = std::make_unique<AstroPeriodTargetListImpl>();
        impl->items.reserve(results.size());
        // String pool uses std::deque to guarantee pointer stability across push_back calls

        auto intern_str = [&](const std::string& s) -> const char* {
            if (s.empty()) return "";
            impl->string_pool.push_back(s);
            return impl->string_pool.back().c_str();
        };

        for (const auto& r : results) {
            AstroPeriodTargetItem item{};
            item.id = r.dso.id;
            item.name = intern_str(r.dso.name);
            item.messier = intern_str(r.dso.messier.value_or(""));
            item.caldwell = intern_str(r.dso.caldwell.value_or(""));
            item.arp = intern_str(r.dso.arp.value_or(""));
            item.herschel = intern_str(r.dso.herschel.value_or(""));
            item.catalog = intern_str(r.dso.catalog);
            item.object_type = intern_str(r.dso.object_type);
            item.constellation = intern_str(r.dso.constellation);
            item.ra_hours = r.dso.coordinates.ra.value;
            item.dec_degrees = r.dso.coordinates.dec.value;
            item.magnitude = r.dso.magnitude.value_or(999.0);
            item.major_axis_arcmin = r.dso.major_axis_arcmin.value_or(-1.0);
            item.position_angle_deg = r.dso.position_angle_deg.value_or(-1.0);
            item.surface_brightness = r.dso.surface_brightness.value_or(-1.0);
            item.common_name = intern_str(r.dso.common_names.value_or(""));
            item.peak_altitude_deg = r.visibility.peak_altitude_deg;
            item.max_hours_observable = r.visibility.max_hours_observable;
            item.peak_date_utc = astro::time::julian_date_to_unix(r.visibility.peak_date);
            item.observable_days_count = r.visibility.total_observable_days;
            item.total_period_days = r.visibility.total_period_days;
            item.start_month = r.visibility.start_month;
            item.start_day = r.visibility.start_day;
            item.end_month = r.visibility.end_month;
            item.end_day = r.visibility.end_day;
            item.is_observable = r.visibility.is_observable ? 1 : 0;

            impl->items.push_back(item);
        }

        impl->public_list.items = impl->items.data();
        impl->public_list.count = impl->items.size();

        return reinterpret_cast<AstroPeriodTargetList*>(impl.release());
    } catch (const std::exception& e) {
        ctx->last_error = e.what();
        return nullptr;
    }
}

void astro_free_period_target_list(AstroPeriodTargetList* list) {
    if (list) {
        delete reinterpret_cast<AstroPeriodTargetListImpl*>(list);
    }
}

AstroCurveData* astro_generate_curve(
    AstroEngine* engine,
    int64_t target_id,
    const AstroObserver* observer,
    int64_t start_utc,
    int64_t end_utc,
    int32_t step_minutes
) {
    if (!engine || !observer) return nullptr;
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);

    try {
        auto dso = ctx->storage->get_object_by_id(target_id);
        if (!dso) {
            ctx->last_error = "Target ID not found";
            return nullptr;
        }

        astro::coordinates::ObserverLocation obs{
            astro::units::Degrees{observer->latitude_deg},
            astro::units::Degrees{observer->longitude_deg},
            observer->elevation_m
        };

        auto start_jd = astro::time::unix_to_julian_date(start_utc);
        auto end_jd = astro::time::unix_to_julian_date(end_utc);

        int step = step_minutes > 0 ? step_minutes : 5;
        auto points = astro::visibility::generate_altitude_curve(
            dso->coordinates, obs, start_jd, end_jd, step
        );

        auto impl = std::make_unique<AstroCurveDataImpl>();
        impl->points.reserve(points.size());

        for (const auto& p : points) {
            AstroAltitudePoint ap{};
            ap.timestamp_utc = p.timestamp_utc;
            ap.altitude_deg = p.altitude.value;
            ap.azimuth_deg = p.azimuth.value;
            ap.moon_separation_deg = p.moon_separation.value;
            ap.meets_criteria = p.meets_instant_criteria ? 1 : 0;
            impl->points.push_back(ap);
        }

        impl->public_curve.points = impl->points.data();
        impl->public_curve.count = impl->points.size();

        return reinterpret_cast<AstroCurveData*>(impl.release());
    } catch (const std::exception& e) {
        ctx->last_error = e.what();
        return nullptr;
    }
}

void astro_free_curve_data(AstroCurveData* curve) {
    if (curve) {
        delete reinterpret_cast<AstroCurveDataImpl*>(curve);
    }
}

int64_t astro_create_observing_list(
    AstroEngine* engine,
    const char* name,
    const char* description,
    const char* session_date
) {
    if (!engine || !name) return -1;
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);
    return ctx->storage->create_list(
        name,
        description ? description : "",
        session_date ? session_date : ""
    );
}

int32_t astro_delete_observing_list(AstroEngine* engine, int64_t list_id) {
    if (!engine) return 0;
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);
    return ctx->storage->delete_list(list_id) ? 1 : 0;
}

int32_t astro_add_to_observing_list(
    AstroEngine* engine,
    int64_t list_id,
    int64_t dso_id,
    const char* notes
) {
    if (!engine) return 0;
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);
    return ctx->storage->add_target_to_list(list_id, dso_id, notes ? notes : "") ? 1 : 0;
}

int32_t astro_remove_from_observing_list(
    AstroEngine* engine,
    int64_t list_id,
    int64_t dso_id
) {
    if (!engine) return 0;
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);
    return ctx->storage->remove_target_from_list(list_id, dso_id) ? 1 : 0;
}

static std::string escape_json(const std::string& s) {
    std::ostringstream o;
    for (char c : s) {
        if (c == '"') o << "\\\"";
        else if (c == '\\') o << "\\\\";
        else if (c == '\b') o << "\\b";
        else if (c == '\f') o << "\\f";
        else if (c == '\n') o << "\\n";
        else if (c == '\r') o << "\\r";
        else if (c == '\t') o << "\\t";
        else o << c;
    }
    return o.str();
}

const char* astro_get_observing_lists_json(AstroEngine* engine) {
    if (!engine) return duplicate_string("[]");
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);

    auto lists = ctx->storage->get_all_lists();

    std::ostringstream ss;
    ss << "[";
    for (size_t i = 0; i < lists.size(); ++i) {
        if (i > 0) ss << ",";
        const auto& l = lists[i];
        ss << "{"
           << "\"id\":" << l.id << ","
           << "\"name\":\"" << escape_json(l.name) << "\","
           << "\"description\":\"" << escape_json(l.description) << "\","
           << "\"session_date\":\"" << escape_json(l.session_date) << "\","
           << "\"created_at\":" << l.created_at << ","
           << "\"items\":[";

        for (size_t j = 0; j < l.items.size(); ++j) {
            if (j > 0) ss << ",";
            const auto& item = l.items[j];
            ss << "{"
               << "\"list_id\":" << item.list_id << ","
               << "\"dso_id\":" << item.dso_id << ","
               << "\"name\":\"" << escape_json(item.dso.name) << "\","
               << "\"display_name\":\"" << escape_json(item.dso.display_name()) << "\","
               << "\"catalog\":\"" << escape_json(item.dso.catalog) << "\","
               << "\"object_type\":\"" << escape_json(item.dso.object_type) << "\","
               << "\"constellation\":\"" << escape_json(item.dso.constellation) << "\","
               << "\"magnitude\":" << (item.dso.magnitude.has_value() ? std::to_string(*item.dso.magnitude) : "null") << ","
               << "\"notes\":\"" << escape_json(item.notes) << "\","
               << "\"status\":\"" << escape_json(item.status) << "\","
               << "\"added_at\":" << item.added_at
               << "}";
        }

        ss << "]}";
    }
    ss << "]";

    return duplicate_string(ss.str());
}

int32_t astro_clear_all_observing_lists(AstroEngine* engine) {
    if (!engine) return 0;
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);
    return ctx->storage->clear_all_lists() ? 1 : 0;
}

const char* astro_get_target_yearly_visibility_json(
    AstroEngine* engine,
    int64_t target_id,
    const AstroObserver* observer,
    const AstroFilterCriteria* criteria,
    int32_t year
) {
    if (!engine || !observer) return duplicate_string("{}");
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);

    try {
        auto opt_dso = ctx->storage->get_object_by_id(target_id);
        if (!opt_dso.has_value()) {
            return duplicate_string("{\"error\":\"Target not found\"}");
        }

        astro::coordinates::ObserverLocation obs{
            astro::units::Degrees{observer->latitude_deg},
            astro::units::Degrees{observer->longitude_deg},
            observer->elevation_m
        };

        astro::visibility::VisibilityCriteria crit;
        if (criteria) {
            crit.min_altitude = astro::units::Degrees{criteria->min_altitude_deg};
            crit.min_duration_hours = criteria->min_duration_hours > 0 ? criteria->min_duration_hours : 2.0;
            crit.azimuth_range = astro::horizon::AzimuthRange{
                astro::units::Degrees{criteria->min_azimuth_deg},
                astro::units::Degrees{criteria->max_azimuth_deg}
            };
            crit.quadrant = static_cast<astro::horizon::Quadrant>(criteria->quadrant);
            crit.use_custom_time_window = (criteria->use_custom_time_window != 0);
            crit.custom_start_hour = criteria->custom_start_hour;
            crit.custom_start_minute = criteria->custom_start_minute;
            crit.custom_end_hour = criteria->custom_end_hour;
            crit.custom_end_minute = criteria->custom_end_minute;
            crit.utc_offset_minutes = criteria->utc_offset_minutes;
            apply_criteria_extra(criteria, crit);
        } else {
            crit.min_altitude = astro::units::Degrees{30.0};
            crit.min_duration_hours = 2.0;
        }

        int sim_year = year > 1900 ? year : 2026;
        auto res = astro::visibility::calculate_yearly_visibility(opt_dso->coordinates, obs, crit, sim_year);

        std::ostringstream ss;
        ss << "{"
           << "\"target_id\":" << target_id << ","
           << "\"theoretical_max_altitude_deg\":" << res.theoretical_max_altitude_deg << ","
           << "\"can_ever_reach_min_alt\":" << (res.can_ever_reach_min_alt ? "true" : "false") << ","
           << "\"peak_month\":" << res.peak_month << ","
           << "\"peak_day\":" << res.peak_day << ","
           << "\"start_month\":" << res.start_month << ","
           << "\"start_day\":" << res.start_day << ","
           << "\"end_month\":" << res.end_month << ","
           << "\"end_day\":" << res.end_day << ","
           << "\"best_window_start\":" << res.best_window_start << ","
           << "\"best_window_end\":" << res.best_window_end << ","
           << "\"total_observable_days\":" << res.total_observable_days << ","
           << "\"max_hours_in_peak\":" << res.max_hours_in_peak << ","
           << "\"best_window_summary\":\"" << escape_json(res.best_window_summary) << "\","
           << "\"months\":[";

        for (size_t i = 0; i < res.months.size(); ++i) {
            if (i > 0) ss << ",";
            const auto& m = res.months[i];
            ss << "{"
               << "\"month\":" << m.month << ","
               << "\"name\":\"" << m.month_name << "\","
               << "\"hours_observable\":" << m.hours_observable << ","
               << "\"peak_altitude_deg\":" << m.peak_altitude_deg << ","
               << "\"is_observable\":" << (m.is_observable ? "true" : "false") << ","
               << "\"observable_days_count\":" << m.observable_days_count << ","
               << "\"start_day\":" << m.start_day << ","
               << "\"end_day\":" << m.end_day << ","
               << "\"total_days_in_month\":" << m.total_days_in_month
               << "}";
        }
        ss << "]}";

        return duplicate_string(ss.str());
    } catch (const std::exception& e) {
        ctx->last_error = e.what();
        return duplicate_string("{}");
    }
}

const char* astro_get_target_description_json(AstroEngine* engine, const char* target_name) {
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);
    if (!ctx || !ctx->storage || !target_name) return nullptr;

    try {
        auto rec = ctx->storage->get_target_description(target_name);
        if (!rec.has_value()) {
            return nullptr;
        }

        std::ostringstream ss;
        ss << "{"
           << "\"title\":\"" << escape_json(rec->title) << "\","
           << "\"description\":\"" << escape_json(rec->description) << "\","
           << "\"extract\":\"" << escape_json(rec->extract) << "\","
           << "\"thumbnail_url\":\"" << escape_json(rec->thumbnail_url) << "\","
           << "\"page_url\":\"" << escape_json(rec->page_url) << "\","
           << "\"source\":\"" << escape_json(rec->source) << "\""
           << "}";

        return duplicate_string(ss.str());
    } catch (const std::exception& e) {
        ctx->last_error = e.what();
        return nullptr;
    }
}

int32_t astro_save_target_description(
    AstroEngine* engine,
    const char* title,
    const char* description,
    const char* extract,
    const char* thumbnail_url,
    const char* page_url,
    const char* source,
    const char* aliases_csv
) {
    auto* ctx = reinterpret_cast<AstroEngineContext*>(engine);
    if (!ctx || !ctx->storage || !title || !extract) return 0;

    try {
        std::vector<std::string> aliases = split_csv(aliases_csv);
        bool ok = ctx->storage->save_target_description(
            title,
            description ? description : "",
            extract,
            thumbnail_url ? thumbnail_url : "",
            page_url ? page_url : "",
            source ? source : "Wikipedia",
            aliases
        );
        return ok ? 1 : 0;
    } catch (const std::exception& e) {
        ctx->last_error = e.what();
        return 0;
    }
}

void astro_free_string(const char* str) {
    if (str) {
        free(const_cast<char*>(str));
    }
}
