#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const EeveeThemeDidChangeNotification;

typedef NS_ENUM(NSInteger, EeveeWallpaperType) {
    EeveeWallpaperTypeNone = 0,
    EeveeWallpaperTypeImage,
    EeveeWallpaperTypeGIF,
    EeveeWallpaperTypeVideo
};

@interface ThemeManager : NSObject

@property (nonatomic, assign, getter=isThemeEnabled) BOOL themeEnabled;
@property (nonatomic, strong, readonly) NSString *activeThemeName;

+ (instancetype)shared;

// Named color themes
- (NSArray<NSString *> *)allSavedThemes;
- (void)saveTheme:(NSDictionary *)dict name:(NSString *)name;
- (void)setActiveTheme:(NSString *)name;
- (void)deleteTheme:(NSString *)name;
- (UIColor *)colorForKey:(NSString *)key fallback:(nullable UIColor *)fallback;

// Wallpaper
- (BOOL)hasWallpaper;
- (nullable NSString *)wallpaperFilePath;
- (EeveeWallpaperType)currentWallpaperType;
- (BOOL)saveWallpaperFromURL:(NSURL *)sourceURL type:(EeveeWallpaperType)type error:(NSError * _Nullable * _Nullable)error;
- (void)clearWallpaper;

- (NSURL *)documentsDirectory;

@end

NS_ASSUME_NONNULL_END
