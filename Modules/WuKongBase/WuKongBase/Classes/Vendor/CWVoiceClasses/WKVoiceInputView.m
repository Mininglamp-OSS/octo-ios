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

@interface WKVoiceInputView ()

// UI
@property (nonatomic, strong) UIButton *micButton;
@property (nonatomic, strong) UILabel  *statusLabel;
@property (nonatomic, strong) UIView   *waveContainer;
@property (nonatomic, strong) UIButton *bottomButton;     // 取消按钮
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSMutableArray<UIView *> *waveBars;

// 录音
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, copy)   NSString *recordFilePath;
@property (nonatomic, strong) NSTimer  *recordTimer;      // 1s 计时
@property (nonatomic, strong) NSTimer  *waveformTimer;    // 0.1s 声波刷新
@property (nonatomic, assign) NSInteger recordSeconds;

// 保存录音前的 AudioSession category 和 categoryOptions
@property (nonatomic, copy) NSString *previousAudioCategory;
@property (nonatomic, assign) AVAudioSessionCategoryOptions previousAudioCategoryOptions;

// 状态
@property (nonatomic, assign) WKVoiceInputState state;

// 防重入
@property (nonatomic, assign) BOOL isStartingRecording;

@end

@implementation WKVoiceInputView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _maxDuration = 60;
        _state = WKVoiceInputStateIdle;
        _isStartingRecording = NO;
        [self setupUI];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidEnterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioSessionInterrupted:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onCancelRecordingNotification:)
                                                     name:WKVoiceInputCancelRecordingNotification
                                                   object:nil];
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

    // 状态标签
    _statusLabel = [[UILabel alloc] init];
    _statusLabel.text = LLang(@"点击说话");
    _statusLabel.textColor = [UIColor grayColor];
    _statusLabel.font = [UIFont systemFontOfSize:15];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_statusLabel];

    // 声波容器
    _waveContainer = [[UIView alloc] init];
    _waveContainer.hidden = YES;
    [self addSubview:_waveContainer];
    [self setupWaveBars];

    // 麦克风按钮
    _micButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _micButton.layer.cornerRadius = 35;
    _micButton.clipsToBounds = YES;
    _micButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_micButton addTarget:self action:@selector(onMicTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_micButton];

    UIImage *micImage = [WKApp.shared loadImage:@"Conversation/Toolbar/MicIdle" moduleID:@"WuKongBase"];
    if (micImage) {
        [_micButton setImage:micImage forState:UIControlStateNormal];
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
#pragma clang diagnostic pop
    _spinner.hidesWhenStopped = YES;
    _spinner.color = [UIColor colorWithRed:0.16 green:0.71 blue:0.96 alpha:1.0];
    [self addSubview:_spinner];

    // 底部取消按钮（仅录音时显示）
    _bottomButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_bottomButton setTitle:LLang(@"取消") forState:UIControlStateNormal];
    _bottomButton.titleLabel.font = [UIFont systemFontOfSize:14];
    _bottomButton.hidden = YES;
    [_bottomButton setTitleColor:[UIColor colorWithRed:1.0 green:0.42 blue:0.42 alpha:1.0] forState:UIControlStateNormal];
    _bottomButton.backgroundColor = [UIColor colorWithRed:0.99 green:0.91 blue:0.91 alpha:1.0];
    _bottomButton.layer.cornerRadius = 16;
    [_bottomButton addTarget:self action:@selector(onBottomButtonTapped)
            forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_bottomButton];

    [self updateUIForState:WKVoiceInputStateIdle];
}

- (void)setupWaveBars {
    _waveBars = [NSMutableArray array];
    NSInteger barCount = 12;
    for (NSInteger i = 0; i < barCount; i++) {
        UIView *bar = [[UIView alloc] init];
        bar.backgroundColor = [UIColor colorWithRed:1.0 green:0.42 blue:0.42 alpha:1.0];
        bar.layer.cornerRadius = 2.0;
        [_waveContainer addSubview:bar];
        [_waveBars addObject:bar];
    }
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = self.bounds.size.width;

    // 声波容器（固定在顶部区域，录音时显示）
    CGFloat waveWidth = 180;
    CGFloat waveHeight = 36;
    _waveContainer.frame = CGRectMake(w/2 - waveWidth/2, 10, waveWidth, waveHeight);
    [self layoutWaveBars];

    // 状态标签 — 固定位置，所有状态都在同一高度
    _statusLabel.frame = CGRectMake(0, 50, w, 18);

    // 麦克风按钮（70x70） — 固定位置，所有状态都在同一高度
    _micButton.frame = CGRectMake(w/2 - 35, 76, 70, 70);

    // 加载动画 — 放在声波容器同位置（顶部区域）
    _spinner.center = CGPointMake(w/2, 28);

    // 底部取消按钮
    _bottomButton.frame = CGRectMake(w/2 - 40, CGRectGetMaxY(_micButton.frame) + 8, 80, 32);
}

- (void)layoutWaveBars {
    CGFloat barWidth = 4;
    CGFloat waveWidth = _waveContainer.bounds.size.width;
    CGFloat waveHeight = _waveContainer.bounds.size.height;
    CGFloat gap = (waveWidth - barWidth * _waveBars.count) / (_waveBars.count - 1);
    for (NSInteger i = 0; i < (NSInteger)_waveBars.count; i++) {
        CGFloat x = i * (barWidth + gap);
        CGFloat h = 14;
        _waveBars[i].frame = CGRectMake(x, (waveHeight - h) / 2, barWidth, h);
    }
}

#pragma mark - State Machine

- (void)setState:(WKVoiceInputState)state {
    _state = state;
    [self updateUIForState:state];
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)updateUIForState:(WKVoiceInputState)state {
    UIColor *blueColor = [UIColor colorWithRed:0.16 green:0.71 blue:0.96 alpha:1.0];
    UIColor *redColor  = [UIColor colorWithRed:1.0 green:0.42 blue:0.42 alpha:1.0];

    switch (state) {
        case WKVoiceInputStateIdle: {
            _micButton.backgroundColor = blueColor;
            _micButton.enabled = YES;
            _micButton.alpha = 1.0;
            _micButton.imageEdgeInsets = UIEdgeInsetsMake(15, 15, 15, 15);
            UIImage *img = [WKApp.shared loadImage:@"Conversation/Toolbar/MicIdle" moduleID:@"WuKongBase"];
            if (img) [_micButton setImage:img forState:UIControlStateNormal];
            _statusLabel.text = LLang(@"点击说话");
            _statusLabel.textColor = [UIColor grayColor];
            _waveContainer.hidden = YES;
            _bottomButton.hidden = YES;
            [_spinner stopAnimating];
            break;
        }
        case WKVoiceInputStateRecording: {
            _micButton.backgroundColor = redColor;
            _micButton.enabled = YES;
            _micButton.alpha = 1.0;
            _micButton.imageEdgeInsets = UIEdgeInsetsZero;
            UIImage *img = [WKApp.shared loadImage:@"Conversation/Toolbar/MicStop" moduleID:@"WuKongBase"];
            if (img) [_micButton setImage:img forState:UIControlStateNormal];
            _statusLabel.text = LLang(@"点击结束");
            _statusLabel.textColor = redColor;
            _waveContainer.hidden = NO;
            _bottomButton.hidden = NO;
            [_spinner stopAnimating];
            break;
        }
        case WKVoiceInputStateTranscribing: {
            _micButton.backgroundColor = blueColor;
            _micButton.enabled = NO;
            _micButton.alpha = 0.5;
            _micButton.imageEdgeInsets = UIEdgeInsetsMake(15, 15, 15, 15);
            UIImage *img = [WKApp.shared loadImage:@"Conversation/Toolbar/MicIdle" moduleID:@"WuKongBase"];
            if (img) [_micButton setImage:img forState:UIControlStateNormal];
            _statusLabel.text = LLang(@"识别完成后自动输入");
            _statusLabel.textColor = [UIColor grayColor];
            _waveContainer.hidden = YES;
            _bottomButton.hidden = YES;
            [_spinner startAnimating];
            break;
        }
    }
}

#pragma mark - Recording

- (void)startRecording {
    // 防重入
    if (self.isStartingRecording) return;
    self.isStartingRecording = YES;

    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isStartingRecording = NO;
            if (!granted) {
                [self showPermissionAlert];
                return;
            }
            [self doStartRecording];
        });
    }];
}

- (void)doStartRecording {
    AVAudioSession *session = [AVAudioSession sharedInstance];

    // 保存当前 AudioSession category 和 categoryOptions
    self.previousAudioCategory = session.category;
    self.previousAudioCategoryOptions = session.categoryOptions;

    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [session setActive:YES error:nil];

    // 录音文件
    NSString *tempDir = NSTemporaryDirectory();
    self.recordFilePath = [tempDir stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"voice_input_%lld.m4a",
                            (long long)([[NSDate date] timeIntervalSince1970] * 1000)]];

    NSDictionary *settings = @{
        AVFormatIDKey:              @(kAudioFormatMPEG4AAC),
        AVSampleRateKey:            @(16000.0),
        AVNumberOfChannelsKey:      @(1),
        AVEncoderAudioQualityKey:   @(AVAudioQualityHigh),
    };

    NSError *error;
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:self.recordFilePath]
                                                     settings:settings
                                                        error:&error];
    if (error) {
        NSLog(@"[VoiceInput] recorder init error: %@", error);
        [self showHUDWithHide:LLang(@"录音初始化失败")];
        [self restoreAudioSession];
        return;
    }

    self.audioRecorder.meteringEnabled = YES;

    if (![self.audioRecorder prepareToRecord]) {
        NSLog(@"[VoiceInput] prepareToRecord failed");
        [self showHUDWithHide:LLang(@"录音初始化失败")];
        [self restoreAudioSession];
        return;
    }
    if (![self.audioRecorder record]) {
        NSLog(@"[VoiceInput] record failed");
        [self showHUDWithHide:LLang(@"录音启动失败")];
        [self restoreAudioSession];
        return;
    }

    self.recordSeconds = 0;
    __weak typeof(self) weakSelf = self;
    self.recordTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
        [weakSelf updateTimer];
    }];

    self.waveformTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
        [weakSelf updateWaveform];
    }];

    self.state = WKVoiceInputStateRecording;

    if ([self.delegate respondsToSelector:@selector(voiceInputRecordingDidStart)]) {
        [self.delegate voiceInputRecordingDidStart];
    }
}

- (void)stopRecordingAndTranscribe {
    [self invalidateTimers];

    if (!self.audioRecorder.isRecording) return;

    // 在 stop() 之前读取 currentTime，stop() 之后 currentTime 归零
    NSTimeInterval duration = self.audioRecorder.currentTime;

    [self.audioRecorder stop];

    // 恢复 AudioSession（category + categoryOptions）
    [self restoreAudioSession];

    // 通知外层录音结束
    if ([self.delegate respondsToSelector:@selector(voiceInputRecordingDidStop)]) {
        [self.delegate voiceInputRecordingDidStop];
    }

    if (duration < 1.0) {
        [self showHUDWithHide:LLang(@"说话时间太短")];
        self.state = WKVoiceInputStateIdle;
        [self cleanupRecordFile];
        return;
    }

    self.state = WKVoiceInputStateTranscribing;

    NSData *audioData = [NSData dataWithContentsOfFile:self.recordFilePath];
    if (!audioData || audioData.length == 0) {
        self.state = WKVoiceInputStateIdle;
        [self cleanupRecordFile];
        return;
    }

    NSString *contextText = nil;
    if ([self.delegate respondsToSelector:@selector(voiceInputCurrentText)]) {
        contextText = [self.delegate voiceInputCurrentText];
    }

    __weak typeof(self) weakSelf = self;
    [[WKVoiceInputService shared] transcribeAudio:audioData
                                      contextText:contextText
                                      chatContext:nil
                                       completion:^(WKVoiceInputResult *result, NSError *error) {
        [weakSelf cleanupRecordFile];

        if (error || result.text.length == 0) {
            [weakSelf showHUDWithHide:LLang(@"语音识别失败，请重试")];
            weakSelf.state = WKVoiceInputStateIdle;
            return;
        }

        BOOL shouldReplace = (contextText.length > 0);
        if ([weakSelf.delegate respondsToSelector:@selector(voiceInputDidTranscribe:shouldReplace:)]) {
            [weakSelf.delegate voiceInputDidTranscribe:result.text shouldReplace:shouldReplace];
        }
        weakSelf.state = WKVoiceInputStateIdle;
    }];
}

- (void)cancelRecording {
    [self invalidateTimers];
    if (self.audioRecorder.isRecording) {
        [self.audioRecorder stop];
    }
    [self cleanupRecordFile];

    // 恢复 AudioSession（category + categoryOptions）
    [self restoreAudioSession];

    // 通知外层
    if ([self.delegate respondsToSelector:@selector(voiceInputRecordingDidStop)]) {
        [self.delegate voiceInputRecordingDidStop];
    }

    self.state = WKVoiceInputStateIdle;
}

- (void)restoreAudioSession {
    if (self.previousAudioCategory) {
        [[AVAudioSession sharedInstance] setCategory:self.previousAudioCategory
                                        withOptions:self.previousAudioCategoryOptions
                                              error:nil];
        self.previousAudioCategory = nil;
        self.previousAudioCategoryOptions = 0;
    }
    [[AVAudioSession sharedInstance] setActive:NO
                                  withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                        error:nil];
}

- (void)invalidateTimers {
    [self.recordTimer invalidate];
    self.recordTimer = nil;
    [self.waveformTimer invalidate];
    self.waveformTimer = nil;
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
        [self stopRecordingAndTranscribe];
    }
}

- (void)updateWaveform {
    if (self.state != WKVoiceInputStateRecording || !self.audioRecorder) return;
    [self.audioRecorder updateMeters];
    float power = [self.audioRecorder averagePowerForChannel:0];
    float normalizedPower = (power + 50) / 50.0;
    normalizedPower = MAX(0, MIN(1, normalizedPower));

    CGFloat waveHeight = _waveContainer.bounds.size.height;
    CGFloat barWidth = 4;
    for (NSInteger i = 0; i < (NSInteger)_waveBars.count; i++) {
        CGFloat variation = 0.4 + (arc4random_uniform(60) / 100.0);
        CGFloat h = 6 + normalizedPower * 28 * variation;
        h = MIN(h, waveHeight);
        UIView *bar = _waveBars[i];
        [UIView animateWithDuration:0.1 animations:^{
            bar.frame = CGRectMake(bar.frame.origin.x, (waveHeight - h) / 2, barWidth, h);
        }];
    }
}

#pragma mark - Button Actions

- (void)onMicTapped {
    switch (self.state) {
        case WKVoiceInputStateIdle:
            [self startRecording];
            break;
        case WKVoiceInputStateRecording:
            [self stopRecordingAndTranscribe];
            break;
        case WKVoiceInputStateTranscribing:
            break;
    }
}

- (void)onBottomButtonTapped {
    if (self.state == WKVoiceInputStateRecording) {
        [self cancelRecording];
    }
}

#pragma mark - Notifications

- (void)appDidEnterBackground {
    if (self.state == WKVoiceInputStateRecording) {
        [self cancelRecording];
    }
}

- (void)audioSessionInterrupted:(NSNotification *)notification {
    NSInteger type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        if (self.state == WKVoiceInputStateRecording) {
            [self cancelRecording];
        }
    }
}

- (void)onCancelRecordingNotification:(NSNotification *)notification {
    [self cancelIfRecording];
}

#pragma mark - Permission

- (void)showPermissionAlert {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:LLang(@"需要麦克风权限")
                         message:LLang(@"请在设置中允许访问麦克风")
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"去设置")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
                                           options:@{} completionHandler:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消")
                                              style:UIAlertActionStyleCancel handler:nil]];
    [[WKNavigationManager shared].topViewController presentViewController:alert animated:YES completion:nil];
}

- (void)showHUDWithHide:(NSString *)text {
    UIView *hudView = self.window ?: self;
    [hudView showHUDWithHide:text];
}

#pragma mark - Public

- (void)cancelIfRecording {
    if (self.state == WKVoiceInputStateRecording) {
        [self cancelRecording];
    }
}

@end
