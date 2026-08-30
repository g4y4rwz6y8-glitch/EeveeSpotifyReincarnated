#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface EeveeThemeFilter : NSObject
+ (BOOL)isBackgroundCanvas:(UIView *)view;
+ (BOOL)isCardOrCellSurface:(UIView *)view;
@end

NS_ASSUME_NONNULL_END
