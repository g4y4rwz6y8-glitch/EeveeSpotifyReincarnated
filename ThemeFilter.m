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
    // Check static keywords
    for (NSString *kw in [self blocklistKeywords]) {
        if ([className rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    
    // Check dynamic blocklist
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
    
    // Reject known card/cell surfaces immediately
    if ([self isCardOrCellSurface:view]) return nil;
    
    CGRect screen = [UIScreen mainScreen].bounds;
    CGRect frameInWindow = [view convertRect:view.bounds toView:nil];
    CGFloat coverageRatio = (frameInWindow.size.width * frameInWindow.size.height) /
                             (screen.size.width * screen.size.height);
    
    // Candidate criteria: covers >80% of screen and has few direct children (<5)
    BOOL isLargeEnough = coverageRatio > 0.80;
    BOOL hasMinimalDirectChildren = view.subviews.count < 5;
    
    if (isLargeEnough && hasMinimalDirectChildren) {
        // Prefer deeper matches by recursing first, then returning current if no better candidate
        UIView *best = nil;
        for (UIView *sub in view.subviews) {
            UIView *candidate = [self findDeepestBackgroundCanvasInView:sub screenType:screenType];
            if (candidate) best = candidate;  // Deeper = later in loop = preferred
        }
        return best ? best : view;  // Return self if no deeper candidate
    }
    
    // Not a canvas itself; recurse into children
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
    
    // Skip card/cell surfaces if requested
    if (skipCards && [self isCardOrCellSurface:view]) return;
    
    // Apply color to labels
    if ([view isKindOfClass:[UILabel class]]) {
        ((UILabel *)view).textColor = color;
    }
    // Apply color to button text
    else if ([view isKindOfClass:[UIButton class]]) {
        [((UIButton *)view) setTitleColor:color forState:UIControlStateNormal];
    }
    
    // Recurse into subviews
    for (UIView *sub in view.subviews) {
        [self recursivelyApplyFontColor:color 
                                toView:sub 
    skippingCardOrCellSurfaces:skipCards 
                                 depth:maxDepth - 1];
    }
}

@end
