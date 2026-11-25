add_subdirectory(Silica)

if(SILICA_BUILD_CAIRO)
  add_subdirectory(SilicaCairo)
endif()

if(SILICA_BUILD_QUARTZ)
  add_subdirectory(SilicaQuartz)
endif()

if(SILICA_BUILD_COREGRAPHICS)
  add_subdirectory(CSilicaCoreGraphics)
  add_subdirectory(SilicaCoreGraphicsABI)
endif()
