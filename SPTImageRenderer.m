#import "SPTImageRenderer.h"
#import "SPTCustomThemeManager.h"

@interface SPTImageRenderer ()

@property (nonatomic, strong, readwrite) UIView *rendererView;
@property (nonatomic, strong, readwrite) UIImageView *imageView;
@property (nonatomic, strong, readwrite) UIVisualEffectView *blurView;
@property (nonatomic, strong, readwrite) UIView *dimmingView;
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
    
    self.imageView = [[UIImageView alloc] initWithFrame:screenBounds];
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.imageView.clipsToBounds = YES;
    self.imageView.backgroundColor = [UIColor clearColor];
    [self.rendererView addSubview:self.imageView];
    
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

+ (nullable UIImage *)loadSavedImage {
    NSString *themeDir = [SPTCustomThemeManager themeMediaDirectory];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *ext = [defaults stringForKey:kEeveeThemeExtensionKey] ?: @"png";
    
    NSArray<NSString *> *candidates = @[
        [themeDir stringByAppendingPathComponent:[NSString stringWithFormat:@"custom_theme_media.%@", ext]],
        [themeDir stringByAppendingPathComponent:@"custom_theme_media.png"],
        [themeDir stringByAppendingPathComponent:@"custom_theme_media.jpg"],
        [themeDir stringByAppendingPathComponent:@"custom_theme_media.jpeg"],
        [themeDir stringByAppendingPathComponent:@"custom_theme_media.dat"]
    ];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in candidates) {
        if ([fm fileExistsAtPath:path]) {
            NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
            if (data && data.length > 0) {
                return [UIImage imageWithData:data scale:[UIScreen mainScreen].scale];
            }
        }
    }
    return nil;
}

- (void)reloadImage {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = [SPTImageRenderer loadSavedImage];
        self.currentImage = image;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView.image = image;
            self.rendererView.hidden = (image == nil);
        });
    });
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
        
        if (!self.currentImage) {
            [self reloadImage];
        }
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
