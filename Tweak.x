*** Begin Patch
*** Update File: Tweak.x
@@
 - (UIView *)eevee_buildGIFWallpaperView:(NSString *)path {
-    NSData *data = [NSData dataWithContentsOfFile:path];
-    if (!data) return nil;
-    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
-    if (!source) return nil;
-
-    size_t count = CGImageSourceGetCount(source);
-    NSMutableArray *images = [NSMutableArray array];
-    for (size_t i = 0; i < count; i++) {
-        CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, i, NULL);
-        if (cgImage) {
-            [images addObject:[UIImage imageWithCGImage:cgImage]];
-            CGImageRelease(cgImage);
-        }
-    }
-    CFRelease(source);
-    if (images.count == 0) return nil;
-
-    UIImageView *iv = [[UIImageView alloc] init];
-    iv.animationImages = images;
-    iv.animationDuration = count * 0.1;
-    iv.contentMode = UIViewContentModeScaleAspectFill;
-    iv.clipsToBounds = YES;
-    [iv startAnimating];
-    return iv;
+    NSData *data = [NSData dataWithContentsOfFile:path];
+    if (!data) return nil;
+
+    // Prefer FLAnimatedImage for efficient GIF playback if it's linked into the binary
+    Class FLAnimatedImageClass = NSClassFromString(@"FLAnimatedImage");
+    Class FLAnimatedImageViewClass = NSClassFromString(@"FLAnimatedImageView");
+    if (FLAnimatedImageClass && FLAnimatedImageViewClass) {
+        id animated = [[FLAnimatedImageClass alloc] initWithAnimatedGIFData:data];
+        id iv = [[FLAnimatedImageViewClass alloc] init];
+        [iv setValue:animated forKey:@"animatedImage"];
+        UIView *view = (UIView *)iv;
+        view.contentMode = UIViewContentModeScaleAspectFill;
+        view.clipsToBounds = YES;
+        return view;
+    }
+
+    // Fallback: decode frames using ImageIO (compatibility mode)
+    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
+    if (!source) return nil;
+    size_t count = CGImageSourceGetCount(source);
+    NSMutableArray *images = [NSMutableArray array];
+    for (size_t i = 0; i < count; i++) {
+        CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, i, NULL);
+        if (cgImage) {
+            [images addObject:[UIImage imageWithCGImage:cgImage]];
+            CGImageRelease(cgImage);
+        }
+    }
+    CFRelease(source);
+    if (images.count == 0) return nil;
+
+    UIImageView *iv = [[UIImageView alloc] init];
+    iv.animationImages = images;
+    iv.animationDuration = MAX(0.1 * images.count, 0.2);
+    iv.contentMode = UIViewContentModeScaleAspectFill;
+    iv.clipsToBounds = YES;
+    [iv startAnimating];
+    return iv;
 }
@@
 - (UIView *)eevee_buildVideoWallpaperView:(NSString *)path {
-    NSURL *url = [NSURL fileURLWithPath:path];
-    AVPlayer *player = [AVPlayer playerWithURL:url];
-    player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
-    player.muted = YES;
-
-    EeveeVideoLayerView *view = [[EeveeVideoLayerView alloc] init];
-    view.playerLayer.player = player;
-    view.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
-
-    [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
-                                                      object:player.currentItem
-                                                       queue:[NSOperationQueue mainQueue]
-                                                  usingBlock:^(NSNotification *note) {
-        [player seekToTime:kCMTimeZero];
-        [player play];
-    }];
-    [player play];
-    return view;
+    NSURL *url = [NSURL fileURLWithPath:path];
+    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
+
+    // Use AVQueuePlayer so we can optionally use AVPlayerLooper for gapless playback
+    AVQueuePlayer *player = [[AVQueuePlayer alloc] initWithPlayerItem:item];
+    player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
+    player.muted = YES;
+
+    EeveeVideoLayerView *view = [[EeveeVideoLayerView alloc] init];
+    view.playerLayer.player = player;
+    view.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
+
+    // Register for end-of-playback on the specific item (more reliable than observing player.currentItem)
+    __weak AVQueuePlayer *weakPlayer = player;
+    id endObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
+                                                                         object:item
+                                                                          queue:[NSOperationQueue mainQueue]
+                                                                     usingBlock:^(NSNotification *note) {
+        AVQueuePlayer *p = weakPlayer;
+        if (!p) return;
+        [p seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
+            [p play];
+        }];
+    }];
+
+    // Store observer on the view so it can be removed when the view is deallocated
+    if ([view respondsToSelector:@selector(setValue:forKey:)]) {
+        [view setValue:endObserver forKey:@"eevee_endObserver"];
+    }
+
+    [player play];
+    return view;
 }
*** End Patch
