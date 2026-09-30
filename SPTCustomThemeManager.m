#import "SPTCustomThemeManager.h"
#import "SPTImageRenderer.h"
#import "SPTGifRenderer.h"
#import "SPTVideoRenderer.h"

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
    
    if (enabled && mode == 0) {
        if ([SPTImageRenderer loadSavedImage] != nil) {
            [defaults setInteger:EeveeThemeModeImage forKey:kEeveeThemeModeKey];
            [defaults synchronize];
            return YES;
        } else if ([SPTVideoRenderer savedVideoURL] != nil) {
            [defaults setInteger:EeveeThemeModeVideo forKey:kEeveeThemeModeKey];
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
    self.containerView.userInteractionEnabled = NO;
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
    
    if (self.containerView.superview != window) {
        [self.containerView removeFromSuperview];
        [window insertSubview:self.containerView atIndex:0];
    }
    [window sendSubviewToBack:self.containerView];
    
    window.backgroundColor = [UIColor clearColor];
    window.opaque = NO;
    
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
        [[SPTGifRenderer sharedInstance] stopRendering];
        [[SPTVideoRenderer sharedInstance] stopRendering];
        return;
    }
    
    EeveeThemeMode mode = self.currentMode;
    
    // Manage active renderer according to selected media mode
    switch (mode) {
        case EeveeThemeModeImage: {
            [[SPTGifRenderer sharedInstance] stopRendering];
            [[SPTVideoRenderer sharedInstance] stopRendering];
            
            UIView *view = [SPTImageRenderer sharedInstance].rendererView;
            if (view.superview != self.containerView) {
                [view removeFromSuperview];
                [self.containerView addSubview:view];
            }
            [[SPTImageRenderer sharedInstance] updateLayoutWithBounds:self.containerView.bounds];
            [[SPTImageRenderer sharedInstance] startRendering];
            break;
        }
        case EeveeThemeModeGIF: {
            [[SPTImageRenderer sharedInstance] stopRendering];
            [[SPTVideoRenderer sharedInstance] stopRendering];
            
            UIView *view = [SPTGifRenderer sharedInstance].rendererView;
            if (view.superview != self.containerView) {
                [view removeFromSuperview];
                [self.containerView addSubview:view];
            }
            [[SPTGifRenderer sharedInstance] updateLayoutWithBounds:self.containerView.bounds];
            [[SPTGifRenderer sharedInstance] startRendering];
            break;
        }
        case EeveeThemeModeVideo: {
            [[SPTImageRenderer sharedInstance] stopRendering];
            [[SPTGifRenderer sharedInstance] stopRendering];
            
            UIView *view = [SPTVideoRenderer sharedInstance].rendererView;
            if (view.superview != self.containerView) {
                [view removeFromSuperview];
                [self.containerView addSubview:view];
            }
            [[SPTVideoRenderer sharedInstance] updateLayoutWithBounds:self.containerView.bounds];
            [[SPTVideoRenderer sharedInstance] startRendering];
            break;
        }
        default: {
            [[SPTImageRenderer sharedInstance] stopRendering];
            [[SPTGifRenderer sharedInstance] stopRendering];
            [[SPTVideoRenderer sharedInstance] stopRendering];
            break;
        }
    }
    
    [self ensureAttached];
}

- (void)makeViewTransparent:(UIView *)view {
    if (!view || ![SPTCustomThemeManager isCustomThemeActive]) return;
    view.backgroundColor = [UIColor clearColor];
    view.opaque = NO;
}

@end
