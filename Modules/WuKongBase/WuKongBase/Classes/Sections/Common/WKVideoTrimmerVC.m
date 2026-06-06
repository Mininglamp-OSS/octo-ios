//
//  WKVideoTrimmerVC.m
//  WuKongBase
//

#import "WKVideoTrimmerVC.h"
#import <AVFoundation/AVFoundation.h>
#import "WuKongBase.h"
#import "WKApp.h"
#import "UIView+WK.h"
#import "WKLogs.h"

static const CGFloat kThumbBarHeight = 60.0f;
static const CGFloat kThumbBarHPad   = 16.0f;
static const NSInteger kThumbCount   = 10;

@interface WKVideoTrimmerVC ()

@property(nonatomic, strong) NSURL *videoURL;
@property(nonatomic, assign) NSTimeInterval windowDuration;
@property(nonatomic, copy)   void (^onConfirm)(CMTime startTime);
@property(nonatomic, copy)   void (^onCancel)(void);

@property(nonatomic, strong) AVURLAsset *asset;
@property(nonatomic, strong) AVPlayer *player;
@property(nonatomic, strong) AVPlayerLayer *playerLayer;
@property(nonatomic, strong) UIView *playerView;
// addPeriodicTimeObserverForInterval 返回的 token, dealloc 时必须 removeTimeObserver,
// 否则 observer 会保留 player 强引用, 引发观察者生命周期问题。
@property(nonatomic, strong) id timeObserverToken;

@property(nonatomic, strong) UIView *thumbBar;       // 缩略图带容器
@property(nonatomic, strong) UIView *windowView;     // 半透明白框 (3 秒窗口)
@property(nonatomic, strong) UIView *dimLeft;        // 窗口左侧遮罩
@property(nonatomic, strong) UIView *dimRight;       // 窗口右侧遮罩
@property(nonatomic, strong) UIPanGestureRecognizer *panGR;

@property(nonatomic, assign) NSTimeInterval totalDuration;
@property(nonatomic, assign) CGFloat windowWidth;    // 窗口像素宽
@property(nonatomic, assign) CGFloat barUsableWidth; // 缩略图带可拖区宽
@property(nonatomic, assign) CGFloat panStartX;      // 拖动起始 windowView.x
@property(nonatomic, assign) CGFloat currentWindowX; // 当前 windowView.x (绝对坐标, 含 kThumbBarHPad)

@property(nonatomic, strong) UIActivityIndicatorView *thumbSpinner; // 缩略图加载转圈
@property(nonatomic, assign) BOOL didStartThumbGen;                 // 防重入（viewDidLayoutSubviews 会多次触发）

@end

@implementation WKVideoTrimmerVC

- (instancetype)initWithVideoURL:(NSURL *)url
                  windowDuration:(NSTimeInterval)windowDuration
                       onConfirm:(void (^)(CMTime))onConfirm
                        onCancel:(void (^)(void))onCancel {
    self = [super init];
    if (self) {
        _videoURL = url;
        _windowDuration = windowDuration;
        _onConfirm = [onConfirm copy];
        _onCancel = [onCancel copy];
    }
    return self;
}

- (NSString *)langTitle {
    return LLang(@"截取片段");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    self.asset = [AVURLAsset URLAssetWithURL:self.videoURL options:nil];
    self.totalDuration = CMTimeGetSeconds(self.asset.duration);

    [self setupPlayerArea];
    [self setupThumbBar];
    [self setupNavBar];
    [self generateThumbnails];

    // 默认起点 0，预播放
    [self.player play];
}

- (void)setupNavBar {
    self.navigationBar.titleLabel.textColor = [UIColor whiteColor];

    UIButton *nextBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [nextBtn setTitle:LLang(@"下一步") forState:UIControlStateNormal];
    [nextBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
    nextBtn.titleLabel.font = [UIFont systemFontOfSize:16.0f weight:UIFontWeightMedium];
    nextBtn.frame = CGRectMake(0, 0, 60, 44);
    [nextBtn addTarget:self action:@selector(nextPressed) forControlEvents:UIControlEventTouchUpInside];
    self.navigationBar.rightView = nextBtn;
}

- (void)setupPlayerArea {
    CGFloat top = [self getNavBottom];
    CGFloat thumbBarY = self.view.bounds.size.height - kThumbBarHeight - 40;
    CGFloat playerH = thumbBarY - top - 20;
    CGFloat playerW = self.view.bounds.size.width;

    self.playerView = [[UIView alloc] initWithFrame:CGRectMake(0, top + 10, playerW, playerH)];
    self.playerView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.playerView];

    self.player = [AVPlayer playerWithURL:self.videoURL];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playerLayer.frame = self.playerView.bounds;
    [self.playerView.layer addSublayer:self.playerLayer];

    // 循环播放到窗口末端就 seek 回起点
    __weak typeof(self) ws = self;
    self.timeObserverToken = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.05, 600)
                                              queue:dispatch_get_main_queue()
                                         usingBlock:^(CMTime time) {
        NSTimeInterval cur = CMTimeGetSeconds(time);
        NSTimeInterval startSec = [ws currentStartSec];
        if (cur >= startSec + ws.windowDuration || cur < startSec - 0.05) {
            [ws.player seekToTime:CMTimeMakeWithSeconds(startSec, 600)
                  toleranceBefore:kCMTimeZero
                   toleranceAfter:kCMTimeZero];
        }
    }];
}

- (void)setupThumbBar {
    CGFloat y = self.view.bounds.size.height - kThumbBarHeight - 40;
    CGFloat w = self.view.bounds.size.width - kThumbBarHPad * 2;

    self.thumbBar = [[UIView alloc] initWithFrame:CGRectMake(kThumbBarHPad, y, w, kThumbBarHeight)];
    self.thumbBar.layer.cornerRadius = 6.0f;
    self.thumbBar.layer.masksToBounds = YES;
    self.thumbBar.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [self.view addSubview:self.thumbBar];

    self.barUsableWidth = w;
    CGFloat ratio = MIN(1.0, self.windowDuration / MAX(self.totalDuration, 0.001));
    self.windowWidth = MAX(60.0, ratio * w);

    // 左右遮罩
    self.dimLeft = [[UIView alloc] initWithFrame:CGRectZero];
    self.dimLeft.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    self.dimLeft.userInteractionEnabled = NO;
    [self.thumbBar addSubview:self.dimLeft];

    self.dimRight = [[UIView alloc] initWithFrame:CGRectZero];
    self.dimRight.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    self.dimRight.userInteractionEnabled = NO;
    [self.thumbBar addSubview:self.dimRight];

    // 半透明白框 (window) — 拖动它整体平移
    self.windowView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.windowWidth, kThumbBarHeight)];
    self.windowView.layer.borderColor = [UIColor whiteColor].CGColor;
    self.windowView.layer.borderWidth = 3.0f;
    self.windowView.layer.cornerRadius = 4.0f;
    self.windowView.backgroundColor = [UIColor clearColor];
    [self.thumbBar addSubview:self.windowView];

    self.panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.windowView addGestureRecognizer:self.panGR];

    self.currentWindowX = kThumbBarHPad; // 绝对坐标
    [self updateOverlayLayout];
}

- (void)generateThumbnails {
    if (self.didStartThumbGen) return;
    self.didStartThumbGen = YES;

    NSInteger count = kThumbCount;
    CGFloat thumbW = self.thumbBar.bounds.size.width / count;
    CGFloat thumbH = kThumbBarHeight;

    // 1. 主线程立刻把 10 个占位排好，灰底，让用户看到位置
    NSMutableArray<UIImageView *> *placeholders = [NSMutableArray array];
    for (NSInteger i = 0; i < count; i++) {
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(i * thumbW, 0, thumbW, thumbH)];
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        [self.thumbBar insertSubview:iv atIndex:0]; // 在 dim/window 下面
        [placeholders addObject:iv];
    }

    // 2. 中间放 loading 转圈，等所有帧都解出来再隐藏，避免"半截黑色"被当成 bug
    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.color = [UIColor whiteColor];
    spinner.hidesWhenStopped = YES;
    spinner.center = CGPointMake(self.thumbBar.bounds.size.width * 0.5, self.thumbBar.bounds.size.height * 0.5);
    [self.thumbBar addSubview:spinner];
    [spinner startAnimating];
    self.thumbSpinner = spinner;

    // 3. 异步加 asset metadata，再丢到串行 background 队列做截帧
    __weak typeof(self) ws = self;
    NSArray *loadKeys = @[@"duration", @"tracks"];
    [self.asset loadValuesAsynchronouslyForKeys:loadKeys completionHandler:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __strong typeof(ws) ss = ws;
            if (!ss) return;
            [ss extractThumbsSerial:placeholders thumbW:thumbW thumbH:thumbH count:count];
        });
    }];
}

// 串行同步截帧：相比 generateCGImagesAsynchronouslyForTimes: 批量异步 API，
// copyCGImageAtTime: 是同步、单帧、稳定，没有内部多请求 race / 状态机问题。
// 但 **同一个 AVAssetImageGenerator 实例**连续 copyCGImageAtTime: 在 iOS 上
// 有概率把 VideoToolbox 解码器状态打污——前几帧 OK，后续全 fail 报
// AVErrorUnknown(-11800) / OSStatus -12785。所以每帧 new 一个全新的
// generator，再加一次重试兜底；成本可忽略 (单次 alloc/init <1ms)。
- (void)extractThumbsSerial:(NSArray<UIImageView *> *)placeholders
                     thumbW:(CGFloat)thumbW
                     thumbH:(CGFloat)thumbH
                      count:(NSInteger)count {
    // 校验 metadata
    NSError *kvErr = nil;
    AVKeyValueStatus durStatus = [self.asset statusOfValueForKey:@"duration" error:&kvErr];
    AVKeyValueStatus trkStatus = [self.asset statusOfValueForKey:@"tracks" error:nil];
    if (durStatus != AVKeyValueStatusLoaded || trkStatus != AVKeyValueStatusLoaded) {
        WKLogInfo(@"[trimmer] asset KV not loaded duration=%ld tracks=%ld err=%@",
                  (long)durStatus, (long)trkStatus, kvErr);
        [self hideThumbSpinnerOnMain];
        return;
    }

    NSTimeInterval total = CMTimeGetSeconds(self.asset.duration);
    if (total <= 0 || isnan(total)) {
        WKLogInfo(@"[trimmer] asset duration invalid: %.3f", total);
        [self hideThumbSpinnerOnMain];
        return;
    }

    CGSize maxSize = CGSizeMake(thumbW * 2, thumbH * 2);

    NSInteger okCount = 0;
    NSInteger failCount = 0;

    __weak typeof(self) ws = self;
    for (NSInteger i = 0; i < count; i++) {
        @autoreleasepool {
            __strong typeof(ws) ss = ws;
            if (!ss) return; // VC dealloc，提前退出

            NSTimeInterval t = (total / count) * i;
            CMTime cmTime = CMTimeMakeWithSeconds(t, 600);

            CGImageRef cgImage = NULL;
            CMTime actualTime = kCMTimeZero;
            NSError *err = nil;

            // 第一次尝试：fresh generator
            cgImage = [self wk_copyCGImageAt:cmTime
                                    maxSize:maxSize
                                  actualOut:&actualTime
                                     errOut:&err];

            // 失败立即用一个全新 generator 重试一次
            if (!cgImage) {
                err = nil;
                cgImage = [self wk_copyCGImageAt:cmTime
                                        maxSize:maxSize
                                      actualOut:&actualTime
                                         errOut:&err];
            }

            if (!cgImage) {
                failCount++;
                WKLogInfo(@"[trimmer] frame#%ld t=%.2fs FAILED (after retry) err=%@",
                          (long)i, t, err);
                continue;
            }

            okCount++;
            UIImage *img = [UIImage imageWithCGImage:cgImage];
            CGImageRelease(cgImage);
            NSInteger idx = i;
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(ws) ss2 = ws;
                if (!ss2) return;
                if (idx >= 0 && idx < (NSInteger)placeholders.count) {
                    placeholders[idx].image = img;
                }
            });
        }
    }

    if (failCount > 0) {
        WKLogInfo(@"[trimmer] serial extract done: ok=%ld fail=%ld of %ld",
                  (long)okCount, (long)failCount, (long)count);
    }

    [self hideThumbSpinnerOnMain];
}

// 每次都 new 一个 generator + 同步取一帧。
// 调用方负责 CGImageRelease 返回的 CGImageRef。
- (CGImageRef)wk_copyCGImageAt:(CMTime)t
                       maxSize:(CGSize)maxSize
                     actualOut:(CMTime *)actualOut
                        errOut:(NSError **)errOut CF_RETURNS_RETAINED {
    AVAssetImageGenerator *gen = [AVAssetImageGenerator assetImageGeneratorWithAsset:self.asset];
    gen.appliesPreferredTrackTransform = YES;
    gen.maximumSize = maxSize;
    gen.requestedTimeToleranceBefore = kCMTimePositiveInfinity;
    gen.requestedTimeToleranceAfter = kCMTimePositiveInfinity;
    return [gen copyCGImageAtTime:t actualTime:actualOut error:errOut];
}

- (void)hideThumbSpinnerOnMain {
    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(ws) ss = ws;
        [ss.thumbSpinner stopAnimating];
        [ss.thumbSpinner removeFromSuperview];
        ss.thumbSpinner = nil;
    });
}

#pragma mark - 拖动

- (void)handlePan:(UIPanGestureRecognizer *)gr {
    CGPoint t = [gr translationInView:self.view];
    if (gr.state == UIGestureRecognizerStateBegan) {
        self.panStartX = self.currentWindowX;
        [self.player pause];
    }
    if (gr.state == UIGestureRecognizerStateChanged || gr.state == UIGestureRecognizerStateEnded) {
        CGFloat newX = self.panStartX + t.x;
        CGFloat minX = kThumbBarHPad;
        CGFloat maxX = kThumbBarHPad + self.barUsableWidth - self.windowWidth;
        newX = MAX(minX, MIN(maxX, newX));
        self.currentWindowX = newX;
        [self updateOverlayLayout];

        NSTimeInterval startSec = [self currentStartSec];
        [self.player seekToTime:CMTimeMakeWithSeconds(startSec, 600)
                toleranceBefore:kCMTimeZero
                 toleranceAfter:kCMTimeZero];
    }
    if (gr.state == UIGestureRecognizerStateEnded || gr.state == UIGestureRecognizerStateCancelled) {
        [self.player play];
    }
}

- (void)updateOverlayLayout {
    CGFloat localX = self.currentWindowX - kThumbBarHPad;
    self.windowView.frame = CGRectMake(localX, 0, self.windowWidth, kThumbBarHeight);
    self.dimLeft.frame = CGRectMake(0, 0, localX, kThumbBarHeight);
    self.dimRight.frame = CGRectMake(localX + self.windowWidth, 0,
                                     self.barUsableWidth - localX - self.windowWidth,
                                     kThumbBarHeight);
}

- (NSTimeInterval)currentStartSec {
    CGFloat localX = self.currentWindowX - kThumbBarHPad;
    return (localX / self.barUsableWidth) * self.totalDuration;
}

#pragma mark - 按钮

- (void)nextPressed {
    [self.player pause];
    CMTime t = CMTimeMakeWithSeconds([self currentStartSec], 600);
    if (self.onConfirm) {
        self.onConfirm(t);
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)backPressed {
    [self.player pause];
    if (self.onCancel) {
        self.onCancel();
    }
    [super backPressed];
}

- (void)dealloc {
    [_player pause];
    if (_timeObserverToken && _player) {
        [_player removeTimeObserver:_timeObserverToken];
        _timeObserverToken = nil;
    }
}

@end
