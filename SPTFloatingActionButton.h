#import <UIKit/UIKit.h>

@interface SPTFloatingActionButton : UIButton
+ (instancetype)sharedButton;
- (void)installInWindow:(UIWindow *)window;
@end
