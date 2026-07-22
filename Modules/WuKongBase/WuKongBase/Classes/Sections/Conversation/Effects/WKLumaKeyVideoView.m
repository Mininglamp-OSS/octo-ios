//
//  WKLumaKeyVideoView.m
//  WuKongBase
//

#import "WKLumaKeyVideoView.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#pragma mark - 弱引用代理（打破 CADisplayLink 对 target 的强持有）

/// CADisplayLink 会强引用 target；用弱代理转发 tick，避免 view 无法释放。
@interface WKLumaKeyDisplayLinkProxy : NSObject
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector;
@end

@implementation WKLumaKeyDisplayLinkProxy
- (void)onTick:(CADisplayLink *)link {
    id t = self.target;
    if (t && [t respondsToSelector:self.selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [t performSelector:self.selector withObject:link];
#pragma clang diagnostic pop
    }
}
@end

#pragma mark -

@interface WKLumaKeyVideoView ()
@property (nonatomic, strong) NSURL *videoURL;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayerItemVideoOutput *videoOutput;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) WKLumaKeyDisplayLinkProxy *displayLinkProxy;

@property (nonatomic, strong) id<MTLDevice> metalDevice;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) CIContext *ciContext;
@property (nonatomic, strong) CIKernel *lumaKernel;
@property (nonatomic, assign) CGColorSpaceRef colorSpace;

@property (nonatomic, copy, nullable) void (^completion)(void);
@property (nonatomic, assign) BOOL stopped;
@end

@implementation WKLumaKeyVideoView

+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (CAMetalLayer *)metalLayer {
    return (CAMetalLayer *)self.layer;
}

- (instancetype)initWithVideoURL:(NSURL *)videoURL {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _videoURL = videoURL;
        _lumaThreshold = 0.10;   // 深蓝近黑背景实测值
        _lumaTolerance = 0.12;
        _centerProtectRadius = 0.30;
        _centerProtectSoftness = 0.12;
        _centerProtectCenter = CGPointMake(0.5, 0.5);
        _backgroundAlphaFloor = 0.05;
        _backgroundAlphaCeil = 0.45;
        _eyeProtectCenter = CGPointMake(0.5, 0.5);
        _eyeProtectRadius = 0.0;         // 默认关闭
        _eyeProtectSoftness = 0.0;
        _centerProtectStartTime = 0.0;   // 默认中心盘从头常驻
        _centerProtectRampDuration = 0.0;
        _soundEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        [self setupMetal];
        [self setupKernel];
    }
    return self;
}

- (void)dealloc {
    [self stop];
    if (_colorSpace) { CGColorSpaceRelease(_colorSpace); _colorSpace = NULL; }
}

#pragma mark - Setup

- (void)setupMetal {
    _metalDevice = MTLCreateSystemDefaultDevice();
    if (!_metalDevice) return;  // 模拟器极老机型兜底：无 Metal 则不渲染（特效静默跳过）
    _commandQueue = [_metalDevice newCommandQueue];

    CAMetalLayer *ml = [self metalLayer];
    ml.device = _metalDevice;
    ml.pixelFormat = MTLPixelFormatBGRA8Unorm;
    ml.framebufferOnly = NO;          // CIContext 要写入 drawable 纹理
    ml.opaque = NO;                   // 允许透明合成到聊天界面
    ml.presentsWithTransaction = NO;

    _colorSpace = CGColorSpaceCreateDeviceRGB();
    _ciContext = [CIContext contextWithMTLDevice:_metalDevice
                                         options:@{kCIContextWorkingColorSpace: (__bridge id)_colorSpace}];
}

- (void)setupKernel {
    // lumakey 色彩核（general kernel，需要 destCoord 做中心径向保护）：
    //   主体（luma >= thr+tol）→ 完全不透明，清晰浮在最上层。
    //   背景（luma < thr）→ **不全删**，做成"半透明纱"：alpha 随亮度线性变化
    //        bgA = bgFloor + (luma/thr) * (bgCeil - bgFloor)
    //        → 越亮（底部蓝光晕）保留越多(接近 bgCeil)，越暗（四角）越透(接近 bgFloor)。
    //   过渡带（thr ~ thr+tol）→ smoothstep 从 bgCeil 平滑到 1（发光边缘自然）。
    //   中心保护：destCoord 落在中心圆内 → alpha 抬到 1（脸/眼睛不被抠），受 centerStrength 门控。
    //   眼部保护：另一个更小、可定位、带强度(时间门控)的圆，补回被抠穿的深色眼睛。
    //   返回预乘 alpha。
    //   参数：image, thr, tol, bgFloor, bgCeil, center(像素), protectR(像素), protectSoft(像素),
    //        centerStrength(0~1), eyeCenter(像素), eyeR(像素), eyeSoft(像素), eyeStrength(0~1)
    static NSString *src =
        @"kernel vec4 lumaKey(sampler image, float thr, float tol,"
        @"                     float bgFloor, float bgCeil,"
        @"                     vec2 center, float protectR, float protectSoft, float centerStrength,"
        @"                     vec2 eyeCenter, float eyeR, float eyeSoft, float eyeStrength) {"
        @"  vec4 s = sample(image, samplerCoord(image));"
        @"  float luma = dot(s.rgb, vec3(0.299, 0.587, 0.114));"
        @"  float t = max(thr, 0.0001);"
        @"  float bgA = bgFloor + clamp(luma / t, 0.0, 1.0) * (bgCeil - bgFloor);"  // 背景半透明纱
        @"  float edge = smoothstep(thr, thr + max(tol, 0.0001), luma);"            // 过渡带 0→1
        @"  float a = mix(bgA, 1.0, edge);"                                          // 背景纱 → 主体不透明
        @"  float d = distance(destCoord(), center);"
        @"  float protect = (1.0 - smoothstep(protectR, protectR + max(protectSoft, 0.0001), d)) * clamp(centerStrength, 0.0, 1.0);"
        @"  a = max(a, protect);"               // 中心圆内强制不透明（按 centerStrength）
        @"  float de = distance(destCoord(), eyeCenter);"
        @"  float eye = (1.0 - smoothstep(eyeR, eyeR + max(eyeSoft, 0.0001), de)) * clamp(eyeStrength, 0.0, 1.0);"
        @"  a = max(a, eye);"                   // 眼部小圈按强度补回不透明
        @"  return vec4(s.rgb * a, a);"         // 预乘 alpha
        @"}";
    // kernelWithString: 自 iOS 12 标记 deprecated 但仍可用；改用 Metal .ci.metal 内核
    // 需要单独的编译配置，对单个核函数属过度工程，这里沿用运行时编译并消除告警。
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    _lumaKernel = [CIKernel kernelWithString:src];
#pragma clang diagnostic pop
}

#pragma mark - Public

- (void)playWithCompletion:(nullable void (^)(void))completion {
    self.completion = completion;
    self.stopped = NO;

    if (!self.metalDevice || !self.lumaKernel || !self.videoURL) {
        [self finishOnce];   // 环境不满足：直接回调完成，让上层正常清理
        return;
    }

    AVURLAsset *asset = [AVURLAsset assetWithURL:self.videoURL];
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];

    NSDictionary *attrs = @{ (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA) };
    self.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:attrs];
    [self.playerItem addOutput:self.videoOutput];

    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    self.player.muted = !self.soundEnabled;
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.playerItem];

    // CADisplayLink（弱代理）逐帧拉取已解码的视频帧
    self.displayLinkProxy = [WKLumaKeyDisplayLinkProxy new];
    self.displayLinkProxy.target = self;
    self.displayLinkProxy.selector = @selector(displayLinkTick:);
    self.displayLink = [CADisplayLink displayLinkWithTarget:self.displayLinkProxy
                                                   selector:@selector(onTick:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    [self.player play];
}

- (void)stop {
    if (self.stopped) return;
    self.stopped = YES;

    [self.displayLink invalidate];
    self.displayLink = nil;
    self.displayLinkProxy = nil;

    [self.player pause];
    if (self.playerItem && self.videoOutput) {
        [self.playerItem removeOutput:self.videoOutput];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:self.playerItem];
    self.videoOutput = nil;
    self.player = nil;
    self.playerItem = nil;
    // 必须 nil completion: 调用方 (WKActionVideoEffect / WKClassyVideoEffect) 的
    // playWithCompletion: block 内 strong-capture videoView (UIView animateWithDuration
    // 里 videoView.alpha = 0.0), 而 completion 是本 view 的 copy property →
    // videoView → completion → videoView retain cycle。cancel 路径 (cancelCurrentEffect
    // → removeFromSuperview → willMoveToWindow:nil → stop) 不 nil completion 会
    // 漏一整套 AVPlayer / AVPlayerItem / AVPlayerItemVideoOutput / CIContext /
    // MTLCommandQueue / MTLDevice + dealloc 里 CGColorSpaceRelease 永不跑
    // (PR #32 R18 review: yujiawei)。
    self.completion = nil;
}

#pragma mark - Lifecycle hooks

// effectView 被 cancelCurrentEffect 移除（退出会话）时会走到这：及时停掉渲染。
- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];
    if (newWindow == nil) {
        [self stop];
    }
}

#pragma mark - Frame pump

- (void)displayLinkTick:(CADisplayLink *)link {
    AVPlayerItemVideoOutput *output = self.videoOutput;
    if (!output) return;

    CFTimeInterval hostTime = link.timestamp + link.duration;
    CMTime itemTime = [output itemTimeForHostTime:hostTime];
    if (![output hasNewPixelBufferForItemTime:itemTime]) return;

    CVPixelBufferRef pixelBuffer = [output copyPixelBufferForItemTime:itemTime itemTimeForDisplay:NULL];
    if (!pixelBuffer) return;

    NSTimeInterval seconds = CMTimeGetSeconds(itemTime);
    if (isnan(seconds) || seconds < 0) seconds = 0;
    [self renderPixelBuffer:pixelBuffer atTime:seconds];
    CVPixelBufferRelease(pixelBuffer);
}

- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer atTime:(NSTimeInterval)seconds {
    CAMetalLayer *ml = [self metalLayer];
    CGFloat scale = self.window.screen.scale ?: UIScreen.mainScreen.scale;
    CGSize drawableSize = CGSizeMake(self.bounds.size.width * scale,
                                     self.bounds.size.height * scale);
    if (drawableSize.width < 1 || drawableSize.height < 1) return;
    ml.drawableSize = drawableSize;

    CIImage *source = [CIImage imageWithCVPixelBuffer:pixelBuffer];

    // 中心保护区 / floor 参数换算到 source 像素坐标
    CGRect ext = source.extent;
    CGFloat shortSide = MIN(ext.size.width, ext.size.height);
    // 中心盘圆心：归一化（原点左上）→ source 像素。CIImage/destCoord 左下原点、y 向上，故 y 翻转。
    CGPoint center = CGPointMake(ext.origin.x + self.centerProtectCenter.x * ext.size.width,
                                 ext.origin.y + (1.0 - self.centerProtectCenter.y) * ext.size.height);
    CGFloat protectR = self.centerProtectRadius * shortSide;
    CGFloat protectSoft = self.centerProtectSoftness * shortSide;

    // 眼部保护圈：归一化坐标（原点左上）换算到 source 像素坐标。
    // 注意 CIImage / destCoord 为左下原点、y 向上，故 y 需翻转 (1 - ny)。
    CGFloat eyeCx = ext.origin.x + self.eyeProtectCenter.x * ext.size.width;
    CGFloat eyeCy = ext.origin.y + (1.0 - self.eyeProtectCenter.y) * ext.size.height;
    CGFloat eyeR = self.eyeProtectRadius * shortSide;
    CGFloat eyeSoft = self.eyeProtectSoftness * shortSide;
    // 中心盘延时出现（眼部小圈不受影响，见下）：
    //   startTime<=0 → 中心盘从头常驻全强度（Action/Classy 原行为）。
    //   startTime>0  → <startTime 强度 0；[startTime, +rampDuration] 线性淡入；之后全强度。
    CGFloat centerStrength = 1.0;
    if (self.centerProtectStartTime > 0.0) {
        if (seconds <= self.centerProtectStartTime) {
            centerStrength = 0.0;
        } else if (self.centerProtectRampDuration <= 0) {
            centerStrength = 1.0;
        } else {
            centerStrength = MIN(1.0, (seconds - self.centerProtectStartTime) / self.centerProtectRampDuration);
        }
    }
    // 眼部小圈：只要半径>0 就全程常驻（0→结束），与中心盘时间门控无关。
    CGFloat eyeStrength = (self.eyeProtectRadius > 0.0) ? 1.0 : 0.0;

    // lumakey 抠像（general kernel：中心径向保护 + 眼部小圈 + alpha floor）
    CIVector *centerVec = [CIVector vectorWithX:center.x Y:center.y];
    CIVector *eyeVec = [CIVector vectorWithX:eyeCx Y:eyeCy];
    CIImage *keyed = [self.lumaKernel applyWithExtent:ext
                                          roiCallback:^CGRect(int index, CGRect destRect) {
        return destRect;   // 逐像素一一对应，ROI = 目标区域
    }
                                            arguments:@[ source,
                                                         @(self.lumaThreshold),
                                                         @(self.lumaTolerance),
                                                         @(self.backgroundAlphaFloor),
                                                         @(self.backgroundAlphaCeil),
                                                         centerVec,
                                                         @(protectR),
                                                         @(protectSoft),
                                                         @(centerStrength),
                                                         eyeVec,
                                                         @(eyeR),
                                                         @(eyeSoft),
                                                         @(eyeStrength) ]];
    if (!keyed) return;

    // aspect-fill 缩放到 drawable，并把坐标系映射到 [0, drawableSize]
    CGFloat sw = source.extent.size.width;
    CGFloat sh = source.extent.size.height;
    if (sw < 1 || sh < 1) return;
    CGFloat s = MAX(drawableSize.width / sw, drawableSize.height / sh);
    CGFloat tx = (drawableSize.width  - sw * s) * 0.5;
    CGFloat ty = (drawableSize.height - sh * s) * 0.5;
    CIImage *scaled = [keyed imageByApplyingTransform:CGAffineTransformMake(s, 0, 0, s, tx, ty)];

    id<CAMetalDrawable> drawable = [ml nextDrawable];
    if (!drawable) return;

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

    // 先清空 drawable 为全透明（被 key 掉的区域 / 边界保持透明）
    MTLRenderPassDescriptor *clearPass = [MTLRenderPassDescriptor renderPassDescriptor];
    clearPass.colorAttachments[0].texture = drawable.texture;
    clearPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    clearPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    clearPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    id<MTLRenderCommandEncoder> enc = [commandBuffer renderCommandEncoderWithDescriptor:clearPass];
    [enc endEncoding];

    // 把抠好的帧渲染进 drawable 纹理
    CGRect renderBounds = CGRectMake(0, 0, drawableSize.width, drawableSize.height);
    [self.ciContext render:scaled
              toMTLTexture:drawable.texture
             commandBuffer:commandBuffer
                    bounds:renderBounds
                colorSpace:self.colorSpace];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

#pragma mark - End

- (void)playerDidReachEnd:(NSNotification *)note {
    [self finishOnce];
}

- (void)finishOnce {
    void (^cb)(void) = self.completion;
    self.completion = nil;
    [self stop];
    if (cb) cb();
}

@end
