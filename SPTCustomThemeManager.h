#import <UIKit/UIKit.h>
#import "SPTBackgroundRenderer.h"

@interface SPTCustomThemeManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, assign, readonly) BOOL themeEnabled;
@property (nonatomic, assign, readonly) SPTWallpaperType currentType;
@property (nonatomic, strong, readonly) id<SPTBackgroundRenderer> activeRenderer;

- (void)reloadPreferences;
- (void)installInWindow:(UIWindow *)window;
- (void)setWallpaperFileURL:(NSURL *)fileURL type:(SPTWallpaperType)type;
- (void)resetWallpaper;
- (void)applicationDidEnterBackground;
- (void)applicationWillEnterForeground;

@end
