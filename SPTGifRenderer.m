#import "SPTGifRenderer.h"
#import "SPTCustomThemeManager.h"
#import <ImageIO/ImageIO.h>

@interface SPTGifRenderer ()

@property (nonatomic, strong, readwrite) UIView *rendererView;
@property (nonatomic, strong, readwrite) UIImageView *imageView;
@property (nonatomic, strong, readwrite) UIVisualEffectView *blurView;
@property (nonatomic, strong, readwrite) UIView *dimmingView;
@property (nonatomic, strong, nullable) NSArray<UIImage *> *cachedFrames;
@property (nonatomic, assign) NSTimeInterval cachedDuration;

@end

@implementation SPTGifRenderer

+ (instancetype)sharedInstance {
    static SPTGifRenderer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SPTGifRenderer alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupViews];
        [self reloadGif];
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

+ (nullable UIImage *)animatedGIFWithData:(NSData *)data {
    if (!data || data.length < 10) return nil;
    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) return nil;
    
    size_t count = CGImageSourceGetCount(source);
    if (count <= 1) {
        UIImage *img = [UIImage imageWithData:data scale:[UIScreen mainScreen].scale];
        CFRelease(source);
        return img;
    }
    
    NSMutableArray<UIImage *> *images = [NSMutableArray arrayWithCapacity:count];
    NSTimeInterval totalDuration = 0.0;
    
    for (size_t i = 0; i < count; i++) {
        CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, i, NULL);
        if (!cgImage) continue;
        
        [images addObject:[UIImage imageWithCGImage:cgImage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp]];
        CGImageRelease(cgImage);
        
        NSTimeInterval frameDuration = 0.1;
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
        if (properties) {
            CFDictionaryRef gifProperties = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
            if (gifProperties) {
                NSNumber *unclamped = CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFUnclampedDelayTime);
                if (unclamped && unclamped.doubleValue > 0.0) {
                    frameDuration = unclamped.doubleValue;
                } else {
                    NSNumber *delay = CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFDelayTime);
                    if (delay && delay.doubleValue > 0.0) {
                        frameDuration = delay.doubleValue;
                    }
                }
            }
            CFRelease(properties);
        }
        
        if (frameDuration < 0.02) frameDuration = 0.1;
        totalDuration += frameDuration;
    }
    
    CFRelease(source);
    return [UIImage animatedImageWithImages:images duration:totalDuration];
}

- (void)reloadGif {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *themeDir = [SPTCustomThemeManager themeMediaDirectory];
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSArray<NSString *> *candidates = @[
            [themeDir stringByAppendingPathComponent:@"custom_theme_media.gif"],
            [themeDir stringByAppendingPathComponent:@"custom_theme_media.dat"]
        ];
        
        NSData *gifData = nil;
        for (NSString *path in candidates) {
            if ([fm fileExistsAtPath:path]) {
                gifData = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
                if (gifData && gifData.length > 0) break;
            }
        }
        
        if (!gifData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.rendererView.hidden = YES;
            });
            return;
        }
        
        CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)gifData, NULL);
        if (!source) return;
        
        size_t count = CGImageSourceGetCount(source);
        NSMutableArray<UIImage *> *frames = [NSMutableArray arrayWithCapacity:count];
        NSTimeInterval duration = 0.0;
        
        for (size_t i = 0; i < count; i++) {
            CGImageRef imgRef = CGImageSourceCreateImageAtIndex(source, i, NULL);
            if (!imgRef) continue;
            [frames addObject:[UIImage imageWithCGImage:imgRef]];
            CGImageRelease(imgRef);
            
            NSTimeInterval delay = 0.1;
            CFDictionaryRef prop = CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
            if (prop) {
                CFDictionaryRef gifProp = CFDictionaryGetValue(prop, kCGImagePropertyGIFDictionary);
                if (gifProp) {
                    NSNumber *d = CFDictionaryGetValue(gifProp, kCGImagePropertyGIFUnclampedDelayTime) ?: CFDictionaryGetValue(gifProp, kCGImagePropertyGIFDelayTime);
                    if (d && d.doubleValue > 0.0) delay = d.doubleValue;
                }
                CFRelease(prop);
            }
            if (delay < 0.02) delay = 0.1;
            duration += delay;
        }
        CFRelease(source);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.cachedFrames = frames;
            self.cachedDuration = duration;
            
            self.imageView.animationImages = frames;
            self.imageView.animationDuration = duration;
            self.imageView.animationRepeatCount = 0;
            self.imageView.image = frames.firstObject;
            
            [self.imageView startAnimating];
            self.rendererView.hidden = (frames.count == 0);
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
    };
    
    if ([NSThread isMainThread]) {
        applyBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), applyBlock);
    }
}

- (void)startRendering {
    [self applySettings];
    if (self.cachedFrames.count > 0) {
        self.imageView.animationImages = self.cachedFrames;
        self.imageView.animationDuration = self.cachedDuration;
        [self.imageView startAnimating];
        self.rendererView.hidden = NO;
    } else {
        [self reloadGif];
    }
}

- (void)stopRendering {
    [self.imageView stopAnimating];
    self.rendererView.hidden = YES;
}

- (void)updateLayoutWithBounds:(CGRect)bounds {
    self.rendererView.frame = bounds;
    self.imageView.frame = bounds;
    self.dimmingView.frame = bounds;
    self.blurView.frame = bounds;
}

@end
