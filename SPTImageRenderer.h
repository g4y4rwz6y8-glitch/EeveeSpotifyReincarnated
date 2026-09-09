#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, SPTWallpaperType) {
    SPTWallpaperTypeNone,
    SPTWallpaperTypeImage,
    SPTWallpaperTypeGif,
    SPTWallpaperTypeVideo
};

@protocol SPTBackgroundRenderer <NSObject>

@property (nonatomic, strong, readonly) UIView *renderView;

- (void)installInWindow:(UIWindow *)window;
- (void)loadFromFileURL:(NSURL *)fileURL completion:(void (^)(BOOL success))completion;
- (void)pause;   // stop timers/players, keep last frame visible
- (void)resume;
- (void)teardown; // fully release buffers/players, remove from superview

@end
