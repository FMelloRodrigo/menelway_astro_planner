cmake_minimum_required(VERSION 3.20)
project(astro_core VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Position Independent Code for shared libraries
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Target-scoped compile options to avoid leaking flags to parent/third-party targets
add_library(astro_compile_options INTERFACE)
if(MSVC)
    target_compile_options(astro_compile_options INTERFACE /W4 /permissive- /utf-8 /EHsc)
    target_compile_definitions(astro_compile_options INTERFACE _CRT_SECURE_NO_WARNINGS)
else()
    target_compile_options(astro_compile_options INTERFACE -Wall -Wextra -Wpedantic)
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
    src/target_filter_service.cpp
)

# Object library: compile core sources once to avoid duplicate compilation
add_library(astro_core_obj OBJECT ${ASTRO_CORE_SOURCES})
target_link_libraries(astro_core_obj PUBLIC astro_compile_options sqlite3)
target_include_directories(astro_core_obj PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Static core for internal testing
add_library(astro_core_static STATIC $<TARGET_OBJECTS:astro_core_obj>)
target_link_libraries(astro_core_static PUBLIC sqlite3)
target_include_directories(astro_core_static PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Shared library for Flutter / Dart FFI (astro_core.dll / libastro_core.so)
add_library(astro_core SHARED
    $<TARGET_OBJECTS:astro_core_obj>
    capi/astro_capi.cpp
)
target_link_libraries(astro_core PRIVATE astro_compile_options PUBLIC sqlite3)
target_include_directories(astro_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/capi
)
target_compile_definitions(astro_core PRIVATE ASTRO_CORE_EXPORTS)

if(ANDROID)
    target_link_libraries(astro_core PUBLIC log)
endif()

# Test executables: enabled by default only when building standalone, off when included by Flutter runner
if(CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
    set(ASTRO_BUILD_TESTS_DEFAULT ON)
else()
    set(ASTRO_BUILD_TESTS_DEFAULT OFF)
endif()
option(ASTRO_BUILD_TESTS "Build C++ unit test executables" ${ASTRO_BUILD_TESTS_DEFAULT})

if(ASTRO_BUILD_TESTS AND NOT ANDROID)
    enable_testing()

    add_executable(test_astro tests/test_astro.cpp)
    target_link_libraries(test_astro PRIVATE astro_compile_options astro_core_static)
    add_test(NAME test_astro COMMAND test_astro)

    add_executable(test_storage tests/test_storage.cpp)
    target_link_libraries(test_storage PRIVATE astro_compile_options astro_core_static)
    add_test(NAME test_storage COMMAND test_storage)

    add_executable(test_capi tests/test_capi.cpp)
    target_include_directories(test_capi PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/capi)
    target_link_libraries(test_capi PRIVATE astro_compile_options astro_core)
    add_test(NAME test_capi COMMAND test_capi)
endif()
