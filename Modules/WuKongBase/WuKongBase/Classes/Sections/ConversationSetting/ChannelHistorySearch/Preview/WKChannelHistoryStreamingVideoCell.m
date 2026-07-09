//
//  WKChannelHistoryStreamingVideoCell.m
//
//  流式视频 cell —— AVPlayer 直接吃 URL, 中央 loading 转圈, 首帧到位后隐藏封面。
//  行为对齐主流视频浏览器 (WeChat / iOS Photos):
//    · 进入 cell 立即起播 (autoplay), 不必等下载完
//    · 缓冲/未就绪 → 中央 UIActivityIndicator
//    · 首帧 (AVPlayerLayer.readyForDisplay=YES) → 隐藏封面
//    · 底部进度条: 播/停按钮 + elapsed / total 时间 + slider 支持拖拽 seek
//    · 单击 → 切换 播放/暂停 + 弹出/收起底部控件
//    · 播放中 3s 无操作 → 自动隐藏底部控件 (paused 时常驻)
//    · 播放到尾 → 循环重播
//    · cell 滚出屏幕 (prepareForReuse) → 暂停 + 拆 KVO / 通知
//    · App 进后台 → 暂停音频 (避免锁屏还在响)
//

#import "WKChannelHistoryStreamingVideoCell.h"
#import "WKChannelHistoryStreamingVideoData.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import "UIView+WK.h"
#import "UIView+WKCommon.h"
#import <AVFoundation/AVFoundation.h>

static void * kStreamingKVOStatus = &kStreamingKVOStatus;
static void * kStreamingKVOTimeControl = &kStreamingKVOTimeControl;
static void * kStreamingKVOReadyForDisplay = &kStreamingKVOReadyForDisplay;

// 底部控件常量 — 集中一处, 后续调节 spacing/字号只在这里改。
#define kBottomBarHeight     44.0f
#define kBottomBarHPadding   12.0f
#define kBottomBarBtnSize    32.0f
#define kBottomTimeLblW      44.0f  // "00:00" @ 11pt monospaced 够用
#define kBottomTimeLblLongW  62.0f  // "00:00:00" (>1h 视频)
#define kAutoHideAfterSec    3.0

@interface WKChannelHistoryStreamingVideoCell ()
@property (nonatomic, strong) UIImageView *coverImgView;
@property (nonatomic, strong) UIView *playerContainer;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;
@property (nonatomic, strong) UIView *playIconOverlay;   // 暂停时中央大播放三角
@property (nonatomic, assign) BOOL didAttachObservers;
@property (nonatomic, weak) AVPlayerItem *observedItem;

// 底部进度条
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIVisualEffectView *bottomBarBg;
@property (nonatomic, strong) UIButton *playPauseBtn;
@property (nonatomic, strong) UILabel *elapsedLbl;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *totalLbl;
@property (nonatomic, strong) id periodicObserver;   // AVPlayer time observer token
@property (nonatomic, assign) BOOL isDraggingSlider; // 拖拽期间不被 periodic 更新覆盖
@property (nonatomic, strong) NSTimer *autoHideTimer;
@property (nonatomic, assign) CGFloat durationSeconds; // 缓存 duration, 避免重复读 CMTime
@end

@implementation WKChannelHistoryStreamingVideoCell

@synthesize yb_cellData = _yb_cellData;
@synthesize yb_hideBrowser = _yb_hideBrowser;
@synthesize yb_hideStatusBar = _yb_hideStatusBar;
@synthesize yb_hideToolViews = _yb_hideToolViews;
@synthesize yb_selfPage = _yb_selfPage;
@synthesize yb_containerSize = _yb_containerSize;
@synthesize yb_currentOrientation = _yb_currentOrientation;
@synthesize yb_containerView = _yb_containerView;
@synthesize yb_auxiliaryViewHandler = _yb_auxiliaryViewHandler;
@synthesize yb_webImageMediator = _yb_webImageMediator;
@synthesize yb_currentPage = _yb_currentPage;
@synthesize yb_totalPage = _yb_totalPage;
@synthesize yb_cellIsInCenter = _yb_cellIsInCenter;
@synthesize yb_isTransitioning = _yb_isTransitioning;
@synthesize yb_isShowTransitioning = _yb_isShowTransitioning;
@synthesize yb_isHideTransitioning = _yb_isHideTransitioning;
@synthesize yb_isRotating = _yb_isRotating;
@synthesize yb_backView = _yb_backView;
@synthesize yb_collectionView = _yb_collectionView;

#pragma mark - init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = [UIColor blackColor];

        _coverImgView = [UIImageView new];
        _coverImgView.contentMode = UIViewContentModeScaleAspectFit;
        _coverImgView.clipsToBounds = YES;
        [self.contentView addSubview:_coverImgView];

        _playerContainer = [UIView new];
        _playerContainer.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_playerContainer];

        _loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        _loadingView.color = [UIColor whiteColor];
        _loadingView.hidesWhenStopped = YES;
        [self.contentView addSubview:_loadingView];

        _playIconOverlay = [self buildPlayIconOverlay];
        _playIconOverlay.hidden = YES;
        [self.contentView addSubview:_playIconOverlay];

        [self buildBottomBar];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(onTap)];
        [self.contentView addGestureRecognizer:tap];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                  selector:@selector(onAppDidEnterBackground)
                                                      name:UIApplicationDidEnterBackgroundNotification
                                                    object:nil];
    }
    return self;
}

- (UIView *)buildPlayIconOverlay {
    UIView *v = [UIView new];
    v.frame = CGRectMake(0, 0, 64, 64);
    v.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    v.layer.cornerRadius = 32;
    v.layer.masksToBounds = YES;
    // SF Symbol 系统 play.fill — 与 iOS 原生播放器 (AVPlayerViewController) 一致
    UIImageView *iv = [UIImageView new];
    iv.contentMode = UIViewContentModeCenter;
    iv.tintColor = [UIColor whiteColor];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:26
                                                                                            weight:UIImageSymbolWeightMedium];
        iv.image = [[UIImage systemImageNamed:@"play.fill" withConfiguration:cfg]
                     imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    iv.frame = v.bounds;
    [v addSubview:iv];
    return v;
}

- (void)buildBottomBar {
    _bottomBar = [UIView new];
    _bottomBar.backgroundColor = [UIColor clearColor];
    _bottomBar.hidden = YES; // 起播前隐藏, item 就绪后再显示
    [self.contentView addSubview:_bottomBar];

    // dark blur 半透明 0.3 — 与顶部 navbar 风格一致
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    _bottomBarBg = [[UIVisualEffectView alloc] initWithEffect:blur];
    _bottomBarBg.alpha = 0.3;
    [_bottomBar addSubview:_bottomBarBg];

    _playPauseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _playPauseBtn.tintColor = [UIColor whiteColor];
    // 默认给个 pause 图标, syncPlayPauseBtn 会按 timeControlStatus 覆盖
    [_playPauseBtn setImage:[self playerSymbol:@"pause.fill"] forState:UIControlStateNormal];
    [_playPauseBtn addTarget:self action:@selector(onPlayPauseBtnTap) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_playPauseBtn];

    UIFont *timeFont = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
    _elapsedLbl = [UILabel new];
    _elapsedLbl.font = timeFont;
    _elapsedLbl.textColor = [UIColor whiteColor];
    _elapsedLbl.textAlignment = NSTextAlignmentCenter;
    _elapsedLbl.text = @"--:--";
    [_bottomBar addSubview:_elapsedLbl];

    _totalLbl = [UILabel new];
    _totalLbl.font = timeFont;
    _totalLbl.textColor = [UIColor whiteColor];
    _totalLbl.textAlignment = NSTextAlignmentCenter;
    _totalLbl.text = @"--:--";
    [_bottomBar addSubview:_totalLbl];

    _slider = [UISlider new];
    _slider.minimumValue = 0;
    _slider.maximumValue = 1;
    _slider.value = 0;
    _slider.minimumTrackTintColor = [WKApp shared].config.themeColor;
    _slider.maximumTrackTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
    _slider.thumbTintColor = [UIColor whiteColor];
    [_slider addTarget:self action:@selector(onSliderTouchDown) forControlEvents:UIControlEventTouchDown];
    [_slider addTarget:self action:@selector(onSliderValueChanged) forControlEvents:UIControlEventValueChanged];
    [_slider addTarget:self action:@selector(onSliderTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [_bottomBar addSubview:_slider];
}

- (void)dealloc {
    [self teardownPlayer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.autoHideTimer invalidate];
}

#pragma mark - layout

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.contentView.bounds;
    self.coverImgView.frame = b;
    self.playerContainer.frame = b;
    self.playerLayer.frame = self.playerContainer.bounds;
    self.loadingView.center = CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b));
    self.playIconOverlay.center = CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b));

    // 底部条: 贴 safe area bottom 上方
    CGFloat safeBot = 0;
    if (@available(iOS 11.0, *)) {
        safeBot = UIApplication.sharedApplication.keyWindow.safeAreaInsets.bottom;
    }
    CGFloat barY = b.size.height - safeBot - kBottomBarHeight;
    self.bottomBar.frame = CGRectMake(0, barY, b.size.width, kBottomBarHeight + safeBot);
    self.bottomBarBg.frame = self.bottomBar.bounds;

    CGFloat timeLblW = self.durationSeconds >= 3600.0 ? kBottomTimeLblLongW : kBottomTimeLblW;
    CGFloat x = kBottomBarHPadding;
    self.playPauseBtn.frame = CGRectMake(x, 0, kBottomBarBtnSize, kBottomBarHeight);
    x = CGRectGetMaxX(self.playPauseBtn.frame) + 4.0f;
    self.elapsedLbl.frame = CGRectMake(x, 0, timeLblW, kBottomBarHeight);
    x = CGRectGetMaxX(self.elapsedLbl.frame) + 4.0f;
    CGFloat rightX = self.bottomBar.lim_width - kBottomBarHPadding - timeLblW;
    self.totalLbl.frame = CGRectMake(rightX, 0, timeLblW, kBottomBarHeight);
    CGFloat sliderX = x;
    CGFloat sliderW = rightX - sliderX - 8.0f;
    if (sliderW < 40) sliderW = 40; // 极窄屏兜底
    self.slider.frame = CGRectMake(sliderX, (kBottomBarHeight - 20) / 2.0f, sliderW, 20);
}

#pragma mark - <YBIBCellProtocol>

- (UIView *)yb_foregroundView {
    return self.coverImgView;
}

- (void)yb_pageChanged {
    // 页码变化后, 若本 cell 不再是中心项 → 暂停播放, 避免用户翻页后还在放音。
    BOOL isCenter = self.yb_cellIsInCenter ? self.yb_cellIsInCenter() : NO;
    if (!isCenter && self.player) {
        [self.player pause];
        [self syncPlayPauseBtn];
        [self refreshPlayIconVisibility];
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self teardownPlayer];
    self.coverImgView.image = nil;
    self.coverImgView.hidden = NO;
    self.playIconOverlay.hidden = YES;
    [self.loadingView stopAnimating];
    // 复位底部条状态
    self.bottomBar.hidden = YES;
    self.slider.value = 0;
    self.elapsedLbl.text = @"--:--";
    self.totalLbl.text = @"--:--";
    self.durationSeconds = 0;
    self.isDraggingSlider = NO;
    [self cancelAutoHideTimer];
}

- (void)setYb_cellData:(id<YBIBDataProtocol>)yb_cellData {
    _yb_cellData = yb_cellData;
    if (![yb_cellData isKindOfClass:[WKChannelHistoryStreamingVideoData class]]) return;
    WKChannelHistoryStreamingVideoData *data = (WKChannelHistoryStreamingVideoData *)yb_cellData;

    self.coverImgView.image = data.coverImage;
    self.coverImgView.hidden = (data.coverImage == nil);

    [self teardownPlayer];
    if (!data.videoURL) {
        // 无 URL: 只显示 cover + 一个错误 toast (不 spinner, 会一直转)。
        id<YBIBAuxiliaryViewHandler> aux = self.yb_auxiliaryViewHandler ? self.yb_auxiliaryViewHandler() : nil;
        [aux yb_showIncorrectToastWithContainer:self text:LLang(@"视频不可用")];
        return;
    }

    // 起播: AVPlayer 直接吃 URL (file:// 或 https://) — AVFoundation 内部会做流式 range
    // 请求 / HLS 处理。首帧到位前的空档由 spinner + cover 遮盖。
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:data.videoURL];
    self.player = [AVPlayer playerWithPlayerItem:item];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone; // 手动 loop
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playerLayer.frame = self.playerContainer.bounds;
    [self.playerContainer.layer addSublayer:self.playerLayer];

    [item addObserver:self forKeyPath:@"status" options:0 context:kStreamingKVOStatus];
    [self.player addObserver:self forKeyPath:@"timeControlStatus" options:0 context:kStreamingKVOTimeControl];
    [self.playerLayer addObserver:self forKeyPath:@"readyForDisplay" options:0 context:kStreamingKVOReadyForDisplay];
    self.observedItem = item;
    self.didAttachObservers = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(onItemDidPlayToEnd:)
                                                  name:AVPlayerItemDidPlayToEndTimeNotification
                                                object:item];

    // Slider 位置 → 定期回读 AVPlayer.currentTime 更新。0.5s 一次对拖拽预览体感够顺,
    // 又不至于耗 CPU。拖拽期由 isDraggingSlider 拦住不覆盖。
    __weak typeof(self) ws = self;
    self.periodicObserver = [self.player
        addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.5, NSEC_PER_SEC)
                                     queue:dispatch_get_main_queue()
                                usingBlock:^(CMTime time) {
        [ws refreshSliderFromPlayer];
    }];

    // 起播前 spinner 转起来 (readyForDisplay 或 status=readyToPlay 后再关闭)
    [self.loadingView startAnimating];
    self.playIconOverlay.hidden = YES;
    [self.player play];
    [self syncPlayPauseBtn];
    [self setNeedsLayout];
}

- (void)onAppDidEnterBackground {
    [self.player pause];
    [self syncPlayPauseBtn];
    [self refreshPlayIconVisibility];
    [self showBottomBarAnimated:YES]; // paused → 常驻显示
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (context != kStreamingKVOStatus
        && context != kStreamingKVOTimeControl
        && context != kStreamingKVOReadyForDisplay) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    // weak-strong + object == observed 双重保护 (PR #64 review Octo-Q + yujiawei
    // 共同 P2)。dispatch_async 会 retain block 里的 self, cell 在 dealloc 后
    // block 才 drain 会短暂延后释放; 更重要的是 prepareForReuse → teardownPlayer
    // 后再 setYb_cellData: 换新 item, 旧 KVO 的 in-flight callback 到 main 时
    // observedItem/player/playerLayer 已经是新的, 不 guard 会用错 item 的状态
    // 去改新 UI (提前 hide loading / 顶起进度条)。
    __weak typeof(self) weakSelf = self;
    id observedObject = object;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if ((context == kStreamingKVOStatus && observedObject != self.observedItem) ||
            (context == kStreamingKVOTimeControl && observedObject != self.player) ||
            (context == kStreamingKVOReadyForDisplay && observedObject != self.playerLayer)) {
            // 已被 teardown / 换 item, 老回调直接丢弃, 不动新 UI
            return;
        }
        [self refreshLoadingVisibility];
        [self syncPlayPauseBtn];
        if (context == kStreamingKVOReadyForDisplay && self.playerLayer.readyForDisplay) {
            self.coverImgView.hidden = YES;
        }
        if (context == kStreamingKVOStatus && self.observedItem.status == AVPlayerItemStatusReadyToPlay) {
            [self refreshDurationFromPlayer];
            [self showBottomBarAnimated:YES];
            [self scheduleAutoHideIfPlaying];
        }
        if (context == kStreamingKVOStatus && self.observedItem.status == AVPlayerItemStatusFailed) {
            [self.loadingView stopAnimating];
            id<YBIBAuxiliaryViewHandler> aux = self.yb_auxiliaryViewHandler ? self.yb_auxiliaryViewHandler() : nil;
            [aux yb_showIncorrectToastWithContainer:self text:LLang(@"视频加载失败")];
        }
        if (context == kStreamingKVOTimeControl) {
            // 播放 → 播完 3s 自动隐藏; 暂停 → 常驻显示
            if (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
                [self scheduleAutoHideIfPlaying];
            } else {
                [self cancelAutoHideTimer];
                [self showBottomBarAnimated:YES];
            }
        }
    });
}

- (void)refreshLoadingVisibility {
    if (!self.player) {
        [self.loadingView stopAnimating];
        return;
    }
    BOOL loading = NO;
    if (self.observedItem.status == AVPlayerItemStatusUnknown) loading = YES;
    // waitingToPlayAtSpecifiedRate = 因缓冲/无网/其它原因暂停等待
    if (self.player.timeControlStatus == AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate) loading = YES;
    if (loading) {
        [self.loadingView startAnimating];
        self.playIconOverlay.hidden = YES;
    } else {
        [self.loadingView stopAnimating];
        [self refreshPlayIconVisibility];
    }
}

- (void)refreshPlayIconVisibility {
    // 只在明确暂停时显示中央播放三角。播放中 / 加载中都藏起来。
    BOOL paused = (self.player.timeControlStatus == AVPlayerTimeControlStatusPaused);
    BOOL loading = (self.player.timeControlStatus == AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate);
    self.playIconOverlay.hidden = !(paused && !loading);
}

- (void)onItemDidPlayToEnd:(NSNotification *)note {
    if (note.object != self.observedItem) return;
    [self.player seekToTime:kCMTimeZero];
    [self.player play];
    [self syncPlayPauseBtn];
}

#pragma mark - progress bar helpers

- (void)refreshSliderFromPlayer {
    if (self.isDraggingSlider) return;
    if (!self.player) return;
    CMTime cur = self.player.currentTime;
    CGFloat curSec = CMTIME_IS_VALID(cur) ? CMTimeGetSeconds(cur) : 0;
    if (!isfinite(curSec) || curSec < 0) curSec = 0;
    self.elapsedLbl.text = [self formatSeconds:curSec];
    if (self.durationSeconds > 0) {
        self.slider.value = (float)MIN(1.0, curSec / self.durationSeconds);
    }
}

- (void)refreshDurationFromPlayer {
    CMTime dur = self.observedItem.duration;
    if (!CMTIME_IS_VALID(dur) || CMTIME_IS_INDEFINITE(dur)) return;
    CGFloat s = CMTimeGetSeconds(dur);
    if (!isfinite(s) || s <= 0) return;
    self.durationSeconds = s;
    self.totalLbl.text = [self formatSeconds:s];
    [self setNeedsLayout]; // 视频超过 1h, 时间标签宽度要变
}

- (NSString *)formatSeconds:(CGFloat)sec {
    if (!isfinite(sec) || sec < 0) sec = 0;
    NSInteger total = (NSInteger)sec;
    NSInteger h = total / 3600;
    NSInteger m = (total / 60) % 60;
    NSInteger s = total % 60;
    if (h > 0) return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)h, (long)m, (long)s];
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)m, (long)s];
}

- (void)syncPlayPauseBtn {
    if (!self.player) return;
    BOOL playing = (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying)
        || (self.player.timeControlStatus == AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate);
    [self.playPauseBtn setImage:[self playerSymbol:playing ? @"pause.fill" : @"play.fill"]
                        forState:UIControlStateNormal];
}

/// SF Symbol 播放器图标 (18pt medium) — iOS 13+ 都能用, 更早 iOS 返 nil 让按钮回落到无图。
- (UIImage *)playerSymbol:(NSString *)name {
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:18
                                                                                            weight:UIImageSymbolWeightMedium];
        return [[UIImage systemImageNamed:name withConfiguration:cfg]
                 imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return nil;
}

#pragma mark - slider events

- (void)onSliderTouchDown {
    self.isDraggingSlider = YES;
    [self cancelAutoHideTimer]; // 拖拽期间不隐藏
}

- (void)onSliderValueChanged {
    // 只更新左侧时间预览, 不真 seek — 松手才 seek, 拖拽体感更流畅 (省频繁 IO)
    if (self.durationSeconds > 0) {
        CGFloat previewSec = self.slider.value * self.durationSeconds;
        self.elapsedLbl.text = [self formatSeconds:previewSec];
    }
}

- (void)onSliderTouchUp {
    self.isDraggingSlider = NO;
    if (!self.player || self.durationSeconds <= 0) return;
    CGFloat target = self.slider.value * self.durationSeconds;
    CMTime targetTime = CMTimeMakeWithSeconds(target, NSEC_PER_SEC);
    // toleranceBefore/After = kCMTimeZero → 精确 seek (稍慢但准), 用户拖拽后期望"就到这"。
    [self.player seekToTime:targetTime
             toleranceBefore:kCMTimeZero
              toleranceAfter:kCMTimeZero];
    [self scheduleAutoHideIfPlaying];
}

- (void)onPlayPauseBtnTap {
    if (!self.player) return;
    if (self.player.timeControlStatus == AVPlayerTimeControlStatusPaused) {
        [self.player play];
    } else {
        [self.player pause];
    }
    [self syncPlayPauseBtn];
    [self refreshPlayIconVisibility];
}

#pragma mark - auto hide bottom bar

- (void)showBottomBarAnimated:(BOOL)animated {
    if (!self.player || self.observedItem.status != AVPlayerItemStatusReadyToPlay) return;
    if (!self.bottomBar.hidden && self.bottomBar.alpha >= 0.99) return;
    self.bottomBar.hidden = NO;
    if (animated) {
        [UIView animateWithDuration:0.2 animations:^{ self.bottomBar.alpha = 1.0; }];
    } else {
        self.bottomBar.alpha = 1.0;
    }
}

- (void)hideBottomBarAnimated {
    if (self.bottomBar.hidden) return;
    [UIView animateWithDuration:0.2 animations:^{
        self.bottomBar.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.bottomBar.hidden = YES;
        self.bottomBar.alpha = 1.0;
    }];
}

- (void)scheduleAutoHideIfPlaying {
    [self cancelAutoHideTimer];
    if (self.player.timeControlStatus != AVPlayerTimeControlStatusPlaying) return;
    __weak typeof(self) ws = self;
    self.autoHideTimer = [NSTimer scheduledTimerWithTimeInterval:kAutoHideAfterSec
                                                          repeats:NO
                                                            block:^(NSTimer *t) {
        [ws hideBottomBarAnimated];
    }];
}

- (void)cancelAutoHideTimer {
    [self.autoHideTimer invalidate];
    self.autoHideTimer = nil;
}

#pragma mark - tap

- (void)onTap {
    if (!self.player) return;
    // waiting 状态下不响应, 让 spinner 继续转; 用户可以稍后再点
    if (self.player.timeControlStatus == AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate) return;
    // 单击: 弹出/收起底部条; 播 ↔ 暂停 通过底部按钮或点中央播放三角来切
    if (self.bottomBar.hidden || self.bottomBar.alpha < 0.99) {
        [self showBottomBarAnimated:YES];
        [self scheduleAutoHideIfPlaying];
    } else {
        // 已显示: 播放中 → 隐藏; 暂停中 → 保持
        if (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
            [self hideBottomBarAnimated];
            [self cancelAutoHideTimer];
        } else {
            // 暂停时二次点 → 恢复播放 (让用户还能靠"点视频"起播, 不必非得点小按钮)
            [self.player play];
            [self syncPlayPauseBtn];
            [self scheduleAutoHideIfPlaying];
        }
    }
    [self refreshPlayIconVisibility];
}

#pragma mark - teardown

- (void)teardownPlayer {
    if (self.didAttachObservers) {
        @try { [self.observedItem removeObserver:self forKeyPath:@"status" context:kStreamingKVOStatus]; }
        @catch (__unused NSException *e) {}
        @try { [self.player removeObserver:self forKeyPath:@"timeControlStatus" context:kStreamingKVOTimeControl]; }
        @catch (__unused NSException *e) {}
        @try { [self.playerLayer removeObserver:self forKeyPath:@"readyForDisplay" context:kStreamingKVOReadyForDisplay]; }
        @catch (__unused NSException *e) {}
        self.didAttachObservers = NO;
    }
    if (self.periodicObserver && self.player) {
        [self.player removeTimeObserver:self.periodicObserver];
    }
    self.periodicObserver = nil;
    if (self.observedItem) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.observedItem];
        self.observedItem = nil;
    }
    [self.player pause];
    self.player = nil;
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
    [self cancelAutoHideTimer];
}

@end
