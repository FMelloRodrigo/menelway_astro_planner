#pragma once

#include <iostream>
#include <cstdlib>
#include <cmath>

#define ASTRO_CHECK(cond) \
    do { \
        if (!(cond)) { \
            std::cerr << "Assertion failed: " #cond << " at " << __FILE__ << ":" << __LINE__ << std::endl; \
            std::exit(1); \
        } \
    } while (0)

#define ASTRO_CHECK_NEAR(a, b, eps) \
    do { \
        if (std::abs((a) - (b)) > (eps)) { \
            std::cerr << "Assertion failed: |" #a " - " #b "| <= " #eps \
                      << " (" << (a) << " vs " << (b) << ", diff=" << std::abs((a) - (b)) << ")" \
                      << " at " << __FILE__ << ":" << __LINE__ << std::endl; \
            std::exit(1); \
        } \
    } while (0)

#ifdef assert
#undef assert
#endif
#define assert(cond) ASTRO_CHECK(cond)
