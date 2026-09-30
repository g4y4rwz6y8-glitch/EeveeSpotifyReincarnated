#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPTVideoRenderer : NSObject

@property (nonatomic, strong, readonly) UIView *rendererView;
@property (nonatomic, strong, readonly) UIVisualEffectView *blurView;
@property (nonatomic, strong, readonly) UIView *dimmingView;

+ (instancetype)sharedInstance;
+ (nullable NSURL *)savedVideoURL;

- (void)startRendering;
- (void)stopRendering;
- (void)reloadVideo;
- (void)applySettings;
- (void)updateLayoutWithBounds:(CGRect)bounds;

@end

NS_ASSUME_NONNULL_END
