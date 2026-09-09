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

// Exempt floating action button, settings cards, search input fields, and text controls
static BOOL SPTViewBelongsToOwnOrInteractiveUI(UIView *view) {
    UIView *v = view;
    while (v) {
        NSString *className = NSStringFromClass(v.class);
        if ([v isKindOfClass:NSClassFromString(@"SPTOpaqueContainerView")] ||
            [v isKindOfClass:NSClassFromString(@"SPTSettingsViewController")] ||
            [v isKindOfClass:[SPTFloatingActionButton class]] ||
            [v isKindOfClass:[UIVisualEffectView class]] ||
            [v isKindOfClass:[UISearchBar class]] ||
            [v isKindOfClass:[UITextField class]] ||
            [className containsString:@"TouchForwardingView"] ||
            [className containsString:@"Search"]) {
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

- (void)layoutSubviews {
    %orig;
    // Always keep floating button visible and brought to front
    if (SPTIsThemeEnabled()) {
        [[SPTFloatingActionButton sharedButton] installInWindow:self];
    }
}

%end

%hook UICollectionView

- (void)didMoveToWindow {
    %orig;
    if (SPTIsThemeEnabled() && self.window && !SPTViewBelongsToOwnOrInteractiveUI(self) &&
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
    }
}

%end

%hook UITableView

- (void)didMoveToWindow {
    %orig;
    if (SPTIsThemeEnabled() && self.window && !SPTViewBelongsToOwnOrInteractiveUI(self) &&
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
        !SPTViewBelongsToOwnOrInteractiveUI(self) &&
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
    }
}

- (void)layoutSubviews {
    %orig;
    if (SPTIsThemeEnabled() && self.window &&
        self.subviews.count <= 1 &&
        !SPTViewBelongsToOwnOrInteractiveUI(self) &&
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
    }
}

%end

%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (SPTIsThemeEnabled() && self.view && !SPTViewBelongsToOwnOrInteractiveUI(self.view)) {
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
