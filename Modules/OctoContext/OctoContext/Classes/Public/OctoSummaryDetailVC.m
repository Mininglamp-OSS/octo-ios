//
//  OctoSummaryDetailVC.m
//  OctoContext
//

#import "OctoSummaryDetailVC.h"
#import "OctoSummaryAPI.h"
#import "OctoSummaryGroupNotifyHelper.h"
#import "OctoSummaryActionSheet.h"
#import "OctoSummaryMarkdownRender.h"
#import "OctoCitationBadgeView.h"
#import "OctoSummaryDateFormat.h"
#import "OctoDetailSourcesView.h"
#import "OctoRelatedChatSheet.h"
#import "OctoSummaryEditVC.h"
#import "OctoSummaryConfirmVC.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <WuKongIMSDK/WKTextContent.h>
#import <WuKongBase/WuKongBase-Swift.h>           // WKMarkdownRenderer (Swift)
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface OctoSummaryDetailVC () <UITextViewDelegate, WKNavigationDelegate>
@property(nonatomic, strong) UIScrollView *scroll;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) OctoDetailSourcesView *sourcesView;
@property(nonatomic, strong) UILabel *createdAtLabel;
@property(nonatomic, strong) UIView *processingView;
@property(nonatomic, strong) UIActivityIndicatorView *processingSpinner;
@property(nonatomic, strong) UILabel *processingTitle;
@property(nonatomic, strong) UILabel *processingDesc;
@property(nonatomic, strong) UILabel *waitingTitle;
@property(nonatomic, strong) UIButton *waitingActionBtn;

// 总结内容容器 + 顺序分段渲染
//   - 文本段: UITextView (selectable=NO + 强制 TK1, 修首次点击跳动)
//   - 表格段: WKWebView 渲染 cmark-gfm 出的 HTML, citation 通过预处理 [N] → [N](octo-cit://N)
//             嵌入为 <a>, WKNavigationDelegate 拦截 octo-cit:// 触发 RelatedChatSheet
@property(nonatomic, strong) UIView *contentContainer;
@property(nonatomic, strong) NSMutableArray<UIView *> *contentSegments;

@property(nonatomic, strong) UIButton *moreBtn;
@property(nonatomic, strong) OctoSummaryDetail *detail;
@property(nonatomic, strong) NSTimer *pollTimer;
/// 轮询失败只提示第一次, 后续静默重试 (见 loadDetail 的错误分支)。
@property(nonatomic, assign) BOOL pollErrorToastShown;
/// 连续临时性错误 (超时/断连/5xx) 计数, 成功一次清零。超过上限就不再续轮询——
/// 否则弱网/服务端持续异常时, 页面开着就一直 3s 一发, 没有任何退避或上限。
@property(nonatomic, assign) NSUInteger pollTransientErrorCount;

/// 上一次 loadDetail 观测到的任务状态。nil = 本页还没观测过 (首屏)。
/// 群提示只在观测到 非完成 → 完成 的状态跃变时发; 首屏就是完成态的情况靠
/// "本机发起标记" 单独开闸 (见 notifyGroupsIfCompleted:)。
/// 与安卓 SmartSummaryDetailViewModel.lastKnownStatus 一一对应。
@property(nonatomic, copy, nullable) NSNumber *lastKnownStatus;

/// YES 表示 VC 进入"消失中"状态 (viewWillDisappear → viewDidDisappear 之间, 或者
/// 用户在做交互式右滑 pop)。期间所有"会改变 layout 的异步回调"都必须 no-op,
/// 否则会和 UIKit 的 transition driver 抢 layout 触发死循环。viewWillAppear 重置
/// (用户取消右滑回到详情页时)。
@property(nonatomic, assign) BOOL contentDetaching;

/// relayoutContent 重入闸: viewDidLayoutSubviews 内调 relayoutContent, 而
/// relayoutContent 自身改子 frame / scroll.contentSize 又会触发 layoutSubviews
/// 回环。正常情况下子 frame 不变能自然收敛, 但 webview 高度回填和 transition
/// driver 同时拨 layout 时会重入 → 死循环。整套链路下我们手动闸住。
@property(nonatomic, assign) BOOL relayoutInFlight;

/// 是否因 "当前详情含 WKWebView 渲染表格" 而临时关掉了 nav 的交互式右滑返回手势。
/// 状态记下来, restore 时只在我们关过的情况下才恢复, 避免覆盖其它 VC /
/// WKRootNavigationController 自己的逻辑。
@property(nonatomic, assign) BOOL disabledInteractivePopForTable;

/// 关闭手势前捕获的原 enabled 值。多窗口快速 push/pop 时不能假设"恢复=YES",
/// 例如根 nav stack 只有 1 个 VC 时 WKRootNavigationController 自己也会关右滑,
/// 这种状态下我们的 restore 不能把它强制开成 YES, 否则与根 nav 抢状态。
@property(nonatomic, assign) BOOL gestureOriginalEnabled;

/// 还没渲染稳定的表格 webview 集合。webview 加载是完全异步的:
///   T0    loadHTMLString → WebKit 渲染
///   T0+x  didFinishNavigation 异步回调 (~50-300ms)
///   T0+y  evaluateJavaScript scrollHeight 完成
///   T0+z  我方 applyWebviewHeight 写入 frame + relayoutContent
/// 这个 T0~T0+z 窗口内, 用户右滑返回就会和 WebKit 内部 IPC + transition driver
/// 撞 layout 死循环 (WebContent 进程 ↔ 主线程同步通信链路是 app 层管不到的)。
/// 实现 "稳定后才允许右滑": webview 创建即加进集合 + 关右滑, 每个 webview 完成
/// applyWebviewHeight 后从集合移除; 集合空 → 重新开右滑。
@property(nonatomic, strong) NSMutableSet<WKWebView *> *pendingTableWebviews;

// 底部悬浮 footer (转发到聊天 + 编辑), 只在 completed 时出现
@property(nonatomic, strong) UIView *bottomBar;
@property(nonatomic, strong) UIButton *footerForwardBtn;
@property(nonatomic, strong) UIButton *footerEditBtn;
@end

// disarmTableWebviews / rearmTableWebviewsIfNeeded 共用同一个 associated-object key。
// 之前定义在 disarmTableWebviews 函数内 (function-static) → 仅本函数可见, 别处只能各自
// 声明同名静态, 但地址互异, 关联标记跨函数对不上。提到文件级 static 后两处一致。
static const void * const kOctoWebviewDisarmedKey = &kOctoWebviewDisarmedKey;

@implementation OctoSummaryDetailVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor systemBackgroundColor]
            : [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF7/255.0 alpha:1.0];
    }];
    // 标题固定 "智能总结" (用户要求): 不再随 detail.title 变化, 因为详情页本身已经在 body
    // 大标题里展示总结主题, nav 上再放总结主题就重复了。
    self.navigationBar.title = LLang(@"智能总结");

    self.moreBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.moreBtn setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal];
    self.moreBtn.tintColor = [UIColor labelColor];
    self.moreBtn.frame = CGRectMake(0, 0, 28, 28);
    [self.moreBtn addTarget:self action:@selector(onMore:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationBar.rightView = self.moreBtn;

    self.scroll = [UIScrollView new];
    self.scroll.alwaysBounceVertical = YES;
    [self.view addSubview:self.scroll];

    self.titleLabel = [UILabel new];
    self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.textColor = [UIColor labelColor];
    [self.scroll addSubview:self.titleLabel];

    self.sourcesView = [[OctoDetailSourcesView alloc] initWithFrame:CGRectZero];
    __weak typeof(self) ws = self;
    self.sourcesView.onToggle = ^(BOOL expanded) {
        // chip 折叠/展开 → 高度变化, 触发 scroll 内容重排
        [ws relayoutContent];
    };
    [self.scroll addSubview:self.sourcesView];

    self.createdAtLabel = [UILabel new];
    self.createdAtLabel.font = [UIFont systemFontOfSize:12];
    self.createdAtLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.5];
    [self.scroll addSubview:self.createdAtLabel];

    // contentView: selectable = NO 是修 "首次点击文本会跳一下" 的关键 ——
    self.contentContainer = [UIView new];
    self.contentContainer.backgroundColor = [UIColor systemBackgroundColor];
    self.contentContainer.layer.cornerRadius = 12;
    self.contentContainer.clipsToBounds = YES;
    self.contentContainer.hidden = YES;
    [self.scroll addSubview:self.contentContainer];
    self.contentSegments = [NSMutableArray array];
    self.pendingTableWebviews = [NSMutableSet set];

    // processing
    self.processingView = [UIView new];
    // 浅色: #FCF3FF (品牌紫的极淡铺底); 深色: 用深紫调与黑底分层, 又与品牌紫 spinner
    // 视觉一致, 不会出现 "白底白字看不见" 的问题。两态都和 contentContainer 的
    // systemBackgroundColor 形成层级对比。
    self.processingView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0x2A/255.0 green:0x1A/255.0 blue:0x38/255.0 alpha:1.0];
        }
        return [UIColor colorWithRed:0xFC/255.0 green:0xF3/255.0 blue:0xFF/255.0 alpha:1.0];
    }];
    self.processingView.layer.cornerRadius = 16;
    self.processingView.hidden = YES;
    [self.scroll addSubview:self.processingView];
    self.processingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.processingSpinner.color = [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0];
    [self.processingView addSubview:self.processingSpinner];
    self.processingTitle = [UILabel new];
    self.processingTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.processingTitle.textColor = [UIColor labelColor];
    self.processingTitle.text = LLang(@"AI正在分析聊天记录...");
    self.processingTitle.textAlignment = NSTextAlignmentCenter;
    [self.processingView addSubview:self.processingTitle];
    self.processingDesc = [UILabel new];
    self.processingDesc.font = [UIFont systemFontOfSize:13];
    self.processingDesc.textColor = [UIColor.labelColor colorWithAlphaComponent:0.6];
    self.processingDesc.text = LLang(@"可能需要一会儿时间,请稍候");
    self.processingDesc.numberOfLines = 0;
    self.processingDesc.textAlignment = NSTextAlignmentCenter;
    [self.processingView addSubview:self.processingDesc];

    // waiting
    self.waitingTitle = [UILabel new];
    self.waitingTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.waitingTitle.textColor = [UIColor labelColor];
    self.waitingTitle.numberOfLines = 0;
    self.waitingTitle.textAlignment = NSTextAlignmentCenter;
    self.waitingTitle.hidden = YES;
    [self.scroll addSubview:self.waitingTitle];
    self.waitingActionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.waitingActionBtn setTitle:LLang(@"查看确认状态") forState:UIControlStateNormal];
    [self.waitingActionBtn addTarget:self action:@selector(onWaitingAction) forControlEvents:UIControlEventTouchUpInside];
    self.waitingActionBtn.hidden = YES;
    [self.scroll addSubview:self.waitingActionBtn];

    [self buildBottomBar];

    // 前台恢复时重新拉起轮询。viewWillAppear 只覆盖"被子页盖住后返回", 覆盖不到
    // "页面一直开着, 但 App 进了后台 / 断网": 后台期间 NSTimer 不走, 且弱网时轮询
    // 可能已经退避到低频, 用户切回来时需要立刻续上一拍, 否则完成时刻可能整段错过。
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(onAppDidBecomeActive)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];

    [self loadDetail];
}

- (void)onAppDidBecomeActive {
    // 已经离场 / 正在离场的 VC 不复活轮询 (view 不在窗口上就没必要跑)。
    if (!self.view.window) return;
    [self resumePollingIfNeeded];
}

- (void)dealloc {
    [self.pollTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                   name:UIApplicationDidBecomeActiveNotification
                                                 object:nil];
    // 最后一道兜底: VC 真正销毁时确保所有 webview 不再回调任何东西。视图层级已经
    // 不存在了, 异步在飞的 completion handler 触到 weakSelf=nil 自然 no-op, 这里
    // 兜底也防一些极端时序 (比如 webview 还在排队 IPC 时 VC 整体 dealloc)。
    for (UIView *seg in self.contentSegments) {
        if ([seg isKindOfClass:[WKWebView class]]) {
            WKWebView *wv = (WKWebView *)seg;
            wv.navigationDelegate = nil;
            [wv stopLoading];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 取消右滑 pop 回到详情页时, 恢复 detaching=NO 让后续 webview 高度回填等异步
    // 链路重新生效。第一次进入时也会走这里, 不影响初始 NO。
    self.contentDetaching = NO;
    // R6 fix (Jerry-Xin / lml2468): 取消右滑场景。viewWillDisappear 在右滑刚开始就跑过
    // 一次 disarm (那时 isMovingFromParentViewController 已 YES), 用户中途松手取消
    // → viewDidDisappear 不 fire (viewDidDisappear 加的 trulyLeaving 闸救不到这条)
    // → webview 永久 disarmed (delegate=nil + 关联标记), octo-cit:// 引用点击 +
    // didFinishNavigation 高度回填都失效, 直到 pop+push 整页才恢复。viewWillAppear
    // 这里 re-arm: 重设 navigationDelegate + 清关联标记 (与 disarmTableWebviews 互逆)。
    [self rearmTableWebviewsIfNeeded];
    // webview 是否已稳定, 决定右滑手势开关。pendingTableWebviews 由 makeTableSegment
    // 加入 / applyWebviewHeight 完成时移除, 这里基于当前集合状态同步一次。
    [self syncInteractivePopGestureWithWebviewState];

    // R4 补充 fix: viewWillDisappear 里 invalidate 定时器时不区分"真离场"还是"被
    // push 的子页盖住" (转发 / 编辑 / 查看确认状态都会 push 子页)。之前 pop 回来后
    // 轮询没有任何地方重新拉起, 永久停摆——群提示现在挂在这条轮询上, 停摆等于提示
    // 再也发不出去。这里补上: 非终态且轮询确实没在跑时, 重新拉一次。
    [self resumePollingIfNeeded];
}

/// 取消右滑后 viewWillAppear 调用, 与 disarmTableWebviews 配对。idempotent: 没 disarm
/// 过的 webview 跳过, 避免重置已经在工作中的 delegate。
- (void)rearmTableWebviewsIfNeeded {
    for (UIView *seg in self.contentSegments) {
        if (![seg isKindOfClass:[WKWebView class]]) continue;
        WKWebView *wv = (WKWebView *)seg;
        if (![objc_getAssociatedObject(wv, kOctoWebviewDisarmedKey) boolValue]) continue;
        // 注: 不再 reload —— 已渲染的 HTML 内容仍有效 (UIWebContentProcess 还活)。我们要恢复的
        // 是 delegate 路径 (octo-cit:// hooks + didFinishNavigation 的 evalJS 高度回填),
        // 不是重新载入。
        objc_setAssociatedObject(wv, kOctoWebviewDisarmedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        wv.navigationDelegate = self;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // R3 review (yujiawei): 仅在确实正在被 pop / dismiss 时才执行 disarm / detaching / 手势恢复。
    // push 子页 (转发到聊天 / 查看确认状态) 让本 VC 暂时被覆盖时, 不能动这些状态——
    // 否则 pop-back 后表格 webview 永久 disarm: octo-cit:// citation 点不响应、表格高度无法回填。
    // 轮询定时器同理挪到这道闸后面: 之前不管三七二十一先 invalidate, 被子页盖住时也会
    // 把轮询杀掉, 且 viewWillAppear 不会重新拉起——群提示挂在这条轮询上, 停摆等于提示
    // 再也发不出去 (见 viewWillAppear 里补的重新拉起逻辑)。
    BOOL trulyLeaving = self.isMovingFromParentViewController || self.isBeingDismissed;
    if (!trulyLeaving) return;

    [self stopPolling];

    // 漏掉的并发路径: A 顶着 sheet (RelatedChatSheet) 时被 swipe-back pop —— UIKit
    // 把 "sheet 强 dismiss" 和 "nav pop 转场" 两段并发跑在 tracking runloop 上,
    // 与本 VC 内 webview 异步回填一起重入触发 layout 死锁; 即使 A 当前 webview 已
    // 稳定, 进程级 (WebContent IPC / 视图栈) 残余状态会拖到下一个 detail VC 的 pop
    // 时撞死。先 animated:NO 同步摘掉 sheet, 再继续 pop, 让两段串行。
    // 仅在确实正在被 pop 时做 (isMovingFromParentViewController), 避免误伤
    // "我们正在 present 别的 VC, 自己暂时被覆盖" 的合法路径。
    if (self.presentedViewController && self.isMovingFromParentViewController) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
    // 整个链路最关键的闸: detaching=YES 让所有异步 layout 回调 (didFinishNavigation 内
    // evaluateJavaScript 的 completionHandler, 还有任何后续 dispatch_async 进来的) 全部
    // no-op。原因: 右滑返回时 UIKit 在 tracking runloop mode 下做交互过渡, layout 节奏
    // 由 transition driver 拨动; 这时 webview 异步把 frame 高度回填 + 触发父 layout +
    // viewDidLayoutSubviews → relayoutContent → 改子 frame → layout 再来一轮, 与 driver
    // 抢 runloop 重入死循环。
    //
    // 单 disarm (delegate=nil + stopLoading) 不够: completionHandler 是 block 直接持有的
    // 回调, 不走 delegate; stopLoading 也只取消导航, JS 引擎已开跑的语句仍会回来。所以
    // 必须在 completionHandler 体内显式查 detaching 才稳。
    self.contentDetaching = YES;
    [self disarmTableWebviews];
    // 用户既然要走, 没必要再追踪 pending: 清空集合 + 同步手势状态。否则老 VC 的
    // 5s 兜底 timeout / 异步 didFinishNavigation 还在飞, 在 dealloc 前的某个时刻
    // 触发 syncInteractivePopGestureWithWebviewState 改新 VC 的 gesture 状态, 出
    // 多窗口快速切换时的 race。disarmTableWebviews 内部已经清过一次, 这里幂等。
    [self.pendingTableWebviews removeAllObjects];
    // 离开详情时恢复全局右滑手势, 不影响其他页面 (用户可能从这里回到列表后再
    // 进别的页面)。WKRootNavigationController 的 didShowViewController: 也会基于
    // 栈深做最终调整, 这里只是早一拍恢复。
    [self restoreInteractivePopGestureFromTableContent];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    // R4 fix (yujiawei #1): 与 viewWillDisappear 对称的 pop-only 闸. push 子页 (转发 / 查看
    // 确认状态等) 让本 VC 暂时被覆盖时, viewDidDisappear 也不能 disarm webview, 否则
    // pop-back 后 octo-cit:// citation 点击失效 + 表格高度不回填 (viewWillAppear 不 re-arm)。
    // viewWillDisappear 已经在真离场时 disarm 过, 这里只是早一拍重复, 不漏路径。
    BOOL trulyLeaving = self.isMovingFromParentViewController || self.isBeingDismissed;
    if (!trulyLeaving) return;
    // 真的 pop 走了: 彻底清掉, dealloc 兜底, 但这里更早一拍。所有清理路径全做幂等
    // 处理 (disarm 用 associated object 标记 / pendingTableWebviews removeAllObjects /
    // restore 检 disabledInteractivePopForTable 标志), 重复调用安全。
    [self disarmTableWebviews];
    [self.pendingTableWebviews removeAllObjects];
    [self restoreInteractivePopGestureFromTableContent];
}

#pragma mark - Interactive pop gesture toggle (webview 稳定后才开启)

/// 调用时机: 任何会改变 pendingTableWebviews 的地方 + viewWillAppear。
/// 集合非空 → 关右滑 (webview 在飞, 用户右滑必撞 race);
/// 集合为空 → 恢复到原值 (不一定是 YES, 见 gestureOriginalEnabled 注释)。
- (void)syncInteractivePopGestureWithWebviewState {
    if (!self.isViewLoaded || !self.view.window) return;
    UIGestureRecognizer *gr = self.navigationController.interactivePopGestureRecognizer;
    if (!gr) return;
    BOOL hasPending = self.pendingTableWebviews.count > 0;
    if (hasPending) {
        if (!self.disabledInteractivePopForTable) {
            // 第一次关: 先记下原 enabled 值, restore 时按这个值恢复, 避免与
            // WKRootNavigationController.didShowViewController 的 "栈深=1 强制关右滑"
            // 逻辑抢状态。
            self.gestureOriginalEnabled = gr.isEnabled;
            self.disabledInteractivePopForTable = YES;
        }
        if (gr.isEnabled) gr.enabled = NO;
    } else {
        if (self.disabledInteractivePopForTable) {
            gr.enabled = self.gestureOriginalEnabled;
            self.disabledInteractivePopForTable = NO;
        }
    }
}

/// VC 离开时一定要还原, 避免我们的 disabled 状态污染下一个 VC / 根 nav 的策略。
- (void)restoreInteractivePopGestureFromTableContent {
    if (!self.disabledInteractivePopForTable) return;
    UIGestureRecognizer *gr = self.navigationController.interactivePopGestureRecognizer;
    if (gr) gr.enabled = self.gestureOriginalEnabled;
    self.disabledInteractivePopForTable = NO;
}

- (void)disarmTableWebviews {
    for (UIView *seg in self.contentSegments) {
        if (![seg isKindOfClass:[WKWebView class]]) continue;
        WKWebView *wv = (WKWebView *)seg;
        // 幂等: 同一 webview 被多次 disarm (viewWillDisappear → viewDidDisappear →
        // dealloc, 还有 clearContentSegments 等) 是常态。重复 stopLoading 在新版
        // iOS 容忍, 但老版本 (iOS 14/15) 会累积无效 IPC; 而且第二次以后再走
        // delegate=nil 已经是 nil → nil 也无意义。associated object 打标后跳过。
        if ([objc_getAssociatedObject(wv, kOctoWebviewDisarmedKey) boolValue]) continue;
        objc_setAssociatedObject(wv, kOctoWebviewDisarmedKey, @YES,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // Apple 推荐顺序: stopLoading 在前, navigationDelegate=nil 在后。
        // 反过来 (旧代码) 的问题: stopLoading 触发 didFail 时 delegate 已经 nil,
        // WebKit 内部状态机收不到 ack, IPC 链路可能挂着等回, 主线程在某些场景被
        // 同步等待 → 偶发卡死的潜在源头之一。
        [wv stopLoading];
        wv.navigationDelegate = nil;
    }
    // disarm 后的 webview 不会再回调 didFinishNavigation, 也就永远不会到 markWebviewSettled.
    // pending 集合里若还残留这些 webview, 就永远开不了右滑了 → 强制清空。
    [self.pendingTableWebviews removeAllObjects];
    [self syncInteractivePopGestureWithWebviewState];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = CGRectGetMaxY(self.navigationBar.frame);

    // 底部悬浮按钮区:占 bottomBarH + bottomSafe; scroll 自身底部留出空间, 不被遮挡。
    CGFloat bottomBarH = self.bottomBar.hidden ? 0 : 72;
    CGFloat bottomSafe = self.view.safeAreaInsets.bottom;
    if (!self.bottomBar.hidden) {
        self.bottomBar.frame = CGRectMake(0,
                                          self.view.bounds.size.height - bottomBarH - bottomSafe,
                                          self.view.bounds.size.width, bottomBarH + bottomSafe);
        [self layoutBottomBarButtons];
    }

    self.scroll.frame = CGRectMake(0, top,
                                   self.view.bounds.size.width,
                                   self.view.bounds.size.height - top);
    self.scroll.contentInset = UIEdgeInsetsMake(0, 0,
                                                 (self.bottomBar.hidden ? 0 : bottomBarH + bottomSafe + 12),
                                                 0);
    // 过渡期统一 defer (sheet present/dismiss / nav pop / detaching), 不再驱动
    // content 段重排, 避免与 transition driver 抢 layout。relayoutContent 内部也
    // 有同样闸, 这里早退一次省掉栈深一层。
    if (![self shouldDeferLayoutWork]) {
        [self relayoutContent];
    }
}

- (void)relayoutContent {
    // 重入 + 过渡闸: viewDidLayoutSubviews 内调 relayoutContent, relayoutContent 自己
    // 又改子 frame / scroll.contentSize 触发 layoutSubviews 回环。两道闸:
    //   1. shouldDeferLayoutWork: 过渡期 (sheet present/dismiss / nav pop / detaching)
    //      统一 no-op, 让 transition 走完再说
    //   2. relayoutInFlight: 重入早退, 一次 layout pass 内只让一条链跑到底
    if ([self shouldDeferLayoutWork]) return;
    if (self.relayoutInFlight) return;
    self.relayoutInFlight = YES;

    CGFloat w = self.view.bounds.size.width - 32;
    CGFloat y = 12;

    CGSize titleSize = [self.titleLabel sizeThatFits:CGSizeMake(w, CGFLOAT_MAX)];
    self.titleLabel.frame = CGRectMake(16, y, w, titleSize.height);
    y += titleSize.height + 10;

    // 来源 chip 流式列表 (折叠/展开自适应高度)
    CGFloat srcH = [self.sourcesView heightForWidth:w];
    if (srcH > 0) {
        self.sourcesView.frame = CGRectMake(16, y, w, srcH);
        y += srcH + 12;     // 来源行 → 创建时间行 间距 12 (用户反馈"目前太紧凑了")
    }

    // 创建时间 (单独一行, "创建于："带冒号)
    if (self.createdAtLabel.text.length > 0) {
        CGSize ts = [self.createdAtLabel sizeThatFits:CGSizeMake(w, CGFLOAT_MAX)];
        self.createdAtLabel.frame = CGRectMake(16, y, w, ts.height);
        y += ts.height + 12;
    }

    if (!self.processingView.hidden) {
        self.processingView.frame = CGRectMake(16, y, w, 200);
        self.processingSpinner.frame = CGRectMake((w - 40) / 2.0, 36, 40, 40);
        self.processingTitle.frame  = CGRectMake(16, 96, w - 32, 24);
        self.processingDesc.frame   = CGRectMake(16, 130, w - 32, 36);
        y += 200 + 12;
    }
    if (!self.waitingTitle.hidden) {
        self.waitingTitle.frame = CGRectMake(16, y, w, 60);
        y += 60 + 4;
        self.waitingActionBtn.frame = CGRectMake(16, y, w, 36);
        y += 36 + 12;
    }
    if (!self.contentContainer.hidden) {
        // 容器 = 所有 segment 的累积高度 + 上下 16 padding。每个 segment 自身的 frame
        // 在创建/收到 webview 高度回调时已写入。这里把 container 高度对齐子总高即可。
        CGFloat innerY = 16;
        CGFloat innerW = w - 28;     // 容器内左右各 14 padding
        for (UIView *seg in self.contentSegments) {
            CGFloat h = seg.frame.size.height;
            if ([seg isKindOfClass:UITextView.class]) {
                CGSize sz = [seg sizeThatFits:CGSizeMake(innerW, CGFLOAT_MAX)];
                h = MAX(ceilf(sz.height), 20);
            }
            seg.frame = CGRectMake(14, innerY, innerW, h);
            innerY += h + 8;          // 段间留 8pt 间距
        }
        CGFloat containerH = MAX(innerY + 8, 80);
        self.contentContainer.frame = CGRectMake(16, y, w, containerH);
        y += containerH + 12;
    }
    self.scroll.contentSize = CGSizeMake(self.view.bounds.size.width, y);
    self.relayoutInFlight = NO;
}

#pragma mark - Bottom bar (转发到聊天 + 编辑)

- (void)buildBottomBar {
    self.bottomBar = [UIView new];
    self.bottomBar.backgroundColor = [UIColor systemBackgroundColor];
    self.bottomBar.layer.shadowColor = [UIColor blackColor].CGColor;
    self.bottomBar.layer.shadowOffset = CGSizeMake(0, -2);
    self.bottomBar.layer.shadowOpacity = 0.06;
    self.bottomBar.layer.shadowRadius = 8;
    self.bottomBar.hidden = YES;
    [self.view addSubview:self.bottomBar];

    self.footerForwardBtn = [self makeFooterButton:LLang(@"转发到聊天") primary:NO action:@selector(forwardToChat)];
    self.footerEditBtn    = [self makeFooterButton:LLang(@"编辑")    primary:YES action:@selector(openEditor)];
    [self.bottomBar addSubview:self.footerForwardBtn];
    [self.bottomBar addSubview:self.footerEditBtn];
}

- (UIButton *)makeFooterButton:(NSString *)title primary:(BOOL)primary action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    if (primary) {
        b.backgroundColor = [UIColor labelColor];
        [b setTitleColor:[UIColor systemBackgroundColor] forState:UIControlStateNormal];
    } else {
        b.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.06];
        [b setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    }
    b.layer.cornerRadius = 22;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)layoutBottomBarButtons {
    CGFloat w = self.view.bounds.size.width;
    CGFloat hSide = 16;
    CGFloat gap = 12;
    CGFloat btnW = (w - hSide * 2 - gap) / 2.0;
    CGFloat btnH = 44;
    self.footerForwardBtn.frame = CGRectMake(hSide, 14, btnW, btnH);
    self.footerEditBtn.frame    = CGRectMake(hSide + btnW + gap, 14, btnW, btnH);
}

#pragma mark - Load

- (void)loadDetail {
    int64_t tid = self.taskId.longLongValue;
    if (tid == 0) return;
    __weak typeof(self) weakSelf = self;
    [[OctoSummaryAPI shared] getSummaryDetail:tid callback:^(id _Nullable result, NSError * _Nullable error) {
        if (error || ![result isKindOfClass:OctoSummaryDetail.class]) {
            // 4xx (任务被删/无权限/参数错误等) 是永久性的, 换个 3s 再问一次结果不会变——
            // 之前不分青红皂白一律重试, 断网时还好, 遇到 404/403 这种会用户开着页面
            // 就一直白打请求。永久性错误直接停轮询, 不留死循环。
            NSInteger httpStatus = error.code;
            BOOL permanent = error && httpStatus >= 400 && httpStatus < 500;
            if (permanent) {
                weakSelf.pollTransientErrorCount = 0;
                [weakSelf stopPolling];
                [weakSelf.view showMsg:error.localizedDescription ?: LLang(@"加载失败")];
                return;
            }
            // 临时性失败 (弱网抖动/超时/切后台瞬间断连/5xx) 不能让轮询链路永久停摆——
            // 群提示挂在这条轮询观测到的状态跃变上, 断一次就再也没人去看任务完成了。
            // 只在第一次失败时提示, 后续静默重试, 避免持续断网时 toast 刷屏; 但也不能
            // 一直 3s 一发空转, 所以连续失败到一定次数后退避到更长间隔 (而不是彻底停),
            // 这样地铁/电梯里断网一分钟以上、之后网络自己恢复时, 轮询仍能自愈。
            if (!weakSelf.pollErrorToastShown) {
                weakSelf.pollErrorToastShown = YES;
                [weakSelf.view showMsg:LLang(@"加载失败")];
            }
            weakSelf.pollTransientErrorCount += 1;
            [weakSelf scheduleNextPollWithBackoff];
            return;
        }
        weakSelf.pollErrorToastShown = NO;
        weakSelf.pollTransientErrorCount = 0;
        weakSelf.detail = result;
        [weakSelf renderDetail];
        // 群提示的两个触发点之一: 详情页自身轮询观测到状态跃变 (另一个是通知助手
        // 卡片/链接点击, 见 OctoSummaryGroupNotifyHelper.handleSummaryDeepLink:)。
        [weakSelf notifyGroupsIfCompleted:weakSelf.detail];
        // WaitingConfirm ("等待参与者确认") 必须留在续轮询名单里 —— 它是本页文档声明
        // 覆盖的三个非终态之一 (OctoSummaryGroupNotifyHelper.h), 确认动作发生在其他
        // 参与者的设备上, 耗时通常远超 eligible 标记的 10 分钟 TTL, 少了这一档轮询会
        // 一直停在这个状态直到用户重开页面, 之后的 WaitingConfirm→Completed 跃变
        // 永远没人观测到, 群提示也就发不出来。
        if (weakSelf.detail.status == OctoTaskStatusProcessing
            || weakSelf.detail.status == OctoTaskStatusPending
            || weakSelf.detail.status == OctoTaskStatusWaitingConfirm) {
            [weakSelf scheduleNextPoll];
        }
    }];
}

/// 状态跃变判定。两条开闸路径:
///   1) prev 非空且非完成、本次完成 —— 亲眼看到了跃变, 这是主路径 (聊天页发起 →
///      自动进详情页 → 轮询到完成)。
///   2) prev 为空 (首屏) 且本次就是完成态 —— 没有跃变可观测, 只有"本机刚发起过这条
///      总结"(eligible 标记, 10 分钟 TTL, 一次性) 才开闸。用来覆盖创建后极快完成的
///      边界; 也正因为有这道闸, 点开一条历史已完成的总结不会追溯广播。
/// 两条路径都会消费掉 eligible 标记, 避免同一条总结之后又被深链路径判定一次。
- (void)notifyGroupsIfCompleted:(OctoSummaryDetail *)detail {
    if (!detail || detail.taskId <= 0) return;
    NSNumber *prev = self.lastKnownStatus;
    self.lastKnownStatus = @(detail.status);
    if (detail.status != OctoTaskStatusCompleted) return;

    BOOL transitioned = (prev != nil && prev.integerValue != OctoTaskStatusCompleted);
    if (transitioned) {
        [OctoSummaryGroupNotifyHelper consumeEligibleTaskId:detail.taskId];
    } else if (prev == nil) {
        if (![OctoSummaryGroupNotifyHelper consumeEligibleTaskId:detail.taskId]) return;
    } else {
        // prev 已经是完成态 —— 同一个终态被轮询/重入看到第二次, 不是新的完成。
        return;
    }
    [OctoSummaryGroupNotifyHelper notifyIfNeededWithDetail:detail];
}

- (void)scheduleNextPoll {
    [self scheduleNextPollAfter:3.0];
}

/// 连续临时性失败时的退避: 前 20 次维持 3s (弱网抖动通常几秒内自愈), 之后拉到 30s
/// 长驻低频重试。**不彻底停** —— 停掉的话网络恢复后没有任何东西会把轮询拉回来,
/// 用户开着页面却永远等不到完成, 群提示也发不出去 (review 指出的阻塞场景)。
/// 30s × 长期开页的成本可接受: 只在持续异常时才走到这一档。
- (void)scheduleNextPollWithBackoff {
    static const NSUInteger kFastRetryLimit = 20;   // 3s 间隔, 约 1 分钟
    NSTimeInterval delay = self.pollTransientErrorCount > kFastRetryLimit ? 30.0 : 3.0;
    [self scheduleNextPollAfter:delay];
}

- (void)scheduleNextPollAfter:(NSTimeInterval)delay {
    [self.pollTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:delay repeats:NO block:^(NSTimer *t) {
        // 一次性 timer 触发后自身变 invalid, 但 self.pollTimer 仍持有这个对象 (非 nil)。
        // 不清掉的话 viewWillAppear / applicationDidBecomeActive 里的 `!self.pollTimer`
        // 恢复闸永远进不去 —— 轮询一旦停摆就再也拉不起来。所以每次触发即清, 让
        // "pollTimer == nil" 严格等价于 "当前没有排队中的下一拍"。
        [weakSelf clearPollTimer];
        [weakSelf loadDetail];
    }];
}

/// 停轮询的唯一出口: invalidate + 置 nil。所有停止路径都必须走这里, 否则
/// pollTimer 会留着一个 invalid 对象, 把上面说的恢复闸永久堵死。
- (void)stopPolling {
    [self.pollTimer invalidate];
    self.pollTimer = nil;
}

/// 只清引用 (timer 已自然触发完, 无需再 invalidate)。
- (void)clearPollTimer {
    self.pollTimer = nil;
}

/// 非终态且当前没有排队中的下一拍 → 重新拉起轮询。
/// viewWillAppear (子页 pop 回来) 和 applicationDidBecomeActive (前台恢复) 共用。
- (void)resumePollingIfNeeded {
    // detail 为空是首次进页, viewDidLoad 已经调过 loadDetail, 不必重复。
    if (!self.detail || self.pollTimer) return;
    BOOL nonTerminal = self.detail.status == OctoTaskStatusProcessing
        || self.detail.status == OctoTaskStatusPending
        || self.detail.status == OctoTaskStatusWaitingConfirm;
    if (!nonTerminal) return;
    // 弱网期间累计的连续失败计数在这里清零: 用户回到前台 / 从子页返回, 说明这是一次
    // 新的重试机会, 不该继承上一轮网络异常留下的额度。
    self.pollTransientErrorCount = 0;
    [self loadDetail];
}

- (void)renderDetail {
    OctoSummaryDetail *d = self.detail;
    self.titleLabel.text = d.title;

    // 来源 chip 列表 (无 "来自" 前缀, 直接显示每个 source 的胶囊)
    self.sourcesView.items = d.sources;

    // 创建时间: "创建于：yyyy-MM-dd HH:mm" (带冒号)
    if (d.createdAt.length > 0) {
        self.createdAtLabel.text = [NSString stringWithFormat:LLang(@"创建于：%@"),
                                    [OctoSummaryDateFormat localFromISO:d.createdAt]];
    } else {
        self.createdAtLabel.text = @"";
    }

    BOOL processing = (d.status == OctoTaskStatusProcessing || d.status == OctoTaskStatusPending);
    BOOL waiting    = (d.status == OctoTaskStatusWaitingConfirm);
    BOOL completed  = (d.status == OctoTaskStatusCompleted);
    BOOL failed     = (d.status == OctoTaskStatusFailed);
    BOOL cancelled  = (d.status == OctoTaskStatusCancelled);

    self.processingView.hidden = !processing;
    if (processing) [self.processingSpinner startAnimating]; else [self.processingSpinner stopAnimating];

    self.waitingTitle.hidden = !waiting;
    self.waitingActionBtn.hidden = !waiting;
    if (waiting) {
        self.waitingTitle.text = LLang(@"等待参与者确认\n所有参与者确认后开始生成");
    }

    BOOL hasContent = (completed || failed || cancelled);
    self.contentContainer.hidden = !hasContent;
    if (completed) {
        [self renderCompletedContent:d.result.content citations:d.result.citations];
    } else if (failed) {
        NSString *err = d.errorMessage.length > 0 ? d.errorMessage : LLang(@"未知错误");
        NSString *prefix = LLang(@"生成失败:\n");
        [self renderPlainSegmentText:[prefix stringByAppendingString:err]
                                color:[UIColor systemRedColor]];
    } else if (cancelled) {
        [self renderPlainSegmentText:LLang(@"任务已取消")
                                color:[UIColor.labelColor colorWithAlphaComponent:0.5]];
    } else {
        [self clearContentSegments];
    }

    // 底部悬浮按钮: 仅 completed 显示 (转发到聊天 + 编辑都需要有结果存在)
    self.bottomBar.hidden = !completed;
    [self.view setNeedsLayout];

    [self relayoutContent];
}

#pragma mark - Content segments (text + table 混排)

- (void)clearContentSegments {
    // 把要被 remove 的 webview 先 disarm, 否则旧 webview 在 removeFromSuperview 后
    // 仍可能跑 didFinishNavigation 异步回调, 拿弱引用 self / 已废弃的 segment 改 frame。
    [self disarmTableWebviews];
    for (UIView *v in self.contentSegments) [v removeFromSuperview];
    [self.contentSegments removeAllObjects];
}

/// 失败/取消等"纯文本提示"分支: 只放一个文本 segment。不走 markdown / citation,
/// 避免格式化逻辑命中错位。
- (void)renderPlainSegmentText:(NSString *)text color:(UIColor *)color {
    [self clearContentSegments];
    UITextView *tv = [self makeTextSegment];
    tv.attributedText = [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:14],
        NSForegroundColorAttributeName: color,
    }];
    [self.contentContainer addSubview:tv];
    [self.contentSegments addObject:tv];
    [self relayoutContent];
}

/// completed 分支: 解析 markdown 内容里的表格段, 文本段走自家 OctoSummaryMarkdownRender
/// (含 [N] citation 徽章), 表格段走 WKMarkdownRenderer 输出 HTML 由 WKWebView 渲染。
/// citation 在表格里的可点击性: 把 [N] 预处理成 [N](octo-cit://N) 让 cmark 出 <a>,
/// WKNavigationDelegate 拦截 octo-cit:// scheme 触发 RelatedChatSheet。
- (void)renderCompletedContent:(NSString *)content
                     citations:(NSArray<OctoCitationItem *> *)citations {
    [self clearContentSegments];
    NSString *raw = content ?: @"";
    if (raw.length == 0) return;

    BOOL hasTable = [WKMarkdownRenderer containsTable:raw];
    if (!hasTable) {
        UITextView *tv = [self makeTextSegment];
        tv.attributedText = [OctoSummaryMarkdownRender attributedFromContent:raw
                                                                    citations:citations
                                                                     fontSize:14];
        [self.contentContainer addSubview:tv];
        [self.contentSegments addObject:tv];
        [self relayoutContent];
        return;
    }

    NSArray<NSDictionary *> *segments = [WKMarkdownRenderer splitContentSegments:raw];
    for (NSDictionary *seg in segments) {
        NSString *type = seg[@"type"];
        NSString *text = seg[@"content"];
        if (text.length == 0) continue;
        if ([type isEqualToString:@"text"]) {
            UITextView *tv = [self makeTextSegment];
            tv.attributedText = [OctoSummaryMarkdownRender attributedFromContent:text
                                                                        citations:citations
                                                                         fontSize:14];
            [self.contentContainer addSubview:tv];
            [self.contentSegments addObject:tv];
        } else if ([type isEqualToString:@"table"]) {
            // 在传给 cmark 前把 [N] 转 [N](octo-cit://N) —— 让 renderInlineCellContent
            // 把它们转成 <a href="octo-cit://N">[N]</a>, WKNavigationDelegate 接管点击。
            NSString *injected = [self injectCitationLinks:text];
            UIColor *textColor = [UIColor labelColor];
            NSString *colorHex = [self hexFromColor:textColor];
            NSString *html = [WKMarkdownRenderer extractTableHTML:injected
                                                          fontSize:14
                                                      textColorHex:colorHex];
            if (html.length == 0) continue;
            html = [self wrapTableHTML:html];
            WKWebView *wv = [self makeTableSegment];
            [wv loadHTMLString:html baseURL:nil];
            [self.contentContainer addSubview:wv];
            [self.contentSegments addObject:wv];
            // 加入 pending 集合 → 关右滑直到该 webview applyWebviewHeight 完成
            [self.pendingTableWebviews addObject:wv];
            [self syncInteractivePopGestureWithWebviewState];
            // 兜底: 5s 超时仍没 settle 就强制移出, 避免 webview 异常情况下永远不开右滑。
            // 5s 远超表格 HTML 渲染正常耗时 (一般 50-300ms), 触发说明 webview 真出问题了。
            // 多重身份校验: weakSelf nil-guard + isViewLoaded + view.window 非空, VC 已
            // dealloc / 已离屏的情况下任何 gesture 状态修改都没意义还可能与新 VC 抢状态。
            __weak typeof(self) ws = self;
            __weak WKWebView *wweb = wv;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                typeof(ws) strong = ws;
                if (!strong) return;
                if (!strong.isViewLoaded || !strong.view.window) return;
                WKWebView *wv2 = wweb;
                if (!wv2) return;
                if ([strong.pendingTableWebviews containsObject:wv2]) {
                    [strong.pendingTableWebviews removeObject:wv2];
                    [strong syncInteractivePopGestureWithWebviewState];
                }
            });
        }
    }
    [self relayoutContent];
}

- (UITextView *)makeTextSegment {
    UITextView *tv = [UITextView new];
    tv.editable = NO;
    tv.selectable = NO;          // 禁用系统文字选择, 修首次点击 "激活跳动"
    tv.scrollEnabled = NO;
    tv.backgroundColor = [UIColor clearColor];
    // 顶/底各留 4pt 让 markdown 标题(更大字号 → 更高 ascender)不被 frame 顶边裁掉。
    // 之前用 UIEdgeInsetsZero 把 padding 完全抹掉, 第一行 # 标题的 cap-height 超出 y=0
    // 直接被 frame 切掉一半 (用户报"顶部标题文本少显示了一半")。
    tv.textContainerInset = UIEdgeInsetsMake(4, 0, 4, 0);
    tv.textContainer.lineFragmentPadding = 0;
    tv.allowsEditingTextAttributes = NO;
    (void)tv.layoutManager;          // 强制 TextKit 1, 修首次点击布局抖动
    if (@available(iOS 16.0, *)) {
        tv.findInteractionEnabled = NO;
    }
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTextSegmentTap:)];
    [tv addGestureRecognizer:tap];
    return tv;
}

- (WKWebView *)makeTableSegment {
    WKWebViewConfiguration *cfg = [WKWebViewConfiguration new];
    WKWebView *wv = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 300, 80)
                                       configuration:cfg];
    wv.navigationDelegate = self;
    wv.scrollView.scrollEnabled = NO;
    wv.scrollView.bounces = NO;
    wv.opaque = NO;
    wv.backgroundColor = [UIColor clearColor];
    return wv;
}

/// 表格里的 citation 聚合: 连续相邻的 [N][M]... 合成单条 markdown link, 与正文段
/// (OctoSummaryMarkdownRender.applyCitationsTo:) 同口径; URL host 用下划线连接索引,
/// label 走 OctoSummaryMarkdownRender.badgeTextFromIndices:。点击时 navigation
/// delegate 把 host 拆回 indices 数组下放给 RelatedChatSheet。
- (NSString *)injectCitationLinks:(NSString *)content {
    NSError *err = nil;
    // 一连串紧贴的 [N][M]... 视为一组 (中间无字符);
    // 已是 markdown 链接形式 [N](...) 的不动 (negative lookahead/-behind)。
    NSRegularExpression *runRe = [NSRegularExpression
        regularExpressionWithPattern:@"(?<!\\]\\()(?:\\[\\d+\\])+(?!\\()"
                             options:0
                               error:&err];
    if (!runRe) return content;
    NSArray<NSTextCheckingResult *> *runs = [runRe matchesInString:content
                                                            options:0
                                                              range:NSMakeRange(0, content.length)];
    if (runs.count == 0) return content;

    NSRegularExpression *digitRe = [NSRegularExpression regularExpressionWithPattern:@"\\d+" options:0 error:nil];
    NSMutableString *out = [NSMutableString string];
    NSUInteger cursor = 0;
    for (NSTextCheckingResult *m in runs) {
        if (m.range.location > cursor) {
            [out appendString:[content substringWithRange:NSMakeRange(cursor, m.range.location - cursor)]];
        }
        NSString *runText = [content substringWithRange:m.range];   // e.g. "[1][2][3]"
        NSMutableArray<NSNumber *> *indices = [NSMutableArray array];
        NSMutableArray<NSString *> *idStrs = [NSMutableArray array];
        for (NSTextCheckingResult *dm in [digitRe matchesInString:runText options:0 range:NSMakeRange(0, runText.length)]) {
            NSString *s = [runText substringWithRange:dm.range];
            [indices addObject:@([s integerValue])];
            [idStrs addObject:s];
        }
        if (indices.count == 0) {
            [out appendString:runText];
        } else {
            NSString *label = [OctoSummaryMarkdownRender badgeTextFromIndices:indices];
            // 用下划线串而不是逗号: NSURL host 对逗号不友好, integerValue 解 "1,2,3"
            // 也只会拿到 1 丢掉后面的; 下划线 host (如 "1_3_5") 解析完整且 NSURL 接受。
            NSString *host = [idStrs componentsJoinedByString:@"_"];
            [out appendFormat:@"[%@](octo-cit://%@)", label, host];
        }
        cursor = NSMaxRange(m.range);
    }
    if (cursor < content.length) {
        [out appendString:[content substringFromIndex:cursor]];
    }
    return out;
}

/// 给 extractTableHTML 输出的 HTML 注入: ① 横向滚动容器(用户报"无法左右滑动")
/// ② 深色模式 CSS(用户报"未适配深色") ③ citation 徽章样式。
///
/// 横向滚动: 在 body 外包 .octo-table-wrap{overflow-x:auto}, 表格本身已声明
/// width:max-content + white-space:nowrap, 超出视口时容器内可左右滑。
/// WKWebView 外层 scrollView.scrollEnabled = NO 不影响内部 overflow div 的
/// 触摸滚动 (WebKit 单独处理 inner scroller),所以纵向不会与父 scrollView 抢手势。
///
/// 深色模式: 用 @media (prefers-color-scheme: dark) —— WKWebView 跟随 iOS
/// traitCollection 的 userInterfaceStyle 自动 resolve, 系统切换深浅时 CSS 即时生效,
/// 无需重新 loadHTMLString。
- (NSString *)wrapTableHTML:(NSString *)html {
    if (html.length == 0) return html;
    // CSP 兜底: WKMarkdownRenderer.escapeHTML 不转义 `"`, 服务端 markdown 表格 cell 里
    // 如果有 `[x](" onmouseover=...)` 形式可以闭合 href 引号注入事件属性。这里在 webview
    // 顶部声明 `script-src 'none'` + 关掉 inline event handler / data: 之外的源, 同时把
    // 按钮链接 scheme 限定到 octo-cit (nav policy 已 cancel 其它), 双层关闭 XSS sink。
    // 该 CSP 只影响本表格 webview, 共享 markdown 渲染器不动, 避免影响消息 cell 路径。
    NSString *injectedCSS =
        @"<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'self' data:; script-src 'none'; style-src 'unsafe-inline';\">"
        @"<style>"
        @"a[href^='octo-cit']{display:inline-block;padding:0 6px;margin:0 1px;"
        @"background:rgba(127,59,245,0.16);color:#7F3BF5;border-radius:7px;"
        @"font-size:11px;font-weight:500;text-decoration:none;line-height:1.6;}"
        @".octo-table-wrap{overflow-x:auto;-webkit-overflow-scrolling:touch;width:100%;}"
        @"@media (prefers-color-scheme: dark){"
        @"  body,*{color:rgba(255,255,255,0.92)!important;}"
        @"  table{border-color:#555!important;}"
        @"  th{background:rgba(255,255,255,0.08)!important;border-color:#555!important;}"
        @"  td{border-color:#444!important;}"
        @"  a[href^='octo-cit']{background:rgba(127,59,245,0.32);color:#D1B7FF;}"
        @"}"
        @"</style></head>";
    html = [html stringByReplacingOccurrencesOfString:@"</head>" withString:injectedCSS];
    html = [html stringByReplacingOccurrencesOfString:@"<body>"
                                            withString:@"<body><div class=\"octo-table-wrap\">"];
    html = [html stringByReplacingOccurrencesOfString:@"</body>"
                                            withString:@"</div></body>"];
    return html;
}

- (NSString *)hexFromColor:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    [color getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)(r * 255), (int)(g * 255), (int)(b * 255)];
}

#pragma mark - Citation tap (per text segment)

- (void)onTextSegmentTap:(UITapGestureRecognizer *)g {
    UIView *v = g.view;
    if (![v isKindOfClass:UITextView.class]) return;
    UITextView *tv = (UITextView *)v;
    CGPoint p = [g locationInView:tv];
    p.x -= tv.textContainerInset.left;
    p.y -= tv.textContainerInset.top;
    NSUInteger idx = [tv.layoutManager characterIndexForPoint:p
                                              inTextContainer:tv.textContainer
                     fractionOfDistanceBetweenInsertionPoints:nil];
    if (idx >= tv.attributedText.length) return;
    // 优先取 group 数组 (合并徽章): [1,2,3]; 没有就退化为单 index, 包成单元素数组
    NSArray<NSNumber *> *groupIndices = [tv.attributedText attribute:OctoCitationGroupAttrKey
                                                              atIndex:idx
                                                       effectiveRange:NULL];
    if (groupIndices.count == 0) {
        NSNumber *single = [tv.attributedText attribute:OctoCitationIndexAttrKey
                                                  atIndex:idx
                                           effectiveRange:NULL];
        if (!single) return;
        groupIndices = @[single];
    }
    [self openCitationsByIndices:groupIndices];
}

- (void)openCitationsByIndices:(NSArray<NSNumber *> *)indices {
    if (indices.count == 0) return;
    // 文本段 tap 入口也走这: 与 webview decidePolicyForNavigationAction 同口径,
    // 过渡期 (sheet present/dismiss / nav pop / detaching) 直接吞掉, 防止此时再
    // present 新 sheet 跟 in-flight 转场撞 layout 重入。webview 那条路径之前已经加
    // 过类似闸, 这里把文本 tap 路径补齐。
    if ([self shouldDeferLayoutWork]) return;
    [OctoRelatedChatSheet presentInVC:self
                            citations:self.detail.result.citations
                              sources:self.detail.sources
                        activeIndices:indices];
}

/// 旧入口保留: 表格里的 octo-cit:// 单 index 链路 + 任何遗留单点调用。
- (void)openCitationByIndex:(NSInteger)citationIndex {
    [self openCitationsByIndices:@[@(citationIndex)]];
}

#pragma mark - WKNavigationDelegate (table 内 citation 点击 + 高度自适应)

- (void)webView:(WKWebView *)webView
        decidePolicyForNavigationAction:(WKNavigationAction *)action
                        decisionHandler:(void (^)(WKNavigationActionPolicy))handler {
    NSURL *url = action.request.URL;
    // 拦截 octo-cit://N 或 octo-cit://N_M_K → 打开关联聊天 sheet。
    // 单索引 host = "1" 仍然成立; 聚合 host = "1_3_5" 时按 _ 拆开成 indices 数组。
    if ([url.scheme isEqualToString:@"octo-cit"]) {
        // 过渡期 (sheet present/dismiss / nav pop) 收到 citation 点击, 立即 present 新
        // sheet 等于 sheet 套 sheet 套 pop, 易触发 layout 重入死循环。这种情况直接吞掉
        // 这次点击 (用户在过渡期间不太可能精确点中 citation, 多半是误触或残留事件)。
        if ([self shouldDeferLayoutWork]) {
            handler(WKNavigationActionPolicyCancel);
            return;
        }
        NSString *host = url.host ?: @"";
        NSMutableArray<NSNumber *> *indices = [NSMutableArray array];
        for (NSString *part in [host componentsSeparatedByString:@"_"]) {
            NSInteger v = [part integerValue];
            if (v > 0) [indices addObject:@(v)];
        }
        if (indices.count > 0) [self openCitationsByIndices:indices];
        handler(WKNavigationActionPolicyCancel);
        return;
    }
    // 首次 loadHTMLString 自身的 about:blank / non-http 加载放行
    if (action.navigationType == WKNavigationTypeOther) {
        handler(WKNavigationActionPolicyAllow);
        return;
    }
    // 用户点击表格内其他 <a> 链接: 一律不在 webview 内导航 (避免在 cell 里跳页面)。
    // 后续可在这里接通用 URL 路由。
    handler(WKNavigationActionPolicyCancel);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    // 整条链路: didFinishNavigation → JS scrollHeight → 改 frame → relayoutContent →
    //          layoutSubviews → relayoutContent ... 与 transition driver 抢 layout 必死循环。
    // 防御策略: 任何"过渡进行中" (sheet present/dismiss / nav pop / detaching) 都
    //          走 deferWebviewHeightSync, 等过渡完成后再 apply。
    if ([self shouldDeferLayoutWork]) {
        [self deferWebviewHeightSync:webView];
        return;
    }
    __weak typeof(self) ws = self;
    __weak WKWebView *wweb = webView;
    [webView evaluateJavaScript:@"document.body.scrollHeight"
              completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        // completionHandler 是 block 直接持有, 不走 delegate, navigationDelegate=nil /
        // stopLoading 都拦不住已经在飞的 callback —— 所以这里要亲自查闸。
        typeof(ws) strong = ws;
        if (!strong) return;
        WKWebView *wv = wweb;
        if (!wv || ![strong.contentSegments containsObject:wv]) return;
        if (![result respondsToSelector:@selector(floatValue)]) return;
        CGFloat h = MAX(20, [result floatValue]);
        [strong applyWebviewHeight:h to:wv];
    }];
}

/// 真正去改 webview.frame 的唯一入口: 把 "现在能不能改 layout" 的判断收敛在这。
/// 过渡期检测到时, 借 transitionCoordinator.animateAlongsideTransition:completion:
/// 把 frame apply 推迟到过渡完成后, 而不是 dispatch_async 简单一拍 (那个还在
/// tracking runloop 内, 和 transition driver 仍会撞)。没拿到 coordinator 时退到
/// 主队列一拍兜底, 下次会被 deferWebviewHeightSync 接住继续等。
- (void)applyWebviewHeight:(CGFloat)h to:(WKWebView *)wv {
    if (!wv || ![self.contentSegments containsObject:wv]) return;
    if (!self.isViewLoaded || !self.view.window) return;
    CGRect f = wv.frame;
    if (fabs(f.size.height - h) < 0.5) return;

    if ([self shouldDeferLayoutWork]) {
        id<UIViewControllerTransitionCoordinator> coord = [self activeTransitionCoordinator];
        __weak typeof(self) ws = self;
        __weak WKWebView *wweb = wv;
        void (^apply)(void) = ^{
            typeof(ws) strong = ws;
            if (!strong) return;
            // 过渡完成的那一刻可能又触发了新过渡, 完整闸再走一遍
            if ([strong shouldDeferLayoutWork]) { [strong deferWebviewHeightSync:wweb]; return; }
            WKWebView *wv2 = wweb;
            if (!wv2 || ![strong.contentSegments containsObject:wv2]) return;
            CGRect f2 = wv2.frame;
            if (fabs(f2.size.height - h) < 0.5) return;
            f2.size.height = h;
            wv2.frame = f2;
            [strong relayoutContent];
            // 过渡完成后才 apply 的路径: 这里也算 settled, 可以开右滑了。
            [strong markWebviewSettled:wv2];
        };
        if (coord) {
            [coord animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> _) {
                apply();
            }];
        } else {
            // 没有 coordinator (sheet 稳态展开 / 即将完成的过渡): 退一步, 100ms 后再轮询。
            // 不要用 dispatch_async 一拍重投——sheet 一直开着时 shouldDeferLayoutWork 永远 YES,
            // 会形成每个 runloop 周期都在 main queue 投递的轻量轮询, 持续耗 CPU/电。
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), apply);
        }
        return;
    }

    f.size.height = h;
    wv.frame = f;
    [self relayoutContent];
    // 标准路径: frame 写完即 settled。第一次到达 settled 状态的 webview 会触发
    // syncInteractivePopGestureWithWebviewState 重新打开右滑。
    [self markWebviewSettled:wv];
}

/// 标记某个 webview 已稳定 (frame 写完 + relayoutContent 跑过)。从 pending 集合
/// 移除并同步右滑手势状态; 集合空时自动开启右滑。idempotent: 多次调用安全。
- (void)markWebviewSettled:(WKWebView *)wv {
    if (!wv) return;
    if (![self.pendingTableWebviews containsObject:wv]) return;
    [self.pendingTableWebviews removeObject:wv];
    [self syncInteractivePopGestureWithWebviewState];
}

/// "现在改 layout 是否危险" 综合判定。区分 "appearing" 与 "disappearing":
///   - appearing (push 进来 / 首次显示): transitionCoordinator 也 != nil, 但这是
///     VC 被 SHOW 出来的过渡, 改 frame 完全安全 (没有 transition driver 反向拨
///     layout 的对抗局面)。这种情况不 defer, 否则用户会看到详情已显示但表格
///     区空白 1-2 秒。
///   - disappearing (pop 出去 / 被 dismissed): VC 被 HIDE, 此时 transition driver
///     在 tracking runloop 推动 layout, 我方再去改 frame 必撞死循环, 必须 defer。
/// 三个 disappearing 信号:
///   1. contentDetaching            viewWillDisappear 显式设
///   2. isMovingFromParentViewController  nav pop 中 (含交互式右滑)
///   3. isBeingDismissed            modal dismiss 中
/// 此外:
///   - presentedViewController != nil  自己 present 了 sheet (含 dismiss 动画期);
///                                     这段改 frame 风险大 (sheet 套 layout 套 pop)
///   - !view.window                    已彻底离屏
- (BOOL)shouldDeferLayoutWork {
    if (self.contentDetaching) return YES;
    if (!self.isViewLoaded || !self.view.window) return YES;
    if (self.presentedViewController) return YES;
    if (self.isMovingFromParentViewController) return YES;
    if (self.isBeingDismissed) return YES;
    return NO;
}

- (id<UIViewControllerTransitionCoordinator>)activeTransitionCoordinator {
    if (self.transitionCoordinator) return self.transitionCoordinator;
    if (self.presentedViewController.transitionCoordinator) return self.presentedViewController.transitionCoordinator;
    return nil;
}

/// 过渡期间不发起 JS 评估; 100ms 后再来一次, 避免裸 dispatch_async 把"再试一次"
/// 投到下一个 runloop 周期——sheet 长开 / VC 离屏期间 shouldDeferLayoutWork 一直 YES,
/// 那种粒度的重投会变成每帧轮询。下次执行时若仍处于过渡, 继续 defer; 直到
/// shouldDeferLayoutWork == NO 才真正 apply。用 scrollView.contentSize 同步取高度
/// (WebKit 内部 layout 大概率已完成), 避免反复发 JS, 也消掉了 evaluateJavaScript
/// 与 main runloop 的耦合。
- (void)deferWebviewHeightSync:(WKWebView *)wv {
    if (!wv) return;
    __weak typeof(self) ws = self;
    __weak WKWebView *wweb = wv;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        typeof(ws) strong = ws;
        if (!strong) return;
        WKWebView *wv2 = wweb;
        if (!wv2 || ![strong.contentSegments containsObject:wv2]) return;
        CGFloat h = wv2.scrollView.contentSize.height;
        if (h > 20) {
            [strong applyWebviewHeight:h to:wv2];
        } else {
            [strong deferWebviewHeightSync:wv2];
        }
    });
}

#pragma mark - More menu (WKFloatingMenu, 与列表 cell 同款风格)

/// 详情页菜单只保留 "重新生成 + 删除" / "取消任务 + 删除" 等 ——
/// "编辑" 与 "转发到聊天" 走底部 footer, 不重复出现在菜单。
- (void)onMore:(UIButton *)btn {
    OctoSummaryDetail *d = self.detail;
    if (!d) return;
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    __weak typeof(self) ws = self;
    void (^add)(NSString *, void(^)(void), BOOL) = ^(NSString *title, void (^action)(void), BOOL destructive) {
        [items addObject:@{
            @"title": title,
            @"isDestructive": @(destructive),
            @"action": [action copy],
        }];
    };
    switch (d.status) {
        case OctoTaskStatusProcessing:
        case OctoTaskStatusPending:
        case OctoTaskStatusWaitingConfirm: {
            add(LLang(@"取消任务"), ^{ [ws performCancel]; }, NO);
            break;
        }
        case OctoTaskStatusCompleted: {
            add(LLang(@"重新生成"), ^{ [ws performRegenerate]; }, NO);
            break;
        }
        case OctoTaskStatusCancelled: {
            add(LLang(@"重新生成"), ^{ [ws performRegenerate]; }, NO);
            break;
        }
        case OctoTaskStatusFailed: {
            add(LLang(@"重试"),    ^{ [ws performRegenerate]; }, NO);
            break;
        }
        default: break;
    }
    add(LLang(@"删除"), ^{ [ws confirmDelete]; }, YES);
    CGPoint anchor = [btn.superview convertPoint:btn.center toView:nil];
    [WKFloatingMenu showItems:items atPoint:anchor];
}

- (void)performCancel {
    [[OctoSummaryAPI shared] cancelSummary:self.detail.taskId callback:^(id _Nullable result, NSError * _Nullable error) {
        if (error) { [self.view showMsg:LLang(@"取消失败")]; return; }
        [self.view showMsg:LLang(@"已取消")];
        [self loadDetail];
    }];
}

- (void)performRegenerate {
    [[OctoSummaryAPI shared] regenerateSummary:self.detail.taskId topic:nil callback:^(id _Nullable result, NSError * _Nullable error) {
        if (error) { [self.view showMsg:LLang(@"重新生成失败")]; return; }
        [self.view showMsg:LLang(@"已开始重新生成")];
        // regenerate API 返回 { task_id: <new id> } —— 与 ListVC.performRegenerate 同口径,
        // 切到新 taskId 后再 loadDetail, 才能拉到/轮询新一轮任务; 不切的话页面永远卡在
        // 旧 completed/failed 任务上, 用户看不到新进度。
        if ([result isKindOfClass:NSDictionary.class]) {
            id tidVal = ((NSDictionary *)result)[@"task_id"];
            // 同 CreateVC: 走模型层统一口径, 容忍数字 / 数字字符串两种回值。只认
            // NSNumber 的话后端回字符串时会静默不切 task, 页面永远卡在旧任务上。
            int64_t newId = [OctoSummaryModelHelper int64FromValue:tidVal];
            if (newId > 0 && newId != self.detail.taskId) {
                self.taskId = @(newId);
                // 换了 task 就得复位状态观测锚, 否则新任务的首屏会被当成"旧任务的
                // 后续一拍", 拿旧状态去比跃变。
                self.lastKnownStatus = nil;
                // 重新生成也是"本机发起", 与创建同口径打上 eligible 标记 —— 新任务
                // 极快完成、首屏就是终态时才有闸可开。
                [OctoSummaryGroupNotifyHelper markEligibleTaskId:newId];
            }
        }
        [self loadDetail];
        // 通知列表同步: 否则用户从详情发起"重新生成"后返回,
        // 列表仍卡在旧的 completed 状态,看不到"正在重新总结"。
        // 复用 CreateVC 的口径——后端层面 regenerate 就是发起一条新 task_id。
        [[NSNotificationCenter defaultCenter] postNotificationName:@"OctoSummaryDidCreateNotification" object:nil];
    }];
}

- (void)confirmDelete {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"确认删除")
                                                                   message:LLang(@"删除后将无法恢复")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"删除") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull a) {
        [[OctoSummaryAPI shared] deleteSummary:self.detail.taskId callback:^(id _Nullable result, NSError * _Nullable error) {
            if (error) { [self.view showMsg:LLang(@"删除失败")]; return; }
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Footer actions

- (void)openEditor {
    OctoSummaryEditVC *vc = [OctoSummaryEditVC new];
    vc.detail = self.detail;
    vc.onSaved = ^{ [self loadDetail]; };
    // push 到根 nav (与发起总结/选择聊天页同一栈), 这样保存/返回的 popViewControllerAnimated:
    // 才能正确回到详情页。原 modal 路径 popViewControllerAnimated 走的是根 nav, 但 EditVC
    // 在另一条 modal nav 栈里, pop 没人响应 → "无法返回也无法保存"。
    vc.hidesBottomBarWhenPushed = YES;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

- (void)forwardToChat {
    NSString *content = self.detail.result.content;
    if (content.length == 0) {
        [self.view showMsg:LLang(@"暂无可转发内容")];
        return;
    }
    Class fwdCls = NSClassFromString(@"WKForwardSelectVC");
    if (!fwdCls) return;
    UIViewController *vc = [fwdCls new];
    vc.title = LLang(@"选择聊天");
    void (^onConfirm)(NSArray *) = ^(NSArray *channels) {
        [self performForwardToChannels:channels content:content];
    };
    [vc setValue:onConfirm forKey:@"onConfirmChannels"];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)performForwardToChannels:(NSArray *)channels content:(NSString *)content {
    if (channels.count == 0) return;
    NSInteger okCount = 0, failCount = 0;
    for (id ch in channels) {
        if (![ch isKindOfClass:WKChannel.class]) { failCount++; continue; }
        WKTextContent *tc = [[WKTextContent alloc] initWithContent:content];
        WKMessage *msg = [[WKSDK shared].chatManager sendMessage:tc channel:(WKChannel *)ch];
        if (msg) okCount++; else failCount++;
    }
    NSString *msg;
    if (failCount == 0) msg = [NSString stringWithFormat:LLang(@"已转发到 %ld 个聊天"), (long)okCount];
    else                msg = [NSString stringWithFormat:LLang(@"成功 %ld / 失败 %ld"), (long)okCount, (long)failCount];
    [self.view showMsg:msg];
}

- (void)onWaitingAction {
    OctoSummaryConfirmVC *vc = [OctoSummaryConfirmVC new];
    vc.detail = self.detail;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
