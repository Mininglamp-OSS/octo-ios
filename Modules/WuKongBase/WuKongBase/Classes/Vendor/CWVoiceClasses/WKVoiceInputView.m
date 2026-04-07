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

// 波形（在 micButton 内部）
@property (nonatomic, strong) UIView *waveContainer;
@property (nonatomic, strong) NSMutableArray<UIView *> *waveBars;

// 圆点（录音等待）
@property (nonatomic, strong) UIView *dotsContainer;

// 脉冲光晕
@property (nonatomic, strong) UIView *glowView;

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
    _statusLabel.text = LLang(@"点击说话");
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
    [_micButton addTarget:self action:@selector(onMicTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_micButton];

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
            case WKVoiceInputStateRecording: [self applyRecordingLayout:YES]; break;
            case WKVoiceInputStateTranscribing: [self applyTranscribingLayout:YES]; break;
        }
        [self setNeedsLayout];
        [self layoutIfNeeded];
    };

    if (oldState != state) {
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseInOut animations:changes completion:nil];
    } else {
        changes();
    }
}

- (void)applyIdleLayout:(BOOL)animated {
    _micButton.backgroundColor = [WKApp shared].config.themeColor;
    _micButton.enabled = YES;
    _micButton.alpha = 1.0;
    _micButton.imageEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    UIImage *img = [WKApp.shared loadImage:@"Conversation/Toolbar/MicIdle2" moduleID:@"WuKongBase"];
    if (img) [_micButton setImage:img forState:UIControlStateNormal];
    _micButton.imageView.hidden = NO;

    _statusLabel.text = LLang(@"点击说话");
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
        if ([self.delegate respondsToSelector:@selector(voiceInputDidTranscribe:shouldReplace:)]) {
            [self.delegate voiceInputDidTranscribe:text shouldReplace:shouldReplace];
        }
    }
}

- (void)applyRecordingLayout:(BOOL)animated {
    _micButton.backgroundColor = [WKApp shared].config.themeColor;
    _micButton.enabled = YES;
    _micButton.alpha = 1.0;
    [_micButton setImage:nil forState:UIControlStateNormal];
    _micButton.imageView.hidden = YES;

    _statusLabel.text = LLang(@"再次点击以完成");
    _statusLabel.textColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    _statusLabel.font = [UIFont boldSystemFontOfSize:14];
    _statusLabel.hidden = NO;

    _atButton.hidden = YES; _spaceButton.hidden = YES; _deleteButton.hidden = YES;
    _bottomButton.hidden = YES;
    _thinkingLabel.hidden = YES; _glowView.hidden = NO;

    _hasReceivedAudio = NO;
    _dotsContainer.hidden = NO; _waveContainer.hidden = YES;

    [self stopThinkingAnimation];
}

- (void)applyTranscribingLayout:(BOOL)animated {
    // 转写中：主题色稍浅
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
            [self doStartRecording];
        });
    }];
}

- (void)doStartRecording {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    self.previousAudioCategory = session.category;
    self.previousAudioCategoryOptions = session.categoryOptions;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
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
    NSString *chatContext = nil;
    if ([self.delegate respondsToSelector:@selector(voiceInputChatContext)]) {
        chatContext = [self.delegate voiceInputChatContext];
    }

    __weak typeof(self) weakSelf = self;
    [[WKVoiceInputService shared] transcribeAudio:audioData contextText:contextText chatContext:chatContext
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
    if (self.recordSeconds >= self.maxDuration) [self stopRecordingAndTranscribe];
}

- (void)updateWaveform {
    if (self.state != WKVoiceInputStateRecording || !self.audioRecorder) return;
    [self.audioRecorder updateMeters];
    float power = [self.audioRecorder averagePowerForChannel:0];
    // dB 值通常在 -160 ~ 0 之间，-40 以下视为静音
    float normalizedPower = (power + 40) / 40.0; // -40dB 以下 = 0
    normalizedPower = MAX(0, MIN(1, normalizedPower));

    // 低于阈值视为静音，波形完全不动
    static float const kSilenceThreshold = 0.08;
    if (normalizedPower < kSilenceThreshold) {
        normalizedPower = 0;
    }
    _currentPower = normalizedPower;

    // 有明显音频时从圆点切换为波形
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

    if (_waveContainer.hidden) return;

    CGFloat containerH = _waveContainer.bounds.size.height;
    CGFloat barWidth = 3;
    CGFloat baseH = 3; // 静音时柱体高度
    for (NSInteger i = 0; i < (NSInteger)_waveBars.count; i++) {
        CGFloat h;
        if (normalizedPower == 0) {
            // 完全静音：所有柱体固定最小高度，不抖动
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

// 扩大录音状态下的点击区域（按钮动态缩放时可能很小）
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.state == WKVoiceInputStateRecording) {
        // 将光晕区域内的点击都转发给 micButton
        CGPoint micCenter = _micButton.center;
        CGFloat hitRadius = 60; // 固定 60pt 点击半径
        CGFloat dx = point.x - micCenter.x;
        CGFloat dy = point.y - micCenter.y;
        if (dx * dx + dy * dy <= hitRadius * hitRadius) {
            return _micButton;
        }
    }
    return [super hitTest:point withEvent:event];
}

- (void)onMicTapped {
    switch (self.state) {
        case WKVoiceInputStateIdle: [self startRecording]; break;
        case WKVoiceInputStateRecording: [self stopRecordingAndTranscribe]; break;
        case WKVoiceInputStateTranscribing: break;
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

#pragma mark - Notifications

- (void)appDidEnterBackground {
    if (self.state == WKVoiceInputStateRecording) [self cancelRecording];
}

- (void)audioSessionInterrupted:(NSNotification *)notification {
    if ([notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue] == AVAudioSessionInterruptionTypeBegan) {
        if (self.state == WKVoiceInputStateRecording) [self cancelRecording];
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
    [(self.window ?: self) showHUDWithHide:text];
}

#pragma mark - Public

- (void)cancelIfRecording {
    if (self.state == WKVoiceInputStateRecording) [self cancelRecording];
}

@end
