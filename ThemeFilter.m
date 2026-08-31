#import "ThemeFilter.h"

@implementation EeveeThemeFilter

static NSMutableSet *gDynamicBlocklist = nil;

#pragma mark - Blocklist Keywords (Static)

+ (NSSet<NSString *> *)blocklistKeywords {
    return [NSSet setWithArray:@[
        @"Cell", @"Card", @"Row", @"Button", @"Artwork", @"Image",
        @"Label", @"Cover", @"Chip", @"Badge", @"Icon", @"Avatar",
        @"Track", @"Artist", @"Album", @"Playlist", @"Section",
        @"Header", @"Footer", @"Separator", @"Divider", @"Indicator"
    ]];
}

#pragma mark - Canvas Allowlist

+ (NSSet<NSString *> *)canvasAllowlist {
    static NSSet *set;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        set = [NSSet setWithArray:@[
            @"NowPlaying_MixingTransitionImpl.MixingBackgroundView",
            @"HomeViewController",
            @"SearchViewController",
            @"LibraryViewController",
            @"SettingsViewController"
        ]];
    });
    return set;
}

#pragma mark - Blocklist Matching

+ (BOOL)classNameMatchesBlocklist:(NSString *)className {
    for (NSString *kw in [self blocklistKeywords]) {
        if ([className rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    
    if (gDynamicBlocklist) {
        for (NSString *blocked in gDynamicBlocklist) {
            if ([className isEqualToString:blocked]) {
                return YES;
            }
        }
    }
    
    return NO;
}

+ (NSSet<NSString *> *)currentBlocklist {
    if (!gDynamicBlocklist) {
        gDynamicBlocklist = [NSMutableSet set];
    }
    return [gDynamicBlocklist copy];
}

+ (void)addToBlocklist:(NSString *)className {
    if (!gDynamicBlocklist) {
        gDynamicBlocklist = [NSMutableSet set];
    }
    [gDynamicBlocklist addObject:className];
}

#pragma mark - Canvas Detection

+ (BOOL)isBackgroundCanvas:(UIView *)view {
    if (!view) return NO;
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
    if (!view) return NO;
    NSString *className = NSStringFromClass([view class]);
    return [self classNameMatchesBlocklist:className];
}

#pragma mark - Screen-Aware Canvas Finder

+ (UIView *)findDeepestBackgroundCanvasInView:(UIView *)view screenType:(NSString *)screenType {
    if (!view) return nil;
    
    if ([self isCardOrCellSurface:view]) return nil;
    
    CGRect screen = [UIScreen mainScreen].bounds;
    CGRect frameInWindow = [view convertRect:view.bounds toView:nil];
    CGFloat coverageRatio = (frameInWindow.size.width * frameInWindow.size.height) /
                             (screen.size.width * screen.size.height);
    
    BOOL isLargeEnough = coverageRatio > 0.80;
    BOOL hasMinimalDirectChildren = view.subviews.count < 5;
    
    if (isLargeEnough && hasMinimalDirectChildren) {
        UIView *best = nil;
        for (UIView *sub in view.subviews) {
            UIView *candidate = [self findDeepestBackgroundCanvasInView:sub screenType:screenType];
            if (candidate) best = candidate;
        }
        return best ? best : view;
    }
    
    UIView *best = nil;
    for (UIView *sub in view.subviews) {
        UIView *candidate = [self findDeepestBackgroundCanvasInView:sub screenType:screenType];
        if (candidate) best = candidate;
    }
    return best;
}

#pragma mark - Safe Recursive Font Coloring

+ (void)recursivelyApplyFontColor:(UIColor *)color 
                           toView:(UIView *)view 
       skippingCardOrCellSurfaces:(BOOL)skipCards 
                            depth:(NSInteger)maxDepth {
    if (!view || maxDepth <= 0 || !color) return;
    
    if (skipCards && [self isCardOrCellSurface:view]) return;
    
    if ([view isKindOfClass:[UILabel class]]) {
        ((UILabel *)view).textColor = color;
    }
    else if ([view isKindOfClass:[UIButton class]]) {
        [((UIButton *)view) setTitleColor:color forState:UIControlStateNormal];
    }
    
    for (UIView *sub in view.subviews) {
        [self recursivelyApplyFontColor:color 
                                toView:sub 
    skippingCardOrCellSurfaces:skipCards 
                                 depth:maxDepth - 1];
    }
}

@end
