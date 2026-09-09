#import "SPTCustomThemeManager.h"
#import "SPTFloatingActionButton.h"

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

%hook UICollectionView

- (void)didMoveToWindow {
    %orig;
    if (SPTIsThemeEnabled() && self.window && SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
    }
}

%end

%hook UITableView

- (void)didMoveToWindow {
    %orig;
    if (SPTIsThemeEnabled() && self.window && SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
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
        SPTIsNearBlackOpaqueFill(self.backgroundColor)) {
        self.backgroundColor = [UIColor clearColor];
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
