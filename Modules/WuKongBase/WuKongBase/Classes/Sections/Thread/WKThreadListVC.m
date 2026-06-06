//
//  WKThreadListVC.m
//  WuKongBase
//

#import "WKThreadListVC.h"
#import "WKThreadListCell.h"
#import "WKThreadModel.h"
#import "WKThreadService.h"
#import "WKNavigationManager.h"
#import "WKConversationVC.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import "WKApp.h"
#import "WKFollowService.h"
#import "WKFollowedKeysStore.h"
#import "WKConversationListVM.h"
#import "WKCategoryService.h"
#import "WKCategoryEntity.h"
#import "WKFloatingMenu.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

static NSString *const kCellIdentifier = @"WKThreadListCell";
static const NSInteger kPageSize = 15;

@interface WKThreadListVC () <UITableViewDataSource, UITableViewDelegate, WKConversationManagerDelegate, WKReminderManagerDelegate>

@property (nonatomic, strong) UISegmentedControl *segmentControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *createBtn;
@property (nonatomic, strong) UILabel *emptyLbl;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIView *tableFooterView;
@property (nonatomic, strong) UIActivityIndicatorView *footerSpinner;

// 当前展示的线程（按当前 tab 过滤后）
@property (nonatomic, strong) NSArray<WKThreadModel *> *threads;
// 所有已加载的原始线程（跨页累积）
@property (nonatomic, strong) NSMutableArray<WKThreadModel *> *allLoadedThreads;

@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL isLoadingMore;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger totalCount;
// 每次 loadThreads 启动 +1, callback 比对; 不一致就丢弃, 防止
// 同 status 重复刷新 / active→archived→active 来回切时旧请求
// 把 stale 数据 append/写入选中 tab.
@property (nonatomic, assign) NSInteger loadGeneration;

@end

@implementation WKThreadListVC

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = LLang(@"子区列表");
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;

    [self.view addSubview:self.segmentControl];
    [self.view addSubview:self.tableView];
    [self.view addSubview:self.createBtn];
    [self.view addSubview:self.emptyLbl];

    self.threads = @[];
    self.allLoadedThreads = [NSMutableArray array];
    [self loadThreads];

    // 长按子区行 → 复用会话列表风格的浮层菜单（关注 / 取消关注）
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onThreadLongPress:)];
    longPress.minimumPressDuration = 0.4;
    [self.tableView addGestureRecognizer:longPress];

    [[WKSDK shared].conversationManager addDelegate:self];
    [[WKReminderManager shared] addDelegate:self];
}

// 切语言时所有静态文案 (nav title / segment / createBtn / emptyLbl) 都需重走 LLang
- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    if (type != WKViewConfigChangeTypeLang) return;
    self.title = LLang(@"子区列表");
    if (_segmentControl) {
        [_segmentControl setTitle:LLang(@"活跃") forSegmentAtIndex:0];
        [_segmentControl setTitle:LLang(@"已归档") forSegmentAtIndex:1];
    }
    if (_createBtn) {
        [_createBtn setTitle:[NSString stringWithFormat:@"+ %@", LLang(@"创建子区")] forState:UIControlStateNormal];
    }
    if (_emptyLbl) {
        _emptyLbl.text = LLang(@"暂无子区\n创建一个来讨论特定话题");
    }
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 不再在 viewWillAppear 里重跑 loadThreads —— 那条路径会 reset
    // currentPage=1 + 清 allLoadedThreads + 只拉首页 (pageSize=15)，用户从子区
    // 详情页返回时之前已加载的 2+ 页全部丢失，contentSize 缩到 15 行高度，
    // contentOffset 被 clamp 到 maxY → 列表跳回顶部。
    //
    // 数据新鲜度的来源继续靠：
    //  - WKConversationManagerDelegate / WKReminderManagerDelegate（在
    //    viewDidLoad 注册、dealloc 移除）— 进详情页期间收到的 unread / 提醒
    //    变化都会触发 [tableView reloadData]，contentOffset 自然保留
    //  - 用户主动下拉刷新 → onRefresh → loadThreads（这条会 reset 是预期的）
    //
    // 远端新建子区（其他端 / 其他人）的发现交给下拉刷新 — 大多用户从详情返回时
    // 不希望"列表跳走"，这是更高优先级的 UX。
    [self.tableView reloadData];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat navBottom = [self getNavBottom];
    CGFloat padding = 16.0f;

    self.segmentControl.frame = CGRectMake(padding, navBottom + 12, self.view.lim_width - padding * 2, 32);

    CGFloat tableTop = self.segmentControl.lim_bottom + 10;
    CGFloat tableBottom = 60 + self.view.safeAreaInsets.bottom + 12;
    self.tableView.frame = CGRectMake(0, tableTop, self.view.lim_width, self.view.lim_height - tableTop - tableBottom);

    CGFloat btnWidth = self.view.lim_width - padding * 2;
    self.createBtn.frame = CGRectMake(padding,
                                       self.view.lim_height - 60 - self.view.safeAreaInsets.bottom,
                                       btnWidth,
                                       44);

    self.emptyLbl.frame = CGRectMake(0, tableTop + 80, self.view.lim_width, 60);
}

#pragma mark - Data

/// 当前 segment 对应的 server status query：active / archived。
/// 同 server 端 api.go:300 parseListThreadStatuses 接受的字面量。
- (NSString *)currentStatusParam {
    return (self.segmentControl.selectedSegmentIndex == 0) ? @"active" : @"archived";
}

- (void)loadThreads {
    // 不再用 self.loading 早 return — 用户在飞行中切 tab 时
    // onSegmentChanged → loadThreads 不能被吞掉. 改用 generation
    // token: capture 本次 gen, 回调对比当前 gen 一致才写, 否则丢弃.
    // 比单纯 capture status 更彻底 — 同 status 重复刷新 (e.g.
    // active→archived→active) 时旧 active 请求也会作废, 不会 append
    // stale rows.
    self.loadGeneration += 1;
    NSInteger gen = self.loadGeneration;
    self.loading = YES;
    self.currentPage = 1;
    [self.allLoadedThreads removeAllObjects];

    __weak typeof(self) weakSelf = self;
    NSString *requestedStatus = [self currentStatusParam];
    [[WKThreadService shared] listThreads:self.groupNo status:requestedStatus pageIndex:1 pageSize:kPageSize].then(^(NSDictionary *result) {
        if (gen != weakSelf.loadGeneration) return; // stale
        weakSelf.loading = NO;
        [weakSelf.refreshControl endRefreshing];
        weakSelf.totalCount = [result[@"count"] integerValue];
        NSArray<WKThreadModel *> *list = result[@"list"] ?: @[];
        [weakSelf.allLoadedThreads addObjectsFromArray:list];
        [weakSelf filterAndReload];
        [weakSelf updateFooterVisibility];
        [weakSelf loadMoreUntilFillsScreenIfNeed];
    }).catch(^(NSError *error) {
        if (gen != weakSelf.loadGeneration) return; // stale
        weakSelf.loading = NO;
        [weakSelf.refreshControl endRefreshing];
        [weakSelf.view showMsg:error.domain];
    });
}

- (void)loadMoreThreads {
    if (self.isLoadingMore || self.loading) return;
    // 已加载全部（两个 tab 都支持分页 —— server #1378 后 ?status=archived 同样
    // 走 count + list 分页协议）
    if (self.allLoadedThreads.count >= (NSUInteger)self.totalCount) return;

    self.isLoadingMore = YES;
    [self.footerSpinner startAnimating];
    NSInteger nextPage = self.currentPage + 1;
    // capture 当前 gen, 若 loadThreads 在飞行中触发, 本次 loadMore 的
    // 回包同样要被作废, 不要 append 到 reloaded 后的 list 上.
    NSInteger gen = self.loadGeneration;
    NSString *requestedStatus = [self currentStatusParam];

    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] listThreads:self.groupNo status:requestedStatus pageIndex:nextPage pageSize:kPageSize].then(^(NSDictionary *result) {
        if (gen != weakSelf.loadGeneration) { // stale
            weakSelf.isLoadingMore = NO;
            [weakSelf.footerSpinner stopAnimating];
            return;
        }
        weakSelf.isLoadingMore = NO;
        [weakSelf.footerSpinner stopAnimating];
        weakSelf.totalCount = [result[@"count"] integerValue];
        NSArray<WKThreadModel *> *newItems = result[@"list"] ?: @[];
        if (newItems.count == 0) return;
        weakSelf.currentPage = nextPage;
        [weakSelf.allLoadedThreads addObjectsFromArray:newItems];
        [weakSelf filterAndReload];
        [weakSelf updateFooterVisibility];
        [weakSelf loadMoreUntilFillsScreenIfNeed];
    }).catch(^(NSError *error) {
        weakSelf.isLoadingMore = NO;
        [weakSelf.footerSpinner stopAnimating];
    });
}

- (void)filterAndReload {
    // server 已按 ?status=active/archived 过滤好，不再做客户端二次过滤
    self.threads = [self.allLoadedThreads copy];
    [self.tableView reloadData];
    self.emptyLbl.hidden = (self.threads.count > 0);
}

- (void)updateFooterVisibility {
    BOOL hasMore = (self.allLoadedThreads.count < (NSUInteger)self.totalCount);
    self.tableView.tableFooterView = hasMore ? self.tableFooterView : [[UIView alloc] init];
}

// 首屏数据如果不够撑满 tableView (contentHeight <= frameHeight), scrollViewDidScroll
// 的 if (contentHeight > frameHeight ...) 直接 false, 永远不会触发 loadMoreThreads,
// 用户看到的就是"177 个子区只显示 2 个"。这里在主线程下一拍主动 loadMore 凑齐
// 第一屏。loadMoreThreads 内部已有 isLoadingMore / hasMore / generation token
// 防御, 重入安全。
- (void)loadMoreUntilFillsScreenIfNeed {
    BOOL hasMore = (self.allLoadedThreads.count < (NSUInteger)self.totalCount);
    if (!hasMore) return;
    [self.tableView layoutIfNeeded];
    CGFloat contentH = self.tableView.contentSize.height;
    CGFloat frameH = self.tableView.frame.size.height;
    if (frameH <= 0 || contentH > frameH) return; // 已撑满, 走原 scrollViewDidScroll
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf loadMoreThreads];
    });
}

#pragma mark - UIScrollViewDelegate (load more on scroll)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;
    if (contentHeight > frameHeight && offsetY > contentHeight - frameHeight - 80) {
        [self loadMoreThreads];
    }
}

#pragma mark - Actions

- (void)onSegmentChanged:(UISegmentedControl *)sender {
    // 切 tab 改成重新拉数据：server 自 #1378 起按 ?status=active/archived 各自分页,
    // 客户端不再用一份 cache 跨 tab 过滤（之前 client filter 会让已归档 tab 永远空）
    [self loadThreads];
}

- (void)onRefresh {
    [self loadThreads];
}

- (void)onCreateThread {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"创建子区")
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = LLang(@"子区名称 (最多50字)");
    }];

    __weak typeof(self) weakSelf = self;
    UIAlertAction *createAction = [UIAlertAction actionWithTitle:LLang(@"创建") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        if (name.length == 0) return;
        if (name.length > 50) {
            name = [name substringToIndex:50];
        }
        [weakSelf doCreateThread:name sourceMessageId:nil];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:cancelAction];
    [alert addAction:createAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)doCreateThread:(NSString *)name sourceMessageId:(NSString *)sourceMessageId {
    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] createThread:self.groupNo name:name sourceMessageId:sourceMessageId sourceMessagePayload:nil].then(^(WKThreadModel *thread) {
        [[WKThreadService shared] joinThread:thread.shortId].then(^(id result) {
            // 写回本地 model：viewWillAppear 不再 loadThreads（避免列表跳回顶部 +
            // 丢分页），从详情返回时只 reloadData，必须在跳详情前把新建的 thread
            // append 到 allLoadedThreads，否则用户回到这一页看不到刚创建的子区
            // （PR review #4 critical）。
            thread.isMember = YES;
            [weakSelf appendCreatedThreadIfAbsent:thread];
            [weakSelf openThread:thread];
        }).catch(^(NSError *error) {
            // join 失败也插入：thread 创建已成功，列表里得有它；isMember 保持 NO
            // 让用户从详情回来时还能再点一次加入
            [weakSelf appendCreatedThreadIfAbsent:thread];
            [weakSelf openThread:thread];
        });
    }).catch(^(NSError *error) {
        [weakSelf.view showMsg:error.domain];
    });
}

/// 把新建的 thread 插入 allLoadedThreads 顶部并触发刷新；shortId 已存在则跳过
/// （下拉刷新已经把它拉回来的罕见 race 下避免重复行）。
- (void)appendCreatedThreadIfAbsent:(WKThreadModel *)thread {
    if (!thread || thread.shortId.length == 0) return;
    for (WKThreadModel *t in self.allLoadedThreads) {
        if ([t.shortId isEqualToString:thread.shortId]) return;
    }
    [self.allLoadedThreads insertObject:thread atIndex:0];
    self.totalCount += 1;
    [self filterAndReload];
    [self updateFooterVisibility];
}

- (void)openThread:(WKThreadModel *)thread {
    WKChannel *channel = [thread toChannel];
    [[WKApp shared] invoke:WKPOINT_CONVERSATION_SHOW param:channel];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.threads.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKThreadListCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier forIndexPath:indexPath];
    WKThreadModel *thread = self.threads[indexPath.row];
    [cell refreshWithModel:thread];
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKThreadModel *thread = self.threads[indexPath.row];
    BOOL hasPreview = NO;
    WKChannel *threadChannel = [WKChannel channelID:thread.channelId channelType:WK_COMMUNITY_TOPIC];
    NSArray<WKReminder *> *reminders = [[WKReminderDB shared] getWaitDoneReminder:threadChannel];
    for (WKReminder *r in reminders) {
        if (r.type == WKReminderTypeMentionMe) { hasPreview = YES; break; }
    }
    if (!hasPreview) {
        WKConversation *threadConv = [[WKSDK shared].conversationManager getConversation:threadChannel];
        if (threadConv && threadConv.lastMessage && threadConv.lastMessage.content) {
            NSString *digest = [threadConv.lastMessage.content conversationDigest];
            if (digest.length > 0) hasPreview = YES;
        }
    }
    if (!hasPreview && thread.lastMessageContent.length > 0) {
        hasPreview = YES;
    }
    return hasPreview ? 80.0f : 62.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    WKThreadModel *thread = self.threads[indexPath.row];

    __weak typeof(self) weakSelf = self;
    if (!thread.isMember) {
        [[WKThreadService shared] joinThread:thread.shortId].then(^(id result) {
            // 写回本地 model：viewWillAppear 不再 loadThreads（避免列表跳走），
            // 从详情返回时只 reloadData，必须在跳详情前把 isMember 翻成 YES，
            // 否则用户回到这一页 cell 仍显示"加入"状态直到下拉刷新
            // （PR review #4 critical）。
            thread.isMember = YES;
            [weakSelf openThread:thread];
        }).catch(^(NSError *error) {
            [weakSelf openThread:thread];
        });
    } else {
        [self openThread:thread];
    }
}

// 移除 trailingSwipeActionsConfigurationForRowAtIndexPath: —— 左滑 swipe pan 在
// 这个 cell 高度（80pt 含 preview）下跟 tableView 的竖滚 pan / cell tap 抢手势：
// 用户轻微横向位移会被识别成 tap 误打开详情，偏竖直的滑动又被列表 scroll 抢走。
// 归档 / 取消归档 / 删除 / 退出全部移到长按菜单 (showFollowMenuForThread:) 里,
// 长按本身跟 tap/pan 互不干扰，识别可靠；破坏性操作 (归档/删除/退出) 全部走
// confirmXxxThread: 二次确认。

#pragma mark - Thread Operations

- (void)confirmDeleteThread:(WKThreadModel *)thread {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"删除子区")
                                                                  message:[NSString stringWithFormat:@"%@「%@」?", LLang(@"确定删除子区"), thread.name]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"删除") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[WKThreadService shared] deleteThread:weakSelf.groupNo shortId:thread.shortId].then(^(id result) {
            [weakSelf loadThreads];
        }).catch(^(NSError *error) {
            [weakSelf.view showMsg:error.domain];
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmArchiveThread:(WKThreadModel *)thread {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"归档子区")
                                                                  message:[NSString stringWithFormat:@"%@「%@」?", LLang(@"确定归档子区"), thread.name]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"归档") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf archiveThread:thread];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)archiveThread:(WKThreadModel *)thread {
    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] archiveThread:self.groupNo shortId:thread.shortId].then(^(id result) {
        [weakSelf loadThreads];
    }).catch(^(NSError *error) {
        [weakSelf.view showMsg:error.domain];
    });
}

- (void)unarchiveThread:(WKThreadModel *)thread {
    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] unarchiveThread:self.groupNo shortId:thread.shortId].then(^(id result) {
        [weakSelf loadThreads];
    }).catch(^(NSError *error) {
        [weakSelf.view showMsg:error.domain];
    });
}

#pragma mark - Lazy Init

- (UISegmentedControl *)segmentControl {
    if (!_segmentControl) {
        _segmentControl = [[UISegmentedControl alloc] initWithItems:@[LLang(@"活跃"), LLang(@"已归档")]];
        _segmentControl.selectedSegmentIndex = 0;
        [_segmentControl addTarget:self action:@selector(onSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return _segmentControl;
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        _tableView.separatorInset = UIEdgeInsetsMake(0, 58, 0, 0);
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.tableFooterView = [[UIView alloc] init];
        [_tableView registerClass:[WKThreadListCell class] forCellReuseIdentifier:kCellIdentifier];
        _tableView.refreshControl = self.refreshControl;
    }
    return _tableView;
}

- (UIRefreshControl *)refreshControl {
    if (!_refreshControl) {
        _refreshControl = [[UIRefreshControl alloc] init];
        [_refreshControl addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventValueChanged];
    }
    return _refreshControl;
}

- (UIView *)tableFooterView {
    if (!_tableFooterView) {
        _tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 52)];
        _footerSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _footerSpinner.center = CGPointMake(UIScreen.mainScreen.bounds.size.width / 2, 26);
        [_tableFooterView addSubview:_footerSpinner];
    }
    return _tableFooterView;
}

- (UIButton *)createBtn {
    if (!_createBtn) {
        _createBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_createBtn setTitle:[NSString stringWithFormat:@"+ %@", LLang(@"创建子区")] forState:UIControlStateNormal];
        [_createBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _createBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        _createBtn.backgroundColor = [WKApp shared].config.themeColor;
        _createBtn.layer.cornerRadius = 22;
        _createBtn.layer.masksToBounds = YES;
        [_createBtn addTarget:self action:@selector(onCreateThread) forControlEvents:UIControlEventTouchUpInside];
    }
    return _createBtn;
}

- (UILabel *)emptyLbl {
    if (!_emptyLbl) {
        _emptyLbl = [[UILabel alloc] init];
        _emptyLbl.text = LLang(@"暂无子区\n创建一个来讨论特定话题");
        _emptyLbl.numberOfLines = 2;
        _emptyLbl.textAlignment = NSTextAlignmentCenter;
        _emptyLbl.font = [UIFont systemFontOfSize:14];
        _emptyLbl.textColor = [UIColor lightGrayColor];
        _emptyLbl.hidden = YES;
    }
    return _emptyLbl;
}

- (void)dealloc {
    [[WKSDK shared].conversationManager removeDelegate:self];
    [[WKReminderManager shared] removeDelegate:self];
}

#pragma mark - 长按菜单：关注 / 取消关注（与会话列表菜单同款风格）

- (void)onThreadLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint pInTable = [gesture locationInView:self.tableView];
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:pInTable];
    if (!ip || ip.row >= (NSInteger)self.threads.count) return;
    WKThreadModel *thread = self.threads[ip.row];

    UIWindow *window = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    CGPoint pInWindow = [self.tableView convertPoint:pInTable toView:window];

    [self showFollowMenuForThread:thread atPointInWindow:pInWindow];

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
}

- (void)showFollowMenuForThread:(WKThreadModel *)thread atPointInWindow:(CGPoint)pointInWindow {
    if (thread.channelId.length == 0) return;
    WKFollowedKeysStore *store = [WKFollowedKeysStore shared];
    BOOL isFollowed = [store isFollowedWithType:WKFollowTargetTypeThread targetId:thread.channelId];
    NSString *currentUid = [WKSDK shared].options.connectInfo.uid ?: @"";
    BOOL isCreator = (currentUid.length > 0 && [thread.creatorUid isEqualToString:currentUid]);
    // 服务端 service.go canOperate: 子区创建者 OR 群主/管理员都能 archive/delete
    // 任何子区。iOS 也对齐这条权限规则 —— 群主/管理员长按非自己创建的子区也能
    // 看到归档/删除选项。WKChannelManager.isManager:memberUID: 已经覆盖
    // creator+manager 两种 role（WKChannelManager.m:348）。
    BOOL isGroupAdmin = NO;
    if (currentUid.length > 0 && self.groupNo.length > 0) {
        WKChannel *parentChannel = [WKChannel channelID:self.groupNo channelType:WK_GROUP];
        isGroupAdmin = [[WKSDK shared].channelManager isManager:parentChannel memberUID:currentUid];
    }
    BOOL canManageThread = isCreator || isGroupAdmin;
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;

    // 关注 / 取消关注
    if (isFollowed) {
        [items addObject:@{
            @"title": LLang(@"取消关注"),
            @"icon": [WKFloatingMenu iconUnfollow],
            @"action": ^{ [weakSelf doUnfollowThread:thread]; }
        }];
    } else {
        [items addObject:@{
            @"title": LLang(@"添加到关注"),
            @"icon": [WKFloatingMenu iconFollow],
            @"action": ^{ [weakSelf doFollowThread:thread]; }
        }];
    }

    // 归档 / 取消归档 / 删除 —— 子区创建者 OR 群主/管理员都能用，与服务端
    // canOperate (service.go:674) 完全对齐。普通成员的「退出子区」入口已下线 ——
    // 产品语义上用户在子区列表里默认是加入态，没有显式退出操作的需求。
    if (canManageThread) {
        if (thread.status == WKThreadStatusActive) {
            [items addObject:@{
                @"title": LLang(@"归档"),
                @"action": ^{ [weakSelf confirmArchiveThread:thread]; }
            }];
        } else if (thread.status == WKThreadStatusArchived) {
            [items addObject:@{
                @"title": LLang(@"取消归档"),
                @"action": ^{ [weakSelf unarchiveThread:thread]; }
            }];
        }
        [items addObject:@{
            @"title": LLang(@"删除子区"),
            @"isDestructive": @YES,
            @"action": ^{ [weakSelf confirmDeleteThread:thread]; }
        }];
    }
    [WKFloatingMenu showItems:items atPoint:pointInWindow];
}

/// 关注子区。两条路径，与会话列表 showAddToFollowDialogForModel: 的子区分支同款语义
/// （PR review #5 critical）：
///  - 父群已关注：直接 followThread，后端 cascade 处理父群关注关系
///  - 父群未关注：弹分组选择 → refollowChannel(父群) → moveGroup(父群到分组) → followThread
///    必须把父群移进非默认分组才能让 Follow tab 看见 —— buildGroupDisplayList 严格
///    跳过 default 分组（is_default == YES，VM:1877）。直接 followThread 不带这一步,
///    后端虽然能落数，UI 上是隐藏的。
- (void)doFollowThread:(WKThreadModel *)thread {
    if (thread.channelId.length == 0) return;
    BOOL parentFollowed = [[WKFollowedKeysStore shared]
                            isFollowedWithType:WKFollowTargetTypeChannel
                                      targetId:self.groupNo];
    if (parentFollowed) {
        [self performFollowThreadDirect:thread];
    } else {
        [self pickCategoryAndPerformFollowThread:thread];
    }
}

/// 父群已关注 — 直接关注子区，与原实现一致。
- (void)performFollowThreadDirect:(WKThreadModel *)thread {
    NSString *parentGroupNo = self.groupNo;
    __weak typeof(self) weakSelf = self;
    [[WKFollowService shared] followThread:thread.channelId].then(^(id _) {
        // followedKeys 是异步 reload，必须等回包才 reloadData，否则 cell 上的星标
        // 还是旧状态（与 unfollowConversationModel: 同款 chain）
        return [[WKFollowedKeysStore shared] reload];
    }).then(^(id _) {
        // PR review #8 critical：父群之前可能没有任何已关注子区，cachedTopicsByGroup
        // 在冷启时只跑了 maxPages=1，新关注的子区若落在 page 2+ 上 cache 漏掉它,
        // Follow tab badge / +N 角标会算不到这一条 unread。store 已 reload，闸门自动
        // 翻 maxPages=10，refreshThreadCountForGroups 重新拉父群补全 cache。
        [[WKConversationListVM shared] refreshThreadCountForGroups:[NSSet setWithObject:parentGroupNo]];
        [weakSelf.view showMsg:LLang(@"已添加到关注")];
        [weakSelf.tableView reloadData];
        return (id)nil;
    }).catch(^(NSError *err) {
        [weakSelf.view showMsg:err.domain ?: LLang(@"添加到关注失败")];
    });
}

/// 父群未关注 — 弹简单 action sheet 让用户选目标分组（非默认分组），选完串
/// refollowChannel(父群) → moveGroup(父群→分组) → followThread。空非默认分组的
/// 边界给一条提示让用户去会话列表创建分组（这里不内联 create 弹窗，避免在子区
/// 列表 VC 里塞 follow flow 的全部 UI 路径，会话列表那边已有完整的 sheet）。
- (void)pickCategoryAndPerformFollowThread:(WKThreadModel *)thread {
    NSArray<WKCategoryEntity *> *all = [WKConversationListVM shared].categoryList;
    NSMutableArray<WKCategoryEntity *> *cats = [NSMutableArray array];
    for (WKCategoryEntity *cat in all) {
        if (cat.is_default) continue;
        if (cat.category_id.length == 0) continue;
        [cats addObject:cat];
    }
    if (cats.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"添加到关注")
                                                                        message:LLang(@"父群尚未关注。请先在会话列表创建分组并关注此群，然后再来此处关注子区。")
                                                                 preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:LLang(@"我知道了") style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:LLang(@"添加到关注")
                                                                     message:LLang(@"父群尚未关注，请选择父群所在分组")
                                                              preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (WKCategoryEntity *cat in cats) {
        NSString *catId = cat.category_id;
        NSString *catName = cat.name;
        [sheet addAction:[UIAlertAction actionWithTitle:catName ?: @""
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [weakSelf performFollowThreadWithRefollowParent:thread categoryId:catId categoryName:catName];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    // iPad popover 锚点（避免崩）
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2,
                                                                     self.view.bounds.size.height - 100, 1, 1);
        sheet.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

/// 与 WKConversationListVC.performFollowThread:parentGroupNo:categoryId:categoryName: 的
/// categoryId 非空分支同款链：refollowChannel(父群) → moveGroup → followThread。
- (void)performFollowThreadWithRefollowParent:(WKThreadModel *)thread
                                   categoryId:(NSString *)categoryId
                                 categoryName:(NSString *)categoryName {
    NSString *parentGroupNo = self.groupNo;
    NSString *threadChannelId = thread.channelId;
    __weak typeof(self) weakSelf = self;
    AnyPromise *chain = [[WKFollowService shared] refollowChannel:parentGroupNo].then(^id(id _) {
        return [[WKCategoryService shared] moveGroup:parentGroupNo toCategoryId:categoryId];
    }).then(^id(id _) {
        return [[WKFollowService shared] followThread:threadChannelId];
    }).then(^id(id _) {
        // PR review #8 critical：必须等 store.reload 回包再 reloadData，否则 cell 上
        // 的星标还是旧 unfollowed 状态（与 performFollowThreadDirect 同款 chain）。
        return [[WKFollowedKeysStore shared] reload];
    });
    chain.then(^(id _) {
        // PR review #8 critical：父群之前没关注，cachedTopicsByGroup 里也没有它的
        // 任何条目；刚刚 follow 的子区必须主动 fetch 进 cache，否则 Follow tab
        // badge / +N 角标都看不到这条 unread。store 已 loaded → 闸门 maxPages=10。
        [[WKConversationListVM shared] refreshThreadCountForGroups:[NSSet setWithObject:parentGroupNo]];
        // 重新拉一次 categories，让 buildGroupDisplayList 立即看到父群在新分组下
        [[WKConversationListVM shared] loadCategoriesWithCompletion:nil];
        NSString *toast = categoryName.length > 0
            ? [NSString stringWithFormat:LLang(@"已添加到「%@」"), categoryName]
            : LLang(@"已添加到关注");
        [weakSelf.view showMsg:toast];
        [weakSelf.tableView reloadData];
    }).catch(^(NSError *err) {
        [weakSelf.view showMsg:err.domain ?: LLang(@"添加到关注失败")];
    });
}

- (void)doUnfollowThread:(WKThreadModel *)thread {
    __weak typeof(self) weakSelf = self;
    [[WKFollowService shared] unfollowThread:thread.channelId].then(^(id _) {
        return [[WKFollowedKeysStore shared] reload];
    }).then(^(id _) {
        [weakSelf.view showMsg:LLang(@"已取消关注")];
        [weakSelf.tableView reloadData];
        return (id)nil;
    }).catch(^(NSError *err) {
        [weakSelf.view showMsg:err.domain ?: LLang(@"取消关注失败")];
    });
}

#pragma mark - WKConversationManagerDelegate

- (void)onConversationUpdate:(NSArray<WKConversation *> *)conversations {
    NSString *prefix = [NSString stringWithFormat:@"%@____", self.groupNo];
    for (WKConversation *conv in conversations) {
        if (conv.channel.channelType == WK_COMMUNITY_TOPIC && [conv.channel.channelId hasPrefix:prefix]) {
            [self.tableView reloadData];
            return;
        }
    }
}

#pragma mark - WKReminderManagerDelegate

- (void)reminderManager:(WKReminderManager *)manager didChange:(WKChannel *)channel reminders:(NSArray<WKReminder *> *)reminders {
    NSString *prefix = [NSString stringWithFormat:@"%@____", self.groupNo];
    if (channel.channelType == WK_COMMUNITY_TOPIC && [channel.channelId hasPrefix:prefix]) {
        [self.tableView reloadData];
    }
}

@end
