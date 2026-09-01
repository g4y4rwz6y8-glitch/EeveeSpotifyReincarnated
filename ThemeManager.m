#import "ThemeManager.h"

@implementation ThemeManager

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

@end
