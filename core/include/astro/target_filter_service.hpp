#pragma once

#include "astro/catalog.hpp"
#include "astro/coordinates.hpp"
#include "astro/time.hpp"
#include "astro/visibility.hpp"
#include "astro/storage.hpp"

#include <vector>

namespace astro::services {

/// Pure domain service that computes target visibility, filtering, multi-threaded
/// period simulations, and sorting over an ICatalogRepository data source.
class TargetFilterService {
public:
    explicit TargetFilterService(storage::ICatalogRepository& catalog_repo);

    /// Decorates solar system bodies (planets and Moon) with dynamic ephemeris coordinates,
    /// magnitude, and angular size computed for a specific epoch and observer location.
    static void decorate_solar_system_body(
        catalog::DsoObject& obj,
        time::JulianDate jd,
        const coordinates::ObserverLocation& obs
    );

    /// Evaluates tonight's visibility for catalog candidates matching filter_options.
    /// Sorts candidates with strict weak ordering (criteria met first, then magnitude ASC, then peak altitude DESC).
    std::vector<catalog::TargetWithVisibility> filter_targets(
        const coordinates::ObserverLocation& obs,
        const catalog::DsoFilterOptions& filter_options,
        const visibility::VisibilityCriteria& visibility_criteria,
        int step_minutes = 10
    );

    /// Evaluates multi-night period visibility for catalog candidates matching filter_options.
    std::vector<catalog::TargetWithPeriodVisibility> filter_targets_period(
        const coordinates::ObserverLocation& obs,
        const catalog::DsoFilterOptions& filter_options,
        const visibility::VisibilityCriteria& visibility_criteria,
        time::JulianDate start_jd,
        time::JulianDate end_jd,
        int step_minutes = 10
    );

private:
    storage::ICatalogRepository& catalog_repo_;
};

} // namespace astro::services
