#import "EeveeDumpSession.h"

static NSString * const kCompletedScreensDefaultsKey = @"com.eevee.themeengine.dumpSession.completed";
static NSString * const kScanFileName = @"eevee_full_scan.txt";

@interface EeveeDumpSession ()
@property (nonatomic, strong, readwrite) NSArray<NSString *> *targetScreens;
@property (nonatomic, strong) NSMutableSet<NSString *> *mutableCompleted;
@end

@implementation EeveeDumpSession

+ (instancetype)shared {
    static EeveeDumpSession *instance;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        instance = [EeveeDumpSession new];
        instance.targetScreens = @[@"Now Playing", @"Home", @"Search", @"Your Library", @"Settings"];
        NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:kCompletedScreensDefaultsKey];
        instance.mutableCompleted = saved ? [NSMutableSet setWithArray:saved] : [NSMutableSet set];
    });
    return instance;
}

- (NSSet<NSString *> *)completedScreens {
    return [self.mutableCompleted copy];
}

- (NSInteger)completedCount { return self.mutableCompleted.count; }
- (NSInteger)totalCount { return self.targetScreens.count; }
- (BOOL)isComplete { return self.mutableCompleted.count >= self.targetScreens.count; }

- (NSURL *)documentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
}

- (void)recordDumpForScreen:(NSString *)screenName hierarchyLog:(NSString *)log {
    [self.mutableCompleted addObject:screenName];
    [[NSUserDefaults standardUserDefaults] setObject:self.mutableCompleted.allObjects forKey:kCompletedScreensDefaultsKey];

    NSURL *fileURL = [[self documentsDirectory] URLByAppendingPathComponent:kScanFileName];
    NSString *existing = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:nil] ?: @"";
    NSString *header = [NSString stringWithFormat:@"\n\n########## SCREEN: %@ ##########\n", screenName];
    NSString *combined = [existing stringByAppendingString:[header stringByAppendingString:log]];
    [combined writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (void)reset {
    [self.mutableCompleted removeAllObjects];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kCompletedScreensDefaultsKey];
    NSURL *fileURL = [[self documentsDirectory] URLByAppendingPathComponent:kScanFileName];
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
}

@end
