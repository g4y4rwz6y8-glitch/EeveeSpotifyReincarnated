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
// from the clearing pass.
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

// Generic UIViewController hook to transparently expose view backgrounds safely
%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (SPTIsThemeEnabled() && self.view && !SPTViewBelongsToOwnUI(self.view)) {
        if (SPTIsNearBlackOpaqueFill(self.view.backgroundColor)) {
            self.view.backgroundColor = [UIColor clearColor];
        }
    }
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
