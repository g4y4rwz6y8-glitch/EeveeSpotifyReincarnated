#import "SPTCustomThemeManager.h"
#import "SPTFloatingActionButton.h"

static BOOL SPTIsThemeEnabled(void) {
    return [[SPTCustomThemeManager sharedManager] themeEnabled];
}

static BOOL SPTIsNearBlackOpaqueFill(UIColor *color) {
    if (!color) return NO;
    CGFloat white = 0, alpha = 0;
    if ([color getWhite:&white alpha:&alpha]) {
        return alpha > 0.95 && white < 0.15;
    }
    return NO;
}

// Any view that is, or is nested inside, our own settings UI is exempt
// from the clearing pass — walks up the responder chain looking for our
// marker class by name (avoids a hard header dependency from Tweak.x).
static BOOL SPTViewBelongsToOwnUI(UIView *view) {
    UIView *v = view;
    while (v) {
        if ([v isKindOfClass:NSClassFromString(@"SPTOpaqueContainerView")] ||
            [v isKindOfClass:NSClassFromString(@"SPTSettingsViewController")] ||
            [v isKindOfClass:[UIVisualEffectView class]]) {
            return YES;
        }
        v = v.superview;
    }
    return NO;
}

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    [[SPTCustomThemeManager sharedManager] installInWindow:self];
    [[SPTFloatingActionButton sharedButton] installInWindow:self];
}

- (void)setRootViewController:(UIViewController *)rootViewController {
    %orig;
    [[SPTCustomThemeManager sharedManager] installInWindow:self];
    [[SPTFloatingActionButton sharedButton] installInWindow:self];
}

%end

%hook UICollectionView

- (void)didMoveToWindow {
    %orig;
    if (SPTIsThemeEnabled() && self.window && !SPTViewBelongsToOwnUI(self) &&
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
    }
}

%end

%hook UITableView

- (void)didMoveToWindow {
    %orig;
    if (SPTIsThemeEnabled() && self.window && !SPTViewBelongsToOwnUI(self) &&
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
        self.backgroundView = nil;
    }
}

%end

%hook UIView

- (void)didMoveToWindow {
    %orig;
    if (SPTIsThemeEnabled() && self.window &&
        self.subviews.count <= 1 &&
        !SPTViewBelongsToOwnUI(self) &&
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
    }
}

// Layout can re-trigger Spotify's own theming code which re-applies a
// solid fill after the initial clear (common with Encore views that
// re-read a design-token color on every layout pass). Re-clear here too.
- (void)layoutSubviews {
    %orig;
    if (SPTIsThemeEnabled() && self.window &&
        self.subviews.count <= 1 &&
        !SPTViewBelongsToOwnUI(self) &&
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
    }
}

%end

// Best-effort hooks on named Spotify controllers. If a class doesn't
// exist in this build, Logos silently no-ops the hook rather than
// crashing — safe to keep even across Spotify versions where these
// classes may be renamed or absent.

%hook SPTNavigationController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (SPTIsThemeEnabled() && !SPTViewBelongsToOwnUI(self.view)) {
        self.view.backgroundColor = [UIColor clearColor];
    }
}

%end

%hook SPTHomeViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (SPTIsThemeEnabled() && !SPTViewBelongsToOwnUI(self.view)) {
        self.view.backgroundColor = [UIColor clearColor];
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (SPTIsThemeEnabled() && !SPTViewBelongsToOwnUI(self.view)) {
        self.view.backgroundColor = [UIColor clearColor];
    }
}

%end

%hook SPTMainViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (SPTIsThemeEnabled() && !SPTViewBelongsToOwnUI(self.view)) {
        self.view.backgroundColor = [UIColor clearColor];
    }
}

%end

%hook SPTNowPlayingViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    // Now Playing intentionally stays opaque by default — most users want
    // album art/blur here, not the raw wallpaper. Leave commented unless
    // you specifically want the wallpaper behind Now Playing too:
    // if (SPTIsThemeEnabled() && !SPTViewBelongsToOwnUI(self.view)) {
    //     self.view.backgroundColor = [UIColor clearColor];
    // }
}

%end

%ctor {
    [[SPTCustomThemeManager sharedManager] reloadPreferences];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                       object:nil
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification *note) {
        [[SPTCustomThemeManager sharedManager] applicationDidEnterBackground];
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                       object:nil
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification *note) {
        [[SPTCustomThemeManager sharedManager] applicationWillEnterForeground];
    }];
}
