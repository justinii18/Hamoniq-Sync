# CMakeLists.txt for HarmoniqSyncCore
# C++ audio processing engine for HarmoniqSync

cmake_minimum_required(VERSION 3.20)
project(HarmoniqSyncCore VERSION 1.0.0 LANGUAGES CXX C)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Platform-specific settings
if(APPLE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0")
    set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64")
endif()

# Build configuration
set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type")
set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "RelWithDebInfo" "MinSizeRel")

# Compiler flags
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wno-unused-parameter")
    set(CMAKE_CXX_FLAGS_DEBUG "-g -O0 -DDEBUG")
    set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG -ffast-math")
endif()

# Apple-specific optimizations
if(APPLE)
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -flto=thin")
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mcpu=apple-m1")
    endif()
endif()

# Source files
set(HARMONIQ_SYNC_CORE_SOURCES
    src/audio_processor.cpp
    src/alignment_engine.cpp
    src/c_bridge.cpp
)

# Header files
set(HARMONIQ_SYNC_CORE_HEADERS
    include/harmoniq_sync.h
    include/audio_processor.hpp
    include/alignment_engine.hpp
)

# Create static library for linking with Swift
add_library(HarmoniqSyncCore STATIC
    ${HARMONIQ_SYNC_CORE_SOURCES}
    ${HARMONIQ_SYNC_CORE_HEADERS}
)

# Include directories
target_include_directories(HarmoniqSyncCore
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Platform-specific libraries
if(APPLE)
    # Link with Accelerate framework for optimized DSP operations
    find_library(ACCELERATE_FRAMEWORK Accelerate)
    if(ACCELERATE_FRAMEWORK)
        target_link_libraries(HarmoniqSyncCore PRIVATE ${ACCELERATE_FRAMEWORK})
        target_compile_definitions(HarmoniqSyncCore PRIVATE HARMONIQ_USE_ACCELERATE=1)
    endif()
    
    # Link with CoreAudio for audio format support (if needed in future)
    find_library(COREAUDIO_FRAMEWORK CoreAudio)
    if(COREAUDIO_FRAMEWORK)
        target_link_libraries(HarmoniqSyncCore PRIVATE ${COREAUDIO_FRAMEWORK})
    endif()
endif()

# Compiler-specific optimizations
if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND APPLE)
    # Use Apple's libc++ for better performance
    target_compile_options(HarmoniqSyncCore PRIVATE -stdlib=libc++)
    target_link_options(HarmoniqSyncCore PRIVATE -stdlib=libc++)
endif()

# Enable position-independent code for shared library usage
set_target_properties(HarmoniqSyncCore PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
)

# Add preprocessor definitions
target_compile_definitions(HarmoniqSyncCore PRIVATE
    HARMONIQ_SYNC_VERSION="${PROJECT_VERSION}"
    $<$<CONFIG:Debug>:HARMONIQ_SYNC_DEBUG=1>
    $<$<CONFIG:Release>:HARMONIQ_SYNC_RELEASE=1>
)

# Optional: Add threading support
find_package(Threads REQUIRED)
target_link_libraries(HarmoniqSyncCore PRIVATE Threads::Threads)

# Optional: Add OpenMP support for parallel processing
find_package(OpenMP)
if(OpenMP_CXX_FOUND AND NOT APPLE)
    # Note: Skip OpenMP on Apple as it's not well supported
    target_link_libraries(HarmoniqSyncCore PRIVATE OpenMP::OpenMP_CXX)
    target_compile_definitions(HarmoniqSyncCore PRIVATE HARMONIQ_USE_OPENMP=1)
endif()

# Installation (optional, for package distribution)
install(TARGETS HarmoniqSyncCore
    EXPORT HarmoniqSyncCoreTargets
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
    INCLUDES DESTINATION include
)

install(FILES ${HARMONIQ_SYNC_CORE_HEADERS}
    DESTINATION include/harmoniq_sync
)

# Export targets for find_package support
install(EXPORT HarmoniqSyncCoreTargets
    FILE HarmoniqSyncCoreTargets.cmake
    NAMESPACE HarmoniqSync::
    DESTINATION lib/cmake/HarmoniqSyncCore
)

# Generate and install package configuration
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/HarmoniqSyncCoreConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY AnyNewerVersion
)

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/HarmoniqSyncCoreConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/HarmoniqSyncCoreConfig.cmake"
    INSTALL_DESTINATION lib/cmake/HarmoniqSyncCore
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/HarmoniqSyncCoreConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/HarmoniqSyncCoreConfigVersion.cmake"
    DESTINATION lib/cmake/HarmoniqSyncCore
)

# Testing (optional)
option(HARMONIQ_BUILD_TESTS "Build unit tests" OFF)
if(HARMONIQ_BUILD_TESTS)
    enable_testing()
    
    # Find Google Test
    find_package(GTest REQUIRED)
    include(GoogleTest)
    
    # Create test executable
    add_executable(test_audio_processor 
        test/test_audio_processor.cpp
    )
    
    target_link_libraries(test_audio_processor 
        HarmoniqSyncCore 
        GTest::gtest 
        GTest::gtest_main 
        ${CMAKE_THREAD_LIBS_INIT}
    )
    
    target_include_directories(test_audio_processor PRIVATE 
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    )
    
    # Discover tests
    gtest_discover_tests(test_audio_processor)
endif()

# Benchmarks (optional)
option(HARMONIQ_BUILD_BENCHMARKS "Build performance benchmarks" OFF)
if(HARMONIQ_BUILD_BENCHMARKS)
    add_subdirectory(benchmarks)
endif()

# Print configuration summary
message(STATUS "HarmoniqSyncCore Configuration Summary:")
message(STATUS "  Version: ${PROJECT_VERSION}")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  C++ standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "  Compiler: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
if(APPLE)
    message(STATUS "  Target architectures: ${CMAKE_OSX_ARCHITECTURES}")
    message(STATUS "  Deployment target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
    if(ACCELERATE_FRAMEWORK)
        message(STATUS "  Accelerate framework: Found")
    endif()
endif()
if(OpenMP_CXX_FOUND)
    message(STATUS "  OpenMP: Found")
endif()
message(STATUS "  Tests: ${HARMONIQ_BUILD_TESTS}")
message(STATUS "  Benchmarks: ${HARMONIQ_BUILD_BENCHMARKS}")