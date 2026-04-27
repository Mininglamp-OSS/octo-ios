//
//  WKHoldToTalkManager.m
//  WuKongBase
//

#import "WKHoldToTalkManager.h"
#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKVoiceInputService.h"
#import "WKApp.h"
#import "WKNavigationManager.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import "WKInputMentionCache.h"

static NSString * const kVoiceAPIPreferenceKey = @"WKVoiceAPIPreference";
static NSString * const kVoiceAPIServer = @"server";
static NSString * const kVoiceAPIApple  = @"apple";

typedef NS_ENUM(NSInteger, WKHTTState) {
    WKHTTStateIdle,
    WKHTTStateRecording,
    WKHTTStateSendVoice,
    WKHTTStateCancelling,
    WKHTTStateThinking,
    WKHTTStateResult,
};

static NSInteger const kOverlayWaveBarCount = 30;
static CGFloat const kMaxTextViewHeight = 15 * 20.0; // 15 lines * ~20pt line height

@interface WKHoldToTalkManager () <SFSpeechRecognizerDelegate, UITextViewDelegate>

@property (nonatomic, assign) WKHTTState state;

// 录音
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, copy)   NSString *recordFilePath;
@property (nonatomic, strong) NSTimer  *recordTimer;
@property (nonatomic, strong) NSTimer  *waveformTimer;
@property (nonatomic, assign) NSInteger recordSeconds;
@property (nonatomic, assign) float currentPower;
@property (nonatomic, copy) NSString *previousAudioCategory;
@property (nonatomic, assign) AVAudioSessionCategoryOptions previousAudioCategoryOptions;

// Apple ASR
@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;

// 覆盖层
@property (nonatomic, strong) UIView *overlay;

// 录音 UI
@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) UIView *bubbleTail;
@property (nonatomic, strong) NSMutableArray<UIView *> *waveBars;
@property (nonatomic, strong) UIView *waveContainer;
@property (nonatomic, strong) UIView *bottomAreaView;   // 底部暗色背景
@property (nonatomic, strong) UIView *cancelPill;       // 左侧取消胶囊
@property (nonatomic, strong) UILabel *cancelPillLabel;
@property (nonatomic, strong) UIView *sendVoicePill;    // 右侧发送原语音胶囊
@property (nonatomic, strong) UILabel *sendVoicePillLabel;
@property (nonatomic, strong) UILabel *hintLabel;       // 底部提示文字
@property (nonatomic, assign) CGPoint bubbleOriginCenter; // 气泡初始中心点

// Thinking UI (自研引擎 — 在气泡内显示思考动画，半透明背景)
@property (nonatomic, strong) UIView *thinkingOverlayView; // 半透明遮罩覆盖在文本框上
@property (nonatomic, strong) NSMutableArray<UIView *> *thinkingDots;
@property (nonatomic, strong) NSTimer *thinkingTimer;
@property (nonatomic, assign) NSInteger thinkingDotIndex;

// 结果 UI
@property (nonatomic, strong) UITextView *resultTextView;
@property (nonatomic, strong) UIView *resultBottomBar;
@property (nonatomic, strong) UIButton *resultCancelBtn;
@property (nonatomic, strong) UIButton *resultSendTextBtn;
@property (nonatomic, strong) UIButton *resultMicBtn;
@property (nonatomic, strong) UIButton *apiSwitchBtn;

// 追加录音覆盖层（在结果页之上的录音层）
@property (nonatomic, strong) UIView *appendOverlay;
@property (nonatomic, strong) UIView *appendBubble;
@property (nonatomic, strong) UIView *appendWaveContainer;
@property (nonatomic, strong) NSMutableArray<UIView *> *appendWaveBars;
@property (nonatomic, strong) UIView *appendBottomArea;
@property (nonatomic, strong) UILabel *appendHintLabel;
@property (nonatomic, assign) BOOL isAppendMode;

// 数据
@property (nonatomic, copy) NSString *transcribedText;
@property (nonatomic, strong) NSData *recordedAudioData;
@property (nonatomic, assign) NSTimeInterval recordedDuration;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *recordedLevels; // 录音波形数据

// 键盘
@property (nonatomic, assign) CGFloat keyboardHeight;

// 手势
@property (nonatomic, assign) CGPoint touchStartPoint;
@property (nonatomic, weak) UIWindow *currentWindow;
@property (nonatomic, assign) BOOL isGestureActive; // 手势是否仍在按住状态

@end

@implementation WKHoldToTalkManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = WKHTTStateIdle;
        _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"zh-CN"]];
        _speechRecognizer.delegate = self;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
        // 系统中断：电话、进入后台、音频被打断 → 自动取消录音
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSystemInterrupt) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSystemInterrupt) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAudioInterrupt:) name:AVAudioSessionInterruptionNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self cleanup];
}

#pragma mark - System Interrupt（电话/后台/音频中断）

- (void)onSystemInterrupt {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.state == WKHTTStateRecording || self.state == WKHTTStateSendVoice || self.state == WKHTTStateCancelling) {
            self.isGestureActive = NO;
            [self cancelRecording];
            [self hideOverlay];
        } else if (self.state == WKHTTStateThinking) {
            // thinking 状态不中断，等待结果返回
        }
        // result 状态保留，用户回来后可以继续编辑
    });
}

- (void)onAudioInterrupt:(NSNotification *)notification {
    NSInteger type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        [self onSystemInterrupt];
    }
}

#pragma mark - API Preference

- (NSString *)currentAPIPreference {
    NSString *pref = [[NSUserDefaults standardUserDefaults] stringForKey:kVoiceAPIPreferenceKey];
    return pref ?: kVoiceAPIServer;
}

- (void)setAPIPreference:(NSString *)pref {
    [[NSUserDefaults standardUserDefaults] setObject:pref forKey:kVoiceAPIPreferenceKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self updateAPISwitchBtnTitle];
}

- (NSString *)currentAPIDisplayName {
    return [[self currentAPIPreference] isEqualToString:kVoiceAPIApple] ? @"Apple引擎" : @"自研引擎";
}

#pragma mark - Long Press Gesture

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture inWindow:(UIWindow *)window {
    self.currentWindow = window;

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            if (self.state == WKHTTStateIdle) {
                self.isGestureActive = YES;
                self.touchStartPoint = [gesture locationInView:window];
                [self startRecording];
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (self.state != WKHTTStateRecording && self.state != WKHTTStateSendVoice && self.state != WKHTTStateCancelling) return;
            CGPoint current = [gesture locationInView:window];
            [self handleDragAtPoint:current];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            self.isGestureActive = NO;
            [self handleGestureEnd];
            break;
        }
        default: break;
    }
}

/// 追加录音的长按手势处理（来自继续语音按钮）
- (void)handleAppendLongPress:(UILongPressGestureRecognizer *)gesture {
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            self.isGestureActive = YES;
            self.touchStartPoint = [gesture locationInView:self.currentWindow];
            [self startAppendRecording];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (self.state != WKHTTStateRecording && self.state != WKHTTStateCancelling) return;
            CGPoint current = [gesture locationInView:self.currentWindow];
            // 追加模式只检测上滑取消
            CGFloat upOffset = self.touchStartPoint.y - current.y;
            WKHTTState newState = (upOffset > 100) ? WKHTTStateCancelling : WKHTTStateRecording;
            if (self.state != newState) {
                self.state = newState;
                [self updateAppendOverlayForState];
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            self.isGestureActive = NO;
            if (self.state == WKHTTStateCancelling) {
                [self cancelAppendRecording];
            } else if (self.state == WKHTTStateRecording) {
                [self stopAppendRecordingAndTranscribe];
            }
            break;
        }
        default: break;
    }
}

- (void)handleDragAtPoint:(CGPoint)point {
    // 扩大胶囊判定区域（上下各扩展20pt）
    CGRect cancelHit = CGRectInset(self.cancelPill.frame, -10, -20);
    CGRect sendVoiceHit = CGRectInset(self.sendVoicePill.frame, -10, -20);

    BOOL inCancelZone = CGRectContainsPoint(cancelHit, point);
    BOOL inSendVoiceZone = CGRectContainsPoint(sendVoiceHit, point);

    WKHTTState newState;
    if (inCancelZone) {
        newState = WKHTTStateCancelling;
    } else if (inSendVoiceZone) {
        newState = WKHTTStateSendVoice;
    } else {
        newState = WKHTTStateRecording;
    }

    if (self.state != newState) {
        self.state = newState;
        [UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
            [self updateOverlayForState];
        } completion:nil];
    }
}

- (void)handleGestureEnd {
    if (self.state == WKHTTStateSendVoice) {
        [self stopRecordingAndSendVoice];
    } else if (self.state == WKHTTStateCancelling) {
        [self cancelRecording];
        [self hideOverlay];
    } else if (self.state == WKHTTStateRecording) {
        [self stopRecordingAndTranscribe];
    }
}

#pragma mark - Recording

- (void)startRecording {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!granted) { [self showPermissionAlert]; return; }
            // 权限弹窗期间手指已松开，不再开始录音（否则会卡在录音界面）
            if (!self.isGestureActive) { return; }
            [self doStartRecordingAppend:NO];
        });
    }];
}

- (void)startAppendRecording {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!granted) { [self showPermissionAlert]; return; }
            if (!self.isGestureActive) { return; }
            [self doStartRecordingAppend:YES];
        });
    }];
}

- (void)doStartRecordingAppend:(BOOL)isAppend {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    self.previousAudioCategory = session.category;
    self.previousAudioCategoryOptions = session.categoryOptions;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeDefault options:0 error:nil];
    [session setActive:YES error:nil];

    // 使用 PCM 格式录音（与对讲模块一致，确保语音消息兼容）
    self.recordFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"hold_talk_%lld.wav", (long long)([[NSDate date] timeIntervalSince1970] * 1000)]];

    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatLinearPCM),
        AVSampleRateKey: @(8000.0),
        AVNumberOfChannelsKey: @(1),
        AVLinearPCMBitDepthKey: @(16),
        AVEncoderAudioQualityKey: @(AVAudioQualityMin),
    };

    NSError *error;
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:self.recordFilePath] settings:settings error:&error];
    if (error) { [self showHUD:LLang(@"录音初始化失败")]; [self restoreAudioSession]; return; }

    self.audioRecorder.meteringEnabled = YES;
    if (![self.audioRecorder prepareToRecord] || ![self.audioRecorder record]) {
        [self showHUD:LLang(@"录音启动失败")]; [self restoreAudioSession]; return;
    }

    self.recordSeconds = 0;
    self.currentPower = 0;
    self.recordedLevels = [NSMutableArray array];
    __weak typeof(self) ws = self;
    self.recordTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) { [ws updateRecordTimer]; }];
    self.waveformTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *t) { [ws updateWaveform]; }];

    self.state = WKHTTStateRecording;

    // 录音开始时预取语音上下文（异步，不阻塞录音）
    [[WKVoiceInputService shared] prefetchVoiceContext];

    if (!isAppend) {
        self.transcribedText = nil;
        [self showRecordingOverlay];
    } else {
        [self transitionToRecordingUI];
    }

    if ([self.delegate respondsToSelector:@selector(holdToTalkManagerDidStartRecording:)]) {
        [self.delegate holdToTalkManagerDidStartRecording:self];
    }
}

- (void)stopRecordingAndTranscribe {
    [self invalidateRecordTimers];
    if (!self.audioRecorder.isRecording) return;

    NSTimeInterval duration = self.audioRecorder.currentTime;
    [self.audioRecorder stop];
    [self restoreAudioSession];
    self.recordedDuration = duration;

    if ([self.delegate respondsToSelector:@selector(holdToTalkManagerDidStopRecording:)]) {
        [self.delegate holdToTalkManagerDidStopRecording:self];
    }

    if (duration < 1.0) {
        [self showHUD:LLang(@"说话时间太短")];
        [self hideOverlay]; self.state = WKHTTStateIdle; [self cleanupRecordFile]; return;
    }

    NSData *audioData = [NSData dataWithContentsOfFile:self.recordFilePath];
    self.recordedAudioData = audioData;
    if (!audioData || audioData.length == 0) {
        [self showHUD:LLang(@"录音数据异常")];
        [self hideOverlay]; self.state = WKHTTStateIdle; [self cleanupRecordFile]; return;
    }

    if ([[self currentAPIPreference] isEqualToString:kVoiceAPIApple]) {
        // Apple 引擎：直接进入结果页，在结果页内显示"识别中"
        self.state = WKHTTStateThinking;
        [self transitionToResultUIWithThinking:YES];
        [self transcribeWithAppleASR:audioData];
    } else {
        // 自研引擎：进入结果页，气泡内显示 thinking 动画
        self.state = WKHTTStateThinking;
        [self transitionToResultUIWithThinking:YES];
        [self transcribeWithServerAPI:audioData];
    }
}

- (void)stopRecordingAndSendVoice {
    [self invalidateRecordTimers];
    if (!self.audioRecorder.isRecording) { [self hideOverlay]; self.state = WKHTTStateIdle; return; }

    NSTimeInterval duration = self.audioRecorder.currentTime;
    [self.audioRecorder stop];
    [self restoreAudioSession];

    if ([self.delegate respondsToSelector:@selector(holdToTalkManagerDidStopRecording:)]) {
        [self.delegate holdToTalkManagerDidStopRecording:self];
    }

    if (duration < 1.0) {
        [self showHUD:LLang(@"说话时间太短")];
        [self hideOverlay]; self.state = WKHTTStateIdle; [self cleanupRecordFile]; return;
    }

    NSData *voiceData = [NSData dataWithContentsOfFile:self.recordFilePath];
    NSInteger seconds = (NSInteger)ceil(duration);
    [self hideOverlay]; self.state = WKHTTStateIdle;

    if (voiceData && [self.delegate respondsToSelector:@selector(holdToTalkManager:sendVoiceData:seconds:waveform:)]) {
        [self.delegate holdToTalkManager:self sendVoiceData:voiceData seconds:seconds waveform:self.recordedLevels];
    }
    [self cleanupRecordFile];
}

- (void)cancelRecording {
    [self invalidateRecordTimers];
    if (self.audioRecorder.isRecording) [self.audioRecorder stop];
    [self cleanupRecordFile];
    [self restoreAudioSession];
    if ([self.delegate respondsToSelector:@selector(holdToTalkManagerDidStopRecording:)]) {
        [self.delegate holdToTalkManagerDidStopRecording:self];
    }
    self.state = WKHTTStateIdle;
}

- (void)cancelIfRecording {
    if (self.state == WKHTTStateRecording || self.state == WKHTTStateSendVoice || self.state == WKHTTStateCancelling) {
        [self cancelRecording];
        [self hideOverlay];
    }
}

#pragma mark - Transcription

- (void)transcribeWithServerAPI:(NSData *)audioData {
    // context_text: 仅使用当前已转写的文本（独立于外部输入框）
    NSString *contextText = self.transcribedText.length > 0 ? self.transcribedText : nil;
    BOOL hasContext = (contextText.length > 0);

    __weak typeof(self) ws = self;

    // 等待预取的语音上下文完成，再发起转写
    [[WKVoiceInputService shared] getVoiceContextWithCompletion:^(NSString *voiceContext) {
        NSString *personalContext = voiceContext;
        NSString *chatContext = nil;
        NSString *memberContext = nil;
        if ([ws.delegate respondsToSelector:@selector(holdToTalkManagerChatContext:)]) {
            NSString *fullContext = [ws.delegate holdToTalkManagerChatContext:ws];
            if (fullContext) {
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

        [[WKVoiceInputService shared] transcribeWavAudio:audioData
                                             contextText:contextText
                                             chatContext:chatContext
                                         personalContext:personalContext
                                           memberContext:memberContext
                                              completion:^(WKVoiceInputResult *result, NSError *error) {
            [ws cleanupRecordFile];
            if (error || result.text.length == 0) {
                [ws showHUD:LLang(@"语音识别失败，请重试")];
                [ws hideOverlay]; ws.state = WKHTTStateIdle;
                return;
            }
            if (hasContext) {
                ws.transcribedText = result.text;
            } else {
                ws.transcribedText = ws.transcribedText.length > 0
                    ? [ws.transcribedText stringByAppendingString:result.text]
                    : result.text;
            }
            [ws finishThinkingAndShowText];
        }];
    }];
}

- (void)transcribeWithAppleASR:(NSData *)audioData {
    if (!self.speechRecognizer.isAvailable) {
        [self showHUD:LLang(@"Apple语音识别不可用")];
        [self hideOverlay]; self.state = WKHTTStateIdle; return;
    }

    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status != SFSpeechRecognizerAuthorizationStatusAuthorized) {
                [self showHUD:LLang(@"请在设置中允许语音识别")];
                [self hideOverlay]; self.state = WKHTTStateIdle; return;
            }
            [self performAppleRecognition];
        });
    }];
}

- (void)performAppleRecognition {
    NSURL *audioURL = [NSURL fileURLWithPath:self.recordFilePath];
    SFSpeechURLRecognitionRequest *request = [[SFSpeechURLRecognitionRequest alloc] initWithURL:audioURL];
    request.shouldReportPartialResults = NO;
    request.taskHint = SFSpeechRecognitionTaskHintDictation;
    if (@available(iOS 16, *)) { request.addsPunctuation = YES; }

    __weak typeof(self) ws = self;
    [self.speechRecognizer recognitionTaskWithRequest:request resultHandler:^(SFSpeechRecognitionResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [ws cleanupRecordFile];
                [ws showHUD:LLang(@"语音识别失败，请重试")];
                [ws hideOverlay]; ws.state = WKHTTStateIdle; return;
            }
            if (result.isFinal) {
                NSString *text = result.bestTranscription.formattedString;
                [ws cleanupRecordFile];
                if (text.length == 0) {
                    [ws showHUD:LLang(@"未识别到语音")];
                    [ws hideOverlay]; ws.state = WKHTTStateIdle; return;
                }
                ws.transcribedText = ws.transcribedText.length > 0
                    ? [ws.transcribedText stringByAppendingString:text]
                    : text;
                [ws finishThinkingAndShowText];
            }
        });
    }];
}

#pragma mark - Recording Overlay

- (void)showRecordingOverlay {
    if (self.overlay) return;
    UIWindow *window = self.currentWindow;
    if (!window) return;

    CGFloat sw = window.bounds.size.width;
    CGFloat sh = window.bounds.size.height;

    // 全屏蒙层
    self.overlay = [[UIView alloc] initWithFrame:window.bounds];
    self.overlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
    self.overlay.userInteractionEnabled = YES;
    self.overlay.alpha = 0;

    // ===== 气泡 =====
    CGFloat bubbleW = sw * 0.62;
    CGFloat bubbleH = 85;
    CGFloat bubbleCenterY = sh * 0.42;
    self.bubbleView = [[UIView alloc] initWithFrame:CGRectMake((sw - bubbleW) / 2, bubbleCenterY - bubbleH / 2, bubbleW, bubbleH)];
    self.bubbleView.backgroundColor = [UIColor colorWithRed:0.88 green:0.94 blue:1.0 alpha:1.0];
    self.bubbleView.layer.cornerRadius = 16;
    self.bubbleView.clipsToBounds = YES;
    [self.overlay addSubview:self.bubbleView];
    self.bubbleOriginCenter = self.bubbleView.center;

    // 气泡尖角
    self.bubbleTail = [self createBubbleTailWithColor:[UIColor colorWithRed:0.88 green:0.94 blue:1.0 alpha:1.0]];
    self.bubbleTail.center = CGPointMake(self.bubbleView.center.x, CGRectGetMaxY(self.bubbleView.frame) + 4);
    [self.overlay addSubview:self.bubbleTail];

    // 波形
    CGFloat waveW = bubbleW * 0.85;
    CGFloat waveH = 50;
    self.waveContainer = [[UIView alloc] initWithFrame:CGRectMake((bubbleW - waveW) / 2, (bubbleH - waveH) / 2, waveW, waveH)];
    [self.bubbleView addSubview:self.waveContainer];

    self.waveBars = [NSMutableArray array];
    CGFloat barW = 3, barGap = 2.5;
    CGFloat totalBarW = kOverlayWaveBarCount * barW + (kOverlayWaveBarCount - 1) * barGap;
    CGFloat startX = (waveW - totalBarW) / 2;
    for (NSInteger i = 0; i < kOverlayWaveBarCount; i++) {
        UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(startX + i * (barW + barGap), waveH / 2 - 3, barW, 6)];
        bar.backgroundColor = [UIColor colorWithRed:0.35 green:0.55 blue:0.85 alpha:0.7];
        bar.layer.cornerRadius = 1.5;
        [self.waveContainer addSubview:bar];
        [self.waveBars addObject:bar];
    }

    // ===== 底部暗色背景（上凸弧） =====
    CGFloat bottomH = 100;
    CGFloat safeBottom = window.safeAreaInsets.bottom;
    self.bottomAreaView = [[UIView alloc] initWithFrame:CGRectMake(0, sh - bottomH - safeBottom, sw, bottomH + safeBottom)];
    self.bottomAreaView.backgroundColor = [UIColor clearColor];

    CAShapeLayer *arcBg = [CAShapeLayer layer];
    UIBezierPath *arcPath = [UIBezierPath bezierPath];
    [arcPath moveToPoint:CGPointMake(0, bottomH + safeBottom)];
    [arcPath addLineToPoint:CGPointMake(0, 35)];
    [arcPath addQuadCurveToPoint:CGPointMake(sw, 35) controlPoint:CGPointMake(sw / 2, -15)];
    [arcPath addLineToPoint:CGPointMake(sw, bottomH + safeBottom)];
    [arcPath closePath];
    arcBg.path = arcPath.CGPath;
    arcBg.fillColor = [WKApp shared].config.themeColor.CGColor;
    [self.bottomAreaView.layer addSublayer:arcBg];
    [self.overlay addSubview:self.bottomAreaView];

    // 底部提示文字
    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.text = LLang(@"松手 转文字");
    self.hintLabel.textColor = [UIColor whiteColor];
    self.hintLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    self.hintLabel.frame = CGRectMake(0, 45, sw, 20);
    [self.bottomAreaView addSubview:self.hintLabel];

    // ===== 两个独立胶囊按钮（直接在 overlay 上，便于手势检测） =====
    CGFloat pillH = 55;
    CGFloat pillW = sw * 0.42;
    CGFloat pillY = self.bottomAreaView.frame.origin.y - pillH - 25;
    CGFloat pillGap = 12;

    // 左侧：取消
    self.cancelPill = [[UIView alloc] initWithFrame:CGRectMake((sw / 2 - pillW - pillGap / 2), pillY, pillW, pillH)];
    self.cancelPill.backgroundColor = [UIColor colorWithWhite:0.28 alpha:0.9];
    self.cancelPill.layer.cornerRadius = pillH / 2;
    self.cancelPill.clipsToBounds = YES;
    [self.overlay addSubview:self.cancelPill];

    self.cancelPillLabel = [[UILabel alloc] initWithFrame:self.cancelPill.bounds];
    self.cancelPillLabel.text = LLang(@"取消");
    self.cancelPillLabel.textColor = [UIColor whiteColor];
    self.cancelPillLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.cancelPillLabel.textAlignment = NSTextAlignmentCenter;
    [self.cancelPill addSubview:self.cancelPillLabel];

    // 右侧：发送原语音
    self.sendVoicePill = [[UIView alloc] initWithFrame:CGRectMake((sw / 2 + pillGap / 2), pillY, pillW, pillH)];
    self.sendVoicePill.backgroundColor = [UIColor colorWithWhite:0.28 alpha:0.9];
    self.sendVoicePill.layer.cornerRadius = pillH / 2;
    self.sendVoicePill.clipsToBounds = YES;
    [self.overlay addSubview:self.sendVoicePill];

    self.sendVoicePillLabel = [[UILabel alloc] initWithFrame:self.sendVoicePill.bounds];
    self.sendVoicePillLabel.text = [NSString stringWithFormat:@"%@\n%@", LLang(@"滑动到这里"), LLang(@"发送原语音")];
    self.sendVoicePillLabel.numberOfLines = 2;
    self.sendVoicePillLabel.textColor = [UIColor whiteColor];
    self.sendVoicePillLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.sendVoicePillLabel.textAlignment = NSTextAlignmentCenter;
    [self.sendVoicePill addSubview:self.sendVoicePillLabel];

    [window addSubview:self.overlay];
    [UIView animateWithDuration:0.2 animations:^{ self.overlay.alpha = 1.0; }];
}

- (UIView *)createBubbleTailWithColor:(UIColor *)color {
    UIView *tail = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 10)];
    tail.backgroundColor = [UIColor clearColor];
    CAShapeLayer *shape = [CAShapeLayer layer];
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(0, 0)];
    [path addLineToPoint:CGPointMake(8, 10)];
    [path addLineToPoint:CGPointMake(16, 0)];
    [path closePath];
    shape.path = path.CGPath;
    shape.fillColor = color.CGColor;
    [tail.layer addSublayer:shape];
    return tail;
}


- (void)hideOverlay {
    if (!self.overlay) return;
    [self stopThinkingAnimation];
    UIView *ov = self.overlay;
    [UIView animateWithDuration:0.18 animations:^{ ov.alpha = 0; } completion:^(BOOL f) { [ov removeFromSuperview]; }];
    self.overlay = nil;
    self.bubbleView = nil; self.bubbleTail = nil;
    self.waveContainer = nil; self.waveBars = nil;
    self.bottomAreaView = nil; self.hintLabel = nil;
    self.cancelPill = nil; self.cancelPillLabel = nil;
    self.sendVoicePill = nil; self.sendVoicePillLabel = nil;
    self.resultTextView = nil; self.resultBottomBar = nil;
    self.resultCancelBtn = nil; self.resultSendTextBtn = nil;
    self.resultMicBtn = nil; self.apiSwitchBtn = nil;
    self.thinkingDots = nil; self.thinkingOverlayView = nil;
    self.appendOverlay = nil; self.appendBubble = nil;
    self.appendWaveContainer = nil; self.appendWaveBars = nil;
    self.isAppendMode = NO; self.keyboardHeight = 0;
    self.state = WKHTTStateIdle;
}

- (void)setPillBackgroundColor:(UIColor *)color forPill:(UIView *)pill {
    // 更新弧形胶囊的背景色（第一个sublayer是背景）
    for (CALayer *sub in pill.layer.sublayers) {
        if ([sub isKindOfClass:[CAShapeLayer class]]) {
            ((CAShapeLayer *)sub).fillColor = color.CGColor;
            break;
        }
    }
}

- (void)updateOverlayForState {
    UIColor *normalPillBg = [UIColor colorWithWhite:0.28 alpha:0.9];
    UIColor *highlightPillBg = [UIColor colorWithWhite:0.95 alpha:1.0];
    UIColor *bubbleNormalColor = [UIColor colorWithRed:0.88 green:0.94 blue:1.0 alpha:1.0];

    switch (self.state) {
        case WKHTTStateRecording: {
            [self setPillBackgroundColor:normalPillBg forPill:self.cancelPill];
            self.cancelPill.transform = CGAffineTransformIdentity;
            self.cancelPillLabel.textColor = [UIColor whiteColor];
            [self setPillBackgroundColor:normalPillBg forPill:self.sendVoicePill];
            self.sendVoicePill.transform = CGAffineTransformIdentity;
            self.sendVoicePillLabel.textColor = [UIColor whiteColor];
            self.hintLabel.text = LLang(@"松手 转文字");
            self.bubbleView.backgroundColor = bubbleNormalColor;
            self.bubbleView.center = self.bubbleOriginCenter;
            self.bubbleTail.center = CGPointMake(self.bubbleOriginCenter.x, CGRectGetMaxY(self.bubbleView.frame) + 4);
            break;
        }
        case WKHTTStateSendVoice: {
            [self setPillBackgroundColor:highlightPillBg forPill:self.sendVoicePill];
            self.sendVoicePill.transform = CGAffineTransformMakeScale(1.06, 1.06);
            self.sendVoicePillLabel.textColor = [UIColor colorWithWhite:0.15 alpha:1.0];
            [self setPillBackgroundColor:normalPillBg forPill:self.cancelPill];
            self.cancelPill.transform = CGAffineTransformIdentity;
            self.cancelPillLabel.textColor = [UIColor whiteColor];
            self.hintLabel.text = LLang(@"松手 发送原语音");
            self.bubbleView.backgroundColor = [UIColor colorWithRed:0.3 green:0.78 blue:0.4 alpha:1.0];
            CGFloat offsetX = 25;
            self.bubbleView.center = CGPointMake(self.bubbleOriginCenter.x + offsetX, self.bubbleOriginCenter.y);
            self.bubbleTail.center = CGPointMake(self.bubbleOriginCenter.x + offsetX, CGRectGetMaxY(self.bubbleView.frame) + 4);
            break;
        }
        case WKHTTStateCancelling: {
            [self setPillBackgroundColor:highlightPillBg forPill:self.cancelPill];
            self.cancelPill.transform = CGAffineTransformMakeScale(1.06, 1.06);
            self.cancelPillLabel.textColor = [UIColor colorWithWhite:0.15 alpha:1.0];
            [self setPillBackgroundColor:normalPillBg forPill:self.sendVoicePill];
            self.sendVoicePill.transform = CGAffineTransformIdentity;
            self.sendVoicePillLabel.textColor = [UIColor whiteColor];
            self.hintLabel.text = LLang(@"松手 取消");
            self.bubbleView.backgroundColor = [UIColor colorWithRed:0.95 green:0.35 blue:0.3 alpha:1.0];
            CGFloat offsetX = -25;
            self.bubbleView.center = CGPointMake(self.bubbleOriginCenter.x + offsetX, self.bubbleOriginCenter.y);
            self.bubbleTail.center = CGPointMake(self.bubbleOriginCenter.x + offsetX, CGRectGetMaxY(self.bubbleView.frame) + 4);
            break;
        }
        default: break;
    }
}

- (void)transitionToRecordingUI {
    // 追加录音模式：在结果页之上覆盖一层半透明录音层
    self.isAppendMode = YES;
    [self.resultTextView resignFirstResponder];

    CGFloat sw = self.currentWindow.bounds.size.width;
    CGFloat sh = self.currentWindow.bounds.size.height;

    // 半透明覆盖层（让用户隐约看到底下的文字编辑页）
    self.appendOverlay = [[UIView alloc] initWithFrame:self.overlay.bounds];
    self.appendOverlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
    self.appendOverlay.userInteractionEnabled = YES;
    self.appendOverlay.alpha = 0;
    [self.overlay addSubview:self.appendOverlay];

    // 小气泡（波形）
    CGFloat abW = sw * 0.55;
    CGFloat abH = 70;
    CGFloat abY = sh * 0.35;
    self.appendBubble = [[UIView alloc] initWithFrame:CGRectMake((sw - abW) / 2, abY, abW, abH)];
    self.appendBubble.backgroundColor = [UIColor colorWithRed:0.88 green:0.94 blue:1.0 alpha:1.0];
    self.appendBubble.layer.cornerRadius = 14;
    self.appendBubble.clipsToBounds = YES;
    [self.appendOverlay addSubview:self.appendBubble];

    // 波形
    CGFloat waveW = abW * 0.85;
    CGFloat waveH = 40;
    self.appendWaveContainer = [[UIView alloc] initWithFrame:CGRectMake((abW - waveW) / 2, (abH - waveH) / 2, waveW, waveH)];
    [self.appendBubble addSubview:self.appendWaveContainer];

    self.appendWaveBars = [NSMutableArray array];
    CGFloat barW = 3, barGap = 2.5;
    NSInteger barCount = 24;
    CGFloat totalBarW = barCount * barW + (barCount - 1) * barGap;
    CGFloat startX = (waveW - totalBarW) / 2;
    for (NSInteger i = 0; i < barCount; i++) {
        UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(startX + i * (barW + barGap), waveH / 2 - 3, barW, 6)];
        bar.backgroundColor = [UIColor colorWithRed:0.35 green:0.55 blue:0.85 alpha:0.7];
        bar.layer.cornerRadius = 1.5;
        [self.appendWaveContainer addSubview:bar];
        [self.appendWaveBars addObject:bar];
    }

    // 底部提示
    self.appendHintLabel = [[UILabel alloc] init];
    self.appendHintLabel.text = LLang(@"松手 转文字，上滑取消");
    self.appendHintLabel.textColor = [UIColor whiteColor];
    self.appendHintLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.appendHintLabel.textAlignment = NSTextAlignmentCenter;
    self.appendHintLabel.frame = CGRectMake(0, CGRectGetMaxY(self.appendBubble.frame) + 16, sw, 20);
    [self.appendOverlay addSubview:self.appendHintLabel];

    [UIView animateWithDuration:0.25 animations:^{
        self.appendOverlay.alpha = 1.0;
    }];
}

- (void)updateAppendOverlayForState {
    if (self.state == WKHTTStateCancelling) {
        self.appendHintLabel.text = LLang(@"松手 取消");
        self.appendHintLabel.textColor = [UIColor colorWithRed:1.0 green:0.45 blue:0.45 alpha:1.0];
        self.appendBubble.backgroundColor = [UIColor colorWithRed:1.0 green:0.92 blue:0.92 alpha:1.0];
    } else {
        self.appendHintLabel.text = LLang(@"松手 转文字，上滑取消");
        self.appendHintLabel.textColor = [UIColor whiteColor];
        self.appendBubble.backgroundColor = [UIColor colorWithRed:0.88 green:0.94 blue:1.0 alpha:1.0];
    }
}

- (void)hideAppendOverlay {
    self.isAppendMode = NO;
    if (!self.appendOverlay) return;
    UIView *ov = self.appendOverlay;
    [UIView animateWithDuration:0.2 animations:^{ ov.alpha = 0; } completion:^(BOOL f) { [ov removeFromSuperview]; }];
    self.appendOverlay = nil;
    self.appendBubble = nil;
    self.appendWaveContainer = nil;
    self.appendWaveBars = nil;
    self.appendHintLabel = nil;
}

- (void)cancelAppendRecording {
    [self invalidateRecordTimers];
    if (self.audioRecorder.isRecording) [self.audioRecorder stop];
    [self cleanupRecordFile];
    [self restoreAudioSession];
    self.state = WKHTTStateResult;
    [self hideAppendOverlay];
}

- (void)stopAppendRecordingAndTranscribe {
    [self invalidateRecordTimers];
    if (!self.audioRecorder.isRecording) { [self hideAppendOverlay]; self.state = WKHTTStateResult; return; }

    NSTimeInterval duration = self.audioRecorder.currentTime;
    [self.audioRecorder stop];
    [self restoreAudioSession];
    self.recordedDuration = duration;

    if (duration < 1.0) {
        [self showHUD:LLang(@"说话时间太短")];
        [self hideAppendOverlay]; self.state = WKHTTStateResult; [self cleanupRecordFile]; return;
    }

    NSData *audioData = [NSData dataWithContentsOfFile:self.recordFilePath];
    self.recordedAudioData = audioData;
    if (!audioData || audioData.length == 0) {
        [self showHUD:LLang(@"录音数据异常")];
        [self hideAppendOverlay]; self.state = WKHTTStateResult; [self cleanupRecordFile]; return;
    }

    [self hideAppendOverlay];
    self.state = WKHTTStateThinking;
    [self startThinkingAnimation];
    self.resultTextView.editable = NO;
    self.resultBottomBar.hidden = YES;

    if ([[self currentAPIPreference] isEqualToString:kVoiceAPIApple]) {
        [self transcribeWithAppleASR:audioData];
    } else {
        [self transcribeWithServerAPI:audioData];
    }
}

#pragma mark - Thinking Animation (思考气泡动画)

- (void)startThinkingAnimation {
    [self stopThinkingAnimation];

    CGFloat bubbleW = self.bubbleView.bounds.size.width;
    CGFloat bubbleH = self.bubbleView.bounds.size.height;

    // 半透明遮罩（可以隐约看到下面的文字）
    self.thinkingOverlayView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bubbleW, bubbleH)];
    self.thinkingOverlayView.backgroundColor = [UIColor colorWithRed:0.88 green:0.94 blue:1.0 alpha:0.75];
    self.thinkingOverlayView.layer.cornerRadius = 16;
    [self.bubbleView addSubview:self.thinkingOverlayView];

    // 在遮罩上添加三个跳动圆点
    CGFloat dotSize = 10;
    CGFloat dotGap = 10;
    CGFloat totalW = 3 * dotSize + 2 * dotGap;
    CGFloat startX = (bubbleW - totalW) / 2;

    self.thinkingDots = [NSMutableArray array];
    for (NSInteger i = 0; i < 3; i++) {
        UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(startX + i * (dotSize + dotGap), (bubbleH - dotSize) / 2, dotSize, dotSize)];
        dot.backgroundColor = [UIColor colorWithRed:0.35 green:0.55 blue:0.85 alpha:0.9];
        dot.layer.cornerRadius = dotSize / 2;
        [self.thinkingOverlayView addSubview:dot];
        [self.thinkingDots addObject:dot];
    }

    self.thinkingDotIndex = 0;
    __weak typeof(self) ws = self;
    self.thinkingTimer = [NSTimer scheduledTimerWithTimeInterval:0.35 repeats:YES block:^(NSTimer *t) {
        [ws animateThinkingDots];
    }];
}

- (void)animateThinkingDots {
    if (!self.thinkingDots || self.thinkingDots.count == 0) return;
    NSInteger idx = self.thinkingDotIndex % 3;
    for (NSInteger i = 0; i < 3; i++) {
        UIView *dot = self.thinkingDots[i];
        if (i == idx) {
            [UIView animateWithDuration:0.2 animations:^{
                dot.transform = CGAffineTransformMakeScale(1.4, 1.4);
                dot.alpha = 1.0;
            } completion:^(BOOL f) {
                [UIView animateWithDuration:0.15 animations:^{
                    dot.transform = CGAffineTransformIdentity;
                    dot.alpha = 0.8;
                }];
            }];
        }
    }
    self.thinkingDotIndex++;
}

- (void)stopThinkingAnimation {
    [self.thinkingTimer invalidate]; self.thinkingTimer = nil;
    [self.thinkingOverlayView removeFromSuperview];
    self.thinkingOverlayView = nil;
    self.thinkingDots = nil;
}

- (void)finishThinkingAndShowText {
    [self stopThinkingAnimation];
    self.state = WKHTTStateResult;

    // 更新文本框内容
    self.resultTextView.text = self.transcribedText;
    [self updateResultTextViewHeight];
    self.resultTextView.editable = YES;

    // 显示底部按钮
    self.resultBottomBar.hidden = NO;
    self.resultMicBtn.hidden = NO;
    self.apiSwitchBtn.hidden = NO;
}

#pragma mark - Result UI

- (void)transitionToResultUIWithThinking:(BOOL)showThinking {
    // 隐藏录音 UI（包括底部弧形和胶囊按钮）
    self.waveContainer.hidden = YES;
    self.bottomAreaView.hidden = YES;
    self.bubbleTail.hidden = YES;
    self.cancelPill.hidden = YES;
    self.sendVoicePill.hidden = YES;

    CGFloat sw = self.currentWindow.bounds.size.width;
    CGFloat sh = self.currentWindow.bounds.size.height;

    // 点击蒙版收起键盘
    UITapGestureRecognizer *tapDismiss = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onOverlayTapped:)];
    tapDismiss.cancelsTouchesInView = NO;
    [self.overlay addGestureRecognizer:tapDismiss];

    // 调整气泡
    CGFloat bubbleW = sw - 40;
    CGFloat minBubbleH = 80;
    CGFloat bubbleY = sh * 0.15;

    [UIView animateWithDuration:0.3 animations:^{
        self.bubbleView.frame = CGRectMake(20, bubbleY, bubbleW, minBubbleH);
        self.bubbleView.backgroundColor = [UIColor colorWithRed:0.88 green:0.94 blue:1.0 alpha:1.0];
    }];

    // 可编辑文本框
    self.resultTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, 10, bubbleW - 24, minBubbleH - 20)];
    self.resultTextView.backgroundColor = [UIColor clearColor];
    self.resultTextView.textColor = [UIColor blackColor];
    self.resultTextView.font = [UIFont systemFontOfSize:17];
    self.resultTextView.delegate = self;
    self.resultTextView.scrollEnabled = YES;
    self.resultTextView.showsVerticalScrollIndicator = YES;
    self.resultTextView.editable = !showThinking;
    self.resultTextView.text = self.transcribedText ?: @"";
    [self.bubbleView addSubview:self.resultTextView];

    if (showThinking) {
        [self startThinkingAnimation];
    }

    // ===== 底部按钮栏 =====
    CGFloat barH = 80;
    CGFloat barY = sh - barH - 40;
    self.resultBottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, barY, sw, barH)];
    self.resultBottomBar.hidden = showThinking;
    [self.overlay addSubview:self.resultBottomBar];

    CGFloat btnSize = 52;
    CGFloat btnY = 0;
    CGFloat spacing = sw / 4.0; // 3个按钮均分

    // 取消按钮
    self.resultCancelBtn = [self createIconButton:btnSize imageAsset:@"Conversation/Toolbar/HTTCancel"];
    self.resultCancelBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    self.resultCancelBtn.center = CGPointMake(spacing * 1, btnY + btnSize / 2);
    [self.resultCancelBtn addTarget:self action:@selector(onResultCancel) forControlEvents:UIControlEventTouchUpInside];
    [self.resultBottomBar addSubview:self.resultCancelBtn];
    [self.resultBottomBar addSubview:[self createSmallLabel:LLang(@"取消") centerX:self.resultCancelBtn.center.x belowY:CGRectGetMaxY(self.resultCancelBtn.frame) + 6]];

    // 继续语音按钮 — 长按触发追加录音
    self.resultMicBtn = [self createIconButton:btnSize imageAsset:@"Conversation/Toolbar/HTTMic"];
    self.resultMicBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    self.resultMicBtn.center = CGPointMake(spacing * 2, btnY + btnSize / 2);
    self.resultMicBtn.hidden = showThinking;
    // 长按手势替代点击
    UILongPressGestureRecognizer *micLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleAppendLongPress:)];
    micLongPress.minimumPressDuration = 0.15;
    [self.resultMicBtn addGestureRecognizer:micLongPress];
    [self.resultBottomBar addSubview:self.resultMicBtn];
    [self.resultBottomBar addSubview:[self createSmallLabel:LLang(@"按住继续") centerX:self.resultMicBtn.center.x belowY:CGRectGetMaxY(self.resultMicBtn.frame) + 6]];

    // 发送文字按钮
    CGFloat sendW = 72, sendH = btnSize;
    self.resultSendTextBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.resultSendTextBtn setTitle:LLang(@"发送") forState:UIControlStateNormal];
    [self.resultSendTextBtn setTitleColor:[UIColor colorWithRed:0.15 green:0.15 blue:0.2 alpha:1.0] forState:UIControlStateNormal];
    self.resultSendTextBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.resultSendTextBtn.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    self.resultSendTextBtn.layer.cornerRadius = sendH / 2;
    self.resultSendTextBtn.frame = CGRectMake(0, 0, sendW, sendH);
    self.resultSendTextBtn.center = CGPointMake(spacing * 3, btnY + btnSize / 2);
    [self.resultSendTextBtn addTarget:self action:@selector(onResultSendText) forControlEvents:UIControlEventTouchUpInside];
    [self.resultBottomBar addSubview:self.resultSendTextBtn];

    // API 切换按钮 — 使用主题色（紫色）
    UIColor *themeColor = [WKApp shared].config.themeColor;
    self.apiSwitchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.apiSwitchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.apiSwitchBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.apiSwitchBtn.backgroundColor = themeColor;
    self.apiSwitchBtn.layer.cornerRadius = 14;
    [self.apiSwitchBtn addTarget:self action:@selector(onAPISwitchTapped) forControlEvents:UIControlEventTouchUpInside];
    [self updateAPISwitchBtnTitle];
    [self.apiSwitchBtn sizeToFit];
    CGFloat apiBtnW = MAX(self.apiSwitchBtn.frame.size.width + 24, 100);
    self.apiSwitchBtn.frame = CGRectMake((sw - apiBtnW) / 2, bubbleY - 40, apiBtnW, 28);
    self.apiSwitchBtn.hidden = showThinking;
    [self.overlay addSubview:self.apiSwitchBtn];

    self.overlay.userInteractionEnabled = YES;
}

- (void)onOverlayTapped:(UITapGestureRecognizer *)tap {
    // 点击蒙版收起键盘
    [self.resultTextView resignFirstResponder];
}

- (UIButton *)createIconButton:(CGFloat)size imageAsset:(NSString *)assetName {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, size, size);
    btn.layer.cornerRadius = size / 2;
    btn.clipsToBounds = YES;
    btn.imageEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
    btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *img = [WKApp.shared loadImage:assetName moduleID:@"WuKongBase"];
    if (img) [btn setImage:img forState:UIControlStateNormal];
    return btn;
}

- (UILabel *)createSmallLabel:(NSString *)text centerX:(CGFloat)cx belowY:(CGFloat)y {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = text;
    lbl.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    lbl.font = [UIFont systemFontOfSize:11];
    lbl.textAlignment = NSTextAlignmentCenter;
    [lbl sizeToFit];
    lbl.center = CGPointMake(cx, y);
    return lbl;
}

- (void)updateResultTextViewHeight {
    if (!self.resultTextView || !self.bubbleView) return;
    CGFloat sw = self.currentWindow.bounds.size.width;
    CGFloat bubbleW = sw - 40;
    CGFloat textW = bubbleW - 24;

    CGSize fitSize = [self.resultTextView sizeThatFits:CGSizeMake(textW, CGFLOAT_MAX)];
    CGFloat textH = MIN(fitSize.height, kMaxTextViewHeight);
    CGFloat bubbleH = MAX(80, textH + 20);

    CGFloat bubbleY = self.bubbleView.frame.origin.y;
    [UIView animateWithDuration:0.2 animations:^{
        self.bubbleView.frame = CGRectMake(20, bubbleY, bubbleW, bubbleH);
        self.resultTextView.frame = CGRectMake(12, 10, textW, bubbleH - 20);
    }];

    self.resultTextView.scrollEnabled = (fitSize.height > kMaxTextViewHeight);
}

#pragma mark - Keyboard

- (void)keyboardWillShow:(NSNotification *)notification {
    if (self.state != WKHTTStateResult) return;
    CGRect endFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    self.keyboardHeight = endFrame.size.height;
    [UIView animateWithDuration:duration animations:^{
        [self layoutResultUIForKeyboard];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if (self.state != WKHTTStateResult) return;
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    self.keyboardHeight = 0;
    [UIView animateWithDuration:duration animations:^{
        [self layoutResultUIForKeyboard];
    }];
}

- (void)layoutResultUIForKeyboard {
    if (!self.resultBottomBar || !self.currentWindow) return;
    CGFloat sw = self.currentWindow.bounds.size.width;
    CGFloat sh = self.currentWindow.bounds.size.height;
    CGFloat barH = self.resultBottomBar.bounds.size.height;

    if (self.keyboardHeight > 0) {
        // 键盘弹起：底部按钮栏移到键盘上方
        CGFloat barY = sh - self.keyboardHeight - barH;
        self.resultBottomBar.frame = CGRectMake(0, barY, sw, barH);
    } else {
        // 键盘收起：恢复原位
        CGFloat barY = sh - barH - 40;
        self.resultBottomBar.frame = CGRectMake(0, barY, sw, barH);
    }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    self.transcribedText = textView.text;
    [self updateResultTextViewHeight];
}

#pragma mark - Result Actions

- (void)onResultCancel {
    self.transcribedText = nil;
    self.recordedAudioData = nil;
    [self hideOverlay];
}

- (void)onResultSendText {
    NSString *text = self.resultTextView.text ?: self.transcribedText;
    if (text.length > 0) {
        // 解析 @mention
        NSArray *members = nil;
        if ([self.delegate respondsToSelector:@selector(holdToTalkManagerChannelMembers:)]) {
            members = [self.delegate holdToTalkManagerChannelMembers:self];
        }
        NSMutableArray<WKInputMentionItem *> *mentions = [NSMutableArray array];
        if (members.count > 0) {
            text = [self parseMentionMarkers:text members:members mentions:mentions];
        }
        if (mentions.count > 0 && [self.delegate respondsToSelector:@selector(holdToTalkManager:sendText:mentions:)]) {
            [self.delegate holdToTalkManager:self sendText:text mentions:mentions];
        } else if ([self.delegate respondsToSelector:@selector(holdToTalkManager:sendText:)]) {
            [self.delegate holdToTalkManager:self sendText:text];
        }
    }
    self.transcribedText = nil; self.recordedAudioData = nil;
    [self hideOverlay];
}

#pragma mark - API Switch

- (void)updateAPISwitchBtnTitle {
    NSString *title = [NSString stringWithFormat:@" %@ ▾", [self currentAPIDisplayName]];
    [self.apiSwitchBtn setTitle:title forState:UIControlStateNormal];
    [self.apiSwitchBtn sizeToFit];
    if (self.apiSwitchBtn.superview && self.currentWindow) {
        CGFloat sw = self.currentWindow.bounds.size.width;
        CGFloat w = MAX(self.apiSwitchBtn.frame.size.width + 24, 100);
        CGFloat y = self.apiSwitchBtn.frame.origin.y;
        self.apiSwitchBtn.frame = CGRectMake((sw - w) / 2, y, w, 28);
    }
}

- (void)onAPISwitchTapped {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:LLang(@"选择语音识别引擎") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *current = [self currentAPIPreference];
    NSString *serverT = [current isEqualToString:kVoiceAPIServer] ? @"✓ 自研引擎" : @"自研引擎";
    [sheet addAction:[UIAlertAction actionWithTitle:serverT style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self setAPIPreference:kVoiceAPIServer]; }]];
    NSString *appleT = [current isEqualToString:kVoiceAPIApple] ? @"✓ Apple引擎" : @"Apple引擎";
    [sheet addAction:[UIAlertAction actionWithTitle:appleT style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self setAPIPreference:kVoiceAPIApple]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [[WKNavigationManager shared].topViewController presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Waveform

- (void)updateRecordTimer {
    self.recordSeconds++;
    if (self.recordSeconds >= 60) [self stopRecordingAndTranscribe];
}

- (void)updateWaveform {
    if (self.state != WKHTTStateRecording && self.state != WKHTTStateSendVoice && self.state != WKHTTStateCancelling) return;
    if (!self.audioRecorder) return;

    [self.audioRecorder updateMeters];
    float power = [self.audioRecorder averagePowerForChannel:0];
    float norm = MAX(0, MIN(1, (power + 40) / 40.0));
    if (norm < 0.08) norm = 0;
    self.currentPower = norm;
    // 收集波形数据用于语音消息
    [self.recordedLevels addObject:@(norm)];

    // 选择当前活跃的波形条和容器
    NSArray<UIView *> *bars = self.isAppendMode ? self.appendWaveBars : self.waveBars;
    UIView *container = self.isAppendMode ? self.appendWaveContainer : self.waveContainer;

    if (!bars || bars.count == 0 || !container) return;
    CGFloat containerH = container.bounds.size.height;
    CGFloat barW = 3, baseH = 6;
    CGFloat center = bars.count / 2.0;

    for (NSInteger i = 0; i < (NSInteger)bars.count; i++) {
        CGFloat dist = fabs(i - center) / center;
        CGFloat h = baseH;
        if (self.currentPower > 0) {
            CGFloat att = 1.0 - dist * 0.6;
            CGFloat rnd = 0.3 + (arc4random_uniform(70) / 100.0);
            h = baseH + self.currentPower * (containerH * 0.7) * att * rnd;
        }
        h = MAX(baseH, MIN(h, containerH - 4));
        UIView *bar = bars[i];
        [UIView animateWithDuration:0.1 animations:^{
            bar.frame = CGRectMake(bar.frame.origin.x, (containerH - h) / 2, barW, h);
        }];
    }
}

#pragma mark - Utilities

- (void)invalidateRecordTimers {
    [self.recordTimer invalidate]; self.recordTimer = nil;
    [self.waveformTimer invalidate]; self.waveformTimer = nil;
}

- (void)cleanupRecordFile {
    if (self.recordFilePath) {
        [[NSFileManager defaultManager] removeItemAtPath:self.recordFilePath error:nil];
        self.recordFilePath = nil;
    }
}

- (void)restoreAudioSession {
    if (self.previousAudioCategory) {
        [[AVAudioSession sharedInstance] setCategory:self.previousAudioCategory withOptions:self.previousAudioCategoryOptions error:nil];
        self.previousAudioCategory = nil;
    }
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (void)cleanup {
    [self invalidateRecordTimers];
    [self stopThinkingAnimation];
    if (self.audioRecorder.isRecording) { [self.audioRecorder stop]; [self restoreAudioSession]; }
    [self cleanupRecordFile];
}

- (void)showPermissionAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"需要麦克风权限") message:LLang(@"请在设置中允许访问麦克风") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"去设置") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [[WKNavigationManager shared].topViewController presentViewController:alert animated:YES completion:nil];
}

- (void)showHUD:(NSString *)text {
    UIView *target = self.currentWindow ?: [UIApplication sharedApplication].keyWindow;
    if (target) [target showHUDWithHide:text];
}

#pragma mark - SFSpeechRecognizerDelegate

- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {}

#pragma mark - @Mention Parsing

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
