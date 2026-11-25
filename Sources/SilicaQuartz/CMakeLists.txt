# The Quartz (Apple Core Graphics) backend, for Apple platforms.

file(GLOB sources CONFIGURE_DEPENDS *.swift)

silica_add_library(SilicaQuartz ${sources})

target_link_libraries(SilicaQuartz PUBLIC
  Silica)
