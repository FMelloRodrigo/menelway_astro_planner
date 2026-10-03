#pragma once

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32) || defined(__CYGWIN__)
    #ifdef ASTRO_CORE_EXPORTS
        #define ASTRO_API __declspec(dllexport)
    #else
        #define ASTRO_API __declspec(dllimport)
    #endif
#else
    #if __GNUC__ >= 4
        #define ASTRO_API __attribute__((visibility("default")))
    #else
        #define ASTRO_API
    #endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct AstroEngineContext AstroEngine;

typedef struct {
    double latitude_deg;
    double longitude_deg;
    double elevation_m;
} AstroObserver;

typedef struct {
    int64_t sunset_utc;
    int64_t civil_dusk_utc;
    int64_t nautical_dusk_utc;
    int64_t astronomical_dusk_utc;
    int64_t solar_midnight_utc;
    int64_t astronomical_dawn_utc;
    int64_t nautical_dawn_utc;
    int64_t civil_dawn_utc;
    int64_t sunrise_utc;
    double moon_illumination;
    const char* moon_phase_name;
    int32_t has_astronomical_night;
} AstroNightSummary;

typedef struct {
    double min_altitude_deg;
    double max_altitude_deg;
    double min_duration_hours;
    int64_t window_start_utc;
    int64_t window_end_utc;
    double min_moon_separation_deg;
    double min_azimuth_deg;
    double max_azimuth_deg;
    int32_t quadrant; // 0=All, 1=N, 2=E, 3=S, 4=W, 5=NE, 6=SE, 7=SW, 8=NW
    double max_magnitude;
    double min_magnitude;
    double min_size_arcmin;
    double max_size_arcmin;
    const char* catalogs_csv;      // e.g. "Messier,Caldwell,NGC"
    const char* object_types_csv;  // e.g. "Galaxy,Planetary Nebula"
    const char* search_query;      // optional text search
    int32_t limit;
    int32_t offset;
    int32_t use_custom_time_window; // 0 or 1
    int32_t custom_start_hour;
    int32_t custom_start_minute;
    int32_t custom_end_hour;
    int32_t custom_end_minute;
    int32_t utc_offset_minutes;
    const double* horizon_azimuths;
    const double* horizon_altitudes;
    int32_t horizon_points_count;
    int32_t use_custom_horizon;
} AstroFilterCriteria;

typedef struct {
    int64_t id;
    const char* name;
    const char* messier;
    const char* caldwell;
    const char* arp;
    const char* herschel;
    const char* catalog;
    const char* object_type;
    const char* constellation;
    double ra_hours;
    double dec_degrees;
    double magnitude;
    double major_axis_arcmin;
    double position_angle_deg;
    double surface_brightness;
    const char* common_name;
    double peak_altitude_deg;
    double visible_duration_hours;
    int64_t transit_utc;
    int64_t visible_start_utc;
    int64_t visible_end_utc;
    double min_moon_sep_deg;
    int32_t meets_criteria;
} AstroTargetItem;

typedef struct {
    AstroTargetItem* items;
    size_t count;
} AstroTargetList;

typedef struct {
    int64_t id;
    const char* name;
    const char* messier;
    const char* caldwell;
    const char* arp;
    const char* herschel;
    const char* catalog;
    const char* object_type;
    const char* constellation;
    double ra_hours;
    double dec_degrees;
    double magnitude;
    double major_axis_arcmin;
    double position_angle_deg;
    double surface_brightness;
    const char* common_name;
    double peak_altitude_deg;
    double max_hours_observable;
    int64_t peak_date_utc;
    int32_t observable_days_count;
    int32_t total_period_days;
    int32_t start_month;
    int32_t start_day;
    int32_t end_month;
    int32_t end_day;
    int32_t is_observable;
} AstroPeriodTargetItem;

typedef struct {
    AstroPeriodTargetItem* items;
    size_t count;
} AstroPeriodTargetList;

typedef struct {
    int64_t timestamp_utc;
    double altitude_deg;
    double azimuth_deg;
    double moon_separation_deg;
    int32_t meets_criteria;
} AstroAltitudePoint;

typedef struct {
    AstroAltitudePoint* points;
    size_t count;
} AstroCurveData;

// Lifecycle
ASTRO_API AstroEngine* astro_engine_create(const char* db_path);
ASTRO_API AstroEngine* astro_engine_create_with_user_db(const char* catalog_db_path, const char* user_db_path);
ASTRO_API void astro_engine_destroy(AstroEngine* engine);
ASTRO_API const char* astro_engine_get_last_error(AstroEngine* engine);

// Ephemeris & Night info
ASTRO_API int32_t astro_get_night_summary(
    AstroEngine* engine,
    const AstroObserver* observer,
    int64_t date_timestamp_utc,
    AstroNightSummary* out_summary
);

// Target Filtering
ASTRO_API AstroTargetList* astro_filter_targets(
    AstroEngine* engine,
    const AstroObserver* observer,
    const AstroFilterCriteria* criteria,
    int32_t step_minutes
);
ASTRO_API void astro_free_target_list(AstroTargetList* list);

// Period Target Filtering (Future Planning)
ASTRO_API AstroPeriodTargetList* astro_filter_targets_period(
    AstroEngine* engine,
    const AstroObserver* observer,
    const AstroFilterCriteria* criteria,
    int64_t period_start_utc,
    int64_t period_end_utc,
    int32_t step_minutes
);
ASTRO_API void astro_free_period_target_list(AstroPeriodTargetList* list);

// Target Altitude Curve (for high-resolution plotting)
ASTRO_API AstroCurveData* astro_generate_curve(
    AstroEngine* engine,
    int64_t target_id,
    const AstroObserver* observer,
    int64_t start_utc,
    int64_t end_utc,
    int32_t step_minutes
);
ASTRO_API void astro_free_curve_data(AstroCurveData* curve);

// Observing lists (JSON exchange for easy cross-language binding)
ASTRO_API int64_t astro_create_observing_list(
    AstroEngine* engine,
    const char* name,
    const char* description,
    const char* session_date
);
ASTRO_API int32_t astro_delete_observing_list(AstroEngine* engine, int64_t list_id);
ASTRO_API int32_t astro_add_to_observing_list(
    AstroEngine* engine,
    int64_t list_id,
    int64_t dso_id,
    const char* notes
);
ASTRO_API int32_t astro_remove_from_observing_list(
    AstroEngine* engine,
    int64_t list_id,
    int64_t dso_id
);
ASTRO_API const char* astro_get_observing_lists_json(AstroEngine* engine);
ASTRO_API int32_t astro_clear_all_observing_lists(AstroEngine* engine);

// Yearly Target Visibility Simulation (JSON format)
ASTRO_API const char* astro_get_target_yearly_visibility_json(
    AstroEngine* engine,
    int64_t target_id,
    const AstroObserver* observer,
    const AstroFilterCriteria* criteria,
    int32_t year
);

// Target Descriptions (JSON exchange)
ASTRO_API const char* astro_get_target_description_json(
    AstroEngine* engine,
    const char* target_name
);

ASTRO_API int32_t astro_save_target_description(
    AstroEngine* engine,
    const char* title,
    const char* description,
    const char* extract,
    const char* thumbnail_url,
    const char* page_url,
    const char* source,
    const char* aliases_csv
);

ASTRO_API void astro_free_string(const char* str);

#ifdef __cplusplus
}
#endif
