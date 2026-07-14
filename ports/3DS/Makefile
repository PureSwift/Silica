#---------------------------------------------------------------------------------
# ports/3DS -- Nintendo 3DS demo of Silica, built with Embedded Swift.
#
# Follows the same shape as junkbot-swift's ports/3DS: the ARM11 binary is the
# Silica core (compiled straight from ../../Sources/Silica, minus the
# Foundation-dependent files) plus the Silica3DS software renderer and this
# port's source/, targeting armv6-none-none-eabi (the 3DS's ARM11 application
# CPU is an ARMv6K core), linked against libctru, and packaged as a homebrew
# .3dsx with 3dsxtool/smdhtool.
#
# Prerequisites:
#   - devkitPro with devkitARM and libctru (`dkp-pacman -S 3ds-dev`;
#     export DEVKITPRO=/opt/devkitpro, DEVKITARM=$DEVKITPRO/devkitARM)
#   - 3dsxtool and smdhtool ($(DEVKITPRO)/tools/bin)
#   - A Swift toolchain whose Embedded stdlib ships an armv6-none-none-eabi
#     slice (6.3.2+ release toolchains do). Override SWIFTC to select one, e.g.
#     make SWIFTC=~/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/swiftc
#---------------------------------------------------------------------------------
.SUFFIXES:

ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>devkitpro")
endif
ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=$$DEVKITPRO/devkitARM")
endif

SWIFTC		?=	swiftc

TARGET		:=	SilicaDemo
BUILD		:=	build
REPO_ROOT	:=	../..
COMMON		:=	common/

CTRULIB		?=	$(DEVKITPRO)/libctru

PREFIX		:=	$(DEVKITARM)/bin/arm-none-eabi-
CC		:=	$(PREFIX)gcc
LD		:=	$(PREFIX)gcc

3DSXTOOL	?=	3dsxtool
SMDHTOOL	?=	smdhtool
ICON		:=	$(CTRULIB)/default_icon.png

#---------------------------------------------------------------------------------
# code generation -- the 3DS's ARM11 application CPU, armv6k/mpcore, hard float.
#---------------------------------------------------------------------------------
ARCH		:=	-march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft

CTRUDEFS	:=	-D__3DS__ -I$(COMMON) -I$(CTRULIB)/include

CFLAGS		:=	-g -Wall -O2 -mword-relocations -ffunction-sections -fdata-sections \
			$(ARCH) $(CTRUDEFS)

LDFLAGS		:=	-specs=3dsx.specs -g $(ARCH) \
			-Wl,-Map,$(TARGET).map -Wl,--gc-sections \
			-L$(CTRULIB)/lib

# The embedded stdlib's libswiftUnicodeDataTables.a is built soft-float and
# cannot link against the 3DS's hard-float ABI; shim.c stubs the Unicode
# normalization entry points instead (only reached for non-ASCII string
# comparison/hashing, which this port never performs).
LIBS		:=	-lctru -lm

#---------------------------------------------------------------------------------
# Embedded Swift flags, targeting armv6-none-none-eabi.
#---------------------------------------------------------------------------------
SWIFTFLAGS	:=	-target armv6-none-none-eabi \
			-enable-experimental-feature Embedded \
			-wmo -Osize \
			-module-name SilicaDemo \
			-Xcc -D__3DS__ \
			-Xcc -march=armv6k -Xcc -mtune=mpcore -Xcc -mfloat-abi=hard \
			-Xcc -isystem -Xcc $(DEVKITARM)/arm-none-eabi/include \
			-Xcc -I$(COMMON) \
			-Xcc -I$(CTRULIB)/include \
			-Xcc -fmodule-map-file=$(COMMON)module.modulemap

#---------------------------------------------------------------------------------
# Sources: the Silica core (minus Foundation-dependent files) + the Silica3DS
# software renderer (minus the Foundation-only backend registry) + this port.
#---------------------------------------------------------------------------------
CORE_EXCLUDE	:=	CGBitmapInfo.swift CGColorRenderingIntent.swift CGColorSpace.swift \
			CGImageSource.swift CGImageSourcePNG.swift CGImageDestination.swift \
			SilicaBackend.swift
CORE_SWIFT	:=	$(filter-out $(addprefix $(REPO_ROOT)/Sources/Silica/,$(CORE_EXCLUDE)), \
			$(wildcard $(REPO_ROOT)/Sources/Silica/*.swift))

3DS_EXCLUDE	:=	Nintendo3DSBackend.swift Export.swift
3DS_SWIFT	:=	$(filter-out $(addprefix $(REPO_ROOT)/Sources/Silica3DS/,$(3DS_EXCLUDE)), \
			$(wildcard $(REPO_ROOT)/Sources/Silica3DS/*.swift))

PORT_SWIFT	:=	$(wildcard source/*.swift)

OFILES		:=	$(BUILD)/silica.swift.o $(BUILD)/shim.o

#---------------------------------------------------------------------------------
.PHONY: all clean

all: $(TARGET).3dsx

$(BUILD):
	@mkdir -p $@

# All Swift (core + renderer + port) -> one object, whole-module.
$(BUILD)/silica.swift.o: $(CORE_SWIFT) $(3DS_SWIFT) $(PORT_SWIFT) \
		$(COMMON)module.modulemap $(COMMON)ctru_umbrella.h $(COMMON)shim.h | $(BUILD)
	@echo compiling Swift \(Silica + Silica3DS + demo\)
	$(SWIFTC) $(SWIFTFLAGS) -c $(CORE_SWIFT) $(3DS_SWIFT) $(PORT_SWIFT) -o $@

$(BUILD)/shim.o: $(COMMON)shim.c $(COMMON)shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OFILES)
	@echo linking $(notdir $@)
	$(LD) $(LDFLAGS) $(OFILES) $(LIBS) -o $@

$(BUILD)/icon.smdh: | $(BUILD)
	@echo packaging icon
	$(SMDHTOOL) --create SilicaDemo "Silica vector graphics demo" "PureSwift" $(ICON) $@

$(TARGET).3dsx: $(TARGET).elf $(BUILD)/icon.smdh
	@echo packaging $(notdir $@)
	$(3DSXTOOL) $(TARGET).elf $@ --smdh=$(BUILD)/icon.smdh

clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).elf $(TARGET).3dsx $(TARGET).map
