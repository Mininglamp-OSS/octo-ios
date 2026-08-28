//
//  OctoSummaryEditVC.m
//  OctoContext
//

#import "OctoSummaryEditVC.h"
#import "OctoSummaryAPI.h"
#import <AVFoundation/AVFoundation.h>
#import <WuKongBase/WKVoiceInputService.h>
#import <WuKongBase/WKApp.h>

typedef NS_ENUM(NSInteger, OctoVoiceState) {
    OctoVoiceStateIdle,
    OctoVoiceStateRecording,
    OctoVoiceStateCancelling,
    OctoVoiceStateThinking,
    OctoVoiceStateResult,
};

// 首次录音(handleHoldToTalk:)和"按住继续"追加录音(handleAppendLongPress:)原来各自
// 硬编了一个不同的上滑取消阈值(60pt / 100pt)——同一个手势在两个入口的手感不一致,用户在
// 追加录音时要多滑 40pt 才会进入取消区,容易误以为追加录音的取消判定"失灵"了。两处统一
// 用这一个常量。
static const CGFloat kVoiceCancelUpOffset = 60.0;

// voiceOverlay 是挂在 window 上的全屏蒙版,z-order 高于 self.view 里的自绘 WKNavigationBar
// 和系统 interactivePopGestureRecognizer(挂在 nav controller 的 view 上,是全高的左边缘
// UIScreenEdgePanGestureRecognizer)。任何语音态(含没有任何取消入口的 Thinking 态)下,
// 蒙版存在期间返回按钮点击和右滑手势都会被它挡掉,导致编辑页彻底退不出去。
// 这里让蒙版对"导航栏高度带"(返回按钮所在区域)和"左边缘竖条"(interactivePop 手势的
// 识别热区)两处触摸直接返回 nil——hitTest 返回 nil 时该次触摸不会命中蒙版及其祖先链,
// 会继续往下命中 self.view 树,从而正常送达导航栏和挂在其祖先视图上的手势识别器。
@interface OctoVoiceOverlayPassthroughView : UIView
@property(nonatomic, assign) CGFloat topPassthroughHeight;
@property(nonatomic, assign) CGFloat edgePassthroughWidth;
@end

@implementation OctoVoiceOverlayPassthroughView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit != self) return hit; // 命中了气泡/波形/结果条等真实子视图,照常处理
    if (point.y <= self.topPassthroughHeight) return nil;
    if (point.x <= self.edgePassthroughWidth) return nil;
    return hit;
}

@end

@interface OctoSummaryEditVC () <UIGestureRecognizerDelegate, UITextViewDelegate, AVAudioRecorderDelegate>
@property(nonatomic, strong) UITextView *textView;
@property(nonatomic, copy) NSString *initialContent;
@property(nonatomic, strong) UIButton *undoBtn; // 导航栏"撤销",和保存并排,统一撤销 textView.undoManager 的历史(手动打字/语音改写共用一个栈)
@property(nonatomic, strong) NSUndoManager *wk_privateUndoManager; // 本页专属的 undoManager 实例,配合下面对 -undoManager 的重写使用
@property(nonatomic, assign) CGFloat keyboardHeight;     // 当前键盘高度,影响 textView 底缘
@property(nonatomic, assign) BOOL pendingRealKeyboard;   // 点"点击输入…"触发按钮时置 YES,一次性放行真系统键盘

// 语音听写:底部常驻切换栏,键盘/语音模式互斥切换,参照群聊 WKConversationInputPanel 的
// toggleVoiceMode 设计——切到语音模式的第一步就是收起键盘,两者不会同屏出现。
@property(nonatomic, strong) UIView *voiceBar;
@property(nonatomic, strong) UIView *voiceBarHairline;
@property(nonatomic, strong) UIButton *modeToggleBtn;   // 🎤/⌨ 互斥图标
@property(nonatomic, strong) UIButton *holdToTalkBtn;   // "按住 说话" 长按钮,仅语音模式显示
@property(nonatomic, strong) UIButton *textInputTriggerBtn; // "点击输入…" 占位框,仅键盘模式显示,和 holdToTalkBtn 同槽位二选一
@property(nonatomic, assign) BOOL isVoiceMode;
@property(nonatomic, strong) UIView *voiceDummyInputView; // 顶替系统键盘的空视图:语音模式 / 键盘模式下"仅光标不弹键盘"共用

// 语音状态机与录音
@property(nonatomic, assign) OctoVoiceState voiceState;
@property(nonatomic, strong) AVAudioRecorder *audioRecorder;
@property(nonatomic, copy) NSString *recordFilePath;
@property(nonatomic, strong) NSTimer *recordTimer;
@property(nonatomic, strong) NSTimer *waveformTimer;
// textViewDidChange: 每敲一个字符都会触发,而 wk_refreshManualEditHighlight 要跑一遍全文
// diff——直接同步做的话,长文档下每个按键都要重新分配/比较一遍,输入越长越卡。改成"停手
// 后再算":每次 didChange 都把这个计时器重新预约到 0.12s 后,只有连续 0.12s 没有新按键时
// 才真正跑一次 diff,期间无论敲多快都只在末尾算一次。
@property(nonatomic, strong) NSTimer *highlightDebounceTimer;
@property(nonatomic, assign) NSInteger recordSeconds;
@property(nonatomic, assign) float currentPower;
@property(nonatomic, copy) NSString *previousAudioCategory;
@property(nonatomic, assign) AVAudioSessionCategoryOptions previousAudioCategoryOptions;
@property(nonatomic, assign) CGPoint touchStartPoint;
// 权限弹窗打断长按手势时,系统会立刻给一次 Cancelled,但那一刻 voiceState 还是 Idle,
// 落不到任何处理分支;真正的风险在权限回调异步返回时——如果手指已经松开,不能再无条件
// 开始录音(否则会在无人触摸的情况下自己录起来,直到 60 秒上限才结束)。
@property(nonatomic, assign) BOOL isGestureActive;
// 每次 hideVoiceOverlay 兜底重置(取消/关闭/页面消失)都会递增,transcribeAudio 的异步回调
// 在真正落地状态变更前先比对捕获时的这个值——不一致说明这段录音所属的语音会话已经结束,
// 回调是"迟到"的,直接丢弃,不能再把 voiceState/pendingAudioClips 之类的东西改回去。
@property(nonatomic, assign) NSUInteger voiceEditGeneration;
@property(nonatomic, copy) NSString *transcribedText;

// 语音编辑正文只需用户确认一次:气泡展示 ASR 原话("确认原话"阶段),用户确认后重新上传
// 录音交给大模型按当前正文改写(Phase B),处理完直接写回正文并高亮标出改动范围、关闭气泡,
// 不再要求二次确认。"确认原话"阶段允许用户不点确认、继续按住继续多说几句——这几句原始
// 录音先各自攒在 pendingAudioClips 里,直到用户点确认时才依次(链式,前一段的AI改写结果
// 作为后一段的基准正文)重新上传处理,避免因为接口一次只认一段音频而丢内容。
@property(nonatomic, strong) NSMutableArray<NSData *> *pendingAudioClips;
@property(nonatomic, copy) NSString *pendingEditBaseContext; // Phase B 要合并/高亮diff用的基准正文,这一批开始时就锁定
@property(nonatomic, assign) NSRange pendingInsertCursorRange; // 这一批开始录音那一刻的光标位置,判定出"纯口述"时插回这里(而非甩到文末)

// 气泡+波形 overlay UI（参照 WKHoldToTalkManager）
@property(nonatomic, strong) UIView *voiceOverlay;
@property(nonatomic, strong) UIView *bubbleView;
@property(nonatomic, strong) UIView *bubbleTail;
@property(nonatomic, strong) UIView *waveContainer;
@property(nonatomic, strong) NSMutableArray<UIView *> *waveBars;
@property(nonatomic, strong) UIView *bottomAreaView;
@property(nonatomic, strong) UILabel *hintLabel;
@property(nonatomic, assign) CGPoint bubbleOriginCenter;

// 思考动画（三点）
@property(nonatomic, strong) UIView *thinkingOverlayView;
@property(nonatomic, strong) NSMutableArray<UIView *> *thinkingDots;
@property(nonatomic, strong) NSTimer *thinkingTimer;
@property(nonatomic, assign) NSInteger thinkingDotIndex;

// 结果页 UI
@property(nonatomic, strong) UITextView *resultTextView;
@property(nonatomic, strong) UIView *resultBottomBar;
@property(nonatomic, strong) UIButton *resultCancelBtn;
@property(nonatomic, strong) UIButton *resultInsertBtn;
@property(nonatomic, strong) UIButton *resultAppendBtn;
@property(nonatomic, strong) UILabel *resultCancelLabel;
@property(nonatomic, strong) UILabel *resultAppendLabel;

// "按住继续"追加录音直接复用第一次录音的气泡/波形/底部弧形UI(bubbleView/waveContainer/
// bottomAreaView/bubbleTail/hintLabel),不再单独维护一套视觉,保证两次样式完全一致。
// 下面两个字段只是过渡前后用来暂存/恢复气泡的frame。
@property(nonatomic, assign) CGRect recordingBubbleFrame;  // 第一次录音时气泡的原始frame,追加录音时把气泡换回这个录音态尺寸
@property(nonatomic, assign) CGRect preAppendBubbleFrame;  // 追加录音开始前"结果气泡"当时的frame,录音结束后换回来
@property(nonatomic, assign) BOOL isAppendMode;
@end

@implementation OctoSummaryEditVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationBar.title = LLang(@"编辑总结");

    // 不再放自定义 ✕。WKBaseVC.viewDidLoad 检测到 viewControllers.count >= 2 会自动
    // setShowBackButton:YES, 走系统返回箭头 + WKNavigationManager pop, 与发起总结
    // 页面体验一致。
    // 但要拦截"未保存修改时按返回二次确认"的场景: WKNavigationBar.onBack 是这个钩子。
    __weak typeof(self) weakSelf = self;
    self.navigationBar.onBack = ^{
        [weakSelf onClose];
    };

    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [saveBtn setTitle:LLang(@"保存") forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    // 字色与底色反向配对, 浅 / 深两态都正确出对比 (见 CreateVC 同模式注释)
    [saveBtn setTitleColor:[UIColor systemBackgroundColor] forState:UIControlStateNormal];
    saveBtn.backgroundColor = [UIColor labelColor];
    saveBtn.contentEdgeInsets = UIEdgeInsetsMake(5, 16, 5, 16);
    [saveBtn addTarget:self action:@selector(onSave) forControlEvents:UIControlEventTouchUpInside];
    // sizeToFit 算出按英文/中文的实际所需宽度, 切语言后 "Save"(更长) / "保存" 都不被
    // 硬编 60pt 截成 …。高度仍锚到 32pt 让圆角对得齐。
    [saveBtn sizeToFit];
    CGRect bf = saveBtn.frame; bf.size.height = 32;
    saveBtn.frame = bf;
    saveBtn.layer.cornerRadius = 16;

    // 撤销:和保存并排放进同一个 rightView 容器(WKNavigationBar.rightView 只认单个
    // view,多按钮需要自己拼一个容器,参照 WKConversationListVC.rightAddItem 的写法)。
    // 撤的是 self.textView.undoManager 这一份栈——手动打字(系统自动登记)和语音编辑
    // (下面 wk_replaceTextViewAttributedText: 手动登记)共用同一份历史,顺序天然穿插,
    // 不会出现"语音改完又手打几个字,一撤销把手打的也吞掉"的误伤。
    self.undoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.undoBtn.tintColor = [UIColor labelColor];
    [self.undoBtn setImage:[UIImage systemImageNamed:@"arrow.uturn.backward"] forState:UIControlStateNormal];
    self.undoBtn.frame = CGRectMake(0, 0, 32, 32);
    [self.undoBtn addTarget:self action:@selector(onUndoTapped) forControlEvents:UIControlEventTouchUpInside];

    CGFloat gap = 8;
    UIView *rightContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.undoBtn.frame.size.width + gap + saveBtn.frame.size.width, 32)];
    self.undoBtn.center = CGPointMake(self.undoBtn.frame.size.width / 2, rightContainer.frame.size.height / 2);
    [rightContainer addSubview:self.undoBtn];
    CGRect sf = saveBtn.frame;
    sf.origin.x = CGRectGetMaxX(self.undoBtn.frame) + gap;
    sf.origin.y = (rightContainer.frame.size.height - sf.size.height) / 2;
    saveBtn.frame = sf;
    [rightContainer addSubview:saveBtn];
    self.navigationBar.rightView = rightContainer;

    self.textView = [UITextView new];
    self.textView.font = [UIFont systemFontOfSize:14];
    self.textView.text = self.detail.result.content ?: @"";
    self.initialContent = self.textView.text;
    self.textView.textColor = [UIColor labelColor];
    self.textView.delegate = self;
    [self.view addSubview:self.textView];
    // wk_updateUndoButtonState 读的是 self.textView.undoManager,必须放在 textView 创建
    // 之后调用——挪之前这里读到的是 nil.undoManager,靠"给 nil 发消息返回 NO"侥幸算对,
    // 不依赖这种写法。
    [self wk_updateUndoButtonState];

    self.voiceBar = [UIView new];
    self.voiceBar.backgroundColor = [UIColor systemBackgroundColor];
    [self.view addSubview:self.voiceBar];

    self.voiceBarHairline = [UIView new];
    self.voiceBarHairline.backgroundColor = [UIColor separatorColor];
    [self.voiceBar addSubview:self.voiceBarHairline];

    self.modeToggleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.modeToggleBtn.tintColor = [UIColor labelColor];
    [self.modeToggleBtn setImage:[WKApp.shared loadImage:@"Conversation/Toolbar/VoiceToggle" moduleID:@"WuKongBase"] forState:UIControlStateNormal];
    [self.modeToggleBtn addTarget:self action:@selector(onModeToggleTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.voiceBar addSubview:self.modeToggleBtn];

    self.holdToTalkBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.holdToTalkBtn setTitle:LLang(@"按住 说话") forState:UIControlStateNormal];
    [self.holdToTalkBtn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    self.holdToTalkBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.holdToTalkBtn.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.holdToTalkBtn.layer.cornerRadius = 16;
    self.holdToTalkBtn.clipsToBounds = YES;
    self.holdToTalkBtn.hidden = YES; // 默认键盘模式,不显示
    UILongPressGestureRecognizer *holdGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleHoldToTalk:)];
    holdGesture.minimumPressDuration = 0.15;
    [self.holdToTalkBtn addGestureRecognizer:holdGesture];
    [self.voiceBar addSubview:self.holdToTalkBtn];

    // 键盘模式下,和 holdToTalkBtn 占同一个槽位(二选一显示):点一下唤起系统键盘,
    // 和"按住 说话"按钮左右对称,不会出现切回键盘模式后麦克风图标旁边空着一截的观感。
    self.textInputTriggerBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.textInputTriggerBtn setTitle:LLang(@"点击输入…") forState:UIControlStateNormal];
    [self.textInputTriggerBtn setTitleColor:[UIColor placeholderTextColor] forState:UIControlStateNormal];
    self.textInputTriggerBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    self.textInputTriggerBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.textInputTriggerBtn.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    self.textInputTriggerBtn.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.textInputTriggerBtn.layer.cornerRadius = 16;
    self.textInputTriggerBtn.clipsToBounds = YES;
    [self.textInputTriggerBtn addTarget:self action:@selector(onTextInputTriggerTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.voiceBar addSubview:self.textInputTriggerBtn];

    // 键盘弹出时把 textView 高度向上缩 keyboardHeight, 避免最后几行被键盘挡住。
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    // 来电/闹钟等系统中断会由 AVAudioSession 直接把 AVAudioRecorder 停掉,不会触发任何手势
    // 回调——不监听这个通知的话,voiceState 会一直卡在 Recording/Cancelling,录音其实早已
    // 停止,松手手势也再不会触发(手指其实还在屏幕上按着,但 recorder 已经不工作了)。参照
    // WKHoldToTalkManager 的 onAudioInterrupt: 处理方式。
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAudioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:nil];

    // 点击键盘以外的区域收起键盘。挂在 self.view (textView 的祖先视图) 上而不是
    // textView 自己身上——挂在 textView 上会跟它内部"点哪儿光标摆哪儿"的系统手势抢
    // 触摸,导致点正文光标出不来。cancelsTouchesInView=NO + delegate 里过滤掉
    // textView 内部及按钮控件的触摸,保证不影响正常编辑和按钮点击。
    UITapGestureRecognizer *dismissKeyboardTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBackgroundTapped)];
    dismissKeyboardTap.cancelsTouchesInView = NO;
    dismissKeyboardTap.delegate = self;
    [self.view addGestureRecognizer:dismissKeyboardTap];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.recordTimer invalidate];
    [self.waveformTimer invalidate];
    [self.highlightDebounceTimer invalidate];
    if (self.audioRecorder.isRecording) [self.audioRecorder stop];
    [self restoreAudioSession];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self cancelRecordingIfNeeded];
    // cancelRecordingIfNeeded 只在 Recording/Cancelling 态才会清理 timer 和 overlay——
    // 处于 Thinking(AI 处理中)或 Result(结果待确认)态时它直接 return,voiceOverlay 是
    // 挂在 window 而不是 self.view 上的,VC 消失后没人移除,会留下一层全屏蒙版挡住整个
    // App。这里无条件兜底清一次,hideVoiceOverlay/invalidateRecordTimers 本身是幂等的。
    [self invalidateRecordTimers];
    [self hideVoiceOverlay];
}

// wk_privateUndoManager 是本页自己持有的 NSUndoManager,而 wk_replaceTextViewAttributedText:
// 每次注册撤销/重做操作都用 prepareWithInvocationTarget:self——也就是说 undo/redo 栈里的
// NSInvocation 会强引用 self(this VC),形成"VC 强引用 undoManager,undoManager 的栈又强
// 引用 VC"的循环引用。只要用户操作过几次撤销/重做,这个环就一直在,页面 pop 之后 VC 也
// 不会被释放。viewWillDisappear 不能用来打破这个环——它在 push 到新页面、来一个模态弹层等
// "临时不可见"场景下也会触发,那时用户可能还会 pop 回来继续撤销;只有 didMoveToParent
// ViewController: 拿到的 parent==nil 才说明这个页面真的从导航栈里被移除了,这时清空撤销
// 栈把环断开是安全的。
- (void)didMoveToParentViewController:(UIViewController *)parent {
    [super didMoveToParentViewController:parent];
    if (!parent) {
        [self.wk_privateUndoManager removeAllActions];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = CGRectGetMaxY(self.navigationBar.frame);
    CGFloat voiceBarHeight = 48;
    CGFloat bottomInset = self.keyboardHeight + voiceBarHeight;

    self.textView.frame = CGRectMake(8, top + 8,
                                     self.view.bounds.size.width - 16,
                                     self.view.bounds.size.height - top - 8 - bottomInset);

    self.voiceBar.frame = CGRectMake(0, self.view.bounds.size.height - bottomInset,
                                      self.view.bounds.size.width, voiceBarHeight);
    self.voiceBarHairline.frame = CGRectMake(0, 0, self.voiceBar.bounds.size.width, 0.5);

    CGFloat toggleSize = 32;
    self.modeToggleBtn.frame = CGRectMake(12, (voiceBarHeight - toggleSize) / 2, toggleSize, toggleSize);
    CGFloat slotX = CGRectGetMaxX(self.modeToggleBtn.frame) + 12;

    CGRect slotFrame = CGRectMake(slotX, (voiceBarHeight - 36) / 2,
                                   self.voiceBar.bounds.size.width - slotX - 12, 36);
    self.holdToTalkBtn.frame = slotFrame;
    self.textInputTriggerBtn.frame = slotFrame;
}

#pragma mark - Keyboard

- (void)onKeyboardWillShow:(NSNotification *)note {
    CGRect endFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    // 转到 view 坐标系再求与 view 的交集 —— 同时兼容浮动键盘 / iPad 分屏的边界。
    CGRect kbInView = [self.view convertRect:endFrame fromView:nil];
    CGRect intersect = CGRectIntersection(self.view.bounds, kbInView);
    CGFloat kbH = CGRectIsNull(intersect) ? 0 : intersect.size.height;
    if (fabs(kbH - self.keyboardHeight) < 0.5) return;
    self.keyboardHeight = kbH;
    NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = (UIViewAnimationCurve)[note.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0 options:(UIViewAnimationOptions)(curve << 16) animations:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
        [self layoutVoiceResultBarForKeyboard];
    } completion:nil];
}

- (void)onKeyboardWillHide:(NSNotification *)note {
    if (self.keyboardHeight == 0) return;
    self.keyboardHeight = 0;
    NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = (UIViewAnimationCurve)[note.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0 options:(UIViewAnimationOptions)(curve << 16) animations:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
        [self layoutVoiceResultBarForKeyboard];
    } completion:nil];
}

// 结果气泡的确认/取消/按住继续按钮栏在编辑原话/AI结果时被系统键盘挡住的问题:
// resultBottomBar 挂在 window 上、不受 self.view 的 auto layout 驱动,键盘弹起时
// 需要单独把它挪到键盘上方,收起时挪回原位。参照群聊 WKHoldToTalkManager 的
// layoutResultUIForKeyboard 实现。
- (void)layoutVoiceResultBarForKeyboard {
    if (!self.resultBottomBar || !self.voiceOverlay) return;
    if (self.voiceState != OctoVoiceStateResult) return;
    CGFloat sw = self.voiceOverlay.bounds.size.width;
    CGFloat sh = self.voiceOverlay.bounds.size.height;
    CGFloat barH = self.resultBottomBar.bounds.size.height;
    if (self.keyboardHeight > 0) {
        CGFloat barY = sh - self.keyboardHeight - barH;
        self.resultBottomBar.frame = CGRectMake(0, barY, sw, barH);
    } else {
        CGFloat barY = sh - barH - 40;
        self.resultBottomBar.frame = CGRectMake(0, barY, sw, barH);
    }
}

#pragma mark - Actions

- (void)onClose {
    if (![self.textView.text isEqualToString:self.initialContent]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"放弃修改?")
                                                                       message:LLang(@"未保存的修改将丢失")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:LLang(@"继续编辑") style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:LLang(@"放弃") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_) {
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [[WKNavigationManager shared] popViewControllerAnimated:YES];
}

// UITextView 自己不重写 -undoManager,按 UIResponder 默认实现会沿响应链一路上交给
// UIWindow,拿到的是整个 App 唯一共享的一份 undoManager——手动打字和语音改写注册进去的
// 撤销记录会残留在这个全局栈里,页面弹出后依然存在,可能在别处被误触发。这里重写
// -undoManager,让响应链在走到本 VC 时就截停,返回一个本页面私有的实例(和 VC 同生命周期,
// 随 VC 一起释放),self.textView.undoManager 因此拿到的就是这一份。
- (NSUndoManager *)undoManager {
    if (!_wk_privateUndoManager) {
        _wk_privateUndoManager = [[NSUndoManager alloc] init];
    }
    return _wk_privateUndoManager;
}

- (void)onUndoTapped {
    [self.textView.undoManager undo];
    [self wk_updateUndoButtonState];
}

- (void)wk_updateUndoButtonState {
    BOOL canUndo = self.textView.undoManager.canUndo;
    self.undoBtn.enabled = canUndo;
    self.undoBtn.alpha = canUndo ? 1.0 : 0.35;
}

- (void)onSave {
    // 语音编辑留下的高亮标记只保留到用户点保存这一刻,不管保存最终成功与否都清掉;但保存
    // 失败时要把这份高亮加回去(见下面 error 分支)——否则用户会看到"保存失败了,但刚才
    // 语音改过的痕迹却凭空消失"这种不一致的观感。
    NSAttributedString *attrBeforeClear = [self.textView.attributedText copy];
    [self clearVoiceEditHighlight];
    int64_t baseResultId = self.detail.resultId.longLongValue;
    __weak typeof(self) weakSelf = self;
    [[OctoSummaryAPI shared] editSummary:self.detail.taskId
                                  content:self.textView.text ?: @""
                             baseResultId:baseResultId
                                 callback:^(id _Nullable result, NSError * _Nullable error) {
        if (error) {
            NSInteger st = [error.userInfo[@"_httpStatus"] integerValue];
            if (st == 409) {
                [weakSelf.view showMsg:LLang(@"内容已被他人更新,请返回刷新")];
            } else {
                [weakSelf.view showMsg:error.localizedDescription ?: LLang(@"保存失败")];
            }
            weakSelf.textView.attributedText = attrBeforeClear;
            return;
        }
        if (weakSelf.onSaved) weakSelf.onSaved();
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    }];
}

#pragma mark - Voice Mode Toggle

- (void)onModeToggleTapped {
    if (self.voiceState != OctoVoiceStateIdle) return;
    [self.textView resignFirstResponder];
    self.isVoiceMode = !self.isVoiceMode;
    [self updateVoiceBarAppearance];
}

- (void)onBackgroundTapped {
    [self.textView endEditing:YES];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // 按钮自己的 touchUpInside 不受影响; textView/resultTextView 内部(含光标/选区)的触摸
    // 也放行给它们自己处理——同一个 delegate 同时给 self.view 上的收键盘手势和 voiceOverlay
    // 上的收键盘手势用,resultTextView 只有语音气泡场景下才存在,判断前不用额外判空。
    if ([touch.view isKindOfClass:[UIControl class]]) return NO;
    if ([touch.view isDescendantOfView:self.textView]) return NO;
    if (self.resultTextView && [touch.view isDescendantOfView:self.resultTextView]) return NO;
    return YES;
}

#pragma mark - UITextViewDelegate

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView {
    // 语音模式下点正文只应该显示光标、不弹系统键盘(要真录音走"按住说话"),复用一个空
    // inputView 顶替系统键盘;键盘模式下点正文直接弹真键盘,不用再先点"点击输入…"。
    if (self.isVoiceMode && !self.pendingRealKeyboard) {
        if (!self.voiceDummyInputView) {
            self.voiceDummyInputView = [[UIView alloc] initWithFrame:CGRectZero];
        }
        textView.inputView = self.voiceDummyInputView;
    } else {
        textView.inputView = nil;
    }
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
    // 手动打字会被 UITextView 自动登记进 self.textView.undoManager,这里只是跟着
    // 同步一下按钮的可用态,不需要自己再登记一遍。撤销按钮的可用态要跟手感一致,不能延迟,
    // 所以这行仍然同步执行;真正开销大的 diff 高亮走下面的防抖。
    [self wk_updateUndoButtonState];
    [self.highlightDebounceTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.highlightDebounceTimer = [NSTimer scheduledTimerWithTimeInterval:0.12
                                                                    repeats:NO
                                                                      block:^(NSTimer *timer) {
        [weakSelf wk_refreshManualEditHighlight];
    }];
}

// 手动打字和语音改写一样都算"修改过的内容",也要有紫色高亮。这里只重算/重贴
// NSBackgroundColorAttributeName,不碰 textStorage 的字符内容,不会像整段替换
// attributedText 那样把光标/选区弹回开头,也不会打断拼音等输入法的组词状态——
// 所以中文输入法正在组词(markedTextRange 非空)时先不重算,等这个字提交生效、
// 下一次 didChange 触发时自然会补上,不会漏高亮。
- (void)wk_refreshManualEditHighlight {
    if (self.textView.markedTextRange) return;
    NSTextStorage *textStorage = self.textView.textStorage;
    NSArray<NSValue *> *changedRanges = [self wk_changedRangesInNewText:self.textView.text ?: @""
                                                       comparedToOldText:self.initialContent ?: @""];
    [textStorage beginEditing];
    [textStorage removeAttribute:NSBackgroundColorAttributeName range:NSMakeRange(0, textStorage.length)];
    UIColor *highlightColor = [self wk_voiceEditHighlightColor];
    for (NSValue *rangeValue in changedRanges) {
        [textStorage addAttribute:NSBackgroundColorAttributeName value:highlightColor range:rangeValue.rangeValue];
    }
    [textStorage endEditing];
}

- (void)updateVoiceBarAppearance {
    if (self.isVoiceMode) {
        [self.modeToggleBtn setImage:[WKApp.shared loadImage:@"Conversation/Toolbar/KeyboardToggle" moduleID:@"WuKongBase"] forState:UIControlStateNormal];
        self.holdToTalkBtn.hidden = NO;
        self.textInputTriggerBtn.hidden = YES;
        // 注意: 不能用 editable=NO 来"点正文但不弹键盘"——非可编辑状态下 UITextView 根本
        // 不会画出插入点光标(只有可编辑/可成为第一响应者时才有光标),点了跟没点一样看不到
        // 光标落在哪。改用 inputView 顶替系统键盘: textView 仍然是正常可编辑的第一响应者,
        // 点正文会正常显示/移动光标、selectedRange 正常联动,只是弹出来的"键盘"换成一个空
        // 视图,视觉上等于没有键盘弹出。
        if (!self.voiceDummyInputView) {
            self.voiceDummyInputView = [[UIView alloc] initWithFrame:CGRectZero];
        }
        self.textView.inputView = self.voiceDummyInputView;
    } else {
        [self.modeToggleBtn setImage:[WKApp.shared loadImage:@"Conversation/Toolbar/VoiceToggle" moduleID:@"WuKongBase"] forState:UIControlStateNormal];
        self.holdToTalkBtn.hidden = YES;
        self.textInputTriggerBtn.hidden = NO;
        // 键盘模式下 inputView 不在这里定死: textViewShouldBeginEditing: 里已经改成
        // 点正文直接弹真键盘,这里不用再摆哑视图;"点击输入…" 占位框作为兜底入口保留。
    }
}

- (void)onTextInputTriggerTapped {
    // 显式请求系统键盘: 先摘掉哑 inputView, 再按当前是否已经是第一响应者
    // (比如已经处于 textViewShouldBeginEditing: 给的"仅光标"状态) 分别走
    // reloadInputViews / becomeFirstResponder, 两条路径都能弹出真键盘。
    self.pendingRealKeyboard = YES;
    self.textView.inputView = nil;
    if (self.textView.isFirstResponder) {
        [self.textView reloadInputViews];
    } else {
        [self.textView becomeFirstResponder];
    }
    self.pendingRealKeyboard = NO;
}

#pragma mark - Hold To Talk Gesture

- (void)handleHoldToTalk:(UILongPressGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self.view];
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            if (self.voiceState == OctoVoiceStateIdle) {
                self.isGestureActive = YES;
                self.touchStartPoint = point;
                [self requestRecordPermissionThenStart];
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            // 注意:必须放行 Cancelling 状态,不能只放行 Recording——否则手指一旦上滑超过
            // 阈值进了"取消"区,这里就会在下一次 Changed 事件里直接 return,再也追踪不到
            // 手指位置,导致哪怕挪回来也无法撤销取消,松手时只会触发 cancelRecordingIfNeeded
            // 而不是 stopRecordingAndTranscribe——表现为"松手没有进入转文字状态"。
            if (self.voiceState != OctoVoiceStateRecording && self.voiceState != OctoVoiceStateCancelling) return;
            CGFloat delta = self.touchStartPoint.y - point.y;
            BOOL shouldCancel = delta > kVoiceCancelUpOffset;
            BOOL wasInCancel = (self.voiceState == OctoVoiceStateCancelling);
            if (shouldCancel && !wasInCancel) {
                self.voiceState = OctoVoiceStateCancelling;
                [UIView animateWithDuration:0.2 animations:^{ [self updateVoiceOverlayForState]; }];
            } else if (!shouldCancel && wasInCancel) {
                self.voiceState = OctoVoiceStateRecording;
                [UIView animateWithDuration:0.2 animations:^{ [self updateVoiceOverlayForState]; }];
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            self.isGestureActive = NO;
            if (self.voiceState == OctoVoiceStateCancelling) {
                [self cancelRecordingIfNeeded];
            } else if (self.voiceState == OctoVoiceStateRecording) {
                [self stopRecordingAndTranscribe];
            }
            break;
        }
        default:
            break;
    }
}

- (void)requestRecordPermissionThenStart {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    __weak typeof(self) weakSelf = self;
    [session requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!granted) {
                [weakSelf showMicPermissionAlert];
                return;
            }
            // 权限弹窗期间手指已经松开(手势已 Ended/Cancelled),不能再开始录音——
            // 否则会在无人触摸的情况下自己录起来,直到 60 秒上限才结束。
            if (!weakSelf.isGestureActive) return;
            [weakSelf beginRecording];
        });
    }];
}

- (void)showMicPermissionAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"无法访问麦克风")
                                                                     message:LLang(@"请在系统设置中允许访问麦克风")
                                                              preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"去设置") style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)beginRecording {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    self.previousAudioCategory = session.category;
    self.previousAudioCategoryOptions = session.categoryOptions;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
              withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                    error:nil];
    [session setActive:YES error:nil];

    self.recordFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"octo_summary_voice_%lld.m4a", (long long)([[NSDate date] timeIntervalSince1970] * 1000)]];

    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @(16000.0),
        AVNumberOfChannelsKey: @(1),
        AVEncoderAudioQualityKey: @(AVAudioQualityHigh),
    };
    NSError *error;
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:self.recordFilePath]
                                                      settings:settings
                                                         error:&error];
    self.audioRecorder.delegate = self;
    if (error || ![self.audioRecorder prepareToRecord] || ![self.audioRecorder record]) {
        [self.view showMsg:LLang(@"录音启动失败")];
        // 前面已经把 session 切到 PlayAndRecord 并 setActive:YES 了(见上面 previousAudioCategory
        // 的记录),这里如果只是简单 setActive:NO,session 的 category 会一直卡在 PlayAndRecord,
        // 不会换回进页面前的原始 category(比如 Playback)——用 restoreAudioSession 走统一的
        // "换回原 category + setActive:NO"路径,和正常录音结束/取消时完全一致。
        [self restoreAudioSession];
        // initWithURL: / prepareToRecord 阶段 AVAudioRecorder 可能已经在 recordFilePath
        // 建了一个空文件,失败路径不清理会留下孤儿临时文件,和下面正常结束/取消路径的
        // 清理动作保持一致。
        [self cleanupRecordFile];
        self.voiceState = OctoVoiceStateIdle;
        return;
    }

    self.voiceState = OctoVoiceStateRecording;
    self.audioRecorder.meteringEnabled = YES;
    self.recordSeconds = 0;
    self.currentPower = 0;

    __weak typeof(self) weakSelf = self;
    self.recordTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
        [weakSelf onRecordTick];
    }];
    self.waveformTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *t) {
        [weakSelf updateWaveform];
    }];

    // "按住继续"复用结果气泡已展示的 voiceOverlay(showVoiceOverlay 对已存在的 overlay 是 no-op),
    // 必须显式切到录音态 UI,否则用户在追加录音时完全看不到波形/提示,不知道正在录音。
    if (self.isAppendMode) {
        [self transitionToRecordingUI];
    } else {
        [self showVoiceOverlay];
    }
}

- (void)onRecordTick {
    self.recordSeconds++;
    if (self.recordSeconds >= 60) {
        // 触顶那一刻如果手指还在"取消"区(红区),必须走取消路径——否则会违背用户此刻明确
        // 表达出来的"不要提交"意图,把这段录音悄悄发出去。追加录音(isAppendMode)另外还有
        // 一条独立限制:不能走 stopRecordingAndTranscribe——它固定以 isFirstUtterance:YES
        // 提交,会用这一段覆盖掉 pendingAudioClips,把之前追加的片段全部丢掉,还会调
        // hideVoiceOverlay 而不是 hideAppendOverlay 导致 UI 错乱。
        BOOL isCancelling = (self.voiceState == OctoVoiceStateCancelling);
        if (self.isAppendMode) {
            if (isCancelling) {
                [self cancelAppendRecording];
            } else {
                [self stopAppendRecordingAndTranscribe];
            }
        } else {
            if (isCancelling) {
                [self cancelRecordingIfNeeded];
            } else {
                [self stopRecordingAndTranscribe];
            }
        }
    }
}

- (void)onAudioSessionInterruption:(NSNotification *)notification {
    AVAudioSessionInterruptionType type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type != AVAudioSessionInterruptionTypeBegan) return;
    if (self.voiceState != OctoVoiceStateRecording && self.voiceState != OctoVoiceStateCancelling) return;
    // 系统已经把 AVAudioRecorder 停掉,这里只做状态清理,不尝试提交这段录音——打断多半发生
    // 在录音中途,数据大概率不完整,交给用户中断结束后重新按住说一遍更可靠。Thinking 态
    // (已经在等网络返回,不在录音)不受这个通知影响,参照 WKHoldToTalkManager 的处理方式。
    self.isGestureActive = NO;
    if (self.isAppendMode) {
        [self cancelAppendRecording];
    } else {
        [self cancelRecordingIfNeeded];
    }
}

// AVAudioRecorderDelegate:上面的中断通知只覆盖"系统抢占音频会话"这一种场景,录音器自身的
// 编码失败(磁盘写满、格式协商失败等)不会触发中断通知,必须靠这两个 delegate 回调兜底,
// 否则 voiceState 会一直卡在 Recording,波形/计时空转,用户只能手动取消。清理路径复用
// cancelAppendRecording/cancelRecordingIfNeeded,和上面中断处理保持一致;和"用户主动取消"
// 的区别是这里要额外提示一下,让用户知道是录音本身出错、不是自己划走取消的。
- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
    [self wk_abortRecordingDueToRecorderFailure];
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    if (flag) return;
    [self wk_abortRecordingDueToRecorderFailure];
}

- (void)wk_abortRecordingDueToRecorderFailure {
    if (self.voiceState != OctoVoiceStateRecording && self.voiceState != OctoVoiceStateCancelling) return;
    self.isGestureActive = NO;
    if (self.isAppendMode) {
        [self cancelAppendRecording];
    } else {
        [self cancelRecordingIfNeeded];
    }
    [self.view showMsg:LLang(@"录音异常中断,请重试")];
}

- (void)stopRecordingAndTranscribe {
    [self invalidateRecordTimers];
    if (self.voiceState != OctoVoiceStateRecording && self.voiceState != OctoVoiceStateCancelling) return;

    NSTimeInterval duration = self.audioRecorder.currentTime;
    [self.audioRecorder stop];
    [self restoreAudioSession];

    if (duration < 1.0) {
        [self cleanupRecordFile];
        [self hideVoiceOverlay];
        [self.view showMsg:LLang(@"说话时间太短")];
        return;
    }

    NSData *audioData = [NSData dataWithContentsOfFile:self.recordFilePath];
    [self cleanupRecordFile];
    if (audioData.length == 0) {
        [self hideVoiceOverlay];
        [self.view showMsg:LLang(@"语音识别失败,请重试")];
        return;
    }

    [self beginASRPreviewForAudio:audioData isFirstUtterance:YES];
}

- (void)cancelRecordingIfNeeded {
    if (self.voiceState != OctoVoiceStateRecording && self.voiceState != OctoVoiceStateCancelling) return;
    [self invalidateRecordTimers];
    if (self.audioRecorder.isRecording) [self.audioRecorder stop];
    [self restoreAudioSession];
    [self cleanupRecordFile];
    self.voiceState = OctoVoiceStateIdle;
    [self hideVoiceOverlay];
}

- (void)invalidateRecordTimers {
    [self.recordTimer invalidate];
    self.recordTimer = nil;
    [self.waveformTimer invalidate];
    self.waveformTimer = nil;
}

- (void)restoreAudioSession {
    if (self.previousAudioCategory) {
        [[AVAudioSession sharedInstance] setCategory:self.previousAudioCategory withOptions:self.previousAudioCategoryOptions error:nil];
        self.previousAudioCategory = nil;
    }
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (void)cleanupRecordFile {
    if (self.recordFilePath) {
        [[NSFileManager defaultManager] removeItemAtPath:self.recordFilePath error:nil];
        self.recordFilePath = nil;
    }
}

#pragma mark - Voice Overlay UI (参照 WKHoldToTalkManager 气泡+波形)

- (void)showVoiceOverlay {
    if (self.voiceOverlay) return;
    UIWindow *window = self.view.window;
    if (!window) return;

    CGFloat sw = window.bounds.size.width;
    CGFloat sh = window.bounds.size.height;

    OctoVoiceOverlayPassthroughView *overlay = [[OctoVoiceOverlayPassthroughView alloc] initWithFrame:window.bounds];
    overlay.topPassthroughHeight = CGRectGetMaxY(self.navigationBar.frame);
    overlay.edgePassthroughWidth = 24; // 对齐系统 interactivePopGestureRecognizer 的左边缘识别热区
    self.voiceOverlay = overlay;
    self.voiceOverlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
    self.voiceOverlay.userInteractionEnabled = YES;
    self.voiceOverlay.alpha = 0;

    CGFloat bubbleW = sw * 0.62;
    CGFloat bubbleH = 85;
    CGFloat bubbleCenterY = sh * 0.42;
    self.bubbleView = [[UIView alloc] initWithFrame:CGRectMake((sw - bubbleW) / 2, bubbleCenterY - bubbleH / 2, bubbleW, bubbleH)];
    self.bubbleView.backgroundColor = [UIColor colorWithRed:0.88 green:0.94 blue:1.0 alpha:1.0];
    self.bubbleView.layer.cornerRadius = 16;
    self.bubbleView.clipsToBounds = YES;
    [self.voiceOverlay addSubview:self.bubbleView];
    self.bubbleOriginCenter = self.bubbleView.center;
    self.recordingBubbleFrame = self.bubbleView.frame;

    self.bubbleTail = [self createBubbleTailWithColor:[UIColor colorWithRed:0.88 green:0.94 blue:1.0 alpha:1.0]];
    self.bubbleTail.center = CGPointMake(self.bubbleView.center.x, CGRectGetMaxY(self.bubbleView.frame) + 4);
    [self.voiceOverlay addSubview:self.bubbleTail];

    CGFloat waveW = bubbleW * 0.85;
    CGFloat waveH = 50;
    self.waveContainer = [[UIView alloc] initWithFrame:CGRectMake((bubbleW - waveW) / 2, (bubbleH - waveH) / 2, waveW, waveH)];
    [self.bubbleView addSubview:self.waveContainer];

    self.waveBars = [NSMutableArray array];
    CGFloat barW = 3, barGap = 2.5;
    NSInteger barCount = 30;
    CGFloat totalBarW = barCount * barW + (barCount - 1) * barGap;
    CGFloat startX = (waveW - totalBarW) / 2;
    for (NSInteger i = 0; i < barCount; i++) {
        UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(startX + i * (barW + barGap), waveH / 2 - 3, barW, 6)];
        bar.backgroundColor = [UIColor colorWithRed:0.35 green:0.55 blue:0.85 alpha:0.7];
        bar.layer.cornerRadius = 1.5;
        [self.waveContainer addSubview:bar];
        [self.waveBars addObject:bar];
    }

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
    arcBg.fillColor = ([WKApp shared].config.themeColor ?: [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0]).CGColor;
    [self.bottomAreaView.layer addSublayer:arcBg];
    [self.voiceOverlay addSubview:self.bottomAreaView];

    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.text = LLang(@"松手 转文字");
    self.hintLabel.textColor = [UIColor whiteColor];
    self.hintLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    self.hintLabel.frame = CGRectMake(0, 45, sw, 20);
    [self.bottomAreaView addSubview:self.hintLabel];

    // 点击蒙版收起结果气泡的键盘——resultTextView 挂在 window 上的 voiceOverlay 里,
    // 不在 self.view 的视图树内,复用不到 onBackgroundTapped 那个挂在 self.view 上的手势。
    UITapGestureRecognizer *dismissResultKeyboardTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onVoiceOverlayTapped)];
    dismissResultKeyboardTap.cancelsTouchesInView = NO;
    dismissResultKeyboardTap.delegate = self;
    [self.voiceOverlay addGestureRecognizer:dismissResultKeyboardTap];

    [window addSubview:self.voiceOverlay];
    [UIView animateWithDuration:0.2 animations:^{ self.voiceOverlay.alpha = 1.0; }];
}

- (void)onVoiceOverlayTapped {
    [self.resultTextView resignFirstResponder];
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

- (void)updateVoiceOverlayForState {
    UIColor *normalColor = [UIColor colorWithRed:0.88 green:0.94 blue:1.0 alpha:1.0];
    UIColor *cancelColor = [UIColor colorWithRed:0.95 green:0.35 blue:0.3 alpha:1.0];

    if (self.voiceState == OctoVoiceStateRecording) {
        self.bubbleView.backgroundColor = normalColor;
        self.bubbleTail.backgroundColor = normalColor;
        self.hintLabel.text = LLang(@"松手 结束  ·  上滑 取消");
        self.hintLabel.textColor = [UIColor whiteColor];
        self.bubbleView.center = self.bubbleOriginCenter;
        self.bubbleTail.center = CGPointMake(self.bubbleOriginCenter.x, CGRectGetMaxY(self.bubbleView.frame) + 4);
    } else if (self.voiceState == OctoVoiceStateCancelling) {
        self.bubbleView.backgroundColor = cancelColor;
        self.bubbleTail.backgroundColor = cancelColor;
        self.hintLabel.text = LLang(@"松手 取消");
        self.hintLabel.textColor = [UIColor colorWithRed:0.95 green:0.35 blue:0.3 alpha:1.0];
        self.bubbleView.center = self.bubbleOriginCenter;
        self.bubbleTail.center = CGPointMake(self.bubbleOriginCenter.x, CGRectGetMaxY(self.bubbleView.frame) + 4);
    }
}

- (void)updateWaveform {
    if (self.voiceState != OctoVoiceStateRecording && self.voiceState != OctoVoiceStateCancelling) return;
    if (!self.audioRecorder) return;

    [self.audioRecorder updateMeters];
    float power = [self.audioRecorder averagePowerForChannel:0];
    float norm = MAX(0, MIN(1, (power + 40) / 40.0));
    if (norm < 0.08) norm = 0;
    self.currentPower = norm;

    // 追加录音直接复用同一套 waveBars/waveContainer(见 transitionToRecordingUI),
    // 不需要再按 isAppendMode 分流成两套。
    NSArray<UIView *> *bars = self.waveBars;
    UIView *container = self.waveContainer;

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

- (void)hideVoiceOverlay {
    // 状态机重置和"蒙版视图本身还在不在"解耦——不能像以前那样把整个方法用
    // `if (!self.voiceOverlay) return;` 一道闸门挡住:一旦 voiceOverlay 因为某种原因
    // (比如下面这次调用之前,一个过期的转录回调在它已经被清过之后又把 voiceState 改了回去)
    // 已经是 nil 但 voiceState 还卡在非 Idle,外层想"兜底重置"时调这个方法会直接
    // no-op,状态永远卡死、再也进不了下一次录音。这里无条件把状态和 generation 复位,
    // 视图清理这部分才按 voiceOverlay 是否存在来决定要不要做。
    self.voiceEditGeneration++;
    self.isAppendMode = NO;
    self.recordingBubbleFrame = CGRectZero;
    self.preAppendBubbleFrame = CGRectZero;
    self.voiceState = OctoVoiceStateIdle;
    self.transcribedText = nil;
    self.pendingAudioClips = nil;
    self.pendingEditBaseContext = nil;
    self.pendingInsertCursorRange = NSMakeRange(0, 0);

    if (!self.voiceOverlay) return;
    [self stopThinkingAnimation];
    UIView *ov = self.voiceOverlay;
    [UIView animateWithDuration:0.18 animations:^{ ov.alpha = 0; } completion:^(BOOL f) { [ov removeFromSuperview]; }];
    self.voiceOverlay = nil;
    self.bubbleView = nil;
    self.bubbleTail = nil;
    self.waveContainer = nil;
    self.waveBars = nil;
    self.bottomAreaView = nil;
    self.hintLabel = nil;
    self.resultTextView = nil;
    self.resultBottomBar = nil;
    self.resultCancelBtn = nil;
    self.resultInsertBtn = nil;
    self.resultAppendBtn = nil;
    self.resultCancelLabel = nil;
    self.resultAppendLabel = nil;
    self.thinkingDots = nil;
    self.thinkingOverlayView = nil;
}


#pragma mark - Thinking Animation

- (void)startThinkingAnimation {
    [self stopThinkingAnimation];
    CGFloat bubbleW = self.bubbleView.bounds.size.width;
    CGFloat bubbleH = self.bubbleView.bounds.size.height;
    self.thinkingOverlayView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bubbleW, bubbleH)];
    self.thinkingOverlayView.backgroundColor = [UIColor colorWithRed:0.88 green:0.94 blue:1.0 alpha:0.75];
    self.thinkingOverlayView.layer.cornerRadius = 16;
    [self.bubbleView addSubview:self.thinkingOverlayView];
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
    __weak typeof(self) weakSelf = self;
    self.thinkingTimer = [NSTimer scheduledTimerWithTimeInterval:0.35 repeats:YES block:^(NSTimer *t) {
        [weakSelf animateThinkingDots];
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
    [self.thinkingTimer invalidate];
    self.thinkingTimer = nil;
    [self.thinkingOverlayView removeFromSuperview];
    self.thinkingOverlayView = nil;
    self.thinkingDots = nil;
}

- (void)transitionToResultUIWithThinking:(BOOL)showThinking {
    self.waveContainer.hidden = YES;
    self.bottomAreaView.hidden = YES;
    self.bubbleTail.hidden = YES;
    CGFloat sw = self.voiceOverlay.bounds.size.width;
    CGFloat sh = self.voiceOverlay.bounds.size.height;
    CGFloat bubbleW = sw - 40;
    CGFloat minBubbleH = 80;
    CGFloat bubbleY = sh * 0.15;
    [UIView animateWithDuration:0.3 animations:^{
        self.bubbleView.frame = CGRectMake(20, bubbleY, bubbleW, minBubbleH);
        self.bubbleView.backgroundColor = [UIColor colorWithRed:0.88 green:0.94 blue:1.0 alpha:1.0];
    }];
    self.resultTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, 10, bubbleW - 24, minBubbleH - 20)];
    self.resultTextView.backgroundColor = [UIColor clearColor];
    self.resultTextView.textColor = [UIColor blackColor];
    self.resultTextView.font = [UIFont systemFontOfSize:17];
    self.resultTextView.scrollEnabled = YES;
    self.resultTextView.showsVerticalScrollIndicator = YES;
    // 这里展示的是"确认原话"阶段,编辑不会带入 Phase B(服务端只认重新上传的录音,不认这段
    // 文字),故意做成只读——避免用户以为改了这段文字就能修正识别错误,可读可选可复制即可。
    self.resultTextView.editable = NO;
    self.resultTextView.text = self.transcribedText ?: @"";
    [self.bubbleView addSubview:self.resultTextView];
    if (showThinking) {
        [self startThinkingAnimation];
    }
    CGFloat barH = 80;
    CGFloat barY = sh - barH - 40;
    self.resultBottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, barY, sw, barH)];
    self.resultBottomBar.hidden = showThinking;
    [self.voiceOverlay addSubview:self.resultBottomBar];
    CGFloat btnSize = 52;
    CGFloat spacing = sw / 4.0;

    // 以下三个按钮的图标/文案/样式均参照群聊语音输入结果页 WKHoldToTalkManager 的
    // resultCancelBtn/resultMicBtn/resultSendTextBtn + createIconButton:/createSmallLabel:,
    // 保持两处 UI 视觉一致。

    self.resultCancelBtn = [self createResultIconButton:btnSize imageAsset:@"Conversation/Toolbar/HTTCancel"];
    self.resultCancelBtn.center = CGPointMake(spacing * 1, btnSize / 2);
    [self.resultCancelBtn addTarget:self action:@selector(onResultCancel) forControlEvents:UIControlEventTouchUpInside];
    [self.resultBottomBar addSubview:self.resultCancelBtn];
    self.resultCancelLabel = [self createResultSmallLabel:LLang(@"取消") centerX:self.resultCancelBtn.center.x belowY:CGRectGetMaxY(self.resultCancelBtn.frame) + 6];
    [self.resultBottomBar addSubview:self.resultCancelLabel];

    self.resultAppendBtn = [self createResultIconButton:btnSize imageAsset:@"Conversation/Toolbar/HTTMic"];
    self.resultAppendBtn.center = CGPointMake(spacing * 2, btnSize / 2);
    UILongPressGestureRecognizer *appendLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleAppendLongPress:)];
    appendLongPress.minimumPressDuration = 0.15;
    [self.resultAppendBtn addGestureRecognizer:appendLongPress];
    [self.resultBottomBar addSubview:self.resultAppendBtn];
    self.resultAppendLabel = [self createResultSmallLabel:LLang(@"按住继续") centerX:self.resultAppendBtn.center.x belowY:CGRectGetMaxY(self.resultAppendBtn.frame) + 6];
    [self.resultBottomBar addSubview:self.resultAppendLabel];

    self.resultInsertBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.resultInsertBtn setTitle:LLang(@"确认") forState:UIControlStateNormal];
    [self.resultInsertBtn setTitleColor:[UIColor colorWithRed:0.15 green:0.15 blue:0.2 alpha:1.0] forState:UIControlStateNormal];
    self.resultInsertBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.resultInsertBtn.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    self.resultInsertBtn.layer.cornerRadius = btnSize / 2;
    self.resultInsertBtn.frame = CGRectMake(0, 0, 72, btnSize);
    self.resultInsertBtn.center = CGPointMake(spacing * 3, btnSize / 2);
    [self.resultInsertBtn addTarget:self action:@selector(onResultInsertTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.resultBottomBar addSubview:self.resultInsertBtn];
}

- (UIButton *)createResultIconButton:(CGFloat)size imageAsset:(NSString *)assetName {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, size, size);
    btn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    btn.layer.cornerRadius = size / 2;
    btn.clipsToBounds = YES;
    btn.imageEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
    btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *img = [WKApp.shared loadImage:assetName moduleID:@"WuKongBase"];
    if (img) [btn setImage:img forState:UIControlStateNormal];
    return btn;
}

- (UILabel *)createResultSmallLabel:(NSString *)text centerX:(CGFloat)cx belowY:(CGFloat)y {
    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = text;
    lbl.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    lbl.font = [UIFont systemFontOfSize:11];
    lbl.textAlignment = NSTextAlignmentCenter;
    [lbl sizeToFit];
    lbl.center = CGPointMake(cx, y);
    return lbl;
}

// 结果气泡随内容多少动态调整高度:下限与改动前的固定高度(80)保持一致,
// 上限留出气泡顶部到底部按钮栏之间的可用空间(减 20pt 间距,避免贴到按钮栏)。
- (void)resizeResultBubbleForText:(NSString *)text animated:(BOOL)animated {
    if (!self.bubbleView || !self.voiceOverlay) return;
    CGFloat sh = self.voiceOverlay.bounds.size.height;
    CGFloat bubbleW = self.bubbleView.frame.size.width;
    CGFloat bubbleX = self.bubbleView.frame.origin.x;
    CGFloat bubbleY = self.bubbleView.frame.origin.y;
    CGFloat minBubbleH = 80;
    CGFloat barH = 80;
    CGFloat barY = sh - barH - 40;
    CGFloat maxBubbleH = MAX(minBubbleH, barY - bubbleY - 20);

    CGFloat bubbleH = minBubbleH;
    if (text.length > 0) {
        UIFont *font = [UIFont systemFontOfSize:17];
        CGFloat textWidth = bubbleW - 24;
        CGRect rect = [text boundingRectWithSize:CGSizeMake(textWidth, CGFLOAT_MAX)
                                          options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                       attributes:@{NSFontAttributeName: font}
                                          context:nil];
        bubbleH = MAX(minBubbleH, MIN(ceil(rect.size.height) + 20, maxBubbleH));
    }

    void (^apply)(void) = ^{
        self.bubbleView.frame = CGRectMake(bubbleX, bubbleY, bubbleW, bubbleH);
        self.resultTextView.frame = CGRectMake(12, 10, bubbleW - 24, bubbleH - 20);
    };
    if (animated) {
        [UIView animateWithDuration:0.25 animations:apply];
    } else {
        apply();
    }
}

- (void)finishThinkingAndShowText {
    [self stopThinkingAnimation];
    self.voiceState = OctoVoiceStateResult;
    self.resultTextView.text = self.transcribedText;
    // 只读:这段文字编辑了也不会带入 Phase B,见 transitionToResultUIWithThinking: 里的说明。
    self.resultTextView.editable = NO;
    self.resultBottomBar.hidden = NO;
    // "确认原话"阶段也允许继续按住说话——多段录音各自攒进 pendingAudioClips,确认时再依次
    // 链式改写,所以这里不再禁用"按住继续"按钮。
    self.resultAppendBtn.userInteractionEnabled = YES;
    self.resultAppendBtn.alpha = 1.0;
    [self resizeResultBubbleForText:self.transcribedText animated:YES];
}

- (void)onResultCancel {
    // 取消动作和键盘收起要同一时刻发生,不等 hideVoiceOverlay 淡出动画结束后
    // 视图被移出 window 时才被动 resign,那样看起来会慢一拍。
    [self.resultTextView resignFirstResponder];
    self.transcribedText = nil;
    [self hideVoiceOverlay];
}

- (void)onResultInsertTapped {
    // 键盘和按钮动作要同步收起,原因同 onResultCancel。气泡现在只会展示"确认原话"这一个
    // 阶段——AI 改写(Phase B)完成后直接写回正文并关闭气泡,不会再展示等待二次确认的状态,
    // 所以这里点确认统一走 Phase B,不用再分流。
    [self.resultTextView resignFirstResponder];
    [self confirmASRPreviewAndRunEditPhase];
}

- (void)handleAppendLongPress:(UILongPressGestureRecognizer *)gesture {
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            self.isAppendMode = YES;
            self.isGestureActive = YES;
            self.touchStartPoint = [gesture locationInView:self.voiceOverlay];
            [self requestRecordPermissionThenStart];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            // 同 handleHoldToTalk: 的修复——必须放行 Cancelling,否则一旦上滑超过阈值就再也
            // 追踪不到手指位置,松手永远只能触发 cancelAppendRecording,进不了转文字状态。
            if (self.voiceState != OctoVoiceStateRecording && self.voiceState != OctoVoiceStateCancelling) return;
            CGPoint current = [gesture locationInView:self.voiceOverlay];
            CGFloat upOffset = self.touchStartPoint.y - current.y;
            BOOL shouldCancel = upOffset > kVoiceCancelUpOffset;
            if (shouldCancel && self.voiceState != OctoVoiceStateCancelling) {
                self.voiceState = OctoVoiceStateCancelling;
                [self updateVoiceOverlayForState];
            } else if (!shouldCancel && self.voiceState == OctoVoiceStateCancelling) {
                self.voiceState = OctoVoiceStateRecording;
                [self updateVoiceOverlayForState];
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            self.isGestureActive = NO;
            if (self.voiceState == OctoVoiceStateCancelling) {
                [self cancelAppendRecording];
            } else if (self.voiceState == OctoVoiceStateRecording) {
                [self stopAppendRecordingAndTranscribe];
            }
            break;
        }
        default: break;
    }
}

- (void)transitionToRecordingUI {
    [self.resultTextView resignFirstResponder];
    // 直接复用第一次录音的气泡/波形/底部弧形UI(bubbleView/waveContainer/bottomAreaView/
    // bubbleTail),不是另建一套——先记下"确认原话"结果气泡当前的frame(录音结束后要换回来),
    // 再把气泡本身换回第一次录音时的尺寸/位置,取消隐藏波形和弧形区域。这样"按住继续"追加
    // 录音时看到的就是跟第一次一模一样的视图,不会有任何样式差异。
    self.preAppendBubbleFrame = self.bubbleView.frame;
    self.resultTextView.hidden = YES;
    self.bubbleView.frame = self.recordingBubbleFrame;
    self.bubbleTail.center = CGPointMake(self.bubbleOriginCenter.x, CGRectGetMaxY(self.bubbleView.frame) + 4);
    self.waveContainer.hidden = NO;
    self.bottomAreaView.hidden = NO;
    self.bubbleTail.hidden = NO;
    // 按下瞬间要和第一次录音的初始状态完全一致:提示文案"松手 转文字"+气泡/气泡尾正常蓝色,
    // 不能直接调 updateVoiceOverlayForState——它只认 Recording/Cancelling 两态,会把刚按下这
    // 一刻就写成"松手 结束 · 上滑 取消",和第一次录音按下瞬间的文案对不上。后续上滑触发取消区
    // 时仍由 handleAppendLongPress: 的 Changed 分支调用 updateVoiceOverlayForState 正常切换。
    UIColor *normalColor = [UIColor colorWithRed:0.88 green:0.94 blue:1.0 alpha:1.0];
    self.bubbleView.backgroundColor = normalColor;
    self.bubbleTail.backgroundColor = normalColor;
    self.hintLabel.text = LLang(@"松手 转文字");
    self.hintLabel.textColor = [UIColor whiteColor];
    // 追加录音期间不展示"取消/按住继续/确认"三个按钮,和第一次录音时"整个结果条尚未创建、
    // 自然看不到按钮"的观感保持一致;录音结束/取消换回结果页时在 hideAppendOverlay 里恢复。
    self.resultBottomBar.hidden = YES;
}

- (void)hideAppendOverlay {
    self.isAppendMode = NO;
    // 追加录音结束/取消后,把气泡换回"确认原话"结果气泡本身的展示,波形/弧形区域重新隐藏。
    self.waveContainer.hidden = YES;
    self.bottomAreaView.hidden = YES;
    self.bubbleTail.hidden = YES;
    self.bubbleView.frame = self.preAppendBubbleFrame;
    self.resultTextView.hidden = NO;
    self.resultBottomBar.hidden = NO;
}

- (void)cancelAppendRecording {
    [self invalidateRecordTimers];
    if (self.audioRecorder.isRecording) [self.audioRecorder stop];
    [self restoreAudioSession];
    [self cleanupRecordFile];
    self.voiceState = OctoVoiceStateResult;
    [self hideAppendOverlay];
}

- (void)stopAppendRecordingAndTranscribe {
    [self invalidateRecordTimers];
    if (self.voiceState != OctoVoiceStateRecording) return;
    NSTimeInterval duration = self.audioRecorder.currentTime;
    [self.audioRecorder stop];
    [self restoreAudioSession];
    if (duration < 1.0) {
        [self.view showMsg:LLang(@"说话时间太短")];
        [self hideAppendOverlay];
        self.voiceState = OctoVoiceStateResult;
        [self cleanupRecordFile];
        return;
    }
    NSData *audioData = [NSData dataWithContentsOfFile:self.recordFilePath];
    [self cleanupRecordFile];
    if (!audioData || audioData.length == 0) {
        [self.view showMsg:LLang(@"语音识别失败,请重试")];
        [self hideAppendOverlay];
        self.voiceState = OctoVoiceStateResult;
        return;
    }
    [self hideAppendOverlay];
    [self beginASRPreviewForAudio:audioData isFirstUtterance:NO];
}

- (void)beginASRPreviewForAudio:(NSData *)audioData isFirstUtterance:(BOOL)isFirstUtterance {
    // "确认原话"阶段按住继续不禁用,允许用户在还没交给AI处理之前继续
    // 多说几句——这种情况下这段录音要追加进同一批 pendingAudioClips,基准正文不变(仍是
    // 这一整批开始时锁定的正文)。Phase B 确认后会直接把结果写回正文并关闭气泡(见
    // confirmASRPreviewAndRunEditPhase),不会再出现"AI结果已确认、气泡还开着"的状态,
    // 所以"按住继续"只可能发生在这一批还没确认之前,不需要再区分"上一轮已确认AI"的情形。
    if (isFirstUtterance) {
        self.pendingAudioClips = [NSMutableArray arrayWithObject:audioData];
        self.pendingEditBaseContext = self.textView.text;
        // 只在这一批的第一段录音时锁定光标——后续"按住继续"时 textView 早已不是第一响应者、
        // 用户手指也碰不到它,selectedRange 不会再变,不需要每段都重新记录。
        self.pendingInsertCursorRange = self.textView.selectedRange;
    } else {
        [self.pendingAudioClips addObject:audioData];
    }
    self.voiceState = OctoVoiceStateThinking;
    if (isFirstUtterance) {
        [self transitionToResultUIWithThinking:YES];
    } else {
        self.resultTextView.editable = NO;
        self.resultBottomBar.hidden = YES;
        [self startThinkingAnimation];
    }
    // 续说的话要拼在已展示的原话后面,不能被这一次的识别结果整个覆盖掉。
    NSString *previousPreviewText = isFirstUtterance ? nil : (self.transcribedText ?: @"");
    __weak typeof(self) weakSelf = self;
    // 捕获发起这次请求那一刻的 generation——hideVoiceOverlay 会在会话被取消/关闭/页面消失
    // 时递增它。等这个网络回调真正回来时,如果 generation 已经变了,说明这段录音所属的
    // 语音会话早就结束了,回调是"迟到"的,不能再往 voiceState/pendingAudioClips 这些属于
    // 新会话(或者已经不存在的旧会话)的状态上写东西。
    NSUInteger capturedGeneration = self.voiceEditGeneration;
    // Phase A: 不传 contextText,只做纯 ASR——气泡先展示"这一次说的原话"给用户核对,
    // 确认后才进入 Phase B(见 confirmASRPreviewAndRunEditPhase)交给大模型按
    // pendingEditBaseContext 改写。注意:此处用户如果编辑了气泡里的原话文字,那次编辑
    // 不会带入 Phase B——服务端接口只接受音频,Phase B 必须重新上传这段录音重新识别,
    // 编辑框在这一阶段只用于用户自己核对"听清楚了没有"。
    [[WKVoiceInputService shared] transcribeAudio:audioData
                                       contextText:nil
                                       chatContext:nil
                                   personalContext:nil
                                     memberContext:nil
                                              mode:nil
                                        completion:^(WKVoiceInputResult *result, NSError *error) {
        if (!weakSelf || weakSelf.voiceEditGeneration != capturedGeneration) return;
        if (error) {
            // 排查"确认原话就显示成功,确认改写却报识别失败"这类问题时,这行日志能看出
            // 具体是哪一段(Phase A/isFirstUtterance)、什么 domain/code——网络层超时通常是
            // NSURLErrorDomain 负数 code,服务端业务失败是 WKVoiceInput domain、code=status。
#if DEBUG
            NSLog(@"[SummaryVoiceEdit] Phase A ASR 失败 isFirstUtterance=%d domain=%@ code=%ld msg=%@",
                  isFirstUtterance, error.domain, (long)error.code, error.localizedDescription);
#endif
            [weakSelf.view showMsg:LLang(@"语音识别失败,请重试")];
            [weakSelf hideVoiceOverlay];
            return;
        }
        if (result.text.length == 0) {
            [weakSelf.view showMsg:LLang(@"未识别到语音")];
            if (isFirstUtterance) {
                // 第一次录音本身就没内容可核对,没有"上一轮结果"可以停留,只能整体关闭。
                [weakSelf hideVoiceOverlay];
            } else {
                // 追加录音没识别到语音:不关闭气泡,停留在"确认原话"页面等用户自己操作
                // (可以再按一次"按住继续"重录,也可以直接确认/取消已经攒到的内容)。
                // 这次没用的空录音要从批次里移除,否则用户最终确认时 Phase B 链式处理会
                // 在这段空音频上再次判定"未识别到语音"而整体失败退出。
                [weakSelf.pendingAudioClips removeLastObject];
                [weakSelf stopThinkingAnimation];
                weakSelf.voiceState = OctoVoiceStateResult;
                weakSelf.resultTextView.editable = NO;
                weakSelf.resultBottomBar.hidden = NO;
            }
            return;
        }
        weakSelf.transcribedText = previousPreviewText.length > 0
            ? [previousPreviewText stringByAppendingString:result.text]
            : result.text;
        [weakSelf finishThinkingAndShowText];
    }];
}

- (void)confirmASRPreviewAndRunEditPhase {
    if (self.pendingAudioClips.count == 0) {
        [self hideVoiceOverlay];
        return;
    }
    self.resultTextView.editable = NO;
    self.resultBottomBar.hidden = YES;
    [self startThinkingAnimation];
    // "确认原话"阶段允许连续按住继续多说几句,pendingAudioClips 里可能攒了不止一段录音;
    // 依次重新上传+按当前基准正文改写,前一段的改写结果作为后一段的基准正文,链式处理完
    // 整批之后直接把最终结果写回正文——接口一次只认一段音频,链式处理才不会丢内容。
    [self runEditPhaseWithBaseContext:self.pendingEditBaseContext
                        remainingClips:[self.pendingAudioClips mutableCopy]];
}

- (void)runEditPhaseWithBaseContext:(NSString *)baseContext
                      remainingClips:(NSMutableArray<NSData *> *)remainingClips {
    if (remainingClips.count == 0) {
        // octo-speech 无论把这段话判成"口述"还是"编辑指令",text 字段返回的都是整篇处理后的
        // 正文(口述=原文+新话拼接,指令=按指令改写后的整篇正文),接口本身不区分着返回、也
        // 没有多余字段告诉客户端它判了哪一种。但这个"拼接 vs 改写"的差异会机械地体现在文本
        // 关系上:
        // 如果这一整批(不管链了几段、中途是不是有些段落被当成指令重新措辞过)最终产出的
        // 正文,原封不动地把 batch 开始前的正文(pendingEditBaseContext)当成前缀、只在后面
        // 多出一段——那就意味着原文一个字没被动过,不需要借助任何关键词/语义判断,单看
        // "是否前缀不变"这一个机械条件就足够。这种情况下不整篇替换、不把光标甩到文末,而是
        // 把多出来的这一段插回用户开始说话那一刻光标所在的位置——这才是"随口念一段话"该有
        // 的体验。哪怕这次其实是一句"在末尾加个免责声明"之类的指令,只要效果同样是"原文不变
        // +纯追加",插回光标处也不算错——它本来就该在光标处生效,只是巧合被服务端处理成了
        // 追加而非改写。一旦前缀对不上,说明原文中途确实被改写过,不再区分,直接按整篇替换
        // 处理(等价于此前的行为,高亮 diff 对比的基准固定用 initialContent,原因见下面
        // applyVoiceEditResultToDocument: 的调用)。
        NSString *originalDoc = self.pendingEditBaseContext ?: @"";
        if ([baseContext hasPrefix:originalDoc] && baseContext.length > originalDoc.length) {
            NSString *dictatedSuffix = [baseContext substringFromIndex:originalDoc.length];
            [self wk_insertDictatedSuffix:dictatedSuffix atCursorRange:self.pendingInsertCursorRange];
        } else {
            // 高亮 diff 对比的基准固定用 initialContent(页面刚打开时的正文,viewDidLoad 里锁定、
            // 全程不变),而不是这一批开始前的快照——这样连续做几轮语音编辑,每轮高亮的都是
            // "相对刚打开页面时"的累积差异,不会被后一轮整体重绘覆盖掉。副作用:diff是纯文本
            // 对比,不区分改动是语音改的还是手动打字改的,两轮语音编辑之间手动打的字也会被
            // 高亮进去——这是有意接受的取舍,不是bug。
            [self applyVoiceEditResultToDocument:baseContext previousDocText:self.initialContent];
        }
        [self hideVoiceOverlay];
        return;
    }
    NSData *audioData = remainingClips.firstObject;
    [remainingClips removeObjectAtIndex:0];
    __weak typeof(self) weakSelf = self;
    // 同 beginASRPreviewForAudio:isFirstUtterance: 里的道理——这条链每一段录音都要单独
    // 请求一次网络,链条本身可能横跨好几次网络往返;只要中途会话被取消/关闭/页面消失,
    // hideVoiceOverlay 就会让 generation 变掉,后面还没返回的每一段回调都要能认出自己已经
    // "迟到"、不再是当前会话的一部分,否则递归调用 runEditPhaseWithBaseContext: 会继续在
    // 一个早已不存在的会话上跑下去。
    NSUInteger capturedGeneration = self.voiceEditGeneration;
    [[WKVoiceInputService shared] transcribeAudio:audioData
                                       contextText:baseContext
                                       chatContext:nil
                                   personalContext:nil
                                     memberContext:nil
                                              mode:nil
                                        completion:^(WKVoiceInputResult *result, NSError *error) {
        if (!weakSelf || weakSelf.voiceEditGeneration != capturedGeneration) return;
        if (error) {
            // Phase B 比 Phase A 多带了 contextText(当前正文全文)交给服务端做改写,处理量更大、
            // 更可能超时或撞长度限制——这行日志把 remainingClips/contextText 长度和真实 error
            // 一起打出来,方便区分是网络超时(NSURLErrorDomain)还是服务端业务失败(WKVoiceInput
            // domain,code=业务 status)。
#if DEBUG
            NSLog(@"[SummaryVoiceEdit] Phase B 改写失败 remainingClips=%lu contextLen=%lu domain=%@ code=%ld msg=%@",
                  (unsigned long)remainingClips.count, (unsigned long)baseContext.length,
                  error.domain, (long)error.code, error.localizedDescription);
#endif
            [weakSelf.view showMsg:LLang(@"语音识别失败,请重试")];
            [weakSelf hideVoiceOverlay];
            return;
        }
        // result.text 为空是接口层面的硬失败(没转出任何文本),这一批录音已经没有基准可续,
        // 只能整体中止。
        if (result.text.length == 0) {
            [weakSelf.view showMsg:LLang(@"未识别到语音")];
            [weakSelf hideVoiceOverlay];
            return;
        }
        // 未识别到有效语音时,contextText 非空会被服务端原样当作 text 返回(IsNoSpeech 分支)。
        // 但这跟上面 length==0 不是一回事:AI 判断"这段指令效果就是不改正文"(比如追加录音里
        // 有一段是清嗓子/无意义的话)同样会原样返回 baseContext,跟"没识别到语音"在文本上没法
        // 区分。这两种情况的正确处理都是"跳过这一段、不当成这一段有任何改动",但不该像之前
        // 那样把 hideVoiceOverlay 整个会话都收掉——remainingClips 里后面几段可能是有效内容,
        // 一整批因为中间某一段没说清楚就被全部丢弃,对用户是不成比例的破坏。所以这里继续用
        // 同一个 baseContext 跑下一段,只有 remainingClips 耗尽仍是这个结果才会走到上面
        // length==0 分支或者直接进入 count==0 分支正常收尾。
        if (baseContext.length > 0 && [result.text isEqualToString:baseContext]) {
            [weakSelf runEditPhaseWithBaseContext:baseContext remainingClips:remainingClips];
            return;
        }
        [weakSelf runEditPhaseWithBaseContext:result.text remainingClips:remainingClips];
    }];
}

#pragma mark - Voice Edit Diff Highlight

// 把判定为"纯口述"时新增出来的这一段内容,插回 range(通常是这一批语音开始前的光标位置)。
// 用 insertText: 而不是直接改 textStorage/attributedText,是为了完整复用 UITextView 自己
// 那一套"打字"路径——自动登记进 self.textView.undoManager(和手动打字、Cmd+Z 是同一个栈)、
// 自动把 selectedRange 移到插入内容之后、自动触发 -textViewDidChange:(顺带联动
// wk_updateUndoButtonState 和 wk_refreshManualEditHighlight,新插入的这段因此和手动打字一样
// 会有紫色高亮),不需要再写一份重复逻辑,也不会像整段替换 attributedText 那样把光标弹飞。
- (void)wk_insertDictatedSuffix:(NSString *)suffix atCursorRange:(NSRange)range {
    if (suffix.length == 0) return;
    // 语音模式下 textView 未必是 first responder(键盘态被 voiceDummyInputView 顶替),
    // insertText: 依赖的输入会话需要 textView 真正 becomeFirstResponder 才能可靠生效。
    if (!self.textView.isFirstResponder) {
        [self.textView becomeFirstResponder];
    }
    NSInteger textLength = self.textView.text.length;
    NSInteger location = MIN(range.location, textLength);
    NSInteger length = MIN(range.length, textLength - location);
    self.textView.selectedRange = NSMakeRange(location, length);
    [self.textView insertText:suffix];
}

- (void)applyVoiceEditResultToDocument:(NSString *)newText previousDocText:(NSString *)previousDocText {
    if (newText.length == 0) return;
    NSAttributedString *newAttr = [self attributedTextForDocument:newText highlightDiffFrom:previousDocText ?: @""];
    [self wk_replaceTextViewAttributedText:newAttr];
    self.textView.selectedRange = NSMakeRange(newText.length, 0);
}

// 用 prepareWithInvocationTarget: 把"整体替换回旧值"注册成一步 undo——标准 NSUndoManager
// 写法,每次调用自身都会把相反方向的替换再注册一次,undo/redo 可以来回切换,不需要
// 额外维护快照数组。这一步和 UITextView 输入时自动登记的打字 undo 是同一个
// undoManager,顺序天然按时间穿插,不会互相打断对方的历史。
- (void)wk_replaceTextViewAttributedText:(NSAttributedString *)newValue {
    NSAttributedString *oldValue = [self.textView.attributedText copy];
    NSUndoManager *undoManager = self.textView.undoManager;
    [[undoManager prepareWithInvocationTarget:self] wk_replaceTextViewAttributedText:oldValue];
    self.textView.attributedText = newValue;
    [self wk_updateUndoButtonState];
}

// 逐字符 Myers 最短编辑脚本(O(ND) 时间,D 为编辑距离)——只把 newText 里真正"新增/替换
// 进来"的字符收进待高亮区间,不会像"公共前缀+公共后缀"那样一旦中间被重新措辞,就把从第一处
// 分歧到最后一处分歧之间的一大段全部当成"改过"。
// 实现细节:d 每往前推进一轮,都要把当时的 v 数组整份存进 trace 用于回溯——这部分内存/时间
// 开销约是 O(D^2)。真正跑 Myers 的只是每一个"行级锚点之间的小片段"(见
// wk_addChangedIndexesForOldCore:newCore:offset:intoIndexSet:),D 在某个片段本身被
// 大幅改写(比如语音指令是"把这一段生成英文版"这种整段换一种语言)时会退化到接近该片段
// 新旧长度之和。kVoiceDiffMaxTotalLen 就是给这种最坏情形兜底:单个片段长度超过这个值,
// 该片段直接退化为"整段高亮"(只影响这一个片段,不会牵连其它片段)——这类场景下这个片段
// 本来也确实是整段都变了,退化后的效果反而还是合理的,只是不再精细到字符。
static const NSInteger kVoiceDiffMaxTotalLen = 2000;

// 行级 Myers(wk_lineMatchAnchorsForOldLines:newLines:)按 (oldLines.count + newLines.count)
// 分配 trace 数组,大小是 O((n+m)^2) 且没有上限——字符级那条路径靠 kVoiceDiffMaxTotalLen
// 兜底退化,行级这条路径原来没有对应的兜底。总结正文正常情况下就几十到大几十行,
// 但用户可能整段粘贴一篇很长的文章(几千行)进来,此时这里会在主线程(每次
// textViewDidChange: 触发)分配几百 MB 甚至更多、并且不止一次(每敲一个字符都要重新跑),
// 卡顿甚至 OOM。超过这个行数直接退化为不切行、整个核心区交给字符级 Myers 处理——那条
// 路径自己的 kVoiceDiffMaxTotalLen 还会再兜底一层,不会真的按 O(D^2) 展开。
static const NSInteger kVoiceDiffMaxLineCount = 500;

typedef struct {
    NSInteger oldIdx;
    NSInteger newIdx;
} WKLineMatchAnchor;

- (NSArray<NSValue *> *)wk_changedRangesInNewText:(NSString *)newText comparedToOldText:(NSString *)oldText {
    NSInteger n = oldText.length;
    NSInteger m = newText.length;
    if (m == 0) return @[];
    if (n == 0) return @[[NSValue valueWithRange:NSMakeRange(0, m)]];

    unichar *a = (unichar *)malloc(sizeof(unichar) * n);
    unichar *b = (unichar *)malloc(sizeof(unichar) * m);
    if (!a || !b) {
        // 分配失败:退化为"整段都算改动",和上面 n==0 的降级分支保持同一种兜底方式,
        // 不引入独立的错误提示。
        free(a);
        free(b);
        return @[[NSValue valueWithRange:NSMakeRange(0, m)]];
    }
    [oldText getCharacters:a range:NSMakeRange(0, n)];
    [newText getCharacters:b range:NSMakeRange(0, m)];

    // 先裁掉新旧两篇文本的公共前缀/公共后缀,只把中间真正不同的"核心差异区"往下交。
    NSInteger prefixLen = 0;
    NSInteger maxPrefix = MIN(n, m);
    while (prefixLen < maxPrefix && a[prefixLen] == b[prefixLen]) {
        prefixLen++;
    }
    NSInteger suffixLen = 0;
    NSInteger maxSuffix = MIN(n, m) - prefixLen;
    while (suffixLen < maxSuffix && a[n - 1 - suffixLen] == b[m - 1 - suffixLen]) {
        suffixLen++;
    }
    NSInteger coreN = n - prefixLen - suffixLen;
    NSInteger coreM = m - prefixLen - suffixLen;
    free(a);
    free(b);

    NSMutableIndexSet *insertedInNew = [NSMutableIndexSet indexSet];
    if (coreM > 0) {
        NSString *oldCore = [oldText substringWithRange:NSMakeRange(prefixLen, coreN)];
        NSString *newCore = [newText substringWithRange:NSMakeRange(prefixLen, coreM)];
        [self wk_addChangedIndexesForOldCore:oldCore newCore:newCore offset:prefixLen intoIndexSet:insertedInNew];
    }

    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    [insertedInNew enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
        [ranges addObject:[NSValue valueWithRange:range]];
    }];
    return ranges;
}

// 核心差异区如果本身还跨多行、夹着"整段没变的行"——比如两处相隔较远的独立改动,中间隔着
// 一大段没动过的内容——公共前缀/后缀裁剪只能从两头各裁一次,裁不掉夹在中间的这一段,会把
// 没动过的内容也当成"核心区"的一部分,一旦触发下面的超限退化,连没改的部分都会被整段染紫。
// 这里先按行做一次行级 Myers(比较整行是否相同,不看行内字符),把"原样保留、只是恰好夹在
// 两处改动之间"的行当锚点摘出来;锚点之间才是真正连续的改动片段,分别再交给字符级 Myers——
// 退化阈值还是原来那个,只是现在只作用在这一个片段上,不会牵连中间没动过的锚点行。
// 行数通常远小于字符数(总结正文按段落换行,一般几十到大几十行),就算改动分散在文档两端,
// 这里的行级编辑距离也很小,不会有字符级 Myers 那种大 D 时的内存/时间顾虑。
- (void)wk_addChangedIndexesForOldCore:(NSString *)oldCore
                                newCore:(NSString *)newCore
                                 offset:(NSInteger)offset
                           intoIndexSet:(NSMutableIndexSet *)insertedInNew {
    NSArray<NSString *> *oldLines = [oldCore componentsSeparatedByString:@"\n"];
    NSArray<NSString *> *newLines = [newCore componentsSeparatedByString:@"\n"];
    if (oldLines.count <= 1 || newLines.count <= 1 ||
        oldLines.count + newLines.count > kVoiceDiffMaxLineCount) {
        // 核心区本身不跨行,行级切分没有意义;或者行数超过兜底阈值,行级 Myers 的
        // O((n+m)^2) trace 数组不能再展开——两种情况都直接按字符级处理(含超限退化)。
        [self wk_addSingleRegionChangedIndexesOldText:oldCore newText:newCore offset:offset intoIndexSet:insertedInNew];
        return;
    }

    NSInteger newLineCount = newLines.count;
    NSInteger oldLineCount = oldLines.count;
    NSMutableArray<NSValue *> *newLineRanges = [NSMutableArray arrayWithCapacity:newLineCount];
    NSInteger pos = 0;
    for (NSInteger i = 0; i < newLineCount; i++) {
        NSInteger len = newLines[i].length;
        [newLineRanges addObject:[NSValue valueWithRange:NSMakeRange(pos, len)]];
        pos += len;
        if (i < newLineCount - 1) pos += 1; // "\n" 分隔符,最后一行后面没有
    }
    NSMutableArray<NSValue *> *oldLineRanges = [NSMutableArray arrayWithCapacity:oldLineCount];
    pos = 0;
    for (NSInteger i = 0; i < oldLineCount; i++) {
        NSInteger len = oldLines[i].length;
        [oldLineRanges addObject:[NSValue valueWithRange:NSMakeRange(pos, len)]];
        pos += len;
        if (i < oldLineCount - 1) pos += 1;
    }

    NSArray<NSValue *> *anchors = [self wk_lineMatchAnchorsForOldLines:oldLines newLines:newLines];

    NSInteger prevOldLine = 0, prevNewLine = 0;
    for (NSInteger idx = 0; idx <= anchors.count; idx++) {
        NSInteger gapOldEnd, gapNewEnd;
        if (idx < anchors.count) {
            WKLineMatchAnchor anchor;
            [anchors[idx] getValue:&anchor];
            gapOldEnd = anchor.oldIdx;
            gapNewEnd = anchor.newIdx;
        } else {
            // 哨兵:最后一个锚点之后到文档末尾也算一段待比较的尾段。
            gapOldEnd = oldLineCount;
            gapNewEnd = newLineCount;
        }

        if (gapNewEnd > prevNewLine) {
            NSRange newStartRange = [newLineRanges[prevNewLine] rangeValue];
            NSRange newEndRange = [newLineRanges[gapNewEnd - 1] rangeValue];
            NSRange newGapRange = NSMakeRange(newStartRange.location, NSMaxRange(newEndRange) - newStartRange.location);
            NSString *newGapText = [newCore substringWithRange:newGapRange];

            NSString *oldGapText = @"";
            if (gapOldEnd > prevOldLine) {
                NSRange oldStartRange = [oldLineRanges[prevOldLine] rangeValue];
                NSRange oldEndRange = [oldLineRanges[gapOldEnd - 1] rangeValue];
                NSRange oldGapRange = NSMakeRange(oldStartRange.location, NSMaxRange(oldEndRange) - oldStartRange.location);
                oldGapText = [oldCore substringWithRange:oldGapRange];
            }

            [self wk_addSingleRegionChangedIndexesOldText:oldGapText newText:newGapText
                                                     offset:offset + newGapRange.location
                                               intoIndexSet:insertedInNew];
        }

        if (idx < anchors.count) {
            prevOldLine = gapOldEnd + 1;
            prevNewLine = gapNewEnd + 1;
        }
    }
}

// 对一个已经确定"没法再拆"的片段(核心区本身不跨行,或者行级锚点之间的一小段)跑字符级
// Myers,片段新旧长度之和超过 kVoiceDiffMaxTotalLen 时退化为整段高亮。
- (void)wk_addSingleRegionChangedIndexesOldText:(NSString *)oldText
                                         newText:(NSString *)newText
                                          offset:(NSInteger)offset
                                    intoIndexSet:(NSMutableIndexSet *)insertedInNew {
    NSInteger n = oldText.length;
    NSInteger m = newText.length;
    if (m == 0) return;
    if (n == 0 || n + m > kVoiceDiffMaxTotalLen) {
        [insertedInNew addIndexesInRange:NSMakeRange(offset, m)];
        return;
    }
    unichar *a = (unichar *)malloc(sizeof(unichar) * n);
    unichar *b = (unichar *)malloc(sizeof(unichar) * m);
    if (!a || !b) {
        // 分配失败:和上面 n+m 超阈值的降级分支一样,整段直接标记为高亮。
        free(a);
        free(b);
        [insertedInNew addIndexesInRange:NSMakeRange(offset, m)];
        return;
    }
    [oldText getCharacters:a range:NSMakeRange(0, n)];
    [newText getCharacters:b range:NSMakeRange(0, m)];
    [self wk_addMyersInsertedIndexesFromOldChars:a length:n newChars:b length:m offset:offset intoIndexSet:insertedInNew];
    free(a);
    free(b);
}

// 行级 Myers:只用来找出 oldLines/newLines 之间"逐行完全相同、且顺序对应"的锚点行,不看
// 行内字符差异,返回值按 newIdx 升序排列。锚点之间的行段落交给调用方(见上面
// wk_addChangedIndexesForOldCore:newCore:offset:intoIndexSet:)按需再跑字符级 diff。
- (NSArray<NSValue *> *)wk_lineMatchAnchorsForOldLines:(NSArray<NSString *> *)oldLines
                                               newLines:(NSArray<NSString *> *)newLines {
    NSInteger n = oldLines.count;
    NSInteger m = newLines.count;
    NSInteger maxD = n + m;
    NSInteger size = 2 * maxD + 1;
    int32_t *v = (int32_t *)calloc(size, sizeof(int32_t));
    int32_t *trace = (int32_t *)malloc((maxD + 1) * size * sizeof(int32_t));
    if (!v || !trace) {
        // 分配失败:不返回任何锚点,调用方会把整篇当成一个"待比较的尾段"
        // 走字符级 diff(和上面 n+m 超阈值时不切行、直接整段比较是同一种降级路径)。
        free(v);
        free(trace);
        return @[];
    }
    NSInteger foundD = -1;

    for (NSInteger d = 0; d <= maxD; d++) {
        memcpy(trace + d * size, v, size * sizeof(int32_t));
        for (NSInteger k = -d; k <= d; k += 2) {
            NSInteger x;
            if (k == -d || (k != d && v[k - 1 + maxD] < v[k + 1 + maxD])) {
                x = v[k + 1 + maxD];
            } else {
                x = v[k - 1 + maxD] + 1;
            }
            NSInteger y = x - k;
            while (x < n && y < m && [oldLines[x] isEqualToString:newLines[y]]) {
                x++;
                y++;
            }
            v[k + maxD] = (int32_t)x;
            if (x >= n && y >= m) {
                foundD = d;
                break;
            }
        }
        if (foundD >= 0) break;
    }

    NSMutableArray<NSValue *> *anchorsReversed = [NSMutableArray array];
    if (foundD >= 0) {
        NSInteger x = n, y = m;
        for (NSInteger d = foundD; d > 0; d--) {
            int32_t *vv = trace + d * size;
            NSInteger k = x - y;
            NSInteger prevK;
            if (k == -d || (k != d && vv[k - 1 + maxD] < vv[k + 1 + maxD])) {
                prevK = k + 1;
            } else {
                prevK = k - 1;
            }
            NSInteger prevX = vv[prevK + maxD];
            NSInteger prevY = prevX - prevK;
            while (x > prevX && y > prevY) {
                x--;
                y--;
                WKLineMatchAnchor anchor = {x, y};
                [anchorsReversed addObject:[NSValue valueWithBytes:&anchor objCType:@encode(WKLineMatchAnchor)]];
            }
            x = prevX;
            y = prevY;
        }
    }

    free(v);
    free(trace);

    return [[anchorsReversed reverseObjectEnumerator] allObjects];
}

// 对某个已经确定范围的文本片段跑 Myers 最短编辑脚本,插入型下标按 offset 换算回原始
// newText 坐标系,写进 insertedInNew。offset 由调用方决定(可能是全局前后缀裁剪后的核心区
// 起点,也可能是行级锚点之间某一段在 newText 里的起点)。
- (void)wk_addMyersInsertedIndexesFromOldChars:(const unichar *)a length:(NSInteger)n
                                      newChars:(const unichar *)b length:(NSInteger)m
                                         offset:(NSInteger)offset
                                   intoIndexSet:(NSMutableIndexSet *)insertedInNew {
    NSInteger maxD = n + m;
    NSInteger size = 2 * maxD + 1;
    int32_t *v = (int32_t *)calloc(size, sizeof(int32_t));
    int32_t *trace = (int32_t *)malloc((maxD + 1) * size * sizeof(int32_t));
    if (!v || !trace) {
        // 分配失败:退化为"这一段全算插入",和上面 n==0/超阈值的降级分支保持同一种兜底方式。
        free(v);
        free(trace);
        [insertedInNew addIndexesInRange:NSMakeRange(offset, m)];
        return;
    }
    NSInteger foundD = -1;

    for (NSInteger d = 0; d <= maxD; d++) {
        memcpy(trace + d * size, v, size * sizeof(int32_t));
        for (NSInteger k = -d; k <= d; k += 2) {
            NSInteger x;
            if (k == -d || (k != d && v[k - 1 + maxD] < v[k + 1 + maxD])) {
                x = v[k + 1 + maxD];
            } else {
                x = v[k - 1 + maxD] + 1;
            }
            NSInteger y = x - k;
            while (x < n && y < m && a[x] == b[y]) {
                x++;
                y++;
            }
            v[k + maxD] = (int32_t)x;
            if (x >= n && y >= m) {
                foundD = d;
                break;
            }
        }
        if (foundD >= 0) break;
    }

    if (foundD >= 0) {
        NSInteger x = n, y = m;
        for (NSInteger d = foundD; d > 0; d--) {
            int32_t *vv = trace + d * size;
            NSInteger k = x - y;
            NSInteger prevK;
            if (k == -d || (k != d && vv[k - 1 + maxD] < vv[k + 1 + maxD])) {
                prevK = k + 1;
            } else {
                prevK = k - 1;
            }
            NSInteger prevX = vv[prevK + maxD];
            NSInteger prevY = prevX - prevK;
            while (x > prevX && y > prevY) {
                x--;
                y--;
            }
            if (x == prevX) {
                // 竖直移动:这一步在核心区里插入/替换进了下标为 y-1 的字符,换算回原始坐标系
                [insertedInNew addIndex:offset + y - 1];
            }
            // 否则是水平移动,即从核心区旧文本里删掉一个字符,不影响 newText 的高亮范围
            x = prevX;
            y = prevY;
        }
    } else {
        // 理论上 d 最多推进到 maxD 必定能收敛,这里只是兜底,不应该真正走到
        [insertedInNew addIndexesInRange:NSMakeRange(offset, m)];
    }

    free(v);
    free(trace);
}

- (UIColor *)wk_voiceEditHighlightColor {
    UIColor *themeColor = [WKApp shared].config.themeColor ?: [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0];
    return [themeColor colorWithAlphaComponent:0.18];
}

// self.textView.font/textColor 正常情况下 viewDidLoad 就赋过值,理论可空但不会实际发生;
// 字典字面量对 nil value 会直接抛异常,这里统一兜底一份默认值,成本很低。
- (NSDictionary *)wk_baseTextAttributes {
    UIFont *font = self.textView.font ?: [UIFont systemFontOfSize:14];
    UIColor *color = self.textView.textColor ?: [UIColor labelColor];
    return @{NSFontAttributeName: font, NSForegroundColorAttributeName: color};
}

- (NSAttributedString *)attributedTextForDocument:(NSString *)text highlightDiffFrom:(NSString *)previousText {
    NSDictionary *baseAttrs = [self wk_baseTextAttributes];
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:text ?: @"" attributes:baseAttrs];
    NSArray<NSValue *> *changedRanges = [self wk_changedRangesInNewText:text ?: @"" comparedToOldText:previousText ?: @""];
    if (changedRanges.count > 0) {
        UIColor *highlightColor = [self wk_voiceEditHighlightColor];
        for (NSValue *rangeValue in changedRanges) {
            [attr addAttribute:NSBackgroundColorAttributeName value:highlightColor range:rangeValue.rangeValue];
        }
    }
    return attr;
}

// 语音编辑留下的高亮要一直保留到用户点保存(onSave)才清除,不随其他操作提前消失。
- (void)clearVoiceEditHighlight {
    NSString *text = self.textView.text;
    self.textView.attributedText = [[NSAttributedString alloc] initWithString:text ?: @""
                                                                     attributes:[self wk_baseTextAttributes]];
}

@end
