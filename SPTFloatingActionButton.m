#import "SPTFloatingActionButton.h"
#import "SPTSettingsViewController.h"

@interface SPTFloatingActionButton () <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIWindow *installedWindow;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *positionConstraints;
@end

@implementation SPTFloatingActionButton

+ (instancetype)sharedButton {
    static SPTFloatingActionButton *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[SPTFloatingActionButton alloc] initWithFrame:CGRectMake(0, 0, 52, 52)];
        [shared setup];
    });
    return shared;
}

- (void)setup {
    self.backgroundColor = [UIColor colorWithRed:0.11 green:0.73 blue:0.33 alpha:1.0];
    self.layer.cornerRadius = 26;
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.4;
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.layer.shadowRadius = 4;
    self.translatesAutoresizingMaskIntoConstraints = NO;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self.adjustsImageWhenHighlighted = NO;
#pragma clang diagnostic pop

    UIImage *icon = [UIImage systemImageNamed:@"paintpalette.fill"];
    [self setImage:icon forState:UIControlStateNormal];
    self.tintColor = [UIColor whiteColor];

    [self addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:pan];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [self addGestureRecognizer:longPress];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.transform = CGAffineTransformIdentity;
}

#pragma mark - Window eligibility

// This is the actual fix for Issue B: only ever install into the real
// app content window, never a system overlay/keyboard/effects window.
+ (BOOL)isEligibleContentWindow:(UIWindow *)window {
    if (!window) return NO;
    if (window.windowLevel != UIWindowLevelNormal) return NO;       // excludes keyboard/alert/status windows
    if (!window.rootViewController) return NO;                     // system windows rarely have one
    if (CGRectIsEmpty(window.bounds)) return NO;
    if (window.bounds.size.width < 100 || window.bounds.size.height < 100) return NO; // guards tiny overlay windows

    NSString *className = NSStringFromClass(window.class);
    if ([className containsString:@"UIRemoteKeyboardWindow"]) return NO;
    if ([className containsString:@"UITextEffectsWindow"]) return NO;

    return YES;
}

- (void)installInWindow:(UIWindow *)window {
    if (![SPTFloatingActionButton isEligibleContentWindow:window]) return;

    // Already correctly parented — just make sure we're on top, don't
    // touch constraints (this is what stopped the repeated re-parenting
    // that was causing the top-left jumps under layoutSubviews churn).
    if (self.installedWindow == window && self.superview == window) {
        [window bringSubviewToFront:self];
        return;
    }

    if (self.positionConstraints.count > 0) {
        [NSLayoutConstraint deactivateConstraints:self.positionConstraints];
        self.positionConstraints = nil;
    }

    [self removeFromSuperview];
    [window addSubview:self];
    [window bringSubviewToFront:self];

    NSLayoutConstraint *trailing = [self.trailingAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.trailingAnchor constant:-16];
    NSLayoutConstraint *bottom = [self.bottomAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.bottomAnchor constant:-140];
    NSLayoutConstraint *width = [self.widthAnchor constraintEqualToConstant:52];
    NSLayoutConstraint *height = [self.heightAnchor constraintEqualToConstant:52];

    self.positionConstraints = @[trailing, bottom, width, height];
    [NSLayoutConstraint activateConstraints:self.positionConstraints];

    self.installedWindow = window;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *window = self.superview;
    if (!window) return;
    CGPoint translation = [pan translationInView:window];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:window];
}

- (void)tapped {
    UIViewController *topVC = [self topmostViewController];
    if (!topVC) return;

    SPTSettingsViewController *settingsVC = [[SPTSettingsViewController alloc] init];
    settingsVC.modalPresentationStyle = UIModalPresentationFormSheet;
    [topVC presentViewController:settingsVC animated:YES completion:nil];
}

#pragma mark - Long press: hierarchy inspector

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    UIViewController *topVC = [self topmostViewController];
    if (!topVC) return;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Diagnostics & Dump"
                                                                     message:@"Choose diagnostic dump options for current screen"
                                                              preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Dump Active Visible Screen Hierarchy"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        [self dumpAndShareHierarchyFromViewController:topVC pageName:@"ActiveScreen"];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Dump Window Root Hierarchy"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        if (self.window.rootViewController) {
            [self dumpAndShareHierarchyFromViewController:self.window.rootViewController pageName:@"WindowRoot"];
        }
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    sheet.popoverPresentationController.sourceView = self;
    sheet.popoverPresentationController.sourceRect = self.bounds;

    [topVC presentViewController:sheet animated:YES completion:nil];
}

- (void)dumpAndShareHierarchyFromViewController:(UIViewController *)vc pageName:(NSString *)pageName {
    UIViewController *targetVC = vc;
    while (targetVC.presentedViewController && ![targetVC.presentedViewController isKindOfClass:[UIAlertController class]]) {
        targetVC = targetVC.presentedViewController;
    }

    NSMutableString *output = [NSMutableString string];
    [output appendFormat:@"Dump Section: %@\n", pageName];
    [output appendFormat:@"Root VC: %@\n", NSStringFromClass(targetVC.class)];
    [output appendFormat:@"Timestamp: %@\n\n", [NSDate date]];

    [self appendDescriptionOfView:targetVC.view depth:0 into:output];

    NSString *fileName = [NSString stringWithFormat:@"spt_hierarchy_%@_%.0f.txt", pageName, [NSDate date].timeIntervalSince1970];
    NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];

    NSError *writeError;
    [output writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    if (writeError) return;

    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
        initWithActivityItems:@[fileURL] applicationActivities:nil];
    activityVC.popoverPresentationController.sourceView = self;
    activityVC.popoverPresentationController.sourceRect = self.bounds;

    [[self topmostViewController] presentViewController:activityVC animated:YES completion:nil];
}

- (void)appendDescriptionOfView:(UIView *)view depth:(NSInteger)depth into:(NSMutableString *)output {
    if (!view) return;

    NSString *indent = [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0];
    NSString *bgDescription = view.backgroundColor ? [self hexStringForColor:view.backgroundColor] : @"nil";

    [output appendFormat:@"%@%@ frame=%@ bg=%@ alpha=%.2f hidden=%d subviews=%lu\n",
        indent, NSStringFromClass(view.class), NSStringFromCGRect(view.frame),
        bgDescription, view.alpha, view.hidden, (unsigned long)view.subviews.count];

    for (UIView *subview in view.subviews) {
        [self appendDescriptionOfView:subview depth:depth + 1 into:output];
    }
}

- (NSString *)hexStringForColor:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        return [NSString stringWithFormat:@"#%02lX%02lX%02lX a=%.2f", (long)(r * 255), (long)(g * 255), (long)(b * 255), a];
    }
    CGFloat white = 0;
    if ([color getWhite:&white alpha:&a]) {
        return [NSString stringWithFormat:@"gray=%.3f a=%.2f", white, a];
    }
    return @"unknown";
}

- (UIViewController *)topmostViewController {
    UIWindow *window = self.window;
    if (!window) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *w in windowScene.windows) {
                    if (w.isKeyWindow && [SPTFloatingActionButton isEligibleContentWindow:w]) {
                        window = w;
                        break;
                    }
                }
            }
            if (window) break;
        }
    }

    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    return top;
}

@end
