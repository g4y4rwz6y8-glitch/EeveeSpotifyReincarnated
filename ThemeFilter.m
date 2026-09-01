#import "ThemeFilter.h"

@implementation EeveeThemeFilter

static NSMutableSet *gDynamicBlocklist = nil;

#pragma mark - Blocklist Keywords

+ (NSSet<NSString *> *)blocklistKeywords {
    static NSSet *keywords = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keywords = [NSSet setWithArray:@[
            @"Cell", @"Card", @"Row", @"Button", @"Artwork", @"Image",
            @"Label", @"Cover", @"Chip", @"Badge", @"Icon", @"Avatar",
            @"Track", @"Artist", @"Album", @"Playlist", @"Section",
            @"Header", @"Footer", @"Separator", @"Divider", @"Indicator"
        ]];
    });
    return keywords;
}

#pragma mark - Canvas Allowlist

+ (NSSet<NSString *> *)canvasAllowlist {
    static NSSet *set = nil;
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

#pragma mark - Blocklist Logic

+ (BOOL)classNameMatchesBlocklist:(NSString *)className {
    if (!className) return NO;
    
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
    return gDynamicBlocklist ? [gDynamicBlocklist copy] : [NSSet set];
}

+ (void)addToBlocklist:(NSString *)className {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gDynamicBlocklist = [[NSMutableSet alloc] init];
    });
    if (className) [gDynamicBlocklist addObject:className];
}

#pragma mark - Detection

+ (BOOL)isBackgroundCanvas:(UIView *)view {
    if (!view) return NO;
    NSString *className = NSStringFromClass([view class]);
    
    if ([self classNameMatchesBlocklist:className]) return NO;
    if ([[self canvasAllowlist] containsObject:className]) return YES;
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGRect frameInWindow = [view convertRect:view.bounds toView:nil];
    
    CGFloat coverageRatio = (frameInWindow.size.width * frameInWindow.size.height) /
                             (screenBounds.size.width * screenBounds.size.height);
    
    // Large background-like views usually have very few direct subviews
    return (coverageRatio > 0.85 && view.subviews.count <= 2);
}

+ (BOOL)isCardOrCellSurface:(UIView *)view {
    if (!view) return NO;
    return [self classNameMatchesBlocklist:NSStringFromClass([view class])];
}

#pragma mark - Deepest Container Search

+ (UIView *)findDeepestBackgroundCanvasInView:(UIView *)view screenType:(NSString *)screenType {
    if (!view || view.hidden || view.alpha < 0.01) return nil;
    if ([self isCardOrCellSurface:view]) return nil;
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGRect frameInWindow = [view convertRect:view.bounds toView:nil];
    
    CGFloat coverageRatio = (frameInWindow.size.width * frameInWindow.size.height) /
                             (screenBounds.size.width * screenBounds.size.height);
    
    // Optimization: If a view is significantly smaller than the screen, don't look deeper.
    if (coverageRatio < 0.50) return nil;

    UIView *deepestCandidate = nil;
    for (UIView *sub in view.subviews) {
        UIView *found = [self findDeepestBackgroundCanvasInView:sub screenType:screenType];
        if (found) deepestCandidate = found;
    }
    
    if (deepestCandidate) return deepestCandidate;
    
    // Fallback to self if we meet background criteria
    if (coverageRatio > 0.80 && view.subviews.count < 5) {
        return view;
    }
    
    return nil;
}

#pragma mark - Optimized Recursive Coloring

+ (void)recursivelyApplyFontColor:(UIColor *)color 
                           toView:(UIView *)view 
       skippingCardOrCellSurfaces:(BOOL)skipCards 
                            depth:(NSInteger)maxDepth {
    
    if (!view || maxDepth <= 0 || !color || view.hidden) return;
    
    // Optimization: Skip recursive heavy-lifting if view is a content surface
    if (skipCards && [self isCardOrCellSurface:view]) return;
    
    // Optimization: Only update if the color actually differs to avoid hitching
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (![label.textColor isEqual:color]) {
            label.textColor = color;
        }
    }
    else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        if (![[button titleColorForState:UIControlStateNormal] isEqual:color]) {
            [button setTitleColor:color forState:UIControlStateNormal];
        }
    }
    
    // Don't recurse into common system views that don't hold user text labels
    NSString *className = NSStringFromClass([view class]);
    if ([className containsString:@"UISlider"] || [className containsString:@"UIProgress"]) return;

    for (UIView *sub in view.subviews) {
        [self recursivelyApplyFontColor:color 
                                toView:sub 
            skippingCardOrCellSurfaces:skipCards 
                                 depth:maxDepth - 1];
    }
}

@end
