#import "SPTGifRenderer.h"
#import <ImageIO/ImageIO.h>

@interface SPTGifRenderer ()
@property (nonatomic, strong) UIImageView *gifView;
@end

@implementation SPTGifRenderer

@synthesize renderView = _renderView;

- (instancetype)init {
    self = [super init];
    if (self) {
        _gifView = [[UIImageView alloc] init];
        _gifView.contentMode = UIViewContentModeScaleAspectFill;
        _gifView.clipsToBounds = YES;
        _gifView.translatesAutoresizingMaskIntoConstraints = NO;
        _renderView = _gifView;
    }
    return self;
}

- (void)installInWindow:(UIWindow *)window {
    if (self.gifView.superview == window) return;
    [self.gifView removeFromSuperview];
    [window insertSubview:self.gifView atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [self.gifView.topAnchor constraintEqualToAnchor:window.topAnchor],
        [self.gifView.bottomAnchor constraintEqualToAnchor:window.bottomAnchor],
        [self.gifView.leadingAnchor constraintEqualToAnchor:window.leadingAnchor],
        [self.gifView.trailingAnchor constraintEqualToAnchor:window.trailingAnchor],
    ]];
}

- (void)loadFromFileURL:(NSURL *)fileURL completion:(void (^)(BOOL))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)fileURL, NULL);
        if (!source) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO);
            });
            return;
        }

        size_t count = CGImageSourceGetCount(source);
        NSMutableArray<UIImage *> *frames = [NSMutableArray arrayWithCapacity:count];
        NSTimeInterval totalDuration = 0;

        for (size_t i = 0; i < count; i++) {
            CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, i, NULL);
            if (!cgImage) continue;

            [frames addObject:[UIImage imageWithCGImage:cgImage]];
            CGImageRelease(cgImage);

            NSDictionary *props = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
            NSDictionary *gifProps = props[(__bridge NSString *)kCGImagePropertyGIFDictionary];
            NSNumber *delay = gifProps[(__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime]
                              ?: gifProps[(__bridge NSString *)kCGImagePropertyGIFDelayTime];
            totalDuration += delay ? delay.doubleValue : 0.1;
        }
        CFRelease(source);

        dispatch_async(dispatch_get_main_queue(), ^{
            self.gifView.animationImages = frames;
            self.gifView.animationDuration = totalDuration > 0 ? totalDuration : (frames.count * 0.1);
            self.gifView.animationRepeatCount = 0; // infinite
            self.gifView.image = frames.firstObject; // static fallback frame
            [self.gifView startAnimating];
            if (completion) completion(frames.count > 0);
        });
    });
}

- (void)pause {
    [self.gifView stopAnimating];
}

- (void)resume {
    [self.gifView startAnimating];
}

- (void)teardown {
    [self.gifView stopAnimating];
    self.gifView.animationImages = nil;
    self.gifView.image = nil;
    [self.gifView removeFromSuperview];
}

@end
