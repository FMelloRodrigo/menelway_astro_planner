#pragma once

#include <cmath>
#include <compare>
#include <numbers>

namespace astro::units {

/**
 * @brief Strongly typed degrees angle.
 */
struct Degrees {
    double value{0.0};

    constexpr Degrees() = default;
    constexpr explicit Degrees(double v) : value(v) {}

    constexpr auto operator<=>(const Degrees&) const = default;

    constexpr Degrees operator+(Degrees o) const { return Degrees{value + o.value}; }
    constexpr Degrees operator-(Degrees o) const { return Degrees{value - o.value}; }
    constexpr Degrees operator*(double scalar) const { return Degrees{value * scalar}; }
    constexpr Degrees operator/(double scalar) const { return Degrees{value / scalar}; }

    constexpr Degrees& operator+=(Degrees o) { value += o.value; return *this; }
    constexpr Degrees& operator-=(Degrees o) { value -= o.value; return *this; }
};

/**
 * @brief Strongly typed radians angle.
 */
struct Radians {
    double value{0.0};

    constexpr Radians() = default;
    constexpr explicit Radians(double v) : value(v) {}

    constexpr auto operator<=>(const Radians&) const = default;

    constexpr Radians operator+(Radians o) const { return Radians{value + o.value}; }
    constexpr Radians operator-(Radians o) const { return Radians{value - o.value}; }
    constexpr Radians operator*(double scalar) const { return Radians{value * scalar}; }
    constexpr Radians operator/(double scalar) const { return Radians{value / scalar}; }

    constexpr Radians& operator+=(Radians o) { value += o.value; return *this; }
    constexpr Radians& operator-=(Radians o) { value -= o.value; return *this; }
};

/**
 * @brief Strongly typed hours of Right Ascension or Sidereal Time [0, 24).
 */
struct Hours {
    double value{0.0};

    constexpr Hours() = default;
    constexpr explicit Hours(double v) : value(v) {}

    constexpr auto operator<=>(const Hours&) const = default;

    constexpr Hours operator+(Hours o) const { return Hours{value + o.value}; }
    constexpr Hours operator-(Hours o) const { return Hours{value - o.value}; }
    constexpr Hours operator*(double scalar) const { return Hours{value * scalar}; }
    constexpr Hours operator/(double scalar) const { return Hours{value / scalar}; }

    constexpr Hours& operator+=(Hours o) { value += o.value; return *this; }
    constexpr Hours& operator-=(Hours o) { value -= o.value; return *this; }
};

/**
 * @brief Apparent angular size in arcminutes (1/60th of a degree).
 */
struct Arcminutes {
    double value{0.0};

    constexpr Arcminutes() = default;
    constexpr explicit Arcminutes(double v) : value(v) {}

    constexpr auto operator<=>(const Arcminutes&) const = default;
};

// Conversions
constexpr Radians to_radians(Degrees deg) {
    return Radians{deg.value * (std::numbers::pi / 180.0)};
}

constexpr Degrees to_degrees(Radians rad) {
    return Degrees{rad.value * (180.0 / std::numbers::pi)};
}

constexpr Degrees hours_to_degrees(Hours h) {
    return Degrees{h.value * 15.0};
}

constexpr Hours degrees_to_hours(Degrees deg) {
    return Hours{deg.value / 15.0};
}

constexpr Arcminutes degrees_to_arcminutes(Degrees deg) {
    return Arcminutes{deg.value * 60.0};
}

constexpr Degrees arcminutes_to_degrees(Arcminutes arcmin) {
    return Degrees{arcmin.value / 60.0};
}

// Normalizations
inline Degrees normalize_degrees_360(Degrees deg) {
    double v = std::fmod(deg.value, 360.0);
    if (v < 0.0) v += 360.0;
    return Degrees{v};
}

inline Degrees normalize_degrees_180(Degrees deg) {
    double v = normalize_degrees_360(deg).value;
    if (v > 180.0) v -= 360.0;
    return Degrees{v};
}

inline Hours normalize_hours_24(Hours h) {
    double v = std::fmod(h.value, 24.0);
    if (v < 0.0) v += 24.0;
    return Hours{v};
}

} // namespace astro::units
