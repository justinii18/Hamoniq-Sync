#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "HarmoniqSync::HarmoniqSyncCore" for configuration "Release"
set_property(TARGET HarmoniqSync::HarmoniqSyncCore APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(HarmoniqSync::HarmoniqSyncCore PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libHarmoniqSyncCore.a"
  )

list(APPEND _cmake_import_check_targets HarmoniqSync::HarmoniqSyncCore )
list(APPEND _cmake_import_check_files_for_HarmoniqSync::HarmoniqSyncCore "${_IMPORT_PREFIX}/lib/libHarmoniqSyncCore.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
