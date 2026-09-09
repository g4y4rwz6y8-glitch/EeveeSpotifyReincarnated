#import <UIKit/UIKit.h>

@interface SPTFloatingActionButton : UIButton

+ (instancetype)sharedButton;
+ (BOOL)isEligibleContentWindow:(UIWindow *)window; // Add this line
- (void)installInWindow:(UIWindow *)window;

@end
