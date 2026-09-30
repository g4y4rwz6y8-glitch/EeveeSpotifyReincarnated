#import "ThemeSettingsViewController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <PhotosUI/PhotosUI.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

#if __has_include("SPTCustomThemeManager.h")
#import "SPTCustomThemeManager.h"
#else
// Fallback definitions only if SPTCustomThemeManager.h is not found
static NSString *const kEeveeThemeEnabledKey          = @"EeveeTheme_Enabled";
static NSString *const kEeveeThemeModeKey             = @"EeveeTheme_Mode"; // 0: None, 1: Color, 2: Image, 3: GIF, 4: Video
static NSString *const kEeveeThemeBlurEnabledKey      = @"EeveeTheme_BlurEnabled";
static NSString *const kEeveeThemeBlurStyleKey        = @"EeveeTheme_BlurStyle"; // 0: UltraThin, 1: Thin, 2: Regular, 3: Dark
static NSString *const kEeveeThemeOpacityKey          = @"EeveeTheme_Opacity"; // float 0.0 - 1.0
static NSString *const kEeveeThemeBlurAlphaKey        = @"EeveeTheme_BlurAlpha"; // float 0.0 - 1.0
static NSString *const kEeveeThemeHexColorKey         = @"EeveeTheme_HexColor";
static NSString *const kEeveeThemeExtensionKey        = @"EeveeTheme_MediaExtension";
static NSString *const kEeveeThemeMediaFileName       = @"custom_theme_media";
static NSString *const kEeveeThemeChangedNotification = @"SPTThemeSettingsChangedNotification";
static NSString *const kEeveeThemeReloadNotification  = @"EeveeThemeReloadNotification";
#endif

@interface ThemeSettingsViewController ()

@property (nonatomic, strong) UISwitch *masterSwitch;
@property (nonatomic, strong) UISegmentedControl *modeControl;
@property (nonatomic, strong) UISwitch *blurSwitch;
@property (nonatomic, strong) UISegmentedControl *blurStyleControl;
@property (nonatomic, strong) UISlider *opacitySlider;
@property (nonatomic, strong) UISlider *blurAlphaSlider;
@property (nonatomic, strong) UILabel *opacityValueLabel;
@property (nonatomic, strong) UILabel *blurAlphaValueLabel;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@end

@implementation ThemeSettingsViewController

#pragma mark - Storage & Directory Utilities

+ (NSString *)themeMediaDirectory {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *baseDir = paths.firstObject ?: NSTemporaryDirectory();
    NSString *themeDir = [baseDir stringByAppendingPathComponent:@"EeveeTheme"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:themeDir]) {
        [fileManager createDirectoryAtPath:themeDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return themeDir;
}

+ (NSString *)savedMediaPath {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *ext = [defaults stringForKey:kEeveeThemeExtensionKey] ?: @"dat";
    return [[self themeMediaDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", kEeveeThemeMediaFileName, ext]];
}

+ (void)removeSavedMediaFiles {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *themeDir = [self themeMediaDirectory];
    NSArray<NSString *> *contents = [fileManager contentsOfDirectoryAtPath:themeDir error:nil];
    for (NSString *file in contents) {
        if ([file hasPrefix:kEeveeThemeMediaFileName]) {
            NSString *filePath = [themeDir stringByAppendingPathComponent:file];
            [fileManager removeItemAtPath:filePath error:nil];
        }
    }
}

#pragma mark - View Controller Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Custom Theme";
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    
    [self setupNavigationItems];
    [self setupTableView];
    [self setupActivityIndicator];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)setupNavigationItems {
    if (self.navigationController) {
        self.navigationController.navigationBar.barTintColor = [UIColor blackColor];
        self.navigationController.navigationBar.translucent = NO;
        self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
        self.navigationController.navigationBar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
        };
    }
    
    UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneAction)];
    self.navigationItem.rightBarButtonItem = doneItem;
    
    UIBarButtonItem *resetItem = [[UIBarButtonItem alloc] initWithTitle:@"Reset" style:UIBarButtonItemStylePlain target:self action:@selector(resetThemeSettings)];
    self.navigationItem.leftBarButtonItem = resetItem;
}

- (void)setupTableView {
    UITableViewStyle style = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) {
        style = UITableViewStyleInsetGrouped;
    }
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:style];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    [self.view addSubview:self.tableView];
}

- (void)setupActivityIndicator {
    if (@available(iOS 13.0, *)) {
        self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    } else {
        self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    }
    self.activityIndicator.color = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
    self.activityIndicator.hidesWhenStopped = YES;
    self.activityIndicator.center = self.view.center;
    self.activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.activityIndicator];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1; // Master Switch
        case 1: return 2; // Media Mode, Select Media
        case 2: return 2; // Blur Toggle, Blur Style
        case 3: return 2; // Background Opacity, Blur Alpha
        case 4: return 2; // Apply, Clear Media
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"General";
        case 1: return @"Background Media";
        case 2: return @"Blur Overlay";
        case 3: return @"Transparency Controls";
        case 4: return @"Actions";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"Enable or disable custom background rendering across Spotify.";
    } else if (section == 1) {
        return @"Supports static images, animated GIFs, and looping MP4/MOV videos.";
    } else if (section == 4) {
        return @"Tap Apply to synchronize changes with active playback views.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *reuseID = [NSString stringWithFormat:@"ThemeCell_%ld_%ld", (long)indexPath.section, (long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseID];
        cell.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.textLabel.text = @"Enable Custom Theme";
        if (!self.masterSwitch) {
            self.masterSwitch = [[UISwitch alloc] init];
            self.masterSwitch.onTintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
            [self.masterSwitch addTarget:self action:@selector(masterSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        }
        self.masterSwitch.on = [defaults boolForKey:kEeveeThemeEnabledKey];
        cell.accessoryView = self.masterSwitch;
    }
    else if (indexPath.section == 1 && indexPath.row == 0) {
        cell.textLabel.text = @"Media Type";
        if (!self.modeControl) {
            NSArray *items = @[@"Color", @"Image", @"GIF", @"Video"];
            self.modeControl = [[UISegmentedControl alloc] initWithItems:items];
            if (@available(iOS 13.0, *)) {
                self.modeControl.selectedSegmentTintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
            }
            [self.modeControl addTarget:self action:@selector(modeControlChanged:) forControlEvents:UIControlEventValueChanged];
        }
        NSInteger currentMode = [defaults integerForKey:kEeveeThemeModeKey];
        if (currentMode >= 1 && currentMode <= 4) {
            self.modeControl.selectedSegmentIndex = currentMode - 1;
        } else {
            self.modeControl.selectedSegmentIndex = 1;
        }
        cell.accessoryView = self.modeControl;
    }
    else if (indexPath.section == 1 && indexPath.row == 1) {
        cell.textLabel.text = @"Choose Media from Library";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    else if (indexPath.section == 2 && indexPath.row == 0) {
        cell.textLabel.text = @"Enable Glass Blur";
        if (!self.blurSwitch) {
            self.blurSwitch = [[UISwitch alloc] init];
            self.blurSwitch.onTintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
            [self.blurSwitch addTarget:self action:@selector(blurSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        }
        self.blurSwitch.on = [defaults objectForKey:kEeveeThemeBlurEnabledKey] ? [defaults boolForKey:kEeveeThemeBlurEnabledKey] : YES;
        cell.accessoryView = self.blurSwitch;
    }
    else if (indexPath.section == 2 && indexPath.row == 1) {
        cell.textLabel.text = @"Blur Style";
        if (!self.blurStyleControl) {
            NSArray *styles = @[@"UltraThin", @"Thin", @"Regular", @"Dark"];
            self.blurStyleControl = [[UISegmentedControl alloc] initWithItems:styles];
            if (@available(iOS 13.0, *)) {
                self.blurStyleControl.selectedSegmentTintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
            }
            [self.blurStyleControl addTarget:self action:@selector(blurStyleControlChanged:) forControlEvents:UIControlEventValueChanged];
        }
        self.blurStyleControl.selectedSegmentIndex = [defaults integerForKey:kEeveeThemeBlurStyleKey];
        cell.accessoryView = self.blurStyleControl;
    }
    else if (indexPath.section == 3 && indexPath.row == 0) {
        cell.textLabel.text = @"Background Opacity";
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
        if (!self.opacitySlider) {
            self.opacitySlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 130, 30)];
            self.opacitySlider.minimumValue = 0.05f;
            self.opacitySlider.maximumValue = 1.0f;
            self.opacitySlider.minimumTrackTintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
            [self.opacitySlider addTarget:self action:@selector(opacitySliderChanged:) forControlEvents:UIControlEventValueChanged];
        }
        float op = [defaults objectForKey:kEeveeThemeOpacityKey] ? [defaults floatForKey:kEeveeThemeOpacityKey] : 0.85f;
        self.opacitySlider.value = op;
        [container addSubview:self.opacitySlider];
        
        if (!self.opacityValueLabel) {
            self.opacityValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(135, 0, 45, 30)];
            self.opacityValueLabel.textColor = [UIColor lightGrayColor];
            self.opacityValueLabel.font = [UIFont systemFontOfSize:13];
            self.opacityValueLabel.textAlignment = NSTextAlignmentRight;
        }
        self.opacityValueLabel.text = [NSString stringWithFormat:@"%.0f%%", op * 100];
        [container addSubview:self.opacityValueLabel];
        
        cell.accessoryView = container;
    }
    else if (indexPath.section == 3 && indexPath.row == 1) {
        cell.textLabel.text = @"Blur Alpha";
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
        if (!self.blurAlphaSlider) {
            self.blurAlphaSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 130, 30)];
            self.blurAlphaSlider.minimumValue = 0.0f;
            self.blurAlphaSlider.maximumValue = 1.0f;
            self.blurAlphaSlider.minimumTrackTintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
            [self.blurAlphaSlider addTarget:self action:@selector(blurAlphaSliderChanged:) forControlEvents:UIControlEventValueChanged];
        }
        float ba = [defaults objectForKey:kEeveeThemeBlurAlphaKey] ? [defaults floatForKey:kEeveeThemeBlurAlphaKey] : 0.70f;
        self.blurAlphaSlider.value = ba;
        [container addSubview:self.blurAlphaSlider];
        
        if (!self.blurAlphaValueLabel) {
            self.blurAlphaValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(135, 0, 45, 30)];
            self.blurAlphaValueLabel.textColor = [UIColor lightGrayColor];
            self.blurAlphaValueLabel.font = [UIFont systemFontOfSize:13];
            self.blurAlphaValueLabel.textAlignment = NSTextAlignmentRight;
        }
        self.blurAlphaValueLabel.text = [NSString stringWithFormat:@"%.0f%%", ba * 100];
        [container addSubview:self.blurAlphaValueLabel];
        
        cell.accessoryView = container;
    }
    else if (indexPath.section == 4 && indexPath.row == 0) {
        cell.textLabel.text = @"Apply Changes";
        cell.textLabel.textColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    else if (indexPath.section == 4 && indexPath.row == 1) {
        cell.textLabel.text = @"Clear Cached Media";
        cell.textLabel.textColor = [UIColor colorWithRed:0.95 green:0.25 blue:0.25 alpha:1.0];
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1 && indexPath.row == 1) {
        [self presentMediaPicker];
    } else if (indexPath.section == 4 && indexPath.row == 0) {
        [self applyThemeSettings];
    } else if (indexPath.section == 4 && indexPath.row == 1) {
        [self clearMediaAction];
    }
}

#pragma mark - Media Picker

- (void)presentMediaPicker {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        [self displayAlertWithTitle:@"Notice" message:@"Photo Library is unavailable."];
        return;
    }
    
    UIImagePickerController *pickerController = [[UIImagePickerController alloc] init];
    pickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    pickerController.delegate = self;
    pickerController.modalPresentationStyle = UIModalPresentationFullScreen;
    
    pickerController.mediaTypes = @[
        UTTypeImage.identifier,
        UTTypeGIF.identifier,
        UTTypeMovie.identifier,
        UTTypeVideo.identifier
    ];
    
    [self presentViewController:pickerController animated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    if (!mediaType) {
        return;
    }
    
    NSURL *mediaURL = info[UIImagePickerControllerMediaURL];
    NSURL *imageURL = info[UIImagePickerControllerImageURL];
    UIImage *originalImage = info[UIImagePickerControllerOriginalImage];
    
    BOOL isGIF = NO;
    BOOL isVideo = NO;
    BOOL isImage = NO;
    
    UTType *resolvedType = [UTType typeWithIdentifier:mediaType];
    if (!resolvedType) {
        NSURL *sourceURL = mediaURL ?: imageURL;
        if (sourceURL.pathExtension.length > 0) {
            resolvedType = [UTType typeWithFilenameExtension:sourceURL.pathExtension];
        }
    }
    
    if (resolvedType) {
        if ([resolvedType conformsToType:UTTypeGIF]) {
            isGIF = YES;
        } else if ([resolvedType conformsToType:UTTypeMovie] || [resolvedType conformsToType:UTTypeVideo]) {
            isVideo = YES;
        } else if ([resolvedType conformsToType:UTTypeImage]) {
            isImage = YES;
        }
    } else {
        NSString *typeLower = mediaType.lowercaseString;
        NSString *extLower = (mediaURL ?: imageURL).pathExtension.lowercaseString;
        if ([typeLower containsString:@"gif"] || [extLower isEqualToString:@"gif"]) {
            isGIF = YES;
        } else if ([typeLower containsString:@"movie"] || [typeLower containsString:@"video"] || [extLower isEqualToString:@"mp4"] || [extLower isEqualToString:@"mov"]) {
            isVideo = YES;
        } else {
            isImage = YES;
        }
    }
    
    if (isGIF) {
        [self processPickedGIFWithURL:(imageURL ?: mediaURL) fallbackImage:originalImage];
    } else if (isVideo) {
        [self processPickedVideoWithURL:mediaURL];
    } else if (isImage || originalImage) {
        [self processPickedImage:originalImage imageURL:imageURL];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Media Processing Handlers

- (void)processPickedGIFWithURL:(NSURL *)gifURL fallbackImage:(UIImage *)image {
    [self.activityIndicator startAnimating];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = nil;
        if (gifURL) {
            data = [NSData dataWithContentsOfURL:gifURL];
        }
        if (!data && image) {
            data = UIImagePNGRepresentation(image);
        }
        
        if (data && data.length > 0) {
            [ThemeSettingsViewController removeSavedMediaFiles];
            NSString *targetPath = [[ThemeSettingsViewController themeMediaDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.gif", kEeveeThemeMediaFileName]];
            [data writeToFile:targetPath atomically:YES];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setInteger:3 forKey:kEeveeThemeModeKey]; // 3: GIF
                [defaults setObject:@"gif" forKey:kEeveeThemeExtensionKey];
                [defaults synchronize];
                
                [self.activityIndicator stopAnimating];
                [self.tableView reloadData];
                [self applyThemeSettings];
                [self displayAlertWithTitle:@"Success" message:@"GIF background successfully updated."];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.activityIndicator stopAnimating];
                [self displayAlertWithTitle:@"Error" message:@"Failed to process GIF data."];
            });
        }
    });
}

- (void)processPickedVideoWithURL:(NSURL *)videoURL {
    if (!videoURL) {
        [self displayAlertWithTitle:@"Error" message:@"Invalid video path."];
        return;
    }
    
    [self.activityIndicator startAnimating];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *ext = videoURL.pathExtension.lowercaseString;
        if (ext.length == 0) {
            ext = @"mp4";
        }
        
        [ThemeSettingsViewController removeSavedMediaFiles];
        NSString *targetPath = [[ThemeSettingsViewController themeMediaDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", kEeveeThemeMediaFileName, ext]];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager removeItemAtPath:targetPath error:nil];
        
        NSError *error = nil;
        BOOL success = [fileManager copyItemAtURL:videoURL toURL:[NSURL fileURLWithPath:targetPath] error:&error];
        
        if (!success) {
            NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
            success = [videoData writeToFile:targetPath atomically:YES];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
            if (success) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setInteger:4 forKey:kEeveeThemeModeKey]; // 4: Video
                [defaults setObject:ext forKey:kEeveeThemeExtensionKey];
                [defaults synchronize];
                
                [self.tableView reloadData];
                [self applyThemeSettings];
                [self displayAlertWithTitle:@"Success" message:@"Video background successfully configured."];
            } else {
                [self displayAlertWithTitle:@"Error" message:@"Failed to save video media."];
            }
        });
    });
}

- (void)processPickedImage:(UIImage *)image imageURL:(NSURL *)imageURL {
    if (!image) {
        return;
    }
    
    [self.activityIndicator startAnimating];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *imageData = UIImageJPEGRepresentation(image, 0.90f);
        if (!imageData) {
            imageData = UIImagePNGRepresentation(image);
        }
        
        if (imageData && imageData.length > 0) {
            [ThemeSettingsViewController removeSavedMediaFiles];
            NSString *targetPath = [[ThemeSettingsViewController themeMediaDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", kEeveeThemeMediaFileName]];
            [imageData writeToFile:targetPath atomically:YES];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setInteger:2 forKey:kEeveeThemeModeKey]; // 2: Image
                [defaults setObject:@"png" forKey:kEeveeThemeExtensionKey];
                [defaults synchronize];
                
                [self.activityIndicator stopAnimating];
                [self.tableView reloadData];
                [self applyThemeSettings];
                [self displayAlertWithTitle:@"Success" message:@"Static background image applied."];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.activityIndicator stopAnimating];
                [self displayAlertWithTitle:@"Error" message:@"Failed to serialize selected image."];
            });
        }
    });
}

#pragma mark - Actions & Target Events

- (void)masterSwitchChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:kEeveeThemeEnabledKey];
    [defaults synchronize];
    [self applyThemeSettings];
}

- (void)modeControlChanged:(UISegmentedControl *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:(sender.selectedSegmentIndex + 1) forKey:kEeveeThemeModeKey];
    [defaults synchronize];
    [self applyThemeSettings];
}

- (void)blurSwitchChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:kEeveeThemeBlurEnabledKey];
    [defaults synchronize];
    [self applyThemeSettings];
}

- (void)blurStyleControlChanged:(UISegmentedControl *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:sender.selectedSegmentIndex forKey:kEeveeThemeBlurStyleKey];
    [defaults synchronize];
    [self applyThemeSettings];
}

- (void)opacitySliderChanged:(UISlider *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:sender.value forKey:kEeveeThemeOpacityKey];
    [defaults synchronize];
    if (self.opacityValueLabel) {
        self.opacityValueLabel.text = [NSString stringWithFormat:@"%.0f%%", sender.value * 100];
    }
}

- (void)blurAlphaSliderChanged:(UISlider *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:sender.value forKey:kEeveeThemeBlurAlphaKey];
    [defaults synchronize];
    if (self.blurAlphaValueLabel) {
        self.blurAlphaValueLabel.text = [NSString stringWithFormat:@"%.0f%%", sender.value * 100];
    }
}

- (void)clearMediaAction {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Clear Media" message:@"Do you want to remove the stored custom background media?" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [ThemeSettingsViewController removeSavedMediaFiles];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setInteger:0 forKey:kEeveeThemeModeKey];
        [defaults removeObjectForKey:kEeveeThemeExtensionKey];
        [defaults synchronize];
        [self.tableView reloadData];
        [self applyThemeSettings];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyThemeSettings {
    [[NSNotificationCenter defaultCenter] postNotificationName:kEeveeThemeChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kEeveeThemeReloadNotification object:nil];
    
    Class managerClass = NSClassFromString(@"SPTCustomThemeManager");
    if (managerClass && [managerClass respondsToSelector:@selector(sharedInstance)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id manager = [managerClass performSelector:@selector(sharedInstance)];
        if ([manager respondsToSelector:@selector(applyTheme)]) {
            [manager performSelector:@selector(applyTheme)];
        }
#pragma clang diagnostic pop
    }
}

- (void)resetThemeSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset All Settings" message:@"Reset all custom theme options to their default values?" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:kEeveeThemeEnabledKey];
        [defaults removeObjectForKey:kEeveeThemeModeKey];
        [defaults removeObjectForKey:kEeveeThemeBlurEnabledKey];
        [defaults removeObjectForKey:kEeveeThemeBlurStyleKey];
        [defaults removeObjectForKey:kEeveeThemeOpacityKey];
        [defaults removeObjectForKey:kEeveeThemeBlurAlphaKey];
        [defaults removeObjectForKey:kEeveeThemeHexColorKey];
        [defaults removeObjectForKey:kEeveeThemeExtensionKey];
        [defaults synchronize];
        
        [ThemeSettingsViewController removeSavedMediaFiles];
        [self.tableView reloadData];
        [self applyThemeSettings];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)doneAction {
    [self applyThemeSettings];
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)displayAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
