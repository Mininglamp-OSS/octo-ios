//
//  WKInteractiveCardCell.m
//  WuKongBase
//

#import "WKInteractiveCardCell.h"
#import "WKInteractiveCardContent.h"
#import "WKACardRenderer.h"
#import "WKCardActionAPI.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import "WKWebViewVC.h"
#import "WKNavigationManager.h"
#import <WuKongBase/WuKongBase-Swift.h>
#import <AdaptiveCards/ACRView.h>
#import <AdaptiveCards/ACRActionDelegate.h>
#import <AdaptiveCards/ACOBaseActionElement.h>
#import <AdaptiveCards/ACOAdaptiveCard.h>
#import <AdaptiveCards/ACOEnums.h>

// WKMessageListView 的高度缓存失效 helper（实现在 WKMessageListView.m），
// 供 async reflow 复用既有机制而无需暴露完整头。
@interface NSObject (WKCardListHeightInvalidate)
- (void)wk_invalidateHeightCacheForMessage:(WKMessageModel *)msg;
@end

// 卡片正文与宿主的内边距（卡片自身还有 host config 的 padding）
#define WKCardHostInset 0.0f
#define WKCardFallbackFont [UIFont systemFontOfSize:15.0f]
#define WKCardSubmitTimeout 10.0  // 提交后等待 bot 回写帧的超时（秒），对齐 web SUBMIT_TIMEOUT_MS

@interface WKInteractiveCardCell () <ACRActionDelegate>
@property(nonatomic,strong) UIView *cardHostView;        // 承载 ACRView 的容器
@property(nonatomic,strong) ACRView *acrView;            // 当前卡片视图
@property(nonatomic,strong) UILabel *plainFallbackLabel; // 降级纯文本
@property(nonatomic,copy)   NSString *renderedFingerprint; // 已渲染指纹（去重，防重复 remount）
@property(nonatomic,assign) BOOL renderedDark;             // 已渲染的主题
@property(nonatomic,copy)   NSString *renderedClientMsgNo; // 已渲染帧所属消息
@property(nonatomic,assign) NSInteger renderedCardSeq;     // 已渲染帧的 card_seq（乱序丢弃用）
// —— 交互档（octo/v2）提交态 ——
@property(nonatomic,strong) UIView *loadingOverlay;        // 提交 loading 遮罩
@property(nonatomic,assign) BOOL submitInFlight;           // 提交进行中
@property(nonatomic,copy)   NSString *submitFingerprint;   // 提交时的帧指纹（用于识别 bot 回写帧到达）
@property(nonatomic,strong) NSTimer *submitTimeoutTimer;   // 10s 超时
@property(nonatomic,assign) BOOL pendingLiveHeightSync;    // 滚动中跳过的实测重排，滚动停下补做
@end

@implementation WKInteractiveCardCell

#pragma mark - 有效帧解析（复刻 web resolveEffectiveCardContent）

/// 取有效卡片正文：优先编辑帧 remoteExtra.contentEdit（仅当它是合法卡片），否则原始 content。
+ (WKInteractiveCardContent *)effectiveContent:(WKMessageModel *)model {
    id edit = model.remoteExtra.contentEdit;
    if ([edit isKindOfClass:[WKInteractiveCardContent class]]) {
        WKInteractiveCardContent *editContent = (WKInteractiveCardContent *)edit;
        if (editContent.card) {
            return editContent;
        }
    }
    if ([model.content isKindOfClass:[WKInteractiveCardContent class]]) {
        return (WKInteractiveCardContent *)model.content;
    }
    return nil;
}

#pragma mark - 信任门 / 渲染决策（复刻 web senderTrust + decideCardBody）

/// 灰度开关（镜像服务端 OCTO_CARD_MESSAGE_ENABLED）。默认开启；可用 NSUserDefaults
/// 或启动参数 -OCTO_CARD_MESSAGE_ENABLED 0 一键关闭 → type17 全部降级 plain。
+ (BOOL)cardFeatureEnabled {
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:@"OCTO_CARD_MESSAGE_ENABLED"];
    if (v == nil) {
        return YES; // 默认开启（服务端已在投递侧控制）
    }
    return [v boolValue];
}

/// 发送者是否可信（bot 或 webhook）——源自服务端权威 fromUID。
/// bot：channelInfo.robot=1；webhook：channelInfo.category=="webhook"（web 端 webhook 卡片可信但只读）。
+ (BOOL)isTrustedSender:(WKMessageModel *)model {
    if (model.memberOfFrom.robot) {
        return YES;
    }
    if (model.from) {
        if (model.from.robot) {
            return YES;
        }
        if ([model.from.category isEqualToString:@"webhook"]) {
            return YES;
        }
    }
    return NO;
}

/// 是否应作为卡片渲染：可信发送者 + profile/version 支持 + 有合法 card。否则降级 plain。
+ (BOOL)shouldRenderCardForModel:(WKMessageModel *)model {
    if (![self cardFeatureEnabled]) {
        return NO; // 灰度关闭 → 全部降级 plain
    }
    WKInteractiveCardContent *content = [self effectiveContent:model];
    if (!content || !content.card) {
        return NO;
    }
    if (![self isTrustedSender:model]) {
        return NO;
    }
    if (![content isProfileSupported]) {
        return NO;
    }
    return YES;
}

/// 卡片渲染宽度（气泡正文最大宽度）。
+ (CGFloat)cardWidthForModel:(WKMessageModel *)model {
    CGFloat w = [WKApp shared].config.messageContentMaxWidth;
    if (w <= 0) {
        w = WKScreenWidth * 0.72f;
    }
    return floor(w);
}

+ (BOOL)isDarkStyle {
    return [WKApp shared].config.style == WKSystemStyleDark;
}

#pragma mark - Live 高度覆盖（交互后 ACRView 实际高度 ≠ 新渲染的初始高度）

// ToggleVisibility(展开/收起)、异步图片加载会改变**当前活着的 ACRView** 的高度，
// 而 measureCard 每次都新渲染一个初始(收起)态视图。故用一张 clientMsgNo|fingerprint →
// 实测高度 的覆盖表：cell 交互后写入实测高度，+contentSizeForMessage 优先读它。
+ (NSMutableDictionary<NSString *, NSNumber *> *)liveHeightOverride {
    static NSMutableDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ map = [NSMutableDictionary dictionary]; });
    return map;
}

+ (NSString *)liveHeightKeyForClientMsgNo:(NSString *)clientMsgNo fingerprint:(NSString *)fp {
    return [NSString stringWithFormat:@"%@|%@", clientMsgNo ?: @"", fp ?: @""];
}

#pragma mark - 尺寸

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    CGFloat width = [self cardWidthForModel:model];
    WKInteractiveCardContent *content = [self effectiveContent:model];

    if ([self shouldRenderCardForModel:model]) {
        NSString *fp = [content renderFingerprint];
        // 优先用交互后的实测高度覆盖（展开/收起、异步图片）
        NSNumber *override = [[self liveHeightOverride] objectForKey:[self liveHeightKeyForClientMsgNo:model.clientMsgNo fingerprint:fp]];
        if (override) {
            return CGSizeMake(width, MAX(1, override.doubleValue));
        }
        CGSize size = [WKACardRenderer measureCard:content.card
                                             width:width
                                              dark:[self isDarkStyle]
                                       fingerprint:fp];
        CGFloat h = size.height;
        if (h < 1) {
            h = 1; // 兜底，避免 0 高
        }
        return CGSizeMake(width, h);
    }

    // 降级：纯文本高度
    NSString *plain = content.plain ?: LLang(@"[卡片]");
    CGRect rect = [plain boundingRectWithSize:CGSizeMake(MAX(1, width - 8.0f), CGFLOAT_MAX)
                                      options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                   attributes:@{NSFontAttributeName: WKCardFallbackFont}
                                      context:nil];
    return CGSizeMake(width, ceil(rect.size.height) + 8.0f);
}

#pragma mark - UI

+ (BOOL)hiddenBubble {
    // 卡片自带容器背景（host config containerStyle），不叠加 App 气泡背景。
    return YES;
}

- (void)initUI {
    [super initUI];

    // 打通触摸链：气泡背景(UIImageView 默认不可交互)会挡住卡片内控件的原生触摸。
    // 放开后，文本/日期/时间输入框、开关、按钮都走 ACR 原生交互（文本框由自身
    // UITextInteraction 启动编辑，可靠弹键盘 + 光标定位）。单选列表原生不触发，
    // 由 onTap 兜底手动 didSelectRow。
    self.bubbleBackgroundView.userInteractionEnabled = YES;

    self.cardHostView = [[UIView alloc] initWithFrame:CGRectZero];
    self.cardHostView.backgroundColor = [UIColor clearColor];
    self.cardHostView.userInteractionEnabled = YES;
    self.cardHostView.layer.cornerRadius = 8.0f;
    self.cardHostView.layer.masksToBounds = YES;
    [self.messageContentView addSubview:self.cardHostView];

    self.plainFallbackLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.plainFallbackLabel.numberOfLines = 0;
    self.plainFallbackLabel.font = WKCardFallbackFont;
    self.plainFallbackLabel.hidden = YES;
    [self.messageContentView addSubview:self.plainFallbackLabel];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];

    WKInteractiveCardContent *content = [WKInteractiveCardCell effectiveContent:model];
    BOOL dark = [WKInteractiveCardCell isDarkStyle];

    if (![WKInteractiveCardCell shouldRenderCardForModel:model]) {
        [self showFallbackWithText:(content.plain ?: LLang(@"[卡片]")) dark:dark];
        return;
    }

    // 乱序丢弃（复刻服务端 D9 CAS 语义）：同一消息、更旧的 card_seq 不覆盖已渲染帧。
    BOOL sameMessage = [self.renderedClientMsgNo isEqualToString:model.clientMsgNo];
    if (sameMessage && self.acrView && content.cardSeq >= 0 &&
        self.renderedCardSeq >= 0 && content.cardSeq < self.renderedCardSeq) {
        self.plainFallbackLabel.hidden = YES;
        self.cardHostView.hidden = NO;
        return;
    }

    NSString *fp = [content renderFingerprint];
    // 指纹去重（复刻 web syncSdkCard）：同消息 + 内容 + 主题都未变 → 不 remount，保留状态。
    if (sameMessage && self.acrView && [fp isEqualToString:self.renderedFingerprint] && self.renderedDark == dark) {
        self.plainFallbackLabel.hidden = YES;
        self.cardHostView.hidden = NO;
        return;
    }

    CGFloat width = [WKInteractiveCardCell cardWidthForModel:model];
    WKACardRenderResult *result = [WKACardRenderer renderCard:content.card
                                                        width:width
                                                         dark:dark
                                                     delegate:self];
    if (!result.succeeded || !result.view) {
        [self showFallbackWithText:(content.plain ?: LLang(@"[卡片]")) dark:dark];
        return;
    }

    // 提交进行中且回来的是**不同**帧 → 视为 bot 回写帧到达，解除 loading。
    if (self.submitInFlight && self.submitFingerprint && ![fp isEqualToString:self.submitFingerprint]) {
        [self endSubmitLoading];
    }

    // 换上新卡片视图
    [self.acrView removeFromSuperview];
    self.acrView = result.view;
    self.acrView.userInteractionEnabled = YES;
    [self.cardHostView addSubview:self.acrView];

    self.renderedFingerprint = fp;
    self.renderedDark = dark;
    self.renderedClientMsgNo = model.clientMsgNo;
    self.renderedCardSeq = content.cardSeq;
    // 新渲染的是初始(收起)态视图 → 清掉旧的实测高度覆盖，让行高回到 measureCard 初值，
    // 后续交互/异步布局再由 syncLiveHeightAndReflow 重新写入。
    [[WKInteractiveCardCell liveHeightOverride] removeObjectForKey:
        [WKInteractiveCardCell liveHeightKeyForClientMsgNo:model.clientMsgNo fingerprint:fp]];

    self.plainFallbackLabel.hidden = YES;
    self.cardHostView.hidden = NO;

    [self setNeedsLayout];

    // 异步安全网：ACRView 图片/异步布局落定后高度可能变化，做一次实测高度校准。
    [self scheduleLiveHeightSync];
}

- (void)showFallbackWithText:(NSString *)text dark:(BOOL)dark {
    [self.acrView removeFromSuperview];
    self.acrView = nil;
    self.renderedFingerprint = nil;
    self.renderedClientMsgNo = nil;
    self.renderedCardSeq = -1;

    self.cardHostView.hidden = YES;
    self.plainFallbackLabel.hidden = NO;
    self.plainFallbackLabel.text = text;
    self.plainFallbackLabel.textColor = [WKApp shared].config.messageRecvTextColor;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = self.messageContentView.lim_width;
    CGFloat h = self.messageContentView.lim_height;

    self.cardHostView.frame = CGRectMake(WKCardHostInset, WKCardHostInset,
                                         MAX(0, w - 2 * WKCardHostInset),
                                         MAX(0, h - 2 * WKCardHostInset));
    self.acrView.frame = self.cardHostView.bounds;

    if (self.loadingOverlay.superview) {
        self.loadingOverlay.frame = self.cardHostView.bounds;
        UIView *spinner = [self.loadingOverlay viewWithTag:9901];
        spinner.center = CGPointMake(self.loadingOverlay.bounds.size.width / 2.0,
                                     self.loadingOverlay.bounds.size.height / 2.0);
    }

    self.plainFallbackLabel.frame = CGRectMake(4.0f, 4.0f, MAX(0, w - 8.0f), MAX(0, h - 8.0f));

    // 布局后校准：ACR 交互(展开/收起)/异步图片会改变内容实测高度。若实测高度与
    // 覆盖表记录不一致，异步触发一次 reflow（override 门控，收敛后不再重复）。
    [self checkLiveHeightMismatchAndReflow];
}

/// 比较 ACR 实测高度与覆盖表记录；不一致则异步 syncLiveHeightAndReflow。以 override
/// 为收敛判据（而非行高），避免行高被外部约束时反复 reload。
- (void)checkLiveHeightMismatchAndReflow {
    if (!self.acrView || self.renderedFingerprint.length == 0 || self.renderedClientMsgNo.length == 0) return;
    NSString *key = [WKInteractiveCardCell liveHeightKeyForClientMsgNo:self.renderedClientMsgNo
                                                          fingerprint:self.renderedFingerprint];
    // 已有覆盖值 → 初值已定；后续展开/选择/异步的变化由 tap burst / scheduleLiveHeightSync 处理，
    // 这里不再每次 layoutSubviews 都测量，避免滚动时反复计算。
    if ([[WKInteractiveCardCell liveHeightOverride] objectForKey:key]) return;
    // [perf] 滚动中不测量(measureLiveACRHeightAtWidth 的 10万-layout 很贵)；标记待办，滚动停下补做。
    UITableView *tv = [self wk_enclosingTableView];
    if (tv && (tv.isDragging || tv.isDecelerating)) {
        self.pendingLiveHeightSync = YES;
        return;
    }
    CGFloat width = self.cardHostView.lim_width;
    if (width <= 0) return;
    CGFloat fitH = [self measureLiveACRHeightAtWidth:width];
    if (fitH < 1) return;
    if (fabs(fitH - self.cardHostView.lim_height) <= 1.0) return; // 行高已对
    __weak WKInteractiveCardCell *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf syncLiveHeightAndReflow]; });
}

- (void)prepareForReuse {
    [super prepareForReuse];
    // 复用时不主动销毁 acrView；refresh: 会按指纹决定是否 remount。
    // 但清掉 fallback 文本避免闪现旧内容，并结束任何进行中的提交 loading。
    self.plainFallbackLabel.text = nil;
    [self endSubmitLoading];
}

#pragma mark - 交互：BotFather 模式，手势路由 → 手动派发到卡片按钮/单选行

// 卡片内的 UIControl(按钮)与 ACRInputTableView(单选/复选)在这个手势繁重、
// 且气泡背景不可交互的 cell 里，原生触摸不可靠。故统一走消息手势识别器的单击回调，
// 直接对 acrView 子树做 hitTest，命中后手动触发按钮 TouchUpInside / 表格 didSelectRow。
- (BOOL)respondContentSingleTap {
    return YES;
}

/// 点是否落在卡片(acrView)区域内（contentView 坐标系）。
- (BOOL)isPointInCard:(CGPoint)pointInContentView {
    if (!self.acrView || self.acrView.hidden) return NO;
    CGPoint p = [self.acrView convertPoint:pointInContentView fromView:self.contentView];
    return CGRectContainsPoint(self.acrView.bounds, p);
}

/// 对 acrView 子树 hitTest（不受祖先 userInteractionEnabled 影响）。
- (UIView *)hitViewInCardAtContentPoint:(CGPoint)pointInContentView {
    if (![self isPointInCard:pointInContentView]) return nil;
    CGPoint p = [self.acrView convertPoint:pointInContentView fromView:self.contentView];
    return [self.acrView hitTest:p withEvent:nil];
}

// 手势路由：命中单选列表(UITableView) → WaitForSingleTap，让 onTap 兜底手动 didSelectRow；
// 其余(文本输入框/按钮/开关等) → Fail，把整段手势让给 ACR 原生控件——这样文本框的
// 光标定位、长按放大镜、双击选词、按钮点击都由原生手势处理，不被消息手势抢占。
- (WKTapLongTapOrDoubleTapGestureRecognizerEvent *)tapActionAtPoint:(CGPoint)point {
    if ([self isPointInCard:point]) {
        UIView *v = [self hitViewInCardAtContentPoint:point];
        while (v && v != self.acrView.superview) {
            if ([v isKindOfClass:[UITableView class]]) {
                return [WKTapLongTapOrDoubleTapGestureRecognizerEvent action:WKTapLongTapOrDoubleTapGestureRecognizerActionWaitForSingleTap];
            }
            v = v.superview;
        }
        // 按钮(展开/收起推理 ToggleVisibility、Submit 等)交给原生处理；同时调度高度实测 burst，
        // 追随 ToggleVisibility 引起的高度变化（ACR 不回调 delegate，需主动多打几拍实测）。
        // 若命中的是正在编辑的输入框，burst 里的 syncLiveHeightAndReflow 会被编辑守卫挡住，无害。
        [self scheduleLiveHeightSyncBurst];
        return [WKTapLongTapOrDoubleTapGestureRecognizerEvent action:WKTapLongTapOrDoubleTapGestureRecognizerActionFail];
    }
    return [super tapActionAtPoint:point];
}

// 触摸链已打通，按钮/文本/日期/时间/开关都由 ACR 原生控件处理。唯一原生不触发的是
// Input.ChoiceSet 的嵌套 UITableView 行选择——这里兜底手动 didSelectRow。
- (void)onTapWithGestureRecognizer:(TapLongTapOrDoubleTapGestureRecognizerWrap *)gesture {
    UIView *hit = [self hitViewInCardAtContentPoint:gesture.tapPoint];
    if (hit) {
        UITableViewCell *cell = nil;
        UITableView *table = nil;
        UIView *v = hit;
        while (v && v != self.acrView.superview) {
            if (!cell && [v isKindOfClass:[UITableViewCell class]]) cell = (UITableViewCell *)v;
            if ([v isKindOfClass:[UITableView class]]) { table = (UITableView *)v; break; }
            v = v.superview;
        }
        if (cell && table) {
            NSIndexPath *ip = [table indexPathForCell:cell];
            if (ip && [table.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
                [table selectRowAtIndexPath:ip animated:NO scrollPosition:UITableViewScrollPositionNone];
                [table.delegate tableView:table didSelectRowAtIndexPath:ip];
                [self scheduleLiveHeightSyncBurst];
                return;
            }
        }
    }
    [super onTapWithGestureRecognizer:gesture];
}

#pragma mark - 卡片输入框焦点辅助

- (UIView *)wk_firstResponderTextInputInView:(UIView *)view {
    if (!view) return nil;
    if (([view isKindOfClass:[UITextField class]] || [view isKindOfClass:[UITextView class]]) && view.isFirstResponder) {
        return view;
    }
    for (UIView *sub in view.subviews) {
        UIView *r = [self wk_firstResponderTextInputInView:sub];
        if (r) return r;
    }
    return nil;
}

- (BOOL)wk_hasFocusedCardInput {
    return [self wk_firstResponderTextInputInView:self.acrView] != nil;
}

// 卡片内不触发长按上下文菜单（让位给卡片交互）。
- (BOOL)shouldBeginContextGestureAtPoint:(CGPoint)point {
    if ([self isPointInCard:point]) return NO;
    return [super shouldBeginContextGestureAtPoint:point];
}

#pragma mark - ACRActionDelegate（octo/v2 交互档）

- (void)didFetchUserResponses:(ACOAdaptiveCard *)card action:(ACOBaseActionElement *)action {
    if (!action) return;
    switch (action.type) {
        case ACRSubmit:
            [self handleSubmitAction:action card:card];
            break;
        case ACROpenUrl:
            [self handleOpenUrlAction:action];
            break;
        default:
            // ACRToggleVisibility 由 ACR 内部处理；ACRShowCard/ACRExecute 不在 octo 白名单。
            break;
    }
}

// ACRView 异步布局变化(图片加载/ToggleVisibility 展开收起) → 校准实测高度并重排。
- (void)didChangeViewLayout:(CGRect)oldFrame newFrame:(CGRect)newFrame {
    [self syncLiveHeightAndReflow];
}

// ToggleVisibility 切换可见性 → 同样校准高度(等 ACR 完成内部布局后一拍)。
- (void)didChangeVisibility:(UIButton *)button isVisible:(BOOL)isVisible {
    __weak WKInteractiveCardCell *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf syncLiveHeightAndReflow]; });
}

- (void)handleSubmitAction:(ACOBaseActionElement *)action card:(ACOAdaptiveCard *)card {
    WKMessageModel *model = self.messageModel;
    if (!model) return;

    // 收集输入值（{inputId: value}）——服务端会重算/校验；不传 data。
    NSDictionary *inputs = @{};
    NSData *inputsData = [card inputs];
    if (inputsData.length > 0) {
        id obj = [NSJSONSerialization JSONObjectWithData:inputsData options:0 error:nil];
        if ([obj isKindOfClass:[NSDictionary class]]) {
            inputs = obj;
        }
    }

    NSString *messageId = [NSString stringWithFormat:@"%llu", model.messageId];
    NSString *channelId = model.channel.channelId ?: @"";
    uint8_t channelType = model.channel.channelType;
    NSString *actionId = [action elementId] ?: @"";
    NSString *clientToken = [[NSUUID UUID] UUIDString];

    [self beginSubmitLoading];

    __weak WKInteractiveCardCell *weakSelf = self;
    [WKCardActionAPI submitCardAction:actionId
                            messageId:messageId
                            channelId:channelId
                          channelType:channelType
                               inputs:inputs
                          clientToken:clientToken]
    .then(^(id resp){
        // 成功（accepted / replay）——保持 loading，等 bot 回写帧经 extra-sync 到达再解除。
        // 若卡片无后续改写，10s 超时兜底解除。
    })
    .catch(^(NSError *err){
        // 409 InProgress / 400 Invalid / 403 Denied 等：解除 loading 并提示。
        WKInteractiveCardCell *strongSelf = weakSelf;
        [strongSelf endSubmitLoading];
        [strongSelf showMsg:LLang(@"操作失败，请重试")];
    });
}

- (void)handleOpenUrlAction:(ACOBaseActionElement *)action {
    NSString *urlStr = [action url];
    if (urlStr.length == 0) return;
    if (![urlStr hasPrefix:@"http"]) {
        urlStr = [NSString stringWithFormat:@"http://%@", urlStr];
    }
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) return;
    // 统一走 app 内部 WebView(与消息里点链接一致)，不跳外部 Safari。
    WKWebViewVC *vc = [[WKWebViewVC alloc] init];
    vc.url = url;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

#pragma mark - 提交 loading 态

- (void)beginSubmitLoading {
    self.submitInFlight = YES;
    self.submitFingerprint = self.renderedFingerprint;

    if (!self.loadingOverlay) {
        UIView *overlay = [[UIView alloc] initWithFrame:CGRectZero];
        overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.08];
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        spinner.tag = 9901;
        [spinner startAnimating];
        [overlay addSubview:spinner];
        self.loadingOverlay = overlay;
    }
    self.loadingOverlay.frame = self.cardHostView.bounds;
    UIView *spinner = [self.loadingOverlay viewWithTag:9901];
    spinner.center = CGPointMake(self.loadingOverlay.bounds.size.width / 2.0,
                                 self.loadingOverlay.bounds.size.height / 2.0);
    [self.cardHostView addSubview:self.loadingOverlay];

    [self.submitTimeoutTimer invalidate];
    self.submitTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:WKCardSubmitTimeout
                                                               target:self
                                                             selector:@selector(onSubmitTimeout)
                                                             userInfo:nil
                                                              repeats:NO];
}

- (void)onSubmitTimeout {
    if (!self.submitInFlight) return;
    [self endSubmitLoading];
    [self showMsg:LLang(@"操作超时，请重试")];
}

- (void)endSubmitLoading {
    self.submitInFlight = NO;
    self.submitFingerprint = nil;
    [self.submitTimeoutTimer invalidate];
    self.submitTimeoutTimer = nil;
    [self.loadingOverlay removeFromSuperview];
}

#pragma mark - 实测高度校准（异步图片 / ToggleVisibility 展开收起 / 选择）

/// 测量当前活着 ACRView 的真实内容高度：Auto Layout 拟合高度 与 子视图并集底部 取大者。
/// 交互后 ACR 会把新内容布局到 clamp 的 frame 之外，systemLayout 可能低估，故并集兜底。
- (CGFloat)measureLiveACRHeightAtWidth:(CGFloat)width {
    if (!self.acrView || width <= 0) return 0;
    // 临时把 frame 放大到足够高度再布局，让 ACR 把(可能新展开的)内容完整排开，
    // 取"拟合高度"与"子视图并集底部"的较大者；测完还原 frame，交回 layoutSubviews 重新 clamp。
    // 同步执行、无 runloop tick，不会有可见跳动。
    CGRect saved = self.acrView.frame;
    self.acrView.frame = CGRectMake(saved.origin.x, saved.origin.y, width, 100000);
    [self.acrView setNeedsLayout];
    [self.acrView layoutIfNeeded];

    CGSize fit = [self.acrView systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                             withHorizontalFittingPriority:UILayoutPriorityRequired
                                   verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGFloat h = ceil(fit.height);
    CGFloat unionBottom = 0;
    for (UIView *sub in self.acrView.subviews) {
        if (sub.hidden) continue;
        unionBottom = MAX(unionBottom, CGRectGetMaxY(sub.frame));
    }
    h = MAX(h, ceil(unionBottom));

    self.acrView.frame = saved;
    return h;
}

- (void)scheduleLiveHeightSync {
    __weak WKInteractiveCardCell *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf syncLiveHeightAndReflow]; });
}

/// 交互(展开/收起/选择)后多打几拍校准，覆盖 ACR 无 delegate 回调、cell 不 layoutSubviews 的情况。
- (void)scheduleLiveHeightSyncBurst {
    __weak WKInteractiveCardCell *weakSelf = self;
    for (NSNumber *delay in @[@0.05, @0.20, @0.45]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [weakSelf syncLiveHeightAndReflow]; });
    }
}

/// 测量实测高度；若与覆盖表记录不同，则写入覆盖、失效行高缓存并重排。
/// 这是 ToggleVisibility 展开/选择后行高能跟随、内容不被裁剪的关键。
- (void)syncLiveHeightAndReflow {
    if (!self.acrView || self.renderedFingerprint.length == 0 || self.renderedClientMsgNo.length == 0) return;
    // 用户正在卡片输入框里编辑时跳过实测/重排：measureLiveACRHeightAtWidth 会临时把 acrView
    // 尺寸改成超大再 layout、reflow 又走 begin/endUpdates，都会扰动正在编辑的输入框，导致
    // 每次打字光标就消失。编辑期间卡片高度稳定、无需重排；结束编辑后由其它路径再校准。
    if ([self wk_hasFocusedCardInput]) return;
    // [perf] 列表正在滚动时跳过实测重排：measureLiveACRHeightAtWidth 的 10万-layout +
    // begin/endUpdates 在快滑+大量卡片时会把 60fps 打到 30。标记待办，滚动停下后补做一次。
    // 卡片此刻仍按 measureCard/override 的正确高度显示，视觉无回退。
    UITableView *tv = [self wk_enclosingTableView];
    if (tv && (tv.isDragging || tv.isDecelerating)) {
        self.pendingLiveHeightSync = YES;
        return;
    }
    CGFloat width = self.cardHostView.lim_width;
    if (width <= 0) return;

    CGFloat liveH = [self measureLiveACRHeightAtWidth:width];
    if (liveH < 1) return;

    NSString *key = [WKInteractiveCardCell liveHeightKeyForClientMsgNo:self.renderedClientMsgNo
                                                          fingerprint:self.renderedFingerprint];
    NSNumber *cur = [[WKInteractiveCardCell liveHeightOverride] objectForKey:key];
    if (cur && fabs(cur.doubleValue - liveH) <= 1.0) { self.pendingLiveHeightSync = NO; return; } // 高度未变

    self.pendingLiveHeightSync = NO;
    [[WKInteractiveCardCell liveHeightOverride] setObject:@(liveH) forKey:key];
    [self reflowHeightUsingListInvalidate];
}

/// 滚动停下后由列表调用：补做一次被滚动跳过的实测重排。
- (void)wk_calibrateLiveHeightIfPending {
    if (!self.pendingLiveHeightSync) return;
    self.pendingLiveHeightSync = NO;
    [self syncLiveHeightAndReflow];
}

- (UITableView *)wk_enclosingTableView {
    UIView *v = self.superview;
    while (v && ![v isKindOfClass:[UITableView class]]) v = v.superview;
    return (UITableView *)v;
}

/// 失效上层行高缓存 + begin/endUpdates 重新测高。keepPosition/ajustTableViewByStreams
/// 负责保持滚动位置，上方增高由既有 offset 补偿逻辑吸收。
- (void)reflowHeightUsingListInvalidate {
    UIView *hostView = self.superview;
    while (hostView && ![hostView isKindOfClass:[UITableView class]]) hostView = hostView.superview;
    if (![hostView isKindOfClass:[UITableView class]]) return;
    UITableView *tv = (UITableView *)hostView;

    UIView *listView = tv.superview;
    while (listView && ![NSStringFromClass([listView class]) isEqualToString:@"WKMessageListView"]) {
        listView = listView.superview;
    }
    if (listView && [listView respondsToSelector:@selector(wk_invalidateHeightCacheForMessage:)] && self.messageModel) {
        [listView wk_invalidateHeightCacheForMessage:self.messageModel];
    }
    @try {
        [tv beginUpdates];
        [tv endUpdates];
    } @catch (NSException *ex) {
        // 行数漂移等异常安全吞掉（沿用本仓库对 UITableView batch 的防御姿态）
    }
}

@end
