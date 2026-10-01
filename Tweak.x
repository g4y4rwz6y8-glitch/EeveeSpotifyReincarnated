#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SPTCustomThemeManager.h"
#import "SPTImageRenderer.h"
#import "SPTGifRenderer.h"
#import "SPTVideoRenderer.h"
#import "SPTFloatingActionButton.h"
#import "ThemeSettingsViewController.h"

static char kGlassShieldKey;

// Injects an acrylic frosted glass backdrop so pushed navigation pages don't show double text
static void EnsureFrostedBackdrop(UIViewController *vc) {
    if (!vc || !vc.view || ![SPTCustomThemeManager isCustomThemeActive]) return;
    
    if (objc_getAssociatedObject(vc, &kGlassShieldKey)) return;
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *shield = [[UIVisualEffectView alloc] initWithEffect:blur];
    shield.frame = vc.view.bounds;
    shield.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    shield.userInteractionEnabled = NO;
    shield.alpha = 0.88f;
    
    UIView *darkTint = [[UIView alloc] initWithFrame:shield.bounds];
    darkTint.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.08 alpha:0.65];
    darkTint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [shield.contentView addSubview:darkTint];
    
    [vc.view insertSubview:shield atIndex:0];
    objc_setAssociatedObject(vc, &kGlassShieldKey, shield, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// 1. Hook UIWindow for persistent wallpaper anchoring and shortcut triggers
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

// 2. Hook UIViewController: Transparent Root Feeds vs. Frosted Pushed Subpages
%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (![SPTCustomThemeManager isCustomThemeActive]) return;
    
    NSString *cls = NSStringFromClass([self class]);
    BOOL isPushedChild = (self.navigationController && self.navigationController.viewControllers.count > 1);
    
    // Side drawer / Profile / Context modals
    if ([cls containsString:@"Profile"] || [cls containsString:@"Drawer"] || [cls containsString:@"ContextMenu"] || [cls containsString:@"Message"]) {
        EnsureFrostedBackdrop(self);
        return;
    }
    
    // Pushed sub-pages (Settings, Playback, Album tracklist, Playlist details)
    if (isPushedChild || [cls containsString:@"Settings"] || [cls containsString:@"Playback"]) {
        EnsureFrostedBackdrop(self);
        return;
    }
    
    // Primary Root Views (Home, Search Browse, Your Library main view): Pure transparent
    if ([cls containsString:@"Root"] ||
        [cls containsString:@"Home"] ||
        [cls containsString:@"Library"] ||
        [cls containsString:@"YourLibrary"] ||
        [cls containsString:@"Search"] ||
        [cls containsString:@"Navigation"] ||
        [cls containsString:@"TabBar"] ||
        [cls containsString:@"Page"]) {
        
        self.view.backgroundColor = [UIColor clearColor];
        self.view.opaque = NO;
    }
    
    [[SPTCustomThemeManager sharedInstance] ensureAttached];
}

%end

// 3. Search Field / Keyboard Focus Hook (Eliminates overlap in screenshot 00:05)
%hook UISearchBar

- (BOOL)becomeFirstResponder {
    BOOL res = %orig;
    [[SPTFloatingActionButton sharedInstance] setFloatingAlpha:0.0 animated:YES];
    return res;
}

- (BOOL)resignFirstResponder {
    BOOL res = %orig;
    [[SPTFloatingActionButton sharedInstance] setFloatingAlpha:1.0 animated:YES];
    return res;
}

%end

// 4. Hook Collection & Table Views
%hook UICollectionView

- (void)layoutSubviews {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        NSString *parentClass = NSStringFromClass([self.superview class]);
        // Give active search suggestions a frosted dark backdrop so underlying categories don't bleed through
        if ([parentClass containsString:@"Search"] || [NSStringFromClass([self class]) containsString:@"Search"]) {
            self.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.08 alpha:0.92];
        } else {
            self.backgroundColor = [UIColor clearColor];
        }
        if (self.backgroundView) {
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
        self.backgroundColor = [UIColor clearColor];
        if (self.backgroundView) {
            self.backgroundView.hidden = YES;
            self.backgroundView.alpha = 0.0;
        }
        self.opaque = NO;
    }
}

%end

// 5. Hook Navigation Bars
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

// 6. Hook Cells (Translucent Rows)
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

// 7. Strip Harsh Dark Gradients
%hook UIView

- (void)didMoveToWindow {
    %orig;
    if ([SPTCustomThemeManager isCustomThemeActive]) {
        NSString *cls = NSStringFromClass([self class]);
        if ([cls containsString:@"GLUEGradient"] ||
            [cls containsString:@"SPTNowPlayingBackgroundView"] ||
            [cls containsString:@"GradientOverlay"]) {
            self.alpha = 0.0;
            self.hidden = YES;
        }
    }
}

%end

// 8. Inject "Liquid Glass Studio" Directly into Spotify Native Settings
%hook SPTSettingsViewController

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return %orig + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    return %orig(tableView, section - 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Theme Customization";
    return %orig(tableView, section - 1);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LiquidGlassCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"LiquidGlassCell"];
            cell.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:0.9];
            cell.textLabel.textColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
            cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
            cell.detailTextLabel.textColor = [UIColor lightGrayColor];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.textLabel.text = @"Liquid Glass Studio";
        cell.detailTextLabel.text = @"Customize background, blur & glassmorphism";
        return cell;
    }
    NSIndexPath *origPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
    return %orig(tableView, origPath);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [[SPTFloatingActionButton sharedInstance] presentThemeSettings];
        return;
    }
    NSIndexPath *origPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
    %orig(tableView, origPath);
}

%end

// 9. Early App Launch Initialization
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
