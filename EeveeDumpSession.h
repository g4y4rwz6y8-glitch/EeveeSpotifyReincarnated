#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EeveeDumpSession : NSObject

+ (instancetype)shared;

@property (nonatomic, strong, readonly) NSArray<NSString *> *targetScreens;
@property (nonatomic, strong, readonly) NSSet<NSString *> *completedScreens;

- (void)recordDumpForScreen:(NSString *)screenName hierarchyLog:(NSString *)log;
- (void)reset;
- (NSInteger)completedCount;
- (NSInteger)totalCount;
- (BOOL)isComplete;

@end

NS_ASSUME_NONNULL_END
