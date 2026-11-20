# The Cairo backend, with fonts from FontConfig and FreeType.
#
# The `Cairo` and `FontConfig` Swift modules (PureSwift/Cairo and
# PureSwift/FontConfig) and their C modules come from the Swift resource
# directory, or from search paths in CMAKE_Swift_FLAGS.

file(GLOB sources CONFIGURE_DEPENDS *.swift)

silica_add_library(SilicaCairo ${sources})

target_link_libraries(SilicaCairo
  PUBLIC
    Silica
  PRIVATE
    Cairo
    FontConfig)
