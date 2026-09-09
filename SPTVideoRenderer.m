#import "SPTVideoRenderer.h"
#import <AVFoundation/AVFoundation.h>

@interface SPTVideoRenderer ()
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) AVQueuePlayer *player;
@property (nonatomic, strong) AVPlayerLooper *looper;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

@implementation SPTVideoRenderer

@synthesize renderView = _renderView;

- (instancetype)init {
    self = [super init];
    if (self) {
        _containerView = [[UIView alloc] init];
        _containerView.translatesAutoresizingMaskIntoConstraints = NO;
        _containerView.clipsToBounds = YES;
        _renderView = _containerView;
    }
    return self;
}

- (void)installInWindow:(UIWindow *)window {
    if (self.containerView.superview == window) return;
    [self.containerView removeFromSuperview];
    [window insertSubview:self.containerView atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [self.containerView.topAnchor constraintEqualToAnchor:window.topAnchor],
        [self.containerView.bottomAnchor constraintEqualToAnchor:window.bottomAnchor],
        [self.containerView.leadingAnchor constraintEqualToAnchor:window.leadingAnchor],
        [self.containerView.trailingAnchor constraintEqualToAnchor:window.trailingAnchor],
    ]];
    if (self.playerLayer) {
        self.playerLayer.frame = self.containerView.bounds;
    }
}

- (void)loadFromFileURL:(NSURL *)fileURL completion:(void (^)(BOOL))completion {
    [self teardownPlayerOnly];

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:fileURL];
    self.player = [AVQueuePlayer queuePlayerWithItems:@[]];
    self.player.muted = YES;
    self.looper = [AVPlayerLooper playerLooperWithPlayer:self.player templateItem:item];

    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.playerLayer.frame = self.containerView.bounds;
    [self.containerView.layer addSublayer:self.playerLayer];

    [self.player play];

    if (completion) completion(YES);
}

- (void)pause {
    [self.player pause];
}

- (void)resume {
    [self.player play];
}

- (void)teardownPlayerOnly {
    [self.player pause];
    [self.looper disableLooping];
    self.looper = nil;
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
    self.player = nil;
}

- (void)teardown {
    [self teardownPlayerOnly];
    [self.containerView removeFromSuperview];
}

@end
