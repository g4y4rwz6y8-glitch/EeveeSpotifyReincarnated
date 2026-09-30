#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SPTCustomThemeManager.h"
#import "SPTImageRenderer.h"
#import "SPTGifRenderer.h"
#import "SPTVideoRenderer.h"
#import "SPTFloatingActionButton.h"
#import "ThemeSettingsViewController.h"

// Recursively strips opaque backgrounds across Spotify container hierarchies
static void StripViewAndSubviews(UIView *view, NSInteger depth) {
    if (!view || depth > 5) return;
    
    NSString *cls = NSStringFromClass([view class]);
    
    // Protect UI controls from being stripped of necessary interactive visual state
    if ([view isKindOfClass:[UIButton class]] || [view isKindOfClass:[UISwitch class]] || [view isKindOfClass:[UISlider class]]) {
        return;
    }
    
    if (view.backgroundColor && view.backgroundColor != [UIColor clearColor]) {
        view.backgroundColor = [UIColor clearColor];
    }
    view.opaque = NO;
    
    // Eliminate gradient/dimming masks
    if ([cls containsString:@"GLUEGradient"] || 
        [cls containsString:@"SPTNowPlayingBackgroundView"] ||
        [cls containsString:@"DimmingView"] ||
        [cls containsString:@"GradientOverlay"]) {
        view.alpha = 0.0;
        view.hidden = YES;
    }
    
    for (UIView *subview in view.subviews) {
        StripViewAndSubviews(subview, depth + 1);
    }
}

// 1. Hook UIWindow to establish layer 0 anchoring and floating button attachment
%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        [[SPTCustomThemeManager sharedInstance] attachToWindow:self];
    }
    [[SPTFloatingActionButton sharedInstance] attachToWindow:self];
    
    static char kThemeDoubleTapKey;
    if (!objc_getAssociatedObject(self, &kThemeDoubleTapKey)) {
        UITapGestureRecognizer *twoFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:[SPTFloatingActionButton sharedInstance] action:@selector(presentThemeSettings)];
        twoFingerTap.numberOfTouchesRequired = 2;
        twoFingerTap.numberOfTapsRequired = 2;
        twoFingerTap.cancelsTouchesInView = NO;
        [self addGestureRecognizer:twoFingerTap];
        objc_setAssociatedObject(self, &kThemeDoubleTapKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)layoutSubviews {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        [[SPTCustomThemeManager sharedInstance] ensureAttachedToWindow:self];
    }
    [self bringSubviewToFront:[SPTFloatingActionButton sharedInstance]];
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig;
    if (motion == UIEventSubtypeMotionShake) {
        [[SPTFloatingActionButton sharedInstance] presentThemeSettings];
    }
}

%end

// 2. Comprehensive UIViewController hook: Fixes "Your Library", Home, Search & Now Playing
%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        NSString *className = NSStringFromClass([self class]);
        
        // Match Spotify's root, library, navigation, and page containers
        if ([className containsString:@"SPT"] ||
            [className containsString:@"Library"] ||
            [className containsString:@"YourLibrary"] ||
            [className containsString:@"Root"] ||
            [className containsString:@"Navigation"] ||
            [className containsString:@"TabBar"] ||
            [className containsString:@"Page"] ||
            [className containsString:@"Home"] ||
            [className containsString:@"Search"] ||
            [className containsString:@"HUB"] ||
            [className containsString:@"Hub"] ||
            [className containsString:@"NowPlaying"]) {
            
            StripViewAndSubviews(self.view, 0);
        }
        
        [[SPTCustomThemeManager sharedInstance] ensureAttached];
    }
    
    UIWindow *win = self.view.window ?: [UIApplication sharedApplication].keyWindow;
    if (win) {
        [[SPTFloatingActionButton sharedInstance] attachToWindow:win];
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        NSString *className = NSStringFromClass([self class]);
        if ([className containsString:@"Library"] ||
            [className containsString:@"YourLibrary"] ||
            [className containsString:@"Root"] ||
            [className containsString:@"Page"] ||
            [className containsString:@"Home"] ||
            [className containsString:@"Navigation"]) {
            
            StripViewAndSubviews(self.view, 0);
        }
    }
}

%end

// 3. Hook Navigation Bars to eliminate opaque navigation header headers
%hook UINavigationBar

- (void)layoutSubviews {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        self.backgroundColor = [UIColor clearColor];
        self.barTintColor = [UIColor clearColor];
        self.translucent = YES;
        [self setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
        self.shadowImage = [UIImage new];
    }
}

%end

// 4. Hook Collection & Table views (Playlists, Library lists, Album tracks)
%hook UICollectionView

- (void)layoutSubviews {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        if (self.backgroundColor != [UIColor clearColor]) {
            self.backgroundColor = [UIColor clearColor];
        }
        if (self.backgroundView != nil && !self.backgroundView.hidden) {
            self.backgroundView.hidden = YES;
            self.backgroundView.alpha = 0.0;
        }
        self.opaque = NO;
    }
}

%end

%hook UITableView

- (void)layoutSubviews {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        if (self.backgroundColor != [UIColor clearColor]) {
            self.backgroundColor = [UIColor clearColor];
        }
        if (self.backgroundView != nil && !self.backgroundView.hidden) {
            self.backgroundView.hidden = YES;
            self.backgroundView.alpha = 0.0;
        }
        self.opaque = NO;
    }
}

%end

// 5. Hook Collection and Table Cells to ensure transparent row backgrounds
%hook UICollectionViewCell

- (void)didMoveToWindow {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.backgroundView = nil;
        self.opaque = NO;
    }
}

%end

%hook UITableViewCell

- (void)didMoveToWindow {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.backgroundView = nil;
        self.opaque = NO;
    }
}

%end

// 6. Hook Spotify-specific container & gradient views
%hook UIView

- (void)didMoveToWindow {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        NSString *cls = NSStringFromClass([self class]);
        
        if ([cls containsString:@"GLUEGradient"] ||
            [cls containsString:@"SPTNowPlayingBackgroundView"] ||
            [cls containsString:@"SPTLibraryHeader"] ||
            [cls containsString:@"SPTPageContainer"] ||
            [cls containsString:@"SPTFilterBar"]) {
            
            self.backgroundColor = [UIColor clearColor];
            self.opaque = NO;
            
            if ([cls containsString:@"GLUEGradient"] || [cls containsString:@"SPTNowPlayingBackgroundView"]) {
                self.alpha = 0.0;
                self.hidden = YES;
            }
        }
    }
}

%end

// 7. Initialize Theme Engine & Floating Trigger on App Launch
%hook SpotifyAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[SPTCustomThemeManager sharedInstance] setup];
        UIWindow *win = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
        if (win) {
            [[SPTCustomThemeManager sharedInstance] attachToWindow:win];
            [[SPTFloatingActionButton sharedInstance] attachToWindow:win];
        }
    });
    
    return result;
}

%end
