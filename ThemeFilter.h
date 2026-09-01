#import <UIKit/UIKit.h>

@interface EeveeThemeFilter : NSObject

+ (NSSet<NSString *> *)blocklistKeywords;
+ (NSSet<NSString *> *)canvasAllowlist;

+ (BOOL)classNameMatchesBlocklist:(NSString *)className;
+ (void)addToBlocklist:(NSString *)className;
+ (NSSet<NSString *> *)currentBlocklist;

+ (BOOL)isBackgroundCanvas:(UIView *)view;
+ (BOOL)isCardOrCellSurface:(UIView *)view;

+ (UIView *)findDeepestBackgroundCanvasInView:(UIView *)view screenType:(NSString *)screenType;

+ (void)recursivelyApplyFontColor:(UIColor *)color 
                           toView:(UIView *)view 
       skippingCardOrCellSurfaces:(BOOL)skipCards 
                            depth:(NSInteger)maxDepth;

@end
