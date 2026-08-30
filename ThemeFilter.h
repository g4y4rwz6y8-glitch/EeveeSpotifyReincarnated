#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface EeveeThemeFilter : NSObject

// MARK: - Canvas & Card Detection
+ (BOOL)isBackgroundCanvas:(UIView *)view;
+ (BOOL)isCardOrCellSurface:(UIView *)view;

// MARK: - Screen-Aware Canvas Finder
+ (UIView *)findDeepestBackgroundCanvasInView:(UIView *)view screenType:(NSString *)screenType;

// MARK: - Safe Recursive Font Coloring
+ (void)recursivelyApplyFontColor:(UIColor *)color 
                           toView:(UIView *)view 
              skippingCardOrCellSurfaces:(BOOL)skipCards 
                                 depth:(NSInteger)maxDepth;

// MARK: - Blocklist Management
+ (NSSet<NSString *> *)blocklistKeywords;
+ (BOOL)classNameMatchesBlocklist:(NSString *)className;
+ (NSSet<NSString *> *)currentBlocklist;
+ (void)addToBlocklist:(NSString *)className;

@end

NS_ASSUME_NONNULL_END
