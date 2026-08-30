#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import "ThemeManager.h"
#import "ThemeFilter.h"
#import "ThemeSettingsViewController.h"
#import "EeveeDumpSession.h"

static UIButton *gThemeButton = nil;
static const NSInteger kEeveeWallpaperViewTag = 918273;

#pragma mark - Video wallpaper backing view

@interface EeveeVideoLayerView : UIView
@property (nonatomic, readonly) AVPlayerLayer *playerLayer;
@end

@implementation EeveeVideoLayerView
+ (Class)layerClass { return [AVPlayerLayer class]; }
- (AVPlayerLayer *)playerLayer { return (AVPlayerLayer *)self.layer; }
@end

#pragma mark - Screen Context Registry

@interface EeveeScreenRegistry : NSObject
+ (instancetype)shared;
- (NSString *)identifyScreenContext:(UIViewController *)vc;
- (UIView *)findBackgroundContainerInView:(UIView *)view forScreen:(NSString *)screenType;
@end

@implementation EeveeScreenRegistry

static EeveeScreenRegistry *sharedInstance = nil;

+ (instancetype)shared {
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (NSString *)identifyScreenContext:(UIViewController *)vc {
    NSString *className = NSStringFromClass([vc class]);
    
    if ([className containsString:@"NowPlaying"]) return @"NowPlaying";
    if ([className containsString:@"Home"] || [className containsString:@"Browse"]) return @"Home";
    if ([className containsString:@"Search"]) return @"Search";
    if ([className containsString:@"Collection"] || [className containsString:@"YourLibrary"] || [className containsString:@"Library"]) return @"Library";
    if ([className containsString:@"Settings"] || [className containsString:@"Preferences"]) return @"Settings";
    
    return nil;
}

- (UIView *)findBackgroundContainerInView:(UIView *)view forScreen:(NSString *)screenType {
    return [EeveeThemeFilter findDeepestBackgroundCanvasInView:view screenType:screenType];
}

@end

#pragma mark - Success pill toast

static void EeveeShowSuccessPill(NSString *title, NSString *subtitle) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;

        CGFloat width = keyWindow.bounds.size.width - 40;
        UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(20, -100, width, 76)];
        pill.backgroundColor = [UIColor colorWithRed:0.09 green:0.16 blue:0.12 alpha:0.97];
        pill.layer.cornerRadius = 38;
        pill.layer.shadowColor = [UIColor blackColor].CGColor;
        pill.layer.shadowOpacity = 0.3;
        pill.layer.shadowRadius = 8;
        pill.layer.shadowOffset = CGSizeMake(0, 4);

        UIView *badge = [[UIView alloc] initWithFrame:CGRectMake(14, 14, 48, 48)];
        badge.backgroundColor = [UIColor colorWithRed:0.24 green:0.62 blue:0.42 alpha:1.0];
        badge.layer.cornerRadius = 24;
        [pill addSubview:badge];

        UIImageView *check = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"]];
        check.tintColor = [UIColor whiteColor];
        check.contentMode = UIViewContentModeCenter;
        check.frame = badge.bounds;
        [badge addSubview:check];

        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(74, 12, width - 90, 24)];
        titleLabel.text = title;
        titleLabel.font = [UIFont boldSystemFontOfSize:18];
        titleLabel.textColor = [UIColor whiteColor];
        [pill addSubview:titleLabel];

        UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(74, 38, width - 90, 22)];
        subtitleLabel.text = subtitle;
        subtitleLabel.font = [UIFont systemFontOfSize:15];
        subtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
        [pill addSubview:subtitleLabel];

        [keyWindow addSubview:pill];
        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
            pill.frame = CGRectMake(20, 60, width, 76);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3 delay:1.6 options:0 animations:^{
                pill.alpha = 0;
            } completion:^(BOOL done) {
                [pill removeFromSuperview];
            }];
        }];
    });
}

#pragma mark - All helper methods (plain category, not inside a hook block)

@interface UIViewController (EeveeThemeEngine)
- (void)setupEeveeThemeButton;
- (void)eevee_openThemeSettings;
- (void)eevee_handlePan:(UIPanGestureRecognizer *)pan;
- (void)eevee_handleLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)eevee_captureCurrentScreenAs:(NSString *)screenName;
- (void)eevee_dumpView:(UIView *)view depth:(NSInteger)depth intoLog:(NSMutableString *)log;
- (void)eevee_applyCanvasTheme;
- (BOOL)eevee_findAndThemeMixingBackground:(UIView *)view theme:(ThemeManager *)tm;
- (void)eevee_applyWallpaperToContainer:(UIView *)container;
- (UIView *)eevee_buildWallpaperView;
- (UIView *)eevee_buildImageWallpaperView:(NSString *)path;
- (UIView *)eevee_buildGIFWallpaperView:(NSString *)path;
- (UIView *)eevee_buildVideoWallpaperView:(NSString *)path;
@end

@implementation UIViewController (EeveeThemeEngine)

#pragma mark Floating button

- (void)setupEeveeThemeButton {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { keyWindow = w; break; }
        }
    }
    if (!keyWindow) return;

    if (gThemeButton) {
        if (gThemeButton.superview != keyWindow) {
            [gThemeButton removeFromSuperview];
            [keyWindow addSubview:gThemeButton];
        }
        [keyWindow bringSubviewToFront:gThemeButton];
        return;
    }

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect bounds = [UIScreen mainScreen].bounds;
    btn.frame = CGRectMake(bounds.size.width - 65, bounds.size.height - 180, 50, 50);
    btn.layer.cornerRadius = 25;
    btn.layer.zPosition = CGFLOAT_MAX;
    btn.backgroundColor = [UIColor colorWithRed:0.1 green:0.7 blue:0.8 alpha:0.95];
    [btn setImage:[UIImage systemImageNamed:@"paintpalette.fill"] forState:UIControlStateNormal];
    btn.tintColor = [UIColor whiteColor];
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOffset = CGSizeMake(0, 3);
    btn.layer.shadowRadius = 4;
    btn.layer.shadowOpacity = 0.3;

    [btn addTarget:self action:@selector(eevee_openThemeSettings) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(eevee_handlePan:)];
    [btn addGestureRecognizer:pan];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(eevee_handleLongPress:)];
    [btn addGestureRecognizer:longPress];

    [keyWindow addSubview:btn];
    gThemeButton = btn;
}

- (void)eevee_openThemeSettings {
    ThemeSettingsViewController *themeVC = [[ThemeSettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:themeVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)eevee_handlePan:(UIPanGestureRecognizer *)pan {
    UIView *btn = pan.view;
    CGPoint translation = [pan translationInView:btn.superview];
    CGPoint newCenter = CGPointMake(btn.center.x + translation.x, btn.center.y + translation.y);
    CGRect bounds = [UIScreen mainScreen].bounds;
    newCenter.x = MIN(MAX(30, newCenter.x), bounds.size.width - 30);
    newCenter.y = MIN(MAX(60, newCenter.y), bounds.size.height - 60);
    btn.center = newCenter;
    [pan setTranslation:CGPointZero inView:btn.superview];
}

#pragma mark Scanner

- (void)eevee_handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    EeveeDumpSession *session = [EeveeDumpSession shared];
    UIAlertController *picker = [UIAlertController alertControllerWithTitle:@"Which screen is this?"
                                                                      message:[NSString stringWithFormat:@"Captured %ld of %ld", (long)session.completedCount, (long)session.totalCount]
                                                               preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *screenName in session.targetScreens) {
        BOOL done = [session.completedScreens containsObject:screenName];
        NSString *label = done ? [NSString stringWithFormat:@"✓ %@ (re-scan)", screenName] : screenName;
        [picker addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self eevee_captureCurrentScreenAs:screenName];
        }]];
    }

    [picker addAction:[UIAlertAction actionWithTitle:@"Reset Scan Progress" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [session reset];
        EeveeShowSuccessPill(@"Progress reset", @"Start capturing screens again");
    }]];
    [picker addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;

    if (picker.popoverPresentationController) {
        picker.popoverPresentationController.sourceView = gThemeButton;
        picker.popoverPresentationController.sourceRect = gThemeButton.bounds;
    }
    [topVC presentViewController:picker animated:YES completion:nil];
}

- (void)eevee_captureCurrentScreenAs:(NSString *)screenName {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;

    NSMutableString *log = [NSMutableString stringWithFormat:@"root class: %@\n", NSStringFromClass([topVC class])];
    [topVC eevee_dumpView:topVC.view depth:0 intoLog:log];

    EeveeDumpSession *session = [EeveeDumpSession shared];
    [session recordDumpForScreen:screenName hierarchyLog:log];

    NSInteger done = session.completedCount;
    NSInteger total = session.totalCount;
    NSInteger percent = total > 0 ? (done * 100 / total) : 0;

    if (session.isComplete) {
        EeveeShowSuccessPill(@"All screens captured!", @"eevee_full_scan.txt is ready in Files");
    } else {
        EeveeShowSuccessPill(@"Captured", [NSString stringWithFormat:@"%@ • %ld%% done (%ld/%ld)", screenName, (long)percent, (long)done, (long)total]);
    }
}

- (void)eevee_dumpView:(UIView *)view depth:(NSInteger)depth intoLog:(NSMutableString *)log {
    NSString *indent = [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0];
    [log appendFormat:@"%@%@ frame=%@ bg=%@ subviews=%lu\n",
        indent, NSStringFromClass([view class]), NSStringFromCGRect(view.frame), view.backgroundColor,
        (unsigned long)view.subviews.count];
    for (UIView *sub in view.subviews) {
        [self eevee_dumpView:sub depth:depth + 1 intoLog:log];
    }
}

#pragma mark Canvas theming (Now Playing background)

- (void)eevee_applyCanvasTheme {
    ThemeManager *tm = [ThemeManager shared];
    if (!tm.isThemeEnabled || tm.activeThemeName.length == 0) return;

    NSString *vcName = NSStringFromClass([self class]);
    if (![vcName containsString:@"NowPlaying"]) return;

    [self eevee_findAndThemeMixingBackground:self.view theme:tm];
}

- (BOOL)eevee_findAndThemeMixingBackground:(UIView *)view theme:(ThemeManager *)tm {
    if ([NSStringFromClass([view class]) isEqualToString:@"NowPlaying_MixingTransitionImpl.MixingBackgroundView"]) {
        UIColor *bg = [tm colorForKey:@"backgroundColor" fallback:nil];
        if (bg) {
            for (UIView *sub in view.subviews) {
                if ([sub isMemberOfClass:[UIView class]]) {
                    sub.backgroundColor = bg;
                }
            }
        }
        return YES;
    }
    for (UIView *sub in view.subviews) {
        if ([self eevee_findAndThemeMixingBackground:sub theme:tm]) return YES;
    }
    return NO;
}

#pragma mark Wallpaper (with Auto Layout constraints)

- (void)eevee_applyWallpaperToContainer:(UIView *)container {
    ThemeManager *tm = [ThemeManager shared];
    if (![tm hasWallpaper]) {
        UIView *existing = [container viewWithTag:kEeveeWallpaperViewTag];
        [existing removeFromSuperview];
        return;
    }

    UIView *existing = [container viewWithTag:kEeveeWallpaperViewTag];
    if (existing) return;

    UIView *wallpaperView = [self eevee_buildWallpaperView];
    if (wallpaperView) {
        wallpaperView.tag = kEeveeWallpaperViewTag;
        wallpaperView.translatesAutoresizingMaskIntoConstraints = NO;
        [container insertSubview:wallpaperView atIndex:0];

        // Auto Layout constraint pinning (leading, trailing, top, bottom)
        [NSLayoutConstraint activateConstraints:@[
            [wallpaperView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [wallpaperView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [wallpaperView.topAnchor constraintEqualToAnchor:container.topAnchor],
            [wallpaperView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
        ]];
    }
}

- (UIView *)eevee_buildWallpaperView {
    ThemeManager *tm = [ThemeManager shared];
    NSString *path = [tm wallpaperFilePath];
    if (!path) return nil;

    switch ([tm currentWallpaperType]) {
        case EeveeWallpaperTypeImage: return [self eevee_buildImageWallpaperView:path];
        case EeveeWallpaperTypeGIF:   return [self eevee_buildGIFWallpaperView:path];
        case EeveeWallpaperTypeVideo: return [self eevee_buildVideoWallpaperView:path];
        default: return nil;
    }
}

- (UIView *)eevee_buildImageWallpaperView:(NSString *)path {
    UIImage *img = [UIImage imageWithContentsOfFile:path];
    if (!img) return nil;
    UIImageView *iv = [[UIImageView alloc] initWithImage:img];
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    return iv;
}

- (UIView *)eevee_buildGIFWallpaperView:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) return nil;

    size_t count = CGImageSourceGetCount(source);
    NSMutableArray *images = [NSMutableArray array];
    for (size_t i = 0; i < count; i++) {
        CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, i, NULL);
        if (cgImage) {
            [images addObject:[UIImage imageWithCGImage:cgImage]];
            CGImageRelease(cgImage);
        }
    }
    CFRelease(source);
    if (images.count == 0) return nil;

    UIImageView *iv = [[UIImageView alloc] init];
    iv.animationImages = images;
    iv.animationDuration = count * 0.1;
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    [iv startAnimating];
    return iv;
}

- (UIView *)eevee_buildVideoWallpaperView:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    AVPlayer *player = [AVPlayer playerWithURL:url];
    player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    player.muted = YES;

    EeveeVideoLayerView *view = [[EeveeVideoLayerView alloc] init];
    view.playerLayer.player = player;
    view.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

    [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:player.currentItem
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        [player seekToTime:kCMTimeZero];
        [player play];
    }];
    [player play];
    return view;
}

@end

#pragma mark - Global refresh

static void RefreshAppUI(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            [window setNeedsLayout];
            [window layoutIfNeeded];
        }
    });
}

#pragma mark - Hooks (universal viewDidAppear and viewDidLayoutSubviews)

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self setupEeveeThemeButton];
}

%end

%hook UIViewController

- (void)viewDidLayoutSubviews {
    %orig;

    ThemeManager *tm = [ThemeManager shared];
    if (!tm.isThemeEnabled || tm.activeThemeName.length == 0) return;

    EeveeScreenRegistry *registry = [EeveeScreenRegistry shared];
    NSString *screenType = [registry identifyScreenContext:self];

    if (!screenType) return;

    // Apply wallpaper to background container (ALL screens)
    UIView *bgContainer = [registry findBackgroundContainerInView:self.view forScreen:screenType];
    if (bgContainer) {
        [self eevee_applyWallpaperToContainer:bgContainer];
    }

    // Apply canvas recoloring (NowPlaying only—has MixingBackgroundView)
    if ([screenType isEqualToString:@"NowPlaying"]) {
        [self eevee_applyCanvasTheme];
    }

    // Apply font colors globally (all screens, max depth 20)
    UIColor *textColor = [tm colorForKey:@"textColor" fallback:nil];
    if (textColor) {
        [EeveeThemeFilter recursivelyApplyFontColor:textColor
                                             toView:self.view
                                skippingCardOrCellSurfaces:YES
                                                   depth:20];
    }
}

%end

#pragma mark - Ctor

%ctor {
    %init;
    [[NSNotificationCenter defaultCenter] addObserverForName:EeveeThemeDidChangeNotification
                                                       object:nil
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification *note) {
        RefreshAppUI();
    }];
}
