TARGET := iphone:clang:latest:14.0
ARCHS = arm64
DEBUG ?= 0
FINALPACKAGE ?= 1

INSTALL_TARGET_PROCESSES = Spotify

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EeveeSpotify

# Include Logos hooks and all Objective-C implementation files dynamically
EeveeSpotify_FILES = $(wildcard *.x) $(wildcard *.xm) $(wildcard *.m) $(wildcard *.mm)

# ARC enabled, suppress legacy symbol deprecation warnings on iOS 17.5+ SDK
EeveeSpotify_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function -Wno-nullability-completeness

# Link MobileCoreServices and UniformTypeIdentifiers to satisfy UTTypeConformsTo and modern UTType symbols
EeveeSpotify_FRAMEWORKS = UIKit \
                          Foundation \
                          CoreGraphics \
                          QuartzCore \
                          AVFoundation \
                          MobileCoreServices \
                          UniformTypeIdentifiers \
                          PhotosUI \
                          Photos \
                          ImageIO \
                          CoreMedia

EeveeSpotify_EXTRA_FRAMEWORKS = SwiftProtobuf

# Alias configuration for EeveeThemeEngine target compatibility
EeveeThemeEngine_FILES = $(EeveeSpotify_FILES)
EeveeThemeEngine_CFLAGS = $(EeveeSpotify_CFLAGS)
EeveeThemeEngine_FRAMEWORKS = $(EeveeSpotify_FRAMEWORKS)
EeveeThemeEngine_EXTRA_FRAMEWORKS = $(EeveeSpotify_EXTRA_FRAMEWORKS)

include $(THEOS_MAKE_PATH)/tweak.mk

# Support swiftprotobuf subproject if present in directory
ifneq ($(wildcard swiftprotobuf/Makefile),)
SUBPROJECTS += swiftprotobuf
include $(THEOS_MAKE_PATH)/aggregate.mk
endif

all::
