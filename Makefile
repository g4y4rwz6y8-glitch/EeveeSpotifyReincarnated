TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Spotify
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EeveeThemeEngine

EeveeThemeEngine_FILES = Tweak.x ThemeManager.m ThemeFilter.m ThemeSettingsViewController.m EeveeDumpSession.m
EeveeThemeEngine_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
EeveeThemeEngine_FRAMEWORKS = UIKit Foundation UniformTypeIdentifiers AVFoundation ImageIO Photos PhotosUI

include $(THEOS_MAKE_PATH)/tweak.mk
