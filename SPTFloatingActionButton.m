#import "SPTFloatingActionButton.h"
#import "ThemeSettingsViewController.h"

@interface SPTFloatingActionButton ()

@property (nonatomic, assign) BOOL isDragging;
@property (nonatomic, strong) UIVisualEffectView *glassBackground;
@property (nonatomic, strong) UIImpactFeedbackGenerator *feedbackGenerator;

@end

@implementation SPTFloatingActionButton

+ (instancetype)sharedInstance {
    static SPTFloatingActionButton *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [SPTFloatingActionButton buttonWithType:UIButtonTypeCustom];
        [instance setupModernButton];
    });
    return instance;
}

- (void)setupModernButton {
    CGFloat size = 44.0f; // Compact, unobtrusive diameter
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    
    self.frame = CGRectMake(screenBounds.size.width - size - 16.0f, screenBounds.size.height - size - 150.0f, size, size);
    self.layer.cornerRadius = size / 2.0f;
    self.layer.masksToBounds = NO;
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.glassBackground = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.glassBackground.frame = self.bounds;
    self.glassBackground.layer.cornerRadius = size / 2.0f;
    self.glassBackground.layer.masksToBounds = YES;
    self.glassBackground.userInteractionEnabled = NO;
    [self insertSubview:self.glassBackground atIndex:0];
    
    self.layer.borderColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:0.85].CGColor;
    self.layer.borderWidth = 1.5f;
    
    self.layer.shadowColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:0.45].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 3);
    self.layer.shadowOpacity = 0.5f;
    self.layer.shadowRadius = 6.0f;
    
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
        UIImage *paletteIcon = [UIImage systemImageNamed:@"paintpalette.fill" withConfiguration:config];
        if (!paletteIcon) {
            paletteIcon = [UIImage systemImageNamed:@"paintbrush.fill" withConfiguration:config];
        }
        [self setImage:paletteIcon forState:UIControlStateNormal];
        self.tintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
    } else {
        [self setTitle:@"🎨" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:20];
    }
    
    self.feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [self.feedbackGenerator prepare];
    
    [self addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:pan];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *superview = self.superview;
    if (!superview) return;
    
    CGPoint translation = [pan translationInView:superview];
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.isDragging = YES;
        [UIView animateWithDuration:0.15 animations:^{
            self.transform = CGAffineTransformMakeScale(1.10, 1.10);
        }];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
        [pan setTranslation:CGPointZero inView:superview];
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        self.isDragging = NO;
        [UIView animateWithDuration:0.25 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
        [self snapToEdge];
    }
}

- (void)snapToEdge {
    UIView *superview = self.superview;
    if (!superview) return;
    
    CGRect bounds = superview.bounds;
    CGFloat size = self.frame.size.width;
    CGFloat minX = 14.0f + (size / 2.0f);
    CGFloat maxX = bounds.size.width - 14.0f - (size / 2.0f);
    
    CGFloat targetX = (self.center.x < bounds.size.width / 2.0f) ? minX : maxX;
    CGFloat minY = 90.0f + (size / 2.0f);
    CGFloat maxY = bounds.size.height - 110.0f - (size / 2.0f);
    CGFloat targetY = MAX(minY, MIN(self.center.y, maxY));
    
    [UIView animateWithDuration:0.40 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.4 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.center = CGPointMake(targetX, targetY);
    } completion:nil];
}

- (void)buttonTapped {
    if (self.isDragging) return;
    [self.feedbackGenerator impactOccurred];
    [self presentThemeSettings];
}

- (void)setFloatingAlpha:(CGFloat)alpha animated:(BOOL)animated {
    if (animated) {
        [UIView animateWithDuration:0.25 animations:^{
            self.alpha = alpha;
        }];
    } else {
        self.alpha = alpha;
    }
}

+ (UIViewController *)topViewController {
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.isKeyWindow && !w.isHidden) {
                        window = w;
                        break;
                    }
                }
            }
        }
    }
    if (!window) {
        window = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    }
    
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    if ([top isKindOfClass:[UINavigationController class]]) {
        top = [(UINavigationController *)top visibleViewController] ?: top;
    }
    if ([top isKindOfClass:[UITabBarController class]]) {
        top = [(UITabBarController *)top selectedViewController] ?: top;
    }
    return top;
}

- (void)presentThemeSettings {
    UIViewController *top = [SPTFloatingActionButton topViewController];
    if (!top) return;
    
    if ([top isKindOfClass:[ThemeSettingsViewController class]] ||
        [top.presentedViewController isKindOfClass:[ThemeSettingsViewController class]]) {
        return;
    }
    
    [self setFloatingAlpha:0.0 animated:YES];
    
    ThemeSettingsViewController *themeVC = [[ThemeSettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:themeVC];
    if (@available(iOS 13.0, *)) {
        nav.modalPresentationStyle = UIModalPresentationPageSheet;
    } else {
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    [top presentViewController:nav animated:YES completion:nil];
}

- (void)attachToWindow:(UIWindow *)window {
    if (!window) return;
    NSString *cls = NSStringFromClass([window class]);
    if ([cls containsString:@"TextEffects"] || [cls containsString:@"Keyboard"] || [cls containsString:@"Alert"]) {
        return;
    }
    
    if (self.superview != window) {
        [self removeFromSuperview];
        [window addSubview:self];
    }
    [window bringSubviewToFront:self];
}

@end
