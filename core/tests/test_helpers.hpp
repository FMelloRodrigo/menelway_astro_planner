#pragma once

#include <iostream>
#include <cstdlib>
#include <cmath>
#include <string>

namespace astro::testing {

struct TestStats {
    static inline int total_assertions = 0;
    static inline int failed_assertions = 0;

    static void record_pass() {
        ++total_assertions;
    }

    static void record_fail(const char* expr, const char* file, int line, const std::string& extra = "") {
        ++total_assertions;
        ++failed_assertions;
        std::cerr << "  [FAIL] Assertion failed: " << expr
                  << " at " << file << ":" << line;
        if (!extra.empty()) {
            std::cerr << " (" << extra << ")";
        }
        std::cerr << std::endl;
    }

    static int summarize(const std::string& suite_name) {
        std::cout << "\n----------------------------------------\n";
        std::cout << "Suite: " << suite_name << "\n";
        std::cout << "Total assertions: " << total_assertions << "\n";
        if (failed_assertions == 0) {
            std::cout << "Status: ALL ASSERTIONS PASSED (100% OK)\n";
            std::cout << "----------------------------------------\n";
            return 0;
        } else {
            std::cerr << "Status: " << failed_assertions << " ASSERTION(S) FAILED!\n";
            std::cerr << "----------------------------------------\n";
            return 1;
        }
    }
};

} // namespace astro::testing

#define ASTRO_CHECK(cond) \
    do { \
        if (!(cond)) { \
            ::astro::testing::TestStats::record_fail(#cond, __FILE__, __LINE__); \
            std::exit(1); \
        } else { \
            ::astro::testing::TestStats::record_pass(); \
        } \
    } while (0)

#define ASTRO_CHECK_NEAR(a, b, eps) \
    do { \
        double diff_val = std::abs((a) - (b)); \
        if (diff_val > (eps)) { \
            std::string extra_msg = "|" + std::string(#a) + " - " + std::string(#b) + "| <= " + std::to_string(eps) + \
                " (" + std::to_string(a) + " vs " + std::to_string(b) + ", diff=" + std::to_string(diff_val) + ")"; \
            ::astro::testing::TestStats::record_fail(#a " ~ " #b, __FILE__, __LINE__, extra_msg); \
            std::exit(1); \
        } else { \
            ::astro::testing::TestStats::record_pass(); \
        } \
    } while (0)

#ifdef assert
#undef assert
#endif
#define assert(cond) ASTRO_CHECK(cond)
