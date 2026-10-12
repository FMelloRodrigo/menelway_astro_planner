#include "astro/target_filter_service.hpp"
#include <algorithm>
#include <cctype>
#include <cmath>
#include <string_view>
#include <thread>
#include <utility>

namespace astro::services {

namespace {

std::string normalize_ident(std::string_view s) {
    std::string res;
    res.reserve(s.size());
    for (char c : s) {
        if (std::isalnum(static_cast<unsigned char>(c))) {
            res.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(c))));
        }
    }
    return res;
}

int compute_search_match_score(const catalog::DsoObject& dso, const std::string& norm_query) {
    if (norm_query.empty()) return 3;

    std::string query_alt = norm_query;
    if (query_alt.rfind("messier", 0) == 0 && query_alt.size() > 7) {
        query_alt = "m" + query_alt.substr(7);
    } else if (query_alt.rfind("caldwell", 0) == 0 && query_alt.size() > 8) {
        query_alt = "c" + query_alt.substr(8);
    } else if (query_alt.rfind("herschel", 0) == 0 && query_alt.size() > 8) {
        query_alt = "h" + query_alt.substr(8);
    }

    // Tier 0: Exact match on primary catalog designations
    if (normalize_ident(dso.name) == norm_query || normalize_ident(dso.name) == query_alt) return 0;
    if (dso.messier && (normalize_ident(*dso.messier) == norm_query || normalize_ident(*dso.messier) == query_alt)) return 0;
    if (dso.caldwell && (normalize_ident(*dso.caldwell) == norm_query || normalize_ident(*dso.caldwell) == query_alt)) return 0;
    if (dso.arp && (normalize_ident(*dso.arp) == norm_query || normalize_ident(*dso.arp) == query_alt)) return 0;
    if (dso.herschel && (normalize_ident(*dso.herschel) == norm_query || normalize_ident(*dso.herschel) == query_alt)) return 0;
    if (!dso.ngc_ic.empty() && (normalize_ident(dso.ngc_ic) == norm_query || normalize_ident(dso.ngc_ic) == query_alt)) return 0;

    // Tier 1: Substring / token match in common names (or Tier 0 if exact)
    if (dso.common_names) {
        std::string norm_cn = normalize_ident(*dso.common_names);
        if (norm_cn == norm_query || norm_cn == query_alt) return 0;
        if (norm_cn.find(norm_query) != std::string::npos || norm_cn.find(query_alt) != std::string::npos) {
            return 1;
        }
    }

    // Tier 2: FTS match on other fields (description, guide references, identifiers)
    return 2;
}

} // namespace

TargetFilterService::TargetFilterService(storage::ICatalogRepository& catalog_repo)
    : catalog_repo_(catalog_repo) {}

void TargetFilterService::decorate_solar_system_body(
    catalog::DsoObject& obj,
    time::JulianDate jd,
    const coordinates::ObserverLocation& obs
) {
    if (obj.catalog == "Solar System" || (obj.id >= 90001 && obj.id <= 90010)) {
        int pid_num = static_cast<int>(obj.id - 90000);
        if (pid_num >= 1 && pid_num <= 10) {
            auto pid = static_cast<ephemeris::PlanetId>(pid_num);
            auto pinfo = ephemeris::get_planet_info(pid, jd, obs);
            obj.coordinates = pinfo.coords;
            obj.magnitude = pinfo.visual_magnitude;
            obj.major_axis_arcmin = pinfo.angular_diameter_arcsec / 60.0;
        }
    }
}

std::vector<catalog::TargetWithVisibility> TargetFilterService::filter_targets(
    const coordinates::ObserverLocation& obs,
    const catalog::DsoFilterOptions& filter_options,
    const visibility::VisibilityCriteria& visibility_criteria,
    int step_minutes
) {
    std::vector<catalog::TargetWithVisibility> results;

    bool has_search_query = !filter_options.search_query.empty();
    std::string norm_query = has_search_query ? normalize_ident(filter_options.search_query) : "";

    // Candidate pool sizing:
    // When actively searching, keep pool focused so FTS BM25 relevance is respected,
    // and clear browsing filters so searched targets (e.g. M44, M69) are not excluded by unselected object types/catalogs.
    // When browsing catalogs, pull a wide candidate pool so the visibility engine can rank all visible objects.
    catalog::DsoFilterOptions candidate_opts = filter_options;
    if (has_search_query) {
        candidate_opts.limit = filter_options.limit > 0 ? std::max(filter_options.limit * 5, 100) : 500;
        candidate_opts.catalogs.clear();
        candidate_opts.object_types.clear();
        candidate_opts.min_magnitude.reset();
        candidate_opts.max_magnitude.reset();
        candidate_opts.min_size_arcmin.reset();
        candidate_opts.max_size_arcmin.reset();
        candidate_opts.constellation.reset();
    } else {
        candidate_opts.limit = 15000;
    }
    candidate_opts.offset = 0;

    std::vector<catalog::DsoObject> candidates = catalog_repo_.query_objects(candidate_opts);
    if (candidates.empty()) return results;

    time::JulianDate eval_jd = visibility_criteria.window_start;
    if (visibility_criteria.window_end.value > visibility_criteria.window_start.value) {
        eval_jd = time::JulianDate{
            (visibility_criteria.window_start.value + visibility_criteria.window_end.value) * 0.5
        };
    }

    struct ScoredTarget {
        catalog::TargetWithVisibility item;
        size_t original_index;
        int match_tier;
    };
    std::vector<ScoredTarget> scored_items;
    scored_items.reserve(candidates.size());

    for (size_t i = 0; i < candidates.size(); ++i) {
        auto dso = candidates[i];
        decorate_solar_system_body(dso, eval_jd, obs);

        auto vis = visibility::evaluate_visibility(
            dso.coordinates,
            obs,
            visibility_criteria,
            step_minutes,
            /*include_samples=*/false
        );

        // When actively searching by name/query, keep targets even if they do not meet
        // tonight's criteria so the user can inspect their yearly observing window.
        if (vis.meets_criteria || has_search_query) {
            int tier = has_search_query ? compute_search_match_score(dso, norm_query) : 0;
            scored_items.push_back({catalog::TargetWithVisibility{std::move(dso), vis}, i, tier});
        }
    }

    if (has_search_query) {
        // Strict weak ordering for search query results:
        // 1. Direct designation match tier (exact name/Messier/Caldwell/NGC/common name)
        // 2. Visible tonight vs off-season (within the same match tier)
        // 3. FTS BM25 candidate order (original_index)
        std::sort(scored_items.begin(), scored_items.end(), [](const auto& a, const auto& b) {
            if (a.match_tier != b.match_tier) {
                return a.match_tier < b.match_tier;
            }
            if (a.item.visibility.meets_criteria != b.item.visibility.meets_criteria) {
                return a.item.visibility.meets_criteria > b.item.visibility.meets_criteria;
            }
            if (a.original_index != b.original_index) {
                return a.original_index < b.original_index;
            }
            return a.item.dso.id < b.item.dso.id;
        });
    } else {
        // Strict weak ordering for normal catalog browsing:
        // 1. Meets criteria tonight first
        // 2. Brightest first (magnitude ASC, nulls last)
        // 3. Peak altitude descending
        // 4. Stable tie-breaker: dso.id
        std::sort(scored_items.begin(), scored_items.end(), [](const auto& a, const auto& b) {
            if (a.item.visibility.meets_criteria != b.item.visibility.meets_criteria) {
                return a.item.visibility.meets_criteria > b.item.visibility.meets_criteria;
            }
            bool a_has_mag = a.item.dso.magnitude.has_value();
            bool b_has_mag = b.item.dso.magnitude.has_value();
            if (a_has_mag != b_has_mag) {
                return a_has_mag > b_has_mag;
            }
            if (a_has_mag && b_has_mag) {
                if (*a.item.dso.magnitude != *b.item.dso.magnitude) {
                    return *a.item.dso.magnitude < *b.item.dso.magnitude;
                }
            }
            if (a.item.visibility.peak_altitude.value != b.item.visibility.peak_altitude.value) {
                return a.item.visibility.peak_altitude.value > b.item.visibility.peak_altitude.value;
            }
            return a.item.dso.id < b.item.dso.id;
        });
    }

    results.reserve(scored_items.size());
    for (auto& s : scored_items) {
        results.push_back(std::move(s.item));
    }

    if (filter_options.offset > 0) {
        if (static_cast<size_t>(filter_options.offset) >= results.size()) {
            results.clear();
        } else {
            results.erase(results.begin(), results.begin() + filter_options.offset);
        }
    }

    if (filter_options.limit > 0 && results.size() > static_cast<size_t>(filter_options.limit)) {
        results.resize(filter_options.limit);
    }

    return results;
}

std::vector<catalog::TargetWithPeriodVisibility> TargetFilterService::filter_targets_period(
    const coordinates::ObserverLocation& obs,
    const catalog::DsoFilterOptions& filter_options,
    const visibility::VisibilityCriteria& visibility_criteria,
    time::JulianDate start_jd,
    time::JulianDate end_jd,
    int step_minutes
) {
    std::vector<catalog::TargetWithPeriodVisibility> results;

    bool has_search_query = !filter_options.search_query.empty();
    std::string norm_query = has_search_query ? normalize_ident(filter_options.search_query) : "";

    // Candidate limits
    catalog::DsoFilterOptions candidate_opts = filter_options;
    if (has_search_query) {
        candidate_opts.limit = filter_options.limit > 0 ? std::max(filter_options.limit * 5, 100) : 500;
        candidate_opts.catalogs.clear();
        candidate_opts.object_types.clear();
        candidate_opts.min_magnitude.reset();
        candidate_opts.max_magnitude.reset();
        candidate_opts.min_size_arcmin.reset();
        candidate_opts.max_size_arcmin.reset();
        candidate_opts.constellation.reset();
    } else {
        candidate_opts.limit = 15000;
    }
    candidate_opts.offset = 0;

    std::vector<catalog::DsoObject> candidates = catalog_repo_.query_objects(candidate_opts);
    if (candidates.empty()) return results;

    time::JulianDate eval_jd = start_jd;
    if (end_jd.value > start_jd.value) {
        eval_jd = time::JulianDate{(start_jd.value + end_jd.value) * 0.5};
    }
    for (auto& dso : candidates) {
        decorate_solar_system_body(dso, eval_jd, obs);
    }

    auto period_ctx = visibility::prepare_period_context(obs, visibility_criteria, start_jd, end_jd, step_minutes);

    unsigned int num_threads = std::max(1u, std::thread::hardware_concurrency());
    if (candidates.size() <= 64 || num_threads <= 1) {
        results.reserve(std::min<size_t>(candidates.size(), 1000));
        for (const auto& dso : candidates) {
            auto vis = visibility::evaluate_period_visibility_fast(
                dso.coordinates,
                obs,
                visibility_criteria,
                period_ctx,
                step_minutes
            );

            if (vis.is_observable || has_search_query) {
                results.push_back({dso, vis});
            }
        }
    } else {
        std::vector<std::vector<catalog::TargetWithPeriodVisibility>> thread_results(num_threads);
        std::vector<std::thread> workers;
        workers.reserve(num_threads);

        size_t chunk_size = (candidates.size() + num_threads - 1) / num_threads;
        for (unsigned int t = 0; t < num_threads; ++t) {
            size_t start_idx = t * chunk_size;
            size_t end_idx = std::min(start_idx + chunk_size, candidates.size());
            if (start_idx >= end_idx) continue;

            workers.emplace_back([&, t, start_idx, end_idx]() {
                thread_results[t].reserve((end_idx - start_idx) / 4);
                for (size_t i = start_idx; i < end_idx; ++i) {
                    const auto& dso = candidates[i];
                    auto vis = visibility::evaluate_period_visibility_fast(
                        dso.coordinates,
                        obs,
                        visibility_criteria,
                        period_ctx,
                        step_minutes
                    );

                    if (vis.is_observable || has_search_query) {
                        thread_results[t].push_back({dso, vis});
                    }
                }
            });
        }

        for (auto& w : workers) {
            w.join();
        }

        size_t total_count = 0;
        for (const auto& tr : thread_results) {
            total_count += tr.size();
        }
        results.reserve(total_count);
        for (auto& tr : thread_results) {
            results.insert(results.end(), std::make_move_iterator(tr.begin()), std::make_move_iterator(tr.end()));
        }
    }

    if (has_search_query) {
        std::sort(results.begin(), results.end(), [&](const auto& a, const auto& b) {
            int a_tier = compute_search_match_score(a.dso, norm_query);
            int b_tier = compute_search_match_score(b.dso, norm_query);
            if (a_tier != b_tier) {
                return a_tier < b_tier;
            }
            if (a.visibility.is_observable != b.visibility.is_observable) {
                return a.visibility.is_observable > b.visibility.is_observable;
            }
            if (a.visibility.total_observable_days != b.visibility.total_observable_days) {
                return a.visibility.total_observable_days > b.visibility.total_observable_days;
            }
            if (a.visibility.peak_altitude_deg != b.visibility.peak_altitude_deg) {
                return a.visibility.peak_altitude_deg > b.visibility.peak_altitude_deg;
            }
            return a.dso.id < b.dso.id;
        });
    } else {
        std::sort(results.begin(), results.end(), [](const auto& a, const auto& b) {
            if (a.visibility.is_observable != b.visibility.is_observable) {
                return a.visibility.is_observable > b.visibility.is_observable;
            }
            if (a.visibility.total_observable_days != b.visibility.total_observable_days) {
                return a.visibility.total_observable_days > b.visibility.total_observable_days;
            }
            if (a.visibility.peak_altitude_deg != b.visibility.peak_altitude_deg) {
                return a.visibility.peak_altitude_deg > b.visibility.peak_altitude_deg;
            }
            return a.dso.id < b.dso.id;
        });
    }

    if (filter_options.offset > 0) {
        if (static_cast<size_t>(filter_options.offset) >= results.size()) {
            results.clear();
        } else {
            results.erase(results.begin(), results.begin() + filter_options.offset);
        }
    }

    if (filter_options.limit > 0 && results.size() > static_cast<size_t>(filter_options.limit)) {
        results.resize(filter_options.limit);
    }

    return results;
}

} // namespace astro::services
