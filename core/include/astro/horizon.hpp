#pragma once

#include "astro/units.hpp"
#include <vector>

namespace astro::horizon {

enum class Quadrant {
    All,
    North,
    East,
    South,
    West,
    NorthEast,
    SouthEast,
    SouthWest,
    NorthWest
};

/**
 * @brief Represents an azimuth range in degrees [min_az, max_az].
 * Can wrap around 360/0 (e.g. 330 to 45 deg).
 */
struct AzimuthRange {
    units::Degrees min_az{0.0};
    units::Degrees max_az{360.0};

    bool contains(units::Degrees az) const;
};

/**
 * @brief Checks if an azimuth angle belongs to a named quadrant.
 */
bool is_in_quadrant(units::Degrees az, Quadrant quad);

/**
 * @brief A single anchor point on a local horizon obstruction profile.
 */
struct HorizonPoint {
    units::Degrees azimuth{0.0};
    units::Degrees min_altitude{0.0};
};

/**
 * @brief Custom local horizon obstruction mask (trees, buildings, walls).
 */
class HorizonProfile {
public:
    HorizonProfile() = default;
    explicit HorizonProfile(std::vector<HorizonPoint> points);

    void add_point(units::Degrees az, units::Degrees min_alt);
    void clear();

    /**
     * @brief Computes the minimum obstruction altitude at a given azimuth angle.
     */
    units::Degrees min_altitude_at(units::Degrees az) const;

    /**
     * @brief Returns true if the object at (alt, az) is clear of horizon obstructions.
     */
    bool is_visible(units::Degrees alt, units::Degrees az) const;

    const std::vector<HorizonPoint>& points() const { return points_; }

private:
    std::vector<HorizonPoint> points_;
    void sort_points();
};

} // namespace astro::horizon
