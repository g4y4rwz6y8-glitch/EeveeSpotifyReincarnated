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

# System frameworks required by the tweak and theme engine
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

# Only link SwiftProtobuf if the framework has actually been built and placed on disk
ifneq ($(wildcard $(THEOS)/lib/SwiftProtobuf.framework),)
EeveeSpotify_EXTRA_FRAMEWORKS += SwiftProtobuf
else ifneq ($(wildcard ./SwiftProtobuf.framework),)
EeveeSpotify_EXTRA_FRAMEWORKS += SwiftProtobuf
EeveeSpotify_LDFLAGS += -F.
else ifneq ($(wildcard ./swiftprotobuf/SwiftProtobuf.framework),)
EeveeSpotify_EXTRA_FRAMEWORKS += SwiftProtobuf
EeveeSpotify_LDFLAGS += -F./swiftprotobuf
endif

# Alias configuration for EeveeThemeEngine target compatibility
EeveeThemeEngine_FILES = $(EeveeSpotify_FILES)
EeveeThemeEngine_CFLAGS = $(EeveeSpotify_CFLAGS)
EeveeThemeEngine_FRAMEWORKS = $(EeveeSpotify_FRAMEWORKS)
EeveeThemeEngine_EXTRA_FRAMEWORKS = $(EeveeSpotify_EXTRA_FRAMEWORKS)

include $(THEOS_MAKE_PATH)/tweak.mk

# Support swiftprotobuf subproject only if a Makefile exists inside swiftprotobuf/
ifneq ($(wildcard swiftprotobuf/Makefile),)
SUBPROJECTS += swiftprotobuf
include $(THEOS_MAKE_PATH)/aggregate.mk
endif

all::
