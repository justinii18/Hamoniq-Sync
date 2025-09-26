#----------------------------------------------------------------
# Generated CMake target import file.
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "HarmoniqSync::HarmoniqSyncCore" for configuration ""
set_property(TARGET HarmoniqSync::HarmoniqSyncCore APPEND PROPERTY IMPORTED_CONFIGURATIONS NOCONFIG)
set_target_properties(HarmoniqSync::HarmoniqSyncCore PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_NOCONFIG "CXX"
  IMPORTED_LOCATION_NOCONFIG "${_IMPORT_PREFIX}/lib/libHarmoniqSyncCore.a"
  )

list(APPEND _cmake_import_check_targets HarmoniqSync::HarmoniqSyncCore )
list(APPEND _cmake_import_check_files_for_HarmoniqSync::HarmoniqSyncCore "${_IMPORT_PREFIX}/lib/libHarmoniqSyncCore.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
