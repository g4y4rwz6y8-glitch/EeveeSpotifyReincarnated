#import "SPTSettingsViewController.h"

@implementation SPTSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (!self.title || [self.title isEqualToString:@"Custom Theme"]) {
        self.title = @"Eevee Theme Engine";
    }
}

@end
