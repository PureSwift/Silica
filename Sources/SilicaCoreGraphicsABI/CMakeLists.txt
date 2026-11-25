# libCoreGraphics: Darwin's CoreGraphics C API, drawn by Silica. The Swift
# functions here and the C objects of CSilicaCoreGraphics, exporting exactly
# the symbols in Scripts/CoreGraphics/symbols.txt (and the Swift API Perry
# uses to supply its own objects), each also under its Mach-O name
# (`_CGPathCreateMutable`), as Darwin code links it.

file(GLOB sources CONFIGURE_DEPENDS *.swift)

set(exports ${PROJECT_SOURCE_DIR}/Scripts/CoreGraphics)

add_library(CoreGraphics SHARED
  ${sources}
  $<TARGET_OBJECTS:CSilicaCoreGraphics>)

set_target_properties(CoreGraphics PROPERTIES
  Swift_MODULE_NAME SilicaCoreGraphicsABI
  LINKER_LANGUAGE Swift
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_Swift_MODULE_DIRECTORY}
  LINK_DEPENDS "${exports}/exports.map;${exports}/macho-aliases.ld")

target_include_directories(CoreGraphics PRIVATE
  ${PROJECT_SOURCE_DIR}/Sources/CSilicaCoreGraphics/include)

target_link_libraries(CoreGraphics PRIVATE
  Silica)

target_link_options(CoreGraphics PRIVATE
  "LINKER:--version-script=${exports}/exports.map"
  "LINKER:${exports}/macho-aliases.ld")

install(TARGETS CoreGraphics
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin)
install(FILES
    ${CMAKE_Swift_MODULE_DIRECTORY}/SilicaCoreGraphicsABI.swiftmodule
    ${CMAKE_Swift_MODULE_DIRECTORY}/SilicaCoreGraphicsABI.swiftdoc
  DESTINATION ${SILICA_INSTALL_SWIFTMODULEDIR}
  OPTIONAL)
