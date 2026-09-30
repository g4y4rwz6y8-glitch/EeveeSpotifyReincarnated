#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SPTCustomThemeManager.h"
#import "SPTImageRenderer.h"
#import "SPTFloatingActionButton.h"
#import "ThemeSettingsViewController.h"

// Fast inline helper to strip backgrounds from views
static inline void StripOpaqueBackground(UIView *view) {
    if (!view) return;
    if (view.backgroundColor != [UIColor clearColor]) {
        view.backgroundColor = [UIColor clearColor];
    }
    view.opaque = NO;
}

// 1. Hook UIWindow to attach the background and the floating settings button
%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        [[SPTCustomThemeManager sharedInstance] attachToWindow:self];
    }
    
    // Attach the floating settings action button
    [[SPTFloatingActionButton sharedInstance] attachToWindow:self];
    
    // Add two-finger double-tap gesture shortcut to open settings anytime
    static char kThemeGestureKey;
    if (!objc_getAssociatedObject(self, &kThemeGestureKey)) {
        UITapGestureRecognizer *twoFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:[SPTFloatingActionButton sharedInstance] action:@selector(presentThemeSettings)];
        twoFingerTap.numberOfTouchesRequired = 2;
        twoFingerTap.numberOfTapsRequired = 2;
        twoFingerTap.cancelsTouchesInView = NO;
        [self addGestureRecognizer:twoFingerTap];
        objc_setAssociatedObject(self, &kThemeGestureKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)layoutSubviews {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        [[SPTCustomThemeManager sharedInstance] ensureAttachedToWindow:self];
    }
    // Keep floating action button at the very front
    [self bringSubviewToFront:[SPTFloatingActionButton sharedInstance]];
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig;
    // Shake gesture shortcut to immediately pop open theme settings
    if (motion == UIEventSubtypeMotionShake) {
        [[SPTFloatingActionButton sharedInstance] presentThemeSettings];
    }
}

%end

// 2. Hook UIViewController to eliminate opaque walls on Spotify's root and content screens
%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        NSString *className = NSStringFromClass([self class]);
        
        if ([className containsString:@"SPT"] ||
            [className containsString:@"Root"] ||
            [className containsString:@"Navigation"] ||
            [className containsString:@"TabBar"] ||
            [className containsString:@"Page"] ||
            [className containsString:@"Home"] ||
            [className containsString:@"Search"] ||
            [className containsString:@"Library"] ||
            [className containsString:@"HUB"] ||
            [className containsString:@"NowPlaying"]) {
            
            StripOpaqueBackground(self.view);
        }
        
        [[SPTCustomThemeManager sharedInstance] ensureAttached];
    }
    
    // Ensure the button stays attached to the active window
    UIWindow *win = self.view.window ?: [UIApplication sharedApplication].keyWindow;
    if (win) {
        [[SPTFloatingActionButton sharedInstance] attachToWindow:win];
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        NSString *className = NSStringFromClass([self class]);
        if ([className containsString:@"Root"] || 
            [className containsString:@"Navigation"] || 
            [className containsString:@"TabBar"] || 
            [className containsString:@"Page"]) {
            
            StripOpaqueBackground(self.view);
        }
    }
}

%end

// 3. Hook UICollectionView & UITableView to make playlists, albums, and feeds transparent
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

// 4. Hook Collection & Table cells
%hook UICollectionViewCell

- (void)didMoveToWindow {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        self.backgroundColor = [UIColor clearColor];
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
        self.backgroundView = nil;
        self.opaque = NO;
    }
}

%end

// 5. Hook GLUEGradientView and Spotify's internal gradient overlays
%hook UIView

- (void)didMoveToWindow {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        NSString *className = NSStringFromClass([self class]);
        
        if ([className containsString:@"GLUEGradient"] ||
            [className containsString:@"SPTNowPlayingBackgroundView"] ||
            [className isEqualToString:@"SPTPageContainerView"] ||
            [className isEqualToString:@"SPTPageContentContainerView"]) {
            
            StripOpaqueBackground(self);
            
            if ([className containsString:@"GLUEGradient"] || [className containsString:@"SPTNowPlayingBackgroundView"]) {
                self.alpha = 0.0;
                self.hidden = YES;
            }
        }
    }
}

%end

// 6. Hook Application Launch to initialize both managers early
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
