#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPTImageRenderer : NSObject

@property (nonatomic, strong, readonly) UIView *rendererView;
@property (nonatomic, strong, readonly) UIImageView *imageView;
@property (nonatomic, strong, readonly) UIVisualEffectView *blurView;
@property (nonatomic, strong, readonly) UIView *dimmingView;
@property (nonatomic, strong, readonly, nullable) UIImage *currentImage;

+ (instancetype)sharedInstance;
+ (nullable UIImage *)loadSavedImage;

- (void)startRendering;
- (void)stopRendering;
- (void)reloadImage;
- (void)applySettings;
- (void)updateLayoutWithBounds:(CGRect)bounds;

@end

NS_ASSUME_NONNULL_END
