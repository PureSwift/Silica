# Helpers for Silica's targets: flags every module shares, and where they
# install.

include(GNUInstallDirs)

# The Swift resource directory's name for the system: `linux`, `macosx`.
if(NOT SWIFT_SYSTEM_NAME)
  if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
    set(SWIFT_SYSTEM_NAME macosx)
  else()
    string(TOLOWER "${CMAKE_SYSTEM_NAME}" SWIFT_SYSTEM_NAME)
  endif()
endif()

# The directory of the resource directory that holds modules for the
# target's architecture. When cross compiling, set this (or
# CMAKE_SYSTEM_PROCESSOR) to the target's.
if(NOT SWIFT_SYSTEM_ARCH)
  set(SWIFT_SYSTEM_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
endif()

set(SILICA_INSTALL_LIBDIR "lib/swift/${SWIFT_SYSTEM_NAME}" CACHE STRING
  "Where libraries install, under the prefix")
set(SILICA_INSTALL_SWIFTMODULEDIR "${SILICA_INSTALL_LIBDIR}/${SWIFT_SYSTEM_ARCH}" CACHE STRING
  "Where Swift modules install, under the prefix")

# Adds one of Silica's Swift libraries, named for its module.
#
#   silica_add_library(<name> [<source>...])
function(silica_add_library name)
  add_library(${name} ${ARGN})

  if(SILICA_ENABLE_LIBRARY_EVOLUTION)
    target_compile_options(${name} PRIVATE
      -enable-library-evolution
      "SHELL:-emit-module-interface-path ${CMAKE_Swift_MODULE_DIRECTORY}/${name}.swiftinterface")
  endif()

  set_target_properties(${name} PROPERTIES
    Swift_MODULE_NAME ${name}
    INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_Swift_MODULE_DIRECTORY})

  install(TARGETS ${name}
    ARCHIVE DESTINATION ${SILICA_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${SILICA_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
  install(FILES
      ${CMAKE_Swift_MODULE_DIRECTORY}/${name}.swiftmodule
      ${CMAKE_Swift_MODULE_DIRECTORY}/${name}.swiftdoc
    DESTINATION ${SILICA_INSTALL_SWIFTMODULEDIR}
    OPTIONAL)
  if(SILICA_ENABLE_LIBRARY_EVOLUTION)
    install(FILES
        ${CMAKE_Swift_MODULE_DIRECTORY}/${name}.swiftinterface
      DESTINATION ${SILICA_INSTALL_SWIFTMODULEDIR}
      OPTIONAL)
  endif()
endfunction()
