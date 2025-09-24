# HarmoniqSyncCoreConfig.cmake
# Configuration file for the HarmoniqSyncCore package


####### Expanded from @PACKAGE_INIT@ by configure_package_config_file() #######
####### Any changes to this file will be overwritten by the next CMake run ####
####### The input file was HarmoniqSyncCoreConfig.cmake.in                            ########

get_filename_component(PACKAGE_PREFIX_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../" ABSOLUTE)

macro(set_and_check _var _file)
  set(${_var} "${_file}")
  if(NOT EXISTS "${_file}")
    message(FATAL_ERROR "File or directory ${_file} referenced by variable ${_var} does not exist !")
  endif()
endmacro()

macro(check_required_components _NAME)
  foreach(comp ${${_NAME}_FIND_COMPONENTS})
    if(NOT ${_NAME}_${comp}_FOUND)
      if(${_NAME}_FIND_REQUIRED_${comp})
        set(${_NAME}_FOUND FALSE)
      endif()
    endif()
  endforeach()
endmacro()

####################################################################################

include(CMakeFindDependencyMacro)

# Find required dependencies
find_dependency(Threads REQUIRED)

# Platform-specific dependencies
if(APPLE)
    find_library(ACCELERATE_FRAMEWORK Accelerate REQUIRED)
    find_library(COREAUDIO_FRAMEWORK CoreAudio REQUIRED)
endif()

# Include the targets file
include("${CMAKE_CURRENT_LIST_DIR}/HarmoniqSyncCoreTargets.cmake")

# Provide variables for consumers
set(HarmoniqSyncCore_VERSION 1.0.0)
set(HarmoniqSyncCore_VERSION_MAJOR 1)
set(HarmoniqSyncCore_VERSION_MINOR 0)
set(HarmoniqSyncCore_VERSION_PATCH 0)

# Check that the targets exist
check_required_components(HarmoniqSyncCore)
