#import "ThemeSettingsViewController.h"
#import "SPTCustomThemeManager.h"
#import "SPTImageRenderer.h"
#import "SPTGifRenderer.h"
#import "SPTVideoRenderer.h"
#import "SPTFloatingActionButton.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <PhotosUI/PhotosUI.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

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
@property (nonatomic, strong) UIView *previewContainer;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UIVisualEffectView *previewBlurView;
@property (nonatomic, strong) UIImpactFeedbackGenerator *hapticFeedback;

@end

@implementation ThemeSettingsViewController

#pragma mark - Directory & Storage

+ (NSString *)themeMediaDirectory {
    return [SPTCustomThemeManager themeMediaDirectory];
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

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Eevee Theme Studio";
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.07 alpha:1.0];
    
    self.hapticFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [self.hapticFeedback prepare];
    
    [self setupNavigationItems];
    [self setupHeaderPreview];
    [self setupTableView];
    [self setupActivityIndicator];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[SPTFloatingActionButton sharedInstance] setFloatingAlpha:1.0 animated:YES];
}

- (void)setupNavigationItems {
    if (self.navigationController) {
        self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.09 alpha:0.95];
        self.navigationController.navigationBar.translucent = YES;
        self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
        self.navigationController.navigationBar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
        };
    }
    
    UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(doneAction)];
    self.navigationItem.rightBarButtonItem = doneItem;
    
    UIBarButtonItem *resetItem = [[UIBarButtonItem alloc] initWithTitle:@"Reset" style:UIBarButtonItemStylePlain target:self action:@selector(resetThemeSettings)];
    resetItem.tintColor = [UIColor colorWithRed:0.95 green:0.35 blue:0.35 alpha:1.0];
    self.navigationItem.leftBarButtonItem = resetItem;
}

- (void)setupHeaderPreview {
    CGFloat previewHeight = 150.0f;
    CGRect previewFrame = CGRectMake(16, 12, self.view.bounds.size.width - 32, previewHeight);
    
    self.previewContainer = [[UIView alloc] initWithFrame:previewFrame];
    self.previewContainer.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
    self.previewContainer.layer.cornerRadius = 16.0f;
    self.previewContainer.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    self.previewContainer.layer.borderWidth = 1.0f;
    self.previewContainer.clipsToBounds = YES;
    
    self.previewImageView = [[UIImageView alloc] initWithFrame:self.previewContainer.bounds];
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.previewImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.previewImageView.clipsToBounds = YES;
    [self.previewContainer addSubview:self.previewImageView];
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.previewBlurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.previewBlurView.frame = self.previewContainer.bounds;
    self.previewBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.previewContainer addSubview:self.previewBlurView];
    
    UILabel *badgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 12, 110, 24)];
    badgeLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
    badgeLabel.layer.cornerRadius = 12.0f;
    badgeLabel.clipsToBounds = YES;
    badgeLabel.text = @"LIVE PREVIEW";
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    badgeLabel.font = [UIFont boldSystemFontOfSize:10];
    badgeLabel.textColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
    [self.previewContainer addSubview:badgeLabel];
    
    UIView *tableHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, previewHeight + 24)];
    [tableHeader addSubview:self.previewContainer];
    
    [self updatePreviewDisplay];
    self.tableView.tableHeaderView = tableHeader;
}

- (void)setupTableView {
    UITableViewStyle style = UITableViewStyleInsetGrouped;
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:style];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.07 alpha:1.0];
    self.tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    [self setupHeaderPreview];
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

- (void)updatePreviewDisplay {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    UIImage *img = [SPTImageRenderer loadSavedImage];
    self.previewImageView.image = img;
    
    BOOL blurOn = [defaults objectForKey:kEeveeThemeBlurEnabledKey] ? [defaults boolForKey:kEeveeThemeBlurEnabledKey] : YES;
    float blurAlpha = [defaults objectForKey:kEeveeThemeBlurAlphaKey] ? [defaults floatForKey:kEeveeThemeBlurAlphaKey] : 0.65f;
    NSInteger blurStyle = [defaults integerForKey:kEeveeThemeBlurStyleKey];
    
    if (blurOn) {
        UIBlurEffectStyle style = UIBlurEffectStyleDark;
        if (@available(iOS 13.0, *)) {
            switch (blurStyle) {
                case 0: style = UIBlurEffectStyleSystemUltraThinMaterialDark; break;
                case 1: style = UIBlurEffectStyleSystemThinMaterialDark; break;
                case 2: style = UIBlurEffectStyleDark; break;
                case 3: style = UIBlurEffectStyleRegular; break;
                default: style = UIBlurEffectStyleDark; break;
            }
        }
        self.previewBlurView.effect = [UIBlurEffect effectWithStyle:style];
        self.previewBlurView.alpha = blurAlpha;
        self.previewBlurView.hidden = NO;
    } else {
        self.previewBlurView.hidden = YES;
    }
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1; // Master Switch
        case 1: return 2; // Media Mode, Choose Media
        case 2: return 4; // Blur Switch, Style, Opacity, Blur Alpha
        case 3: return 2; // Apply, Clear Cache
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Master Switch";
        case 1: return @"Media Background";
        case 2: return @"Glassmorphism & Overlay";
        case 3: return @"Engine Actions";
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *reuseID = [NSString stringWithFormat:@"ThemeCell_%ld_%ld", (long)indexPath.section, (long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseID];
        cell.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.13 alpha:0.95];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.textLabel.text = @"Activate Custom Theme";
        if (!self.masterSwitch) {
            self.masterSwitch = [[UISwitch alloc] init];
            self.masterSwitch.onTintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
            [self.masterSwitch addTarget:self action:@selector(masterSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        }
        self.masterSwitch.on = [defaults boolForKey:kEeveeThemeEnabledKey];
        cell.accessoryView = self.masterSwitch;
    } else if (indexPath.section == 1 && indexPath.row == 0) {
        cell.textLabel.text = @"Media Engine";
        if (!self.modeControl) {
            NSArray *items = @[@"Image", @"GIF", @"Video"];
            self.modeControl = [[UISegmentedControl alloc] initWithItems:items];
            if (@available(iOS 13.0, *)) {
                self.modeControl.selectedSegmentTintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
                [self.modeControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor], NSFontAttributeName: [UIFont boldSystemFontOfSize:12]} forState:UIControlStateSelected];
                [self.modeControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont systemFontOfSize:12]} forState:UIControlStateNormal];
            }
            [self.modeControl addTarget:self action:@selector(modeControlChanged:) forControlEvents:UIControlEventValueChanged];
        }
        NSInteger currentMode = [defaults integerForKey:kEeveeThemeModeKey];
        if (currentMode >= 2 && currentMode <= 4) {
            self.modeControl.selectedSegmentIndex = currentMode - 2;
        } else {
            self.modeControl.selectedSegmentIndex = 0;
        }
        cell.accessoryView = self.modeControl;
    } else if (indexPath.section == 1 && indexPath.row == 1) {
        cell.textLabel.text = @"Choose Media from Photos";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else if (indexPath.section == 2 && indexPath.row == 0) {
        cell.textLabel.text = @"Enable Glass Blur";
        if (!self.blurSwitch) {
            self.blurSwitch = [[UISwitch alloc] init];
            self.blurSwitch.onTintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
            [self.blurSwitch addTarget:self action:@selector(blurSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        }
        self.blurSwitch.on = [defaults objectForKey:kEeveeThemeBlurEnabledKey] ? [defaults boolForKey:kEeveeThemeBlurEnabledKey] : YES;
        cell.accessoryView = self.blurSwitch;
    } else if (indexPath.section == 2 && indexPath.row == 1) {
        cell.textLabel.text = @"Glass Style";
        if (!self.blurStyleControl) {
            NSArray *styles = @[@"UltraThin", @"Thin", @"Dark", @"Regular"];
            self.blurStyleControl = [[UISegmentedControl alloc] initWithItems:styles];
            if (@available(iOS 13.0, *)) {
                self.blurStyleControl.selectedSegmentTintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
                [self.blurStyleControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor], NSFontAttributeName: [UIFont boldSystemFontOfSize:11]} forState:UIControlStateSelected];
                [self.blurStyleControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont systemFontOfSize:11]} forState:UIControlStateNormal];
            }
            [self.blurStyleControl addTarget:self action:@selector(blurStyleControlChanged:) forControlEvents:UIControlEventValueChanged];
        }
        self.blurStyleControl.selectedSegmentIndex = [defaults integerForKey:kEeveeThemeBlurStyleKey];
        cell.accessoryView = self.blurStyleControl;
    } else if (indexPath.section == 2 && indexPath.row == 2) {
        cell.textLabel.text = @"Background Lightness";
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
        if (!self.opacitySlider) {
            self.opacitySlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 125, 30)];
            self.opacitySlider.minimumValue = 0.10f;
            self.opacitySlider.maximumValue = 1.0f;
            self.opacitySlider.minimumTrackTintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
            [self.opacitySlider addTarget:self action:@selector(opacitySliderChanged:) forControlEvents:UIControlEventValueChanged];
        }
        float op = [defaults objectForKey:kEeveeThemeOpacityKey] ? [defaults floatForKey:kEeveeThemeOpacityKey] : 0.85f;
        self.opacitySlider.value = op;
        [container addSubview:self.opacitySlider];
        
        if (!self.opacityValueLabel) {
            self.opacityValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(130, 0, 50, 30)];
            self.opacityValueLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
            self.opacityValueLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            self.opacityValueLabel.textAlignment = NSTextAlignmentRight;
        }
        self.opacityValueLabel.text = [NSString stringWithFormat:@"%.0f%%", op * 100];
        [container addSubview:self.opacityValueLabel];
        cell.accessoryView = container;
    } else if (indexPath.section == 2 && indexPath.row == 3) {
        cell.textLabel.text = @"Blur Intensity";
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
        if (!self.blurAlphaSlider) {
            self.blurAlphaSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 125, 30)];
            self.blurAlphaSlider.minimumValue = 0.0f;
            self.blurAlphaSlider.maximumValue = 1.0f;
            self.blurAlphaSlider.minimumTrackTintColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
            [self.blurAlphaSlider addTarget:self action:@selector(blurAlphaSliderChanged:) forControlEvents:UIControlEventValueChanged];
        }
        float ba = [defaults objectForKey:kEeveeThemeBlurAlphaKey] ? [defaults floatForKey:kEeveeThemeBlurAlphaKey] : 0.65f;
        self.blurAlphaSlider.value = ba;
        [container addSubview:self.blurAlphaSlider];
        
        if (!self.blurAlphaValueLabel) {
            self.blurAlphaValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(130, 0, 50, 30)];
            self.blurAlphaValueLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
            self.blurAlphaValueLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            self.blurAlphaValueLabel.textAlignment = NSTextAlignmentRight;
        }
        self.blurAlphaValueLabel.text = [NSString stringWithFormat:@"%.0f%%", ba * 100];
        [container addSubview:self.blurAlphaValueLabel];
        cell.accessoryView = container;
    } else if (indexPath.section == 3 && indexPath.row == 0) {
        cell.textLabel.text = @"Apply Changes";
        cell.textLabel.textColor = [UIColor colorWithRed:0.118 green:0.843 blue:0.376 alpha:1.0];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else if (indexPath.section == 3 && indexPath.row == 1) {
        cell.textLabel.text = @"Clear Cached Media";
        cell.textLabel.textColor = [UIColor colorWithRed:0.95 green:0.30 blue:0.30 alpha:1.0];
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    
    return cell;
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1 && indexPath.row == 1) {
        [self presentMediaPicker];
    } else if (indexPath.section == 3 && indexPath.row == 0) {
        [self.hapticFeedback impactOccurred];
        [self applyThemeSettings];
    } else if (indexPath.section == 3 && indexPath.row == 1) {
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
    if (!mediaType) return;
    
    NSURL *mediaURL = info[UIImagePickerControllerMediaURL];
    NSURL *imageURL = info[UIImagePickerControllerImageURL];
    UIImage *originalImage = info[UIImagePickerControllerOriginalImage];
    
    UTType *resolvedType = [UTType typeWithIdentifier:mediaType];
    if (!resolvedType) {
        NSURL *sourceURL = mediaURL ?: imageURL;
        if (sourceURL.pathExtension.length > 0) {
            resolvedType = [UTType typeWithFilenameExtension:sourceURL.pathExtension];
        }
    }
    
    BOOL isGIF = NO;
    BOOL isVideo = NO;
    
    if (resolvedType) {
        if ([resolvedType conformsToType:UTTypeGIF]) isGIF = YES;
        else if ([resolvedType conformsToType:UTTypeMovie] || [resolvedType conformsToType:UTTypeVideo]) isVideo = YES;
    } else {
        NSString *typeLower = mediaType.lowercaseString;
        NSString *extLower = (mediaURL ?: imageURL).pathExtension.lowercaseString;
        if ([typeLower containsString:@"gif"] || [extLower isEqualToString:@"gif"]) isGIF = YES;
        else if ([typeLower containsString:@"movie"] || [typeLower containsString:@"video"] || [extLower isEqualToString:@"mp4"] || [extLower isEqualToString:@"mov"]) isVideo = YES;
    }
    
    if (isGIF) {
        [self processPickedGIFWithURL:(imageURL ?: mediaURL) fallbackImage:originalImage];
    } else if (isVideo) {
        [self processPickedVideoWithURL:mediaURL];
    } else {
        [self processPickedImage:originalImage imageURL:imageURL];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Process Media

- (void)processPickedGIFWithURL:(NSURL *)gifURL fallbackImage:(UIImage *)image {
    [self.activityIndicator startAnimating];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = gifURL ? [NSData dataWithContentsOfURL:gifURL] : nil;
        if (!data && image) data = UIImagePNGRepresentation(image);
        
        if (data && data.length > 0) {
            [ThemeSettingsViewController removeSavedMediaFiles];
            NSString *targetPath = [[ThemeSettingsViewController themeMediaDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.gif", kEeveeThemeMediaFileName]];
            [data writeToFile:targetPath atomically:YES];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setInteger:EeveeThemeModeGIF forKey:kEeveeThemeModeKey];
                [defaults setObject:@"gif" forKey:kEeveeThemeExtensionKey];
                [defaults setBool:YES forKey:kEeveeThemeEnabledKey];
                [defaults synchronize];
                
                [self.activityIndicator stopAnimating];
                [self updatePreviewDisplay];
                [self.tableView reloadData];
                [self applyThemeSettings];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.activityIndicator stopAnimating];
                [self displayAlertWithTitle:@"Error" message:@"Failed to process GIF file."];
            });
        }
    });
}

- (void)processPickedVideoWithURL:(NSURL *)videoURL {
    if (!videoURL) return;
    
    [self.activityIndicator startAnimating];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *ext = videoURL.pathExtension.lowercaseString;
        if (ext.length == 0) ext = @"mp4";
        
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
                [defaults setInteger:EeveeThemeModeVideo forKey:kEeveeThemeModeKey];
                [defaults setObject:ext forKey:kEeveeThemeExtensionKey];
                [defaults setBool:YES forKey:kEeveeThemeEnabledKey];
                [defaults synchronize];
                
                [self updatePreviewDisplay];
                [self.tableView reloadData];
                [self applyThemeSettings];
            } else {
                [self displayAlertWithTitle:@"Error" message:@"Failed to save video media."];
            }
        });
    });
}

- (void)processPickedImage:(UIImage *)image imageURL:(NSURL *)imageURL {
    if (!image) return;
    
    [self.activityIndicator startAnimating];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *imageData = UIImageJPEGRepresentation(image, 0.92f) ?: UIImagePNGRepresentation(image);
        if (imageData && imageData.length > 0) {
            [ThemeSettingsViewController removeSavedMediaFiles];
            NSString *targetPath = [[ThemeSettingsViewController themeMediaDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", kEeveeThemeMediaFileName]];
            [imageData writeToFile:targetPath atomically:YES];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setInteger:EeveeThemeModeImage forKey:kEeveeThemeModeKey];
                [defaults setObject:@"png" forKey:kEeveeThemeExtensionKey];
                [defaults setBool:YES forKey:kEeveeThemeEnabledKey];
                [defaults synchronize];
                
                [self.activityIndicator stopAnimating];
                [self updatePreviewDisplay];
                [self.tableView reloadData];
                [self applyThemeSettings];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.activityIndicator stopAnimating];
                [self displayAlertWithTitle:@"Error" message:@"Failed to serialize image."];
            });
        }
    });
}

#pragma mark - Actions

- (void)masterSwitchChanged:(UISwitch *)sender {
    [self.hapticFeedback impactOccurred];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:kEeveeThemeEnabledKey];
    [defaults synchronize];
    [self applyThemeSettings];
}

- (void)modeControlChanged:(UISegmentedControl *)sender {
    [self.hapticFeedback impactOccurred];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:(sender.selectedSegmentIndex + 2) forKey:kEeveeThemeModeKey];
    [defaults synchronize];
    [self applyThemeSettings];
}

- (void)blurSwitchChanged:(UISwitch *)sender {
    [self.hapticFeedback impactOccurred];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:kEeveeThemeBlurEnabledKey];
    [defaults synchronize];
    [self updatePreviewDisplay];
    [self applyThemeSettings];
}

- (void)blurStyleControlChanged:(UISegmentedControl *)sender {
    [self.hapticFeedback impactOccurred];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:sender.selectedSegmentIndex forKey:kEeveeThemeBlurStyleKey];
    [defaults synchronize];
    [self updatePreviewDisplay];
    [self applyThemeSettings];
}

- (void)opacitySliderChanged:(UISlider *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:sender.value forKey:kEeveeThemeOpacityKey];
    [defaults synchronize];
    self.opacityValueLabel.text = [NSString stringWithFormat:@"%.0f%%", sender.value * 100];
    [self applyThemeSettings];
}

- (void)blurAlphaSliderChanged:(UISlider *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:sender.value forKey:kEeveeThemeBlurAlphaKey];
    [defaults synchronize];
    self.blurAlphaValueLabel.text = [NSString stringWithFormat:@"%.0f%%", sender.value * 100];
    [self updatePreviewDisplay];
    [self applyThemeSettings];
}

- (void)clearMediaAction {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Clear Media" message:@"Remove saved background media?" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [ThemeSettingsViewController removeSavedMediaFiles];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setInteger:0 forKey:kEeveeThemeModeKey];
        [defaults removeObjectForKey:kEeveeThemeExtensionKey];
        [defaults synchronize];
        [self updatePreviewDisplay];
        [self.tableView reloadData];
        [self applyThemeSettings];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyThemeSettings {
    [[NSNotificationCenter defaultCenter] postNotificationName:kEeveeThemeChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kEeveeThemeReloadNotification object:nil];
    [[SPTCustomThemeManager sharedInstance] applyTheme];
}

- (void)resetThemeSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset" message:@"Restore default theme options?" preferredStyle:UIAlertControllerStyleAlert];
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
        [self updatePreviewDisplay];
        [self.tableView reloadData];
        [self applyThemeSettings];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)doneAction {
    [self applyThemeSettings];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)displayAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
