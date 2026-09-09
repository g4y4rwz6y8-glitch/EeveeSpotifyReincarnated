#import "SPTCustomThemeManager.h"
#import "SPTImageRenderer.h"
#import "SPTGifRenderer.h"
#import "SPTVideoRenderer.h"

static NSString * const kThemeEnabledKey = @"SPTCustomThemeEnabled";
static NSString * const kWallpaperTypeKey = @"SPTCustomWallpaperType";
static NSString * const kDomain = @"com.yourdomain.spotifytheme";

@interface SPTCustomThemeManager ()
@property (nonatomic, weak) UIWindow *installedWindow;
@end

@implementation SPTCustomThemeManager

+ (instancetype)sharedManager {
    static SPTCustomThemeManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[SPTCustomThemeManager alloc] init];
        [shared reloadPreferences];
    });
    return shared;
}

- (NSString *)themeDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dir = [paths.firstObject stringByAppendingPathComponent:@"SPTCustomTheme"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                   withIntermediateDirectories:YES
                                                    attributes:nil error:nil];
    }
    return dir;
}

- (NSURL *)storedAssetURLForType:(SPTWallpaperType)type {
    NSString *filename;
    switch (type) {
        case SPTWallpaperTypeImage: filename = @"wallpaper.png"; break;
        case SPTWallpaperTypeGif:   filename = @"wallpaper.gif"; break;
        case SPTWallpaperTypeVideo: filename = @"wallpaper.mp4"; break;
        default: return nil;
    }
    return [NSURL fileURLWithPath:[[self themeDirectory] stringByAppendingPathComponent:filename]];
}

- (void)reloadPreferences {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
    _themeEnabled = CFPreferencesGetAppBooleanValue(
        (__bridge CFStringRef)kThemeEnabledKey, (__bridge CFStringRef)kDomain, NULL);

    Boolean hasType = false;
    CFIndex typeVal = CFPreferencesGetAppIntegerValue(
        (__bridge CFStringRef)kWallpaperTypeKey, (__bridge CFStringRef)kDomain, &hasType);
    SPTWallpaperType type = hasType ? (SPTWallpaperType)typeVal : SPTWallpaperTypeNone;

    [self activateRendererForType:type loadExisting:YES];
}

- (void)activateRendererForType:(SPTWallpaperType)type loadExisting:(BOOL)loadExisting {
    if (_activeRenderer && _currentType == type) return;

    [_activeRenderer teardown];
    _activeRenderer = nil;
    _currentType = type;

    switch (type) {
        case SPTWallpaperTypeImage: _activeRenderer = [SPTImageRenderer new]; break;
        case SPTWallpaperTypeGif:   _activeRenderer = [SPTGifRenderer new]; break;
        case SPTWallpaperTypeVideo: _activeRenderer = [SPTVideoRenderer new]; break;
        case SPTWallpaperTypeNone:  _activeRenderer = nil; break;
    }

    if (_activeRenderer && self.installedWindow) {
        [_activeRenderer installInWindow:self.installedWindow];
    }

    if (loadExisting && _activeRenderer) {
        NSURL *url = [self storedAssetURLForType:type];
        if (url && [[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
            [_activeRenderer loadFromFileURL:url completion:nil];
        }
    }
}

- (void)setWallpaperFileURL:(NSURL *)fileURL type:(SPTWallpaperType)type {
    NSURL *dest = [self storedAssetURLForType:type];
    if (!dest) return;

    [[NSFileManager defaultManager] removeItemAtURL:dest error:nil];
    [[NSFileManager defaultManager] copyItemAtURL:fileURL toURL:dest error:nil];

    CFPreferencesSetAppValue((__bridge CFStringRef)kWallpaperTypeKey,
                              (__bridge CFNumberRef)@(type), (__bridge CFStringRef)kDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);

    [self activateRendererForType:type loadExisting:NO];
    [_activeRenderer loadFromFileURL:dest completion:nil];
}

- (void)resetWallpaper {
    [self activateRendererForType:SPTWallpaperTypeNone loadExisting:NO];
    NSArray *files = @[@"wallpaper.png", @"wallpaper.gif", @"wallpaper.mp4"];
    for (NSString *f in files) {
        [[NSFileManager defaultManager] removeItemAtPath:
            [[self themeDirectory] stringByAppendingPathComponent:f] error:nil];
    }
}

- (void)installInWindow:(UIWindow *)window {
    if (!self.themeEnabled || !window) return;
    self.installedWindow = window;
    if (self.activeRenderer) {
        [self.activeRenderer installInWindow:window];
        [window sendSubviewToBack:self.activeRenderer.renderView];
    }
}

- (void)applicationDidEnterBackground {
    [self.activeRenderer pause];
}

- (void)applicationWillEnterForeground {
    [self.activeRenderer resume];
}

@end
