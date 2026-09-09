TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Spotify

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MySpotifyTheme

MySpotifyTheme_FILES = Tweak.x \
                       SPTCustomThemeManager.m \
                       SPTImageRenderer.m \
                       SPTGifRenderer.m \
                       SPTVideoRenderer.m \
                       SPTFloatingActionButton.m \
                       SPTSettingsViewController.m

MySpotifyTheme_CFLAGS = -fobjc-arc
MySpotifyTheme_FRAMEWORKS = UIKit QuartzCore AVFoundation CoreMedia ImageIO PhotosUI UniformTypeIdentifiers

include $(THEOS_MAKE_PATH)/tweak.mk
