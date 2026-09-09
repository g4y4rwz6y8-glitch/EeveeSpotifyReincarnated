#import "SPTFloatingActionButton.h"
#import "SPTSettingsViewController.h"

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

- (UIViewController *)topmostViewController {
    UIWindow *window = self.window;
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    return top;
}

@end
