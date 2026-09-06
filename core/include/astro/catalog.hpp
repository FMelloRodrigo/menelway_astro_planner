#pragma once

#include "astro/coordinates.hpp"
#include "astro/visibility.hpp"
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace astro::catalog {

struct DsoObject {
    std::int64_t id{0};
    std::string name;
    std::optional<std::string> messier;
    std::optional<std::string> caldwell;
    std::optional<std::string> arp;
    std::optional<std::string> herschel;
    std::string ngc_ic;
    std::string catalog;
    std::string catalog_number;
    std::string object_type;
    std::string constellation;
    coordinates::EquatorialCoordinates coordinates;
    std::optional<double> magnitude;
    std::optional<double> b_mag;
    std::optional<double> major_axis_arcmin;
    std::optional<double> minor_axis_arcmin;
    std::optional<double> surface_brightness;
    std::optional<std::string> common_names;
    std::optional<std::string> identifiers;

    std::string display_name() const {
        if (messier.has_value() && !messier->empty()) {
            if (common_names.has_value() && !common_names->empty()) {
                return *messier + " (" + *common_names + ")";
            }
            return *messier + " - " + name;
        }
        if (caldwell.has_value() && !caldwell->empty()) {
            if (common_names.has_value() && !common_names->empty()) {
                return *caldwell + " (" + *common_names + ")";
            }
            return *caldwell + " - " + name;
        }
        if (arp.has_value() && !arp->empty()) {
            if (common_names.has_value() && !common_names->empty()) {
                return *arp + " (" + *common_names + ")";
            }
            return *arp + " - " + name;
        }
        if (herschel.has_value() && !herschel->empty()) {
            if (common_names.has_value() && !common_names->empty()) {
                return *herschel + " (" + *common_names + ")";
            }
            return *herschel + " - " + name;
        }
        if (common_names.has_value() && !common_names->empty()) {
            return name + " (" + *common_names + ")";
        }
        return name;
    }
};

struct DsoFilterOptions {
    std::vector<std::string> catalogs;     // e.g. {"Messier", "Caldwell", "NGC"}
    std::vector<std::string> object_types; // e.g. {"Galaxy", "Planetary Nebula"}
    std::optional<double> max_magnitude;
    std::optional<double> min_magnitude;
    std::optional<double> min_size_arcmin;
    std::optional<double> max_size_arcmin;
    std::optional<std::string> constellation;
    std::string search_query;             // Text search on names, common names, identifiers
    int limit{500};
    int offset{0};
};

struct TargetWithVisibility {
    DsoObject dso;
    visibility::TargetVisibilityResult visibility;
};

struct TargetWithPeriodVisibility {
    DsoObject dso;
    visibility::PeriodVisibilityResult visibility;
};

} // namespace astro::catalog
