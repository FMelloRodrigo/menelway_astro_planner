cmake_minimum_required(VERSION 3.20)
project(astro_core VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Position Independent Code for shared libraries
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(MSVC)
    add_compile_options(/W4 /permissive- /utf-8 /EHsc)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
else()
    add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# SQLite3 Amalgamation
add_library(sqlite3 STATIC
    third_party/sqlite3/sqlite3.c
)
target_include_directories(sqlite3 PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/sqlite3
)
target_compile_definitions(sqlite3 PRIVATE
    SQLITE_ENABLE_FTS5=1
    SQLITE_THREADSAFE=1
    SQLITE_ENABLE_RTREE=1
)
if(MSVC)
    target_compile_options(sqlite3 PRIVATE /W0) # suppress third-party C warnings
endif()

# Core library sources
set(ASTRO_CORE_SOURCES
    src/time.cpp
    src/coordinates.cpp
    src/ephemeris.cpp
    src/horizon.cpp
    src/visibility.cpp
    src/storage.cpp
)

# Static core for internal testing
add_library(astro_core_static STATIC ${ASTRO_CORE_SOURCES})
target_include_directories(astro_core_static PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)
target_link_libraries(astro_core_static PUBLIC sqlite3)

# Shared library for Flutter / Dart FFI (astro_core.dll / libastro_core.so)
add_library(astro_core SHARED
    ${ASTRO_CORE_SOURCES}
    capi/astro_capi.cpp
)
target_include_directories(astro_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/capi
)
target_link_libraries(astro_core PUBLIC sqlite3)
target_compile_definitions(astro_core PRIVATE ASTRO_CORE_EXPORTS)

if(ANDROID)
    target_link_libraries(astro_core PUBLIC log)
endif()

# Test executables (desktop only)
if(NOT ANDROID)
    add_executable(test_astro tests/test_astro.cpp)
    target_link_libraries(test_astro PRIVATE astro_core_static)

    add_executable(test_storage tests/test_storage.cpp)
    target_link_libraries(test_storage PRIVATE astro_core_static)

    add_executable(test_capi tests/test_capi.cpp)
    target_include_directories(test_capi PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/capi)
    target_link_libraries(test_capi PRIVATE astro_core)
endif()
