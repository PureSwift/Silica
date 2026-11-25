# The part of libCoreGraphics that is C: the headers, the constants exported
# as data, and the stubs of what isn't implemented yet. Its objects go into
# libCoreGraphics (Sources/SilicaCoreGraphicsABI).

add_library(CSilicaCoreGraphics OBJECT
  constants.c
  unimplemented.c
  gen/stubs.c)

set_target_properties(CSilicaCoreGraphics PROPERTIES
  POSITION_INDEPENDENT_CODE ON
  C_STANDARD 11)

target_include_directories(CSilicaCoreGraphics PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include)

# C and Swift clients include <CoreGraphics/CoreGraphics.h>, and Swift imports
# the `CoreGraphics` module.
install(DIRECTORY include/CoreGraphics
  DESTINATION include)
install(FILES CoreGraphics.modulemap
  DESTINATION include/CoreGraphics
  RENAME module.modulemap)
