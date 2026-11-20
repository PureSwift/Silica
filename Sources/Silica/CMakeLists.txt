# The Core Graphics API, drawing through a backend.

file(GLOB_RECURSE sources CONFIGURE_DEPENDS *.swift)

silica_add_library(Silica ${sources})
