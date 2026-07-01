//
//  WKChannelHistoryStreamingVideoCell.m
//
//  流式视频 cell —— AVPlayer 直接吃 URL, 中央 loading 转圈, 首帧到位后隐藏封面。
//  行为对齐主流视频浏览器 (WeChat / 抖音):
//    · 进入 cell 立即起播 (autoplay), 不必等下载完
//    · 缓冲/未就绪 → 中央 UIActivityIndicator
//    · 首帧 (AVPlayerLayer.readyForDisplay=YES) → 隐藏封面
//    · 单击 → 切换 播放/暂停
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

@interface WKChannelHistoryStreamingVideoCell ()
@property (nonatomic, strong) UIImageView *coverImgView;
@property (nonatomic, strong) UIView *playerContainer;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;
@property (nonatomic, strong) UIView *playIconOverlay;   // 暂停时中央大播放三角
@property (nonatomic, assign) BOOL didAttachObservers;
@property (nonatomic, weak) AVPlayerItem *observedItem;
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
    UILabel *tri = [UILabel new];
    tri.text = @"▶";
    tri.font = [UIFont systemFontOfSize:28 weight:UIFontWeightMedium];
    tri.textColor = [UIColor whiteColor];
    tri.textAlignment = NSTextAlignmentCenter;
    tri.frame = CGRectMake(4, 0, 64, 64); // 三角形视觉重心偏左, 右移 4pt 让它居中
    [v addSubview:tri];
    return v;
}

- (void)dealloc {
    [self teardownPlayer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

    // 起播前 spinner 转起来 (readyForDisplay 或 status=readyToPlay 后再关闭)
    [self.loadingView startAnimating];
    self.playIconOverlay.hidden = YES;
    [self.player play];
    [self setNeedsLayout];
}

- (void)onAppDidEnterBackground {
    [self.player pause];
    [self refreshPlayIconVisibility];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshLoadingVisibility];
        if (context == kStreamingKVOReadyForDisplay && self.playerLayer.readyForDisplay) {
            self.coverImgView.hidden = YES;
        }
        if (context == kStreamingKVOStatus && self.observedItem.status == AVPlayerItemStatusFailed) {
            [self.loadingView stopAnimating];
            id<YBIBAuxiliaryViewHandler> aux = self.yb_auxiliaryViewHandler ? self.yb_auxiliaryViewHandler() : nil;
            [aux yb_showIncorrectToastWithContainer:self text:LLang(@"视频加载失败")];
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
}

#pragma mark - tap

- (void)onTap {
    if (!self.player) return;
    if (self.player.timeControlStatus == AVPlayerTimeControlStatusPaused) {
        [self.player play];
    } else if (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
        [self.player pause];
    }
    // waiting 状态下不响应, 让 spinner 继续转; 用户可以稍后再点
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
}

@end
