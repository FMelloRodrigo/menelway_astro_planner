#include "astro/horizon.hpp"
#include <algorithm>

namespace astro::horizon {

bool AzimuthRange::contains(units::Degrees az) const {
    double a = units::normalize_degrees_360(az).value;
    double low = units::normalize_degrees_360(min_az).value;
    double high = units::normalize_degrees_360(max_az).value;

    if (std::abs(low - high) < 1e-6) {
        return true; // Full 360 range
    }

    if (low <= high) {
        return a >= low && a <= high;
    } else {
        // Wraps over 0 / 360 deg
        return a >= low || a <= high;
    }
}

bool is_in_quadrant(units::Degrees az, Quadrant quad) {
    double a = units::normalize_degrees_360(az).value;
    switch (quad) {
        case Quadrant::All:
            return true;
        case Quadrant::North:
            return (a >= 315.0 || a < 45.0);
        case Quadrant::East:
            return (a >= 45.0 && a < 135.0);
        case Quadrant::South:
            return (a >= 135.0 && a < 225.0);
        case Quadrant::West:
            return (a >= 225.0 && a < 315.0);
        case Quadrant::NorthEast:
            return (a >= 0.0 && a < 90.0);
        case Quadrant::SouthEast:
            return (a >= 90.0 && a < 180.0);
        case Quadrant::SouthWest:
            return (a >= 180.0 && a < 270.0);
        case Quadrant::NorthWest:
            return (a >= 270.0 && a < 360.0);
    }
    return true;
}

HorizonProfile::HorizonProfile(std::vector<HorizonPoint> points)
    : points_(std::move(points)) {
    sort_points();
}

void HorizonProfile::add_point(units::Degrees az, units::Degrees min_alt) {
    points_.push_back({units::normalize_degrees_360(az), min_alt});
    sort_points();
}

void HorizonProfile::clear() {
    points_.clear();
}

void HorizonProfile::sort_points() {
    std::sort(points_.begin(), points_.end(), [](const HorizonPoint& a, const HorizonPoint& b) {
        return a.azimuth.value < b.azimuth.value;
    });
}

units::Degrees HorizonProfile::min_altitude_at(units::Degrees az) const {
    if (points_.empty()) {
        return units::Degrees{0.0};
    }
    if (points_.size() == 1) {
        return points_.front().min_altitude;
    }

    double a = units::normalize_degrees_360(az).value;

    // Find upper bound in sorted points
    auto it = std::upper_bound(points_.begin(), points_.end(), a,
        [](double val, const HorizonPoint& p) {
            return val < p.azimuth.value;
        });

    if (it == points_.begin()) {
        // Between last point (wrapped) and first point
        const auto& p_prev = points_.back();
        const auto& p_next = points_.front();
        double span = (p_next.azimuth.value + 360.0) - p_prev.azimuth.value;
        double frac = (a + 360.0 - p_prev.azimuth.value) / span;
        double alt = p_prev.min_altitude.value + frac * (p_next.min_altitude.value - p_prev.min_altitude.value);
        return units::Degrees{alt};
    } else if (it == points_.end()) {
        // Between last point and first point (wrapped)
        const auto& p_prev = points_.back();
        const auto& p_next = points_.front();
        double span = (p_next.azimuth.value + 360.0) - p_prev.azimuth.value;
        double frac = (a - p_prev.azimuth.value) / span;
        double alt = p_prev.min_altitude.value + frac * (p_next.min_altitude.value - p_prev.min_altitude.value);
        return units::Degrees{alt};
    } else {
        // Between *(it - 1) and *it
        const auto& p_prev = *(it - 1);
        const auto& p_next = *it;
        double span = p_next.azimuth.value - p_prev.azimuth.value;
        double frac = (a - p_prev.azimuth.value) / span;
        double alt = p_prev.min_altitude.value + frac * (p_next.min_altitude.value - p_prev.min_altitude.value);
        return units::Degrees{alt};
    }
}

bool HorizonProfile::is_visible(units::Degrees alt, units::Degrees az) const {
    return alt.value >= min_altitude_at(az).value;
}

} // namespace astro::horizon
