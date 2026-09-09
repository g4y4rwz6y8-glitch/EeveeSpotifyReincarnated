#import "SPTFloatingActionButton.h"
#import "SPTSettingsViewController.h"

@interface SPTFloatingActionButton () <UIGestureRecognizerDelegate>
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

- (void)installInWindow:(UIWindow *)window {
    if (self.superview == window) return;
    [self removeFromSuperview];
    [window addSubview:self];
    [window bringSubviewToFront:self];

    [NSLayoutConstraint activateConstraints:@[
        [self.widthAnchor constraintEqualToConstant:52],
        [self.heightAnchor constraintEqualToConstant:52],
        [self.trailingAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.bottomAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.bottomAnchor constant:-140],
    ]];
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

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Diagnostics"
                                                                     message:nil
                                                              preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Dump Active View Hierarchy"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        [self dumpAndShareHierarchyFromViewController:topVC];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    // iPad needs a popover source or it crashes.
    sheet.popoverPresentationController.sourceView = self;
    sheet.popoverPresentationController.sourceRect = self.bounds;

    [topVC presentViewController:sheet animated:YES completion:nil];
}

- (void)dumpAndShareHierarchyFromViewController:(UIViewController *)vc {
    UIViewController *targetVC = vc;
    while (targetVC.presentedViewController) {
        targetVC = targetVC.presentedViewController;
    }

    NSMutableString *output = [NSMutableString string];
    [output appendFormat:@"Root VC: %@\n", NSStringFromClass(targetVC.class)];
    [output appendFormat:@"Timestamp: %@\n\n", [NSDate date]];
    [self appendDescriptionOfView:targetVC.view depth:0 into:output];

    NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"spt_hierarchy_dump_%.0f.txt", [NSDate date].timeIntervalSince1970]]];

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
    NSString *indent = [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0];

    NSString *bgDescription = view.backgroundColor
        ? [self hexStringForColor:view.backgroundColor]
        : @"nil";

    [output appendFormat:@"%@%@ frame=%@ bg=%@ alpha=%.2f hidden=%d subviews=%lu\n",
        indent,
        NSStringFromClass(view.class),
        NSStringFromCGRect(view.frame),
        bgDescription,
        view.alpha,
        view.hidden,
        (unsigned long)view.subviews.count];

    for (UIView *subview in view.subviews) {
        [self appendDescriptionOfView:subview depth:depth + 1 into:output];
    }
}

- (NSString *)hexStringForColor:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        return [NSString stringWithFormat:@"#%02lX%02lX%02lX a=%.2f",
            (long)(r * 255), (long)(g * 255), (long)(b * 255), a];
    }
    CGFloat white = 0;
    if ([color getWhite:&white alpha:&a]) {
        return [NSString stringWithFormat:@"gray=%.3f a=%.2f", white, a];
    }
    return @"unknown";
}

- (UIViewController *)topmostViewController {
    UIWindow *window = self.window;
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    return top;
}

@end
