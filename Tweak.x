#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import "ThemeManager.h"
#import "ThemeFilter.h"
#import "ThemeSettingsViewController.h"
#import "EeveeDumpSession.h"

static UIButton *gThemeButton = nil;
static const NSInteger kEeveeWallpaperViewTag = 918273;

#pragma mark - Video Wallpaper Backing

@interface EeveeVideoLayerView : UIView
@property (nonatomic, readonly) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) id eevee_endObserver;
@end

@implementation EeveeVideoLayerView
+ (Class)layerClass { return [AVPlayerLayer class]; }
- (AVPlayerLayer *)playerLayer { return (AVPlayerLayer *)self.layer; }

- (void)dealloc {
    if (_eevee_endObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_eevee_endObserver];
        _eevee_endObserver = nil;
    }
    AVPlayer *player = self.playerLayer.player;
    if (player) {
        [player pause];
        self.playerLayer.player = nil;
    }
}
@end

#pragma mark - Screen Registry

@interface EeveeScreenRegistry : NSObject
+ (instancetype)shared;
- (NSString *)identifyScreenContext:(UIViewController *)vc;
- (UIView *)findBackgroundContainerInView:(UIView *)view forScreen:(NSString *)screenType;
@end

@implementation EeveeScreenRegistry
static EeveeScreenRegistry *sharedInstance = nil;
+ (instancetype)shared {
    static dispatch_once_t token;
    dispatch_once(&token, ^{ sharedInstance = [[self alloc] init]; });
    return sharedInstance;
}

- (NSString *)identifyScreenContext:(UIViewController *)vc {
    if (!vc) return nil;
    NSString *className = NSStringFromClass([vc class]);
    if ([className containsString:@"NowPlaying"]) return @"NowPlaying";
    if ([className containsString:@"Home"] || [className containsString:@"Browse"]) return @"Home";
    if ([className containsString:@"Search"]) return @"Search";
    if ([className containsString:@"Collection"] || [className containsString:@"YourLibrary"] || [className containsString:@"Library"]) return @"Library";
    if ([className containsString:@"Settings"] || [className containsString:@"Preferences"]) return @"Settings";
    return nil;
}

- (UIView *)findBackgroundContainerInView:(UIView *)view forScreen:(NSString *)screenType {
    if (!view) return nil;
    return [EeveeThemeFilter findDeepestBackgroundCanvasInView:view screenType:screenType];
}
@end

#pragma mark - Success Pill Toast

static void EeveeShowSuccessPill(NSString *title, NSString *subtitle) {
    if (!title) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { keyWindow = w; break; }
        }
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
        subtitleLabel.text = subtitle ? subtitle : @"";
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

#pragma mark - Theme Engine Extensions

@interface UIViewController (EeveeThemeEngine)
@end

@implementation UIViewController (EeveeThemeEngine)

- (void)setupEeveeThemeButton {
    UIWindow *keyWindow = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) { keyWindow = w; break; }
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

    CGRect bounds = [UIScreen mainScreen].bounds;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
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

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(eevee_handleLongPress:)];
    [btn addGestureRecognizer:lp];

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
    if (!btn) return;
    CGPoint translation = [pan translationInView:btn.superview];
    CGPoint newCenter = CGPointMake(btn.center.x + translation.x, btn.center.y + translation.y);
    CGRect bounds = [UIScreen mainScreen].bounds;
    newCenter.x = MIN(MAX(30, newCenter.x), bounds.size.width - 30);
    newCenter.y = MIN(MAX(60, newCenter.y), bounds.size.height - 60);
    btn.center = newCenter;
    [pan setTranslation:CGPointZero inView:btn.superview];
}

- (void)eevee_handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    EeveeDumpSession *session = [EeveeDumpSession shared];
    
    UIAlertController *picker = [UIAlertController alertControllerWithTitle:@"Scanner"
        message:[NSString stringWithFormat:@"Captured %ld/%ld", (long)session.completedCount, (long)session.totalCount]
        preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *name in session.targetScreens) {
        BOOL done = [session.completedScreens containsObject:name];
        NSString *label = done ? [NSString stringWithFormat:@"✓ %@ (Re-scan)", name] : name;
        [picker addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self eevee_captureCurrentScreenAs:name];
        }]];
    }

    [picker addAction:[UIAlertAction actionWithTitle:@"Reset All" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[EeveeDumpSession shared] reset];
        EeveeShowSuccessPill(@"Reset", @"Progress cleared");
    }]];
    [picker addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    if (picker.popoverPresentationController && gThemeButton) {
        picker.popoverPresentationController.sourceView = gThemeButton;
        picker.popoverPresentationController.sourceRect = gThemeButton.bounds;
    }
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)eevee_captureCurrentScreenAs:(NSString *)screenName {
    UIViewController *top = self;
    while (top.presentedViewController) top = top.presentedViewController;
    
    NSMutableString *log = [NSMutableString stringWithFormat:@"root class: %@\n", NSStringFromClass([top class])];
    [self eevee_dumpView:top.view depth:0 intoLog:log];
    [[EeveeDumpSession shared] recordDumpForScreen:screenName hierarchyLog:log];

    if ([EeveeDumpSession shared].isComplete) {
        EeveeShowSuccessPill(@"Complete", @"eevee_full_scan.txt saved to Files");
    } else {
        EeveeShowSuccessPill(@"Captured", screenName);
    }
}

- (void)eevee_dumpView:(UIView *)view depth:(NSInteger)depth intoLog:(NSMutableString *)log {
    if (!view) return;
    NSString *indent = [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0];
    [log appendFormat:@"%@%@ frame=%@ subviews=%lu\n", 
        indent, NSStringFromClass([view class]), NSStringFromCGRect(view.frame), (unsigned long)view.subviews.count];
    for (UIView *sub in view.subviews) {
        [self eevee_dumpView:sub depth:depth + 1 intoLog:log];
    }
}

#pragma mark Recolor Support

- (void)eevee_applyCanvasRecoloring {
    ThemeManager *tm = [ThemeManager shared];
    if (!tm.isThemeEnabled) return;

    if ([NSStringFromClass([self class]) containsString:@"NowPlaying"]) {
        [self eevee_recursiveRecolorMixingBackground:self.view theme:tm];
    }
}

- (void)eevee_recursiveRecolorMixingBackground:(UIView *)view theme:(ThemeManager *)tm {
    if (!view) return;
    if ([NSStringFromClass([view class]) isEqualToString:@"NowPlaying_MixingTransitionImpl.MixingBackgroundView"]) {
        UIColor *bg = [tm colorForKey:@"backgroundColor" fallback:nil];
        if (bg) {
            for (UIView *sub in view.subviews) {
                if ([sub isMemberOfClass:[UIView class]]) sub.backgroundColor = bg;
            }
        }
        return;
    }
    for (UIView *sub in view.subviews) {
        [self eevee_recursiveRecolorMixingBackground:sub theme:tm];
    }
}

#pragma mark Wallpaper Support

- (void)eevee_applyWallpaperToContainer:(UIView *)container {
    if (!container) return;
    ThemeManager *tm = [ThemeManager shared];
    
    UIView *existing = [container viewWithTag:kEeveeWallpaperViewTag];
    if (![tm hasWallpaper]) {
        if (existing) [existing removeFromSuperview];
        return;
    }

    if (existing) return;

    UIView *wp = [self eevee_buildWallpaperView];
    if (wp) {
        wp.tag = kEeveeWallpaperViewTag;
        wp.translatesAutoresizingMaskIntoConstraints = NO;
        [container insertSubview:wp atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [wp.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [wp.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [wp.topAnchor constraintEqualToAnchor:container.topAnchor],
            [wp.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
        ]];
    }
}

- (UIView *)eevee_buildWallpaperView {
    ThemeManager *tm = [ThemeManager shared];
    NSString *path = [tm wallpaperFilePath];
    if (!path) return nil;

    switch ([tm currentWallpaperType]) {
        case EeveeWallpaperTypeImage: return [self eevee_buildImageWP:path];
        case EeveeWallpaperTypeGIF:   return [self eevee_buildGIFWP:path];
        case EeveeWallpaperTypeVideo: return [self eevee_buildVideoWP:path];
        default: return nil;
    }
}

- (UIView *)eevee_buildImageWP:(NSString *)path {
    UIImage *img = [UIImage imageWithContentsOfFile:path];
    if (!img) return nil;
    UIImageView *iv = [[UIImageView alloc] initWithImage:img];
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    return iv;
}

- (UIView *)eevee_buildGIFWP:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;

    Class fImg = NSClassFromString(@"FLAnimatedImage");
    Class fView = NSClassFromString(@"FLAnimatedImageView");
    if (fImg && fView) {
        id anim = nil;
        if ([fImg respondsToSelector:@selector(animatedImageWithGIFData:)]) {
            anim = [fImg performSelector:@selector(animatedImageWithGIFData:) withObject:data];
        } else {
            anim = [[fImg alloc] initWithAnimatedGIFData:data];
        }
        if (anim) {
            UIView *iv = [[fView alloc] init];
            [iv setValue:anim forKey:@"animatedImage"];
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.clipsToBounds = YES;
            return iv;
        }
    }

    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!src) return nil;
    size_t count = CGImageSourceGetCount(src);
    NSMutableArray *frames = [NSMutableArray array];
    for (size_t i = 0; i < count; i++) {
        CGImageRef cg = CGImageSourceCreateImageAtIndex(src, i, NULL);
        if (cg) { [frames addObject:[UIImage imageWithCGImage:cg]]; CGImageRelease(cg); }
    }
    CFRelease(src);
    
    UIImageView *iv = [[UIImageView alloc] init];
    iv.animationImages = frames;
    iv.animationDuration = MAX(0.1 * frames.count, 0.5);
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    [iv startAnimating];
    return iv;
}

- (UIView *)eevee_buildVideoWP:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    AVQueuePlayer *player = [[AVQueuePlayer alloc] initWithPlayerItem:item];
    player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    player.muted = YES;

    EeveeVideoLayerView *view = [[EeveeVideoLayerView alloc] init];
    view.playerLayer.player = player;
    view.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

    __weak AVQueuePlayer *wp = player;
    id obs = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                                               object:item
                                                                queue:[NSOperationQueue mainQueue]
                                                           usingBlock:^(NSNotification *n) {
        [wp seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL f) { [wp play]; }];
    }];
    view.eevee_endObserver = obs;
    [player play];
    return view;
}

@end

#pragma mark - Universal Hooks

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self setupEeveeThemeButton];
}

- (void)viewDidLayoutSubviews {
    %orig;

    ThemeManager *tm = [ThemeManager shared];
    if (!tm.isThemeEnabled) return;

    NSString *screenType = [[EeveeScreenRegistry shared] identifyScreenContext:self];
    if (!screenType) return;

    // 1. Wallpaper injection
    UIView *bg = [[EeveeScreenRegistry shared] findBackgroundContainerInView:self.view forScreen:screenType];
    if (bg) [self eevee_applyWallpaperToContainer:bg];

    // 2. Now Playing recoloring
    if ([screenType isEqualToString:@"NowPlaying"]) {
        [self eevee_applyCanvasRecoloring];
    }

    // 3. Global Text Recoloring (Optimized)
    UIColor *txt = [tm colorForKey:@"textColor" fallback:nil];
    if (txt) {
        [EeveeThemeFilter recursivelyApplyFontColor:txt 
                                             toView:self.view 
                         skippingCardOrCellSurfaces:YES 
                                              depth:20];
    }
}

%end

#pragma mark - Global UI Refresh

static void EeveeRefreshAll(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            [window setNeedsLayout];
            [window layoutIfNeeded];
        }
    });
}

%ctor {
    %init;
    [[NSNotificationCenter defaultCenter] addObserverForName:EeveeThemeDidChangeNotification
                                                       object:nil
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification *note) {
        EeveeRefreshAll();
    }];
}
