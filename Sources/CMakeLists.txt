add_subdirectory(Silica)

if(SILICA_BUILD_CAIRO)
  add_subdirectory(SilicaCairo)
endif()

if(SILICA_BUILD_COREGRAPHICS)
  add_subdirectory(SilicaCoreGraphics)
endif()
