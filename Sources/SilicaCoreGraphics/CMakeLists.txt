# The Core Graphics backend, for Apple platforms.

file(GLOB sources CONFIGURE_DEPENDS *.swift)

silica_add_library(SilicaCoreGraphics ${sources})

target_link_libraries(SilicaCoreGraphics PUBLIC
  Silica)
