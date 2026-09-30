#import "SPTFloatingActionButton.h"
#import "ThemeSettingsViewController.h"

@interface SPTFloatingActionButton ()
@property (nonatomic, assign) BOOL isDragging;
@end

@implementation SPTFloatingActionButton

+ (instancetype)sharedInstance {
    static SPTFloatingActionButton *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [SPTFloatingActionButton buttonWithType:UIButtonTypeCustom];
        [instance setupButton];
    });
    return instance;
}

- (void)setupButton {
    CGFloat size = 52.0f;
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    
    // Position button at bottom-right above tab bar and miniplayer
    self.frame = CGRectMake(screenBounds.size.width - size - 18.0f, screenBounds.size.height - size - 140.0f, size, size);
    
    self.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.10 alpha:0.92];
    self.layer.cornerRadius = size / 2.0f;
    self.layer.borderColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0].CGColor;
    self.layer.borderWidth = 2.0f;
    
    // Glowing Spotify-green shadow
    self.layer.shadowColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:0.8].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 3);
    self.layer.shadowOpacity = 0.65f;
    self.layer.shadowRadius = 8.0f;
    self.layer.masksToBounds = NO;
    
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightSemibold];
        UIImage *paletteIcon = [UIImage systemImageNamed:@"paintpalette.fill" withConfiguration:config];
        if (!paletteIcon) {
            paletteIcon = [UIImage systemImageNamed:@"paintbrush.fill" withConfiguration:config];
        }
        [self setImage:paletteIcon forState:UIControlStateNormal];
        self.tintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
    } else {
        [self setTitle:@"🎨" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:24];
    }
    
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
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
        [pan setTranslation:CGPointZero inView:superview];
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        self.isDragging = NO;
        [self snapToNearestEdge];
    }
}

- (void)snapToNearestEdge {
    UIView *superview = self.superview;
    if (!superview) return;
    
    CGRect bounds = superview.bounds;
    CGFloat size = self.frame.size.width;
    CGFloat minX = 16.0f + (size / 2.0f);
    CGFloat maxX = bounds.size.width - 16.0f - (size / 2.0f);
    
    CGFloat targetX = (self.center.x < bounds.size.width / 2.0f) ? minX : maxX;
    CGFloat minY = 80.0f + (size / 2.0f);
    CGFloat maxY = bounds.size.height - 100.0f - (size / 2.0f);
    CGFloat targetY = MAX(minY, MIN(self.center.y, maxY));
    
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.center = CGPointMake(targetX, targetY);
    } completion:nil];
}

- (void)buttonTapped {
    if (self.isDragging) return;
    [self presentThemeSettings];
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
