//
//  WKConversationListVC.m
//  WuKongBase
//
//  Created by tt on 2019/12/15.
//

#import "WKConversationListVC.h"
#import "WKConversationListVM.h"
#import "WKSpaceFilter.h"
#import "WKThreadCreatedContent.h"
#import "WKConversationListCell.h"
#import "WKConversationGroupThreadCell.h"
#import "WKConversationGroupThreadOnlyCell.h"
#import "WKThreadListVC.h"
#import "WKCategoryEntity.h"
#import "WKCategoryService.h"
#import "WKFloatingMenu.h"
#import "WKCategorySectionCell.h"
#import "WKCategoryReorderVC.h"
#import "WKFollowedKeysStore.h"
#import "WKFollowService.h"
#import "WKThreadService.h"
#import "WKThreadModel.h"
#import <objc/runtime.h>
#import <WuKongBase/WuKongBase.h>
#import "WKResource.h"
#import "WKPopMenuView.h"
#import "WKGlobalSearchController.h"
#import "WKSearchbarView.h"
#import "WKGlobalSearchResultController.h"
#import "WKNetworkListener.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKTypingManager.h"
#import "WKTypingContent.h"

// [BotSpaceTrace] 跨 Space Bot 隔离调试日志（PR #118 review）：
// 仅 DEBUG 构建打印，Release 编译为空 —— 防止 channelId / spaceId 等用户标识
// 进入生产环境日志。
#if DEBUG
#define WK_BOT_TRACE(...) NSLog(__VA_ARGS__)
#else
#define WK_BOT_TRACE(...) do {} while(0)
#endif

// [ThreadBadgeDbg] / [ThreadSync] 子区 unread / 关注 badge 链路调试日志
// （PR #137 review 反馈）：仅 DEBUG 构建打印，Release 编译为空。
#if DEBUG
#define WK_THREAD_BADGE_DBG(...) NSLog(__VA_ARGS__)
#else
#define WK_THREAD_BADGE_DBG(...) do {} while(0)
#endif
#import "WKConversationAddItem.h"
#import "WKConversationPasswordVC.h"
#import "WKConversationListTableView.h"
#import "WKConversationListHeaderView.h"
#import "WKConversationTabView.h"
#import "WKOnlineStatusManager.h"
#import "WKMySettingManager.h"
#import "WKMD5Util.h"
#import "WKSpaceModel.h"
#import "WKSpacePopupView.h"
#import "WKSyncService.h"
#import "WKJoinGroupSuccessHelper.h"
#import "WKJoinGroupSuccessDialog.h"
#import "WKConversationVC.h"
#import "WKSpaceConversationCache.h"
#import "WKSpaceConvSyncCache.h"
#import "WKSpaceBotRegistry.h"
#import "WKPCOnlineVC.h"
#import "WKPixelParticleHint.h"
#import "WKThreadModel.h"
@interface WKConversationListVC ()<UITableViewDelegate,UITableViewDataSource,UISearchControllerDelegate,WKConnectionManagerDelegate,WKChannelManagerDelegate,WKConversationManagerDelegate,WKNetworkListenerDelegate,WKChatManagerDelegate,WKTypingManagerDelegate,SwipeTableViewCellDelegate,WKOnlineStatusManagerDelegate,WKReminderManagerDelegate>
@property(nonatomic,copy) NSString *_title;
@property(nonatomic,strong)  WKConversationListTableView *tableView;

@property(nonatomic,strong) WKConversationListVM *conversationListVM;

@property(nonatomic,strong) NSLock *connectLock; // 连接锁

@property(nonatomic,strong) NSRecursiveLock *conversationLock; // 最近会话锁

@property(nonatomic, nonnull,strong) UIView *rightAddItem; // 右边按钮

@property(nonatomic,strong) UIView *networkErroView; // 网络错误视图
@property(nonatomic,strong) UILabel *warnLbl;


//@property(nonatomic,strong) WKSearchbarView *searchbarView;

@property(nonatomic,strong) WKConversationListHeaderView *tableHeader;

//@property(nonatomic,strong) UIView *tableHeaderBottomEmptyView;

@property(nonatomic,strong) NSTimer *refreshTimer; // 定时刷新table的定时器
@property(nonatomic,assign) NSTimeInterval lastLoadTime; // 上次加载时间

// 网络信号监控
@property(nonatomic,assign) NSTimeInterval connectedAtTime; // 连接成功的时间
@property(nonatomic,strong) NSMutableSet<NSNumber *> *shownHintMsgIds; // 已弹过通知的消息ID
@property(nonatomic,assign) NSInteger currentLatencyMs; // 当前延迟（毫秒）
@property(nonatomic,strong) NSTimer *pingTimer; // ping定时器
@property(nonatomic,strong) UIView *signalContainerView; // 信号显示容器
@property(nonatomic,strong) UIImageView *signalImageView; // 信号图标
@property(nonatomic,strong) UILabel *latencyLabel; // 延迟标签
@property(nonatomic,strong) UIButton *pcOnlineBtn; // PC在线小图标
@property(nonatomic,strong) NSTimer *pcOnlineCheckTimer; // PC在线状态轮询定时器

// Space 切换
@property(nonatomic,copy) NSString *currentSpaceName; // 当前 Space 名称
@property(nonatomic,copy) NSString *currentSpaceId; // 当前 Space ID
@property(nonatomic,assign) BOOL spaceListLoaded; // Space列表是否已加载
@property(nonatomic,assign) NSInteger spaceCount; // Space总数
@property(nonatomic,strong) UIImageView *spaceArrowView; // Space标题右侧折叠箭头
@property(nonatomic,assign) BOOL hasCleanedConversationsOnStartup; // 本次启动是否已清理会话数据
@property(nonatomic,strong) WKConversationTabView *conversationTabView; // 群组/私聊 tab
@property(nonatomic,strong) UIView *navLeftView;
@property(nonatomic,strong) UIView *avatarView;
@property(nonatomic,strong) UILabel *avatarLabel;
@property(nonatomic,strong) UILabel *spaceNameLabel;
@property(nonatomic,strong) UIImageView *chevronView;
@property(nonatomic,strong) UIView *fixedHeaderContainer; // 固定在顶部的搜索栏+tab容器
@property(nonatomic,strong) NSArray<WKConversationDisplayItem *> *groupDisplayList; // 群聊 tab 展示列表
@property(nonatomic,strong) UISwipeGestureRecognizer *tabSwipeLeft;
@property(nonatomic,strong) UISwipeGestureRecognizer *tabSwipeRight;
@property(nonatomic,assign) BOOL pendingSpaceSwitchLoad;
/// 切换 Space 期间的 fail-closed 闸门。从 performSwitchToSpaceId: 起到
/// pendingSpaceSwitchLoad 处理完成为止；闸门期内 isConversationInCurrentSpace
/// 的两条向前兼容 fail-open 改为 NO，applyThreadConversationUpdates 调用前
/// 也整批丢弃，避免 A space 残留消息漏入 B。
@property(nonatomic,assign) BOOL spaceSwitchInProgress;
@property(nonatomic,assign) BOOL pendingRebuild;
@property(nonatomic,assign) CGPoint recentTabScrollOffset;
@property(nonatomic,assign) CGPoint followTabScrollOffset;
@property(nonatomic,assign) NSTimeInterval lastFollowedKeysReloadAt; // debounce 用，单位秒

// 关注 tab 拖拽排序（方案 A）— 长按弹菜单后继续按住可拖动到其他分组
@property(nonatomic,strong,nullable) UIView *cellDragSnapshot;
@property(nonatomic,strong,nullable) UIView *cellDragInsertionLine; // 当前手指落点对应的"将插入到这里"指示
@property(nonatomic,strong,nullable) NSIndexPath *cellDragSourceIndexPath;
@property(nonatomic,strong,nullable) NSIndexPath *cellDragLastTargetPath; // 上次更新时落在的 target row
@property(nonatomic,assign) BOOL cellDragLastInsertBelow;
@property(nonatomic,assign) CGPoint cellDragStartLocation; // 在 self.view 坐标系
@property(nonatomic,assign) CGPoint cellDragLastLocation; // 最近一次 update 的位置，autoscroll tick 时复用
@property(nonatomic,assign) BOOL cellDragInProgress;
@property(nonatomic,copy,nullable) NSString *cellDragSourceConvName;
@property(nonatomic,copy,nullable) NSString *cellDragSourceChannelId; // 用于识别源 cell 离场触发清理
/// 拖拽源会话 model — 强引用，保证拖动期间源 cell 被回收/上滚出可视区时
/// endCellDragAtLocation:model: 仍能拿到完整 model 完成 followDM / moveGroup 提交。
@property(nonatomic,strong,nullable) WKConversationWrapModel *cellDragSourceModel;
/// 分组 section header 拖动：拖整段分组重排时记录源 sectionId。非空 → 当前拖动是 section reorder（不是 cell 重排）。
@property(nonatomic,copy,nullable) NSString *cellDragSourceSectionId;
@property(nonatomic,weak,nullable) UITableViewCell *cellDragSourceCell; // 直接 weak 持有源 cell，didEndDisplayingCell 用 == 比较更稳
/// section header 长按时被高亮的 cell（弱引用）— 拖动真正开始 / 手势结束时需要还原视觉。
@property(nonatomic,weak,nullable) WKCategorySectionCell *cellDragHighlightedSectionCell;
/// 表格级统一长按手势 — 装在 self.view 上，生命周期与 VC 同步，不受 cell 复用影响。
/// 取代之前每个 cell 单独装一份的方式：cell 被回收时手势随之销毁会导致 Ended/Cancelled
/// 不触发、snapshot 卡死，并让"拖出界面再回来 snapshot 不见"的 bug 1 也消失。
@property(nonatomic,strong,nullable) UILongPressGestureRecognizer *unifiedLongPress;
@property(nonatomic,strong,nullable) CADisplayLink *cellDragAutoScrollLink;
@property(nonatomic,assign) CGFloat cellDragAutoScrollVelocity; // pts/frame, 0 = 不滚
@property(nonatomic,assign) BOOL pendingRebuildAfterDrag; // 拖动期间收到的刷新请求暂存，结束时回放
@property(nonatomic,assign) BOOL refreshBadgePending; // refreshBadge coalesce：批量事件合并到一次重算

// 关注 tab 空状态引导视图：当前 tab 是 Follow + groupDisplayList 为空时显示
@property(nonatomic,strong,nullable) UIView *followEmptyView;

@end

@implementation WKConversationListVC
-(instancetype) initWithTitle:(NSString*)title {
    self = [super init];
    if(self) {
        self._title = title;
    }
    return self;
}
-(instancetype) init{
    self = [super init];
    if (!self) return self;
    self._title = [WKApp shared].config.appName;
    _conversationListVM = [WKConversationListVM shared];
    [_conversationListVM reset];

    // 初始化网络监控相关属性
    self.connectedAtTime = 0;
    self.shownHintMsgIds = [NSMutableSet set];
    self.currentLatencyMs = -1;

    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];

    // YUJ-bot-isolation: 启动时立即拉取当前 Space 的 Bot 成员名单，给后续
    // isConversationInCurrentSpace 的 Bot gate 提供权威数据；加载完成后会
    // 通过 WKSpaceBotRegistryDidLoadNotification 触发 prune。
    NSString *bootSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(bootSpaceId.length > 0) {
        [[WKSpaceBotRegistry shared] loadBotsForSpace:bootSpaceId completion:nil];
    }

    // 先创建固定头部（搜索栏+tab），再创建 tableView（tableView frame 需要依赖固定头部高度）
    [self setupFixedHeader];
    [self.view addSubview:self.tableView];

    // 左右滑动切换群聊/私聊 tab
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleTabSwipe:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.tableView addGestureRecognizer:swipeLeft];
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleTabSwipe:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.tableView addGestureRecognizer:swipeRight];
    self.tabSwipeLeft = swipeLeft;
    self.tabSwipeRight = swipeRight;
    // tableView 自身的 panGesture 也需要让步给 swipe
    [self.tableView.panGestureRecognizer requireGestureRecognizerToFail:swipeLeft];
    [self.tableView.panGestureRecognizer requireGestureRecognizerToFail:swipeRight];

    self.connectLock = [[NSLock alloc] init];
    self.conversationLock = [[NSRecursiveLock alloc] init];
    [self addDelegates];

    // 恢复上次选中的 tab
    NSInteger savedTab = [[NSUserDefaults standardUserDefaults] integerForKey:@"WKConversationTabIndex"];
    _conversationListVM.filterType = savedTab;
    [_conversationListVM restoreCollapsedSections];
    [_conversationListVM restoreExpandedThreadGroups];
    [self setupConversationTabView];

    // 加载当前 Space 信息
    [self loadCurrentSpace];

    // 加载最近会话列表数据
    __weak __typeof(self) weakSelf  = self;
    [_conversationListVM loadConversationList:^{
        // YUJ-bot-isolation 冷启动 race 兜底（PR #118 review fix）：
        // viewDidLoad 同时发起 loadBotsForSpace（网络）和本 loadConversationList（DB）。
        // 若网络早回 → onSpaceBotRegistryDidLoad 在空 VM 上 prune 等于 no-op；
        // 此处 VM 已被 DB 回灌完成，再做一次 prune 才能擦掉跨 Space 的 stale Bot 行。
        // 若 registry 未回（Unknown）→ 本次 prune no-op，registry 后到时
        // onSpaceBotRegistryDidLoad 会在已 ready 的 VM 上兜底再 prune。两端 callback
        // 都 prune，谁先到都覆盖。
        // 注意：prune 必须在 rebuildGroupDisplayAndReload 之前；removeAtChannnel
        // 只改内存不刷 tableView，先 rebuild 再 prune 会让 stale Bot 行留到下次刷新。
        // 与切 Space 路径（L1210）/ 冷启动无 sync 路径（L1108）三处保持同一节奏。
        NSString *bootSpaceForPrune = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
        if(bootSpaceForPrune.length > 0) {
            [weakSelf.conversationListVM pruneNonCurrentSpaceBotsForSpace:bootSpaceForPrune];
        }
        // 用当前 categoryList（可能为空）构建一次展示列表，确保群聊 tab 能立即显示内容
        [weakSelf rebuildGroupDisplayAndReload];
        [weakSelf refreshBadge];
        // 异步加载分组数据，完成后再次刷新
        [weakSelf loadCategories];
        // : 冷启动 Follow tab 数据源兜底 —— 不等 viewDidAppear 的
        // reloadFollowedKeysIfNeeded（受 30s debounce 影响、且与 viewDidLoad
        // 时序不确定），在 loadCategories 之后并发触发 followStore reload。
        // 标记 lastFollowedKeysReloadAt 让 viewDidAppear 的兜底被 debounce 吞掉，
        // 避免重复打 sidebar/sync。reload 完成后 onFollowedKeysStoreDidUpdate
        // 触发 rebuild，新关注数据就能在第一次可见时尽快到位。
        weakSelf.lastFollowedKeysReloadAt = [NSDate date].timeIntervalSince1970;
        [[WKFollowedKeysStore shared] reload];
    }];

//    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(timerRefreshTable) userInfo:nil repeats:YES];
//
    // PC在线状态移到导航栏图标显示
    [self updatePCOnlineIcon:[WKOnlineStatusManager shared].pcOnline deviceFlag:[WKOnlineStatusManager shared].pcDeviceFlag];

    // 给导航栏标题添加点击手势以切换 Space
    [self setupTitleTapGesture];

    // 初始化标题（即使异步加载未完成也先显示默认标题）
    [self refreshTitle];

    // 表格级统一长按手势 — 取代每个 cell 各自装一份的旧方式。
    // 装在 self.view 上，由 onUnifiedLongPress: 在 Began 反查 indexPath 分发到
    // section header（高亮 + 弹分组管理菜单 + 进入 section 拖拽）或 conversation row
    // （弹会话长按菜单 + Follow tab 进入 cell 拖拽）。生命周期与 VC 同步，cell 复用
    // 不会销毁手势，根治"snapshot 卡死"与"拖出再回来 snapshot 消失"两个 bug。
    [self setupUnifiedLongPressGesture];

    // ⚠️ 临时调试按钮（已隐藏）
    // [self setupStressTestButton];
}

// 给标题添加点击手势
- (void)setupTitleTapGesture {
    CGFloat avatarSize = 32.0f;
    CGFloat hPad = 4.0f;
    CGFloat gap = 6.0f;
    CGFloat chevronSize = 14.0f;
    CGFloat viewH = avatarSize + hPad * 2;

    _avatarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, avatarSize, avatarSize)];
    _avatarView.backgroundColor = [UIColor colorWithRed:0x8B/255.0 green:0x5C/255.0 blue:0xF6/255.0 alpha:1.0];
    _avatarView.layer.cornerRadius = avatarSize / 2.0f;
    _avatarView.layer.masksToBounds = YES;

    _avatarLabel = [[UILabel alloc] initWithFrame:_avatarView.bounds];
    _avatarLabel.textAlignment = NSTextAlignmentCenter;
    _avatarLabel.textColor = [UIColor whiteColor];
    _avatarLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [_avatarView addSubview:_avatarLabel];

    _spaceNameLabel = [[UILabel alloc] init];
    _spaceNameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _spaceNameLabel.textColor = [WKApp shared].config.navBarTitleColor;
    _spaceNameLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    _chevronView = [[UIImageView alloc] initWithImage:[self createChevronDownImage]];
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    _chevronView.frame = CGRectMake(0, 0, chevronSize, chevronSize);

    CGFloat maxNameWidth = WKScreenWidth - 16 - avatarSize - gap * 2 - chevronSize - hPad * 2 - 120;
    _spaceNameLabel.text = self._title ?: [WKApp shared].config.appName;
    [_spaceNameLabel sizeToFit];
    if (_spaceNameLabel.lim_width > maxNameWidth) {
        _spaceNameLabel.lim_width = maxNameWidth;
    }

    CGFloat rightPad = 10.0f;
    CGFloat totalW = hPad + avatarSize + gap + _spaceNameLabel.lim_width + 4 + chevronSize + rightPad;
    _navLeftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, totalW, viewH)];

    // 胶囊背景：浅色模式白色，深色模式深灰
    if (@available(iOS 13.0, *)) {
        _navLeftView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:0.18 alpha:1.0]
                : [UIColor whiteColor];
        }];
    } else {
        _navLeftView.backgroundColor = [UIColor whiteColor];
    }
    _navLeftView.layer.cornerRadius = viewH / 2.0f;
    _navLeftView.layer.masksToBounds = YES;

    _avatarView.frame = CGRectMake(hPad, hPad, avatarSize, avatarSize);
    _spaceNameLabel.frame = CGRectMake(_avatarView.lim_right + gap, (viewH - _spaceNameLabel.lim_height) / 2.0, _spaceNameLabel.lim_width, _spaceNameLabel.lim_height);
    _chevronView.frame = CGRectMake(_spaceNameLabel.lim_right + 4, (viewH - chevronSize) / 2.0, chevronSize, chevronSize);

    [_navLeftView addSubview:_avatarView];
    [_navLeftView addSubview:_spaceNameLabel];
    [_navLeftView addSubview:_chevronView];

    _navLeftView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(spaceButtonTapped)];
    [_navLeftView addGestureRecognizer:tapGesture];

    self.navigationBar.leftView = _navLeftView;
    _spaceArrowView = _chevronView;
}

// 加载当前 Space 信息
- (void)loadCurrentSpace {
    // 从本地获取当前 Space ID
    self.currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];

    if (self.currentSpaceId && self.currentSpaceId.length > 0) {
        NSString *lastSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"WKLastLoadedSpaceId"];
        // 每次App启动都清空旧会话数据，等待sync重新填充当前空间的会话
        // 原因：群聊消息不带space_id，无法通过消息内容过滤归属空间
        //       DB中可能积累了其他空间的群聊（通过实时消息推送写入），
        //       只有deleteAllConversation + sync才能确保DB只包含当前空间的会话
        // 使用hasCleanedConversationsOnStartup防止reconnect时重复清理
        NSLog(@"[ConvDebug] loadCurrentSpace: hasCleanedOnStartup=%d, lastSpaceId=%@, currentSpaceId=%@", self.hasCleanedConversationsOnStartup, lastSpaceId, self.currentSpaceId);
        if (!self.hasCleanedConversationsOnStartup || !lastSpaceId || ![lastSpaceId isEqualToString:self.currentSpaceId]) {
            self.hasCleanedConversationsOnStartup = YES;
            NSLog(@"[ConvDebug] 🔄 CLEARING all conversations for space switch!");
            [self.conversationListVM reset];
            [[WKConversationDB shared] deleteAllConversation];
            [self rebuildGroupDisplayAndReload];
            // 记录当前空间
            [[NSUserDefaults standardUserDefaults] setObject:self.currentSpaceId forKey:@"WKLastLoadedSpaceId"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        // 从缓存或网络获取 Space 列表
        __weak typeof(self) weakSelf = self;
        [[WKSpaceModel shared] getMySpaces].then(^(NSArray<WKSpaceEntity *> *spaces){
            weakSelf.spaceListLoaded = YES;  // 标记已加载
            weakSelf.spaceCount = spaces.count;
            for (WKSpaceEntity *space in spaces) {
                if ([space.space_id isEqualToString:weakSelf.currentSpaceId]) {
                    weakSelf.currentSpaceName = space.name;
                    // 立即更新标题（不需要等待IM连接）
                    [weakSelf refreshTitle];
                    break;
                }
            }
        }).catch(^(NSError *error){
            NSLog(@"加载 Space 失败: %@", error);
            weakSelf.spaceListLoaded = NO;  // 加载失败
        });
    }
}

-(void) timerRefreshTable {
    [self refreshTableNoSort];
}

// 开启大标题模式
- (BOOL)largeTitle {
    return NO;
}

-(void) viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
}


// 设置自定义标题
-(void) setCustomTitle:(NSString*)title {
    self.navigationBar.title = title;
}

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self refreshTitle];
    [self hiddenRightItem:NO];

    BOOL pcOnline = [WKOnlineStatusManager shared].pcOnline;
    self.pcOnlineBtn.hidden = !pcOnline;
    [self relayoutRightItems];

    // 频繁切换 tab 时节流，2 秒内不重复加载
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - self.lastLoadTime < 2) {
        return;
    }
    self.lastLoadTime = now;

    // 交互式转场（右滑返回）期间不做同步 DB 查询，延迟到转场完成后执行
    id<UIViewControllerTransitionCoordinator> coordinator = self.transitionCoordinator;
    if (coordinator && coordinator.isInteractive) {
        __weak typeof(self) weakSelf = self;
        [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if (!context.isCancelled) {
                [weakSelf deferredLoadConversationList];
            }
        }];
        return;
    }

    [self deferredLoadConversationList];
}

-(void) deferredLoadConversationList {
    __weak typeof(self) weakSelf = self;
    [self.conversationListVM loadConversationList:^{
        [weakSelf rebuildGroupDisplayAndReload];
        [weakSelf refreshBadge];
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if(!self.refreshTimer) {
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(timerRefreshTable) userInfo:nil repeats:YES];
    }

    // 如果已连接，启动 ping 监控
    if ([WKSDK shared].connectionManager.connectStatus == WKConnected) {
        if (self.connectedAtTime == 0) {
            self.connectedAtTime = [[NSDate date] timeIntervalSince1970];
        }
        [self startPingMonitoring];
    }

    // 启动 PC 在线状态轮询（服务器只推送登录不推送退出，需要轮询检测退出）
    [self startPCOnlineCheckTimer];

    // : 消费跨 Space 加群通知（见 WKGroupScanJoinVC.joinBtnPressed）。
    // 放在 viewDidAppear 而非 viewWillAppear — WKGroupScanJoinVC pop 的动画
    // 完成后主列表才真正回到前台，这时候 window 才有资格承载 Dialog。
    [self consumeJoinGroupSuccessNoticeIfAny];

    // 关注 tab 兜底刷新：app 切回前台/列表回到前台时同步一次 sidebar。
    // debounce ≥30s 在 reloadFollowedKeysIfNeeded 内部判断。
    [self reloadFollowedKeysIfNeeded:@"viewDidAppear"];
}

/// : 消费一次性「跨 Space 加群成功」通知 — 弹双行 dialog + 紫色切换按钮。
/// 本方法被设计成幂等且每次 viewDidAppear 调用 — Helper 的 consumeNotice 保证
/// 读后即清，不会重复弹窗。
- (void)consumeJoinGroupSuccessNoticeIfAny {
    WKJoinGroupSuccessNotice *notice = [WKJoinGroupSuccessHelper consumeNotice];
    if (!notice) { return; }

    __weak typeof(self) weakSelf = self;
    [WKJoinGroupSuccessDialog showWithNotice:notice onSwitch:^{
        // 先切 Space — 切换完成后 push 到目标群。
        // 硬约束：只有用户显式点击才走到这里，dialog 的 cancel/backdrop 分支不会触发。
        [weakSelf performSwitchToSpaceId:notice.targetSpaceId
                               spaceName:notice.spaceName
                              completion:^{
            // 切换后直接进入目标群。用 replacePush 避免栈里堆积空壳。
            WKConversationVC *vc = [WKConversationVC new];
            vc.channel = [[WKChannel alloc] initWith:notice.groupNo channelType:WK_GROUP];
            [[WKNavigationManager shared] pushViewController:vc animated:YES];
        }];
    }];
}

-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // 在 dismiss / push 真正发生前提前结束拖拽 —— 半屏 sheet、push 别的 VC 等场景下
    // viewDidDisappear 触发可能滞后，提前清理避免 snapshot 在过渡动画里残留。
    if (self.cellDragInProgress
        || self.cellDragSourceChannelId.length > 0
        || self.cellDragSourceSectionId.length > 0
        || self.cellDragHighlightedSectionCell != nil) {
        [self resetCellDragState];
    }
}

-(void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    // 防 drag snapshot 卡在屏上：界面消失时强制清理
    [self resetCellDragState];
    if(self.refreshTimer) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }
    [self stopPCOnlineCheckTimer];

    // 停止 ping 监控
    [self stopPingMonitoring];

    [self hiddenRightItem:YES];
}


-(void) addDelegates {
    // 添加连接监听
    [[[WKSDK shared] connectionManager] addDelegate:self];
    // 频道信息监听
    [[[WKSDK shared] channelManager] addDelegate:self];
    // 最近会话监听
    [[[WKSDK shared] conversationManager] addDelegate:self];
    // 网络监听
    [[WKNetworkListener shared] addDelegate:self];
    // 消息监听
    [[WKSDK shared].chatManager addDelegate:self];
    // 正在输入...
    [[WKTypingManager shared] addDelegate:self];
    // 在线状态
    [[WKOnlineStatusManager shared] addDelegate:self];
    // 监听当前空间新建群聊，立即加入白名单
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onGroupCreatedInCurrentSpace:) name:@"WKGroupCreatedInCurrentSpace" object:nil];
    // 提醒项（@我）变化监听
    [[WKReminderManager shared] addDelegate:self];
    // 监听子区数量批量更新（统一 reloadData，不逐行刷新）
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onThreadCountBatchUpdated:) name:@"WKThreadCountBatchUpdated" object:nil];
    // 监听"创建分组"弹窗请求
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showCreateCategoryDialog) name:@"WKShowCreateCategoryDialog" object:nil];
    // YUJ-bot-isolation: 当前 Space 的 Bot 列表加载完成 → prune 切换瞬间 race 浮上来的旧 Space Bot
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSpaceBotRegistryDidLoad:) name:WKSpaceBotRegistryDidLoadNotification object:nil];
    // 关注 tab 兜底刷新：app 切回前台时拉一次 sidebar/sync 同步 followedKeys + follow_version
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    // app 退到后台 / 被来电等系统事件打断时，强制结束拖拽 —— 否则恢复后 snapshot
    // 可能还挂在 window 上，配合手势状态已 reset，会出现"卡死的悬浮 cell"。
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    // followedKeys 更新（reload 后 / 写操作后）→ 关注 tab 重建展示列表，让新加/取消的 DM 在分组里立即生效
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFollowedKeysStoreDidUpdate:) name:kWKFollowedKeysStoreDidUpdateNotification object:nil];
}

-(void) removeDelegates {
    [[WKReminderManager shared] removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"WKShowCreateCategoryDialog" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"WKThreadCountBatchUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKSpaceBotRegistryDidLoadNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kWKFollowedKeysStoreDidUpdateNotification object:nil];
    // 移除连接监听
    [[[WKSDK shared] connectionManager] removeDelegate:self];
    // 移除频道监听
    [[[WKSDK shared] channelManager] removeDelegate:self];
    // 移除最近会话监听
    [[[WKSDK shared] conversationManager] removeDelegate:self];
    // 网络监听
    [[WKNetworkListener shared] removeDelegate:self];
    // 移除消息监听
    [[WKSDK shared].chatManager removeDelegate:self];
    // 正在输入...
    [[WKTypingManager shared] removeDelegate:self];
    // 在线状态
    [[WKOnlineStatusManager shared] removeDelegate:self];
    // 移除群聊创建通知监听
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"WKGroupCreatedInCurrentSpace" object:nil];
}

-(UIView*) rightAddItem {
    if (!_rightAddItem) {
        CGFloat itemH = 32.0f;
        CGFloat iconSize = 20.0f;
        CGFloat btnSize = 24.0f;
        CGFloat gap = 14.0f;

        // 信号容器（图标+延迟文字）— 保留全部信号监控逻辑
        self.signalContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 60, itemH)];
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(signalTapped)];
        [self.signalContainerView addGestureRecognizer:tapGesture];
        self.signalContainerView.userInteractionEnabled = YES;

        self.signalImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, (itemH - 14) / 2, 16, 14)];
        self.signalImageView.image = [self createSignalBarsImage];
        [self.signalContainerView addSubview:self.signalImageView];

        self.latencyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, 40, itemH)];
        self.latencyLabel.font = [UIFont systemFontOfSize:11.0f];
        self.latencyLabel.textAlignment = NSTextAlignmentLeft;
        [self.signalContainerView addSubview:self.latencyLabel];

        // PC/Web 在线图标（默认隐藏）— SVG monitor + green dot
        self.pcOnlineBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.pcOnlineBtn.frame = CGRectMake(0, 0, iconSize, iconSize);
        [self.pcOnlineBtn setImage:[self createMonitorOnlineImage] forState:UIControlStateNormal];
        [self.pcOnlineBtn addTarget:self action:@selector(pcOnlineIconTapped) forControlEvents:UIControlEventTouchUpInside];
        self.pcOnlineBtn.hidden = YES;

        // 加号按钮
        UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        addBtn.tag = 8888;
        addBtn.frame = CGRectMake(0, 0, btnSize, btnSize);
        [addBtn setImage:[self createPlusImage] forState:UIControlStateNormal];
        addBtn.tintColor = [WKApp shared].config.navBarButtonColor;
        [addBtn addTarget:self action:@selector(rightAddPressed) forControlEvents:UIControlEventTouchUpInside];

        _rightAddItem = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, itemH)];
        [_rightAddItem addSubview:self.signalContainerView];
        [_rightAddItem addSubview:self.pcOnlineBtn];
        [_rightAddItem addSubview:addBtn];

        [self updateSignalViewForStatus:[WKSDK shared].connectionManager.connectStatus];
        self.pcOnlineBtn.hidden = YES;

        [self relayoutRightItems];
    }
    return _rightAddItem;
}

- (void)updatePCOnlineIcon:(BOOL)online deviceFlag:(WKDeviceFlagEnum)deviceFlag {
    NSLog(@"[PCDebug] updatePCOnlineIcon: online=%d, deviceFlag=%ld", online, (long)deviceFlag);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.pcOnlineBtn.hidden = !online;
        [self relayoutRightItems];
    });
}

- (void)startPCOnlineCheckTimer {
    [self stopPCOnlineCheckTimer];
    __weak typeof(self) ws = self;
    self.pcOnlineCheckTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 repeats:YES block:^(NSTimer *t) {
        // 只在 PC 图标显示时才需要轮询检测退出
        if (!ws.pcOnlineBtn.hidden) {
            NSLog(@"[PCDebug] pcOnlineCheckTimer fired, icon visible, polling server");
            [WKOnlineStatusManager shared].needUpdate = YES;
            [[WKOnlineStatusManager shared] requestUpdateChannelOnlineStatusIfNeed];
        }
    }];
}

- (void)stopPCOnlineCheckTimer {
    [self.pcOnlineCheckTimer invalidate];
    self.pcOnlineCheckTimer = nil;
}

/// 根据 PC 图标显隐动态重排右侧元素（从左到右：信号 → PC图标 → 加号）
- (void)relayoutRightItems {
    if (!_rightAddItem) return;
    CGFloat itemH = 32.0f;
    CGFloat gap = 14.0f;
    CGFloat btnSize = 24.0f;
    CGFloat pcIconSize = 20.0f;

    UIView *addBtn = [_rightAddItem viewWithTag:8888];

    CGFloat x = 0;
    self.signalContainerView.frame = CGRectMake(x, 0, 60, itemH);
    x += 60 + gap;

    if (!self.pcOnlineBtn.hidden) {
        self.pcOnlineBtn.frame = CGRectMake(x, (itemH - pcIconSize) / 2, pcIconSize, pcIconSize);
        x += pcIconSize + gap;
    }

    if (addBtn) {
        addBtn.frame = CGRectMake(x, (itemH - btnSize) / 2, btnSize, btnSize);
        x += btnSize;
    }

    _rightAddItem.frame = CGRectMake(0, 0, x, itemH);
    self.rightView = _rightAddItem;
}

- (void)pcOnlineIconTapped {
    WKPCOnlineVC *vc = [WKPCOnlineVC new];
    vc.mute = [WKMySettingManager shared].muteOfApp;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

-(void) hiddenRightItem:(BOOL)hidden {
    UIView *rightItem = nil;
    if(!hidden) {
        rightItem = self.rightAddItem;
    }
    self.rightView = rightItem;
}

-(void) rightAddPressed {
    
    NSArray<WKConversationAddItem*> *items = [[WKApp shared] invokes:WKPOINT_CATEGORY_CONVERSATION_ADD param:nil];
    
    CGFloat statusHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
    NSMutableArray *itemDicts = [NSMutableArray array];
    if(items && items.count>0) {
        for (WKConversationAddItem *item in items) {
            [itemDicts addObject:@{
                @"title":item.title?:@"",
                @"image": item.icon,
            }];
        }
    }
    [WKPopMenuView showWithItems:itemDicts width:140.0f triangleLocation:CGPointMake(WKScreenWidth-30, self.navigationController.navigationBar.lim_height + statusHeight-4.0f) action:^(NSInteger index) {
        WKConversationAddItem *item = [items objectAtIndex:index];
        if(item.onClick) {
            item.onClick();
        }
    }];
}

-(void) refreshTitle{
    [self.connectLock lock];

    if (self.currentSpaceName && self.currentSpaceName.length > 0) {
        self._title = self.currentSpaceName;
    } else {
        self._title = [WKApp shared].config.appName;
    }

    if (_spaceNameLabel) {
        CGFloat hPad = 4.0f;
        CGFloat avatarSize = 32.0f;
        CGFloat gap = 6.0f;
        CGFloat chevronSize = 14.0f;
        CGFloat rightPad = 10.0f;
        CGFloat viewH = avatarSize + hPad * 2;

        _spaceNameLabel.text = self._title;
        [_spaceNameLabel sizeToFit];
        CGFloat maxNameWidth = WKScreenWidth - 16 - avatarSize - gap * 2 - chevronSize - hPad * 2 - 120;
        if (_spaceNameLabel.lim_width > maxNameWidth) {
            _spaceNameLabel.lim_width = maxNameWidth;
        }
        _spaceNameLabel.frame = CGRectMake(_avatarView.lim_right + gap, (viewH - _spaceNameLabel.lim_height) / 2.0, _spaceNameLabel.lim_width, _spaceNameLabel.lim_height);
        _chevronView.frame = CGRectMake(_spaceNameLabel.lim_right + 4, (viewH - chevronSize) / 2.0, chevronSize, chevronSize);
        _navLeftView.lim_width = _chevronView.lim_right + rightPad;
        self.navigationBar.leftView = _navLeftView;
    } else {
        [self setCustomTitle:self._title];
    }

    if (_avatarLabel && self._title.length > 0) {
        _avatarLabel.text = [self._title substringToIndex:1];
    }

    [self.connectLock unlock];
}

- (void)setSpaceArrowExpanded:(BOOL)expanded {
    if (!_chevronView) return;
    [UIView animateWithDuration:0.2 animations:^{
        self->_chevronView.transform = expanded ? CGAffineTransformMakeRotation(M_PI) : CGAffineTransformIdentity;
    }];
}

// 标题点击事件 - 通过导航栏标题触发
- (void)spaceButtonTapped {
    NSLog(@"🔘 Space标题被点击");

    // 检查Space列表是否已加载
    if (!self.spaceListLoaded) {
        NSLog(@"⚠️ Space列表未加载，禁止点击");
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (window) {
            [window showMsg:@"正在加载空间列表..."];
        }
        return;
    }

    // 只有在已连接状态才允许切换 Space
    WKConnectStatus status = [WKSDK shared].connectionManager.connectStatus;
    if (status != WKConnected) {
        NSLog(@"⚠️ 当前未连接，无法切换 Space (status=%ld)", (long)status);
        // 显示提示
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (window) {
            [window showMsg:@"请等待连接成功后再切换空间"];
        }
        return;
    }

    NSLog(@"✅ 准备显示Space选择器");
    WKSpacePopupView *popupView = [[WKSpacePopupView alloc] init];
    popupView.currentSpaceId = self.currentSpaceId;

    // 箭头切换为向下（展开状态）
    [self setSpaceArrowExpanded:YES];

    __weak typeof(self) weakSelf = self;

    // 弹窗关闭时箭头切换回向右
    popupView.onDismiss = ^{
        [weakSelf setSpaceArrowExpanded:NO];
    };

    popupView.onSpaceSelected = ^(WKSpaceEntity *space) {
        NSLog(@"✅ Space选中: %@", space.name);
        if (!space || !space.space_id || space.space_id.length == 0) {
            return;
        }
        [weakSelf performSwitchToSpaceId:space.space_id spaceName:space.name completion:nil];
    };

    [popupView showFromView:_navLeftView ?: self.navigationBar.titleLabel];
}

/// : 抽出的 Space 切换执行体 — 原 `onSpaceSelected` 闭包内的实现，
/// 由 popup 选择 + 跨 Space 加群 dialog「切换过去」按钮共用，行为必须完全一致
/// （清缓存 → 重置 VM → 重新同步会话 + 联系人）。
- (void)performSwitchToSpaceId:(NSString *)spaceId
                     spaceName:(nullable NSString *)spaceName
                    completion:(nullable void(^)(void))completion {
    if (!spaceId || spaceId.length == 0) {
        if (completion) { completion(); }
        return;
    }

    // 检查是否是当前Space
    if ([spaceId isEqualToString:self.currentSpaceId]) {
        NSLog(@"ℹ️ 目标即当前 Space，无需切换");
        if (completion) { completion(); }
        return;
    }

    self.currentSpaceName = spaceName ?: @"";
    self.currentSpaceId = spaceId;
    // 开 fail-closed 闸门 —— B 的 sync 数据 + 白名单 snapshot 未就绪前,
    // 把所有 fail-open / nil-fail-open 路径翻成 NO，避免 A space 残留消息漏入 B。
    self.spaceSwitchInProgress = YES;
    // 兜底：万一 sync 永不回包（断网等），8s 后自动落闸，恢复正常 fail-open 行为
    __weak typeof(self) weakSelfSwitchGate = self;
    NSString *gateSpaceId = spaceId;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakSelfSwitchGate.spaceSwitchInProgress
            && [weakSelfSwitchGate.currentSpaceId isEqualToString:gateSpaceId]) {
            NSLog(@"[SpaceGate] 8s 超时兜底落闸 spaceId=%@", gateSpaceId);
            weakSelfSwitchGate.spaceSwitchInProgress = NO;
        }
    });

    // 清除分组缓存
    [[WKCategoryService shared] invalidateCache];

    // 先保存新的 Space ID（conversation/sync 会从 NSUserDefaults 读取）
    [[NSUserDefaults standardUserDefaults] setObject:spaceId forKey:@"currentSpaceId"];
    [[NSUserDefaults standardUserDefaults] setObject:spaceId forKey:@"WKLastLoadedSpaceId"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // 清空 space_unread / space_last_message 缓存（新空间会重新同步）
    [[WKSpaceConversationCache shared] clearAll];
    // 清空 conv sync 预填的 space_id 内存缓存（新空间下 sync 会再次填充）
    [[WKSpaceConvSyncCache shared] clearAll];

    // YUJ-bot-isolation: 切 Space → 重新拉取该 Space 的 Bot 列表。
    // 加载完成会广播 WKSpaceBotRegistryDidLoadNotification，由 viewDidLoad 注册的
    // 监听者触发 pruneNonCurrentSpaceBots，清掉切换瞬间从 SDK 浮上来的旧 Space Bot。
    [[WKSpaceBotRegistry shared] resetAllCaches];
    [[WKSpaceBotRegistry shared] loadBotsForSpace:spaceId completion:nil];

    // 更新标题
    [self refreshTitle];

    // 参考 Web/Android 端：清空本地会话数据后重新从服务器同步
    // 1. 清空 VM 数据和本地会话数据库
    [self.conversationListVM reset];
    [[WKConversationDB shared] deleteAllConversation];

    // : 关注 tab 跨空间残留修复 —— FollowedKeysStore 是单例，
    // followedGroupNos / itemsByCategory 都是 A space 的数据；新空间的 categoryList
    // 拉回来后，buildGroupDisplayList 会用旧 followedGroupNos 去过滤新 cat.groups，
    // 命中 0 条 → 用户视角是"切完空间分组下面没有任何会话"。这里 fail-closed
    // 把 store 状态打回未加载，紧跟下面 pendingSpaceSwitchLoad 完成块里的 reload
    // 拉新空间数据；中间的渲染窗口里 buildGroupDisplayList 走 followLoaded=NO
    // 分支，section 内只出 header（与切换瞬间的"空列表"语义一致）。
    [[WKFollowedKeysStore shared] reset];
    self.lastFollowedKeysReloadAt = 0; // 解除 30s debounce，避免下面 reload 被吞

    // 2. 先刷新 UI 显示空列表
    [self rebuildGroupDisplayAndReload];

    // 3. 通过 syncConversationProvider 重新同步会话（会带上新的 space_id）
    __weak typeof(self) weakSelf = self;
    WKSyncConversationProvider provider = [WKSDK shared].conversationManager.syncConversationProvider;
    WKSyncConversationAck ack = [WKSDK shared].conversationManager.syncConversationAck;
    if (provider) {
        long long version = [[WKConversationDB shared] getConversationMaxVersion];
        NSString *syncKey = [[WKConversationDB shared] getConversationSyncKey];
        provider(version, syncKey, ^(WKSyncConversationWrapModel * _Nullable model, NSError * _Nullable error) {
            if (error) {
                NSLog(@"❌ Space会话同步失败: %@", error);
                return;
            }
            // 保存到本地数据库并触发回调
            if (model) {
                [[WKSDK shared].conversationManager handleSyncConversation:model];
            }
            // 回执
            if (ack) {
                ack(0, ^(NSError * _Nullable ackError) {
                    if (ackError) {
                        NSLog(@"❌ 会话同步回执失败: %@", ackError);
                    }
                });
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                // 不直接调 loadConversationList：handleSyncConversation 是异步的，
                // DB 写入还没完成，此时查 DB 会返回空数据。
                // 设标记，等 onConversationUpdate 回调（DB 写入完成后触发）再加载。
                weakSelf.pendingSpaceSwitchLoad = YES;
            });
        });
    }

    // 4. 触发联系人重新同步
    [[WKSyncService shared] syncContacts:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ 联系人同步失败: %@", error);
        } else {
            NSLog(@"✅ 联系人同步成功");
        }
    }];

    if (completion) {
        // 切换是异步（后台同步），但 UserDefaults 和 VM 状态都已同步就绪，
        // caller push 目标群聊可立即进行 — 进群视图会拿到新 space_id 查询。
        completion();
    }
}

/// 创建固定在顶部的搜索栏容器（不随 tableView 滚动）
-(void) setupFixedHeader {
    CGFloat navBottom = self.navigationBar.lim_bottom;
    _fixedHeaderContainer = [[UIView alloc] initWithFrame:CGRectMake(0, navBottom, WKScreenWidth, 0)];
    _fixedHeaderContainer.backgroundColor = [WKApp shared].config.backgroundColor;

    WKSearchbarView *searchbar = [[WKSearchbarView alloc] initWithFrame:CGRectMake(15, 6, WKScreenWidth - 30, 36)];
    searchbar.placeholder = LLang(@"搜索");
    searchbar.layer.masksToBounds = YES;
    searchbar.onClick = ^{
        WKGlobalSearchResultController *vc = [WKGlobalSearchResultController new];
        [[WKNavigationManager shared] pushViewController:vc animated:NO];
    };
    searchbar.tag = 9990;
    [_fixedHeaderContainer addSubview:searchbar];

    [self.view addSubview:_fixedHeaderContainer];
}

/// 重新布局固定头部（搜索栏 + tabView）并调整 tableView 的 frame
-(void) layoutFixedHeader {
    CGFloat navBottom = self.navigationBar.lim_bottom;
    CGFloat y = 0;

    // 搜索栏（左右 15pt 间距）
    UIView *searchbar = [_fixedHeaderContainer viewWithTag:9990];
    if (searchbar && !searchbar.hidden) {
        searchbar.frame = CGRectMake(15, y + 6, WKScreenWidth - 30, 36);
        y = searchbar.lim_bottom + 6;
    }

    // tab 栏
    if (_conversationTabView) {
        _conversationTabView.frame = CGRectMake(0, y, WKScreenWidth, 44);
        y = _conversationTabView.lim_bottom;
    }

    _fixedHeaderContainer.frame = CGRectMake(0, navBottom, WKScreenWidth, y);

    // 调整 tableView 位置到固定头部下方
    CGFloat tableTop = _fixedHeaderContainer.lim_bottom;
    self.tableView.frame = CGRectMake(0, tableTop, self.view.lim_width, self.view.lim_height - tableTop);
}

- (WKConversationListTableView *)tableView{
    if (!_tableView) {
        _tableView = [[WKConversationListTableView alloc] initWithFrame:[self visibleRect] style:UITableViewStyleGrouped];
        _tableView.dataSource = self;
        _tableView.delegate = self;
//        _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UIEdgeInsets separatorInset = _tableView.separatorInset;
        separatorInset.right          = 0;
        _tableView.separatorInset = separatorInset;
        _tableView.backgroundColor=[UIColor clearColor];
        _tableView.sectionIndexBackgroundColor = [UIColor clearColor];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        // tabbar高度 + 额外边距，确保最后一行完整显示
        CGFloat tabBarHeight = self.tabBarController.tabBar.frame.size.height ?: 49;
        _tableView.contentInset = UIEdgeInsetsMake(0, 0, tabBarHeight + 10, 0);
        _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(-0.1f, 0.0f, 0.0f, 0.0f);
        _tableView.tableFooterView = [[UIView alloc] init];
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.sectionHeaderHeight = 0.0f;
        _tableView.sectionFooterHeight = 0.0f;
        
        // 搜索栏和 tab 已移到固定头部，不再使用 tableHeaderView
        _tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, CGFLOAT_MIN)];

        [_tableView registerClass:[WKConversationListCell class] forCellReuseIdentifier:@"WKConversationListCell"];
        [_tableView registerClass:[WKConversationGroupThreadCell class] forCellReuseIdentifier:@"WKConversationGroupThreadCell"];
        [_tableView registerClass:[WKConversationGroupThreadOnlyCell class] forCellReuseIdentifier:@"WKConversationGroupThreadOnlyCell"];
        [_tableView registerClass:[WKCategorySectionCell class] forCellReuseIdentifier:@"WKCategorySectionCell"];
    }
    return _tableView;
}


#define networkErrorViewHeight 50.0f
-(WKConversationListHeaderView*) tableHeader {
    if(!_tableHeader) {
        _tableHeader = [[WKConversationListHeaderView alloc] init];
        _tableHeader.backgroundColor = [UIColor clearColor];
//        _tableHeader.showEmpty = true;
//        [_tableHeader addSubview:self.searchbarView];

//        _tableHeader.lim_height = self.searchbarView.frame.size.height+20.0f;
        
//        self.tableHeaderBottomEmptyView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.searchbarView.lim_bottom+10.0f, WKScreenWidth, 10.0f)];
//        [self.tableHeaderBottomEmptyView setBackgroundColor:[UIColor whiteColor]];
//        [_tableHeader addSubview:self.tableHeaderBottomEmptyView];
    }
    return _tableHeader;
}

-(void) showNetworkError:(BOOL) show {
    self.tableHeader.showNetworkError = show;
    [self rebuildGroupDisplayAndReload];
     
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    [self.navigationBar setBackgroundColor:[WKApp shared].config.navBackgroudColor];
    if([WKApp shared].config.style == WKSystemStyleDark) {
        self.navigationBar.style = WKNavigationBarStyleDark;
    }else {
        self.navigationBar.style = WKNavigationBarStyleDefault;
    }
    [self.tableHeader viewConfigChange:type];
    [self refreshTable];
}

- (UIView *)networkErroView {
    if(!_networkErroView) {
        _networkErroView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, networkErrorViewHeight)];
        UIImageView *warnIcon = [[UIImageView alloc] initWithFrame:CGRectMake(20.0f, 0.0f, 26.0f, 26.0f)];
        [warnIcon setImage:[self imageName:@"ConversationList/Index/NetworkStatusFail"]];
        warnIcon.lim_top = _networkErroView.lim_height/2.0f - warnIcon.lim_height/2.0f;
        [_networkErroView addSubview:warnIcon];
        
         _warnLbl = [[UILabel alloc] init];
        [_warnLbl setText:LLang(@"当前网络不可用，请检查网络设置")];
        [_warnLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
        [_warnLbl sizeToFit];
        _warnLbl.lim_top = _networkErroView.lim_height/2.0f - _warnLbl.lim_height/2.0f;
        _warnLbl.lim_left = warnIcon.lim_right + 20.0f;
        [_networkErroView addSubview:_warnLbl];
    }
    return _networkErroView;
}

#pragma mark -- WKOnlineStatusManagerDelegate

// 我的pc状态改变
- (void)onlineStatusManagerMyPCOnlineChange:(WKOnlineStatusManager *)manager status:(WKPCOnlineResp *)status {
    NSLog(@"[PCDebug] delegate onlineStatusManagerMyPCOnlineChange: online=%d, deviceFlag=%ld", status.online, (long)status.deviceFlag);
    [self updatePCOnlineIcon:status.online deviceFlag:status.deviceFlag];
}

#pragma mark - WKTypingManagerDelegate

- (void)typingAdd:(WKTypingManager *)manager message:(WKMessage *)message {
    if(message.fromUid && [message.fromUid isEqualToString:[WKApp shared].loginInfo.uid]) {
        return;
    }
    WKChannel *channel = message.channel;
    NSInteger index =  [self.conversationListVM indexAtChannel:channel];
    if(index!=-1) {
        WKConversationWrapModel *model = [self.conversationListVM modelAtIndex:index];
        if(model) {
            WKTypingContent *content = (WKTypingContent*)message.content;
            model.typing = YES;
            model.typer = content.typingName;
            [self safeReloadRows:@[[NSIndexPath indexPathForRow:index inSection:0]] animation:UITableViewRowAnimationNone];
        }
    }
    
}

- (void)typingRemove:(WKTypingManager *)manager message:(WKMessage *)message newMessage:(WKMessage *)newMessage{
    if(message.fromUid && [message.fromUid isEqualToString:[WKApp shared].loginInfo.uid]) {
        return;
    }
    WKChannel *channel = message.channel;
    NSInteger index =  [self.conversationListVM indexAtChannel:channel];
    if(index!=-1) {
        WKConversationWrapModel *model = [self.conversationListVM modelAtIndex:index];
        model.typing = NO;
        [self safeReloadRows:@[[NSIndexPath indexPathForRow:index inSection:0]] animation:UITableViewRowAnimationNone];
        
//        [self refreshTable];
    }
}

-(void) typingReplace:(WKTypingManager*)manager newmessage:(WKMessage*)newmessage oldmessage:(WKMessage*)oldmessage {
    [self typingAdd:manager message:newmessage];
}


#pragma mark - WKChatManagerDelegate

-(void) onMessageUpdate:(WKMessage*) message left:(NSInteger)left{

    NSInteger index = [self.conversationListVM indexAtChannel:message.channel];
    if(index!=-1) {
        WKConversationWrapModel *conversation = [self.conversationListVM modelAtIndex:index];
        if([conversation.lastClientMsgNo isEqualToString:message.clientMsgNo]) {
            [conversation setLastMessage:message];
        }
//
        // 群聊 tab 使用分组展示列表，index 不匹配，直接全量刷新
        if (_conversationListVM.filterType == WKConversationFilterFollow) {
            if (left == 0) [self rebuildGroupDisplayAndReload];
        } else {
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
            if ([cell isKindOfClass:[WKConversationListCell class]]) {
                [(WKConversationListCell *)cell refreshWithModel:conversation];
            }
        }
    }

    if(left == 0 ) {
        [self refreshTable];
    }
}

#pragma mark - WKConnectionManagerDelegate

/**
 连接状态改变
 */
-(void) onConnectStatus:(WKConnectStatus)status reasonCode:(WKReason)reasonCode {
    // 更新标题
    [self refreshTitle];

    // 更新网络信号显示（参考 Web 端：根据状态更新）
    [self updateSignalViewForStatus:status];

    // 处理网络信号监控
    if (status == WKConnected) {
        NSLog(@"[ConvDebug] onConnectStatus: WKConnected, calling loadCurrentSpace + sync");
        // 连接成功，重新加载 Space 信息
        [self loadCurrentSpace];

        // 连接成功后主动同步会话列表（解决首次登录后会话列表为空的问题）
        __weak typeof(self) weakSelf = self;
        WKSyncConversationProvider provider = [WKSDK shared].conversationManager.syncConversationProvider;
        if (provider) {
            long long version = [[WKConversationDB shared] getConversationMaxVersion];
            NSString *syncKey = [[WKConversationDB shared] getConversationSyncKey];
            provider(version, syncKey, ^(WKSyncConversationWrapModel * _Nullable model, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"❌ 连接后会话同步失败: %@", error);
                    return;
                }
                if (model) {
                    // handleSyncConversation 写入 DB 并通过 delegate 更新 UI
                    [[WKSDK shared].conversationManager handleSyncConversation:model];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 不再从 DB 重新加载（handleSyncConversation 的 delegate 已更新内存数据）
                    // 直接记录白名单并刷新分组
                    [weakSelf.conversationListVM snapshotSyncedGroupIds];
                    // : snapshot 后再 prune 一遍，对齐 performSwitchToSpaceId 流程
                    [weakSelf.conversationListVM pruneNonCurrentSpaceGroups];
                    // YUJ-bot-isolation: 同步路径 race 兜底——若 registry 加载早于 sync
                    // 写库，onSpaceBotRegistryDidLoad 那次 prune 跑在空 VM 上没用；这里
                    // VM 已被 handleSyncConversation 回灌，必须重跑一次 bot prune。
                    NSString *curSpaceForPrune = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
                    if(curSpaceForPrune.length > 0) {
                        [weakSelf.conversationListVM pruneNonCurrentSpaceBotsForSpace:curSpaceForPrune];
                    }
                    // : backend sync 可能不返回 botfather（按 X-Space-Id 过滤时）—
                    // 本地兜底合成占位 entry，保证系统 bot 可见；已存在则无操作。
                    [weakSelf.conversationListVM ensureSystemBotsVisible];
                    [weakSelf rebuildGroupDisplayAndReload];
                    [weakSelf refreshBadge];
                    [weakSelf loadCategories];
                });
            });
        } else {
            // 没有 syncProvider 时直接从本地 DB 重新加载
            [self.conversationListVM loadConversationList:^{
                // 无sync时也记录白名单（DB中的数据视为当前空间的）
                [weakSelf.conversationListVM snapshotSyncedGroupIds];
                // : prune 残留（见 performSwitchToSpaceId 注释）
                [weakSelf.conversationListVM pruneNonCurrentSpaceGroups];
                // YUJ-bot-isolation: 同 sync 完成路径，DB 冷启动也必须 bot prune
                // 一次，避免上次 session 残留的跨 Space Bot 行被 sortConversationList 浮回。
                NSString *curSpaceForPrune2 = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
                if(curSpaceForPrune2.length > 0) {
                    [weakSelf.conversationListVM pruneNonCurrentSpaceBotsForSpace:curSpaceForPrune2];
                }
                // : DB 冷启动也兜底（上次 sync 若未写入 botfather，DB 同样缺失）。
                [weakSelf.conversationListVM ensureSystemBotsVisible];
                [weakSelf rebuildGroupDisplayAndReload];
                [weakSelf refreshBadge];
                [weakSelf loadCategories];
            }];
        }

        // 记录时间并开始 ping 监控
        self.connectedAtTime = [[NSDate date] timeIntervalSince1970];
        [self startPingMonitoring];
    } else {
        // 连接中或已断开，停止 ping 监控
        [self stopPingMonitoring];
    }
}

#pragma mark - WKConversationManagerDelegate

// 更新最近会话
- (void)onConversationUpdate:(NSArray<WKConversation*>*)conversations{
    if(!conversations || conversations.count<=0) {
        return;
    }

    // 交互式转场期间暂存更新，转场完成后再处理，避免主线程阻塞导致动画卡顿
    id<UIViewControllerTransitionCoordinator> coordinator = self.transitionCoordinator;
    if (coordinator && coordinator.isInteractive) {
        __weak typeof(self) weakSelf = self;
        [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if (!context.isCancelled) {
                [weakSelf onConversationUpdate:conversations];
            }
        }];
        return;
    }

    // 空间隔离：过滤掉不属于当前空间的会话更新
    NSArray<WKConversation*> *filtered = [self filterConversationsBySpace:conversations];
    // 过滤子区：子区不独立显示在 关注 tab；但 最近 tab 子区是独立行，update 必须能驱动 refresh。
    NSMutableArray<WKConversation*> *nonThreadFiltered = [NSMutableArray array];
    NSMutableArray<WKConversation*> *threadUpdates = [NSMutableArray array];
    NSMutableSet<NSString*> *refreshGroupNos = [NSMutableSet set];
    for (WKConversation *conv in filtered) {
        if (conv.channel.channelType == WK_COMMUNITY_TOPIC) {
            // 关键：thread updates 必须取自 filtered（已经过 filterConversationsBySpace 的 Space 校验），
            // 不能再从原始 conversations 里捞 —— 否则跨 Space 子区会污染 threadWrapModels 进而
            // 出现在 Recent tab 并累计到 badge（PR review #1）。
            [threadUpdates addObject:conv];
            NSString *threadChannelId = conv.channel.channelId;
            NSRange range = [threadChannelId rangeOfString:@"____"];
            if (range.location != NSNotFound) {
                NSString *groupNo = [threadChannelId substringToIndex:range.location];
                [refreshGroupNos addObject:groupNo];
            }
            // 子区消息不走 onMessageUpdate，在这里触发提醒
            if (conv.lastMessage) {
                [self tryShowPixelHintForMessage:conv.lastMessage];
            }
        } else {
            [nonThreadFiltered addObject:conv];
        }
    }
    // 刷新受影响的父群子区数量
    if (refreshGroupNos.count > 0) {
        [self.conversationListVM refreshThreadCountForGroups:refreshGroupNos];
    }
    // 子区 update 必须不论当前 tab 都 apply 进 threadWrapModels —— 否则用户在
    // Follow tab 收到子区消息，切到 Recent 看到的还是旧 preview/时间戳/排序。
    // Follow tab 也要刷一次：cell 上的"+N个子区"badge 数字读 cachedTopicsByGroup,
    // 这次 update 已经被 applyThreadConversationUpdates 并进 cache，但 cell 不重渲染
    // 数字就停在 0；冷启动后第一次收到子区推送即命中此分支。
    if (threadUpdates.count > 0) {
        if (self.spaceSwitchInProgress) {
            NSLog(@"[SpaceGate] drop %d thread updates (switch in progress)", (int)threadUpdates.count);
        } else {
            [self.conversationListVM applyThreadConversationUpdates:threadUpdates];
            if (self.conversationListVM.filterType == WKConversationFilterRecent) {
                [self refreshTable];
                [self refreshBadge];
            } else if (self.conversationListVM.filterType == WKConversationFilterFollow) {
                [self rebuildGroupDisplayAndReload];
                [self refreshBadge];
            }
        }
    }
    filtered = nonThreadFiltered;
    if(filtered.count <= 0) {
        return;
    }

    if(filtered.count>1) {
        for (WKConversation *conversation in filtered) {
            // 私聊 + 群聊都允许触发提醒（子区已在 line 1156 分支处理过，nonThreadFiltered 不含子区）
            if (conversation.lastMessage) {
                NSLog(@"[HintDebug] conv-multi → tryShowPixelHint channelType=%d ch=%@",
                      conversation.channel.channelType, conversation.channel.channelId);
                [self tryShowPixelHintForMessage:conversation.lastMessage];
            }
            [self onlyAddOrUpdateConversation:conversation];
        }
        [self refreshTable];
        [self refreshBadge];
        [self updateGroupMentionBadge];
        // 批量更新后补拉子区数据（网络恢复等场景）
        [self.conversationListVM fetchThreadCountsForGroups];

        // 空间切换后的延迟加载：DB 写入已完成，现在可以安全调 loadConversationList
        if (self.pendingSpaceSwitchLoad) {
            self.pendingSpaceSwitchLoad = NO;
            __weak typeof(self) weakSelf = self;
            [self.conversationListVM loadConversationList:^{
                [weakSelf.conversationListVM snapshotSyncedGroupIds];
                // : Space 切换完成后再扫一遍 VM，把任何 WKSpaceFilter 明确 Skip
                // 的群聊从 conversation array 踢出。reset() 已清空，但 sync 回来的批次
                // 以及中间 onConversationUpdate 里 FailOpen 走回 existsInList 分支都
                // 可能把不该属于当前 Space 的群带回来——最后一次 prune 保证 snapshot
                // 之后的单例内存是干净的。
                [weakSelf.conversationListVM pruneNonCurrentSpaceGroups];
                // YUJ-bot-isolation: race 关键点——performSwitchToSpaceId 里启动了
                // 异步 loadBotsForSpace；若 registry 回包早于本次 reload，
                // onSpaceBotRegistryDidLoad 那次 prune 跑在还没被 sync 回灌的 VM 上
                // 等于空跑。此处 VM 已被 handleSyncConversation 重新填好，必须再
                // prune 一次。即便 registry 还没回来（Unknown），下次回来时仍会
                // 走 onSpaceBotRegistryDidLoad 兜底，两者覆盖所有时序。
                NSString *curSpaceForPrune3 = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
                if(curSpaceForPrune3.length > 0) {
                    [weakSelf.conversationListVM pruneNonCurrentSpaceBotsForSpace:curSpaceForPrune3];
                }
                // : 切 Space 后若 backend sync 在新 Space 未返回 botfather，
                // 本地兜底合成占位 entry，保证用户立即看到系统 bot 入口。
                [weakSelf.conversationListVM ensureSystemBotsVisible];
                // : 切换瞬间漏入的跨 Space 会话兜底总清扫 —— 即便闸门
                // 在某些路径上没拦住（debug 兜底），也能在用户看到列表前最后一次
                // 把不属于当前 Space 的会话从 VM 中清掉。
                NSString *sweepSpace = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
                if(sweepSpace.length > 0) {
                    NSInteger sweptConv = 0, sweptThread = 0;
                    [weakSelf.conversationListVM sweepForeignToSpace:sweepSpace removedCount:&sweptConv removedThreadCount:&sweptThread];
                }
                [weakSelf rebuildGroupDisplayAndReload];
                [weakSelf refreshBadge];
                [weakSelf loadCategories];
                // : 切空间后 followStore 已被 reset，必须显式 reload 拉新空间
                // 的 followed 数据，否则 Follow tab 永远只有 header 没有会话。
                // 走原始 reload 而不是 reloadFollowedKeysIfNeeded，前面已经把
                // lastFollowedKeysReloadAt 清零，这里再标记一次（让后续 30s 内
                // 的兜底刷新被 debounce 吞掉，避免重复打）。reload 完成后
                // onFollowedKeysStoreDidUpdate 会触发 rebuild。
                weakSelf.lastFollowedKeysReloadAt = [NSDate date].timeIntervalSince1970;
                [[WKFollowedKeysStore shared] reload];
                // VM 已被 B 的 sync 数据填好、白名单 snapshot 完成、bot registry
                // 也已尝试加载 → 闸门可落，恢复正常 fail-open 行为
                weakSelf.spaceSwitchInProgress = NO;
            }];
        }

        return;
    }

   WKConversation *conversation = filtered[0];
    // 私聊 + 群聊都允许触发提醒（子区已在前面单独处理）
    if (conversation.lastMessage) {
        NSLog(@"[HintDebug] conv-single → tryShowPixelHint channelType=%d ch=%@",
              conversation.channel.channelType, conversation.channel.channelId);
        [self tryShowPixelHintForMessage:conversation.lastMessage];
    }
    [self uiAddOrUpdateConversationForOne:conversation];
    [self refreshBadge];
    // 无论当前在哪个 tab，都更新群聊 tab 的 @提醒标识
    [self updateGroupMentionBadge];
}
/// 过滤不属于当前空间的会话更新（解决跨空间消息产生红点的问题）
-(NSArray<WKConversation*>*) filterConversationsBySpace:(NSArray<WKConversation*>*)conversations {
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(!currentSpaceId || currentSpaceId.length == 0) {
        return conversations; // 无空间上下文，不过滤
    }
    NSMutableArray<WKConversation*> *filtered = [NSMutableArray array];
    NSMutableArray<NSString*> *unknownGroupChannelIds = [NSMutableArray array]; // 不在白名单中的群聊，待后台验证
    NSString *botfatherUID = [WKApp shared].config.botfatherUID;
    for (WKConversation *conversation in conversations) {
        NSString *channelId = conversation.channel.channelId;
        // 系统通知和文件助手始终通过
        if([channelId isEqualToString:[WKApp shared].config.systemUID] ||
           [channelId isEqualToString:[WKApp shared].config.fileHelperUID]) {
            [filtered addObject:conversation];
            continue;
        }
        // 子区(topic) 严格按父群空间校验，不走 existsInList / 白名单 fail-open 路径（PR review #1B）：
        //   - 解析 channelId 「{groupNo}____{shortId}」拿父群 groupNo
        //   - 父群必须在当前 Space 群白名单内才放行
        //   - 白名单未初始化（reset 后 sync 完成前的 race 窗口）一律拒绝（fail-closed），
        //     避免跨 Space 子区污染 threadWrapModels 进而出现在 Recent / 计入 badge
        if(conversation.channel.channelType == WK_COMMUNITY_TOPIC) {
            NSRange sep = [channelId rangeOfString:@"____"];
            if(sep.location == NSNotFound) continue;
            NSString *parentGroupNo = [channelId substringToIndex:sep.location];
            if(![self.conversationListVM isGroupWhitelistInitialized] ||
               ![self.conversationListVM isGroupInWhitelist:parentGroupNo]) {
                continue;
            }
            [filtered addObject:conversation];
            continue;
        }
        // BotFather空间隔离：新消息到达时自动取消隐藏
        if(botfatherUID && [channelId isEqualToString:botfatherUID]) {
            if(conversation.lastMessage) {
                NSString *msgSpaceId = conversation.lastMessage.content.contentDict[@"space_id"];
                if([msgSpaceId isKindOfClass:[NSString class]] && [msgSpaceId isEqualToString:currentSpaceId]) {
                    // 当前空间有新消息，自动取消隐藏
                    NSString *hiddenKey = [NSString stringWithFormat:@"WKBotFatherHidden_%@", currentSpaceId];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:hiddenKey];
                    [filtered addObject:conversation];
                    continue;
                } else if(msgSpaceId && ![msgSpaceId isKindOfClass:[NSNull class]] && msgSpaceId.length > 0) {
                    // 消息来自其他空间：清除已有WrapModel的缓存，确保预览刷新为当前空间
                    WKConversationWrapModel *existingModel = [self.conversationListVM modelAtChannel:conversation.channel];
                    if(existingModel) {
                        [existingModel reloadLastMessage];
                        // 刷新对应Cell的预览显示
                        if (_conversationListVM.filterType == WKConversationFilterFollow) {
                            [self rebuildGroupDisplayAndReload];
                        } else {
                            NSInteger idx = [self.conversationListVM indexAtChannel:conversation.channel];
                            if(idx != -1) {
                                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]];
                                if([cell isKindOfClass:[WKConversationListCell class]]) {
                                    [(WKConversationListCell *)cell refreshWithModel:existingModel];
                                }
                            }
                        }
                    }
                    continue;
                }
            }
            // BotFather消息没有space_id：仍然让其通过（但预览内容由spaceFilteredLastMessage控制，会展示为空）
            // 检查是否被当前空间隐藏
            NSString *hiddenKey = [NSString stringWithFormat:@"WKBotFatherHidden_%@", currentSpaceId];
            if([[NSUserDefaults standardUserDefaults] boolForKey:hiddenKey]) {
                continue; // 当前空间已隐藏BotFather
            }
            [filtered addObject:conversation];
            continue;
        }
        // : 新消息到达路径必须与冷启动 / Space 切换路径（WKConversationListVM.shouldShowConversation）
        // 对齐——两者都走 WKSpaceFilter。否则外部群收到新消息时会被错挂到 viewer 当前 Space 列表，
        // 污染 conversationListVM 单例的内存状态（DB / SDK 层已正确，见 根因）。
        //   - Keep: channelInfo.space_id == currentSpaceId 或 member.source_space_id == currentSpaceId
        //   - Skip: channelInfo.space_id 明确不匹配且我不是外部成员 → 不加入当前 Space 列表
        //   - FailOpen: channelInfo/member 未缓存，降级走下方白名单 / existsInList 原有逻辑（fail-open 原则）
        if(conversation.channel.channelType == WK_GROUP) {
            WKSpaceFilterDecision decision = [[WKSpaceFilter shared]
                                               decideChannel:channelId
                                                 channelType:conversation.channel.channelType];
            if(decision == WKSpaceFilterDecisionSkip) {
                // 明确归属其它 Space 且我不是当前 Space 的外部成员：
                // 若单例内存中残留该群（历史串台或并发写入导致），同步清理，避免下次
                // sortConversationList / refreshTable 再次浮到顶部。
                if([self.conversationListVM indexAtChannel:conversation.channel] != -1) {
                    [self.conversationListVM removeAtChannnel:conversation.channel];
                }
                continue;
            }
            if(decision == WKSpaceFilterDecisionKeep) {
                // 明确归属当前 Space（owning 或 external-member）→ 直接通过，
                // 不再绕 whitelist / verifyAndAddGroupsToList 走 sync 回兜。
                [filtered addObject:conversation];
                continue;
            }
            // FailOpen：WKChannelInfo 或 member.extra 未缓存（EP1 尚未回写）
            // → 继续走下方原有 existsInList / whitelist / verifyAndAddGroupsToList 兜底路径。
            //
            // : 清残留 + 禁走 existsInList 裸放行。
            // 真机复现：user 在 Space A 打开外部群 EDF，切到 Space B，EDF 新消息 → 错挂 B。
            // 原因：访问 EDF 会触发 SDK 内存/DB 层把 EDF 的 WKConversation 物化到当前进程
            // 的 conversation list 里（即使 Space 切换 reset 了 VM，某些路径——如 SDK
            // conversationManager in-memory cache、后续 re-sync 重放等——仍可能把 EDF
            // 条目带回 VM）。Round-1 只在 Skip 分支做 removeAtChannnel，但 FailOpen 会
            // 直接走到下方 existsInList==YES → [filtered addObject:conversation]，等于
            // 跨 Space 裸放行。现在即便 FailOpen，也先清掉非白名单的残留，再交 unknown
            // 路径 verifyAndAddGroupsToList 异步核验。
            if([self.conversationListVM indexAtChannel:conversation.channel] != -1 &&
               ![self.conversationListVM isGroupInWhitelist:channelId]) {
                [self.conversationListVM removeAtChannnel:conversation.channel];
            }
        }

        // 检查该会话是否已在当前列表中
        BOOL existsInList = [self.conversationListVM indexAtChannel:conversation.channel] != -1;
        if(existsInList) {
            // 已在列表中的 Person 会话：仍需检查消息 space_id，避免跨空间消息产生红点
            if(conversation.channel.channelType == WK_PERSON && conversation.lastMessage) {
                NSString *msgSpaceId = conversation.lastMessage.content.contentDict[@"space_id"];
                if(msgSpaceId && [msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length > 0
                   && ![msgSpaceId isEqualToString:currentSpaceId]) {
                    // 消息来自其他空间：刷新预览但不递增未读数
                    WKConversationWrapModel *existingModel = [self.conversationListVM modelAtChannel:conversation.channel];
                    if(existingModel) {
                        [existingModel reloadLastMessage];
                        if (_conversationListVM.filterType == WKConversationFilterFollow) {
                            [self rebuildGroupDisplayAndReload];
                        } else {
                            NSInteger idx = [self.conversationListVM indexAtChannel:conversation.channel];
                            if(idx != -1) {
                                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]];
                                if([cell isKindOfClass:[WKConversationListCell class]]) {
                                    [(WKConversationListCell *)cell refreshWithModel:existingModel];
                                }
                            }
                        }
                    }
                    continue;
                }
                // YUJ-bot-isolation: 上面只能判出"消息明确带跨 Space space_id"的情况。
                // 裸 Bot DM（无 space_id）会从这里漏过去 → 下游 onlyAddOrUpdateConversation
                // 的 setConversation 把 stale bot 行刷新成跨 Space 内容。这里补一道：
                // 走 isConversationInCurrentSpace（含 prefix / channelInfo space_id /
                // WKSpaceBotRegistry 三层判定）。Skip → 跳过（gate 内部已 removeAtChannnel
                // 兜底清残留）；Keep → 继续 addObject，让消息正常更新当前 Space 列表。
                if(![self isConversationInCurrentSpace:conversation spaceId:currentSpaceId]) {
                    continue;
                }
            }
            [filtered addObject:conversation];
        } else {
            // 群聊不在列表中：检查白名单决定是否允许添加
            if(conversation.channel.channelType == WK_GROUP) {
                // (对齐 Android Round-2 PR#155): 白名单未初始化（nil）时
                // 不再裸放行——强制走 verifyAndAddGroupsToList 回兜。
                // 背景：iOS 原 isGroupInWhitelist 对 nil 返回 YES（pre-sync fail-open），
                // 与 Android 原 spaceConversationKeys.isEmpty() 短路等价。Android PR#155
                // 已证实该短路是跨 Space 串台的 race 窗口：Space 切换后 reset() → nil，
                // sync 完成并 snapshot 之前若 EDF 新消息命中 FailOpen，此处短路放行 →
                // EDF 被 Space B 错挂。
                //   已初始化 + 命中 → 放行（兼容已有流程）
                //   已初始化 + 未命中 → 收集 verify（原行为）
                //   未初始化（race 窗口）→ 也收集 verify，由异步 sync API 核验是否真属于当前 Space
                BOOL whitelistKnows = [self.conversationListVM isGroupWhitelistInitialized] &&
                                      [self.conversationListVM isGroupInWhitelist:channelId];
                if(whitelistKnows) {
                    [filtered addObject:conversation];
                } else {
                    [unknownGroupChannelIds addObject:channelId];
                }
                continue;
            }
            // Person 频道（新会话）：检查消息的 space_id 是否属于当前空间
            // 已在列表中的 Person 会话不受此影响（由 existsInList 分支处理）
            if(conversation.channel.channelType == WK_PERSON) {
                if(![self isConversationInCurrentSpace:conversation spaceId:currentSpaceId]) {
                    continue; // 消息来自其他空间，不添加到当前空间列表
                }
            }
            [filtered addObject:conversation];
        }
    }
    // 对不在白名单中的群聊，后台调 sync API 验证是否属于当前空间
    // 验证通过后单独插入到 tableview（不刷新整个列表）
    if(unknownGroupChannelIds.count > 0) {
        [self verifyAndAddGroupsToList:unknownGroupChannelIds];
    }
    return filtered;
}

/// 后台调用 conversation/sync API 验证群聊是否属于当前空间
/// 验证通过的群聊加入白名单并单独插入到 tableview（不刷新整个列表）
-(void) verifyAndAddGroupsToList:(NSArray<NSString*>*)groupChannelIds {
    static NSTimeInterval lastVerifyTime = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if(now - lastVerifyTime < 2.0) {
        return; // 2秒内不重复触发
    }
    lastVerifyTime = now;

    __weak typeof(self) weakSelf = self;
    WKSyncConversationProvider provider = [WKSDK shared].conversationManager.syncConversationProvider;
    if(!provider) return;

    NSSet *pendingIds = [NSSet setWithArray:groupChannelIds];
    NSLog(@"🔍 后台验证 %lu 个未知群聊是否属于当前空间", (unsigned long)pendingIds.count);

    // 用 version=0 调用 sync API 获取当前空间的所有会话（仅用于验证，不走 handleSyncConversation）
    provider(0, @"", ^(WKSyncConversationWrapModel * _Nullable model, NSError * _Nullable error) {
        if(error || !model) {
            NSLog(@"❌ 群聊空间验证失败: %@", error);
            return;
        }
        // 从 sync 响应中收集当前空间的所有群聊 channelId
        NSMutableSet *spaceGroupIds = [NSMutableSet set];
        for(WKSyncConversationModel *conv in model.conversations) {
            if(conv.channel.channelType == WK_GROUP) {
                [spaceGroupIds addObject:conv.channel.channelId];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            for(NSString *gid in pendingIds) {
                if([spaceGroupIds containsObject:gid]) {
                    // 验证通过：群聊属于当前空间
                    [weakSelf.conversationListVM addGroupToWhitelist:gid];
                    // 避免重复添加
                    WKChannel *channel = [[WKChannel alloc] initWith:gid channelType:WK_GROUP];
                    if([weakSelf.conversationListVM indexAtChannel:channel] == -1) {
                        WKConversation *conv = [[WKSDK shared].conversationManager getConversation:channel];
                        if(conv) {
                            NSLog(@"✅ 群聊 %@ 属于当前空间，插入会话列表", gid);
                            [weakSelf uiAddConversation:conv];
                        }
                    }
                }
            }
            [weakSelf refreshBadge];
        });
    });
}

/// 当前空间新建群聊的通知回调：将新群聊添加到白名单
-(void) onGroupCreatedInCurrentSpace:(NSNotification*)notification {
    NSString *groupNo = notification.object;
    if(groupNo) {
        [self.conversationListVM addGroupToWhitelist:groupNo];
    }
}

#pragma mark - WKReminderManagerDelegate

- (void)reminderManager:(WKReminderManager *)manager didChange:(WKChannel *)channel reminders:(NSArray<WKReminder *> *)reminders {
    WKConversationWrapModel *model = [self.conversationListVM modelAtChannel:channel];
    if (model) {
        WKConversation *conv = [model getConversation];
        conv.reminders = reminders;
    }
    // 子区不在 conversationWrapModels 里，modelAtChannel: 取不到 — 顶层路径的
    // conv.reminders = reminders 不会发生。tab 上 [有人@我] 走的是
    // VM.cachedRemindersByChannelId（仅 loadConversationList 时建好的子区索引），
    // 不主动回写就读不到新到的子区 @，关注/最近 tab 标签永远不亮。
    [self.conversationListVM applySubzoneRemindersUpdate:channel reminders:reminders];
    // 子区：reminder 变化也需要刷新（子区的@提醒显示在父群组的预览行上）
    [self rebuildGroupDisplayAndReload];
}

/// 子区数量批量更新完成后统一刷新整个列表（避免大量逐行更新导致 tableView 卡死）
-(void) onThreadCountBatchUpdated:(NSNotification*)notification {
    [self rebuildGroupDisplayAndReload];
}

/// YUJ-bot-isolation: 当前 Space 的 Bot 列表加载完成 → 触发 prune + UI 刷新。
/// 服务端没把 Bot DM 的 channel_id 前缀化、payload 也无 space_id（实测线上行为），
/// 切 Space 瞬间 SDK 仍可能把旧 Space Bot 的 conversation 浮上来；这里在
/// /robot/my_bots + /robot/space_bots 返回后做一次兜底清理，确保 UI 与服务端权威
/// Bot 成员名单一致。
-(void) onSpaceBotRegistryDidLoad:(NSNotification*)notification {
    NSString *loadedSpaceId = notification.userInfo[@"space_id"];
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(loadedSpaceId.length == 0 || ![loadedSpaceId isEqualToString:currentSpaceId]) {
        // 加载完成后用户已经又切走了，本次加载的结果对当前 Space 无意义。
        return;
    }
    NSArray<NSString*> *removed = [self.conversationListVM pruneNonCurrentSpaceBotsForSpace:loadedSpaceId];
    if(removed.count > 0) {
        [self rebuildGroupDisplayAndReload];
        [self refreshBadge];
    }
}

#pragma mark - 关注 tab sidebar 自动刷新

-(void) onAppDidBecomeActive:(NSNotification*)notification {
    [self reloadFollowedKeysIfNeeded:@"appDidBecomeActive"];
}

-(void) onAppWillResignActive:(NSNotification*)notification {
    // 拖拽中突然进后台 / 来电 → 系统会取消触摸，但 UILongPressGestureRecognizer
    // 在 app 立即被挂起的场景下不一定能在合适的时机 fire Cancelled。这里主动收尾,
    // 防止恢复时 snapshot 残留在 window 上。
    if (self.cellDragInProgress
        || self.cellDragSourceChannelId.length > 0
        || self.cellDragSourceSectionId.length > 0
        || self.cellDragHighlightedSectionCell != nil) {
        [self resetCellDragState];
    }
}

-(void) onFollowedKeysStoreDidUpdate:(NSNotification*)notification {
    // 任意 follow/unfollow 写操作完成 + reload 完成都会 post 这个通知。
    // 关注 tab 需要把新加的 DM/取消的会话在分组里更新；最近 tab 不需要重建（数据源是 IM cache），
    // 但长按菜单下次弹出时已经能拿到最新 followedKeys。
    // followedKeys 也是 seedFollowedThreadsIntoTopicsCache 的输入 — 这里补拉一次，
    // 覆盖"loadConversationList 跑完后 store 才 loaded"的冷启动 race。
    [self.conversationListVM seedFollowedThreadsIntoTopicsCache];
    if (self.conversationListVM.filterType == WKConversationFilterFollow) {
        [self rebuildGroupDisplayAndReload];
    }
    // 关注集合变了，两个 tab 的 badge 都要重新算（被关注的群/DM 进出会同时影响两边）
    [self refreshBadge];
}

/// 触发一次 sidebar/sync，debounce ≥30s 避免与 viewDidAppear 在快速切回前后台时重复打。
/// 详见 spec §4.6 "自动 reload sidebar"。
-(void) reloadFollowedKeysIfNeeded:(NSString*)reason {
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    NSTimeInterval delta = now - self.lastFollowedKeysReloadAt;
    if (self.lastFollowedKeysReloadAt > 0 && delta < 30.0) {
        return; // debounce
    }
    self.lastFollowedKeysReloadAt = now;
    NSLog(@"[FollowedKeys] reload triggered by %@", reason);
    [[WKFollowedKeysStore shared] reload];
    // 同时刷一次 categoryList —— 跨设备新建分类 / 把已关注项移入新分类时，sidebar/sync 会带新
    // category_id，但本地 categoryList 没有对应 header，buildGroupDisplayList 在 `for (cat in
    // self.categoryList)` 循环里就跳过这些 sidebar-only 项，导致用户 follow 了却看不到（PR review #2）。
    // store reload 完成会通过 didUpdateNotification 触发一次 rebuild，但 categories 接口可能更慢回来，
    // 那次 rebuild 拿到的是旧 categoryList；这里 completion 再补一次 rebuild 兜底。
    __weak typeof(self) weakSelf = self;
    [self.conversationListVM loadCategoriesWithCompletion:^{
        if (weakSelf.conversationListVM.filterType == WKConversationFilterFollow) {
            [weakSelf rebuildGroupDisplayAndReload];
        }
        [weakSelf refreshBadge];
    }];
}

/// : 判断 channel 是否为系统 Bot（botfather / u_10000 / fileHelper 等）。
/// SYSTEM_BOTS 集合在本单先取 WKAppConfig 已有的三个 UID，口径与
/// `isConversationInCurrentSpace` 放行"全局可见"的那三项保持一致。
/// 后续 会把集合迁到 appconfig system_bot_uids 下发，本单不触碰。
-(BOOL) isSystemBotChannel:(WKChannel*)channel {
    NSString *channelId = channel.channelId;
    if(!channelId || channelId.length == 0) {
        return NO;
    }
    NSString *botfatherUID = [WKApp shared].config.botfatherUID;
    NSString *systemUID = [WKApp shared].config.systemUID;
    NSString *fileHelperUID = [WKApp shared].config.fileHelperUID;
    return (botfatherUID.length > 0 && [channelId isEqualToString:botfatherUID])
        || (systemUID.length > 0 && [channelId isEqualToString:systemUID])
        || (fileHelperUID.length > 0 && [channelId isEqualToString:fileHelperUID]);
}

/// : 判断 message.content.contentDict[@"space_id"] 是否精确匹配当前 Space。
/// 无 space_id / 非字符串类型 → 视为非当前 Space（防止 SystemBot 无 space_id 的跨 Space
/// 消息 bump 当前 Space 的 lastMsg timestamp / unread / 排序）。
-(BOOL) isMessageFromCurrentSpace:(WKMessage*)message spaceId:(NSString*)spaceId {
    if(!message) {
        // 无 lastMessage 不做 bump 判定（上层其他 gate 已决定是否放行）
        return YES;
    }
    id raw = message.content.contentDict[@"space_id"];
    if(![raw isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString *msgSpaceId = (NSString*)raw;
    if(msgSpaceId.length == 0) {
        return NO;
    }
    return [msgSpaceId isEqualToString:spaceId];
}

// 单个会话添加或更新
-(void) uiAddOrUpdateConversationForOne:(WKConversation*)conversation {
    if(conversation.channel.channelType == WK_PERSON) {
#if DEBUG
        NSString *cur = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
        BOOL existsInList = [self.conversationListVM indexAtChannel:conversation.channel] != -1;
        WK_BOT_TRACE(@"[BotSpaceTrace] uiAddOrUpdateConversationForOne enter channelId=%@ current=%@ existsInList=%d",
              conversation.channel.channelId, cur ?: @"<nil>", existsInList);
#endif
    }
    // : push 路径对称 gate —— 必须在 getRealShowConversationWrap 之前做判定。
    // validation-report.md §3 / §5 判定 iOS 是"半保险"：spaceFilteredLastMessage 能擦
    // preview 文字，但 replaceAtChannel 裸替换会照常 bump lastMessage.timestamp 和
    // unreadCount → 当前 Space 列表被他 Space push 冒顶 + 红点。
    // `uiAddConversation`（新增分支）已有 isConversationInCurrentSpace 检查，
    // 这里"已存在 → replace/sort"分支补上对称 gate，与 Android `resetData` 同源。
    //
    // ⚠️ getRealShowConversationWrap 对子区/thread 消息会调用父会话的 addOrUpdateChildren，
    // 从而变更父行的 children / lastChildConversation 状态。因此 gate 必须放在它之前，
    // 否则即便 return 也已产生副作用。通过 conversation.parentChannel ?: conversation.channel
    // 判断对应行是否已存在。
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(currentSpaceId && currentSpaceId.length > 0) {
        WKChannel *targetChannel = conversation.parentChannel ?: conversation.channel;
        if(targetChannel && [self.conversationListVM indexAtChannel:targetChannel] != -1) {
            // 1) 基础 gate：不属于当前 Space → 保持旧状态，不触发任何 wrap/sort/replace。
            if(![self isConversationInCurrentSpace:conversation spaceId:currentSpaceId]) {
                return;
            }
            // 2) 系统 Bot bump 保护：SystemBot entry 全局可见
            //    （isConversationInCurrentSpace 对 botfather / systemUID / fileHelper 放行），
            //    但 lastMessage 若来自他 Space / 无 space_id，不应 bump 当前 Space 的
            //    lastMsgTimestamp / unread / 排序。
            if([self isSystemBotChannel:conversation.channel]
               && ![self isMessageFromCurrentSpace:conversation.lastMessage spaceId:currentSpaceId]) {
                return;
            }
        }
    }

    WKConversationWrapModel *newModel = [self.conversationListVM getRealShowConversationWrap:[[WKConversationWrapModel alloc] initWithConversation:conversation]];

    NSInteger oldIndex = [self.conversationListVM indexAtChannel:newModel.channel];
    if(oldIndex != -1) {
        // 已存在：替换数据并重新排序
        [self.conversationListVM replaceAtChannel:newModel atChannel:newModel.channel];
        [self.conversationListVM sortConversationList];

        // 群聊 tab 使用分组展示，index 不匹配 tableView，直接全量刷新
        if (_conversationListVM.filterType == WKConversationFilterFollow) {
            [self rebuildGroupDisplayAndReload];
        } else {
            NSInteger newIndex = [self.conversationListVM indexAtChannel:newModel.channel];
            if (oldIndex == newIndex) {
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:newIndex inSection:0]];
                if ([cell isKindOfClass:[WKConversationListCell class]]) {
                    [(WKConversationListCell *)cell refreshWithModel:newModel];
                }
            } else {
                [self rebuildGroupDisplayAndReload];
            }
        }
    } else {
        [self uiAddConversation:conversation];
    }
}


/// 判断会话是否属于当前空间（用于过滤其他空间的实时消息）
-(BOOL) isConversationInCurrentSpace:(WKConversation*)conversation spaceId:(NSString*)spaceId {
    NSString *channelId = conversation.channel.channelId;
    BOOL isPerson = (conversation.channel.channelType == WK_PERSON);

    // 系统通知和文件助手是全局的，始终显示
    if([channelId isEqualToString:[WKApp shared].config.systemUID] ||
       [channelId isEqualToString:[WKApp shared].config.fileHelperUID]) {
        if(isPerson) WK_BOT_TRACE(@"[BotSpaceTrace] isConversationInCurrentSpace channelId=%@ → YES (system/fileHelper)", channelId);
        return YES;
    }

    // BotFather是全局的（已有space_id消息过滤）
    if([channelId isEqualToString:[WKApp shared].config.botfatherUID]) {
        if(isPerson) WK_BOT_TRACE(@"[BotSpaceTrace] isConversationInCurrentSpace channelId=%@ → YES (botfather)", channelId);
        return YES;
    }

    // 群聊：先走 WKSpaceFilter（支持外部群 source_space_id 兜底，对齐 shouldShowConversation 与
    // 的串台修复）。FailOpen 场景下再降级到 sync 白名单，保持兜底一致性。
    if(conversation.channel.channelType == WK_GROUP) {
        WKSpaceFilterDecision decision = [[WKSpaceFilter shared]
                                           decideChannel:channelId
                                             channelType:conversation.channel.channelType];
        if(decision == WKSpaceFilterDecisionKeep) {
            return YES;
        }
        if(decision == WKSpaceFilterDecisionSkip) {
            // : Skip 时若 VM 中仍残留该 channel，同步清掉，保证
            // "Skip 决定 ⇒ 从 conversation array 移除"这一语义在所有 Skip 入口
            // （filter 批次 + 单条判定）上一致。避免访问过群后单例内存仍持有该条
            // 目，下次 sort / rebuildGroupDisplayAndReload 再把它浮回当前 Space。
            if([self.conversationListVM indexAtChannel:conversation.channel] != -1) {
                [self.conversationListVM removeAtChannnel:conversation.channel];
            }
            return NO;
        }
        // FailOpen：channelInfo / member 未缓存 → 走白名单兜底。
        // : 白名单未初始化（nil）时不再默认 YES——Space 切换 race 窗口需要
        // 严格过滤（对齐 Android Round-2 PR#155 去 isEmpty() 短路模式）。
        if(![self.conversationListVM isGroupWhitelistInitialized]) {
            return NO;
        }
        return [self.conversationListVM isGroupInWhitelist:conversation.channel.channelId];
    }

    // 个人聊天：先按 channelId 前缀做空间过滤（Bot 与私聊频道均会被后端前缀化为
    // `s{spaceId}_{uid}`），对齐 web `shouldSkipChannelForSpace`
    // （dmwork-web/.../SpaceService.tsx:23-25）。无前缀的旧数据走 lastMessage.space_id 兜底。
    if(conversation.channel.channelType == WK_PERSON) {
        WKSpaceFilterDecision decision = [[WKSpaceFilter shared]
                                           decideChannel:channelId
                                             channelType:conversation.channel.channelType];
        if(decision == WKSpaceFilterDecisionSkip) {
            // 与群聊 Skip 分支对称：清除 VM 中残留，避免下次 sort/rebuild 再浮回。
            WK_BOT_TRACE(@"[BotSpaceTrace] isConversationInCurrentSpace channelId=%@ → NO (WKSpaceFilter Skip)", channelId);
            if([self.conversationListVM indexAtChannel:conversation.channel] != -1) {
                [self.conversationListVM removeAtChannnel:conversation.channel];
            }
            return NO;
        }

        // YUJ-bot-isolation: 服务端对 Bot DM 的 channel_id 不带前缀，且 message
        // payload / channelInfo 都不带 space_id（线上日志证实），上面三层信号全失效。
        // 兜底：用本地"当前 Space 已添加 Bot 列表"判定（数据来自 /robot/my_bots +
        // /robot/space_bots，与 WKBotListVM 同源）。
        // - NotMember：明确不属于当前 Space → Skip + 清残留。
        // - Unknown：列表尚未加载（冷启动/切 Space race）→ fail-open，等加载完成后
        //   pruneNonCurrentSpaceBots 兜底清理。
        // - Member：放行，进入下方 lastMessage.space_id 检查（保留更细粒度判定）。
        WKChannelInfo *info = [[WKChannelInfoDB shared] queryChannelInfo:conversation.channel];
        if(info && info.robot) {
            WKSpaceBotMembership mem = [[WKSpaceBotRegistry shared] membershipForBotUID:channelId inSpace:spaceId];
            if(mem == WKSpaceBotMembershipNotMember) {
                WK_BOT_TRACE(@"[BotSpaceTrace] isConversationInCurrentSpace channelId=%@ → NO (bot not in current space's my_bots∪space_bots)", channelId);
                if([self.conversationListVM indexAtChannel:conversation.channel] != -1) {
                    [self.conversationListVM removeAtChannnel:conversation.channel];
                }
                return NO;
            }
        }
    }

    // 个人聊天：检查最后一条消息的 space_id 是否匹配当前空间
    if(conversation.lastMessage) {
        NSString *msgSpaceId = conversation.lastMessage.content.contentDict[@"space_id"];
        if([msgSpaceId isKindOfClass:[NSString class]] && [msgSpaceId isEqualToString:spaceId]) {
            if(isPerson) WK_BOT_TRACE(@"[BotSpaceTrace] isConversationInCurrentSpace channelId=%@ → YES (msg.space_id=%@ match)", channelId, msgSpaceId);
            return YES; // 消息明确属于当前空间
        }
        // 消息没有 space_id 标记
        if(!msgSpaceId || [msgSpaceId isEqual:[NSNull null]] || ([msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length == 0)) {
            // 切换 Space 闸门期：fail-closed —— 不允许"无 space_id"的 bot DM / 私聊
            // 在 B 的 sync/registry 还没到位时混进来。落闸后这里恢复 YES。
            if(self.spaceSwitchInProgress) {
                if(isPerson) WK_BOT_TRACE(@"[BotSpaceTrace] isConversationInCurrentSpace channelId=%@ → NO (spaceSwitchInProgress, 无 space_id 兜底拒绝)", channelId);
                return NO;
            }
            if(isPerson) WK_BOT_TRACE(@"[BotSpaceTrace] isConversationInCurrentSpace channelId=%@ → YES (msg无 space_id，向前兼容)", channelId);
            return YES; // 消息无 space_id（含 Bot），视为当前空间
        }
        // 消息有 space_id 但不匹配当前空间
        if(isPerson) WK_BOT_TRACE(@"[BotSpaceTrace] isConversationInCurrentSpace channelId=%@ → NO (msg.space_id=%@ != current=%@)", channelId, msgSpaceId, spaceId);
        return NO;
    }

    // 无最后一条消息，允许显示（如空会话）
    // 切换 Space 闸门期：fail-closed —— 任何无 lastMessage 的会话也不放行。
    if(self.spaceSwitchInProgress) {
        if(isPerson) WK_BOT_TRACE(@"[BotSpaceTrace] isConversationInCurrentSpace channelId=%@ → NO (spaceSwitchInProgress, 无 lastMessage 兜底拒绝)", channelId);
        return NO;
    }
    if(isPerson) WK_BOT_TRACE(@"[BotSpaceTrace] isConversationInCurrentSpace channelId=%@ → YES (无 lastMessage)", channelId);
    return YES;
}

-(void) uiAddConversation:(WKConversation*)conversation {
    if(conversation.channel.channelType == WK_PERSON) {
        WK_BOT_TRACE(@"[BotSpaceTrace] uiAddConversation enter channelId=%@", conversation.channel.channelId);
    }
    // 会话已存在则更新，不重复插入
    if ([self.conversationListVM indexAtChannel:conversation.channel] != -1) {
        [self uiAddOrUpdateConversationForOne:conversation];
        return;
    }
    // 有活跃空间时，不自动添加不属于当前空间的新会话
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(currentSpaceId && currentSpaceId.length > 0) {
        if(![self isConversationInCurrentSpace:conversation spaceId:currentSpaceId]) {
            return;
        }
    }
    // 记录插入前的行数
    NSInteger countBefore = [self.conversationListVM conversationCount];
    WKConversationWrapModel *model = [[WKConversationWrapModel alloc] initWithConversation:conversation];
    NSInteger insertPlace = [self.conversationListVM insert:model];
    NSInteger countAfter = [self.conversationListVM conversationCount];
    // 只有过滤后的列表确实多了一行，才做 insertRowsAtIndexPaths
    // 否则直接 reloadData（防止 tab 过滤导致 count 不变触发 Invalid batch updates）
    if (countAfter == countBefore + 1 && _conversationListVM.filterType != WKConversationFilterFollow) {
        [self.tableView insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:insertPlace inSection:0] ] withRowAnimation:UITableViewRowAnimationFade];
    } else {
        [self rebuildGroupDisplayAndReload];
    }
}
// 删除最近会话
- (void)onConversationDelete:(WKChannel *)channel {
    [self.conversationListVM removeAtChannnel:channel];
    [self refreshTable];
    [self refreshBadge];
}

-(void) onlyAddOrUpdateConversation:(WKConversation*)conversation {
    if(conversation.channel.channelType == WK_PERSON) {
        WK_BOT_TRACE(@"[BotSpaceTrace] onlyAddOrUpdateConversation enter channelId=%@", conversation.channel.channelId);
    }
    // 子区不独立显示在会话列表
    if(conversation.channel.channelType == WK_COMMUNITY_TOPIC) {
        return;
    }
    // 系统 Bot（botfather/u_10000/fileHelper）跨 Space 串台 gate：与
    // uiAddOrUpdateConversationForOne 的 gate 对称（参见本文件 m:1500 附近）。
    // 对齐 web `shouldSkipSystemBotConversation`（dmwork-web/.../SpaceService.tsx）。
    // 该路径承载切 Space 后的 sync rebuild 与离线消息刷库回调，缺它会让另一个
    // Space 的 Bot 最近一条消息把当前 Space 的 bot 行 lastMessage 替换掉，再走
    // refreshTable / sortConversationList 时排序与预览一并污染。
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(currentSpaceId.length > 0
       && [self isSystemBotChannel:conversation.channel]
       && ![self isMessageFromCurrentSpace:conversation.lastMessage spaceId:currentSpaceId]) {
        return;
    }
    // YUJ-bot-isolation: 普通 Person/Bot 频道在"已存在 model → setConversation"
    // 分支也必须过 isConversationInCurrentSpace gate（含 prefix / channelInfo
    // space_id / WKSpaceBotRegistry 三层判定）。否则 filterConversationsBySpace
    // 的 existsInList 分支会让"无 space_id 的裸 Bot DM"通过，再 setConversation
    // 把 stale bot 行用跨 Space 消息刷新预览/排序——即使 registry 已判定 NotMember。
    // gate 内部命中 Skip 时会 removeAtChannnel: 兜底清残留。
    if(currentSpaceId.length > 0
       && conversation.channel.channelType == WK_PERSON
       && ![self isSystemBotChannel:conversation.channel]
       && ![self isConversationInCurrentSpace:conversation spaceId:currentSpaceId]) {
        return;
    }
    WKConversationWrapModel *model =  [self.conversationListVM modelAtChannel:conversation.channel];
    if(model) {
        [model setConversation:conversation];
    }else {
        // 有活跃空间时，不自动添加不属于当前空间的新会话
        if(currentSpaceId && currentSpaceId.length > 0) {
            if(![self isConversationInCurrentSpace:conversation spaceId:currentSpaceId]) {
                return;
            }
        }
        [self.conversationListVM insert:[[WKConversationWrapModel alloc] initWithConversation:conversation] atIndex:0];
    }
}
// 更新最近会话未读数
- (void)onConversationUnreadCountUpdate:(WKChannel*)channel unreadCount:(NSInteger)unreadCount {
    // 关键：用 anyModelAtChannel: 查（含 threadWrapModels），不能用 indexAtChannel: ——
    // 后者走 filteredConversations，Follow tab 只含 WK_GROUP，DM/子区直接 -1 漏掉,
    // 已关注的 DM 和嵌套子区的未读永远停在旧值。
    WKConversationWrapModel *model = [self.conversationListVM anyModelAtChannel:channel];
    if(!model) {
        if (channel.channelType == WK_COMMUNITY_TOPIC) {
            // PR review #1 critical：子区不在 threadWrapModels 不代表不存在 —— 它通常
            // 还在 cachedTopicsByGroup 里（threadWrapModels 严格按 parent.threadPreviews
            // 收，是 cachedTopicsByGroup 的真子集）。Follow tab 的「+N 子区」badge /
            // getFollowUnreadCount / getThreadIndicatorForGroup 都直接读这份缓存的
            // unreadCount，必须把 SDK 投来的最新值写回，否则用户在另一端读完已读
            // 后 badge 不收敛。create 占位由 applyThreadConversationUpdates /
            // syncThreadWrapModelsFromCachedTopics 路径负责（带 syncedGroups 闸门），
            // 这里只做 update，不凭空 alloc。
            BOOL updated = [self.conversationListVM updateCachedSubzoneUnread:channel unreadCount:unreadCount];
            if (updated) {
                if (_conversationListVM.filterType == WKConversationFilterFollow) {
                    // Follow tab 上的 +N 子区角标 / section header unread 都从
                    // cachedTopicsByGroup 算出来，rebuild 一次让 cell 重渲染
                    [self rebuildGroupDisplayAndReload];
                }
                // Recent tab 不展示非 preview 子区，没有具体 cell 需要刷；refreshBadge
                // 已 coalesce 到 150ms 一次（refreshBadge 方法注释），多设备 sync 时
                // 批量回调安全
                [self refreshBadge];
            } else {
                WK_THREAD_BADGE_DBG(@"[ThreadBadgeDbg] onConvUnreadUpdate EARLY-RETURN subzone=%@ unread=%ld (not in threadWrapModels nor cachedTopicsByGroup)",
                      channel.channelId, (long)unreadCount);
            }
        }
        return;
    }

    // Person 频道：不阻塞未读更新（Person 会话已全局可见，SDK 回调的 unreadCount 直接使用）
    // Group 频道：仍需检查是否属于当前空间
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(currentSpaceId.length > 0 && channel.channelType != WK_PERSON) {
        WKConversation *conv = [[WKSDK shared].conversationManager getConversation:channel];
        if(conv && conv.lastMessage) {
            NSString *msgSpaceId = conv.lastMessage.content.contentDict[@"space_id"];
            if(msgSpaceId && [msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length > 0
               && ![msgSpaceId isEqualToString:currentSpaceId]) {
                return;
            }
        }
    }

    model.unreadCount = unreadCount;
    // 关注 tab 用分组展示，cell 行号 ≠ index，全量 rebuild
    if (_conversationListVM.filterType == WKConversationFilterFollow) {
        [self rebuildGroupDisplayAndReload];
    } else {
        // 最近 tab：尝试找到行号刷 cell；如果不可见（子区在父群下、或被过滤）也无所谓,
        // 下次滚动到 cell 重用时会从 model 读到新值。
        NSInteger row = [self.conversationListVM indexAtChannel:channel];
        if (row >= 0) {
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
            if ([cell isKindOfClass:[WKConversationListCell class]]) {
                [(WKConversationListCell *)cell refreshWithModel:model];
                [cell layoutSubviews];
            }
        }
    }
    [self refreshBadge];
}
// 删除所有最近会话
- (void)onConversationAllDelete {
    NSLog(@"[ConvDebug] onConversationAllDelete called! callStack=%@", [[NSThread callStackSymbols] subarrayWithRange:NSMakeRange(1, MIN(5, [NSThread callStackSymbols].count - 1))]);
    [self.conversationListVM removeAll];
    [self refreshTable];
    [self refreshBadge];
}


-(void) setupConversationTabView {
    _conversationTabView = [[WKConversationTabView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, 44)];
    _conversationTabView.selectedIndex = _conversationListVM.filterType;

    __weak typeof(self) weakSelf = self;
    _conversationTabView.onTabChanged = ^(NSInteger index) {
        // 切 tab 前若正在拖动，强制清理 — 否则 snapshot 会卡在屏上
        [weakSelf resetCellDragState];
        NSInteger oldIndex = weakSelf.conversationListVM.filterType;
        // 保存当前 tab 滚动位置
        if (oldIndex == WKConversationFilterFollow) {
            weakSelf.followTabScrollOffset = weakSelf.tableView.contentOffset;
        } else {
            weakSelf.recentTabScrollOffset = weakSelf.tableView.contentOffset;
        }
        weakSelf.conversationListVM.filterType = index;
        [weakSelf.conversationListVM rebuildFilteredList];
        [weakSelf rebuildGroupDisplayAndReload];
        WK_THREAD_BADGE_DBG(@"[ThreadSync] onTabChanged → %@ filteredConversations=%ld threadWrapModels=%ld groupDisplayList=%ld",
              index == WKConversationFilterFollow ? @"Follow" : @"Recent",
              (long)[weakSelf.conversationListVM conversationCount],
              (long)weakSelf.conversationListVM.threadWrapModels.count,
              (long)weakSelf.groupDisplayList.count);
        // 切到最近 tab 时主动再拉一次 thread 数据 — 解决冷启在关注 tab 时
        // SDK 还没把所有 thread 加载到本地 cache，导致 threadWrapModels 是空,
        // 切过来一片空白。fetchThreadCountsForGroups 完成后会回调
        // syncThreadWrapModelsFromCachedTopics + rebuildFilteredList。
        if (index == WKConversationFilterRecent) {
            [weakSelf.conversationListVM fetchThreadCountsForGroups];
        }
        // 切到关注 tab 也刷新一下空状态显示
        [weakSelf refreshFollowEmptyVisibility];
        // 恢复目标 tab 的滚动位置
        CGPoint savedOffset = (index == WKConversationFilterFollow) ? weakSelf.followTabScrollOffset : weakSelf.recentTabScrollOffset;
        [weakSelf.tableView setContentOffset:savedOffset animated:NO];
        [weakSelf updateTabUnreadCounts];
        [[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"WKConversationTabIndex"];
    };

    // 将 tabView 添加到固定头部容器（不随 tableView 滚动）
    [self.fixedHeaderContainer addSubview:_conversationTabView];
    [self layoutFixedHeader];
}

-(void) handleTabSwipe:(UISwipeGestureRecognizer *)gesture {
    NSLog(@"[TabSwipe] triggered direction=%ld state=%ld", (long)gesture.direction, (long)gesture.state);
    if (!_conversationTabView) return;
    NSInteger current = _conversationListVM.filterType;
    if (gesture.direction == UISwipeGestureRecognizerDirectionLeft && current == 0) {
        [_conversationTabView setSelectedIndex:1 animated:YES];
    } else if (gesture.direction == UISwipeGestureRecognizerDirectionRight && current == 1) {
        [_conversationTabView setSelectedIndex:0 animated:YES];
    }
}

-(void) updateTabUnreadCounts {
    [self.conversationTabView setFollowUnreadCount:[self.conversationListVM getFollowUnreadCount]];
    [self.conversationTabView setRecentUnreadCount:[self.conversationListVM getRecentUnreadCount]];
}

/// refreshBadge 是高频调用 — viewWillAppear / viewDidAppear / loadConversationList completion /
/// loadCategoriesWithCompletion / channelInfoUpdate（每条）/ onConversationUpdate（每条）/
/// onMessageUpdate 等多个路径都直接调它。每次都同步写 badge 数字会把中间瞬态暴露给用户：
/// 切回 tab 时 loadConversationList 刚 replace conversationWrapModels（数组对象身份变了，
/// 部分 wrap 的 channelInfo cache 还没 ready）的那一刻就算，会算出超过真实值的 99+，等
/// channelInfo 陆续到达 + 多次重算才收敛到 9。
///
/// cell 上看不到这个闪烁是因为 reloadData 是 setNeedsLayout，cell 真正渲染发生在
/// runloop 末尾 —— 那时 channelInfo cache 已经稳定 / model 状态收敛了。
///
/// 把 badge 也对齐到同款节奏：所有调用合并到 150ms 后一次实算，保证算出来的就是稳定值，
/// 不再把 race 中间态 leak 到 UI。150ms 延迟人眼无感知，但足够吸收一连串密集事件。
-(void) refreshBadge {
    if (self.refreshBadgePending) return;
    self.refreshBadgePending = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.refreshBadgePending = NO;
        strongSelf.tabBarItem.badgeValue = nil;
        [strongSelf updateTabUnreadCounts];
    });
}

#pragma mark - WKNetworkListenerDelegate

- (void)networkListenerStatusChange:(WKNetworkListener *)listener {
     [self showNetworkError:!listener.hasNetwork];
}

#pragma mark - WKChannelManagerDelegate

-(void) channelInfoUpdate:(WKChannelInfo *)channelInfo oldChannelInfo:(WKChannelInfo *)oldChannelInfo{
   //[self refreshTable];
    // 子区的 channelInfo 变化(例如子区免打扰切换)在会话列表里没有顶层行,
    // 需要定位到父群行并刷新,子区预览才会重新读取 threadInfo.mute 渲染静音图标。
    if (channelInfo.channel.channelType == WK_COMMUNITY_TOPIC) {
        NSRange sep = [channelInfo.channel.channelId rangeOfString:@"____"];
        if (sep.location != NSNotFound) {
            NSString *parentGroupNo = [channelInfo.channel.channelId substringToIndex:sep.location];
            if (parentGroupNo.length > 0) {
                // 群聊 tab 下 tableView 真实 row 来自 groupDisplayList(含分类 header),
                // filteredConversations 下标和 row 不可直接等同。走 rebuild 路径即可。
                // 私聊 tab 下 indexAtChannel: 返回的就是 row, 但还是做 bounds 校验防御。
                // (Jerry-Xin R2 blocking fix, )
                if (_conversationListVM.filterType == WKConversationFilterFollow) {
                    [self rebuildGroupDisplayAndReload];
                } else {
                    WKChannel *parentChannel = [WKChannel channelID:parentGroupNo channelType:WK_GROUP];
                    NSInteger parentIndex = [self.conversationListVM indexAtChannel:parentChannel];
                    NSInteger rowCount = [self.tableView numberOfRowsInSection:0];
                    if (parentIndex >= 0 && parentIndex < rowCount) {
                        [self safeReloadRows:@[[NSIndexPath indexPathForRow:parentIndex inSection:0]] animation:UITableViewRowAnimationNone];
                    }
                    // 最近 tab：子区是独立行，父群刷新涵盖不到自身静音/改名等 channelInfo 变化,
                    // 还要单独定位子区自身行刷一次。
                    NSInteger threadIndex = [self.conversationListVM indexAtChannel:channelInfo.channel];
                    if (threadIndex >= 0 && threadIndex < rowCount) {
                        [self safeReloadRows:@[[NSIndexPath indexPathForRow:threadIndex inSection:0]] animation:UITableViewRowAnimationNone];
                    }
                }
            }
        }
        return;
    }
    NSInteger index = [self.conversationListVM indexAtChannel:channelInfo.channel];
    if(index!= -1) {
        WKConversationWrapModel *oldModel = [self.conversationListVM modelAtIndex:index];
        // 更新 model 中缓存的 channelInfo，避免使用过期数据
        oldModel.channelInfo = channelInfo;
        WKConversation *conversation = [[oldModel getConversation] copy];
        NSLog(@"[StickDebug] channelInfoUpdate ch=%@ type=%d old(mute=%d stick=%d) new(mute=%d stick=%d) conv.before(mute=%d stick=%d)",
              channelInfo.channel.channelId, channelInfo.channel.channelType,
              oldChannelInfo.mute, oldChannelInfo.stick,
              channelInfo.mute, channelInfo.stick,
              conversation.mute, conversation.stick);
        conversation.mute = channelInfo.mute;
        conversation.stick = channelInfo.stick;
        if([self hasChange:channelInfo oldChannelInfo:oldChannelInfo]) {
            [self uiAddOrUpdateConversationForOne:conversation];
        }else{
            // Bounds-check: 群聊 tab 下 filteredConversations 下标和真实 row 不一致,
            // 直接 reload 可能越界。(Jerry-Xin R2 fix, )
            if (_conversationListVM.filterType == WKConversationFilterFollow) {
                [self rebuildGroupDisplayAndReload];
            } else {
                // 最近 tab：群行用 shadow wrap，其 .c 指向旧 WKConversation 单例。
                // 上面 channelInfoUpdate 路径已经把 mute/stick 同步到原始 wrap.c 的 copy，
                // 但 shadow wrap.c 还指向老的实例 → 直接 reloadRows 渲染不出新的免打扰/置顶。
                // 触发 rebuildFilteredList 让 shadow 从 conversationWrapModels[i].c 取最新值。
                [self.conversationListVM rebuildFilteredList];
                NSInteger newIndex = [self.conversationListVM indexAtChannel:channelInfo.channel];
                NSInteger rowCount = [self.tableView numberOfRowsInSection:0];
                if (newIndex >= 0 && newIndex < rowCount) {
                    [self safeReloadRows:@[[NSIndexPath indexPathForRow:newIndex inSection:0]] animation:UITableViewRowAnimationNone];
                }
            }
            
//            WKConversationListCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
//            if(cell) {
//                WKConversationWrapModel *model = [self.conversationListVM modelAtIndex:index];
//                [cell refreshWithModel:model];
//            }
        }
        [self resetHeaderBottomEmptyBackgroundColor];
    }
    // 最近 tab：父群 channelInfo 到达时，把它名下的所有子区行刷新（拿父群头像 + 来源名）。
    // 子区行的复合头像和"来源:xxx" 第一次渲染时父群 info 可能还没缓存，渲染走兜底回退；
    // channelInfoUpdate 触发后必须主动 reload 这些行让 cell 重新走 refreshAvatar/Source 路径。
    if (_conversationListVM.filterType == WKConversationFilterRecent
        && channelInfo.channel.channelType == WK_GROUP
        && channelInfo.channel.channelId.length > 0) {
        [self reloadThreadRowsForParentGroup:channelInfo.channel.channelId];
    }
    // 静音切换会让 getFollow/RecentUnreadCount 把这条会话计入或排除，必须刷新 tab 红点。
    [self refreshBadge];
}

#pragma mark - 关注 tab 空状态引导

/// 关注 tab 没分组 / 没关注内容时显示的引导视图：折叠图标 + "整理你的群聊" 标题
/// + 一段说明 + 主题色"+ 新建分组"按钮。参考 web 端同款界面。
- (UIView *)followEmptyView {
    if (_followEmptyView) return _followEmptyView;
    UIView *bg = [[UIView alloc] init];
    bg.backgroundColor = [WKApp shared].config.backgroundColor;
    bg.hidden = YES;
    [self.view addSubview:bg];

    UIView *iconBg = [[UIView alloc] init];
    iconBg.tag = 9001;
    iconBg.backgroundColor = [UIColor colorWithRed:235.0/255 green:228.0/255 blue:255.0/255 alpha:1];
    iconBg.layer.cornerRadius = 22;
    [bg addSubview:iconBg];
    UIImageView *icon = [[UIImageView alloc] init];
    icon.tag = 9002;
    if (@available(iOS 13.0, *)) {
        icon.image = [[UIImage systemImageNamed:@"folder"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        icon.image = [WKConversationListVC iconMoveCategory];
    }
    icon.tintColor = [UIColor colorWithRed:51.0/255 green:34.0/255 blue:78.0/255 alpha:1];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [iconBg addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.tag = 9003;
    title.text = LLang(@"关注你最在意的会话");
    title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    title.textColor = [WKApp shared].config.defaultTextColor;
    title.textAlignment = NSTextAlignmentCenter;
    [bg addSubview:title];

    UILabel *desc = [[UILabel alloc] init];
    desc.tag = 9004;
    desc.text = LLang(@"把重要的群聊、私聊、子区集中在这里，沉浸在你真正关心的消息里。\n在「最近」长按任意会话，选择「添加到关注」。");
    desc.font = [UIFont systemFontOfSize:14];
    desc.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    desc.numberOfLines = 0;
    desc.textAlignment = NSTextAlignmentCenter;
    [bg addSubview:desc];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.tag = 9005;
    [btn setTitle:LLang(@"+ 新建分组") forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    btn.backgroundColor = [WKApp shared].config.themeColor ?: [UIColor colorWithRed:88.0/255 green:48.0/255 blue:220.0/255 alpha:1];
    btn.layer.cornerRadius = 22;
    btn.layer.masksToBounds = YES;
    btn.contentEdgeInsets = UIEdgeInsetsMake(0, 24, 0, 24);
    [btn addTarget:self action:@selector(onFollowEmptyCreateTap) forControlEvents:UIControlEventTouchUpInside];
    [bg addSubview:btn];

    _followEmptyView = bg;
    return _followEmptyView;
}

- (void)layoutFollowEmptyViewIfNeeded {
    if (!_followEmptyView || _followEmptyView.hidden) return;
    CGFloat top = self.fixedHeaderContainer.lim_bottom;
    CGFloat bottom = self.tabBarController.tabBar.frame.size.height;
    _followEmptyView.frame = CGRectMake(0, top, self.view.lim_width, self.view.lim_height - top - bottom);
    CGFloat verticalCenter = _followEmptyView.lim_height / 2.0 - 40; // 略上偏一点

    UIView *iconBg = [_followEmptyView viewWithTag:9001];
    UIImageView *icon = (UIImageView *)[_followEmptyView viewWithTag:9002];
    UILabel *title = (UILabel *)[_followEmptyView viewWithTag:9003];
    UILabel *desc = (UILabel *)[_followEmptyView viewWithTag:9004];
    UIButton *btn = (UIButton *)[_followEmptyView viewWithTag:9005];

    iconBg.frame = CGRectMake((_followEmptyView.lim_width - 80) / 2.0, verticalCenter - 130, 80, 80);
    icon.frame = CGRectMake(20, 20, 40, 40);
    title.frame = CGRectMake(0, CGRectGetMaxY(iconBg.frame) + 18, _followEmptyView.lim_width, 26);
    CGFloat descMaxW = _followEmptyView.lim_width - 80;
    CGSize descSize = [desc sizeThatFits:CGSizeMake(descMaxW, CGFLOAT_MAX)];
    desc.frame = CGRectMake((_followEmptyView.lim_width - descMaxW) / 2.0, CGRectGetMaxY(title.frame) + 8, descMaxW, descSize.height);
    CGFloat btnW = 160;
    btn.frame = CGRectMake((_followEmptyView.lim_width - btnW) / 2.0, CGRectGetMaxY(desc.frame) + 24, btnW, 44);
}

- (void)refreshFollowEmptyVisibility {
    BOOL shouldShow = (self.conversationListVM.filterType == WKConversationFilterFollow)
                   && self.groupDisplayList.count == 0;
    if (!shouldShow && !_followEmptyView) return;
    UIView *v = shouldShow ? self.followEmptyView : _followEmptyView;
    v.hidden = !shouldShow;
    if (shouldShow) {
        [self.view bringSubviewToFront:v];
        [self layoutFollowEmptyViewIfNeeded];
    }
}

- (void)onFollowEmptyCreateTap {
    [self showCreateCategoryDialog];
}

/// 最近 tab：找出所有 parent_channel == groupNo 的子区行 indexPath，触发 reload。
- (void)reloadThreadRowsForParentGroup:(NSString *)groupNo {
    if (groupNo.length == 0) return;
    NSMutableArray<NSIndexPath *> *paths = [NSMutableArray array];
    NSArray<WKConversationWrapModel *> *threads = self.conversationListVM.threadWrapModels;
    NSString *prefix = [groupNo stringByAppendingString:@"____"];
    for (WKConversationWrapModel *t in threads) {
        if ([t.channel.channelId hasPrefix:prefix]) {
            NSInteger idx = [self.conversationListVM indexAtChannel:t.channel];
            if (idx >= 0) {
                [paths addObject:[NSIndexPath indexPathForRow:idx inSection:0]];
            }
        }
    }
    if (paths.count == 0) return;
    NSInteger rowCount = [self.tableView numberOfRowsInSection:0];
    NSMutableArray<NSIndexPath *> *valid = [NSMutableArray arrayWithCapacity:paths.count];
    for (NSIndexPath *p in paths) {
        if (p.row < rowCount) [valid addObject:p];
    }
    if (valid.count > 0) {
        [self safeReloadRows:valid animation:UITableViewRowAnimationNone];
    }
}

-(BOOL) hasChange:(WKChannelInfo*)channelInfo oldChannelInfo:(WKChannelInfo*)oldChannelInfo {
    if(oldChannelInfo==nil) {
        return false;
    }
    if(channelInfo.stick != oldChannelInfo.stick) {
        return true;
    }
    if(channelInfo.mute != oldChannelInfo.mute) {
        return true;
    }
    if(![channelInfo.displayName isEqualToString:oldChannelInfo.displayName]) {
        return true;
    }
    return false;
}

#pragma mark-  UITableViewDataSource && UITableViewDelegate

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    // 群聊 tab：使用分组展示列表
    if (_conversationListVM.filterType == WKConversationFilterFollow && self.groupDisplayList) {
        if (indexPath.row >= (NSInteger)self.groupDisplayList.count) return 64.0f;
        WKConversationDisplayItem *item = self.groupDisplayList[indexPath.row];
        if (item.isSectionHeader) return 36.0f;
        WKConversationWrapModel *model = item.conversation;
        // 关注 tab 下，群下面只显示已关注的子区；用 helper 取过滤后的列表来决定 cell 类型
        NSArray<WKThreadModel *> *visiblePreviews = (model && model.channel.channelType == WK_GROUP)
            ? [WKConversationGroupThreadCell visibleThreadPreviewsFor:model] : nil;
        NSInteger visibleCount = (model && model.channel.channelType == WK_GROUP)
            ? [WKConversationGroupThreadCell visibleThreadCountFor:model] : 0;
        if (model && visibleCount > 0 && [WKApp shared].remoteConfig.threadOn && [_conversationListVM isThreadExpanded:model.channel.channelId]) {
            if (visiblePreviews.count > 0) {
                return [WKConversationGroupThreadCell heightForModel:model];
            } else {
                return [WKConversationGroupThreadOnlyCell heightForModel:model];
            }
        }
        // 有 @我 提醒时需要更高的行来显示预览
        if (model && model.simpleReminders.count > 0) {
            for (WKReminder *r in model.simpleReminders) {
                if (r.type == WKReminderTypeMentionMe) return 74.0f;
            }
        }
        return 64.0f;
    }
    // 私聊 tab
    WKConversationWrapModel *model = [_conversationListVM conversationAtIndex:indexPath.row];
    return 76.0f;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if (_conversationListVM.filterType == WKConversationFilterFollow && self.groupDisplayList) {
        return self.groupDisplayList.count;
    }
    return [_conversationListVM conversationCount];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    // 群聊 tab：使用分组展示列表
    if (_conversationListVM.filterType == WKConversationFilterFollow && self.groupDisplayList) {
        if (indexPath.row >= (NSInteger)self.groupDisplayList.count) {
            return [tableView dequeueReusableCellWithIdentifier:@"WKConversationListCell" forIndexPath:indexPath];
        }
        WKConversationDisplayItem *item = self.groupDisplayList[indexPath.row];
        if (item.isSectionHeader) {
            WKCategorySectionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WKCategorySectionCell" forIndexPath:indexPath];
            return cell;
        }
        WKConversationWrapModel *model = item.conversation;
        // 关注 tab：按 followedKeys 过滤后的子区数量决定 cell 类型
        NSInteger visibleCount = (model && model.channel.channelType == WK_GROUP)
            ? [WKConversationGroupThreadCell visibleThreadCountFor:model] : 0;
        NSArray<WKThreadModel *> *visiblePreviews = (model && model.channel.channelType == WK_GROUP)
            ? [WKConversationGroupThreadCell visibleThreadPreviewsFor:model] : nil;
        if (model && visibleCount > 0 && [WKApp shared].remoteConfig.threadOn && [_conversationListVM isThreadExpanded:model.channel.channelId]) {
            if (visiblePreviews.count > 0) {
                WKConversationGroupThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WKConversationGroupThreadCell" forIndexPath:indexPath];
                cell.swipeDelegate = self;
                return cell;
            } else {
                WKConversationGroupThreadOnlyCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WKConversationGroupThreadOnlyCell" forIndexPath:indexPath];
                cell.swipeDelegate = self;
                return cell;
            }
        }
        WKConversationListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WKConversationListCell" forIndexPath:indexPath];
        cell.swipeDelegate = self;
        return cell;
    }
    // 私聊 tab
    WKConversationListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WKConversationListCell" forIndexPath:indexPath];
    cell.swipeDelegate = self;
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    CFAbsoluteTime _wdStart = CFAbsoluteTimeGetCurrent();
    // cell 复用时 alpha 兜底：拖动期间源 cell 被设为 0.3，可能被回收给新行用,
    // 不重置会让别的行显示成半透明。如果当前行就是 drag 源（channelId 同），保持 0.3。
    if (self.cellDragInProgress && self.cellDragSourceChannelId.length > 0) {
        WKConversationWrapModel *m = [_conversationListVM conversationAtIndex:indexPath.row];
        cell.alpha = [m.channel.channelId isEqualToString:self.cellDragSourceChannelId] ? 0.3 : 1.0;
    } else {
        cell.alpha = 1.0;
    }
    // 让 cell 内部的 pan 手势等 tab swipe 手势失败后再识别
    if (self.tabSwipeLeft || self.tabSwipeRight) {
        for (UIGestureRecognizer *gr in cell.gestureRecognizers) {
            if ([gr isKindOfClass:[UIPanGestureRecognizer class]]) {
                if (self.tabSwipeLeft) [gr requireGestureRecognizerToFail:self.tabSwipeLeft];
                if (self.tabSwipeRight) [gr requireGestureRecognizerToFail:self.tabSwipeRight];
            }
        }
    }
    // 群聊 tab
    if (_conversationListVM.filterType == WKConversationFilterFollow && self.groupDisplayList) {
        if (indexPath.row >= (NSInteger)self.groupDisplayList.count) return;
        WKConversationDisplayItem *item = self.groupDisplayList[indexPath.row];
        if (item.isSectionHeader) {
            WKCategorySectionCell *sectionCell = (WKCategorySectionCell *)cell;
            sectionCell.sectionId = item.sectionId;
            sectionCell.sectionTitle = item.sectionTitle;
            sectionCell.collapsed = [_conversationListVM.collapsedSections containsObject:item.sectionId];
            sectionCell.isDefault = item.isDefaultSection;
            sectionCell.groupCount = item.groupCount;
            sectionCell.unreadCount = item.unreadCount;
            sectionCell.hasMention = item.hasMention;
            sectionCell.showTopDivider = (indexPath.row > 0);
            __weak typeof(self) weakSelf = self;
            sectionCell.onToggle = ^(NSString *sectionId, BOOL collapsed) {
                if (collapsed) {
                    [weakSelf.conversationListVM.collapsedSections addObject:sectionId];
                } else {
                    [weakSelf.conversationListVM.collapsedSections removeObject:sectionId];
                }
                [weakSelf.conversationListVM saveCollapsedSections];
                [weakSelf rebuildGroupDisplayAndReload];
            };
            // 长按弹菜单 + 拖拽分发由 VC 的 unifiedLongPress 统一驱动，cell 不再装手势。
            return;
        }
        WKConversationWrapModel *conversationModel = item.conversation;
        if (!conversationModel) return;
        __weak typeof(self) weakSelf = self;
        if ([cell isKindOfClass:[WKConversationGroupThreadCell class]]) {
            WKConversationGroupThreadCell *threadCell = (WKConversationGroupThreadCell *)cell;
            [threadCell refreshWithModel:conversationModel];
            [threadCell setOnThreadPreviewTap:^(NSString *threadChannelId) {
                WKChannel *channel = [WKChannel channelID:threadChannelId channelType:WK_COMMUNITY_TOPIC];
                [[WKApp shared] invoke:WKPOINT_CONVERSATION_SHOW param:channel];
            }];
            [threadCell setOnMoreThreadsTap:^(NSString *groupNo) {
                WKThreadListVC *vc = [WKThreadListVC new];
                vc.groupNo = groupNo;
                [[WKNavigationManager shared] pushViewController:vc animated:YES];
            }];
            [threadCell setOnToggleThreadPreview:^(NSString *channelId) {
                [weakSelf.conversationListVM toggleThreadExpanded:channelId];
                [weakSelf rebuildGroupDisplayAndReload];
            }];
            [threadCell setOnThreadPreviewLongPress:^(NSString *threadChannelId, NSString *threadName, CGPoint pointInWindow) {
                [weakSelf showThreadMuteMenuForChannelId:threadChannelId threadName:threadName atPoint:pointInWindow];
            }];
        } else if ([cell isKindOfClass:[WKConversationGroupThreadOnlyCell class]]) {
            WKConversationGroupThreadOnlyCell *threadOnlyCell = (WKConversationGroupThreadOnlyCell *)cell;
            [threadOnlyCell refreshWithModel:conversationModel];
            [threadOnlyCell setOnMoreThreadsTap:^(NSString *groupNo) {
                WKThreadListVC *vc = [WKThreadListVC new];
                vc.groupNo = groupNo;
                [[WKNavigationManager shared] pushViewController:vc animated:YES];
            }];
            [threadOnlyCell setOnToggleThreadPreview:^(NSString *channelId) {
                [weakSelf.conversationListVM toggleThreadExpanded:channelId];
                [weakSelf rebuildGroupDisplayAndReload];
            }];
        } else if ([cell isKindOfClass:[WKConversationListCell class]]) {
            WKConversationListCell *listCell = (WKConversationListCell *)cell;
            listCell.recentTabContext = NO; // 关注 tab 用 group-summary 风格
            [listCell refreshWithModel:conversationModel];
            [listCell setOnToggleThreadPreview:^(NSString *channelId) {
                [weakSelf.conversationListVM toggleThreadExpanded:channelId];
                [weakSelf rebuildGroupDisplayAndReload];
            }];
        }
        // cell 维度的长按手势已下线 — 长按弹菜单 / Follow tab 拖拽由 VC 上的
        // unifiedLongPress 统一驱动（详见 setupUnifiedLongPressGesture / onUnifiedLongPress:）
        CFAbsoluteTime _wdElapsed = (CFAbsoluteTimeGetCurrent() - _wdStart) * 1000;
        if (_wdElapsed > 8) NSLog(@"[TabPerf] willDisplayCell(group) row=%ld %.1fms %@", (long)indexPath.row, _wdElapsed, NSStringFromClass([cell class]));
        return;
    }
    // 私聊 tab
    WKConversationWrapModel *conversationModel = [_conversationListVM conversationAtIndex:indexPath.row];
    if (!conversationModel) return;
    WKConversationListCell *conversationListCell = (WKConversationListCell *)cell;
    conversationListCell.recentTabContext = (_conversationListVM.filterType == WKConversationFilterRecent);
    [conversationListCell refreshWithModel:conversationModel];
    // 长按弹菜单同样走 unifiedLongPress（按 Began 时 indexPath 反查模型）。
    CFAbsoluteTime _wdElapsed2 = (CFAbsoluteTimeGetCurrent() - _wdStart) * 1000;
    if (_wdElapsed2 > 8) NSLog(@"[TabPerf] willDisplayCell(private) row=%ld %.1fms", (long)indexPath.row, _wdElapsed2);
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    WKConversationWrapModel *conversationModel = [_conversationListVM conversationAtIndex:indexPath.row];
    if(conversationModel) {
        [conversationModel cancelChannelRequest];
    }
    // 仅还原 alpha，不再主动 resetCellDragState：长按手势已上移到 self.view，不会
    // 随源 cell 回收一起销毁，所以源 cell 离场不会导致 Ended/Cancelled 漏触发。
    // 拖动期间用户拖出 tableView 边缘再拖回来时，snapshot/手势保持完整，bug 1 消除。
    if (self.cellDragInProgress && cell == self.cellDragSourceCell) {
        cell.alpha = 1.0;
    }
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // 群聊 tab: section header 不进入聊天
    if (_conversationListVM.filterType == WKConversationFilterFollow && self.groupDisplayList) {
        if (indexPath.row >= (NSInteger)self.groupDisplayList.count) return;
        WKConversationDisplayItem *item = self.groupDisplayList[indexPath.row];
        if (item.isSectionHeader) return;
    }

     WKConversationWrapModel *conversationModel;
    if (_conversationListVM.filterType == WKConversationFilterFollow && self.groupDisplayList) {
        conversationModel = self.groupDisplayList[indexPath.row].conversation;
    } else {
        conversationModel = [_conversationListVM conversationAtIndex:indexPath.row];
    }
    // 防止重复点击
    WKChannel *channel = conversationModel.channel;
    static bool canSelect = true;
    if (canSelect){
        canSelect = false;
        dispatch_async(dispatch_get_main_queue(), ^{
            canSelect = true;
            
            NSString *chatPwd = [WKApp shared].loginInfo.extra[@"chat_pwd"];
            if(conversationModel.channelInfo && chatPwd && ![chatPwd isEqualToString:@""]) {
                __weak typeof(self) weakSelf = self;
                BOOL chatPwdOn = [conversationModel.channelInfo settingForKey:WKChannelExtraKeyChatPwd defaultValue:false];
                if(chatPwdOn) {
                    __block NSInteger errorCount = [self getChatPwdErrorCount:channel];
                    WKPwdKeyboardInputView *vw = [WKPwdKeyboardInputView new];
                    vw.remark = LLang(@"聊天密码");
                    [vw setFinishBlock:^(NSString * _Nonnull pwd) {
                        if([[self digestPwd:pwd] isEqualToString:chatPwd]) {
                            [weakSelf toConversation:conversationModel];
                            [weakSelf setChatPwdErrorCount:0 channel:channel];
                        }else {
                            errorCount++;
                            [weakSelf setChatPwdErrorCount:errorCount channel:channel];
                            if(errorCount >=3) {
                                [WKAlertUtil alert:LLang(@"连续错误次数太多，已删除该聊天记录！") title:LLangW(@"错误密码",weakSelf)];
                            }else{
                                [WKAlertUtil alert:[NSString stringWithFormat:LLang(@"还连续%ld次输入错误，将会清空该聊天记录！\n如果您忘记聊天密码，您可以重置聊天密码"),3- (long)errorCount] title:LLangW(@"错误密码",weakSelf)];
                            }
                           
                            if(errorCount>=3) {
                                [[WKMessageManager shared] clearMessages:conversationModel.channel];
                                [weakSelf setChatPwdErrorCount:0 channel:channel];
                            }
                        }
                        
                    }];
                    [vw setOtherButtonClickBlock:^(UIButton *btn) {
                        WKConversationPasswordVC *vc = [WKConversationPasswordVC new];
                        [[WKNavigationManager shared] pushViewController:vc animated:YES];
                    }];
                    [vw show];
                    return;
                }
            };
            [self toConversation:conversationModel];
        });
    }
    else
        return;
}

-(NSString*) digestPwd:(NSString*)pwd {
    return [WKMD5Util md5HexDigest:[NSString stringWithFormat:@"%@%@",pwd,[WKApp shared].loginInfo.uid]];
}

#pragma  mark -- SwipeTableViewCellDelegate

- (SwipeTableCellStyle)tableView:(UITableView *)tableView styleOfSwipeButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return SwipeTableCellStyleRightToLeft;
}

/**
 *  右滑cell时显示的button
 *
 *  @param indexPath cell的位置
 */
- (NSArray<SwipeButton *> *)tableView:(UITableView *)tableView rightSwipeButtonsAtIndexPath:(NSIndexPath *)indexPath {
    // 左滑已替换为长按弹窗菜单
    return @[];
}

- (NSArray<SwipeButton *> *)tableView:(UITableView *)tableView leftSwipeButtonsAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

#pragma mark - 会话长按弹窗菜单 + 关注 tab 拖拽

/// 装一个 table-level 的长按手势，所有"长按弹菜单 + 拖动重排"逻辑都从这里分发。
/// 装在 self.view 上而不是 cell 上 —— 手势生命周期与 VC 同步，不会随 cell 回收
/// 一起被销毁。这样 ① 拖动期间源 cell 被回收时 Ended/Cancelled 仍能正常触发，
/// snapshot 不会卡死；② 拖出 tableView 边缘后再拖回不会因 didEndDisplayingCell
/// 主动清理而丢失 snapshot。
- (void)setupUnifiedLongPressGesture {
    if (self.unifiedLongPress) return;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
                                        initWithTarget:self action:@selector(onUnifiedLongPress:)];
    lp.minimumPressDuration = 0.5; // 与旧 cell-level 长按对齐，保证短点击不被吃掉
    // 不设 delegate / cancelsTouchesInView，让 tableView pan / cell tap 该工作还能工作 —
    // UILongPressGestureRecognizer 默认 allowableMovement=10 满足"拖动时长按失败、长按时
    // 不触发滚动"的常规交互；真正进入拖动后 beginCellDragForCell 会关 tableView.scrollEnabled
    // 防止表格继续被手指 pan。
    [self.view addGestureRecognizer:lp];
    self.unifiedLongPress = lp;
}

- (void)onUnifiedLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint locInView = [gesture locationInView:self.view];
        CGPoint locInTable = [self.view convertPoint:locInView toView:self.tableView];
        NSIndexPath *path = [self.tableView indexPathForRowAtPoint:locInTable];
        if (!path) return; // 长按落在表格之外（如 tabBar 区）→ 当作误触
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:path];
        if (!cell) return;

        BOOL isFollowTab = (self.conversationListVM.filterType == WKConversationFilterFollow);

        // Follow tab section header
        if (isFollowTab && self.groupDisplayList && path.row < (NSInteger)self.groupDisplayList.count) {
            WKConversationDisplayItem *item = self.groupDisplayList[path.row];
            if (item.isSectionHeader) {
                if (item.isDefaultSection) {
                    // 默认分组不允许长按管理 / 拖拽
                    return;
                }
                UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                [feedback impactOccurred];
                if ([cell isKindOfClass:[WKCategorySectionCell class]]) {
                    WKCategorySectionCell *sectionCell = (WKCategorySectionCell *)cell;
                    [sectionCell setLongPressHighlighted:YES];
                    self.cellDragHighlightedSectionCell = sectionCell;
                }
                CGPoint ptInWindow = [gesture locationInView:nil];
                [self showSectionManagePopup:item.sectionId title:item.sectionTitle atPoint:ptInWindow];

                self.cellDragInProgress = NO;
                self.cellDragStartLocation = locInView;
                self.cellDragSourceIndexPath = path;
                self.cellDragSourceSectionId = item.sectionId;
                self.cellDragSourceConvName = nil;
                self.cellDragSourceChannelId = nil;
                self.cellDragSourceModel = nil;
                self.cellDragSourceCell = cell;
                return;
            }
        }

        // 会话 row（Follow tab 或 Recent tab 都走这里弹菜单；只有 Follow tab 才进入拖拽）
        WKConversationWrapModel *model = nil;
        if (isFollowTab && self.groupDisplayList && path.row < (NSInteger)self.groupDisplayList.count) {
            model = self.groupDisplayList[path.row].conversation;
        } else {
            model = [self.conversationListVM conversationAtIndex:path.row];
        }
        if (!model) return;

        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
        CGPoint ptInWindow = [gesture locationInView:nil];
        [self showConversationMenuForModel:model atPoint:ptInWindow];

        if (isFollowTab) {
            self.cellDragInProgress = NO;
            self.cellDragStartLocation = locInView;
            self.cellDragSourceIndexPath = path;
            self.cellDragSourceConvName = model.channelInfo.displayName ?: model.channel.channelId;
            self.cellDragSourceChannelId = model.channel.channelId;
            self.cellDragSourceSectionId = nil;
            self.cellDragSourceModel = model;
            self.cellDragSourceCell = cell;
        }
        return;
    }

    if (gesture.state == UIGestureRecognizerStateChanged) {
        if (self.conversationListVM.filterType != WKConversationFilterFollow) return;
        BOOL hasSource = (self.cellDragSourceChannelId.length > 0) || (self.cellDragSourceSectionId.length > 0);
        if (!hasSource) return;
        CGPoint locInView = [gesture locationInView:self.view];
        if (!self.cellDragInProgress) {
            CGFloat dx = locInView.x - self.cellDragStartLocation.x;
            CGFloat dy = locInView.y - self.cellDragStartLocation.y;
            if (hypot(dx, dy) > 12.0) {
                UITableViewCell *src = self.cellDragSourceCell;
                if (!src && self.cellDragSourceIndexPath) {
                    src = [self.tableView cellForRowAtIndexPath:self.cellDragSourceIndexPath];
                }
                if (!src) return; // 源 cell 已离屏且无法重取，放弃这次拖动尝试
                // section header 拖拽真正开始时把高亮还原（避免 snapshot 抓到高亮态）
                if (self.cellDragHighlightedSectionCell) {
                    [self.cellDragHighlightedSectionCell setLongPressHighlighted:NO];
                    self.cellDragHighlightedSectionCell = nil;
                }
                if (self.cellDragSourceSectionId.length > 0) {
                    [self beginSectionDragForCell:src atLocation:locInView];
                } else {
                    [self beginCellDragForCell:src atLocation:locInView];
                }
            }
        } else {
            [self updateCellDragAtLocation:locInView];
        }
        return;
    }

    if (gesture.state == UIGestureRecognizerStateEnded
        || gesture.state == UIGestureRecognizerStateCancelled
        || gesture.state == UIGestureRecognizerStateFailed) {
        // section header 长按未进入拖拽就抬手 → 还原高亮
        if (self.cellDragHighlightedSectionCell) {
            [self.cellDragHighlightedSectionCell setLongPressHighlighted:NO];
            self.cellDragHighlightedSectionCell = nil;
        }
        if (self.cellDragInProgress) {
            CGPoint locInView = [gesture locationInView:self.view];
            if (self.cellDragSourceSectionId.length > 0) {
                [self endSectionDragAtLocation:locInView];
            } else if (self.cellDragSourceModel) {
                [self endCellDragAtLocation:locInView model:self.cellDragSourceModel];
            } else {
                [self resetCellDragState];
            }
        } else {
            [self resetCellDragState];
        }
    }
}

#pragma mark - 关注 tab 拖拽排序（方案 A）

#pragma mark - 分组 section header 拖拽 begin/end

- (void)beginSectionDragForCell:(UITableViewCell *)cell atLocation:(CGPoint)loc {
    self.cellDragInProgress = YES;
    self.pendingRebuildAfterDrag = NO;
    [self dismissFloatingMenu];
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];

    // 还原 cell 视觉变换（cell 的 longPress 在 Began 时把 transform 设到 0.98 + bg 高亮,
    // 不同步还原会让 snapshot 抓到错误形状）
    cell.transform = CGAffineTransformIdentity;
    cell.contentView.backgroundColor = [UIColor clearColor];

    UIWindow *win = self.view.window;
    UIView *snapHost = win ?: self.view; // 没 window 时回退到 self.view，保证不崩
    UIView *snap = [cell snapshotViewAfterScreenUpdates:YES];
    snap.layer.shadowColor = [UIColor blackColor].CGColor;
    snap.layer.shadowOpacity = 0.18;
    snap.layer.shadowOffset = CGSizeMake(0, 4);
    snap.layer.shadowRadius = 8;
    snap.alpha = 0.95;
    CGRect cellFrameInHost = [self.tableView convertRect:cell.frame toView:snapHost];
    snap.frame = cellFrameInHost;
    [snapHost addSubview:snap];
    self.cellDragSnapshot = snap;

    UIView *line = [[UIView alloc] init];
    UIColor *baseTheme = [WKApp shared].config.themeColor ?: [UIColor colorWithRed:138.0/255 green:91.0/255 blue:255.0/255 alpha:1];
    UIColor *deepTheme = [UIColor colorWithRed:88.0/255 green:48.0/255 blue:220.0/255 alpha:1];
    line.backgroundColor = deepTheme;
    line.layer.cornerRadius = 2;
    line.layer.shadowColor = baseTheme.CGColor;
    line.layer.shadowOpacity = 0.7;
    line.layer.shadowOffset = CGSizeZero;
    line.layer.shadowRadius = 6;
    line.hidden = YES;
    [snapHost addSubview:line]; // 同 host，保证 bringSubviewToFront 能把线压在 snapshot 之上
    self.cellDragInsertionLine = line;

    // 关闭表格滚动 — 拖动期间统一由 auto-scroll displayLink 驱动 contentOffset，
    // 避免用户手指被同时识别为表格 pan 而出现 snapshot 跟 cell 各走各的。
    self.tableView.scrollEnabled = NO;

    cell.alpha = 0.3;
    self.cellDragSourceCell = cell;

    [self updateCellDragAtLocation:loc];
}

- (void)endSectionDragAtLocation:(CGPoint)loc {
    NSString *sourceSectionId = self.cellDragSourceSectionId;
    NSIndexPath *targetPath = self.cellDragLastTargetPath;
    if (!targetPath) {
        CGPoint locInTable = [self.view convertPoint:loc toView:self.tableView];
        targetPath = [self.tableView indexPathForRowAtPoint:locInTable];
    }
    BOOL insertBelow = self.cellDragLastInsertBelow;

    [self cleanupCellDragSnapshot];

    if (sourceSectionId.length == 0 || !targetPath) {
        [self resetCellDragState];
        return;
    }

    // 解析目标 section: 沿 groupDisplayList 向上找最近 header；insertBelow 决定落在
    // 该 section 之前还是之后。
    NSString *targetSectionId = [self resolveTargetCategoryIdForRow:targetPath.row];
    if (targetSectionId.length == 0 || [targetSectionId isEqualToString:sourceSectionId]) {
        [self resetCellDragState];
        return;
    }

    // 计算 categoryList 中 source / target 的位置 + 决定最终插入索引
    NSArray<WKCategoryEntity *> *all = self.conversationListVM.categoryList;
    NSInteger srcIdx = -1, tgtIdx = -1;
    for (NSInteger i = 0; i < (NSInteger)all.count; i++) {
        WKCategoryEntity *cat = all[i];
        if (cat.is_default) continue;
        if ([cat.category_id isEqualToString:sourceSectionId]) srcIdx = i;
        else if ([cat.category_id isEqualToString:targetSectionId]) tgtIdx = i;
    }
    if (srcIdx < 0 || tgtIdx < 0) {
        [self resetCellDragState];
        return;
    }

    NSInteger insertIdx = insertBelow ? tgtIdx + 1 : tgtIdx;
    // 移除 src 之后，src 之前的索引不变；src 之后的索引整体 -1
    if (srcIdx < insertIdx) insertIdx--;
    if (insertIdx == srcIdx) {
        // 没动 — 落到自己原位
        [self resetCellDragState];
        return;
    }

    // 1) 本地乐观重排 categoryList
    NSMutableArray<WKCategoryEntity *> *next = [all mutableCopy];
    WKCategoryEntity *moving = next[srcIdx];
    [next removeObjectAtIndex:srcIdx];
    if (insertIdx > (NSInteger)next.count) insertIdx = next.count;
    [next insertObject:moving atIndex:insertIdx];
    self.conversationListVM.categoryList = next;
    [self resetCellDragState]; // 清拖拽状态（含 sectionId），rebuild 后才能生效
    [self rebuildGroupDisplayAndReload];

    // 2) 提交完整顺序 — sortCategories 接收所有 category_id 的有序数组
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if (spaceId.length == 0) return;
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    for (WKCategoryEntity *cat in next) {
        if (cat.category_id.length > 0) [ids addObject:cat.category_id];
    }
    __weak typeof(self) weakSelf = self;
    [[WKCategoryService shared] sortCategories:spaceId categoryIds:ids].then(^(id _) {
        // server 已采纳新顺序 — 拉一次最新 categories（顺便兜住跨设备同时改的 race）
        [weakSelf loadCategories];
    }).catch(^(NSError *err) {
        NSLog(@"[CategorySort] failed: %@", err);
        [weakSelf loadCategories]; // 回退到 server 真值
    });
}

#pragma mark -

- (void)beginCellDragForCell:(UITableViewCell *)cell atLocation:(CGPoint)loc {
    self.cellDragInProgress = YES;
    self.pendingRebuildAfterDrag = NO;
    [self dismissFloatingMenu]; // 关掉菜单
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];

    UIWindow *win = self.view.window;
    UIView *snapHost = win ?: self.view;
    // 取 cell 截图作为拖动跟随的 snapshot
    UIView *snap = [cell snapshotViewAfterScreenUpdates:YES];
    snap.layer.shadowColor = [UIColor blackColor].CGColor;
    snap.layer.shadowOpacity = 0.18;
    snap.layer.shadowOffset = CGSizeMake(0, 4);
    snap.layer.shadowRadius = 8;
    snap.alpha = 0.95;
    CGRect cellFrameInHost = [self.tableView convertRect:cell.frame toView:snapHost];
    snap.frame = cellFrameInHost;
    [snapHost addSubview:snap];
    self.cellDragSnapshot = snap;

    // 插入指示线：与 snapshot 同 host（snapHost）。挂到 window 而非 self.view 的好处：
    // ① 拖到导航栏 / tabBar 区域不会被父视图裁切；② 跟 snapshot 在同一坐标系，
    // bringSubviewToFront 能稳定保证线压在 snapshot 之上。每次 updateInsertionLineAtLocation:
    // 重算 host 坐标。
    UIView *line = [[UIView alloc] init];
    UIColor *baseTheme = [WKApp shared].config.themeColor ?: [UIColor colorWithRed:138.0/255 green:91.0/255 blue:255.0/255 alpha:1];
    // 比 theme 紫深 ~15%：让线在白底 / 群头像 / 各种内容上都醒目
    UIColor *deepTheme = [UIColor colorWithRed:88.0/255 green:48.0/255 blue:220.0/255 alpha:1];
    line.backgroundColor = deepTheme;
    line.layer.cornerRadius = 2;
    line.layer.shadowColor = baseTheme.CGColor;
    line.layer.shadowOpacity = 0.7;
    line.layer.shadowOffset = CGSizeZero;
    line.layer.shadowRadius = 6; // 发光晕 — 被 snapshot 盖到边缘时也能看出位置
    line.hidden = YES;
    [snapHost addSubview:line];
    self.cellDragInsertionLine = line;

    // 关闭表格滚动 — 详见 beginSectionDragForCell 同处注释。
    self.tableView.scrollEnabled = NO;

    cell.alpha = 0.3; // 原 cell 半透明提示"正在被拖动"
    self.cellDragSourceCell = cell; // weak ref，didEndDisplayingCell 时按引用比较

    [self updateCellDragAtLocation:loc];
}

- (void)updateCellDragAtLocation:(CGPoint)loc {
    self.cellDragLastLocation = loc;
    // snapshot 在 snapHost（window 优先，回退 self.view）坐标系下；loc 是 self.view 坐标，
    // 需要换到 snapshot 所在的 superview 坐标再设置 frame，否则跨 host 时 y 偏移会错。
    UIView *snapHost = self.cellDragSnapshot.superview ?: self.view;
    CGPoint locInHost = [self.view convertPoint:loc toView:snapHost];
    CGRect f = self.cellDragSnapshot.frame;
    f.origin.y = locInHost.y - f.size.height / 2.0f;
    self.cellDragSnapshot.frame = f;
    // 接近表格上下边缘时设置 auto-scroll 速度，由 CADisplayLink 平滑驱动；
    // 之前在 gesture update 里直接 setContentOffset 会让带子区预览的高 cell 卡死
    // —— 高 cell 重新布局时 heightForRow / cellForRow 同步阻塞主线程，gesture update
    // 又快速堆积 setContentOffset 调用，主线程过载就卡。改 displayLink 每帧只算
    // 一次稳定多了。
    //
    // 触发区按"可视内容区"算（扣掉 adjustedContentInset 上下） — tableView.frame 底部
    // 常被 tab bar / safe area 覆盖，按 frame 边缘判定的话用户手指物理够不到那里 (touch
    // 走不到 tab bar 上)，autoscroll 永远不触发，最后一行被遮住看不到。
    CGRect tableInView = [self.view convertRect:self.tableView.bounds fromView:self.tableView];
    UIEdgeInsets ins = self.tableView.adjustedContentInset;
    CGFloat visibleTop = CGRectGetMinY(tableInView) + ins.top;
    CGFloat visibleBottom = CGRectGetMaxY(tableInView) - ins.bottom;
    CGFloat edgeZone = 60;
    CGFloat maxStep = 12;
    CGFloat velocity = 0;
    if (loc.y < visibleTop + edgeZone) {
        CGFloat depth = (visibleTop + edgeZone) - loc.y;
        velocity = -MIN(maxStep, MAX(2, depth / 5.0));
    } else if (loc.y > visibleBottom - edgeZone) {
        CGFloat depth = loc.y - (visibleBottom - edgeZone);
        velocity = MIN(maxStep, MAX(2, depth / 5.0));
    }
    self.cellDragAutoScrollVelocity = velocity;
    if (velocity != 0 && !self.cellDragAutoScrollLink) {
        self.cellDragAutoScrollLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onCellDragAutoScrollTick:)];
        [self.cellDragAutoScrollLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    } else if (velocity == 0 && self.cellDragAutoScrollLink) {
        [self.cellDragAutoScrollLink invalidate];
        self.cellDragAutoScrollLink = nil;
    }
    // 更新插入位置指示线
    [self updateInsertionLineAtLocation:loc];
}

- (void)onCellDragAutoScrollTick:(CADisplayLink *)link {
    CGFloat v = self.cellDragAutoScrollVelocity;
    if (v == 0 || !self.cellDragInProgress) {
        [self.cellDragAutoScrollLink invalidate];
        self.cellDragAutoScrollLink = nil;
        return;
    }
    CGFloat newY = self.tableView.contentOffset.y + v;
    // contentOffset.y 的合法范围是 [-adjustedContentInset.top,
    //  contentSize.height + adjustedContentInset.bottom - bounds.height]，旧实现 clamp
    // 到 [0, contentSize-bounds]，少算了 bottom inset，autoscroll 滚不到能完整露出最后
    // 一行的位置（最后一行被 tab bar 遮住）。
    UIEdgeInsets ins = self.tableView.adjustedContentInset;
    CGFloat minY = -ins.top;
    CGFloat maxY = self.tableView.contentSize.height + ins.bottom - self.tableView.bounds.size.height;
    if (maxY < minY) maxY = minY;
    newY = MAX(minY, MIN(maxY, newY));
    [self.tableView setContentOffset:CGPointMake(0, newY) animated:NO];
    // 滚屏时手指虽然没动，但相对内容的位置变了 — 重算插入线
    [self updateInsertionLineAtLocation:self.cellDragLastLocation];
}

/// 把插入线放到目标行的上 / 下边缘。section header 一律落在 header 下方（即该分组开头）。
/// 普通行按手指 Y 跟行中线的关系决定插入到上 / 下。
/// 线与 snapshot 同 host（snapHost：window 优先，回退 self.view）；每次都做一次 convertRect:。
- (void)updateInsertionLineAtLocation:(CGPoint)loc {
    if (!self.cellDragInsertionLine) return;
    UIView *lineHost = self.cellDragInsertionLine.superview ?: self.view;
    CGPoint locInTable = [self.view convertPoint:loc toView:self.tableView];
    NSIndexPath *path = [self.tableView indexPathForRowAtPoint:locInTable];
    if (!path) {
        self.cellDragInsertionLine.hidden = YES;
        self.cellDragLastTargetPath = nil;
        return;
    }
    CGRect rectInTable = [self.tableView rectForRowAtIndexPath:path];
    BOOL insertBelow;
    WKConversationDisplayItem *it = (path.row < (NSInteger)self.groupDisplayList.count) ? self.groupDisplayList[path.row] : nil;
    BOOL isSectionDrag = self.cellDragSourceSectionId.length > 0;
    if (it.isSectionHeader) {
        // 拖会话到 header → 进入该 section 顶部（insertBelow=YES）
        // 拖 section 到另一个 header → 落到该 section 之前（insertBelow=NO，更直观）
        insertBelow = !isSectionDrag;
    } else {
        insertBelow = (locInTable.y - rectInTable.origin.y) > rectInTable.size.height / 2.0;
    }
    // 换到 lineHost 坐标系再算线的 frame（同时支持 window / self.view 两种 host）
    CGRect rectInHost = [self.tableView convertRect:rectInTable toView:lineHost];
    CGFloat lineY = insertBelow ? CGRectGetMaxY(rectInHost) : CGRectGetMinY(rectInHost);
    CGFloat lineThickness = 4.0;
    CGFloat lineLeft = CGRectGetMinX(rectInHost) + 12;
    CGFloat lineRight = CGRectGetMaxX(rectInHost) - 12;
    self.cellDragInsertionLine.frame = CGRectMake(lineLeft, lineY - lineThickness / 2.0, lineRight - lineLeft, lineThickness);
    self.cellDragInsertionLine.hidden = NO;
    [lineHost bringSubviewToFront:self.cellDragInsertionLine]; // 始终在 snapshot 之上
    self.cellDragLastTargetPath = path;
    self.cellDragLastInsertBelow = insertBelow;
}

- (void)endCellDragAtLocation:(CGPoint)loc model:(WKConversationWrapModel *)model {
    NSIndexPath *targetPath = self.cellDragLastTargetPath;
    if (!targetPath) {
        CGPoint locInTable = [self.view convertPoint:loc toView:self.tableView];
        targetPath = [self.tableView indexPathForRowAtPoint:locInTable];
    }
    if (!targetPath) {
        // 落到了空白处：找最接近的 row
        NSInteger lastRow = [self.tableView numberOfRowsInSection:0] - 1;
        if (lastRow >= 0) targetPath = [NSIndexPath indexPathForRow:lastRow inSection:0];
    }

    NSString *targetCategoryId = [self resolveTargetCategoryIdForRow:targetPath.row];
    NSString *targetCategoryName = [self categoryNameById:targetCategoryId];
    NSString *sourceCategoryId = [self resolveTargetCategoryIdForRow:self.cellDragSourceIndexPath.row];
    NSInteger sourceRow = self.cellDragSourceIndexPath.row;
    NSInteger destRow = self.cellDragLastInsertBelow ? targetPath.row + 1 : targetPath.row;
    BOOL insertBelow = self.cellDragLastInsertBelow;
    // 拖到 section header 时矫正落点 —— 不矫正会把 conv 插到 header 之前（即上一个 section
    // 末尾），随后 reorderInCategory 的 payload 收集从 header 之后开始 → moving item 被漏掉,
    // PUT /follow/sort 提交不完整顺序。statement: 拖到 header 一律语义为"放到该 section 的
    // 第一行"（顶部），把 destRow 矫正到 header + 1。
    if (targetPath.row >= 0 && targetPath.row < (NSInteger)self.groupDisplayList.count) {
        WKConversationDisplayItem *targetItem = self.groupDisplayList[targetPath.row];
        if (targetItem.isSectionHeader) {
            destRow = targetPath.row + 1;
            insertBelow = YES;
        }
    }

    [self cleanupCellDragSnapshot];

    // 同分组拖动 → 分组内重排（参考 web ChatConversationList.handleSortFollowItems:
    // 本地乐观重排 + PUT /v1/follow/sort 提交完整 bucket 顺序，CAS 失败时 reload）
    if (targetCategoryId.length > 0 && [targetCategoryId isEqualToString:sourceCategoryId]) {
        [self resetCellDragState];
        if (sourceRow != destRow && sourceRow + 1 != destRow) {
            // 不是"自己拖到自己原位"才做实际重排
            [self reorderInCategory:targetCategoryId fromGlobalRow:sourceRow toGlobalRow:destRow];
        }
        return;
    }
    // 拖到默认分组 / 不可识别区域：忽略
    if (targetCategoryId.length == 0) {
        [self resetCellDragState];
        return;
    }

    NSString *convName = self.cellDragSourceConvName ?: @"";
    [self resetCellDragState];

    // 跨分组移动：DM 用 followDM(peer_uid, category_id) 覆盖；群用 moveGroup
    __weak typeof(self) weakSelf = self;
    if (model.channel.channelType == WK_PERSON) {
        [[WKFollowService shared] followDM:model.channel.channelId categoryId:targetCategoryId].then(^(id _) {
            [[WKFollowedKeysStore shared] reload];
            [weakSelf showMovedToast:convName toCategory:targetCategoryName];
        }).catch(^(NSError *err) {
            [[WKNavigationManager shared].topViewController.view showMsg:err.domain ?: LLang(@"移动失败")];
        });
    } else if (model.channel.channelType == WK_GROUP) {
        [[WKCategoryService shared] moveGroup:model.channel.channelId toCategoryId:targetCategoryId].then(^(id _) {
            [[WKFollowedKeysStore shared] reload];
            [weakSelf loadCategories];
            [weakSelf showMovedToast:convName toCategory:targetCategoryName];
        }).catch(^(NSError *err) {
            [[WKNavigationManager shared].topViewController.view showMsg:err.domain ?: LLang(@"移动失败")];
        });
    }
}

#pragma mark - 关注 tab 分组内重排（PUT /v1/follow/sort）

/// 在某分组内把 fromGlobalRow 拖到 toGlobalRow（global = groupDisplayList 行号）。
/// 1) 本地乐观更新 displayList 顺序 + reloadData 让用户立刻看到
/// 2) 计算该分组当前完整顺序 → 调 sortItems:version: 提交
/// 3) 成功 → reload sidebar 让 store 同步新 follow_sort
///    版本冲突 → reload + 提示用户
///    其它错误 → log + 用 server 真值重建（rebuildGroupDisplayAndReload）
- (void)reorderInCategory:(NSString *)catId fromGlobalRow:(NSInteger)fromIdx toGlobalRow:(NSInteger)toIdx {
    NSArray<WKConversationDisplayItem *> *list = self.groupDisplayList;
    if (fromIdx < 0 || fromIdx >= (NSInteger)list.count) return;
    if (toIdx < 0 || toIdx > (NSInteger)list.count) return;
    WKConversationDisplayItem *moving = list[fromIdx];
    if (moving.isSectionHeader || moving.conversation == nil) return;

    // 1) 本地乐观重排 displayList — 用户立即看到新顺序
    NSMutableArray<WKConversationDisplayItem *> *next = [list mutableCopy];
    [next removeObjectAtIndex:fromIdx];
    NSInteger insertAt = toIdx;
    if (toIdx > fromIdx) insertAt--;
    if (insertAt > (NSInteger)next.count) insertAt = next.count;
    [next insertObject:moving atIndex:insertAt];
    self.groupDisplayList = [next copy];
    [self.tableView reloadData];

    // 2) 收集该分组内的所有 wrap，按当前顺序生成 sortItems
    NSInteger sectionStart = -1, sectionEnd = -1;
    for (NSInteger i = 0; i < (NSInteger)self.groupDisplayList.count; i++) {
        WKConversationDisplayItem *it = self.groupDisplayList[i];
        if (it.isSectionHeader && [it.sectionId isEqualToString:catId]) {
            sectionStart = i + 1;
            for (NSInteger j = sectionStart; j < (NSInteger)self.groupDisplayList.count; j++) {
                if (self.groupDisplayList[j].isSectionHeader) { sectionEnd = j; break; }
            }
            if (sectionEnd == -1) sectionEnd = self.groupDisplayList.count;
            break;
        }
    }
    if (sectionStart < 0) return;

    NSMutableArray<WKFollowSortItem *> *sortItems = [NSMutableArray array];
    NSInteger sortIdx = 0;
    for (NSInteger i = sectionStart; i < sectionEnd; i++) {
        WKConversationDisplayItem *it = self.groupDisplayList[i];
        WKConversationWrapModel *wrap = it.conversation;
        if (!wrap) continue;
        WKFollowSortItem *si = [[WKFollowSortItem alloc] init];
        if (wrap.channel.channelType == WK_PERSON) si.target_type = WKFollowTargetTypeDM;
        else if (wrap.channel.channelType == WK_GROUP) si.target_type = WKFollowTargetTypeChannel;
        else continue;
        si.target_id = wrap.channel.channelId;
        si.sort = sortIdx++;
        [sortItems addObject:si];
    }
    if (sortItems.count == 0) return;

    NSInteger version = [WKFollowedKeysStore shared].followVersion;
    __weak typeof(self) weakSelf = self;
    [[WKFollowService shared] sortItems:sortItems version:version].then(^(id _) {
        [[WKFollowedKeysStore shared] reload]; // 刷 store 拿到新 follow_sort
    }).catch(^(NSError *err) {
        if ([WKFollowService isVersionConflictError:err]) {
            // 跨设备已改过 — 拉一次最新 + 重建 + 提示
            [[WKFollowedKeysStore shared] reload];
            [weakSelf rebuildGroupDisplayAndReload];
            [[WKNavigationManager shared].topViewController.view showMsg:LLang(@"顺序已被其它设备更新")];
        } else {
            NSLog(@"[Sort] failed: %@", err);
            [weakSelf rebuildGroupDisplayAndReload]; // 回退到 server 真值
        }
    });
}

/// 给定关注 tab 的 row index，返回它属于哪个分类（沿 groupDisplayList 向上找最近的
/// section header）
- (NSString *)resolveTargetCategoryIdForRow:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.groupDisplayList.count) return @"";
    for (NSInteger i = row; i >= 0; i--) {
        WKConversationDisplayItem *it = self.groupDisplayList[i];
        if (it.isSectionHeader) return it.sectionId ?: @"";
    }
    return @"";
}

- (void)cleanupCellDragSnapshot {
    [self.cellDragSnapshot removeFromSuperview];
    self.cellDragSnapshot = nil;
    [self.cellDragInsertionLine removeFromSuperview];
    self.cellDragInsertionLine = nil;
    [self.cellDragAutoScrollLink invalidate];
    self.cellDragAutoScrollLink = nil;
    self.cellDragAutoScrollVelocity = 0;
    // 恢复表格滚动（beginCellDragForCell / beginSectionDragForCell 中关闭过）
    self.tableView.scrollEnabled = YES;
    // 还原所有 cell 的 alpha（被拖的 cell 改成 0.3）
    for (UITableViewCell *c in self.tableView.visibleCells) {
        if (c.alpha < 1.0) c.alpha = 1.0;
    }
}

- (void)resetCellDragState {
    [self cleanupCellDragSnapshot];
    self.cellDragInProgress = NO;
    self.cellDragSourceIndexPath = nil;
    self.cellDragSourceConvName = nil;
    self.cellDragSourceChannelId = nil;
    self.cellDragSourceModel = nil;
    self.cellDragSourceSectionId = nil;
    self.cellDragSourceCell = nil;
    self.cellDragLastTargetPath = nil;
    // section header 长按未进入拖拽就被中断时，确保高亮也被还原
    if (self.cellDragHighlightedSectionCell) {
        [self.cellDragHighlightedSectionCell setLongPressHighlighted:NO];
        self.cellDragHighlightedSectionCell = nil;
    }
    // 拖动期间累积的刷新一次性回放
    if (self.pendingRebuildAfterDrag) {
        self.pendingRebuildAfterDrag = NO;
        [self rebuildGroupDisplayAndReload];
    }
}

#pragma mark - 拖动期间 reload 安全包装

/// 拖动期间所有 reloadData / reloadRows 都走这里 — 检查 cellDragInProgress,
/// 是就标记 pending 等结束时统一回放；否则正常 reload。
/// 这样新消息进来 / 通知刷新 / typing 状态变化都不会把源 cell 抢走导致 snapshot 卡死。
- (void)safeReloadTable {
    if (self.cellDragInProgress) { self.pendingRebuildAfterDrag = YES; return; }
    [self.tableView reloadData];
}

- (void)safeReloadRows:(NSArray<NSIndexPath *> *)paths animation:(UITableViewRowAnimation)anim {
    if (self.cellDragInProgress) { self.pendingRebuildAfterDrag = YES; return; }
    [self.tableView reloadRowsAtIndexPaths:paths withRowAnimation:anim];
}

-(void) showConversationMenuForModel:(WKConversationWrapModel *)model atPoint:(CGPoint)point {
    __weak typeof(self) weakSelf = self;
    NSMutableArray<NSDictionary *> *menuItems = [NSMutableArray array];

    BOOL isFollowTab = (_conversationListVM.filterType == WKConversationFilterFollow);

    // 0. 关注 / 取消关注（参考 web PR #27 §4.1/§4.2）
    //    最近 tab：基于 followedKeys 决定显示 "添加到关注" 还是 "取消关注"
    //    关注 tab：默认 isFollowed=YES（这里就是它的产生路径），永远显示 "取消关注"
    WKFollowTargetType targetType = [self followTargetTypeForChannel:model.channel];
    if (targetType > 0) {
        WKFollowedKeysStore *store = [WKFollowedKeysStore shared];
        BOOL isFollowed = isFollowTab
                       || [store isFollowedWithType:targetType targetId:model.channel.channelId];
        if (isFollowed) {
            [menuItems addObject:@{
                @"title": LLang(@"取消关注"),
                @"icon": [WKConversationListVC iconUnfollow],
                @"action": ^{ [weakSelf unfollowConversationModel:model]; }
            }];
        } else {
            [menuItems addObject:@{
                @"title": LLang(@"添加到关注"),
                @"icon": [WKConversationListVC iconFollow],
                @"action": ^{ [weakSelf showAddToFollowDialogForModel:model]; }
            }];
        }
    }

    // 1. 关闭/打开通知
    NSString *muteTitle = model.mute ? LLang(@"打开通知") : LLang(@"关闭通知");
    [menuItems addObject:@{
        @"title": muteTitle,
        @"icon": [WKConversationListVC iconMute:model.mute],
        @"action": ^{
            BOOL newMute = !model.mute;
            [[WKChannelSettingManager shared] channel:model.channel mute:newMute];
            // 最近 tab 用 shadow wrap，服务端 channelInfoUpdate 之前 muteIcon
            // 没法立即反映；这里主动把状态同步到原始 wrap 的 c 上 + 触发 rebuild，
            // 让用户拿到即时反馈（与 web 的 optimistic update 同节奏）。
            [weakSelf applyOptimisticConversationUpdateForChannel:model.channel mute:@(newMute) stick:nil];
        }
    }];

    // 2. 置顶/取消置顶
    //  - 关注 tab 隐藏（spec §0：手工排序替代置顶）
    //  - 子区也隐藏（server thread_setting 无 top 字段，UpdateSetting 忽略未知字段，
    //    点了也不持久化，重启即弹回。详见 octo-server modules/thread/service.go:1010）
    if (!isFollowTab && model.channel.channelType != WK_COMMUNITY_TOPIC) {
        NSString *stickTitle = model.stick ? LLang(@"取消置顶") : LLang(@"置顶");
        [menuItems addObject:@{
            @"title": stickTitle,
            @"icon": [WKConversationListVC iconStick],
            @"action": ^{
                BOOL newStick = !model.stick;
                [[WKChannelSettingManager shared] channel:model.channel stick:newStick];
                [weakSelf applyOptimisticConversationUpdateForChannel:model.channel mute:nil stick:@(newStick)];
                [weakSelf showStickToast:model.channelInfo.displayName ?: model.channel.channelId stuck:newStick];
            }
        }];
    }

    // 3. 移动分组（仅关注 tab 下的群聊；最近 tab 用"添加到关注 → 选分组"二级 sheet）
    if (isFollowTab && model.channel.channelType == WK_GROUP) {
        [menuItems addObject:@{
            @"title": LLang(@"移动分组"),
            @"icon": [WKConversationListVC iconMoveCategory],
            @"action": ^{
                [weakSelf showMoveToCategoryDialog:model.channel.channelId];
            }
        }];
    }

    // 4. 删除
    [menuItems addObject:@{
        @"title": LLang(@"删除"),
        @"icon": [WKConversationListVC iconDelete],
        @"isDestructive": @YES,
        @"action": ^{
            WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:nil];
            [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"清空聊天记录") onClick:^{
                [[WKMessageManager shared] clearMessages:model.channel];
            }]];
            [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"确认删除") onClick:^{
                NSString *botfatherUID = [WKApp shared].config.botfatherUID;
                NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
                if(botfatherUID && [model.channel.channelId isEqualToString:botfatherUID] && currentSpaceId.length > 0) {
                    NSString *hiddenKey = [NSString stringWithFormat:@"WKBotFatherHidden_%@", currentSpaceId];
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:hiddenKey];
                    [[WKMessageManager shared] clearMessages:model.channel];
                }
                [[WKSDK shared].conversationManager deleteConversation:model.channel];
                [weakSelf.conversationListVM loadConversationList:^{
                    [weakSelf rebuildGroupDisplayAndReload];
                }];
            }]];
            [sheet show];
        }
    }];

    [self showFloatingMenu:menuItems atPoint:point];
}

-(void) showThreadMuteMenuForChannelId:(NSString *)threadChannelId threadName:(NSString *)threadName atPoint:(CGPoint)point {
    WKChannel *threadChannel = [WKChannel channelID:threadChannelId channelType:WK_COMMUNITY_TOPIC];
    BOOL isMuted = [[WKChannelSettingManager shared] mute:threadChannel];
    BOOL isFollowed = [[WKFollowedKeysStore shared] isFollowedWithType:WKFollowTargetTypeThread targetId:threadChannelId];

    NSString *muteTitle = isMuted ? LLang(@"打开通知") : LLang(@"关闭通知");
    NSMutableArray<NSDictionary *> *menuItems = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;

    // 取消关注 — 关注 tab 嵌套子区是已关注子区集合，第一项就放它，符合 spec 子区单独取关
    if (isFollowed) {
        [menuItems addObject:@{
            @"title": LLang(@"取消关注"),
            @"icon": [WKConversationListVC iconUnfollow],
            @"action": ^{
                [[WKFollowService shared] unfollowThread:threadChannelId].then(^(id _) {
                    [[WKFollowedKeysStore shared] reload];
                    [weakSelf showUnfollowedToast:threadName];
                    // 关注 tab：reload 完后 onFollowedKeysStoreDidUpdate: 会
                    // rebuildGroupDisplayAndReload，子区行自然消失
                }).catch(^(NSError *err) {
                    [[WKNavigationManager shared].topViewController.view showMsg:err.domain ?: LLang(@"取消关注失败")];
                });
            }
        }];
    }

    [menuItems addObject:@{
        @"title": muteTitle,
        @"icon": [WKConversationListVC iconMute:isMuted],
        @"action": ^{
            BOOL newMute = !isMuted;
            // 依赖服务端 PUT groups/{groupNo}/threads/{shortID}/setting 成功后,
            // 通过 SendChannelUpdate 推送 channel update CMD,客户端拉取最新 channelInfo 并刷新 UI。
            [[WKChannelSettingManager shared] channel:threadChannel mute:newMute];
            // 最近 tab 同样需要即时反馈；子区 wrap 在 threadWrapModels 里。
            [weakSelf applyOptimisticConversationUpdateForChannel:threadChannel mute:@(newMute) stick:nil];
        }
    }];
    [self showFloatingMenu:menuItems atPoint:point];
}

/// 长按菜单点击 mute/stick 后的即时反馈：直接同步本地 wrap.c 状态 + 触发刷新。
/// 关注 / 最近 两 tab 都需要 — 关注 tab 早先 gate 在 Recent，DM 切换通知后没刷新。
/// mute / stick 传 nil 表示该字段不变。
- (void)applyOptimisticConversationUpdateForChannel:(WKChannel *)channel
                                                mute:(nullable NSNumber *)mute
                                               stick:(nullable NSNumber *)stick {
    if (!channel || channel.channelId.length == 0) return;
    WKConversation *conv = nil;
    if (channel.channelType == WK_COMMUNITY_TOPIC) {
        // 子区不在 conversationWrapModels，从 threadWrapModels 找
        for (WKConversationWrapModel *m in self.conversationListVM.threadWrapModels) {
            if ([m.channel isEqual:channel]) { conv = [m getConversation]; break; }
        }
    } else {
        WKConversationWrapModel *orig = [self.conversationListVM modelAtChannel:channel];
        conv = [orig getConversation];
    }
    if (!conv) return;
    if (mute) conv.mute = [mute boolValue];
    if (stick) conv.stick = [stick boolValue];
    // 同时把本地 channelInfo 的 mute/stick 也写过去 — SDK 收到服务端 channelUpdate
    // 后会 fetch channelInfo 并自动同步到 conversation 上。如果本地 channelInfo 还
    // 是旧值（stick=NO），SDK sync 会把刚写好的 stick=YES 反向覆盖回 NO,
    // 造成"置顶 1 秒后弹回"的现象。先把 channelInfo 也置成新值阻断这条路径。
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:channel];
    if (info) {
        if (mute) info.mute = [mute boolValue];
        if (stick) info.stick = [stick boolValue];
        [[WKSDK shared].channelManager addOrUpdateChannelInfoIfNeed:info];
    }
#if DEBUG
    NSLog(@"[StickDebug] optimistic ch=%@ mute=%@ stick=%@ infoCached=%d",
          channel.channelId, mute, stick, info != nil);
#endif
    // 关注 tab 走分组展示，需要 rebuildGroupDisplayAndReload；最近 tab 走
    // filteredConversations。stick 变化两种 tab 都可能改顺序，所以 reloadData。
    if (self.conversationListVM.filterType == WKConversationFilterFollow) {
        [self rebuildGroupDisplayAndReload];
    } else {
        [self.conversationListVM rebuildFilteredList];
        if (stick) {
            // 置顶/取消置顶让该行重新排序；reloadRows 只刷一行不够
            [self.tableView reloadData];
        } else {
            NSInteger idx = [self.conversationListVM indexAtChannel:channel];
            NSInteger rowCount = [self.tableView numberOfRowsInSection:0];
            if (idx >= 0 && idx < rowCount) {
                [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:0]]
                                      withRowAnimation:UITableViewRowAnimationNone];
            }
        }
    }
    // mute optimistic 路径自己刷 badge — 不能依赖 SDK 的 channelInfoUpdate 委托：
    // 本方法已把 channelInfo.mute 写成新值，下面 addOrUpdateChannelInfoIfNeed 进去后
    // SDK 看到 info 未变会 dedupe → 委托不 fire → channelInfoUpdate: 里挂的 refreshBadge
    // 在第二次起都不会执行，表现为「第一次能刷新，后续 toggle 失效」。
    if (mute) {
        [self refreshBadge];
    }
}

#pragma mark - 关注 / 取消关注

/// 把 iOS 的 channelType 映射到 web FollowService 的 target_type。
/// 0 表示该 channelType 不参与 follow（系统通知/文件助手/社区等）。
- (WKFollowTargetType)followTargetTypeForChannel:(WKChannel *)channel {
    if (!channel || channel.channelId.length == 0) return 0;
    switch (channel.channelType) {
        case WK_PERSON: {
            // 系统 bot / 文件助手 不允许加关注
            NSString *cid = channel.channelId;
            NSString *botFather = [WKApp shared].config.botfatherUID;
            NSString *systemUID = [WKApp shared].config.systemUID;
            NSString *fileHelperUID = [WKApp shared].config.fileHelperUID;
            if ((botFather.length > 0 && [cid isEqualToString:botFather])
                || (systemUID.length > 0 && [cid isEqualToString:systemUID])
                || (fileHelperUID.length > 0 && [cid isEqualToString:fileHelperUID])) {
                return 0;
            }
            return WKFollowTargetTypeDM;
        }
        case WK_GROUP: return WKFollowTargetTypeChannel;
        case WK_COMMUNITY_TOPIC: return WKFollowTargetTypeThread;
        default: return 0;
    }
}

/// 取消关注。按 channelType 路由到对应 unfollow* API；成功后 reload sidebar
/// 让 followedKeys / 关注 tab 数据收敛。
- (void)unfollowConversationModel:(WKConversationWrapModel *)model {
    WKFollowService *service = [WKFollowService shared];
    AnyPromise *p = nil;
    switch (model.channel.channelType) {
        case WK_PERSON:           p = [service unfollowDM:model.channel.channelId];           break;
        case WK_GROUP:            p = [service unfollowChannel:model.channel.channelId];      break;
        case WK_COMMUNITY_TOPIC:  p = [service unfollowThread:model.channel.channelId];       break;
        default: return;
    }
    __weak typeof(self) weakSelf = self;
    NSString *name = model.channelInfo.displayName ?: @"";
    p.then(^(id _) {
        [[WKFollowedKeysStore shared] reload].then(^(id __) {
            // 关注 tab 需要把行从分组里抹掉；最近 tab 行还在但 followedKeys 已更新。
            if (weakSelf.conversationListVM.filterType == WKConversationFilterFollow) {
                [weakSelf rebuildGroupDisplayAndReload];
            } else {
                [weakSelf.conversationListVM rebuildFilteredList];
                [weakSelf.tableView reloadData];
            }
            [weakSelf showUnfollowedToast:name];
            return (id)nil;
        });
    }).catch(^(NSError *err) {
        [[WKNavigationManager shared].topViewController.view showMsg:err.domain ?: LLang(@"取消关注失败")];
    });
}

/// "添加到关注" — 对齐 web PR #27 §4.2 的子区特殊规则：
///  - DM / Group: 弹分组选择 sheet（默认目的地记忆 → 下次直奔上次选的）
///  - Thread + 父群已关注: 直接 followThread（后端 cascade）
///  - Thread + 父群未关注: 选分组 → refollow 父群 + moveGroup + followThread 链式
- (void)showAddToFollowDialogForModel:(WKConversationWrapModel *)model {
    if (model.channel.channelType == WK_COMMUNITY_TOPIC) {
        // 子区路径
        NSString *cid = model.channel.channelId;
        NSRange sep = [cid rangeOfString:@"____"];
        if (sep.location == NSNotFound) return;
        NSString *parentGroupNo = [cid substringToIndex:sep.location];
        if (parentGroupNo.length == 0) return;
        BOOL parentFollowed = [[WKFollowedKeysStore shared]
                                isFollowedWithType:WKFollowTargetTypeChannel
                                          targetId:parentGroupNo];
        if (parentFollowed) {
            // 直接 followThread；后端会把父群的关注状态 cascade 透传
            [self performFollowThread:cid parentGroupNo:parentGroupNo categoryId:nil categoryName:nil];
        } else {
            // 父群也未关注，先选分组（用于父群落分组）
            __weak typeof(self) weakSelf = self;
            [self pickFollowCategoryWithTitle:LLang(@"添加到关注") onPick:^(NSString * _Nullable categoryId, NSString * _Nullable categoryName) {
                [weakSelf performFollowThread:cid parentGroupNo:parentGroupNo categoryId:categoryId categoryName:categoryName];
            }];
        }
        return;
    }
    // DM / Group：选分组
    __weak typeof(self) weakSelf = self;
    [self pickFollowCategoryWithTitle:LLang(@"添加到关注") onPick:^(NSString * _Nullable categoryId, NSString * _Nullable categoryName) {
        if (model.channel.channelType == WK_PERSON) {
            [weakSelf performFollowDM:model.channel.channelId categoryId:categoryId categoryName:categoryName];
        } else if (model.channel.channelType == WK_GROUP) {
            [weakSelf performFollowGroup:model.channel.channelId categoryId:categoryId categoryName:categoryName];
        }
    }];
}

#pragma mark - 关注分组选择 sheet

/// 弹自定义底部分组选择 sheet。设计要点：
/// 1) 不用 UIAlertController —— 系统 sheet 与项目其他自定义弹窗（showFloatingMenu）
///    视觉风格不一致；自绘可控背景 / 圆角 / 字体，跟 cellBackgroundColor 联动深色模式。
/// 2) 分组超过 6 行自动滚动（中间表格部分），头部和底部"+ 新建分组"按钮固定。
/// 3) 不再显示 ✓ 历史记忆 —— 用户反馈"添加→取消→再添加"会看到上次的勾选状态，
///    具有误导性。Add-to-follow sheet 的语义是选目的地，不存在"当前归属"。
/// 4) onPick 同时回传 categoryId + categoryName，下游 toast 不再依赖 categoryList 异步刷新。
- (void)pickFollowCategoryWithTitle:(NSString *)title
                             onPick:(void(^)(NSString * _Nullable categoryId, NSString * _Nullable categoryName))onPick {
    NSArray<WKCategoryEntity *> *all = self.conversationListVM.categoryList;
    NSMutableArray<WKCategoryEntity *> *cats = [NSMutableArray array];
    for (WKCategoryEntity *cat in all) {
        if (cat.is_default) continue;
        if (cat.category_id.length == 0) continue;
        [cats addObject:cat];
    }

    // 空：直接走新建（与原逻辑一致）
    if (cats.count == 0) {
        [self showCreateCategoryDialogWithCompletion:^(WKCategoryEntity *cat) {
            if (cat.category_id.length == 0) return;
            if (onPick) onPick(cat.category_id, cat.name);
        }];
        return;
    }

    [self presentFollowCategorySheetWithTitle:title categories:cats selectedCategoryId:nil showCreateRow:YES onPick:onPick];
}

/// 自定义底部 sheet 主体。表格 maxVisibleRows=6，超出滚动。
/// selectedCategoryId 非空时该行前缀 ✓ 表示当前归属（移动分组时用，添加关注时传 nil）。
- (void)presentFollowCategorySheetWithTitle:(NSString *)title
                                  categories:(NSArray<WKCategoryEntity *> *)categories
                          selectedCategoryId:(nullable NSString *)selectedCategoryId
                                showCreateRow:(BOOL)showCreateRow
                                      onPick:(void(^)(NSString * _Nullable categoryId, NSString * _Nullable categoryName))onPick {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;

    // 已有同款 sheet 时直接复用 dismiss 流程，避免叠层
    UIView *existing = [window viewWithTag:77800];
    if (existing) [existing removeFromSuperview];

    UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    overlay.alpha = 0;
    overlay.tag = 77800;
    [window addSubview:overlay];

    // 尺寸常量
    CGFloat headerH = 48;
    CGFloat rowH = 52;
    CGFloat createBtnH = 52;
    CGFloat maxVisibleRows = 6;
    CGFloat tableMaxH = rowH * maxVisibleRows;
    CGFloat tableH = MIN(rowH * categories.count, tableMaxH);
    CGFloat bottomSafe = 0;
    if (@available(iOS 11.0, *)) {
        bottomSafe = window.safeAreaInsets.bottom;
    }
    CGFloat sheetH = headerH + tableH + 0.5 + (showCreateRow ? createBtnH : 0) + bottomSafe;
    CGFloat sheetW = window.lim_width;

    UIView *sheet = [[UIView alloc] initWithFrame:CGRectMake(0, window.lim_height, sheetW, sheetH)];
    sheet.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    // 顶部圆角
    if ([sheet respondsToSelector:@selector(setMaskedCorners:)]) {
        sheet.layer.cornerRadius = 14;
        sheet.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
        sheet.layer.masksToBounds = YES;
    } else {
        sheet.layer.cornerRadius = 14;
        sheet.layer.masksToBounds = YES;
    }
    [overlay addSubview:sheet];

    // 头部
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, sheetW, headerH)];
    header.backgroundColor = [UIColor clearColor];
    [sheet addSubview:header];

    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(50, 0, sheetW - 100, headerH)];
    titleLbl.text = title;
    titleLbl.textAlignment = NSTextAlignmentCenter;
    titleLbl.font = [[WKApp shared].config appFontOfSizeSemibold:16];
    titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    [header addSubview:titleLbl];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(sheetW - 44, 0, 44, headerH);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:18];
    closeBtn.tintColor = [[WKApp shared].config.defaultTextColor colorWithAlphaComponent:0.6];
    [closeBtn setTitleColor:closeBtn.tintColor forState:UIControlStateNormal];
    closeBtn.tag = 77810;
    [closeBtn addTarget:self action:@selector(dismissFollowCategorySheet) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    UIView *headerSep = [[UIView alloc] initWithFrame:CGRectMake(0, headerH - 0.5, sheetW, 0.5)];
    headerSep.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.15];
    [sheet addSubview:headerSep];

    // 中间可滚动的分组列表 — 用 UIScrollView 装 N 个按钮（不复用 UITableView,
    // 因为 VC 本身是会话列表的 dataSource，叠层 dataSource 会 collide）
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, headerH, sheetW, tableH)];
    scroll.backgroundColor = [UIColor clearColor];
    scroll.showsVerticalScrollIndicator = YES;
    scroll.alwaysBounceVertical = (categories.count > maxVisibleRows);
    scroll.contentSize = CGSizeMake(sheetW, rowH * categories.count);
    [sheet addSubview:scroll];

    UIColor *cellTextColor = [WKApp shared].config.defaultTextColor;
    UIColor *sepColor = [[UIColor grayColor] colorWithAlphaComponent:0.15];
    for (NSInteger i = 0; i < (NSInteger)categories.count; i++) {
        WKCategoryEntity *cat = categories[i];
        UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
        row.frame = CGRectMake(0, i * rowH, sheetW, rowH);
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        row.contentEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 20);
        BOOL isSelected = selectedCategoryId.length > 0 && [cat.category_id isEqualToString:selectedCategoryId];
        NSString *displayTitle = isSelected ? [NSString stringWithFormat:@"✓ %@", cat.name ?: @""] : (cat.name ?: @"");
        [row setTitle:displayTitle forState:UIControlStateNormal];
        [row setTitleColor:cellTextColor forState:UIControlStateNormal];
        [row setTitleColor:[cellTextColor colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
        row.titleLabel.font = [[WKApp shared].config appFontOfSize:16];
        row.tag = 78000 + i;
        [row addTarget:self action:@selector(onFollowCategorySheetRowTap:) forControlEvents:UIControlEventTouchUpInside];
        [scroll addSubview:row];

        if (i < (NSInteger)categories.count - 1) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(20, (i + 1) * rowH - 0.5, sheetW - 20, 0.5)];
            sep.backgroundColor = sepColor;
            [scroll addSubview:sep];
        }
    }

    // 表格下方分隔（仅在有底部按钮时画）
    if (showCreateRow) {
        UIView *bottomSep = [[UIView alloc] initWithFrame:CGRectMake(0, headerH + tableH, sheetW, 0.5)];
        bottomSep.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.15];
        [sheet addSubview:bottomSep];

        // 底部"+ 新建分组"按钮固定
        UIButton *createBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        createBtn.frame = CGRectMake(0, headerH + tableH + 0.5, sheetW, createBtnH);
        [createBtn setTitle:LLang(@"+ 新建分组") forState:UIControlStateNormal];
        createBtn.titleLabel.font = [[WKApp shared].config appFontOfSizeMedium:16];
        UIColor *accent = [WKApp shared].config.themeColor ?: [UIColor colorWithRed:138.0/255 green:91.0/255 blue:255.0/255 alpha:1];
        createBtn.tintColor = accent;
        [createBtn setTitleColor:accent forState:UIControlStateNormal];
        createBtn.tag = 77811;
        [createBtn addTarget:self action:@selector(onFollowCategorySheetCreateTap) forControlEvents:UIControlEventTouchUpInside];
        [sheet addSubview:createBtn];
    }

    // 关联回调 + 数据源
    objc_setAssociatedObject(overlay, "sheetOnPick", [onPick copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(overlay, "sheetCategories", categories, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 点 overlay 关闭
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissFollowCategorySheet)];
    [overlay addGestureRecognizer:tap];
    // 点 sheet 内部不要冒泡触发 dismiss
    UITapGestureRecognizer *eat = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(noop)];
    [sheet addGestureRecognizer:eat];

    // 弹出动画
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        overlay.alpha = 1;
        sheet.frame = CGRectMake(0, window.lim_height - sheetH, sheetW, sheetH);
    } completion:nil];
}

- (void)noop {}

- (void)dismissFollowCategorySheet {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIView *overlay = [window viewWithTag:77800];
    if (!overlay) return;
    UIView *sheet = nil;
    for (UIView *sub in overlay.subviews) {
        if ([sub isKindOfClass:[UIView class]]) { sheet = sub; break; }
    }
    CGRect end = sheet.frame; end.origin.y = window.lim_height;
    [UIView animateWithDuration:0.2 animations:^{
        overlay.alpha = 0;
        if (sheet) sheet.frame = end;
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
}

- (void)onFollowCategorySheetCreateTap {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIView *overlay = [window viewWithTag:77800];
    if (!overlay) return;
    void(^onPick)(NSString *, NSString *) = objc_getAssociatedObject(overlay, "sheetOnPick");
    [self dismissFollowCategorySheet];
    __weak typeof(self) weakSelf = self;
    [self showCreateCategoryDialogWithCompletion:^(WKCategoryEntity *cat) {
        if (cat.category_id.length == 0) return;
        // 把新建分组同步追加到 VM.categoryList，避免 loadCategories 异步未完成
        // 时下游 categoryNameById: 查不到导致 toast 缺失。
        NSMutableArray *m = [weakSelf.conversationListVM.categoryList mutableCopy] ?: [NSMutableArray array];
        BOOL exists = NO;
        for (WKCategoryEntity *c in m) {
            if ([c.category_id isEqualToString:cat.category_id]) { exists = YES; break; }
        }
        if (!exists) [m addObject:cat];
        weakSelf.conversationListVM.categoryList = m;
        if (onPick) onPick(cat.category_id, cat.name);
    }];
}

- (void)onFollowCategorySheetRowTap:(UIButton *)btn {
    NSInteger idx = btn.tag - 78000;
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIView *overlay = [window viewWithTag:77800];
    if (!overlay) return;
    NSArray<WKCategoryEntity *> *categories = objc_getAssociatedObject(overlay, "sheetCategories");
    void(^onPick)(NSString *, NSString *) = objc_getAssociatedObject(overlay, "sheetOnPick");
    [self dismissFollowCategorySheet];
    if (idx < 0 || idx >= (NSInteger)categories.count) return;
    WKCategoryEntity *cat = categories[idx];
    if (onPick) onPick(cat.category_id, cat.name);
}

#pragma mark - 关注实际写操作

/// 通过 categoryId 反查分组名（找不到时回退 ""）
- (NSString *)categoryNameById:(NSString *)categoryId {
    if (categoryId.length == 0) return @"";
    for (WKCategoryEntity *cat in self.conversationListVM.categoryList) {
        if ([cat.category_id isEqualToString:categoryId]) return cat.name ?: @"";
    }
    return @"";
}

/// 「<会话名> 已添加到 <分组名> 分组」会话名白 bold，分组名主题紫 bold，
/// 形成对比 — 会话名是"主语"用白色稳重，分组名是"目标"用强调色突出。
- (void)showFollowedToast:(NSString *)conversationName toCategory:(NSString *)categoryName {
    [self showFollowOrMoveToast:conversationName verb:LLang(@" 已添加到 ") toCategory:categoryName];
}

/// 「<会话名> 已移动到 <分组名> 分组」拖拽跨分组完成时用，比"已添加到"更准确
- (void)showMovedToast:(NSString *)conversationName toCategory:(NSString *)categoryName {
    [self showFollowOrMoveToast:conversationName verb:LLang(@" 已移动到 ") toCategory:categoryName];
}

- (void)showFollowOrMoveToast:(NSString *)conversationName verb:(NSString *)verb toCategory:(NSString *)categoryName {
    if (categoryName.length == 0) return;
    if (conversationName.length == 0) conversationName = LLang(@"该会话");
    UIColor *accent = [WKApp shared].config.themeColor ?: [UIColor colorWithRed:138.0/255 green:91.0/255 blue:255.0/255 alpha:1];
    NSAttributedString *attr = [self attrTextWithSegments:@[
        @{ @"text": conversationName,             @"color": [UIColor whiteColor], @"bold": @YES },
        @{ @"text": verb,                          @"color": [UIColor whiteColor], @"bold": @NO  },
        @{ @"text": categoryName,                 @"color": accent,               @"bold": @YES },
        @{ @"text": LLang(@" 分组"),                @"color": [UIColor whiteColor], @"bold": @NO  },
    ]];
    [self showAttributedToast:attr];
}

/// 「<会话名> 已取消关注」会话名主题紫 bold
- (void)showUnfollowedToast:(NSString *)conversationName {
    if (conversationName.length == 0) conversationName = LLang(@"该会话");
    UIColor *accent = [WKApp shared].config.themeColor ?: [UIColor colorWithRed:138.0/255 green:91.0/255 blue:255.0/255 alpha:1];
    NSAttributedString *attr = [self attrTextWithSegments:@[
        @{ @"text": conversationName,           @"color": accent,                @"bold": @YES },
        @{ @"text": LLang(@" 已取消关注"),        @"color": [UIColor whiteColor],  @"bold": @NO  },
    ]];
    [self showAttributedToast:attr];
}

/// 「<会话名> 已置顶」/「<会话名> 已取消置顶」会话名主题紫 bold
- (void)showStickToast:(NSString *)conversationName stuck:(BOOL)stuck {
    if (conversationName.length == 0) conversationName = LLang(@"该会话");
    UIColor *accent = [WKApp shared].config.themeColor ?: [UIColor colorWithRed:138.0/255 green:91.0/255 blue:255.0/255 alpha:1];
    NSString *verb = stuck ? LLang(@" 已置顶") : LLang(@" 已取消置顶");
    NSAttributedString *attr = [self attrTextWithSegments:@[
        @{ @"text": conversationName,           @"color": accent,                @"bold": @YES },
        @{ @"text": verb,                        @"color": [UIColor whiteColor],  @"bold": @NO  },
    ]];
    [self showAttributedToast:attr];
}

/// 通用 attr 拼接：[{text, color, bold}, ...]
- (NSAttributedString *)attrTextWithSegments:(NSArray<NSDictionary *> *)segments {
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] init];
    for (NSDictionary *seg in segments) {
        NSString *t = seg[@"text"];
        if (t.length == 0) continue;
        UIColor *c = seg[@"color"] ?: [UIColor whiteColor];
        BOOL bold = [seg[@"bold"] boolValue];
        UIFont *f = bold ? [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold]
                         : [UIFont systemFontOfSize:14];
        [s appendAttributedString:[[NSAttributedString alloc] initWithString:t attributes:@{NSFontAttributeName: f, NSForegroundColorAttributeName: c}]];
    }
    return s;
}

/// 自定义 toast view（CSToast 默认只接受 NSString，要用 attributedText 必须自己拼一个 UIView 走
/// showToast:duration:position:completion:）。深色半透明背景 + 圆角，与系统 toast 视觉一致。
- (void)showAttributedToast:(NSAttributedString *)attrText {
    if (attrText.length == 0) return;
    UILabel *lbl = [[UILabel alloc] init];
    lbl.attributedText = attrText;
    lbl.numberOfLines = 0;
    lbl.textAlignment = NSTextAlignmentCenter;
    UIView *bg = [[UIView alloc] init];
    bg.backgroundColor = [UIColor colorWithWhite:0 alpha:0.78];
    bg.layer.cornerRadius = 10;
    bg.layer.masksToBounds = YES;
    [bg addSubview:lbl];
    CGFloat maxLblWidth = MAX(160, self.view.bounds.size.width - 80 - 32);
    CGSize size = [lbl sizeThatFits:CGSizeMake(maxLblWidth, CGFLOAT_MAX)];
    CGFloat w = MIN(maxLblWidth, ceil(size.width)) + 32;
    CGFloat h = ceil(size.height) + 20;
    bg.frame = CGRectMake(0, 0, w, h);
    lbl.frame = CGRectMake(16, 10, w - 32, h - 20);
    [self.view showToast:bg duration:1.6 position:CSToastPositionCenter completion:nil];
}

- (void)performFollowDM:(NSString *)peerUid categoryId:(NSString *)categoryId categoryName:(nullable NSString *)categoryName {
    __weak typeof(self) weakSelf = self;
    NSString *catName = categoryName.length > 0 ? categoryName : [self categoryNameById:categoryId];
    NSString *convName = [self displayNameForChannel:[WKChannel personWithChannelID:peerUid]];
    [[WKFollowService shared] followDM:peerUid categoryId:categoryId].then(^(id _) {
        [[WKFollowedKeysStore shared] reload];
        [weakSelf.tableView reloadData];
        [weakSelf showFollowedToast:convName toCategory:catName];
    }).catch(^(NSError *err) {
        [[WKNavigationManager shared].topViewController.view showMsg:err.domain ?: LLang(@"添加到关注失败")];
    });
}

- (void)performFollowGroup:(NSString *)groupNo categoryId:(NSString *)categoryId categoryName:(nullable NSString *)categoryName {
    __weak typeof(self) weakSelf = self;
    NSString *catName = categoryName.length > 0 ? categoryName : [self categoryNameById:categoryId];
    NSString *convName = [self displayNameForChannel:[WKChannel groupWithChannelID:groupNo]];
    // 只关注群本身。P3-1.4 的"加群即加全部子区"按用户要求撤回 —— 子区需要单独
    // 长按走 thread 关注流程（避免一次性把不感兴趣的子区全塞进关注 tab）。
    [[WKFollowService shared] refollowChannel:groupNo].then(^(id _) {
        return [[WKCategoryService shared] moveGroup:groupNo toCategoryId:categoryId];
    }).then(^(id _) {
        [[WKFollowedKeysStore shared] reload];
        [weakSelf loadCategories];
        [weakSelf showFollowedToast:convName toCategory:catName];
    }).catch(^(NSError *err) {
        [[WKNavigationManager shared].topViewController.view showMsg:err.domain ?: LLang(@"添加到关注失败")];
    });
}

- (void)performFollowThread:(NSString *)threadChannelId
              parentGroupNo:(NSString *)parentGroupNo
                 categoryId:(nullable NSString *)categoryId
               categoryName:(nullable NSString *)categoryName {
    __weak typeof(self) weakSelf = self;
    NSString *catName = categoryName.length > 0 ? categoryName : [self categoryNameById:categoryId];
    NSString *convName = [self displayNameForChannel:[WKChannel channelID:threadChannelId channelType:WK_COMMUNITY_TOPIC]];
    AnyPromise *chain;
    if (categoryId.length > 0) {
        // 父群也未关注：先 refollow 父群 → moveGroup 到选定分组 → followThread
        chain = [[WKFollowService shared] refollowChannel:parentGroupNo].then(^id(id _) {
            return [[WKCategoryService shared] moveGroup:parentGroupNo toCategoryId:categoryId];
        }).then(^id(id _) {
            return [[WKFollowService shared] followThread:threadChannelId];
        });
    } else {
        // 父群已关注：直接 followThread，后端 cascade
        chain = [[WKFollowService shared] followThread:threadChannelId];
    }
    chain.then(^(id _) {
        [[WKFollowedKeysStore shared] reload];
        [weakSelf loadCategories];
        if (catName.length > 0) {
            [weakSelf showFollowedToast:convName toCategory:catName];
        } else {
            // 父群已关注的子区是 cascade 路径，没选分组；用父群当前所在分组名提示
            for (WKCategoryEntity *cat in weakSelf.conversationListVM.categoryList) {
                for (WKCategoryGroup *cg in cat.groups) {
                    if ([cg.group_no isEqualToString:parentGroupNo]) {
                        [weakSelf showFollowedToast:convName toCategory:cat.name];
                        return;
                    }
                }
            }
        }
    }).catch(^(NSError *err) {
        [[WKNavigationManager shared].topViewController.view showMsg:err.domain ?: LLang(@"添加到关注失败")];
    });
}

/// 兜底取 channel 的 displayName（cache hit / wrap hit / fallback channelId）
- (NSString *)displayNameForChannel:(WKChannel *)channel {
    if (!channel || channel.channelId.length == 0) return @"";
    WKConversationWrapModel *wrap = [self.conversationListVM modelAtChannel:channel];
    NSString *name = wrap.channelInfo.displayName;
    if (name.length > 0) return name;
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:channel];
    name = info.displayName;
    if (name.length > 0) return name;
    return channel.channelId;
}

#pragma mark - 会话菜单图标

+ (UIImage *)iconMute:(BOOL)isMuted {
    CGSize s = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor colorWithWhite:0.3 alpha:1] setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    // 喇叭
    CGContextMoveToPoint(ctx, 4, 8);
    CGContextAddLineToPoint(ctx, 7, 8);
    CGContextAddLineToPoint(ctx, 11, 5);
    CGContextAddLineToPoint(ctx, 11, 15);
    CGContextAddLineToPoint(ctx, 7, 12);
    CGContextAddLineToPoint(ctx, 4, 12);
    CGContextClosePath(ctx);
    CGContextStrokePath(ctx);
    if (isMuted) {
        // 斜线（已静音 → 显示取消静音图标）
        CGContextMoveToPoint(ctx, 14, 7);
        CGContextAddLineToPoint(ctx, 17, 13);
        CGContextStrokePath(ctx);
    } else {
        // 声波（未静音 → 显示关闭通知图标）
        CGContextAddArc(ctx, 11, 10, 4, -M_PI/4, M_PI/4, 0);
        CGContextStrokePath(ctx);
        CGContextAddArc(ctx, 11, 10, 7, -M_PI/4, M_PI/4, 0);
        CGContextStrokePath(ctx);
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)iconStick {
    CGSize s = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor colorWithWhite:0.3 alpha:1] setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    // 图钉
    CGContextMoveToPoint(ctx, 7, 3);
    CGContextAddLineToPoint(ctx, 13, 3);
    CGContextAddLineToPoint(ctx, 12, 10);
    CGContextAddLineToPoint(ctx, 15, 10);
    CGContextMoveToPoint(ctx, 5, 10);
    CGContextAddLineToPoint(ctx, 15, 10);
    CGContextMoveToPoint(ctx, 8, 10);
    CGContextAddLineToPoint(ctx, 7, 3);
    CGContextMoveToPoint(ctx, 10, 10);
    CGContextAddLineToPoint(ctx, 10, 17);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)iconFollow {
    return [WKFloatingMenu iconFollow];
}

+ (UIImage *)iconUnfollow {
    return [WKFloatingMenu iconUnfollow];
}

+ (UIImage *)iconMoveCategory {
    CGSize s = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor colorWithWhite:0.3 alpha:1] setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    // 文件夹
    CGContextMoveToPoint(ctx, 3, 7);
    CGContextAddLineToPoint(ctx, 3, 5);
    CGContextAddLineToPoint(ctx, 8, 5);
    CGContextAddLineToPoint(ctx, 9, 7);
    CGContextAddLineToPoint(ctx, 17, 7);
    CGContextAddLineToPoint(ctx, 17, 16);
    CGContextAddLineToPoint(ctx, 3, 16);
    CGContextAddLineToPoint(ctx, 3, 7);
    CGContextStrokePath(ctx);
    // 箭头
    CGContextMoveToPoint(ctx, 10, 9);
    CGContextAddLineToPoint(ctx, 10, 14);
    CGContextMoveToPoint(ctx, 8, 12);
    CGContextAddLineToPoint(ctx, 10, 14);
    CGContextAddLineToPoint(ctx, 12, 12);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}


-(void) setChatPwdErrorCount:(NSInteger)count channel:(WKChannel*)channel{
    [[NSUserDefaults standardUserDefaults] setInteger:count forKey:[self chatPwdErrorKey:channel]];
}

-(NSInteger) getChatPwdErrorCount:(WKChannel*)channel {
    return [[NSUserDefaults standardUserDefaults] integerForKey:[self chatPwdErrorKey:channel]];
}
-(NSString*) chatPwdErrorKey:(WKChannel*)channel {
    return [NSString stringWithFormat:@"chatpwderror_%@_%@_%hhu",[WKApp shared].loginInfo.uid,channel.channelId,channel.channelType];
}

-(void) toConversation:(WKConversationWrapModel*)conversationModel {
    // 显示聊天UI
    [WKApp.shared pushConversation:conversationModel.channel];
}


//- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
//    NSLog(@"commitEditingStyle--");
//    [self.conversationListVM removeConversationAtIndex:indexPath.row];
//    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationTop];
//}
//- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
//    return @"删除";
//}
//
//- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
//    __weak typeof(self) weakSelf = self;
//    UITableViewRowAction *action = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:LLang(@"删除") handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
//        WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:nil];
//        [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"清空聊天记录") onClick:^{
//            WKConversationWrapModel *conversationModel = [self.conversationListVM conversationAtIndex:indexPath.row];
//            [[WKMessageManager shared] clearMessages:conversationModel.channel];
//        }]];
//        [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"确认删除") onClick:^{
//            WKConversationWrapModel *conversationModel = [self.conversationListVM conversationAtIndex:indexPath.row];
//            [weakSelf.conversationListVM removeConversationAtIndex:indexPath.row];
//            [weakSelf.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
//            if(conversationModel) {
//                [[WKSDK shared].conversationManager deleteConversation:conversationModel.channel];
//            }
//        }]];
//        [sheet show];
//    }];
//    WKConversationWrapModel *conversationModel = [self.conversationListVM conversationAtIndex:indexPath.row];
//    UITableViewRowAction *action1 = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title: conversationModel.unreadCount>0?LLang(@"标为已读"):LLang(@"标为未读") handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
//            // 退出编辑模式
////        [self.tableView setEditing:NO animated:YES];
//        int unreadCount = conversationModel.unreadCount>0?0:1;
//        conversationModel.unreadCount = unreadCount;
//        [[WKConversationDB shared] setConversationUnreadCount:conversationModel.channel unread:unreadCount];
//        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section]] withRowAnimation:UITableViewRowAnimationRight];
//
//    }];
//
//    return @[action,action1];
//}

-(void) refreshTableNoSort {
    [self refreshHeader];
    [self rebuildGroupDisplayAndReload];
}

-(void) refreshTable {
    [self.conversationListVM sortConversationList];
    [self refreshHeader];
    [self rebuildGroupDisplayAndReload];
}

-(void) refreshHeader {
    [self resetHeaderBottomEmptyBackgroundColor];
    [self.tableHeader layoutSubviews];
}

-(void) resetHeaderBottomEmptyBackgroundColor {
    if([self.conversationListVM hasConversationTop]) {
        [self.tableHeader.tableHeaderBottomEmptyView setBackgroundColor:[WKApp shared].config.backgroundColor];
    }else{
        [self.tableHeader.tableHeaderBottomEmptyView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    }
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}

#pragma mark - 网络信号监控

- (UIImage *)createChevronDownImage {
    CGSize size = CGSizeMake(14, 14);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    UIColor *color = [UIColor colorWithWhite:0.5 alpha:1.0];
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, 1.8);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGContextMoveToPoint(ctx, 2.5, 5);
    CGContextAddLineToPoint(ctx, 7, 9.5);
    CGContextAddLineToPoint(ctx, 11.5, 5);
    CGContextStrokePath(ctx);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIImage *)createChatBubblesImage {
    CGSize size = CGSizeMake(24, 24);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor blackColor] setStroke];
    CGContextSetLineWidth(ctx, 1.6);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    UIBezierPath *backBubble = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(8, 2, 14, 11) cornerRadius:3];
    CGContextAddPath(ctx, backBubble.CGPath);
    CGContextStrokePath(ctx);

    UIBezierPath *frontBubble = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2, 8, 14, 11) cornerRadius:3];
    CGContextAddPath(ctx, frontBubble.CGPath);
    CGContextStrokePath(ctx);

    CGContextMoveToPoint(ctx, 4, 19);
    CGContextAddLineToPoint(ctx, 2, 22);
    CGContextAddLineToPoint(ctx, 7, 19);
    CGContextStrokePath(ctx);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (UIImage *)createPlusImage {
    CGSize size = CGSizeMake(24, 24);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor blackColor] setStroke];
    CGContextSetLineWidth(ctx, 2.0);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextMoveToPoint(ctx, 5, 12);
    CGContextAddLineToPoint(ctx, 19, 12);
    CGContextMoveToPoint(ctx, 12, 5);
    CGContextAddLineToPoint(ctx, 12, 19);
    CGContextStrokePath(ctx);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

// SVG monitor icon + green online dot (matches prototype)
- (UIImage *)createMonitorOnlineImage {
    CGFloat sz = 20.0f;
    CGFloat s = sz / 24.0f;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(sz, sz), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    UIColor *strokeColor = [UIColor colorWithRed:20/255.0f green:20/255.0f blue:30/255.0f alpha:0.60f];
    if (@available(iOS 13.0, *)) {
        if (UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark || WKApp.shared.config.style == WKSystemStyleDark) {
            strokeColor = [UIColor colorWithRed:242/255.0f green:243/255.0f blue:245/255.0f alpha:0.62f];
        }
    }
    CGContextSetStrokeColorWithColor(ctx, strokeColor.CGColor);
    CGContextSetLineWidth(ctx, 1.8f * s);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    UIBezierPath *rect = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2*s, 3*s, 20*s, 14*s) cornerRadius:2*s];
    [rect stroke];

    CGContextMoveToPoint(ctx, 12*s, 17*s);
    CGContextAddLineToPoint(ctx, 12*s, 21*s);
    CGContextStrokePath(ctx);

    CGContextMoveToPoint(ctx, 8*s, 21*s);
    CGContextAddLineToPoint(ctx, 16*s, 21*s);
    CGContextStrokePath(ctx);

    CGFloat dotR = 3.0f;
    CGFloat dotX = sz - dotR - 0.5f;
    CGFloat dotY = 3*s - 0.5f;
    UIBezierPath *dot = [UIBezierPath bezierPathWithArcCenter:CGPointMake(dotX, dotY) radius:dotR startAngle:0 endAngle:M_PI*2 clockwise:YES];
    [[UIColor colorWithRed:11/255.0f green:135/255.0f blue:125/255.0f alpha:1.0f] setFill];
    [dot fill];
    [[UIColor whiteColor] setStroke];
    CGContextSetLineWidth(ctx, 1.5f);
    [dot stroke];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (UIImage *)createSignalBarsImage {
    CGSize size = CGSizeMake(16, 14);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();

    // 设置信号条颜色（默认灰色）
    [[UIColor colorWithRed:103/255.0 green:106/255.0 blue:111/255.0 alpha:1.0] setFill];

    // 绘制4个信号条
    // 第1条（最低）
    CGContextFillRect(context, CGRectMake(0, 11, 3, 3));
    // 第2条
    CGContextFillRect(context, CGRectMake(4.5, 7.5, 3, 6.5));
    // 第3条
    CGContextFillRect(context, CGRectMake(9, 4, 3, 10));
    // 第4条（最高）
    CGContextFillRect(context, CGRectMake(13.5, 0, 2.5, 14));

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

// 开始 ping 监控
- (void)startPingMonitoring {
    [self stopPingMonitoring];

    // 立即执行第一次 ping
    [self performPing];

    // 每30秒执行一次
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(performPing) userInfo:nil repeats:YES];
}

// 停止 ping 监控
- (void)stopPingMonitoring {
    if (self.pingTimer) {
        [self.pingTimer invalidate];
        self.pingTimer = nil;
    }

    // 参考 Web 端：只停止定时器，不隐藏信号显示
    // 信号显示应该始终可见，通过 updateSignalViewForStatus 方法控制显示内容
}

// 执行 ping 操作
- (void)performPing {
    NSString *apiBaseUrl = [WKApp shared].config.apiBaseUrl;
    if (!apiBaseUrl || apiBaseUrl.length == 0) {
        // 没有 API URL，使用默认延迟值
        self.currentLatencyMs = 50;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateSignalView];
        });
        return;
    }

    // 从 apiBaseUrl 提取服务器根路径（去掉 /api/v1/ 部分）
    // 例如：https://im.your.server.example.com/api/v1/ -> https://im.your.server.example.com/
    NSURL *apiURL = [NSURL URLWithString:apiBaseUrl];
    NSString *baseURL = [NSString stringWithFormat:@"%@://%@/", apiURL.scheme, apiURL.host];

    NSURL *url = [NSURL URLWithString:baseURL];
    if (!url) {
        // URL 无效，使用默认延迟值
        self.currentLatencyMs = 50;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateSignalView];
        });
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"HEAD";
    request.timeoutInterval = 5.0;

    NSDate *startTime = [NSDate date];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error) {
            NSTimeInterval latency = [[NSDate date] timeIntervalSinceDate:startTime] * 1000; // 转换为毫秒
            weakSelf.currentLatencyMs = (NSInteger)latency;
        } else {
            // ping 失败，使用较高的延迟值表示网络不佳
            weakSelf.currentLatencyMs = 500;
            NSLog(@"Ping 失败: %@", error.localizedDescription);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf updateSignalView];
        });
    }];
    [task resume];
}

// 调度下一次 ping
- (void)scheduleNextPing {
    // ping 定时器已经在运行，无需额外调度
}

// 根据连接状态更新信号显示（参考 Web 端 ConnectionStatus 组件）
- (void)updateSignalViewForStatus:(WKConnectStatus)status {
    if (!self.signalContainerView) {
        return;
    }

    UIColor *color;
    NSString *statusText;

    switch (status) {
        case WKConnecting:
            // 黄色：连接中
            color = [UIColor colorWithRed:234/255.0 green:179/255.0 blue:8/255.0 alpha:1.0];
            statusText = LLang(@"连接中...");
            break;

        case WKConnected:
            // 已连接：使用延迟数据更新（如果有的话）
            if (self.currentLatencyMs > 0) {
                [self updateSignalView]; // 使用现有的延迟更新逻辑
                return;
            }
            // 刚连接还没有延迟数据时显示绿色
            color = [UIColor colorWithRed:34/255.0 green:197/255.0 blue:94/255.0 alpha:1.0];
            statusText = @"--ms";
            break;

        case WKDisconnected:
        case WKPullingOffline:
            // 红色：已断开
            color = [UIColor colorWithRed:239/255.0 green:68/255.0 blue:68/255.0 alpha:1.0];
            statusText = LLang(@"已断开");
            break;

        default:
            return;
    }

    // 更新图标和文字颜色
    self.signalImageView.image = [self.signalImageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.signalImageView.tintColor = color;
    self.latencyLabel.textColor = color;
    self.latencyLabel.text = statusText;

    // 确保显示
    self.signalContainerView.hidden = NO;
}

// 更新信号显示
- (void)updateSignalView {
    if (!self.signalContainerView) {
        return;
    }

    // 显示信号容器
    self.signalContainerView.hidden = NO;

    // 更新延迟文本
    self.latencyLabel.text = [NSString stringWithFormat:@"%ldms", (long)self.currentLatencyMs];

    // 根据延迟设置颜色
    UIColor *color;
    if (self.currentLatencyMs < 100) {
        // 绿色：网速好
        color = [UIColor colorWithRed:76/255.0 green:175/255.0 blue:80/255.0 alpha:1.0];
    } else if (self.currentLatencyMs < 300) {
        // 橙色：一般
        color = [UIColor colorWithRed:255/255.0 green:152/255.0 blue:0/255.0 alpha:1.0];
    } else {
        // 红色：较差
        color = [UIColor colorWithRed:244/255.0 green:67/255.0 blue:54/255.0 alpha:1.0];
    }

    // 更新图标颜色
    self.signalImageView.image = [self.signalImageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.signalImageView.tintColor = color;

    // 更新文字颜色
    self.latencyLabel.textColor = color;
}

// 点击信号显示区域
- (void)signalTapped {
    // 计算已连接时长
    NSTimeInterval connectedDuration = [[NSDate date] timeIntervalSinceDate:[NSDate dateWithTimeIntervalSince1970:self.connectedAtTime]];
    NSInteger seconds = (NSInteger)connectedDuration;
    NSString *durationText;
    if (seconds < 60) {
        durationText = [NSString stringWithFormat:LLang(@"已连接: %ld秒"), (long)seconds];
    } else {
        durationText = [NSString stringWithFormat:LLang(@"已连接: %ld分钟"), (long)(seconds / 60)];
    }

    // 创建详情视图
    UIView *tooltipView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 90)];
    tooltipView.backgroundColor = [UIColor colorWithRed:60/255.0 green:60/255.0 blue:60/255.0 alpha:0.95];
    tooltipView.layer.cornerRadius = 8;

    // 状态标签
    UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, 180, 20)];
    statusLabel.text = LLang(@"状态: 已连接");
    statusLabel.textColor = [UIColor whiteColor];
    statusLabel.font = [UIFont systemFontOfSize:13];
    [tooltipView addSubview:statusLabel];

    // 延迟标签
    UILabel *latencyInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 34, 180, 20)];
    latencyInfoLabel.text = [NSString stringWithFormat:LLang(@"延迟: %ldms"), (long)self.currentLatencyMs];
    latencyInfoLabel.textColor = [UIColor whiteColor];
    latencyInfoLabel.font = [UIFont systemFontOfSize:13];
    [tooltipView addSubview:latencyInfoLabel];

    // 时长标签
    UILabel *durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 58, 180, 20)];
    durationLabel.text = durationText;
    durationLabel.textColor = [UIColor whiteColor];
    durationLabel.font = [UIFont systemFontOfSize:13];
    [tooltipView addSubview:durationLabel];

    // 显示弹窗
    [self showTooltip:tooltipView atView:self.signalContainerView];
}

// 显示提示弹窗
- (void)showTooltip:(UIView *)tooltipView atView:(UIView *)sourceView {
    // 添加到主窗口
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) {
        window = [[UIApplication sharedApplication].windows firstObject];
    }

    [window addSubview:tooltipView];

    // 计算位置（在源视图下方）
    CGRect sourceFrame = [sourceView convertRect:sourceView.bounds toView:window];
    CGFloat x = sourceFrame.origin.x + sourceFrame.size.width / 2 - tooltipView.frame.size.width / 2;
    CGFloat y = sourceFrame.origin.y + sourceFrame.size.height + 4;

    // 确保不超出屏幕
    if (x < 10) x = 10;
    if (x + tooltipView.frame.size.width > window.frame.size.width - 10) {
        x = window.frame.size.width - tooltipView.frame.size.width - 10;
    }

    tooltipView.frame = CGRectMake(x, y, tooltipView.frame.size.width, tooltipView.frame.size.height);

    // 添加点击关闭手势
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissTooltip:)];
    [tooltipView addGestureRecognizer:tapGesture];

    // 添加透明度动画
    tooltipView.alpha = 0;
    [UIView animateWithDuration:0.2 animations:^{
        tooltipView.alpha = 1;
    }];

    // 3秒后自动消失
    [self performSelector:@selector(dismissTooltip:) withObject:tooltipView afterDelay:3.0];
}

// 关闭提示弹窗
- (void)dismissTooltip:(id)sender {
    UIView *tooltipView = sender;
    if ([tooltipView isKindOfClass:[UITapGestureRecognizer class]]) {
        tooltipView = [(UITapGestureRecognizer *)sender view];
    }

    [UIView animateWithDuration:0.2 animations:^{
        tooltipView.alpha = 0;
    } completion:^(BOOL finished) {
        [tooltipView removeFromSuperview];
    }];
}

#pragma mark - Category (分组)

-(void) loadCategories {
    __weak typeof(self) weakSelf = self;
    [_conversationListVM loadCategoriesWithCompletion:^{
        [weakSelf rebuildGroupDisplayAndReload];
    }];
}

-(void) rebuildGroupDisplayAndReload {
    // 拖动期间冻结表格刷新 — 否则源 cell 可能被回收，长按手势随之销毁，
    // Ended/Cancelled 永不触发，snapshot 就卡在屏上。结束拖动时统一回放一次。
    if (self.cellDragInProgress) {
        self.pendingRebuildAfterDrag = YES;
        return;
    }
    CFAbsoluteTime _t0 = CFAbsoluteTimeGetCurrent();
    self.groupDisplayList = [_conversationListVM buildGroupDisplayList];
    CFAbsoluteTime _t1 = CFAbsoluteTimeGetCurrent();
    [self.tableView reloadData];
    CFAbsoluteTime _t2 = CFAbsoluteTimeGetCurrent();
    [self updateGroupMentionBadge];
    [self refreshFollowEmptyVisibility];
    CFAbsoluteTime _t3 = CFAbsoluteTimeGetCurrent();
    NSLog(@"[TabPerf] rebuildGroupDisplayAndReload: buildList=%.1fms reloadData=%.1fms mentionBadge=%.1fms total=%.1fms rows=%lu",
          (_t1-_t0)*1000, (_t2-_t1)*1000, (_t3-_t2)*1000, (_t3-_t0)*1000,
          (unsigned long)self.groupDisplayList.count);
}

/// 检查群聊和子区中是否有未处理的@提醒，分别更新关注/最近 tab 上的 [有人@我] 标识。
/// 直接使用 buildGroupDisplayList 中已计算好的结果，避免重复遍历和 DB 查询。
-(void) updateGroupMentionBadge {
    [_conversationTabView setFollowHasMention:_conversationListVM.lastBuildFollowHasMention];
    [_conversationTabView setRecentHasMention:_conversationListVM.lastBuildRecentHasMention];
}

-(void) showCreateCategoryDialog {
    [self showCreateCategoryDialogWithCompletion:nil];
}

/// 创建分组，完成后回调新建的 WKCategoryEntity。如 completion 为 nil，只创建不联动。
/// 用于"添加到关注/移动到分组 → 新建分组"流程：用户期望新建后会话自动落入新分组，
/// 不联动会很割裂。
-(void) showCreateCategoryDialogWithCompletion:(void(^)(WKCategoryEntity *category))completion {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(!spaceId || spaceId.length == 0) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"创建分组") message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = LLang(@"请输入分组名称");
    }];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"创建") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        if(!name || name.length == 0) return;
        [[WKCategoryService shared] createCategory:spaceId name:name].then(^(WKCategoryEntity *cat) {
            [weakSelf loadCategories];
            if (completion) completion(cat);
        }).catch(^(NSError *error) {
            NSLog(@"创建分组失败: %@", error);
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void) showMoveToCategoryDialog:(NSString *)groupNo {
    // 先刷一次 categoryList，避免显示过期分组（用户在 web/另一设备建/删的分类）
    __weak typeof(self) weakSelf = self;
    [_conversationListVM loadCategoriesWithCompletion:^{
        [weakSelf presentMoveToCategorySheet:groupNo];
    }];
}

-(void) presentMoveToCategorySheet:(NSString *)groupNo {
    NSArray<WKCategoryEntity *> *all = _conversationListVM.categoryList;

    // 获取群组名称
    WKChannelInfo *groupInfo = [[WKSDK shared].channelManager getChannelInfo:[WKChannel groupWithChannelID:groupNo]];
    NSString *groupName = groupInfo ? groupInfo.displayName : groupNo;
    NSString *titleText = [NSString stringWithFormat:@"%@ \"%@\"", LLang(@"移动"), groupName];

    // 找到当前群所在分组（用于 ✓ 标记）
    NSString *currentCategoryId = nil;
    NSMutableArray<WKCategoryEntity *> *cats = [NSMutableArray array];
    for (WKCategoryEntity *cat in all) {
        if (cat.is_default) continue;
        if(!cat.category_id || cat.category_id.length == 0) continue;
        [cats addObject:cat];
        for (WKCategoryGroup *cg in cat.groups) {
            if([groupNo isEqualToString:cg.group_no]) {
                currentCategoryId = cat.category_id;
                break;
            }
        }
    }

    __weak typeof(self) weakSelf = self;
    void(^performMove)(NSString *) = ^(NSString *catId) {
        if(catId.length == 0) return;
        [[WKCategoryService shared] moveGroup:groupNo toCategoryId:catId].then(^(id r) {
            // 移动改变了分组归属 → server 上 follow 关系跟着变,
            // 本地 followedKeys 必须同步刷新，否则长按菜单 / unread 计数会滞后。
            [[WKFollowedKeysStore shared] reload];
            [weakSelf loadCategories];
        }).catch(^(NSError *e) { NSLog(@"移动分组失败: %@", e); });
    };

    // 没有自建分组：直接走新建（新建成功后自动 move）
    if (cats.count == 0) {
        [self showCreateCategoryDialogWithCompletion:^(WKCategoryEntity *cat) {
            if (cat.category_id.length == 0) return;
            performMove(cat.category_id);
        }];
        return;
    }

    // 复用 Add-to-follow 的自定义底部 sheet —— iPad-safe（之前用 ActionSheet 没配
    // popoverPresentationController，iPad 上会崩）。带 ✓ 标记当前归属的分组。
    NSString *currentIdCapture = currentCategoryId;
    [self presentFollowCategorySheetWithTitle:titleText
                                   categories:cats
                           selectedCategoryId:currentIdCapture
                                showCreateRow:YES
                                       onPick:^(NSString * _Nullable categoryId, NSString * _Nullable categoryName) {
        if (categoryId.length == 0) return;
        if ([categoryId isEqualToString:currentIdCapture]) return; // 同分组不动作
        performMove(categoryId);
    }];
}

-(void) showSectionManagePopup:(NSString *)sectionId title:(NSString *)title atPoint:(CGPoint)point {
    __weak typeof(self) weakSelf = self;
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(!spaceId || spaceId.length == 0) return;

    // 构建菜单项
    typedef void(^MenuAction)(void);
    NSMutableArray<NSDictionary *> *menuItems = [NSMutableArray array];

    // 新建群聊（自动归入当前分组）
    NSString *catId = [sectionId copy];
    [menuItems addObject:@{@"title": LLang(@"新建群聊"), @"icon": [WKConversationListVC iconCreateGroup], @"action": [^{
        [[WKApp shared] invoke:WKPOINT_CONTACTS_SELECT param:@{@"on_finished":^(NSArray<NSString*>*members){
            if(members.count == 0) return;
            if(members.count == 1) {
                [[WKNavigationManager shared] popViewControllerAnimated:YES];
                [[WKApp shared] pushConversation:[[WKChannel alloc] initWith:members[0] channelType:WK_PERSON]];
                return;
            }
            UIView *topView = [WKNavigationManager shared].topViewController.view;
            [topView showHUD];
            [[WKGroupManager shared] createGroup:members object:@{@"category_id": catId} complete:^(NSString *groupNo, NSError *error) {
                [topView hideHud];
                if(error) {
                    [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
                    return;
                }
                [[WKNavigationManager shared] popViewControllerAnimated:YES];
                [[WKApp shared] pushConversation:[[WKChannel alloc] initWith:groupNo channelType:WK_GROUP]];
                [weakSelf loadCategories];
            }];
        }}];
    } copy]}];

    // 重命名
    [menuItems addObject:@{@"title": LLang(@"重命名"), @"icon": [WKConversationListVC iconRename], @"action": [^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"重命名分组") message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.text = title;
            tf.placeholder = LLang(@"请输入分组名称");
        }];
        [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:LLang(@"确定") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            NSString *newName = alert.textFields.firstObject.text;
            if(!newName || newName.length == 0 || [newName isEqualToString:title]) return;
            [[WKCategoryService shared] renameCategory:spaceId categoryId:sectionId name:newName].then(^(id r) {
                [weakSelf loadCategories];
            }).catch(^(NSError *e) { NSLog(@"重命名失败: %@", e); });
        }]];
        [weakSelf presentViewController:alert animated:YES completion:nil];
    } copy]}];

    BOOL isFirst = NO;
    for (WKCategoryEntity *cat in _conversationListVM.categoryList) {
        if(cat.category_id && cat.category_id.length > 0) {
            isFirst = [cat.category_id isEqualToString:sectionId];
            break;
        }
    }
    if (!isFirst) {
        [menuItems addObject:@{@"title": LLang(@"移到最前"), @"icon": [WKConversationListVC iconMoveToFront], @"action": [^{
            NSMutableArray *newOrder = [NSMutableArray arrayWithObject:sectionId];
            for (WKCategoryEntity *cat in weakSelf.conversationListVM.categoryList) {
                if(cat.category_id.length > 0 && ![cat.category_id isEqualToString:sectionId]) {
                    [newOrder addObject:cat.category_id];
                }
            }
            [[WKCategoryService shared] sortCategories:spaceId categoryIds:newOrder].then(^(id r) {
                [weakSelf loadCategories];
            }).catch(^(NSError *e) { NSLog(@"排序失败: %@", e); });
        } copy]}];
    }

    [menuItems addObject:@{@"title": LLang(@"排序分组"), @"icon": [WKConversationListVC iconReorder], @"action": [^{
        [weakSelf showReorderCategoryPage];
    } copy]}];

    [menuItems addObject:@{@"title": LLang(@"删除分组"), @"icon": [WKConversationListVC iconDelete], @"isDestructive": @YES, @"action": [^{
        [WKAlertUtil alert:LLang(@"删除后该分组内的会话将不再归属任何分组，确定要删除？") buttonsStatement:@[LLang(@"取消"), LLang(@"删除")] chooseBlock:^(NSInteger buttonIdx) {
            if(buttonIdx == 1) {
                [[WKCategoryService shared] deleteCategory:spaceId categoryId:sectionId].then(^(id r) {
                    [weakSelf loadCategories];
                    // 服务端会把该分组下的全部 follow 一并取消，本地 followedKeys 必须同步刷新,
                    // 否则最近 tab 长按这些会话还会显示"取消关注"，要等下次 30s debounce 兜底才正确。
                    [[WKFollowedKeysStore shared] reload];
                }).catch(^(NSError *e) { NSLog(@"删除分组失败: %@", e); });
            }
        }];
    } copy]}];

    // 创建悬浮菜单
    [self showFloatingMenu:menuItems atPoint:point];
}

/// 在指定位置显示悬浮菜单（带阴影、圆角、三角箭头）
-(void) showFloatingMenu:(NSArray<NSDictionary *> *)menuItems atPoint:(CGPoint)point {
    // 浮层菜单实现挪到 WKFloatingMenu — 让 WKThreadListVC 等也能复用同样的视觉。
    [WKFloatingMenu showItems:menuItems atPoint:point];
}

-(void) dismissFloatingMenu {
    [WKFloatingMenu dismiss];
}

#pragma mark - Menu Icons (程序化绘制)

+ (UIImage *)iconCreateGroup {
    CGSize s = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor colorWithWhite:0.3 alpha:1] setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    // 人形
    CGContextAddArc(ctx, 8, 6, 3, 0, 2*M_PI, 0);
    CGContextStrokePath(ctx);
    CGContextMoveToPoint(ctx, 2, 17);
    CGContextAddCurveToPoint(ctx, 2, 13, 5, 11, 8, 11);
    CGContextAddCurveToPoint(ctx, 11, 11, 14, 13, 14, 17);
    CGContextStrokePath(ctx);
    // 加号
    CGContextMoveToPoint(ctx, 16, 10);
    CGContextAddLineToPoint(ctx, 16, 16);
    CGContextMoveToPoint(ctx, 13, 13);
    CGContextAddLineToPoint(ctx, 19, 13);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)iconRename {
    CGSize s = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor colorWithWhite:0.3 alpha:1] setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    // 铅笔图标
    CGContextMoveToPoint(ctx, 13, 4);
    CGContextAddLineToPoint(ctx, 16, 7);
    CGContextAddLineToPoint(ctx, 8, 15);
    CGContextAddLineToPoint(ctx, 4, 16);
    CGContextAddLineToPoint(ctx, 5, 12);
    CGContextClosePath(ctx);
    CGContextStrokePath(ctx);
    // 铅笔尖
    CGContextMoveToPoint(ctx, 5, 12);
    CGContextAddLineToPoint(ctx, 8, 15);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)iconMoveToFront {
    CGSize s = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor colorWithWhite:0.3 alpha:1] setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    // 上箭头 + 横线
    CGContextMoveToPoint(ctx, 10, 4);
    CGContextAddLineToPoint(ctx, 10, 14);
    CGContextMoveToPoint(ctx, 6, 8);
    CGContextAddLineToPoint(ctx, 10, 4);
    CGContextAddLineToPoint(ctx, 14, 8);
    CGContextMoveToPoint(ctx, 4, 16);
    CGContextAddLineToPoint(ctx, 16, 16);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)iconReorder {
    CGSize s = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor colorWithWhite:0.3 alpha:1] setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    // 三条横线 + 上下箭头
    for (int i = 0; i < 3; i++) {
        CGFloat y = 6 + i * 4;
        CGContextMoveToPoint(ctx, 4, y);
        CGContextAddLineToPoint(ctx, 12, y);
    }
    CGContextMoveToPoint(ctx, 16, 5);
    CGContextAddLineToPoint(ctx, 16, 15);
    CGContextMoveToPoint(ctx, 14, 7);
    CGContextAddLineToPoint(ctx, 16, 5);
    CGContextAddLineToPoint(ctx, 18, 7);
    CGContextMoveToPoint(ctx, 14, 13);
    CGContextAddLineToPoint(ctx, 16, 15);
    CGContextAddLineToPoint(ctx, 18, 13);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)iconDelete {
    CGSize s = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor redColor] setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    // 垃圾桶
    CGContextMoveToPoint(ctx, 5, 7);
    CGContextAddLineToPoint(ctx, 15, 7);
    CGContextMoveToPoint(ctx, 8, 5);
    CGContextAddLineToPoint(ctx, 12, 5);
    CGContextMoveToPoint(ctx, 6, 7);
    CGContextAddLineToPoint(ctx, 7, 16);
    CGContextAddLineToPoint(ctx, 13, 16);
    CGContextAddLineToPoint(ctx, 14, 7);
    CGContextMoveToPoint(ctx, 9, 9);
    CGContextAddLineToPoint(ctx, 9, 14);
    CGContextMoveToPoint(ctx, 11, 9);
    CGContextAddLineToPoint(ctx, 11, 14);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

-(void) showReorderCategoryPage {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(!spaceId || spaceId.length == 0) return;

    WKCategoryReorderVC *vc = [WKCategoryReorderVC new];
    vc.spaceId = spaceId;
    vc.categories = _conversationListVM.categoryList;
    __weak typeof(self) weakSelf = self;
    vc.onReorderComplete = ^{
        [weakSelf loadCategories];
    };
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

-(void) dealloc {
    NSLog(@"WKConversationListVC dealloc ....");
    [self removeDelegates];
    [self stopPingMonitoring];
}

#pragma mark - Pixel Particle Hint

-(void) tryShowPixelHintForMessage:(WKMessage *)message {
    // 拖动期间不弹像素通知 — 通知 view 抢手势会让长按 Ended 永不触发，snapshot 卡屏
    if (self.cellDragInProgress) return;
    NSLog(@"[HintDebug] >>> onMessage channel=%@/%d contentType=%ld fromUid=%@ msgSeq=%u",
          message.channel.channelId, message.channel.channelType,
          (long)message.contentType, message.fromUid ?: @"(nil)", message.messageSeq);

    if (!message) return;

    WKChannel *channel = message.channel;
    // 私聊 / 群聊 / 子区都允许触发，不再限制 channelType
    if (channel.channelType != WK_GROUP && channel.channelType != WK_COMMUNITY_TOPIC && channel.channelType != WK_PERSON) return;

    NSString *loginUid = [WKApp shared].loginInfo.uid;
    if (loginUid.length > 0 && [message.fromUid isEqualToString:loginUid]) return;

    // AI / 机器人的消息不弹像素提醒 — AI 回复频繁会刷屏，只保留人类发的消息
    if (message.fromUid.length > 0) {
        WKChannel *senderChannel = [WKChannel channelID:message.fromUid channelType:WK_PERSON];
        WKChannelInfo *senderInfo = [[WKSDK shared].channelManager getChannelInfo:senderChannel];
        if (senderInfo && senderInfo.robot) {
            NSLog(@"[HintDebug] SKIP: sender is robot uid=%@", message.fromUid);
            return;
        }
    }

    // 消息ID去重：无论是否可见，都先记录，防止返回页面时重复弹出
    NSNumber *msgIdNum = @(message.messageId);
    if (msgIdNum.unsignedLongLongValue == 0) return;
    if ([self.shownHintMsgIds containsObject:msgIdNum]) return;
    [self.shownHintMsgIds addObject:msgIdNum];
    if (self.shownHintMsgIds.count > 500) {
        [self.shownHintMsgIds removeAllObjects];
        [self.shownHintMsgIds addObject:msgIdNum];
    }

    // 以下条件不满足时静默跳过（messageId已记录，不会重复弹）
    // 不再限制 filterType — 任意 tab（全部 / 群聊 / 私聊 等）都允许触发
    if (!self.view.window) return;

    // 空间隔离：不属于当前空间的消息不显示
    if (![[WKLocalNotificationManager shared] isMessageInCurrentSpace:message]) return;

    if (self.connectedAtTime > 0 && message.timestamp > 0 && message.timestamp < self.connectedAtTime) return;

    NSInteger cType = message.contentType;
    if (cType >= 15) {
        NSLog(@"[HintDebug] SKIP: system msg contentType=%ld", (long)cType);
        return;
    }

    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:channel];
    if (channel.channelType == WK_GROUP) {
        // 群聊：直接检查群的 mute
        if (info && info.mute) return;
    } else if (channel.channelType == WK_COMMUNITY_TOPIC) {
        // 子区：只检查子区自身的 mute，不继承父群
        if (info && info.mute) return;
    } else if (channel.channelType == WK_PERSON) {
        // 私聊：对方设了免打扰也不弹
        if (info && info.mute) return;
    }

    NSLog(@"[HintDebug] PASS all filters → showing hint for %@ name=%@",
          channel.channelId, info.displayName ?: @"(nil)");

    NSString *name = info.displayName ?: @"";
    NSString *avatarURL = nil;
    if (channel.channelType == WK_GROUP) {
        if ([info.logo hasPrefix:@"http"]) {
            avatarURL = info.logo;
        } else {
            avatarURL = [WKAvatarUtil getGroupAvatar:channel.channelId cacheKey:info.avatarCacheKey];
        }
    } else if (channel.channelType == WK_PERSON) {
        // 私聊：channel.channelId 就是对方 uid
        if ([info.logo hasPrefix:@"http"]) {
            avatarURL = info.logo;
        } else {
            avatarURL = [WKAvatarUtil getAvatar:channel.channelId cacheKey:info.avatarCacheKey];
        }
    } else if (channel.channelType == WK_COMMUNITY_TOPIC) {
        // 子区名称：从 channelInfo 获取，如果为空则从父群的 threadPreviews 中查找
        if (name.length == 0) {
            NSRange range = [channel.channelId rangeOfString:@"____"];
            if (range.location != NSNotFound) {
                NSString *groupNo = [channel.channelId substringToIndex:range.location];
                WKConversationWrapModel *groupModel = [self.conversationListVM modelAtChannel:[WKChannel channelID:groupNo channelType:WK_GROUP]];
                if (groupModel && groupModel.threadPreviews) {
                    for (WKThreadModel *t in groupModel.threadPreviews) {
                        if ([t.channelId isEqualToString:channel.channelId]) {
                            name = t.name ?: @"";
                            break;
                        }
                    }
                }
                // 如果还是空，用父群名称 + #子区，头像用父群头像
                if (name.length == 0) {
                    WKChannel *parentChannel = [WKChannel channelID:groupNo channelType:WK_GROUP];
                    WKChannelInfo *parentInfo = [[WKSDK shared].channelManager getChannelInfo:parentChannel];
                    name = [NSString stringWithFormat:@"%@/#子区", parentInfo.displayName ?: groupNo];
                    if (parentInfo) {
                        if ([parentInfo.logo hasPrefix:@"http"]) {
                            avatarURL = parentInfo.logo;
                        } else {
                            avatarURL = [WKAvatarUtil getGroupAvatar:groupNo cacheKey:parentInfo.avatarCacheKey];
                        }
                    }
                }
                // 有子区名称时 avatarURL 留空，HUD 会自动用首字显示
            }
        }
    }

    // 消息内容：发送者 + 摘要
    NSString *content = nil;
    if (message.content) {
        NSString *digest = [message.content conversationDigest];
        NSString *senderName = nil;
        if (message.fromUid.length > 0) {
            WKChannel *senderChannel = [WKChannel channelID:message.fromUid channelType:WK_PERSON];
            WKChannelInfo *senderInfo = [[WKSDK shared].channelManager getChannelInfo:senderChannel];
            senderName = senderInfo.displayName;
        }
        if (senderName.length > 0 && digest.length > 0) {
            content = [NSString stringWithFormat:@"%@: %@", senderName, digest];
        } else {
            content = digest;
        }
    }

    uint32_t msgSeq = message.messageSeq;
    [WKPixelParticleHint showInView:self.view
                          avatarURL:avatarURL
                               name:name
                            content:content
                              onTap:^{
        UIViewController *topVC = [WKNavigationManager shared].topViewController;
        if ([topVC isKindOfClass:[WKConversationVC class]]) {
            WKConversationVC *existingVC = (WKConversationVC *)topVC;
            if ([existingVC.channel.channelId isEqualToString:channel.channelId]
                && existingVC.channel.channelType == channel.channelType) {
                if (msgSeq > 0) {
                    [existingVC locateToMessageSeq:msgSeq];
                }
                return;
            }
        }
        WKConversationVC *vc = [WKConversationVC new];
        vc.channel = channel;
        if (msgSeq > 0) {
            uint32_t orderSeq = [[WKSDK shared].chatManager getOrderSeq:msgSeq];
            if (orderSeq > 0) {
                vc.locationAtOrderSeq = orderSeq;
            }
        }
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
    }];
}

#pragma mark - ⚠️ 临时压力测试（上线前删除）

- (void)setupStressTestButton {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(16, WKScreenHeight - 160, 56, 56);
    btn.backgroundColor = [UIColor colorWithRed:0.9 green:0.1 blue:0.1 alpha:0.9];
    btn.layer.cornerRadius = 28;
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.3;
    btn.layer.shadowRadius = 4;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    btn.titleLabel.numberOfLines = 2;
    btn.titleLabel.textAlignment = NSTextAlignmentCenter;
    [btn setTitle:@"压力\n测试" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(stressTestTapped:) forControlEvents:UIControlEventTouchUpInside];
    btn.tag = 99999;
    [self.view addSubview:btn];
}

- (void)stressTestTapped:(UIButton *)btn {
    if (!btn.enabled) return;
    btn.enabled = NO;
    btn.userInteractionEnabled = NO;
    [btn setTitle:@"运行中" forState:UIControlStateDisabled];
    btn.backgroundColor = [UIColor grayColor];

    NSLog(@"========== [StressTest] START — 极限压力 ==========");
    __weak typeof(self) weakSelf = self;

    // ──────────────────────────────────────────────────────────────
    // 场景 A: 模拟网络恢复后 WebSocket 瞬间推送大量消息
    //
    // 真实路径:
    //   WebSocket IO线程 → WKChatManager.onRecvMessages(bg)
    //     → callRecvMessagesDelegate → dispatch_async(main)
    //     → WKConversationManager 写DB → callOnConversationUpdateDelegate(bg)
    //       → dispatch_async(main) → onConversationUpdate(main)
    //         → fetchThreadCountsForGroups (老代码: bg线程semaphore死锁)
    //         → rebuildGroupDisplayAndReload
    //
    // 模拟: 从多个后台线程并发通过 WKConversationManager 真实 delegate 通道
    //        发射 100 条会话更新（使用当前列表中的真实会话数据）
    // ──────────────────────────────────────────────────────────────
    NSArray<WKConversationWrapModel *> *existingModels = [self.conversationListVM conversationList];
    NSInteger convCount = existingModels.count;
    NSInteger sceneA_count = 100;
    NSLog(@"[StressTest] 场景A: 模拟WebSocket批量推送 → onConversationUpdate x%ld (现有会话%ld个)", (long)sceneA_count, (long)convCount);
    if (convCount > 0) {
        for (NSInteger i = 0; i < sceneA_count; i++) {
            WKConversationWrapModel *model = existingModels[i % convCount];
            WKConversation *conv = [model getConversation];
            if (!conv) continue;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [[WKSDK shared].conversationManager callOnConversationUpdateDelegate:conv];
            });
        }
    } else {
        NSLog(@"[StressTest] 警告: 会话列表为空，场景A跳过");
    }

    // ──────────────────────────────────────────────────────────────
    // 场景 B: 模拟高频 CMD 消息（typing + onlineStatus）
    //
    // 真实路径:
    //   WebSocket IO线程 → WKCMDManager.callOnCMDDelegate(bg)
    //     → dispatch_async(main)
    //       → WKSystemMessageHandler.cmdManager:onCMD:(main)
    //         → WKTypingManager / WKOnlineStatusManager
    //           (老代码: dispatch_sync(main) 阻塞bg线程)
    //
    // 模拟: 50个typing + 50个onlineStatus CMD 从后台线程并发发射
    // ──────────────────────────────────────────────────────────────
    NSInteger sceneB_count = 50;
    NSLog(@"[StressTest] 场景B: 模拟CMD批量推送 (typing x%ld + onlineStatus x%ld)", (long)sceneB_count, (long)sceneB_count);
    for (NSInteger i = 0; i < sceneB_count; i++) {
        NSString *uid = [NSString stringWithFormat:@"stress_user_%ld", (long)i];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            WKCMDModel *typingCmd = [[WKCMDModel alloc] init];
            typingCmd.cmd = @"typing";
            typingCmd.param = @{
                @"channel_id": uid,
                @"channel_type": @1,
                @"from_uid": uid,
                @"from_name": [NSString stringWithFormat:@"StressBot%ld", (long)i],
            };
            [[WKSDK shared].cmdManager callOnCMDDelegate:typingCmd];
        });
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            WKCMDModel *onlineCmd = [[WKCMDModel alloc] init];
            onlineCmd.cmd = @"onlineStatus";
            onlineCmd.param = @{
                @"uid": uid,
                @"all_offline": @0,
                @"main_device_flag": @0,
            };
            [[WKSDK shared].cmdManager callOnCMDDelegate:onlineCmd];
        });
    }

    // ──────────────────────────────────────────────────────────────
    // 场景 C: 模拟网络状态频繁抖动
    //
    // 真实路径:
    //   AFNetworking Reachability 回调(bg线程)
    //     → WKNetworkListener.callNetworkListenerStatusChangeDelegate
    //       (老代码: dispatch_sync(main_queue) 阻塞bg线程等主线程)
    //
    // 模拟: 20次网络状态变化从后台线程并发触发
    // ──────────────────────────────────────────────────────────────
    NSInteger sceneC_count = 20;
    NSLog(@"[StressTest] 场景C: 模拟网络状态抖动 x%ld", (long)sceneC_count);
    for (NSInteger i = 0; i < sceneC_count; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            [[WKNetworkListener shared] performSelector:@selector(callNetworkListenerStatusChangeDelegate)];
#pragma clang diagnostic pop
        });
    }

    // ──────────────────────────────────────────────────────────────
    // 场景 D: 模拟 A+B+C 叠加后再追加一波更猛的冲击
    //         延迟 0.5s 发射第二波，确保第一波正在处理时遭遇叠加
    // ──────────────────────────────────────────────────────────────
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"[StressTest] 场景D: 第二波叠加冲击 (conv x50 + CMD x30 + network x10)");
        if (convCount > 0) {
            for (NSInteger i = 0; i < 50; i++) {
                WKConversationWrapModel *model = existingModels[i % convCount];
                WKConversation *conv = [model getConversation];
                if (!conv) continue;
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [[WKSDK shared].conversationManager callOnConversationUpdateDelegate:conv];
                });
            }
        }
        for (NSInteger i = 0; i < 30; i++) {
            NSString *uid = [NSString stringWithFormat:@"stress_wave2_%ld", (long)i];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                WKCMDModel *cmd = [[WKCMDModel alloc] init];
                cmd.cmd = @"typing";
                cmd.param = @{ @"channel_id": uid, @"channel_type": @1, @"from_uid": uid, @"from_name": @"Wave2Bot" };
                [[WKSDK shared].cmdManager callOnCMDDelegate:cmd];
            });
        }
        for (NSInteger i = 0; i < 10; i++) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
                [[WKNetworkListener shared] performSelector:@selector(callNetworkListenerStatusChangeDelegate)];
#pragma clang diagnostic pop
            });
        }
    });

    // ──────────────────────────────────────────────────────────────
    // 检查点: 5秒后验证主线程是否存活
    // 老代码下主线程大概率已死锁，这个 block 永远不会执行
    // ──────────────────────────────────────────────────────────────
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[StressTest] === 5秒检查点: 主线程存活 ===");
        NSLog(@"[StressTest] 总计发射: conv更新=%ld, CMD=%ld, 网络抖动=%ld",
              (long)(sceneA_count + 50), (long)(sceneB_count * 2 + 30), (long)(sceneC_count + 10));
        [btn setTitle:@"通过" forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor colorWithRed:0.1 green:0.7 blue:0.2 alpha:0.9];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            btn.enabled = YES;
            btn.userInteractionEnabled = YES;
            [btn setTitle:@"压力\n测试" forState:UIControlStateNormal];
            btn.backgroundColor = [UIColor colorWithRed:0.9 green:0.1 blue:0.1 alpha:0.9];
            NSLog(@"========== [StressTest] END ==========");
        });
    });
}

@end
