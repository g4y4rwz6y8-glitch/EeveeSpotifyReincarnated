#import "SPTImageRenderer.h"

@interface SPTImageRenderer ()
@property (nonatomic, strong) UIImageView *imageView;
@end

@implementation SPTImageRenderer

@synthesize renderView = _renderView;

- (instancetype)init {
    self = [super init];
    if (self) {
        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        _renderView = _imageView;
    }
    return self;
}

- (void)installInWindow:(UIWindow *)window {
    if (self.imageView.superview == window) return;
    [self.imageView removeFromSuperview];
    [window insertSubview:self.imageView atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [self.imageView.topAnchor constraintEqualToAnchor:window.topAnchor],
        [self.imageView.bottomAnchor constraintEqualToAnchor:window.bottomAnchor],
        [self.imageView.leadingAnchor constraintEqualToAnchor:window.leadingAnchor],
        [self.imageView.trailingAnchor constraintEqualToAnchor:window.trailingAnchor],
    ]];
}

- (void)loadFromFileURL:(NSURL *)fileURL completion:(void (^)(BOOL))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *image = [UIImage imageWithContentsOfFile:fileURL.path];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView.image = image;
            if (completion) completion(image != nil);
        });
    });
}

- (void)pause {}
- (void)resume {}

- (void)teardown {
    self.imageView.image = nil;
    [self.imageView removeFromSuperview];
}

@end
