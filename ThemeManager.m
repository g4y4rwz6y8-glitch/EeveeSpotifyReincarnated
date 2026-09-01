#import "ThemeManager.h"

@implementation ThemeManager

+ (instancetype)shared {
    static ThemeManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (NSURL *)documentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSURL *)wallpaperURLForType:(EeveeWallpaperType)type {
    NSString *ext = (type == EeveeWallpaperTypeVideo) ? @"mp4" : @"png";
    return [[self documentsDirectory] URLByAppendingPathComponent:[NSString stringWithFormat:@"eevee_wallpaper.%@", ext]];
}

- (NSArray<NSString *> *)allSavedThemes {
    // Return saved themes logic
    return @[];
}

- (void)saveTheme:(NSDictionary *)dict name:(NSString *)name {
    // Save theme logic
}

- (void)setActiveTheme:(NSString *)name {
    // Set active theme logic
}

- (void)deleteTheme:(NSString *)name {
    // Delete theme logic
}

- (UIColor *)colorForKey:(NSString *)key fallback:(nullable UIColor *)fallback {
    // Color for key logic
    return fallback;
}

- (BOOL)hasWallpaper {
    return [self wallpaperFilePath] != nil;
}

- (nullable NSString *)wallpaperFilePath {
    for (NSInteger t = EeveeWallpaperTypeImage; t <= EeveeWallpaperTypeVideo; t++) {
        NSURL *url = [self wallpaperURLForType:t];
        if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
            return url.path;
        }
    }
    return nil;
}

- (EeveeWallpaperType)currentWallpaperType {
    NSURL *videoURL = [self wallpaperURLForType:EeveeWallpaperTypeVideo];
    if ([[NSFileManager defaultManager] fileExistsAtPath:videoURL.path]) {
        return EeveeWallpaperTypeVideo;
    }
    return EeveeWallpaperTypeImage;
}

- (BOOL)saveWallpaperFromURL:(NSURL *)sourceURL type:(EeveeWallpaperType)type error:(NSError * _Nullable * _Nullable)error {
    // Clear any wallpaper of a different type first so only one is ever active
    for (NSInteger t = EeveeWallpaperTypeImage; t <= EeveeWallpaperTypeVideo; t++) {
        [[NSFileManager defaultManager] removeItemAtURL:[self wallpaperURLForType:t] error:nil];
    }

    NSURL *dest = [self wallpaperURLForType:type];

    // Prefer copying the file when possible to avoid loading large files into memory
    if (sourceURL.isFileURL) {
        // Ensure destination directory exists
        NSURL *dir = [dest URLByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir.path]) {
            [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }

        // Remove any existing destination
        [[NSFileManager defaultManager] removeItemAtURL:dest error:nil];

        BOOL copied = [[NSFileManager defaultManager] copyItemAtURL:sourceURL toURL:dest error:error];
        if (!copied) {
            // Fallback to data read/write if copy fails for whatever reason
            NSData *data = [NSData dataWithContentsOfURL:sourceURL options:0 error:error];
            if (!data) return NO;
            if (![data writeToURL:dest options:NSDataWritingAtomic error:error]) return NO;
        }
    } else {
        // Non-file URL (provider stream): read into NSData and write
        NSData *data = [NSData dataWithContentsOfURL:sourceURL options:0 error:error];
        if (!data) return NO;
        if (![data writeToURL:dest options:NSDataWritingAtomic error:error]) return NO;
    }

    return YES;
}

- (void)clearWallpaper {
    for (NSInteger t = EeveeWallpaperTypeImage; t <= EeveeWallpaperTypeVideo; t++) {
        [[NSFileManager defaultManager] removeItemAtURL:[self wallpaperURLForType:t] error:nil];
    }
}

@end
