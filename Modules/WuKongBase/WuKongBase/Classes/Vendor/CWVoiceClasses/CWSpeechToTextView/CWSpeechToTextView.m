//
//  CWSpeechToTextView.m
//  WuKongBase
//

#import "CWSpeechToTextView.h"
#import <Speech/Speech.h>
#import <AVFoundation/AVFoundation.h>
#import "UIView+CWChat.h"
#import "CWRecordStateView.h"
#import "CWVoiceButton.h"
#import "CWVoiceView.h"
#import "WKApp.h"
#import "WuKongBase.h"

static CGFloat const kCancelThreshold = -80.0;
static CGFloat const maxScale = 0.45;

@interface CWSpeechToTextView () <UIGestureRecognizerDelegate, SFSpeechRecognizerDelegate>

// UI - 与对讲页完全一致
@property (nonatomic, weak) CWRecordStateView *stateView;
@property (nonatomic, weak) CWVoiceButton *micButton;
@property (nonatomic, weak) CWVoiceButton *sendButton;    // 左侧发送按钮
@property (nonatomic, weak) CWVoiceButton *cancelButton;  // 右侧删除按钮
@property (nonatomic, weak) UIImageView *voiceLine;
@property (nonatomic, weak) UIPanGestureRecognizer *pan;

// 语音识别引擎
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;

// 波形 - 与 CWRecordStateView 一致的参数
@property (nonatomic, weak) UIView *levelContentView;
@property (nonatomic, weak) UILabel *timeLabel;
@property (nonatomic, weak) CAReplicatorLayer *replicatorL;
@property (nonatomic, weak) CAShapeLayer *levelLayer;
@property (nonatomic, strong) NSMutableArray *currentLevels;
@property (nonatomic, strong) UIBezierPath *levelPath;
@property (nonatomic, strong) CADisplayLink *levelTimer;
@property (nonatomic, strong) NSTimer *audioTimer;
@property (nonatomic, assign) NSInteger recordDuration;

// 状态
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) BOOL isCancelled;
@property (nonatomic, assign) BOOL isSendAction;  // 拖到发送按钮时标记
@property (nonatomic, assign) float currentAudioLevel;
@property (nonatomic, copy) NSString *recognizedText;   // 完整的最终文本
@property (nonatomic, copy) NSString *confirmedText;    // 已结束任务的累积文本（isFinal后保存）
@property (nonatomic, assign) NSInteger taskGeneration;

@end

static CGFloat const levelWidth = 3.0;
static CGFloat const levelMargin = 2.0;

@implementation CWSpeechToTextView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"zh-CN"]];
        _speechRecognizer.delegate = self;
        _audioEngine = [[AVAudioEngine alloc] init];
        [self setupSubViews];
    }
    return self;
}

- (void)dealloc {
    [self stopRecording];
    [_levelTimer invalidate];
    [_audioTimer invalidate];
}

#pragma mark - UI Setup（完全参考 CWTalkBackView）

- (void)setupSubViews {
    [self stateView];
    [self voiceLine];
    [self micButton];
    [self sendButton];
    [self cancelButton];
}

// 状态提示 - 与对讲页 CWRecordStateView 位置一致
- (CWRecordStateView *)stateView {
    if (_stateView == nil) {
        CWRecordStateView *stateView = [[CWRecordStateView alloc] initWithFrame:CGRectMake(0, 10, self.cw_width, 50)];
        stateView.recordState = CWRecordStateDefault;
        [self addSubview:stateView];
        _stateView = stateView;
        // 覆盖默认文字为"语音转文字"
        [self updateStateViewDefaultText];
    }
    return _stateView;
}

- (void)updateStateViewDefaultText {
    for (UIView *subview in self.stateView.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if ([label.text isEqualToString:LLang(@"按住说话")]) {
                label.text = LLang(@"语音转文字");
                [label sizeToFit];
                label.cw_centerX = self.stateView.cw_width / 2;
                label.cw_centerY = self.stateView.cw_height / 2;
                break;
            }
        }
    }
}

// 曲线图 - 与对讲页一致
- (UIImageView *)voiceLine {
    if (_voiceLine == nil) {
        UIImageView *imageV = [[UIImageView alloc] initWithImage:[self imageName:@"Conversation/VoiceRecord/aio_voice_line"]];
        imageV.hidden = YES;
        [self addSubview:imageV];
        _voiceLine = imageV;
    }
    return _voiceLine;
}

// 麦克风按钮 - 与对讲页完全一致
- (CWVoiceButton *)micButton {
    if (_micButton == nil) {
        CWVoiceButton *btn = [CWVoiceButton buttonWithBackImageNor:@"Conversation/VoiceRecord/aio_voice_button_nor"
                                                  backImageSelected:@"Conversation/VoiceRecord/aio_voice_button_press"
                                                           imageNor:@"Conversation/VoiceRecord/aio_voice_button_icon"
                                                      imageSelected:@"Conversation/VoiceRecord/aio_voice_button_icon"
                                                              frame:CGRectMake(0, self.stateView.cw_bottom, 0, 0)
                                                         isMicPhone:YES];
        // 手指按下
        [btn addTarget:self action:@selector(startRecorde:) forControlEvents:UIControlEventTouchDown];
        // 松开手指 — 无论手指在按钮内还是外，都触发发送
        [btn addTarget:self action:@selector(sendRecorde:) forControlEvents:UIControlEventTouchUpInside];
        [btn addTarget:self action:@selector(sendRecorde:) forControlEvents:UIControlEventTouchUpOutside];
        // 拖动手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        pan.delegate = self;
        _pan = pan;
        [btn addGestureRecognizer:pan];

        btn.cw_centerX = self.cw_width / 2.0;
        self.voiceLine.center = btn.center;
        [self addSubview:btn];
        _micButton = btn;
    }
    return _micButton;
}

// 左侧发送按钮
- (CWVoiceButton *)sendButton {
    if (_sendButton == nil) {
        CWVoiceButton *btn = [CWVoiceButton buttonWithBackImageNor:@"Conversation/VoiceRecord/aio_voice_operate_nor"
                                                  backImageSelected:@"Conversation/VoiceRecord/aio_voice_operate_press"
                                                           imageNor:@"Conversation/VoiceRecord/aio_voice_stt_send_nor"
                                                      imageSelected:@"Conversation/VoiceRecord/aio_voice_stt_send_press"
                                                              frame:CGRectMake(35, self.stateView.cw_bottom + 10, 0, 0)
                                                         isMicPhone:NO];
        btn.imageEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:btn];
        btn.hidden = YES;
        _sendButton = btn;
    }
    return _sendButton;
}

// 右侧删除按钮
- (CWVoiceButton *)cancelButton {
    if (_cancelButton == nil) {
        CWVoiceButton *btn = [CWVoiceButton buttonWithBackImageNor:@"Conversation/VoiceRecord/aio_voice_operate_nor"
                                                  backImageSelected:@"Conversation/VoiceRecord/aio_voice_operate_press"
                                                           imageNor:@"Conversation/VoiceRecord/aio_voice_stt_delete_nor"
                                                      imageSelected:@"Conversation/VoiceRecord/aio_voice_stt_delete_press"
                                                              frame:CGRectMake(self.cw_width - 35, self.stateView.cw_bottom + 10, 0, 0)
                                                         isMicPhone:NO];
        btn.frame = CGRectMake(self.cw_width - 35 - btn.norImage.size.width, self.stateView.cw_bottom + 10, btn.norImage.size.width, btn.norImage.size.height);
        btn.imageEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:btn];
        btn.hidden = YES;
        _cancelButton = btn;
    }
    return _cancelButton;
}

// 波形视图 - 居中放大显示
- (void)setupLevelContentView {
    if (_levelContentView) return;

    CGFloat contentHeight = 60;
    UIView *contentV = [[UIView alloc] initWithFrame:CGRectMake(0, 5, self.cw_width, contentHeight)];
    contentV.hidden = YES;
    [self addSubview:contentV];
    _levelContentView = contentV;

    // 时间标签 - 居中在波形上方
    UILabel *timeL = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, contentV.cw_width, 20)];
    timeL.text = @"0:00";
    timeL.textAlignment = NSTextAlignmentCenter;
    timeL.font = [UIFont systemFontOfSize:15];
    timeL.textColor = UIColorFromRGBA(119, 119, 119, 1.0);
    [contentV addSubview:timeL];
    _timeLabel = timeL;

    // 波形层 - 居中放大
    CGFloat waveHeight = 30;
    CGFloat waveWidth = contentV.cw_width * 0.6;
    CGFloat waveX = (contentV.cw_width - waveWidth) / 2.0;
    CGFloat waveY = timeL.cw_bottom + 2;

    CAReplicatorLayer *repL = [CAReplicatorLayer layer];
    repL.frame = CGRectMake(waveX, waveY, waveWidth, waveHeight);
    repL.instanceCount = 2;
    repL.instanceTransform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
    [contentV.layer addSublayer:repL];
    _replicatorL = repL;

    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.frame = CGRectMake(0, 0, waveWidth, waveHeight);
    layer.strokeColor = UIColorFromRGBA(253, 99, 9, 1.0).CGColor;
    layer.lineWidth = levelWidth;
    [repL addSublayer:layer];
    _levelLayer = layer;
}

#pragma mark - 手势代理

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isEqual:_pan]) {
        return self.micButton.isSelected;
    }
    return YES;
}

#pragma mark - 录音按钮事件

- (void)startRecorde:(UIButton *)btn {
    btn.enabled = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        btn.enabled = YES;
    });

    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (status) {
                case SFSpeechRecognizerAuthorizationStatusAuthorized:
                    [self beginSpeechRecognition:btn];
                    break;
                case SFSpeechRecognizerAuthorizationStatusDenied:
                case SFSpeechRecognizerAuthorizationStatusRestricted:
                    btn.selected = NO;
                    [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"请在设置中允许语音识别")];
                    break;
                case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                    btn.selected = NO;
                    break;
            }
        });
    }];
}

- (void)beginSpeechRecognition:(UIButton *)btn {
    if (!self.speechRecognizer.isAvailable) {
        btn.selected = NO;
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"语音识别不可用")];
        return;
    }

    if ([self.delegate respondsToSelector:@selector(speechToTextViewDidBeginRecording:)]) {
        [self.delegate speechToTextViewDidBeginRecording:self];
    }

    btn.selected = YES;
    self.isCancelled = NO;
    self.isSendAction = NO;
    self.recognizedText = nil;
    self.confirmedText = nil;

    // 隐藏底部标签
    [(CWVoiceView *)self.superview.superview setState:CWVoiceStateRecord];

    // 按钮动画 - 与对讲页一致
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.10 animations:^{
        weakSelf.micButton.transform = CGAffineTransformMakeScale(1.1, 1.1);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.05 animations:^{
            weakSelf.micButton.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            [weakSelf startRecording];
        }];
    }];
}

// 松手 → 输入到输入框（不发送）
- (void)sendRecorde:(UIButton *)btn {
    NSTimeInterval t = 0;
    if (!self.isRecording) {
        t = 0.3;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(t * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self finishAndInput];
    });
}

- (void)finishAndSend {
    if (!self.isRecording) return; // 防止重复调用

    // 停止音频采集，但保留识别任务处理剩余音频
    [self stopAudioCapture];

    // 立即切换UI
    self.micButton.selected = NO;
    self.sendButton.selected = NO;
    self.sendButton.hidden = YES;
    self.sendButton.backgroudLayer.transform = CATransform3DIdentity;
    self.cancelButton.selected = NO;
    self.cancelButton.hidden = YES;
    self.cancelButton.backgroudLayer.transform = CATransform3DIdentity;
    self.voiceLine.hidden = YES;
    [(CWVoiceView *)self.superview.superview setState:CWVoiceStateDefault];

    // 延迟等待识别器处理完剩余音频后再获取最终文本
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        [strongSelf stopRecognitionAndSession];

        NSString *finalText = strongSelf.recognizedText.length > 0 ? strongSelf.recognizedText : strongSelf.confirmedText;
        NSLog(@"[STT] finishAndSend: finalText='%@'", finalText ?: @"");

        if (strongSelf.isCancelled) {
            NSLog(@"语音转文字：已取消");
        } else if (finalText.length > 0) {
            if ([strongSelf.delegate respondsToSelector:@selector(speechToTextView:didRecognizeText:)]) {
                [strongSelf.delegate speechToTextView:strongSelf didRecognizeText:finalText];
            }
        } else {
            [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"未识别到语音")];
        }

        [strongSelf resetUI];
    });
}

// 松手默认行为：文字输入到输入框
- (void)finishAndInput {
    if (!self.isRecording) return;

    // 停止音频采集，但保留识别任务处理剩余音频
    [self stopAudioCapture];

    // 立即切换UI
    self.micButton.selected = NO;
    self.sendButton.selected = NO;
    self.sendButton.hidden = YES;
    self.sendButton.backgroudLayer.transform = CATransform3DIdentity;
    self.cancelButton.selected = NO;
    self.cancelButton.hidden = YES;
    self.cancelButton.backgroudLayer.transform = CATransform3DIdentity;
    self.voiceLine.hidden = YES;
    [(CWVoiceView *)self.superview.superview setState:CWVoiceStateDefault];

    // 延迟等待识别器处理完剩余音频后再获取最终文本
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        [strongSelf stopRecognitionAndSession];

        NSString *finalText = strongSelf.recognizedText.length > 0 ? strongSelf.recognizedText : strongSelf.confirmedText;
        NSLog(@"[STT] finishAndInput: finalText='%@'", finalText ?: @"");

        if (finalText.length > 0) {
            if ([strongSelf.delegate respondsToSelector:@selector(speechToTextView:didRecognizeTextForInput:)]) {
                [strongSelf.delegate speechToTextView:strongSelf didRecognizeTextForInput:finalText];
            }
        } else {
            [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"未识别到语音")];
        }

        [strongSelf resetUI];
    });
}

#pragma mark - 拖动手势

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (!self.micButton.isSelected) return;

    CGPoint point = [pan locationInView:pan.view.superview];
    CGPoint translation = [pan translationInView:self];

    if (pan.state == UIGestureRecognizerStateBegan) {
        // 刚开始拖动，不做任何操作
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        // 上滑取消
        if (translation.y < kCancelThreshold) {
            self.isCancelled = YES;
            self.isSendAction = NO;
            self.stateView.hidden = NO;
            self.stateView.recordState = CWRecordStateCancel;
            self.levelContentView.hidden = YES;
            return;
        }

        if (point.x < self.cw_width / 2.0) {
            // 左侧：发送按钮交互
            [self transitionButton:self.sendButton WithPoint:point containBlock:^(BOOL isContain) {
                if (isContain) {
                    self.isSendAction = YES;
                    self.isCancelled = NO;
                    self.stateView.hidden = NO;
                    self.stateView.recordState = CWRecordStateSend;
                    self.levelContentView.hidden = YES;
                } else {
                    self.isSendAction = NO;
                    self.stateView.hidden = YES;
                    self.levelContentView.hidden = NO;
                }
            }];
            // 重置右侧按钮
            self.cancelButton.backgroudLayer.transform = CATransform3DIdentity;
            self.cancelButton.selected = NO;
        } else {
            // 右侧：删除按钮交互
            [self transitionButton:self.cancelButton WithPoint:point containBlock:^(BOOL isContain) {
                if (isContain) {
                    self.isCancelled = YES;
                    self.isSendAction = NO;
                    self.stateView.hidden = NO;
                    self.stateView.recordState = CWRecordStateCancel;
                    self.levelContentView.hidden = YES;
                } else {
                    self.isCancelled = NO;
                    self.stateView.hidden = YES;
                    self.levelContentView.hidden = NO;
                }
            }];
            // 重置左侧按钮
            self.sendButton.backgroudLayer.transform = CATransform3DIdentity;
            self.sendButton.selected = NO;
        }
    } else {
        // 松开手指
        if (self.isSendAction) {
            // 拖到发送按钮 → 直接发送
            [self finishAndSend];
        } else if (self.isCancelled) {
            // 拖到删除按钮或上滑 → 取消
            NSLog(@"语音转文字：已取消");
            [self stopRecording];
            self.micButton.selected = NO;
            self.sendButton.selected = NO;
            self.sendButton.hidden = YES;
            self.sendButton.backgroudLayer.transform = CATransform3DIdentity;
            self.cancelButton.selected = NO;
            self.cancelButton.hidden = YES;
            self.cancelButton.backgroudLayer.transform = CATransform3DIdentity;
            self.voiceLine.hidden = YES;
            [(CWVoiceView *)self.superview.superview setState:CWVoiceStateDefault];
            [self resetUI];
        } else {
            // 默认松手 → 输入到输入框
            [self finishAndInput];
        }
        self.isSendAction = NO;
    }
}

#pragma mark 按钮形变（与对讲页一致）

- (void)transitionButton:(CWVoiceButton *)btn WithPoint:(CGPoint)point containBlock:(void(^)(BOOL isContain))block {
    CGFloat distance = [self distanceWithPointA:btn.center pointB:point];
    CGFloat d = btn.cw_width * 3 / 4;
    CGFloat x = distance * maxScale / d;
    CGFloat scale = 1 - x;
    scale = scale > 0 ? scale > maxScale ? maxScale : scale : 0;
    CGPoint p = [self.layer convertPoint:point toLayer:btn.backgroudLayer];
    if ([btn.backgroudLayer containsPoint:p]) {
        btn.selected = YES;
        btn.backgroudLayer.transform = CATransform3DMakeScale(1 + maxScale, 1 + maxScale, 1);
        if (block) block(YES);
    } else {
        btn.backgroudLayer.transform = CATransform3DMakeScale(1 + scale, 1 + scale, 1);
        btn.selected = NO;
        if (block) block(NO);
    }
}

- (CGFloat)distanceWithPointA:(CGPoint)pointA pointB:(CGPoint)pointB {
    return sqrt(pow((pointA.x - pointB.x), 2) + pow((pointA.y - pointB.y), 2));
}

// 发送按钮与删除按钮出现动画 - 参考对讲页 animationPlayAndCancelBtn
- (void)animationSendAndCancelBtn {
    [self animationButtonAppear:self.sendButton fromOffsetX:20];
    [self animationButtonAppear:self.cancelButton fromOffsetX:-20];
}

- (void)animationButtonAppear:(UIView *)view fromOffsetX:(CGFloat)offsetX {
    view.hidden = NO;
    CABasicAnimation *positionAnim = [CABasicAnimation animationWithKeyPath:@"position"];
    positionAnim.fromValue = [NSValue valueWithCGPoint:CGPointMake(view.center.x + offsetX, view.center.y)];
    positionAnim.toValue = [NSValue valueWithCGPoint:view.center];
    positionAnim.duration = 0.15;

    CABasicAnimation *opacityAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacityAnim.toValue = @1;
    opacityAnim.fromValue = @0;

    CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
    animationGroup.animations = @[positionAnim, opacityAnim];
    animationGroup.duration = 0.15;
    [view.layer addAnimation:animationGroup forKey:nil];
}

#pragma mark - 语音识别

- (void)startRecording {
    if (self.recognitionTask) {
        [self.recognitionTask cancel];
        self.recognitionTask = nil;
    }

    // 重建 audioEngine，避免首次授权后 inputNode 格式无效
    self.audioEngine = [[AVAudioEngine alloc] init];

    NSError *error;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                         mode:AVAudioSessionModeMeasurement
                      options:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionDuckOthers
                        error:&error];
    if (error) {
        NSLog(@"Audio session setCategory error: %@", error);
        return;
    }
    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    if (error) {
        NSLog(@"Audio session setActive error: %@", error);
        return;
    }

    AVAudioInputNode *inputNode = self.audioEngine.inputNode;
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];

    if (recordingFormat.sampleRate == 0 || recordingFormat.channelCount == 0) {
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"语音识别不可用")];
        return;
    }

    self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    self.recognitionRequest.shouldReportPartialResults = YES;
    self.recognitionRequest.taskHint = SFSpeechRecognitionTaskHintDictation;
    // iOS 16+ 启用自动标点
    if (@available(iOS 16, *)) {
        self.recognitionRequest.addsPunctuation = YES;
    }

    self.taskGeneration++;
    [self startRecognitionTaskWithGeneration:self.taskGeneration];

    @try {
        [inputNode removeTapOnBus:0];
    } @catch (NSException *exception) {}

    __weak typeof(self) weakSelf = self;
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        [strongSelf.recognitionRequest appendAudioPCMBuffer:buffer];

        if (buffer.floatChannelData == NULL || buffer.frameLength == 0) return;
        float *channelData = buffer.floatChannelData[0];
        NSUInteger frameLength = buffer.frameLength;
        float rms = 0;
        for (NSUInteger i = 0; i < frameLength; i++) {
            rms += channelData[i] * channelData[i];
        }
        rms = sqrtf(rms / frameLength);
        // 与语音输入统一：RMS 转 dB，再映射 [-55dB, -10dB] → [0, 1]
        float dB = 20 * log10f(MAX(rms, 0.00001f));
        float level = (dB + 55) / 45.0f;
        level = MAX(0.05f, MIN(1.0f, level));
        strongSelf.currentAudioLevel = level;
    }];

    [self.audioEngine prepare];
    NSError *startError;
    [self.audioEngine startAndReturnError:&startError];

    if (startError) {
        NSLog(@"Audio engine start error: %@", startError);
        [inputNode removeTapOnBus:0];
        return;
    }

    self.isRecording = YES;

    // UI - 隐藏状态文字，显示波形
    self.stateView.hidden = YES;
    [self setupLevelContentView];
    self.levelContentView.hidden = NO;

    // 曲线动画 - 与对讲页一致
    self.voiceLine.transform = CGAffineTransformMakeScale(0.8, 0.8);
    self.voiceLine.hidden = NO;
    [UIView animateWithDuration:0.15 animations:^{
        self.voiceLine.transform = CGAffineTransformIdentity;
    }];

    // 发送+删除按钮动画
    [self animationSendAndCancelBtn];

    // 启动波形和计时
    [self startMeterTimer];
    [self startAudioTimer];
}

// 创建识别任务
- (void)startRecognitionTaskWithGeneration:(NSInteger)generation {
    __weak typeof(self) weakSelf = self;
    self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest
                                                              resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !strongSelf.isRecording) return;
            if (generation != strongSelf.taskGeneration) return;

            if (result) {
                NSString *currentText = result.bestTranscription.formattedString;

                // 服务端识别器会自动累积全部文本（含标点）
                // 只需在 confirmedText（上一轮任务的文本）后面拼接当前任务的文本
                if (strongSelf.confirmedText.length > 0) {
                    strongSelf.recognizedText = [strongSelf.confirmedText stringByAppendingString:currentText];
                } else {
                    strongSelf.recognizedText = currentText;
                }

                // isFinal = 任务结束（约60秒上限），保存并重启
                if (result.isFinal && strongSelf.isRecording) {
                    strongSelf.confirmedText = [strongSelf.recognizedText copy];
                    [strongSelf restartRecognitionTask];
                }

            } else if (error && strongSelf.isRecording) {
                // 错误时保存并重启
                if (strongSelf.recognizedText.length > 0) {
                    strongSelf.confirmedText = [strongSelf.recognizedText copy];
                }
                [strongSelf restartRecognitionTask];
            }
        });
    }];
}

// 重启识别任务（isFinal 或 error 后调用）
- (void)restartRecognitionTask {
    if (!self.isRecording) return;

    self.taskGeneration++;

    [self.recognitionTask cancel];
    self.recognitionTask = nil;
    if (self.recognitionRequest) {
        [self.recognitionRequest endAudio];
    }
    self.recognitionRequest = nil;

    SFSpeechAudioBufferRecognitionRequest *newRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    newRequest.shouldReportPartialResults = YES;
    newRequest.taskHint = SFSpeechRecognitionTaskHintDictation;
    if (@available(iOS 16, *)) {
        newRequest.addsPunctuation = YES;
    }
    self.recognitionRequest = newRequest;

    [self startRecognitionTaskWithGeneration:self.taskGeneration];
}

// 仅停止音频采集和UI定时器，保留识别任务让其处理剩余音频
- (void)stopAudioCapture {
    [self stopMeterTimer];
    [self.audioTimer invalidate];
    self.audioTimer = nil;

    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
        [self.audioEngine.inputNode removeTapOnBus:0];
    }

    // 通知识别器音频已结束，让其处理剩余缓冲区
    [self.recognitionRequest endAudio];
}

// 完全停止识别并释放资源
- (void)stopRecognitionAndSession {
    self.isRecording = NO;

    if (self.recognitionTask) {
        [self.recognitionTask cancel];
        self.recognitionTask = nil;
    }
    self.recognitionRequest = nil;

    NSError *error;
    [[AVAudioSession sharedInstance] setActive:NO
                                  withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                        error:&error];
}

// 立即停止一切（用于取消场景，不需要等待识别结果）
- (void)stopRecording {
    [self stopAudioCapture];
    [self stopRecognitionAndSession];
}

- (void)resetUI {
    self.stateView.hidden = NO;
    self.stateView.recordState = CWRecordStateDefault;
    [self updateStateViewDefaultText];

    self.levelContentView.hidden = YES;
    self.voiceLine.hidden = YES;
    self.sendButton.hidden = YES;

    self.recordDuration = 0;
    self.currentLevels = nil;
    self.confirmedText = nil;
    self.recognizedText = nil;
    self.isSendAction = NO;
}

#pragma mark - 波形显示（与 CWRecordStateView 完全一致）

- (NSMutableArray *)currentLevels {
    if (!_currentLevels) {
        _currentLevels = [NSMutableArray arrayWithArray:@[@0.05,@0.05,@0.05,@0.05,@0.05,@0.05,@0.05,@0.05,@0.05,@0.05]];
    }
    return _currentLevels;
}

- (void)startMeterTimer {
    [self stopMeterTimer];
    self.levelTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateMeter)];
    if ([[UIDevice currentDevice].systemVersion floatValue] > 10.0) {
        self.levelTimer.preferredFramesPerSecond = 10;
    } else {
        self.levelTimer.frameInterval = 6;
    }
    [self.levelTimer addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopMeterTimer {
    [self.levelTimer invalidate];
    self.levelTimer = nil;
}

- (void)startAudioTimer {
    [self.audioTimer invalidate];
    self.recordDuration = 0;
    self.audioTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(addSecond) userInfo:nil repeats:YES];
}

- (void)addSecond {
    self.recordDuration++;
    [self updateTimeLabel];

    if (self.recordDuration >= MaxRecordTime) {
        [self finishAndSend];
    }
}

- (void)updateTimeLabel {
    NSInteger duration = self.recordDuration;
    NSString *text;
    if (duration < 60) {
        text = [NSString stringWithFormat:@"0:%02zd", duration];
    } else {
        text = [NSString stringWithFormat:@"%zd:%02zd", duration / 60, duration % 60];
    }
    self.timeLabel.text = text;
}

- (void)updateMeter {
    float level = MAX(self.currentAudioLevel, 0.05);
    [self.currentLevels removeLastObject];
    [self.currentLevels insertObject:@(level) atIndex:0];
    [self updateLevelLayer];
}

- (void)updateLevelLayer {
    self.levelPath = [UIBezierPath bezierPath];
    CGFloat height = CGRectGetHeight(self.levelLayer.frame);

    for (int i = 0; i < self.currentLevels.count; i++) {
        CGFloat x = i * (levelWidth + levelMargin) + 5;
        CGFloat pathH = [self.currentLevels[i] floatValue] * height;
        CGFloat startY = height / 2.0 - pathH / 2.0;
        CGFloat endY = height / 2.0 + pathH / 2.0;
        [_levelPath moveToPoint:CGPointMake(x, startY)];
        [_levelPath addLineToPoint:CGPointMake(x, endY)];
    }

    self.levelLayer.path = _levelPath.CGPath;
}

#pragma mark - SFSpeechRecognizerDelegate

- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {
    if (!available && self.isRecording) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishAndSend];
        });
    }
}

#pragma mark - Helper

- (UIImage *)imageName:(NSString *)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}

@end
