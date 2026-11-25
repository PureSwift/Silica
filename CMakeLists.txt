# Builds Silica as shared Swift libraries for a system image (Buildroot and
# the like), where Swift modules live in the compiler's resource directory
# and apps link them like the OS's own frameworks.
#
# SwiftPM (Package.swift) stays the way to develop and test Silica, and to
# build its 3DS and web backends.

cmake_minimum_required(VERSION 3.26)

if(POLICY CMP0157)
  # Swift's new build model: modules are emitted on their own, in parallel.
  cmake_policy(SET CMP0157 NEW)
endif()

project(Silica
  LANGUAGES Swift)

list(APPEND CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake/modules)

option(BUILD_SHARED_LIBS "Build shared libraries" ON)
option(SILICA_ENABLE_LIBRARY_EVOLUTION "Build with library evolution and emit module interfaces, so apps keep working when Silica is updated" ON)
if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
  option(SILICA_BUILD_QUARTZ "Build SilicaQuartz, the Quartz (Core Graphics) backend" ON)
  option(SILICA_BUILD_CAIRO "Build SilicaCairo, the Cairo backend (needs the Cairo and FontConfig Swift modules)" OFF)
else()
  set(SILICA_BUILD_QUARTZ OFF)
  option(SILICA_BUILD_CAIRO "Build SilicaCairo, the Cairo backend (needs the Cairo and FontConfig Swift modules)" ON)
endif()

set(CMAKE_Swift_LANGUAGE_VERSION 6)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

include(SilicaSupport)

add_subdirectory(Sources)
