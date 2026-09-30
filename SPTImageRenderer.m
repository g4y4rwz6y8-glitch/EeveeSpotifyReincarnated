#import "SPTImageRenderer.h"
#import "SPTCustomThemeManager.h"

@interface SPTImageRenderer ()

@property (nonatomic, strong) UIView *rendererView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *dimmingView;
@property (nonatomic, strong, nullable) UIImage *currentImage;

@end

@implementation SPTImageRenderer

+ (instancetype)sharedInstance {
    static SPTImageRenderer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SPTImageRenderer alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupViews];
        [self reloadImage];
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
    
    // Background Image Layer
    self.imageView = [[UIImageView alloc] initWithFrame:screenBounds];
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.imageView.clipsToBounds = YES;
    self.imageView.backgroundColor = [UIColor clearColor];
    [self.rendererView addSubview:self.imageView];
    
    // Dimming Overlay (allows readable text on bright wallpapers)
    self.dimmingView = [[UIView alloc] initWithFrame:screenBounds];
    self.dimmingView.backgroundColor = [UIColor blackColor];
    self.dimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.dimmingView.alpha = 0.15f;
    [self.rendererView addSubview:self.dimmingView];
    
    // Glass Blur Layer
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.blurView.frame = screenBounds;
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.blurView.alpha = 0.70f;
    [self.rendererView addSubview:self.blurView];
}

+ (nullable UIImage *)loadSavedImage {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *ext = [defaults stringForKey:kEeveeThemeExtensionKey] ?: @"png";
    
    NSArray<NSString *> *searchDirs = @[
        [SPTCustomThemeManager themeMediaDirectory],
        [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"EeveeTheme"],
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"EeveeTheme"]
    ];
    
    NSArray<NSString *> *extensions = @[ext, @"png", @"jpg", @"jpeg", @"dat"];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *dir in searchDirs) {
        for (NSString *currExt in extensions) {
            NSString *filePath = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", kEeveeThemeMediaFileName, currExt]];
            if ([fm fileExistsAtPath:filePath]) {
                NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:nil];
                if (data && data.length > 0) {
                    UIImage *img = [UIImage imageWithData:data scale:[UIScreen mainScreen].scale];
                    if (img) {
                        return img;
                    }
                }
            }
        }
    }
    return nil;
}

- (void)reloadImage {
    UIImage *image = [SPTImageRenderer loadSavedImage];
    self.currentImage = image;
    
    void (^updateBlock)(void) = ^{
        self.imageView.image = image;
        self.rendererView.hidden = (image == nil);
    };
    
    if ([NSThread isMainThread]) {
        updateBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), updateBlock);
    }
}

- (void)applySettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    float opacity = [defaults objectForKey:kEeveeThemeOpacityKey] ? [defaults floatForKey:kEeveeThemeOpacityKey] : 0.85f;
    BOOL blurEnabled = [defaults objectForKey:kEeveeThemeBlurEnabledKey] ? [defaults boolForKey:kEeveeThemeBlurEnabledKey] : YES;
    NSInteger blurStyle = [defaults integerForKey:kEeveeThemeBlurStyleKey];
    float blurAlpha = [defaults objectForKey:kEeveeThemeBlurAlphaKey] ? [defaults floatForKey:kEeveeThemeBlurAlphaKey] : 0.70f;
    
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
        
        [self reloadImage];
    };
    
    if ([NSThread isMainThread]) {
        applyBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), applyBlock);
    }
}

- (void)startRendering {
    [self applySettings];
    self.rendererView.hidden = (self.currentImage == nil);
}

- (void)stopRendering {
    self.rendererView.hidden = YES;
}

- (void)updateLayoutWithBounds:(CGRect)bounds {
    self.rendererView.frame = bounds;
    self.imageView.frame = bounds;
    self.dimmingView.frame = bounds;
    self.blurView.frame = bounds;
}

@end
