#import "ThemeSettingsViewController.h"
#import "ThemeManager.h"
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

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

    // Prefer PHAsset-backed results when available — gives us access to original files and proper handling of GIF/HEIC/Live Photos
    if (result.assetIdentifier) {
        PHAsset *asset = [PHAsset fetchAssetsWithLocalIdentifiers:@[result.assetIdentifier] options:nil].firstObject;
        if (!asset) return;

        if (asset.mediaType == PHAssetMediaTypeVideo) {
            PHVideoRequestOptions *vopts = [PHVideoRequestOptions new];
            vopts.networkAccessAllowed = YES;
            [[PHImageManager defaultManager] requestExportSessionForVideo:asset
                                                                   options:vopts
                                                               exportPreset:AVAssetExportPresetPassthrough
                                                            resultHandler:^(AVAssetExportSession *exportSession, NSDictionary *info) {
                if (!exportSession) return;

                NSString *tmpName = [NSTemporaryDirectory() stringByAppendingPathComponent:@"eevee_temp_wallpaper.mp4"];
                NSURL *outURL = [NSURL fileURLWithPath:tmpName];
                // Remove if exists
                [[NSFileManager defaultManager] removeItemAtURL:outURL error:nil];
                exportSession.outputURL = outURL;
                exportSession.outputFileType = AVFileTypeMPEG4;
                [exportSession exportAsynchronouslyWithCompletionHandler:^{
                    if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                        NSError *saveErr;
                        [[ThemeManager shared] saveWallpaperFromURL:outURL type:EeveeWallpaperTypeVideo error:&saveErr];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakSelf.tableView reloadData];
                            [weakSelf showAlertTitle:@"Wallpaper Set" message:@"Video wallpaper applied."];
                        });
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakSelf showAlertTitle:@"Error" message:@"Failed to export selected video."];
                        });
                    }
                }];
            }];
            return;
        }

        // Image (could be GIF/HEIC/JPEG)
        PHImageRequestOptions *opts = [PHImageRequestOptions new];
        opts.networkAccessAllowed = YES;
        opts.version = PHImageRequestOptionsVersionOriginal;
        [[PHImageManager defaultManager] requestImageDataForAsset:asset
                                                          options:opts
                                                    resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
            if (!imageData) return;

            BOOL isGIF = (dataUTI != nil && UTTypeConformsTo((__bridge CFStringRef)dataUTI, kUTTypeGIF));
            NSString *tmpName = isGIF ? @"eevee_temp_wallpaper.gif" : @"eevee_temp_wallpaper.png";
            NSURL *tmpURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:tmpName]];
            [imageData writeToURL:tmpURL atomically:YES];

            NSError *saveErr;
            [[ThemeManager shared] saveWallpaperFromURL:tmpURL type:(isGIF?EeveeWallpaperTypeGIF:EeveeWallpaperTypeImage) error:&saveErr];
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView reloadData];
                [weakSelf showAlertTitle:@"Wallpaper Set" message:(isGIF?@"GIF wallpaper applied.":@"Image wallpaper applied.")];
            });
        }];
        return;
    }

    // Fallback: inspect provided type identifiers and try to load the best match
    NSArray<NSString *> *types = provider.registeredTypeIdentifiers;
    NSString *chosenType = nil;
    EeveeWallpaperType chosenWallpaperType = EeveeWallpaperTypeImage;
    for (NSString *uti in types) {
        // video types
        if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeMovie) || UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeVideo) || [uti.lowercaseString containsString:@"mpeg-4"]) {
            chosenType = uti;
            chosenWallpaperType = EeveeWallpaperTypeVideo;
            break;
        }
        // gif
        if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeGIF) || [uti.lowercaseString containsString:@"gif"]) {
            chosenType = uti;
            chosenWallpaperType = EeveeWallpaperTypeGIF;
            break;
        }
        // generic image
        if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeImage)) {
            chosenType = uti;
            chosenWallpaperType = EeveeWallpaperTypeImage;
            break;
        }
    }

    if (chosenType) {
        [provider loadFileRepresentationForTypeIdentifier:chosenType completionHandler:^(NSURL *url, NSError *error) {
            if (!url) return;

            // The provided URL may be in a temporary location or be security-scoped; copy to our own temp file
            NSString *ext = chosenWallpaperType == EeveeWallpaperTypeVideo ? @"mp4" : (chosenWallpaperType == EeveeWallpaperTypeGIF ? @"gif" : @"png");
            NSURL *tmpURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[@"eevee_temp_wallpaper" stringByAppendingPathExtension:ext]]];
            // Remove any existing
            [[NSFileManager defaultManager] removeItemAtURL:tmpURL error:nil];

            BOOL started = NO;
            if ([url respondsToSelector:@selector(startAccessingSecurityScopedResource)]) {
                started = [url startAccessingSecurityScopedResource];
            }

            NSError *copyErr = nil;
            BOOL ok = [[NSFileManager defaultManager] copyItemAtURL:url toURL:tmpURL error:&copyErr];
            if (!ok) {
                // As a fallback, try reading data and writing
                NSData *d = [NSData dataWithContentsOfURL:url options:0 error:&copyErr];
                if (d) {
                    [d writeToURL:tmpURL options:NSDataWritingAtomic error:&copyErr];
                }
            }

            if (started) { [url stopAccessingSecurityScopedResource]; }

            if (![[NSFileManager defaultManager] fileExistsAtPath:tmpURL.path]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf showAlertTitle:@"Error" message:@"Failed to obtain the selected file."];
                });
                return;
            }

            NSError *saveErr;
            [[ThemeManager shared] saveWallpaperFromURL:tmpURL type:chosenWallpaperType error:&saveErr];
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView reloadData];
                NSString *msg = (chosenWallpaperType == EeveeWallpaperTypeVideo) ? @"Video wallpaper applied." : (chosenWallpaperType == EeveeWallpaperTypeGIF) ? @"GIF wallpaper applied." : @"Image wallpaper applied.";
                [weakSelf showAlertTitle:@"Wallpaper Set" message:msg];
            });
        }];
        return;
    }

    // Last resort: try loading UIImage
    if ([provider canLoadObjectOfClass:[UIImage class]]) {
        [provider loadObjectOfClass:[UIImage class] completionHandler:^(UIImage *image, NSError *error) {
            if (!image) return;
            NSData *imgData = UIImagePNGRepresentation(image);
            if (!imgData) imgData = UIImageJPEGRepresentation(image, 0.9);
            if (!imgData) return;

            NSURL *tempURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"eevee_temp_wallpaper.png"]];
            [imgData writeToURL:tempURL atomically:YES];
            NSError *saveErr;
            [[ThemeManager shared] saveWallpaperFromURL:tempURL type:EeveeWallpaperTypeImage error:&saveErr];
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView reloadData];
                [weakSelf showAlertTitle:@"Wallpaper Set" message:@"Image wallpaper applied."];
            });
        }];
        return;
    }

    // If we get here, we couldn't handle the picked item
    [self showAlertTitle:@"Unsupported" message:@"The selected item type is not supported."];
}

#pragma mark - Helpers

- (void)showAlertTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
