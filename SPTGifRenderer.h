#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPTGifRenderer : NSObject

@property (nonatomic, strong, readonly) UIView *rendererView;
@property (nonatomic, strong, readonly) UIImageView *imageView;
@property (nonatomic, strong, readonly) UIVisualEffectView *blurView;
@property (nonatomic, strong, readonly) UIView *dimmingView;

+ (instancetype)sharedInstance;
+ (nullable UIImage *)animatedGIFWithData:(NSData *)data;

- (void)startRendering;
- (void)stopRendering;
- (void)reloadGif;
- (void)applySettings;
- (void)updateLayoutWithBounds:(CGRect)bounds;

@end

NS_ASSUME_NONNULL_END
