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

// Fix for Issue A: this used to walk the ENTIRE ancestor chain and match
// broad substrings like "TouchForwardingView"/"Search", which sit near
// the root of nearly every screen and poisoned almost all descendants.
// Now: (1) own-UI check still walks up, since our own tree is small and
// intentionally isolated; (2) interactive-input check only looks at the
// view itself, never ancestors, so one search bar can't exempt its
// entire containing tab.

static BOOL SPTViewBelongsToOwnUI(UIView *view) {
    UIView *v = view;
    NSInteger hops = 0;
    while (v && hops < 12) { // bounded walk — our own hierarchy is shallow
        if ([v isKindOfClass:NSClassFromString(@"SPTOpaqueContainerView")] ||
            [v isKindOfClass:NSClassFromString(@"SPTSettingsViewController")] ||
            [v isKindOfClass:[SPTFloatingActionButton class]] ||
            [v isKindOfClass:[UIVisualEffectView class]]) {
            return YES;
        }
        v = v.superview;
        hops++;
    }
    return NO;
}

static BOOL SPTIsInteractiveTextInput(UIView *view) {
    // Check the view itself only — never its ancestors.
    if ([view isKindOfClass:[UISearchBar class]]) return YES;
    if ([view isKindOfClass:[UITextField class]]) return YES;
    if ([view isKindOfClass:[UITextView class]]) return YES;
    // A search bar's own background/field editor is usually its direct
    // subview, so checking one level down (not up) is safe and specific.
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UISearchBar class]] || [sub isKindOfClass:[UITextField class]]) {
            return YES;
        }
    }
    return NO;
}

static BOOL SPTShouldSkipClearing(UIView *view) {
    return SPTViewBelongsToOwnUI(view) || SPTIsInteractiveTextInput(view);
}

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    if ([SPTFloatingActionButton isEligibleContentWindow:self]) {
        [[SPTCustomThemeManager sharedManager] installInWindow:self];
        [[SPTFloatingActionButton sharedButton] installInWindow:self];
    }
}

- (void)setRootViewController:(UIViewController *)rootViewController {
    %orig;
    if ([SPTFloatingActionButton isEligibleContentWindow:self]) {
        [[SPTCustomThemeManager sharedManager] installInWindow:self];
        [[SPTFloatingActionButton sharedButton] installInWindow:self];
    }
}

// Dropped the layoutSubviews override entirely — it fired on every
// window layout pass across every window in the process, which was the
// main driver of the button re-parenting into whichever window
// happened to lay out last. makeKeyAndVisible / setRootViewController
// are sufficient triggers, and installInWindow: is now a cheap no-op
// once correctly parented, so there's no ongoing need to re-check here.

%end

%hook UICollectionView

- (void)didMoveToWindow {
    %orig;
    if (SPTIsThemeEnabled() && self.window && !SPTShouldSkipClearing(self) &&
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
    }
}

// Added: Spotify's Encore layer frequently re-applies its themed fill
// after the view already has a window (e.g. on data reload), silently
// undoing the didMoveToWindow clear. Re-clear on every layout pass too.
- (void)layoutSubviews {
    %orig;
    if (SPTIsThemeEnabled() && self.window && !SPTShouldSkipClearing(self) &&
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
    }
}

%end

%hook UITableView

- (void)didMoveToWindow {
    %orig;
    if (SPTIsThemeEnabled() && self.window && !SPTShouldSkipClearing(self) &&
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
        self.backgroundView = nil;
    }
}

- (void)layoutSubviews {
    %orig;
    if (SPTIsThemeEnabled() && self.window && !SPTShouldSkipClearing(self) &&
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
    }
}

%end

%hook UIView

- (void)didMoveToWindow {
    %orig;
    if (SPTIsThemeEnabled() && self.window &&
        self.subviews.count <= 1 &&
        !SPTShouldSkipClearing(self) &&
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
    }
}

- (void)layoutSubviews {
    %orig;
    if (SPTIsThemeEnabled() && self.window &&
        self.subviews.count <= 1 &&
        !SPTShouldSkipClearing(self) &&
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
    }
}

%end

%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (SPTIsThemeEnabled() && self.view && !SPTShouldSkipClearing(self.view) &&
        SPTIsNearBlackOpaqueFill(self.view.backgroundColor)) {
        self.view.backgroundColor = [UIColor clearColor];
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
