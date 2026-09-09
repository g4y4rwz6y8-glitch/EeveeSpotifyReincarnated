#import "SPTSettingsViewController.h"
#import "SPTCustomThemeManager.h"
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface SPTOpaqueContainerView : UIView
@end
@implementation SPTOpaqueContainerView
@end

@interface SPTSettingsViewController () <PHPickerViewControllerDelegate>

@property (nonatomic, strong) UISwitch *enabledSwitch;
@property (nonatomic, strong) UISegmentedControl *typeControl;
@property (nonatomic, strong) UIButton *chooseFileButton;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, assign) SPTWallpaperType pendingType;
@property (nonatomic, strong) UIVisualEffectView *cardBackgroundView;

@end

@implementation SPTSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Custom Theme";
    self.view.backgroundColor = [UIColor clearColor];

    [self buildUI];
    [self syncUIWithManagerState];
}

#pragma mark - UI construction

- (void)buildUI {
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                  target:self
                                                                                  action:@selector(dismissTapped)];
    self.navigationItem.rightBarButtonItem = doneButton;

    SPTOpaqueContainerView *card = [[SPTOpaqueContainerView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.layer.cornerRadius = 20;
    card.clipsToBounds = YES;
    card.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.85];
    [self.view addSubview:card];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark];
    self.cardBackgroundView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.cardBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:self.cardBackgroundView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.cardBackgroundView.topAnchor constraintEqualToAnchor:card.topAnchor],
        [self.cardBackgroundView.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [self.cardBackgroundView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [self.cardBackgroundView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
    ]];

    UILabel *enabledLabel = [self labelWithText:@"Enable Custom Theme"];
    self.enabledSwitch = [[UISwitch alloc] init];
    [self.enabledSwitch addTarget:self action:@selector(enabledChanged:) forControlEvents:UIControlEventValueChanged];
    UIStackView *enabledRow = [self rowWithViews:@[enabledLabel, self.enabledSwitch]];

    self.typeControl = [[UISegmentedControl alloc] initWithItems:@[@"Image", @"GIF", @"Video"]];
    [self.typeControl addTarget:self action:@selector(typeChanged:) forControlEvents:UIControlEventValueChanged];

    self.previewImageView = [[UIImageView alloc] init];
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.previewImageView.clipsToBounds = YES;
    self.previewImageView.layer.cornerRadius = 12;
    self.previewImageView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2];
    self.previewImageView.translatesAutoresizingMaskIntoConstraints = NO;

    self.chooseFileButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.chooseFileButton setTitle:@"Choose Wallpaper" forState:UIControlStateNormal];
    [self.chooseFileButton addTarget:self action:@selector(chooseFileTapped) forControlEvents:UIControlEventTouchUpInside];

    self.resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.resetButton setTitle:@"Reset to Default" forState:UIControlStateNormal];
    self.resetButton.tintColor = [UIColor systemRedColor];
    [self.resetButton addTarget:self action:@selector(resetTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        enabledRow, self.typeControl, self.previewImageView, self.chooseFileButton, self.resetButton
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [card.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],

        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:24],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-24],

        [self.previewImageView.heightAnchor constraintEqualToConstant:180],
    ]];
}

- (UILabel *)labelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    label.textColor = [UIColor whiteColor];
    return label;
}

- (UIStackView *)rowWithViews:(NSArray<UIView *> *)views {
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:views];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionEqualSpacing;
    row.alignment = UIStackViewAlignmentCenter;
    return row;
}

#pragma mark - State sync

- (void)syncUIWithManagerState {
    SPTCustomThemeManager *manager = [SPTCustomThemeManager sharedManager];
    self.enabledSwitch.on = manager.themeEnabled;
    self.pendingType = manager.currentType == SPTWallpaperTypeNone ? SPTWallpaperTypeImage : manager.currentType;
    self.typeControl.selectedSegmentIndex = self.pendingType - 1;

    if (manager.activeRenderer) {
        self.previewImageView.image = [self snapshotOfRenderView:manager.activeRenderer.renderView];
    } else {
        self.previewImageView.image = nil;
    }
}

- (UIImage *)snapshotOfRenderView:(UIView *)view {
    if (view.bounds.size.width == 0 || view.bounds.size.height == 0) return nil;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:view.bounds.size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:NO];
    }];
}

#pragma mark - Actions

- (void)dismissTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)enabledChanged:(UISwitch *)sender {
    CFPreferencesSetAppValue(CFSTR("SPTCustomThemeEnabled"),
                              sender.on ? kCFBooleanTrue : kCFBooleanFalse,
                              CFSTR("com.yourdomain.spotifytheme"));
    CFPreferencesAppSynchronize(CFSTR("com.yourdomain.spotifytheme"));
    [[SPTCustomThemeManager sharedManager] reloadPreferences];
}

- (void)typeChanged:(UISegmentedControl *)sender {
    self.pendingType = (SPTWallpaperType)(sender.selectedSegmentIndex + 1);
}

- (void)chooseFileTapped {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = 1;

    switch (self.pendingType) {
        case SPTWallpaperTypeVideo:
            config.filter = [PHPickerFilter videosFilter];
            break;
        case SPTWallpaperTypeGif:
            config.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[[PHPickerFilter imagesFilter]]];
            break;
        case SPTWallpaperTypeImage:
        default:
            config.filter = [PHPickerFilter imagesFilter];
            break;
    }

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)resetTapped {
    [[SPTCustomThemeManager sharedManager] resetWallpaper];
    self.previewImageView.image = nil;
}

#pragma mark - PHPickerViewControllerDelegate

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;

    NSItemProvider *provider = results.firstObject.itemProvider;
    SPTWallpaperType type = self.pendingType;

    if (type == SPTWallpaperTypeVideo) {
        [self handleVideoProvider:provider];
        return;
    }

    NSString *typeIdentifier = type == SPTWallpaperTypeGif
        ? (NSString *)UTTypeGIF.identifier
        : (NSString *)UTTypeImage.identifier;

    if (![provider hasItemConformingToTypeIdentifier:typeIdentifier] && type == SPTWallpaperTypeGif) {
        type = SPTWallpaperTypeImage;
        typeIdentifier = (NSString *)UTTypeImage.identifier;
    }

    [provider loadDataRepresentationForTypeIdentifier:typeIdentifier completionHandler:^(NSData *data, NSError *error) {
        if (!data) return;
        NSURL *tempURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSUUID UUID].UUIDString]];
        [data writeToURL:tempURL atomically:YES];

        dispatch_async(dispatch_get_main_queue(), ^{
            [[SPTCustomThemeManager sharedManager] setWallpaperFileURL:tempURL type:type];
            [self syncUIWithManagerState];
        });
    }];
}

- (void)handleVideoProvider:(NSItemProvider *)provider {
    NSString *movieType = (NSString *)UTTypeMovie.identifier;
    if (![provider hasItemConformingToTypeIdentifier:movieType]) return;

    [provider loadInPlaceFileRepresentationForTypeIdentifier:movieType completionHandler:
        ^(NSURL *fileURL, BOOL isInPlace, NSError *error) {
        if (!fileURL) return;

        NSURL *destURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
            [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"mp4"]]];

        NSError *copyError;
        [[NSFileManager defaultManager] copyItemAtURL:fileURL toURL:destURL error:&copyError];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!copyError) {
                [[SPTCustomThemeManager sharedManager] setWallpaperFileURL:destURL type:SPTWallpaperTypeVideo];
                [self syncUIWithManagerState];
            }
        });
    }];
}

@end
