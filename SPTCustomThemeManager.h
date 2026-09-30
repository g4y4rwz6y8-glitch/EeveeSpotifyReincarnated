#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kEeveeThemeEnabledKey;
FOUNDATION_EXPORT NSString *const kEeveeThemeModeKey;
FOUNDATION_EXPORT NSString *const kEeveeThemeBlurEnabledKey;
FOUNDATION_EXPORT NSString *const kEeveeThemeBlurStyleKey;
FOUNDATION_EXPORT NSString *const kEeveeThemeOpacityKey;
FOUNDATION_EXPORT NSString *const kEeveeThemeBlurAlphaKey;
FOUNDATION_EXPORT NSString *const kEeveeThemeHexColorKey;
FOUNDATION_EXPORT NSString *const kEeveeThemeExtensionKey;
FOUNDATION_EXPORT NSString *const kEeveeThemeMediaFileName;
FOUNDATION_EXPORT NSString *const kEeveeThemeChangedNotification;
FOUNDATION_EXPORT NSString *const kEeveeThemeReloadNotification;

typedef NS_ENUM(NSInteger, EeveeThemeMode) {
    EeveeThemeModeNone  = 0,
    EeveeThemeModeColor = 1,
    EeveeThemeModeImage = 2,
    EeveeThemeModeGIF   = 3,
    EeveeThemeModeVideo = 4
};

@interface SPTCustomThemeManager : NSObject

@property (nonatomic, strong, readonly) UIView *containerView;
@property (nonatomic, weak, nullable) UIWindow *targetWindow;
@property (nonatomic, assign, readonly) BOOL isEnabled;
@property (nonatomic, assign, readonly) EeveeThemeMode currentMode;

+ (instancetype)sharedInstance;
+ (BOOL)isCustomThemeActive;
+ (NSString *)themeMediaDirectory;

- (void)setup;
- (void)applyTheme;
- (void)ensureAttached;
- (void)ensureAttachedToWindow:(nullable UIWindow *)window;
- (void)attachToWindow:(UIWindow *)window;
- (void)makeViewTransparent:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
