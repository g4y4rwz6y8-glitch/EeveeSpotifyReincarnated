#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPTFloatingActionButton : UIButton

+ (instancetype)sharedInstance;
- (void)attachToWindow:(UIWindow *)window;
- (void)presentThemeSettings;
- (void)setFloatingAlpha:(CGFloat)alpha animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
