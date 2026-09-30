#import "SPTVideoRenderer.h"
#import "SPTCustomThemeManager.h"

@interface SPTVideoRenderer ()

@property (nonatomic, strong, readwrite) UIView *rendererView;
@property (nonatomic, strong, readwrite) UIVisualEffectView *blurView;
@property (nonatomic, strong, readwrite) UIView *dimmingView;
@property (nonatomic, strong, nullable) AVQueuePlayer *player;
@property (nonatomic, strong, nullable) AVPlayerLooper *looper;
@property (nonatomic, strong, nullable) AVPlayerLayer *playerLayer;
@property (nonatomic, assign) BOOL isPlaying;

@end

@implementation SPTVideoRenderer

+ (instancetype)sharedInstance {
    static SPTVideoRenderer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SPTVideoRenderer alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupViews];
        [self setupLifecycleObservers];
        [self reloadVideo];
        [self applySettings];
    }
    return self;
}

- (void)setupViews {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    
    self.rendererView = [[UIView alloc] initWithFrame:screenBounds];
    self.rendererView.backgroundColor = [UIColor clearColor];
    self.rendererView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.rendererView.clipsToBounds = YES;
    self.rendererView.userInteractionEnabled = NO;
    
    self.dimmingView = [[UIView alloc] initWithFrame:screenBounds];
    self.dimmingView.backgroundColor = [UIColor blackColor];
    self.dimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.dimmingView.alpha = 0.20f;
    [self.rendererView addSubview:self.dimmingView];
    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.blurView.frame = screenBounds;
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.blurView.alpha = 0.65f;
    [self.rendererView addSubview:self.blurView];
}

- (void)setupLifecycleObservers {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [nc addObserver:self selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)appDidEnterBackground {
    if (self.isPlaying && self.player) {
        [self.player pause];
    }
}

- (void)appWillEnterForeground {
    if (self.isPlaying && self.player && [SPTCustomThemeManager isCustomThemeActive]) {
        [self.player play];
    }
}

+ (nullable NSURL *)savedVideoURL {
    NSString *themeDir = [SPTCustomThemeManager themeMediaDirectory];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedExt = [defaults stringForKey:kEeveeThemeExtensionKey] ?: @"mp4";
    
    NSArray<NSString *> *candidates = @[
        [themeDir stringByAppendingPathComponent:[NSString stringWithFormat:@"custom_theme_media.%@", savedExt]],
        [themeDir stringByAppendingPathComponent:@"custom_theme_media.mp4"],
        [themeDir stringByAppendingPathComponent:@"custom_theme_media.mov"],
        [themeDir stringByAppendingPathComponent:@"custom_theme_media.dat"]
    ];
    
    for (NSString *path in candidates) {
        if ([fm fileExistsAtPath:path]) {
            return [NSURL fileURLWithPath:path];
        }
    }
    return nil;
}

- (void)reloadVideo {
    NSURL *videoURL = [SPTVideoRenderer savedVideoURL];
    if (!videoURL) {
        [self cleanupPlayer];
        self.rendererView.hidden = YES;
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self cleanupPlayer];
        
        AVAsset *asset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
        
        self.player = [AVQueuePlayer queuePlayerWithItems:@[playerItem]];
        self.player.muted = YES;
        self.player.volume = 0.0f;
        self.player.preventsDisplaySleepDuringVideoPlayback = NO;
        self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
        
        self.looper = [AVPlayerLooper playerLooperWithPlayer:self.player templateItem:playerItem];
        
        self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.playerLayer.frame = self.rendererView.bounds;
        
        [self.rendererView.layer insertSublayer:self.playerLayer atIndex:0];
        
        if (self.isPlaying) {
            [self.player play];
        }
        
        self.rendererView.hidden = NO;
    });
}

- (void)cleanupPlayer {
    if (self.player) {
        [self.player pause];
        [self.player removeAllItems];
        self.player = nil;
    }
    self.looper = nil;
    if (self.playerLayer) {
        [self.playerLayer removeFromSuperlayer];
        self.playerLayer = nil;
    }
}

- (void)applySettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    float opacity = [defaults objectForKey:kEeveeThemeOpacityKey] ? [defaults floatForKey:kEeveeThemeOpacityKey] : 0.85f;
    BOOL blurEnabled = [defaults objectForKey:kEeveeThemeBlurEnabledKey] ? [defaults boolForKey:kEeveeThemeBlurEnabledKey] : YES;
    NSInteger blurStyle = [defaults integerForKey:kEeveeThemeBlurStyleKey];
    float blurAlpha = [defaults objectForKey:kEeveeThemeBlurAlphaKey] ? [defaults floatForKey:kEeveeThemeBlurAlphaKey] : 0.65f;
    
    void (^applyBlock)(void) = ^{
        self.dimmingView.alpha = 1.0f - opacity;
        
        if (blurEnabled) {
            UIBlurEffectStyle style = UIBlurEffectStyleDark;
            if (@available(iOS 13.0, *)) {
                switch (blurStyle) {
                    case 0: style = UIBlurEffectStyleSystemUltraThinMaterialDark; break;
                    case 1: style = UIBlurEffectStyleSystemThinMaterialDark; break;
                    case 2: style = UIBlurEffectStyleDark; break;
                    case 3: style = UIBlurEffectStyleRegular; break;
                    default: style = UIBlurEffectStyleDark; break;
                }
            }
            self.blurView.effect = [UIBlurEffect effectWithStyle:style];
            self.blurView.alpha = blurAlpha;
            self.blurView.hidden = NO;
        } else {
            self.blurView.hidden = YES;
        }
        
        if (!self.playerLayer) {
            [self reloadVideo];
        }
    };
    
    if ([NSThread isMainThread]) {
        applyBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), applyBlock);
    }
}

- (void)startRendering {
    self.isPlaying = YES;
    [self applySettings];
    if (self.player) {
        [self.player play];
    } else {
        [self reloadVideo];
    }
    self.rendererView.hidden = NO;
}

- (void)stopRendering {
    self.isPlaying = NO;
    if (self.player) {
        [self.player pause];
    }
    self.rendererView.hidden = YES;
}

- (void)updateLayoutWithBounds:(CGRect)bounds {
    self.rendererView.frame = bounds;
    self.playerLayer.frame = bounds;
    self.dimmingView.frame = bounds;
    self.blurView.frame = bounds;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self cleanupPlayer];
}

@end
