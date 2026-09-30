#import <UIKit/UIKit.h>
#import "SPTCustomThemeManager.h"
#import "SPTImageRenderer.h"

#if __has_include("SPTFloatingActionButton.h")
#import "SPTFloatingActionButton.h"
#endif

// Fast inline helper to strip backgrounds from views
static inline void StripOpaqueBackground(UIView *view) {
    if (!view) return;
    if (view.backgroundColor != [UIColor clearColor]) {
        view.backgroundColor = [UIColor clearColor];
    }
    view.opaque = NO;
}

// 1. Hook UIWindow to insert background at index 0 and keep it at the very back
%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        [[SPTCustomThemeManager sharedInstance] attachToWindow:self];
    }
}

- (void)layoutSubviews {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        [[SPTCustomThemeManager sharedInstance] ensureAttachedToWindow:self];
    }
}

%end

// 2. Hook UIViewController to eliminate opaque walls on Spotify's root, navigation, and content screens
%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        NSString *className = NSStringFromClass([self class]);
        
        // Match Spotify's container and page view controller hierarchies
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

// 3. Hook UICollectionView & UITableView to make playlists, albums, and home feeds transparent
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

// 4. Hook Collection & Table cells to ensure individual rows don't paint solid dark boxes
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
        
        // Remove gradient overlays masking the custom background
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

// 6. Hook Application Did Launch to initialize the theme engine early
%hook SpotifyAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[SPTCustomThemeManager sharedInstance] setup];
        [[SPTCustomThemeManager sharedInstance] ensureAttached];
    });
    
    return result;
}

%end
