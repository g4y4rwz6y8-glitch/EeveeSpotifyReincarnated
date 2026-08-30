#import "ThemeManager.h"

NSString * const EeveeThemeDidChangeNotification = @"EeveeThemeDidChangeNotification";

static NSString * const kThemeEnabledDefaultsKey = @"com.eevee.themeengine.enabled";
static NSString * const kActiveThemeNameDefaultsKey = @"com.eevee.themeengine.activeThemeName";
static NSString * const kWallpaperTypeDefaultsKey = @"com.eevee.themeengine.wallpaperType";
static NSString * const kThemesFolderName = @"EeveeThemes";
static NSString * const kWallpaperFileName = @"eevee_wallpaper";

@interface ThemeManager ()
@property (nonatomic, strong, readwrite) NSString *activeThemeName;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *currentThemeDict;
@end

@implementation ThemeManager

+ (instancetype)shared {
    static ThemeManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [ThemeManager new];
        instance.themeEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kThemeEnabledDefaultsKey];
        NSString *savedActive = [[NSUserDefaults standardUserDefaults] stringForKey:kActiveThemeNameDefaultsKey];
        instance.activeThemeName = savedActive ?: @"";
        if (instance.activeThemeName.length > 0) {
            [instance loadDictForThemeNamed:instance.activeThemeName];
        }
    });
    return instance;
}

#pragma mark - Paths

- (NSURL *)documentsDirectory {
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                      inDomains:NSUserDomainMask];
    return urls.firstObject;
}

- (NSURL *)themesDirectory {
    NSURL *dir = [[self documentsDirectory] URLByAppendingPathComponent:kThemesFolderName isDirectory:YES];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir.path]) {
        [[NSFileManager defaultManager] createDirectoryAtURL:dir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }
    return dir;
}

- (NSURL *)urlForThemeNamed:(NSString *)name {
    NSString *safeName = [self sanitizedFileNameFor:name];
    return [[self themesDirectory] URLByAppendingPathComponent:[safeName stringByAppendingPathExtension:@"json"]];
}

- (NSString *)sanitizedFileNameFor:(NSString *)name {
    NSCharacterSet *illegal = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"];
    return [[name componentsSeparatedByCharactersInSet:illegal] componentsJoinedByString:@"_"];
}

#pragma mark - Enable / Disable

- (void)setThemeEnabled:(BOOL)themeEnabled {
    _themeEnabled = themeEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:themeEnabled forKey:kThemeEnabledDefaultsKey];
    [self notifyThemeChanged];
}

#pragma mark - Saved themes

- (NSArray<NSString *> *)allSavedThemes {
    NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self themesDirectory]
                                                              includingPropertiesForKeys:nil
                                                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                   error:nil];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSURL *file in files) {
        if ([file.pathExtension.lowercaseString isEqualToString:@"json"]) {
            [names addObject:file.lastPathComponent.stringByDeletingPathExtension];
        }
    }
    return [names sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (void)saveTheme:(NSDictionary *)dict name:(NSString *)name {
    if (![dict isKindOfClass:[NSDictionary class]] || name.length == 0) return;

    NSError *err;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&err];
    if (!jsonData) {
        NSLog(@"[ThemeEngine] Failed to serialize theme '%@': %@", name, err);
        return;
    }

    NSURL *url = [self urlForThemeNamed:name];
    NSError *writeErr;
    BOOL wrote = [jsonData writeToURL:url options:NSDataWritingAtomic error:&writeErr];
    if (!wrote) {
        NSLog(@"[ThemeEngine] Failed to write theme '%@': %@", name, writeErr);
    }
}

- (void)deleteTheme:(NSString *)name {
    if (name.length == 0) return;

    NSURL *url = [self urlForThemeNamed:name];
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];

    if ([self.activeThemeName isEqualToString:name]) {
        self.activeThemeName = @"";
        self.currentThemeDict = nil;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kActiveThemeNameDefaultsKey];
        [self notifyThemeChanged];
    }
}

- (void)setActiveTheme:(NSString *)name {
    if (name.length == 0) {
        self.activeThemeName = @"";
        self.currentThemeDict = nil;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kActiveThemeNameDefaultsKey];
        [self notifyThemeChanged];
        return;
    }

    if (![self loadDictForThemeNamed:name]) {
        NSLog(@"[ThemeEngine] Could not activate theme '%@' — file missing or invalid", name);
        return;
    }

    self.activeThemeName = name;
    [[NSUserDefaults standardUserDefaults] setObject:name forKey:kActiveThemeNameDefaultsKey];
    [self notifyThemeChanged];
}

- (BOOL)loadDictForThemeNamed:(NSString *)name {
    NSURL *url = [self urlForThemeNamed:name];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) return NO;

    NSError *err;
    NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    if (err || ![parsed isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[ThemeEngine] Failed to parse theme '%@': %@", name, err);
        return NO;
    }

    self.currentThemeDict = parsed;
    return YES;
}

- (void)notifyThemeChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:EeveeThemeDidChangeNotification object:nil];
    });
}

#pragma mark - Color lookup

- (UIColor *)colorForKey:(NSString *)key fallback:(nullable UIColor *)fallback {
    if (!self.isThemeEnabled) return fallback;

    NSString *hex = self.currentThemeDict[key];
    if (![hex isKindOfClass:[NSString class]] || hex.length == 0) return fallback;

    UIColor *color = [self colorFromHexString:hex];
    return color ?: fallback;
}

- (nullable UIColor *)colorFromHexString:(NSString *)hexString {
    NSString *hex = [[hexString stringByReplacingOccurrencesOfString:@"#" withString:@""]
                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (hex.length != 6 && hex.length != 8) return nil;

    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    if (![scanner scanHexInt:&rgbValue]) return nil;

    CGFloat alpha = 1.0, red, green, blue;

    if (hex.length == 8) {
        alpha = ((rgbValue & 0xFF000000) >> 24) / 255.0;
        red   = ((rgbValue & 0x00FF0000) >> 16) / 255.0;
        green = ((rgbValue & 0x0000FF00) >> 8)  / 255.0;
        blue  = (rgbValue & 0x000000FF) / 255.0;
    } else {
        red   = ((rgbValue & 0xFF0000) >> 16) / 255.0;
        green = ((rgbValue & 0x00FF00) >> 8)  / 255.0;
        blue  = (rgbValue & 0x0000FF) / 255.0;
    }

    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

#pragma mark - Wallpaper

- (NSURL *)wallpaperURLForType:(EeveeWallpaperType)type {
    NSString *ext = (type == EeveeWallpaperTypeVideo) ? @"mp4" : (type == EeveeWallpaperTypeGIF) ? @"gif" : @"png";
    return [[self documentsDirectory] URLByAppendingPathComponent:[kWallpaperFileName stringByAppendingPathExtension:ext]];
}

- (EeveeWallpaperType)currentWallpaperType {
    return (EeveeWallpaperType)[[NSUserDefaults standardUserDefaults] integerForKey:kWallpaperTypeDefaultsKey];
}

- (BOOL)hasWallpaper {
    EeveeWallpaperType type = [self currentWallpaperType];
    if (type == EeveeWallpaperTypeNone) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:[self wallpaperURLForType:type].path];
}

- (nullable NSString *)wallpaperFilePath {
    if (![self hasWallpaper]) return nil;
    return [self wallpaperURLForType:[self currentWallpaperType]].path;
}

- (BOOL)saveWallpaperFromURL:(NSURL *)sourceURL type:(EeveeWallpaperType)type error:(NSError * _Nullable * _Nullable)error {
    // Clear any wallpaper of a different type first so only one is ever active
    for (NSInteger t = EeveeWallpaperTypeImage; t <= EeveeWallpaperTypeVideo; t++) {
        [[NSFileManager defaultManager] removeItemAtURL:[self wallpaperURLForType:t] error:nil];
    }

    NSURL *dest = [self wallpaperURLForType:type];
    NSData *data = [NSData dataWithContentsOfURL:sourceURL options:0 error:error];
    if (!data) return NO;

    if (![data writeToURL:dest options:NSDataWritingAtomic error:error]) return NO;

    [[NSUserDefaults standardUserDefaults] setInteger:type forKey:kWallpaperTypeDefaultsKey];
    [self notifyThemeChanged];
    return YES;
}

- (void)clearWallpaper {
    EeveeWallpaperType type = [self currentWallpaperType];
    if (type != EeveeWallpaperTypeNone) {
        [[NSFileManager defaultManager] removeItemAtURL:[self wallpaperURLForType:type] error:nil];
    }
    [[NSUserDefaults standardUserDefaults] setInteger:EeveeWallpaperTypeNone forKey:kWallpaperTypeDefaultsKey];
    [self notifyThemeChanged];
}

@end
