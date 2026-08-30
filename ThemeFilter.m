#import "ThemeFilter.h"

@implementation EeveeThemeFilter

+ (NSSet<NSString *> *)canvasAllowlist {
    static NSSet *set;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        set = [NSSet setWithArray:@[
            @"NowPlaying_MixingTransitionImpl.MixingBackgroundView"
        ]];
    });
    return set;
}

+ (NSArray<NSString *> *)blocklistKeywords {
    return @[@"Cell", @"Card", @"Row", @"Button", @"Artwork", @"Image",
              @"Label", @"Cover", @"Chip", @"Badge", @"Icon", @"Avatar"];
}

+ (BOOL)classNameMatchesBlocklist:(NSString *)className {
    for (NSString *kw in [self blocklistKeywords]) {
        if ([className rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)isBackgroundCanvas:(UIView *)view {
    NSString *className = NSStringFromClass([view class]);
    if ([self classNameMatchesBlocklist:className]) return NO;
    if ([[self canvasAllowlist] containsObject:className]) return YES;

    CGRect screen = [UIScreen mainScreen].bounds;
    CGRect frameInWindow = [view convertRect:view.bounds toView:nil];
    CGFloat coverageRatio = (frameInWindow.size.width * frameInWindow.size.height) /
                             (screen.size.width * screen.size.height);
    BOOL isLargeEnough = coverageRatio > 0.85;
    BOOL hasFewDirectContentSubviews = view.subviews.count <= 2;
    return isLargeEnough && hasFewDirectContentSubviews;
}

+ (BOOL)isCardOrCellSurface:(UIView *)view {
    NSString *className = NSStringFromClass([view class]);
    return [self classNameMatchesBlocklist:className];
}

@end
