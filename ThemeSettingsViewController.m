#import "ThemeSettingsViewController.h"
#import "ThemeManager.h"

typedef NS_ENUM(NSInteger, ThemeSettingsSection) {
    ThemeSettingsSectionToggle = 0,
    ThemeSettingsSectionImport,
    ThemeSettingsSectionWallpaper,
    ThemeSettingsSectionSaved,
    ThemeSettingsSectionCount
};

@interface ThemeSettingsViewController ()
@property (nonatomic, strong) UISwitch *enabledSwitch;
@property (nonatomic, strong) NSArray<NSString *> *savedThemes;
@end

@implementation ThemeSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Custom Theme";
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];

    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                               target:self
                                                                               action:@selector(dismissSelf)];
    self.navigationItem.rightBarButtonItem = doneBtn;

    [self reloadSavedThemes];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)reloadSavedThemes {
    self.savedThemes = [[ThemeManager shared] allSavedThemes];
    [self.tableView reloadData];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return ThemeSettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case ThemeSettingsSectionToggle: return 1;
        case ThemeSettingsSectionImport: return 1;
        case ThemeSettingsSectionWallpaper: return [ThemeManager shared].hasWallpaper ? 2 : 1;
        case ThemeSettingsSectionSaved: return MAX(self.savedThemes.count, (NSUInteger)1);
        default: return 0;
    }
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case ThemeSettingsSectionWallpaper: return @"Wallpaper";
        case ThemeSettingsSectionSaved: return @"Saved Themes";
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor labelColor];

    switch (indexPath.section) {
        case ThemeSettingsSectionToggle: {
            cell.textLabel.text = @"Enable Custom Theme";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (!self.enabledSwitch) {
                self.enabledSwitch = [[UISwitch alloc] init];
                [self.enabledSwitch addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
            }
            self.enabledSwitch.on = [ThemeManager shared].isThemeEnabled;
            cell.accessoryView = self.enabledSwitch;
            break;
        }
        case ThemeSettingsSectionImport: {
            cell.textLabel.text = @"Import Theme File (.json / .plist)";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        }
        case ThemeSettingsSectionWallpaper: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Choose Wallpaper (Photo / GIF / Video)";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                cell.textLabel.text = @"Clear Wallpaper";
                cell.textLabel.textColor = [UIColor systemRedColor];
            }
            break;
        }
        case ThemeSettingsSectionSaved: {
            if (self.savedThemes.count == 0) {
                cell.textLabel.text = @"No saved themes yet";
                cell.textLabel.textColor = [UIColor secondaryLabelColor];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                break;
            }
            NSString *name = self.savedThemes[indexPath.row];
            cell.textLabel.text = name;
            BOOL isActive = [name isEqualToString:[ThemeManager shared].activeThemeName];
            cell.accessoryType = isActive ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            break;
        }
        default: break;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    switch (indexPath.section) {
        case ThemeSettingsSectionImport:
            [self presentDocumentPicker];
            break;
        case ThemeSettingsSectionWallpaper:
            if (indexPath.row == 0) {
                [self presentPhotoPicker];
            } else {
                [[ThemeManager shared] clearWallpaper];
                [self.tableView reloadData];
            }
            break;
        case ThemeSettingsSectionSaved: {
            if (self.savedThemes.count == 0) return;
            NSString *name = self.savedThemes[indexPath.row];
            [[ThemeManager shared] setActiveTheme:name];
            [self.tableView reloadData];
            break;
        }
        default: break;
    }
}

- (nullable UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    if (indexPath.section != ThemeSettingsSectionSaved || self.savedThemes.count == 0) return nil;

    NSString *name = self.savedThemes[indexPath.row];
    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                            title:@"Delete"
                                                                          handler:^(UIContextualAction *action, __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
        [[ThemeManager shared] deleteTheme:name];
        [self reloadSavedThemes];
        completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[delete]];
}

#pragma mark - Actions

- (void)toggleChanged:(UISwitch *)sender {
    [ThemeManager shared].themeEnabled = sender.isOn;
}

#pragma mark - Theme JSON/plist import

- (void)presentDocumentPicker {
    NSArray<UTType *> *types = @[UTTypeJSON, UTTypePropertyList, UTTypeItem];
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) {
        [self showAlertTitle:@"Import Failed" message:@"Could not read the selected file."];
        return;
    }

    NSError *err;
    NSDictionary *parsed;
    NSString *ext = url.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"plist"]) {
        parsed = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&err];
    } else {
        parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    }

    if (![parsed isKindOfClass:[NSDictionary class]]) {
        [self showAlertTitle:@"Import Failed" message:err.localizedDescription ?: @"File did not contain a valid theme dictionary."];
        return;
    }

    NSString *themeName = url.lastPathComponent.stringByDeletingPathExtension;
    if (themeName.length == 0) themeName = [NSString stringWithFormat:@"Theme %@", @([[NSDate date] timeIntervalSince1970])];

    [[ThemeManager shared] saveTheme:parsed name:themeName];
    [[ThemeManager shared] setActiveTheme:themeName];
    [self reloadSavedThemes];
    [self showAlertTitle:@"Theme Loaded" message:[NSString stringWithFormat:@"\"%@\" has been imported and applied.", themeName]];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {}

#pragma mark - Wallpaper (Photos)

- (void)presentPhotoPicker {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[PHPickerFilter.imagesFilter, PHPickerFilter.videosFilter]];
    config.selectionLimit = 1;

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    PHPickerResult *result = results.firstObject;
    if (!result) return;

    NSItemProvider *provider = result.itemProvider;
    __weak typeof(self) weakSelf = self;

    if ([provider hasItemConformingToTypeIdentifier:@"public.mpeg-4"]) {
        [provider loadFileRepresentationForTypeIdentifier:@"public.mpeg-4" completionHandler:^(NSURL *url, NSError *error) {
            if (!url) return;
            NSError *saveErr;
            [[ThemeManager shared] saveWallpaperFromURL:url type:EeveeWallpaperTypeVideo error:&saveErr];
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView reloadData];
                [weakSelf showAlertTitle:@"Wallpaper Set" message:@"Video wallpaper applied."];
            });
        }];
    } else if ([provider hasItemConformingToTypeIdentifier:@"com.compuserve.gif"]) {
        [provider loadFileRepresentationForTypeIdentifier:@"com.compuserve.gif" completionHandler:^(NSURL *url, NSError *error) {
            if (!url) return;
            NSError *saveErr;
            [[ThemeManager shared] saveWallpaperFromURL:url type:EeveeWallpaperTypeGIF error:&saveErr];
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView reloadData];
                [weakSelf showAlertTitle:@"Wallpaper Set" message:@"GIF wallpaper applied."];
            });
        }];
    } else if ([provider canLoadObjectOfClass:[UIImage class]]) {
        [provider loadObjectOfClass:[UIImage class] completionHandler:^(UIImage *image, NSError *error) {
            if (!image) return;
            NSData *pngData = UIImagePNGRepresentation(image);
            NSURL *tempURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"eevee_temp_wallpaper.png"]];
            [pngData writeToURL:tempURL atomically:YES];
            NSError *saveErr;
            [[ThemeManager shared] saveWallpaperFromURL:tempURL type:EeveeWallpaperTypeImage error:&saveErr];
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView reloadData];
                [weakSelf showAlertTitle:@"Wallpaper Set" message:@"Image wallpaper applied."];
            });
        }];
    }
}

#pragma mark - Helpers

- (void)showAlertTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
