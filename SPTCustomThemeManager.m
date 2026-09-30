#import "SPTCustomThemeManager.h"
#import "SPTImageRenderer.h"

NSString *const kEeveeThemeEnabledKey          = @"EeveeTheme_Enabled";
NSString *const kEeveeThemeModeKey             = @"EeveeTheme_Mode";
NSString *const kEeveeThemeBlurEnabledKey      = @"EeveeTheme_BlurEnabled";
NSString *const kEeveeThemeBlurStyleKey        = @"EeveeTheme_BlurStyle";
NSString *const kEeveeThemeOpacityKey          = @"EeveeTheme_Opacity";
NSString *const kEeveeThemeBlurAlphaKey        = @"EeveeTheme_BlurAlpha";
NSString *const kEeveeThemeHexColorKey         = @"EeveeTheme_HexColor";
NSString *const kEeveeThemeExtensionKey        = @"EeveeTheme_MediaExtension";
NSString *const kEeveeThemeMediaFileName       = @"custom_theme_media";
NSString *const kEeveeThemeChangedNotification = @"SPTThemeSettingsChangedNotification";
NSString *const kEeveeThemeReloadNotification  = @"EeveeThemeReloadNotification";

@interface SPTCustomThemeManager ()

// Turn public readonly containerView into private readwrite
@property (nonatomic, strong, readwrite) UIView *containerView;

@end

@implementation SPTCustomThemeManager

+ (instancetype)sharedInstance {
    static SPTCustomThemeManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SPTCustomThemeManager alloc] init];
    });
    return instance;
}

+ (NSString *)themeMediaDirectory {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *baseDir = paths.firstObject ?: NSTemporaryDirectory();
    NSString *themeDir = [baseDir stringByAppendingPathComponent:@"EeveeTheme"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:themeDir]) {
        [fileManager createDirectoryAtPath:themeDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return themeDir;
}

+ (BOOL)isCustomThemeActive {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enabled = [defaults boolForKey:kEeveeThemeEnabledKey];
    NSInteger mode = [defaults integerForKey:kEeveeThemeModeKey];
    
    // Auto-fallback: if theme is enabled but mode was 0, activate image mode if media exists
    if (enabled && mode == 0) {
        if ([SPTImageRenderer loadSavedImage] != nil) {
            [defaults setInteger:EeveeThemeModeImage forKey:kEeveeThemeModeKey];
            [defaults synchronize];
            return YES;
        }
    }
    return (enabled && mode > 0);
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    self.containerView = [[UIView alloc] initWithFrame:screenBounds];
    self.containerView.backgroundColor = [UIColor clearColor];
    self.containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.containerView.clipsToBounds = YES;
    self.containerView.userInteractionEnabled = NO; // Allows touch events to pass directly to Spotify controls
    self.containerView.hidden = ![SPTCustomThemeManager isCustomThemeActive];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(applyTheme) name:kEeveeThemeChangedNotification object:nil];
    [nc addObserver:self selector:@selector(applyTheme) name:kEeveeThemeReloadNotification object:nil];
    [nc addObserver:self selector:@selector(ensureAttached) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (BOOL)isEnabled {
    return [SPTCustomThemeManager isCustomThemeActive];
}

- (EeveeThemeMode)currentMode {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return (EeveeThemeMode)[defaults integerForKey:kEeveeThemeModeKey];
}

- (UIWindow *)findActiveWindow {
    UIWindow *candidate = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *w in windowScene.windows) {
                    if (w.isKeyWindow && !w.isHidden) {
                        return w;
                    }
                    if (!w.isHidden && [NSStringFromClass([w class]) isEqualToString:@"UIWindow"]) {
                        candidate = w;
                    }
                }
            }
        }
    }
    if (candidate) return candidate;
    return [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
}

- (void)attachToWindow:(UIWindow *)window {
    if (!window) return;
    
    NSString *windowClass = NSStringFromClass([window class]);
    if ([windowClass containsString:@"TextEffects"] || [windowClass containsString:@"Keyboard"] || [windowClass containsString:@"Alert"]) {
        return;
    }
    
    self.targetWindow = window;
    self.containerView.frame = window.bounds;
    
    // Ensure containerView is inserted at index 0 and kept at the back of the window
    if (self.containerView.superview != window) {
        [self.containerView removeFromSuperview];
        [window insertSubview:self.containerView atIndex:0];
    }
    [window sendSubviewToBack:self.containerView];
    
    // Make hosting window transparent
    window.backgroundColor = [UIColor clearColor];
    window.opaque = NO;
    
    // Make rootViewController view transparent
    if (window.rootViewController && window.rootViewController.view) {
        window.rootViewController.view.backgroundColor = [UIColor clearColor];
        window.rootViewController.view.opaque = NO;
    }
    
    [self applyTheme];
}

- (void)ensureAttachedToWindow:(nullable UIWindow *)window {
    UIWindow *target = window ?: self.targetWindow ?: [self findActiveWindow];
    if (target) {
        if (self.containerView.superview != target || [target.subviews indexOfObject:self.containerView] != 0) {
            [self attachToWindow:target];
        }
    }
}

- (void)ensureAttached {
    [self ensureAttachedToWindow:nil];
}

- (void)applyTheme {
    BOOL active = [SPTCustomThemeManager isCustomThemeActive];
    self.containerView.hidden = !active;
    
    if (!active) {
        [[SPTImageRenderer sharedInstance] stopRendering];
        return;
    }
    
    EeveeThemeMode mode = self.currentMode;
    if (mode == EeveeThemeModeImage || mode == EeveeThemeModeNone) {
        UIView *rendererView = [SPTImageRenderer sharedInstance].rendererView;
        if (rendererView.superview != self.containerView) {
            [rendererView removeFromSuperview];
            [self.containerView addSubview:rendererView];
        }
        [[SPTImageRenderer sharedInstance] updateLayoutWithBounds:self.containerView.bounds];
        [[SPTImageRenderer sharedInstance] startRendering];
    } else {
        [[SPTImageRenderer sharedInstance] stopRendering];
    }
    
    [self ensureAttached];
}

- (void)makeViewTransparent:(UIView *)view {
    if (!view || ![SPTCustomThemeManager isCustomThemeActive]) return;
    view.backgroundColor = [UIColor clearColor];
    view.opaque = NO;
}

@end
