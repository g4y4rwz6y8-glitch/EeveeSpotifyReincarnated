#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ThemeSettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) UITableView *tableView;

+ (NSString *)themeMediaDirectory;
+ (NSString *)savedMediaPath;
+ (void)removeSavedMediaFiles;

- (void)applyThemeSettings;
- (void)resetThemeSettings;

@end

NS_ASSUME_NONNULL_END
