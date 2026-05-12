//
//  WKVoiceInputView.m
//  WuKongBase
//

#import "WKVoiceInputView.h"
#import "WKVoiceInputService.h"
#import <AVFoundation/AVFoundation.h>
#import "WuKongBase.h"
#import "WKApp.h"
#import "WKNavigationManager.h"
#import "UIView+WKCommon.h"
#import "WKResource.h"
#import "WKInputMentionCache.h"

NSNotificationName const WKVoiceInputCancelRecordingNotification = @"WKVoiceInputCancelRecordingNotification";

// 按钮尺寸（缩小一倍）
static CGFloat const kPillWidth  = 120.0;
static CGFloat const kPillHeight = 46.0;
static CGFloat const kCircleBaseSize = 80.0; // 基础圆形大小，会随音量动态变化

@interface WKVoiceInputView ()

// UI
@property (nonatomic, strong) UIButton *micButton;
@property (nonatomic, strong) UILabel  *statusLabel;
@property (nonatomic, strong) UILabel  *thinkingLabel;
@property (nonatomic, strong) UIButton *bottomButton;
@property (nonatomic, strong) UIButton *atButton;
@property (nonatomic, strong) UIButton *spaceButton;
@property (nonatomic, strong) UIButton *deleteButton;

// 波形（在 micButton 内部，Transcribing前的等待用）
@property (nonatomic, strong) UIView *waveContainer;
@property (nonatomic, strong) NSMutableArray<UIView *> *waveBars;

// 圆点（录音等待）
@property (nonatomic, strong) UIView *dotsContainer;

// 脉冲光晕
@property (nonatomic, strong) UIView *glowView;

// 录音蒙层（长按时全屏覆盖）
@property (nonatomic, strong) UIView *recordingOverlay;
@property (nonatomic, strong) CAGradientLayer *overlayGradient;
@property (nonatomic, strong) CAGradientLayer *touchGlowLayer;
@property (nonatomic, strong) NSMutableArray<CAGradientLayer *> *touchTrailLayers;
@property (nonatomic, strong) UILabel *overlayHintLabel;
@property (nonatomic, strong) UIView *overlayWaveContainer;
@property (nonatomic, strong) NSMutableArray<UIView *> *overlayWaveBars;

// 长按手势
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGesture;
@property (nonatomic, assign) CGPoint touchStartPoint;

// Thinking 渐进填充
@property (nonatomic, strong) UIView *thinkingFillView;
@property (nonatomic, strong) NSTimer *thinkingTimer;
@property (nonatomic, assign) CGFloat thinkingProgress; // 0~1
@property (nonatomic, assign) BOOL thinkingCompleting;  // 网络已返回，正在填满
@property (nonatomic, copy) NSString *pendingTranscribeText;
@property (nonatomic, assign) BOOL pendingTranscribeShouldReplace;

// 录音
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, copy)   NSString *recordFilePath;
@property (nonatomic, strong) NSTimer  *recordTimer;
@property (nonatomic, strong) NSTimer  *waveformTimer;
@property (nonatomic, assign) NSInteger recordSeconds;

@property (nonatomic, copy) NSString *previousAudioCategory;
@property (nonatomic, assign) AVAudioSessionCategoryOptions previousAudioCategoryOptions;

// 状态
@property (nonatomic, assign) WKVoiceInputState state;
@property (nonatomic, assign) BOOL isStartingRecording;
@property (nonatomic, assign) BOOL hasReceivedAudio;
@property (nonatomic, assign) float currentPower; // 当前音量 0~1

@end

@implementation WKVoiceInputView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _maxDuration = 60;
        _state = WKVoiceInputStateIdle;
        _isStartingRecording = NO;
        _hasReceivedAudio = NO;
        _currentPower = 0;
        [self setupUI];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionInterrupted:)
                                                     name:AVAudioSessionInterruptionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onCancelRecordingNotification:)
                                                     name:WKVoiceInputCancelRecordingNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.recordTimer invalidate];
    [self.waveformTimer invalidate];
    if (self.audioRecorder.isRecording) {
        [self.audioRecorder stop];
        [self restoreAudioSession];
    }
    [self cleanupRecordFile];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.backgroundColor = [WKApp shared].config.backgroundColor;

    // 辅助按钮（右上角，更浅灰色）
    _atButton     = [self iconButtonWithImage:@"Conversation/Toolbar/VoiceAt" action:@selector(onAtTapped)];
    _spaceButton  = [self iconButtonWithImage:@"Conversation/Toolbar/VoiceSpace" action:@selector(onSpaceTapped)];
    _deleteButton = [self iconButtonWithImage:@"Conversation/Toolbar/VoiceDelete" action:@selector(onDeleteTapped)];

    // 状态标签
    _statusLabel = [[UILabel alloc] init];
    _statusLabel.text = LLang(@"按住 说话");
    _statusLabel.textColor = [UIColor colorWithRed:0.45 green:0.45 blue:0.47 alpha:1.0];
    _statusLabel.font = [UIFont systemFontOfSize:14];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_statusLabel];

    // 脉冲光晕（不拦截点击）
    _glowView = [[UIView alloc] init];
    _glowView.backgroundColor = [UIColor colorWithRed:0.82 green:0.82 blue:0.84 alpha:0.4];
    _glowView.hidden = YES;
    _glowView.userInteractionEnabled = NO;
    [self addSubview:_glowView];

    // 主按钮
    _micButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _micButton.backgroundColor = [WKApp shared].config.themeColor;
    _micButton.clipsToBounds = YES;
    _micButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    _micButton.imageEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    [self addSubview:_micButton];

    // 长按手势（替代点击）
    _longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    _longPressGesture.minimumPressDuration = 0.15; // 150ms防误触
    [_micButton addGestureRecognizer:_longPressGesture];

    UIImage *micImage = [WKApp.shared loadImage:@"Conversation/Toolbar/MicIdle2" moduleID:@"WuKongBase"];
    if (micImage) [_micButton setImage:micImage forState:UIControlStateNormal];

    // 波形（在 micButton 内部）
    _waveContainer = [[UIView alloc] init];
    _waveContainer.hidden = YES;
    _waveContainer.userInteractionEnabled = NO;
    [_micButton addSubview:_waveContainer];
    [self setupWaveBars];

    // 圆点（在 micButton 内部）
    _dotsContainer = [[UIView alloc] init];
    _dotsContainer.hidden = YES;
    _dotsContainer.userInteractionEnabled = NO;
    [_micButton addSubview:_dotsContainer];
    [self setupDots];

    // Thinking 标签
    _thinkingLabel = [[UILabel alloc] init];
    _thinkingLabel.text = @"Thinking";
    _thinkingLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    _thinkingLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    _thinkingLabel.textAlignment = NSTextAlignmentCenter;
    _thinkingLabel.hidden = YES;
    [_micButton addSubview:_thinkingLabel];

    // 底部按钮
    _bottomButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_bottomButton setTitle:LLang(@"换行") forState:UIControlStateNormal];
    _bottomButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [_bottomButton setTitleColor:[UIColor colorWithRed:0.45 green:0.45 blue:0.47 alpha:1.0] forState:UIControlStateNormal];
    _bottomButton.backgroundColor = [UIColor colorWithRed:0.88 green:0.88 blue:0.90 alpha:1.0];
    _bottomButton.layer.cornerRadius = 16;
    [_bottomButton addTarget:self action:@selector(onBottomButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_bottomButton];

    [self applyIdleLayout:NO];
}

- (void)setupWaveBars {
    _waveBars = [NSMutableArray array];
    for (NSInteger i = 0; i < 9; i++) {
        UIView *bar = [[UIView alloc] init];
        bar.backgroundColor = [UIColor whiteColor];
        bar.layer.cornerRadius = 1.5;
        [_waveContainer addSubview:bar];
        [_waveBars addObject:bar];
    }
}

- (void)setupDots {
    for (NSInteger i = 0; i < 7; i++) {
        UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 4, 4)];
        dot.backgroundColor = [UIColor whiteColor];
        dot.layer.cornerRadius = 2;
        [_dotsContainer addSubview:dot];
    }
}

- (UIButton *)iconButtonWithImage:(NSString *)imageName action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.backgroundColor = [UIColor colorWithRed:0.88 green:0.88 blue:0.90 alpha:1.0];
    btn.layer.cornerRadius = 20;
    btn.clipsToBounds = YES;
    btn.imageEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *img = [WKApp.shared loadImage:imageName moduleID:@"WuKongBase"];
    if (img) [btn setImage:img forState:UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:btn];
    return btn;
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = self.bounds.size.width;
    CGFloat btnSize = 40;
    CGFloat rightMargin = 16;
    CGFloat topMargin = 10;
    CGFloat btnGap = 8;

    // 辅助按钮
    _deleteButton.frame = CGRectMake(w - rightMargin - btnSize, topMargin, btnSize, btnSize);
    _spaceButton.frame  = CGRectMake(CGRectGetMinX(_deleteButton.frame) - btnGap - btnSize, topMargin, btnSize, btnSize);
    _atButton.frame     = CGRectMake(CGRectGetMinX(_spaceButton.frame) - btnGap - btnSize, topMargin, btnSize, btnSize);

    // 状态标签（录音时上移到辅助按钮区域）
    CGFloat statusY = (_state == WKVoiceInputStateRecording)
        ? topMargin + 20
        : topMargin + btnSize + 12;
    _statusLabel.frame = CGRectMake(0, statusY, w, 18);

    // 主按钮（固定位置，不跟随状态标签）
    CGFloat micY = topMargin + btnSize + 12 + 18 + 10;
    CGFloat micW, micH;
    if (_state == WKVoiceInputStateRecording) {
        // 录音时大小随音量动态变化
        CGFloat powerScale = 1.0 + _currentPower * 0.25; // 1.0 ~ 1.25
        CGFloat dynamicSize = kCircleBaseSize * powerScale;
        micW = micH = dynamicSize;
    } else {
        micW = kPillWidth;
        micH = kPillHeight;
    }
    _micButton.frame = CGRectMake(w/2 - micW/2, micY, micW, micH);
    _micButton.layer.cornerRadius = micH / 2.0;

    // 光晕（跟随按钮大小变化）
    if (_state == WKVoiceInputStateRecording) {
        CGFloat glowExtra = 20 + _currentPower * 15; // 20~35
        CGFloat glowSize = micW + glowExtra;
        CGFloat glowY = micY - glowExtra / 2.0;
        _glowView.frame = CGRectMake(w/2 - glowSize/2, glowY, glowSize, glowSize);
        _glowView.layer.cornerRadius = glowSize / 2.0;
    }

    // 波形在按钮内部
    CGFloat waveW = micW * 0.6, waveH = micH * 0.5;
    _waveContainer.frame = CGRectMake(micW/2 - waveW/2, micH/2 - waveH/2, waveW, waveH);
    [self layoutWaveBarsInContainer];

    // 圆点在按钮内部
    CGFloat dotSize = 4;
    CGFloat dotGap = 5;
    CGFloat dotsW = 7 * dotSize + 6 * dotGap;
    _dotsContainer.frame = CGRectMake(micW/2 - dotsW/2, micH/2 - dotSize/2, dotsW, dotSize);
    [self layoutDotsInContainer];

    // Thinking
    _thinkingLabel.frame = CGRectMake(0, 0, micW, micH);
    if (_thinkingFillView) {
        _thinkingFillView.frame = CGRectMake(0, 0, _thinkingFillView.frame.size.width, micH);
    }

    // 底部按钮（下移间距）
    CGFloat bottomY = CGRectGetMaxY(_micButton.frame) + 24;
    _bottomButton.frame = CGRectMake(w/2 - 50, bottomY, 100, 32);
}

- (void)layoutWaveBarsInContainer {
    CGFloat barWidth = 3;
    CGFloat containerW = _waveContainer.bounds.size.width;
    CGFloat containerH = _waveContainer.bounds.size.height;
    if (containerW <= 0) return;
    CGFloat gap = (containerW - barWidth * _waveBars.count) / (_waveBars.count - 1);
    for (NSInteger i = 0; i < (NSInteger)_waveBars.count; i++) {
        CGFloat x = i * (barWidth + gap);
        CGFloat h = 8;
        _waveBars[i].frame = CGRectMake(x, (containerH - h) / 2, barWidth, h);
    }
}

- (void)layoutDotsInContainer {
    NSArray<UIView *> *dots = _dotsContainer.subviews;
    CGFloat dotSize = 4, dotGap = 5;
    for (NSInteger i = 0; i < (NSInteger)dots.count; i++) {
        dots[i].frame = CGRectMake(i * (dotSize + dotGap), 0, dotSize, dotSize);
    }
}

#pragma mark - State Machine

- (void)setState:(WKVoiceInputState)state {
    WKVoiceInputState oldState = _state;
    _state = state;

    void (^changes)(void) = ^{
        switch (state) {
            case WKVoiceInputStateIdle: [self applyIdleLayout:YES]; break;
            case WKVoiceInputStateRecording:
                [self applyRecordingLayout:YES];
                if (oldState == WKVoiceInputStateCancelling) {
                    // 从取消恢复到录音：蒙层切回蓝色
                    [self applyOverlayRecordingStyle];
                }
                break;
            case WKVoiceInputStateCancelling:
                // 切到取消模式：蒙层变红（不停止录音）
                [self applyOverlayCancellingStyle];
                break;
            case WKVoiceInputStateTranscribing: [self applyTranscribingLayout:YES]; break;
        }
        [self setNeedsLayout];
        [self layoutIfNeeded];
    };

    if (oldState != state) {
        if ((oldState == WKVoiceInputStateRecording && state == WKVoiceInputStateCancelling) ||
            (oldState == WKVoiceInputStateCancelling && state == WKVoiceInputStateRecording)) {
            // Recording ↔ Cancelling：蒙层颜色 0.25秒过渡
            [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut
                             animations:changes completion:nil];
        } else {
            [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5
                                options:UIViewAnimationOptionCurveEaseInOut animations:changes completion:nil];
        }
    } else {
        changes();
    }
}

- (void)applyIdleLayout:(BOOL)animated {
    _micButton.hidden = NO;
    _micButton.backgroundColor = [WKApp shared].config.themeColor;
    _micButton.enabled = YES;
    _micButton.alpha = 1.0;
    _micButton.imageEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    UIImage *img = [WKApp.shared loadImage:@"Conversation/Toolbar/MicIdle2" moduleID:@"WuKongBase"];
    if (img) [_micButton setImage:img forState:UIControlStateNormal];
    _micButton.imageView.hidden = NO;

    _statusLabel.text = LLang(@"按住 说话");
    _statusLabel.textColor = [UIColor colorWithRed:0.45 green:0.45 blue:0.47 alpha:1.0];
    _statusLabel.font = [UIFont systemFontOfSize:14];
    _statusLabel.hidden = NO;

    _atButton.hidden = NO; _spaceButton.hidden = NO; _deleteButton.hidden = NO;
    _bottomButton.hidden = NO;
    [_bottomButton setTitle:LLang(@"换行") forState:UIControlStateNormal];

    _waveContainer.hidden = YES; _dotsContainer.hidden = YES;
    _glowView.hidden = YES; _thinkingLabel.hidden = YES;

    [self stopThinkingAnimation];

    // 投递待发送的转写文本
    if (self.pendingTranscribeText.length > 0) {
        NSString *text = self.pendingTranscribeText;
        BOOL shouldReplace = self.pendingTranscribeShouldReplace;
        self.pendingTranscribeText = nil;
        self.pendingTranscribeShouldReplace = NO;

        // 解析 @mention 标记
        NSArray<WKChannelMember *> *members = nil;
        if ([self.delegate respondsToSelector:@selector(voiceInputChannelMembers)]) {
            members = [self.delegate voiceInputChannelMembers];
        }

        if (members.count > 0) {
            NSMutableArray<WKInputMentionItem *> *mentions = [NSMutableArray array];
            NSString *parsed = [self parseMentionMarkers:text members:members mentions:mentions];

            NSLog(@"[VoiceInput] @mention parsing: found %lu mentions in \"%@\"",
                  (unsigned long)mentions.count, text);
            for (WKInputMentionItem *m in mentions) {
                NSLog(@"[VoiceInput] mention: uid=%@, name=%@", m.uid, m.name);
            }

            if (mentions.count > 0 &&
                [self.delegate respondsToSelector:@selector(voiceInputDidTranscribe:mentions:shouldReplace:)]) {
                [self.delegate voiceInputDidTranscribe:parsed mentions:mentions shouldReplace:shouldReplace];
            } else if ([self.delegate respondsToSelector:@selector(voiceInputDidTranscribe:shouldReplace:)]) {
                [self.delegate voiceInputDidTranscribe:text shouldReplace:shouldReplace];
            }
        } else {
            if ([self.delegate respondsToSelector:@selector(voiceInputDidTranscribe:shouldReplace:)]) {
                [self.delegate voiceInputDidTranscribe:text shouldReplace:shouldReplace];
            }
        }
    }
}

- (void)applyRecordingLayout:(BOOL)animated {
    // 录音状态下隐藏所有面板内元素（录音UI在蒙层中显示）
    _micButton.hidden = YES;
    _statusLabel.hidden = YES;
    _atButton.hidden = YES; _spaceButton.hidden = YES; _deleteButton.hidden = YES;
    _bottomButton.hidden = YES;
    _thinkingLabel.hidden = YES; _glowView.hidden = YES;
    _dotsContainer.hidden = YES; _waveContainer.hidden = YES;

    _hasReceivedAudio = NO;
    [self stopThinkingAnimation];
}

- (void)applyTranscribingLayout:(BOOL)animated {
    // 转写中：恢复显示micButton（录音时被隐藏了）
    _micButton.hidden = NO;
    UIColor *themeColor = [WKApp shared].config.themeColor;
    CGFloat r, g, b, a;
    [themeColor getRed:&r green:&g blue:&b alpha:&a];
    _micButton.backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:0.6];
    _micButton.enabled = NO;
    _micButton.alpha = 1.0;
    [_micButton setImage:nil forState:UIControlStateNormal];
    _micButton.imageView.hidden = YES;

    _statusLabel.hidden = YES;
    _atButton.hidden = YES; _spaceButton.hidden = YES; _deleteButton.hidden = YES;
    _bottomButton.hidden = YES;
    _waveContainer.hidden = YES; _dotsContainer.hidden = YES; _glowView.hidden = YES;

    _thinkingLabel.hidden = NO;
    [self startThinkingAnimation];
}

#pragma mark - Thinking Animation（先快后慢渐进填充）

- (void)startThinkingAnimation {
    [self stopThinkingAnimation];

    _thinkingFillView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, kPillHeight)];
    _thinkingFillView.backgroundColor = [WKApp shared].config.themeColor;
    _thinkingFillView.userInteractionEnabled = NO;
    [_micButton insertSubview:_thinkingFillView atIndex:0];

    _thinkingProgress = 0;
    _thinkingCompleting = NO;

    // 用定时器驱动随机步进，模拟真实网络加载
    __weak typeof(self) weakSelf = self;
    _thinkingTimer = [NSTimer scheduledTimerWithTimeInterval:0.06 repeats:YES block:^(NSTimer *t) {
        [weakSelf tickThinkingProgress];
    }];
}

- (void)tickThinkingProgress {
    if (_thinkingCompleting) {
        // 网络已返回，快速平滑填满到 100%
        CGFloat remaining = 1.0 - _thinkingProgress;
        _thinkingProgress += remaining * 0.15; // 每 tick 吃掉剩余的 15%
        if (_thinkingProgress >= 0.995) {
            _thinkingProgress = 1.0;
            [self.thinkingTimer invalidate]; self.thinkingTimer = nil;
            [self updateThinkingFillWidth];
            // 填满后切回 idle
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.state = WKVoiceInputStateIdle;
            });
            return;
        }
    } else if (_thinkingProgress < 0.8) {
        // 阶段1：快速冲到 80%，带随机波动
        CGFloat baseStep = 0.04 + (arc4random_uniform(30) / 1000.0); // 0.04~0.07
        // 越接近 80% 越慢
        CGFloat slowdown = 1.0 - (_thinkingProgress / 0.8) * 0.5;
        _thinkingProgress += baseStep * slowdown;
        if (_thinkingProgress > 0.8) _thinkingProgress = 0.8;
    } else if (_thinkingProgress < 0.95) {
        // 阶段2：缓慢爬升到 95%，随机抖动
        CGFloat step = 0.002 + (arc4random_uniform(30) / 10000.0); // 0.002~0.005
        // 偶尔停顿一下（30% 概率不动）
        if (arc4random_uniform(100) > 30) {
            _thinkingProgress += step;
        }
        if (_thinkingProgress > 0.95) _thinkingProgress = 0.95;
    }
    // 超过 95% 不再自动增长，等网络返回

    [self updateThinkingFillWidth];
}

- (void)updateThinkingFillWidth {
    CGFloat targetWidth = kPillWidth * _thinkingProgress;
    [UIView animateWithDuration:0.06 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.thinkingFillView.frame = CGRectMake(0, 0, targetWidth, kPillHeight);
    } completion:nil];
}

- (void)completeThinkingAnimation {
    // 标记网络已返回，定时器会自动快速填满
    _thinkingCompleting = YES;
}

- (void)stopThinkingAnimation {
    [_thinkingTimer invalidate]; _thinkingTimer = nil;
    [_thinkingFillView removeFromSuperview];
    _thinkingFillView = nil;
    _thinkingProgress = 0;
    _thinkingCompleting = NO;
}

#pragma mark - Recording

- (void)startRecording {
    if (self.isStartingRecording) return;
    self.isStartingRecording = YES;

    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isStartingRecording = NO;
            if (!granted) { [self showPermissionAlert]; return; }
            // 权限弹窗期间手指已松开，不再开始录音（否则会卡在录音画面无法退出）
            if (self.longPressGesture.state != UIGestureRecognizerStateChanged &&
                self.longPressGesture.state != UIGestureRecognizerStateBegan) {
                return;
            }
            [self doStartRecording];
        });
    }];
}

- (void)doStartRecording {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    self.previousAudioCategory = session.category;
    self.previousAudioCategoryOptions = session.categoryOptions;
    // 显式指定 ModeDefault，防止其他模块（如语音转文字的 Measurement 模式）残留影响音量
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
                    mode:AVAudioSessionModeDefault
                 options:0
                   error:nil];
    [session setActive:YES error:nil];

    NSString *tempDir = NSTemporaryDirectory();
    self.recordFilePath = [tempDir stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"voice_input_%lld.m4a",
                            (long long)([[NSDate date] timeIntervalSince1970] * 1000)]];

    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC), AVSampleRateKey: @(16000.0),
        AVNumberOfChannelsKey: @(1), AVEncoderAudioQualityKey: @(AVAudioQualityHigh),
    };

    NSError *error;
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:self.recordFilePath]
                                                     settings:settings error:&error];
    if (error) {
        [self showHUDWithHide:LLang(@"录音初始化失败")];
        [self restoreAudioSession]; return;
    }

    self.audioRecorder.meteringEnabled = YES;
    if (![self.audioRecorder prepareToRecord] || ![self.audioRecorder record]) {
        [self showHUDWithHide:LLang(@"录音启动失败")];
        [self restoreAudioSession]; return;
    }

    self.recordSeconds = 0;
    self.currentPower = 0;
    __weak typeof(self) weakSelf = self;
    self.recordTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) { [weakSelf updateTimer]; }];
    self.waveformTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *t) { [weakSelf updateWaveform]; }];

    self.state = WKVoiceInputStateRecording;

    // 录音开始时预取语音上下文
    [[WKVoiceInputService shared] prefetchVoiceContext];

    // 显示录音蒙层
    [self showRecordingOverlay];

    if ([self.delegate respondsToSelector:@selector(voiceInputRecordingDidStart)]) {
        [self.delegate voiceInputRecordingDidStart];
    }
}

- (void)stopRecordingAndTranscribe {
    [self invalidateTimers];
    if (!self.audioRecorder.isRecording) return;

    NSTimeInterval duration = self.audioRecorder.currentTime;
    [self.audioRecorder stop];
    [self restoreAudioSession];

    if ([self.delegate respondsToSelector:@selector(voiceInputRecordingDidStop)]) {
        [self.delegate voiceInputRecordingDidStop];
    }

    if (duration < 1.0) {
        [self showHUDWithHide:LLang(@"说话时间太短")];
        self.state = WKVoiceInputStateIdle;
        [self cleanupRecordFile]; return;
    }

    self.state = WKVoiceInputStateTranscribing;

    NSData *audioData = [NSData dataWithContentsOfFile:self.recordFilePath];
    if (!audioData || audioData.length == 0) {
        self.state = WKVoiceInputStateIdle;
        [self cleanupRecordFile]; return;
    }

    NSString *contextText = nil;
    if ([self.delegate respondsToSelector:@selector(voiceInputCurrentText)]) {
        contextText = [self.delegate voiceInputCurrentText];
    }

    __weak typeof(self) weakSelf = self;

    // 等待预取的语音上下文完成，再发起转写
    [[WKVoiceInputService shared] getVoiceContextWithCompletion:^(NSString *voiceContext) {
        // 拆分上下文：personalContext 来自预取，chatContext 来自 delegate
        NSString *personalContext = voiceContext;
        NSString *chatContext = nil;
        NSString *memberContext = nil;
        NSString *fullContext = nil;
        if ([weakSelf.delegate respondsToSelector:@selector(voiceInputChatContext)]) {
            fullContext = [weakSelf.delegate voiceInputChatContext];
            if (fullContext) {
                // voiceInputChatContext 返回的格式：聊天成员：xxx\n[发送者]: yyy
                // 拆分成 memberContext 和 chatContext
                NSRange memberRange = [fullContext rangeOfString:@"聊天成员："];
                if (memberRange.location != NSNotFound) {
                    NSRange newlineRange = [fullContext rangeOfString:@"\n"];
                    if (newlineRange.location != NSNotFound) {
                        memberContext = [fullContext substringToIndex:newlineRange.location];
                        chatContext = [fullContext substringFromIndex:newlineRange.location + 1];
                    } else {
                        memberContext = fullContext;
                    }
                } else {
                    chatContext = fullContext;
                }
            }
        }

        // YUJ-420 R4 fix (lml2468 Critical privacy): 不打用户 context 内容，仅 DEBUG metadata。
#if DEBUG
        NSLog(@"[VoiceInputView] context collected: delegate=%@ full.len=%lu member.len=%lu chat.len=%lu personal.len=%lu contextText.len=%lu",
              [weakSelf.delegate respondsToSelector:@selector(voiceInputChatContext)] ? @"Y" : @"N",
              (unsigned long)fullContext.length,
              (unsigned long)memberContext.length,
              (unsigned long)chatContext.length,
              (unsigned long)personalContext.length,
              (unsigned long)contextText.length);
#endif

        [[WKVoiceInputService shared] transcribeAudio:audioData
                                          contextText:contextText
                                          chatContext:chatContext
                                      personalContext:personalContext
                                        memberContext:memberContext
                                           completion:^(WKVoiceInputResult *result, NSError *error) {
        [weakSelf cleanupRecordFile];
        if (error || result.text.length == 0) {
            [weakSelf showHUDWithHide:LLang(@"语音识别失败，请重试")];
            weakSelf.state = WKVoiceInputStateIdle;
            return;
        }
        BOOL shouldReplace = (contextText.length > 0);
        // 保存文本，等 thinking 动画完成后再写入输入框
        weakSelf.pendingTranscribeText = result.text;
        weakSelf.pendingTranscribeShouldReplace = shouldReplace;
        [weakSelf completeThinkingAnimation];
        }];
    }];
}

- (void)cancelRecording {
    [self invalidateTimers];
    if (self.audioRecorder.isRecording) [self.audioRecorder stop];
    [self cleanupRecordFile];
    [self restoreAudioSession];
    if ([self.delegate respondsToSelector:@selector(voiceInputRecordingDidStop)]) {
        [self.delegate voiceInputRecordingDidStop];
    }
    self.state = WKVoiceInputStateIdle;
}

- (void)restoreAudioSession {
    if (self.previousAudioCategory) {
        [[AVAudioSession sharedInstance] setCategory:self.previousAudioCategory
                                        withOptions:self.previousAudioCategoryOptions error:nil];
        self.previousAudioCategory = nil;
    }
    [[AVAudioSession sharedInstance] setActive:NO
                                  withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (void)invalidateTimers {
    [self.recordTimer invalidate]; self.recordTimer = nil;
    [self.waveformTimer invalidate]; self.waveformTimer = nil;
}

- (void)cleanupRecordFile {
    if (self.recordFilePath) {
        [[NSFileManager defaultManager] removeItemAtPath:self.recordFilePath error:nil];
        self.recordFilePath = nil;
    }
}

#pragma mark - Timer & Waveform

- (void)updateTimer {
    self.recordSeconds++;
    if (self.recordSeconds >= self.maxDuration) {
        [self hideRecordingOverlay];
        [self stopRecordingAndTranscribe];
    }
}

- (void)updateWaveform {
    if ((self.state != WKVoiceInputStateRecording && self.state != WKVoiceInputStateCancelling) || !self.audioRecorder) return;
    [self.audioRecorder updateMeters];
    float power = [self.audioRecorder averagePowerForChannel:0];
    float normalizedPower = (power + 40) / 40.0;
    normalizedPower = MAX(0, MIN(1, normalizedPower));

    static float const kSilenceThreshold = 0.08;
    if (normalizedPower < kSilenceThreshold) {
        normalizedPower = 0;
    }
    _currentPower = normalizedPower;

    // 有明显音频时从圆点切换为波形（按钮内部）
    if (!_hasReceivedAudio && normalizedPower > 0.15) {
        _hasReceivedAudio = YES;
        _dotsContainer.hidden = YES;
        _waveContainer.hidden = NO;
    }

    // 动态更新按钮和光晕大小
    [UIView animateWithDuration:0.1 animations:^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
    }];

    // 更新蒙层呼吸动画和蒙层波形
    [self updateOverlayBreathing];
    [self updateOverlayWaveform];

    // 按钮内部波形（保持原逻辑）
    if (_waveContainer.hidden) return;
    CGFloat containerH = _waveContainer.bounds.size.height;
    CGFloat barWidth = 3;
    CGFloat baseH = 3;
    for (NSInteger i = 0; i < (NSInteger)_waveBars.count; i++) {
        CGFloat h;
        if (normalizedPower == 0) {
            h = baseH;
        } else {
            CGFloat variation = 0.3 + (arc4random_uniform(70) / 100.0);
            h = baseH + normalizedPower * containerH * 0.8 * variation;
        }
        h = MAX(baseH, MIN(h, containerH));
        UIView *bar = _waveBars[i];
        [UIView animateWithDuration:0.1 animations:^{
            bar.frame = CGRectMake(bar.frame.origin.x, (containerH - h) / 2, barWidth, h);
        }];
    }
}

#pragma mark - Button Actions

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            if (self.state != WKVoiceInputStateIdle) return;
            self.touchStartPoint = [gesture locationInView:self.window];
            [self startRecording];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (self.state != WKVoiceInputStateRecording && self.state != WKVoiceInputStateCancelling) return;
            CGPoint current = [gesture locationInView:self.window];
            CGFloat upOffset = self.touchStartPoint.y - current.y;
            // 上移超过120pt进入取消，回到80pt以内恢复录音（20pt回弹区间防抖动）
            if (self.state == WKVoiceInputStateRecording && upOffset > 120) {
                self.state = WKVoiceInputStateCancelling;
            } else if (self.state == WKVoiceInputStateCancelling && upOffset < 80) {
                self.state = WKVoiceInputStateRecording;
            }
            [self updateTouchGlowPosition:[gesture locationInView:self.recordingOverlay]];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (self.state == WKVoiceInputStateCancelling) {
                [self hideRecordingOverlay];
                [self cancelRecording];
            } else if (self.state == WKVoiceInputStateRecording) {
                [self hideRecordingOverlay];
                [self stopRecordingAndTranscribe];
            }
            break;
        }
        default: break;
    }
}

- (void)onBottomButtonTapped {
    if (self.state == WKVoiceInputStateRecording) {
        [self cancelRecording];
    } else {
        if ([self.delegate respondsToSelector:@selector(voiceInputInsertText:)]) {
            [self.delegate voiceInputInsertText:@"\n"];
        }
    }
}

- (void)onAtTapped {
    if ([self.delegate respondsToSelector:@selector(voiceInputInsertText:)]) {
        [self.delegate voiceInputInsertText:@"@"];
    }
}

- (void)onSpaceTapped {
    if ([self.delegate respondsToSelector:@selector(voiceInputInsertText:)]) {
        [self.delegate voiceInputInsertText:@" "];
    }
}

- (void)onDeleteTapped {
    if ([self.delegate respondsToSelector:@selector(voiceInputDeleteBackward)]) {
        [self.delegate voiceInputDeleteBackward];
    }
}

#pragma mark - Recording Overlay

static NSInteger const kOverlayWaveBarCount = 40;

- (void)showRecordingOverlay {
    if (self.recordingOverlay) return;

    UIWindow *window = self.window;
    if (!window) return;

    CGFloat screenW = window.bounds.size.width;
    CGFloat screenH = window.bounds.size.height;

    // 蒙层容器：全屏，用于放置各子层
    _recordingOverlay = [[UIView alloc] initWithFrame:window.bounds];
    _recordingOverlay.userInteractionEnabled = NO;
    _recordingOverlay.alpha = 0;

    // 径向渐变：大椭圆从底部中心向外扩散（3倍大小）
    CGFloat glowW = screenW * 2.2;
    CGFloat glowH = screenH * 0.95;
    _overlayGradient = [CAGradientLayer layer];
    _overlayGradient.type = kCAGradientLayerRadial;
    _overlayGradient.frame = CGRectMake((screenW - glowW) / 2,
                                         screenH - glowH / 2, // 圆心在屏幕底边
                                         glowW, glowH);
    _overlayGradient.colors = @[
        // 深色核心区域（0~40%不透明）
        (id)[UIColor colorWithRed:38/255.0 green:95/255.0 blue:218/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:40/255.0 green:100/255.0 blue:220/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:43/255.0 green:105/255.0 blue:223/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:46/255.0 green:110/255.0 blue:226/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:50/255.0 green:116/255.0 blue:230/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:55/255.0 green:122/255.0 blue:234/255.0 alpha:0.99].CGColor,
        (id)[UIColor colorWithRed:60/255.0 green:128/255.0 blue:237/255.0 alpha:0.97].CGColor,
        // 过渡区域（40%~100%细腻淡出）
        (id)[UIColor colorWithRed:66/255.0 green:136/255.0 blue:240/255.0 alpha:0.93].CGColor,
        (id)[UIColor colorWithRed:73/255.0 green:144/255.0 blue:243/255.0 alpha:0.86].CGColor,
        (id)[UIColor colorWithRed:82/255.0 green:153/255.0 blue:245/255.0 alpha:0.76].CGColor,
        (id)[UIColor colorWithRed:92/255.0 green:162/255.0 blue:247/255.0 alpha:0.64].CGColor,
        (id)[UIColor colorWithRed:103/255.0 green:172/255.0 blue:249/255.0 alpha:0.52].CGColor,
        (id)[UIColor colorWithRed:115/255.0 green:182/255.0 blue:250/255.0 alpha:0.40].CGColor,
        (id)[UIColor colorWithRed:128/255.0 green:192/255.0 blue:252/255.0 alpha:0.30].CGColor,
        (id)[UIColor colorWithRed:142/255.0 green:200/255.0 blue:253/255.0 alpha:0.21].CGColor,
        (id)[UIColor colorWithRed:156/255.0 green:209/255.0 blue:254/255.0 alpha:0.14].CGColor,
        (id)[UIColor colorWithRed:170/255.0 green:217/255.0 blue:255/255.0 alpha:0.08].CGColor,
        (id)[UIColor colorWithRed:185/255.0 green:225/255.0 blue:255/255.0 alpha:0.04].CGColor,
        (id)[UIColor colorWithRed:205/255.0 green:236/255.0 blue:255/255.0 alpha:0.01].CGColor,
        (id)[UIColor clearColor].CGColor,
    ];
    _overlayGradient.locations = @[@0.0, @0.06, @0.12, @0.18, @0.25, @0.32, @0.40,
                                    @0.47, @0.53, @0.59, @0.64, @0.69, @0.74, @0.79, @0.83, @0.87, @0.91, @0.94, @0.97, @1.0];
    _overlayGradient.startPoint = CGPointMake(0.5, 0.5);
    _overlayGradient.endPoint   = CGPointMake(1.0, 1.0);
    [_recordingOverlay.layer addSublayer:_overlayGradient];

    // 拖尾残影（12个，尾部小淡 → 头部大浓，连续过渡）
    NSInteger trailCount = 12;
    _touchTrailLayers = [NSMutableArray arrayWithCapacity:trailCount];
    for (NSInteger i = 0; i < trailCount; i++) {
        CAGradientLayer *trail = [CAGradientLayer layer];
        trail.type = kCAGradientLayerRadial;
        // i=0 最远的尾巴（最小最淡），i=11 最近的（最大最浓）
        CGFloat t = (CGFloat)i / (trailCount - 1); // 0~1
        CGFloat size = 160 * (0.25 + t * 0.75);    // 40pt ~ 160pt
        trail.frame = CGRectMake(0, 0, size, size);
        CGFloat alphaBase = 0.02 + t * 0.30;        // 0.02 ~ 0.32
        trail.colors = @[
            (id)[UIColor colorWithRed:20/255.0 green:60/255.0 blue:180/255.0 alpha:alphaBase].CGColor,
            (id)[UIColor colorWithRed:20/255.0 green:60/255.0 blue:180/255.0 alpha:0.0].CGColor,
        ];
        trail.startPoint = CGPointMake(0.5, 0.5);
        trail.endPoint = CGPointMake(1.0, 1.0);
        trail.opacity = 0;
        [_recordingOverlay.layer addSublayer:trail];
        [_touchTrailLayers addObject:trail];
    }

    // 主光圈（最前面最亮）
    _touchGlowLayer = [CAGradientLayer layer];
    _touchGlowLayer.type = kCAGradientLayerRadial;
    _touchGlowLayer.frame = CGRectMake(0, 0, 160, 160);
    _touchGlowLayer.colors = @[
        (id)[UIColor colorWithRed:20/255.0 green:60/255.0 blue:180/255.0 alpha:0.40].CGColor,
        (id)[UIColor colorWithRed:20/255.0 green:60/255.0 blue:180/255.0 alpha:0.0].CGColor,
    ];
    _touchGlowLayer.startPoint = CGPointMake(0.5, 0.5);
    _touchGlowLayer.endPoint = CGPointMake(1.0, 1.0);
    _touchGlowLayer.opacity = 0;
    [_recordingOverlay.layer addSublayer:_touchGlowLayer];

    // 提示文字：纯白色
    _overlayHintLabel = [[UILabel alloc] init];
    _overlayHintLabel.text = LLang(@"松手结束，上移取消");
    _overlayHintLabel.textColor = [UIColor whiteColor];
    _overlayHintLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    _overlayHintLabel.textAlignment = NSTextAlignmentCenter;
    _overlayHintLabel.frame = CGRectMake(0, screenH * 0.68, screenW, 20);
    [_recordingOverlay addSubview:_overlayHintLabel];

    // 波形容器
    CGFloat barW = 4, barGap = 3.5;
    CGFloat totalW = kOverlayWaveBarCount * barW + (kOverlayWaveBarCount - 1) * barGap;
    _overlayWaveContainer = [[UIView alloc] initWithFrame:CGRectMake((screenW - totalW) / 2,
                                                                      screenH - 100, totalW, 66)];
    _overlayWaveContainer.userInteractionEnabled = NO;
    [_recordingOverlay addSubview:_overlayWaveContainer];

    _overlayWaveBars = [NSMutableArray array];
    CGFloat center = kOverlayWaveBarCount / 2.0;
    for (NSInteger i = 0; i < kOverlayWaveBarCount; i++) {
        UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(i * (barW + barGap), 25, barW, 15)];
        // 首尾渐淡：平方曲线让最外几个柱自然消失隐入背景
        CGFloat distFromCenter = fabs(i - center) / center; // 0~1
        CGFloat fade = 1.0 - distFromCenter;                 // 1→0
        CGFloat alpha = fade * fade * 0.95;                   // 平方曲线：中间0.95，边缘趋近0
        bar.backgroundColor = [UIColor colorWithWhite:1.0 alpha:alpha];
        bar.layer.cornerRadius = 2.0;
        [_overlayWaveContainer addSubview:bar];
        [_overlayWaveBars addObject:bar];
    }

    [window addSubview:_recordingOverlay];

    [UIView animateWithDuration:0.2 animations:^{
        self.recordingOverlay.alpha = 1.0;
    }];
}

- (void)hideRecordingOverlay {
    if (!self.recordingOverlay) return;
    UIView *overlay = self.recordingOverlay;
    [UIView animateWithDuration:0.18 animations:^{
        overlay.alpha = 0;
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
    _recordingOverlay = nil;
    _overlayGradient = nil;
    _touchGlowLayer = nil;
    _touchTrailLayers = nil;
    _overlayHintLabel = nil;
    _overlayWaveContainer = nil;
    _overlayWaveBars = nil;
}

- (void)updateTouchGlowPosition:(CGPoint)pointInOverlay {
    if (!_touchGlowLayer || !_recordingOverlay) return;

    BOOL isFirstTouch = (_touchGlowLayer.opacity == 0);

    // 主光圈立即跟随手指
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _touchGlowLayer.position = pointInOverlay;
    _touchGlowLayer.opacity = 1.0;
    [CATransaction commit];

    // 残影：首次直接定位到手指处（不飞入），之后用不同速度追随形成拖尾
    NSInteger count = (NSInteger)_touchTrailLayers.count;
    for (NSInteger i = 0; i < count; i++) {
        CAGradientLayer *trail = _touchTrailLayers[i];
        if (isFirstTouch) {
            // 首次：所有残影直接出现在手指位置，无动画
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            trail.position = pointInOverlay;
            trail.opacity = 1.0;
            [CATransaction commit];
        } else {
            // 后续：越远的残影(i越小)跟随越慢，形成连贯拖尾
            // i=0 最远尾巴 duration=0.35s，i=11 最近 duration=0.05s
            CGFloat t = (CGFloat)i / (count - 1); // 0~1
            CGFloat duration = 0.35 - t * 0.30;    // 0.35s ~ 0.05s
            [CATransaction begin];
            [CATransaction setAnimationDuration:duration];
            [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
            trail.position = pointInOverlay;
            [CATransaction commit];
        }
    }
}

- (void)updateOverlayBreathing {
    if (!_overlayGradient || !self.window) return;

    CGFloat screenW = self.window.bounds.size.width;
    CGFloat screenH = self.window.bounds.size.height;

    // 呼吸效果：缩放径向椭圆大小，底部圆心不动，只向上和两侧膨胀
    CGFloat breathScale = 1.0 + _currentPower * 0.15; // 1.0 ~ 1.15
    CGFloat glowW = screenW * 2.2 * breathScale;
    CGFloat glowH = screenH * 0.85 * breathScale;

    [CATransaction begin];
    [CATransaction setAnimationDuration:0.15];
    [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    _overlayGradient.frame = CGRectMake((screenW - glowW) / 2,
                                         screenH - glowH / 2, // 圆心始终在屏幕底边
                                         glowW, glowH);
    [CATransaction commit];
    // 提示文字和波形位置固定不动
}

- (void)updateOverlayWaveform {
    if (!_overlayWaveContainer || _overlayWaveBars.count == 0) return;

    CGFloat containerH = _overlayWaveContainer.bounds.size.height;
    CGFloat barW = 4, barGap = 3.5;
    CGFloat baseH = 15, maxH = 45;
    CGFloat center = kOverlayWaveBarCount / 2.0;
    BOOL isCancelling = (self.state == WKVoiceInputStateCancelling);

    for (NSInteger i = 0; i < (NSInteger)_overlayWaveBars.count; i++) {
        CGFloat distFromCenter = fabs(i - center) / center; // 0~1
        CGFloat h;
        if (_currentPower == 0) {
            h = baseH;
        } else {
            CGFloat attenuation = 1.0 - distFromCenter * 0.6;
            CGFloat randomFactor = 0.3 + (arc4random_uniform(70) / 100.0);
            h = baseH + _currentPower * maxH * attenuation * randomFactor;
        }
        h = MAX(baseH, MIN(h, containerH));

        // 首尾渐淡：平方曲线，最外几个柱自然消失隐入背景
        CGFloat fade = 1.0 - distFromCenter;
        CGFloat alpha = fade * fade * 0.95;
        UIColor *barColor;
        if (isCancelling) {
            barColor = [UIColor colorWithRed:239/255.0 green:68/255.0 blue:68/255.0 alpha:alpha];
        } else {
            barColor = [UIColor colorWithWhite:1.0 alpha:alpha];
        }

        UIView *bar = _overlayWaveBars[i];
        [UIView animateWithDuration:0.1 animations:^{
            bar.frame = CGRectMake(i * (barW + barGap), (containerH - h) / 2, barW, h);
            bar.backgroundColor = barColor;
        }];
    }
}

- (void)applyOverlayRecordingStyle {
    // 蓝色径向渐变：20段细腻过渡，深色区域扩大
    _overlayGradient.colors = @[
        (id)[UIColor colorWithRed:38/255.0 green:95/255.0 blue:218/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:40/255.0 green:100/255.0 blue:220/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:43/255.0 green:105/255.0 blue:223/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:46/255.0 green:110/255.0 blue:226/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:50/255.0 green:116/255.0 blue:230/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:55/255.0 green:122/255.0 blue:234/255.0 alpha:0.99].CGColor,
        (id)[UIColor colorWithRed:60/255.0 green:128/255.0 blue:237/255.0 alpha:0.97].CGColor,
        (id)[UIColor colorWithRed:66/255.0 green:136/255.0 blue:240/255.0 alpha:0.93].CGColor,
        (id)[UIColor colorWithRed:73/255.0 green:144/255.0 blue:243/255.0 alpha:0.86].CGColor,
        (id)[UIColor colorWithRed:82/255.0 green:153/255.0 blue:245/255.0 alpha:0.76].CGColor,
        (id)[UIColor colorWithRed:92/255.0 green:162/255.0 blue:247/255.0 alpha:0.64].CGColor,
        (id)[UIColor colorWithRed:103/255.0 green:172/255.0 blue:249/255.0 alpha:0.52].CGColor,
        (id)[UIColor colorWithRed:115/255.0 green:182/255.0 blue:250/255.0 alpha:0.40].CGColor,
        (id)[UIColor colorWithRed:128/255.0 green:192/255.0 blue:252/255.0 alpha:0.30].CGColor,
        (id)[UIColor colorWithRed:142/255.0 green:200/255.0 blue:253/255.0 alpha:0.21].CGColor,
        (id)[UIColor colorWithRed:156/255.0 green:209/255.0 blue:254/255.0 alpha:0.14].CGColor,
        (id)[UIColor colorWithRed:170/255.0 green:217/255.0 blue:255/255.0 alpha:0.08].CGColor,
        (id)[UIColor colorWithRed:185/255.0 green:225/255.0 blue:255/255.0 alpha:0.04].CGColor,
        (id)[UIColor colorWithRed:205/255.0 green:236/255.0 blue:255/255.0 alpha:0.01].CGColor,
        (id)[UIColor clearColor].CGColor,
    ];
    _overlayGradient.locations = @[@0.0, @0.06, @0.12, @0.18, @0.25, @0.32, @0.40,
                                    @0.47, @0.53, @0.59, @0.64, @0.69, @0.74, @0.79, @0.83, @0.87, @0.91, @0.94, @0.97, @1.0];
    for (UIView *bar in _overlayWaveBars) {
        bar.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    }
    _touchGlowLayer.colors = @[
        (id)[UIColor colorWithRed:20/255.0 green:60/255.0 blue:180/255.0 alpha:0.40].CGColor,
        (id)[UIColor colorWithRed:20/255.0 green:60/255.0 blue:180/255.0 alpha:0.0].CGColor,
    ];
    for (NSInteger i = 0; i < (NSInteger)_touchTrailLayers.count; i++) {
        CGFloat t = (CGFloat)i / (_touchTrailLayers.count - 1);
        CGFloat a = 0.02 + t * 0.30;
        _touchTrailLayers[i].colors = @[
            (id)[UIColor colorWithRed:20/255.0 green:60/255.0 blue:180/255.0 alpha:a].CGColor,
            (id)[UIColor colorWithRed:20/255.0 green:60/255.0 blue:180/255.0 alpha:0.0].CGColor,
        ];
    }
    _overlayHintLabel.text = LLang(@"松手结束，上移取消");
    _overlayHintLabel.textColor = [UIColor whiteColor];
}

- (void)applyOverlayCancellingStyle {
    // 红色径向渐变：20段细腻过渡，深色区域扩大
    _overlayGradient.colors = @[
        (id)[UIColor colorWithRed:205/255.0 green:40/255.0 blue:40/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:210/255.0 green:45/255.0 blue:45/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:215/255.0 green:50/255.0 blue:50/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:220/255.0 green:56/255.0 blue:56/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:226/255.0 green:63/255.0 blue:63/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:232/255.0 green:72/255.0 blue:72/255.0 alpha:0.99].CGColor,
        (id)[UIColor colorWithRed:237/255.0 green:82/255.0 blue:82/255.0 alpha:0.97].CGColor,
        (id)[UIColor colorWithRed:241/255.0 green:95/255.0 blue:95/255.0 alpha:0.93].CGColor,
        (id)[UIColor colorWithRed:244/255.0 green:110/255.0 blue:110/255.0 alpha:0.86].CGColor,
        (id)[UIColor colorWithRed:247/255.0 green:125/255.0 blue:125/255.0 alpha:0.76].CGColor,
        (id)[UIColor colorWithRed:249/255.0 green:140/255.0 blue:140/255.0 alpha:0.64].CGColor,
        (id)[UIColor colorWithRed:251/255.0 green:158/255.0 blue:158/255.0 alpha:0.52].CGColor,
        (id)[UIColor colorWithRed:252/255.0 green:175/255.0 blue:175/255.0 alpha:0.40].CGColor,
        (id)[UIColor colorWithRed:253/255.0 green:190/255.0 blue:190/255.0 alpha:0.30].CGColor,
        (id)[UIColor colorWithRed:254/255.0 green:203/255.0 blue:203/255.0 alpha:0.21].CGColor,
        (id)[UIColor colorWithRed:254/255.0 green:215/255.0 blue:215/255.0 alpha:0.14].CGColor,
        (id)[UIColor colorWithRed:255/255.0 green:226/255.0 blue:226/255.0 alpha:0.08].CGColor,
        (id)[UIColor colorWithRed:255/255.0 green:236/255.0 blue:236/255.0 alpha:0.04].CGColor,
        (id)[UIColor colorWithRed:255/255.0 green:245/255.0 blue:245/255.0 alpha:0.01].CGColor,
        (id)[UIColor clearColor].CGColor,
    ];
    _overlayGradient.locations = @[@0.0, @0.06, @0.12, @0.18, @0.25, @0.32, @0.40,
                                    @0.47, @0.53, @0.59, @0.64, @0.69, @0.74, @0.79, @0.83, @0.87, @0.91, @0.94, @0.97, @1.0];
    for (UIView *bar in _overlayWaveBars) {
        bar.backgroundColor = [UIColor colorWithRed:239/255.0 green:68/255.0 blue:68/255.0 alpha:0.8];
    }
    _touchGlowLayer.colors = @[
        (id)[UIColor colorWithRed:180/255.0 green:30/255.0 blue:30/255.0 alpha:0.40].CGColor,
        (id)[UIColor colorWithRed:180/255.0 green:30/255.0 blue:30/255.0 alpha:0.0].CGColor,
    ];
    for (NSInteger i = 0; i < (NSInteger)_touchTrailLayers.count; i++) {
        CGFloat t = (CGFloat)i / (_touchTrailLayers.count - 1);
        CGFloat a = 0.02 + t * 0.30;
        _touchTrailLayers[i].colors = @[
            (id)[UIColor colorWithRed:180/255.0 green:30/255.0 blue:30/255.0 alpha:a].CGColor,
            (id)[UIColor colorWithRed:180/255.0 green:30/255.0 blue:30/255.0 alpha:0.0].CGColor,
        ];
    }
    _overlayHintLabel.text = LLang(@"松手取消");
    _overlayHintLabel.textColor = [UIColor colorWithRed:220/255.0 green:60/255.0 blue:60/255.0 alpha:1.0];
}

#pragma mark - Notifications

- (void)appDidEnterBackground {
    if (self.state == WKVoiceInputStateRecording || self.state == WKVoiceInputStateCancelling) {
        [self hideRecordingOverlay];
        [self cancelRecording];
    }
}

- (void)audioSessionInterrupted:(NSNotification *)notification {
    if ([notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue] == AVAudioSessionInterruptionTypeBegan) {
        if (self.state == WKVoiceInputStateRecording || self.state == WKVoiceInputStateCancelling) {
            [self hideRecordingOverlay];
            [self cancelRecording];
        }
    }
}

- (void)onCancelRecordingNotification:(NSNotification *)notification {
    [self cancelIfRecording];
}

#pragma mark - Permission

- (void)showPermissionAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"需要麦克风权限")
                                                                  message:LLang(@"请在设置中允许访问麦克风")
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"去设置") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [[WKNavigationManager shared].topViewController presentViewController:alert animated:YES completion:nil];
}

- (void)showHUDWithHide:(NSString *)text {
    UIView *target = self.window;
    if (!target) {
        target = [UIApplication sharedApplication].keyWindow;
    }
    if (target && target != self) {
        [target showHUDWithHide:text];
    }
}

#pragma mark - Public

- (void)cancelIfRecording {
    if (self.state == WKVoiceInputStateRecording || self.state == WKVoiceInputStateCancelling) {
        [self hideRecordingOverlay];
        [self cancelRecording];
    }
}

#pragma mark - @Mention Parsing (Longest Prefix Match)

- (NSString *)parseMentionMarkers:(NSString *)text
                          members:(NSArray<WKChannelMember *> *)members
                         mentions:(NSMutableArray<WKInputMentionItem *> *)mentions {
    if (text.length == 0) return text;

    NSString *loginUID = [WKApp shared].loginInfo.uid;

    NSMutableArray<NSDictionary *> *nameEntries = [NSMutableArray array];
    for (WKChannelMember *member in members) {
        if ([member.memberUid isEqualToString:loginUID]) continue;
        if (member.isDeleted) continue;
        NSString *displayName = member.memberRemark.length > 0 ? member.memberRemark : member.memberName;
        if (displayName.length > 0) {
            [nameEntries addObject:@{@"name": displayName, @"uid": member.memberUid}];
        }
        if (member.memberRemark.length > 0 && member.memberName.length > 0 &&
            ![member.memberRemark isEqualToString:member.memberName]) {
            [nameEntries addObject:@{@"name": member.memberName, @"uid": member.memberUid}];
        }
    }
    [nameEntries sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSUInteger lenA = [a[@"name"] length];
        NSUInteger lenB = [b[@"name"] length];
        if (lenB > lenA) return NSOrderedDescending;
        if (lenB < lenA) return NSOrderedAscending;
        return NSOrderedSame;
    }];

    NSString *allName = LLang(@"所有人");
    NSMutableString *result = [NSMutableString string];
    NSUInteger i = 0;
    NSUInteger len = text.length;

    while (i < len) {
        unichar ch = [text characterAtIndex:i];
        if (ch != '@') {
            [result appendFormat:@"%C", ch];
            i++;
            continue;
        }

        NSString *rest = [text substringFromIndex:i + 1];

        if ([rest hasPrefix:allName]) {
            WKInputMentionItem *item = [[WKInputMentionItem alloc] init];
            item.uid = @"all";
            item.name = allName;
            [mentions addObject:item];
            [result appendFormat:@"@%@%@", allName, WKInputAtEndChar];
            i += 1 + allName.length;
            if (i < len && [text characterAtIndex:i] == ' ') i++;
            continue;
        }
        if ([rest.lowercaseString hasPrefix:@"all"] &&
            (rest.length == 3 || (i + 4 < len && [text characterAtIndex:i + 4] == ' '))) {
            WKInputMentionItem *item = [[WKInputMentionItem alloc] init];
            item.uid = @"all";
            item.name = allName;
            [mentions addObject:item];
            [result appendFormat:@"@%@%@", allName, WKInputAtEndChar];
            i += 1 + 3;
            if (i < len && [text characterAtIndex:i] == ' ') i++;
            continue;
        }

        BOOL matched = NO;
        for (NSDictionary *entry in nameEntries) {
            NSString *name = entry[@"name"];
            if (rest.length >= name.length &&
                [[rest substringToIndex:name.length] caseInsensitiveCompare:name] == NSOrderedSame) {
                WKInputMentionItem *item = [[WKInputMentionItem alloc] init];
                item.uid = entry[@"uid"];
                item.name = name;
                [mentions addObject:item];
                [result appendFormat:@"@%@%@", name, WKInputAtEndChar];
                i += 1 + name.length;
                if (i < len && [text characterAtIndex:i] == ' ') i++;
                matched = YES;
                break;
            }
        }

        if (!matched) {
            [result appendString:@"@"];
            i++;
        }
    }

    return [result copy];
}

@end
