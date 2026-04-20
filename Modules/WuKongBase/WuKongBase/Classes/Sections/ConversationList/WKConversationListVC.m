//
//  WKConversationListVC.m
//  WuKongBase
//
//  Created by tt on 2019/12/15.
//

#import "WKConversationListVC.h"
#import "WKConversationListVM.h"
#import "WKThreadCreatedContent.h"
#import "WKConversationListCell.h"
#import "WKConversationGroupThreadCell.h"
#import "WKThreadListVC.h"
#import "WKCategoryEntity.h"
#import "WKCategoryService.h"
#import "WKCategorySectionCell.h"
#import "WKCategoryReorderVC.h"
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
#import "WKSpaceConversationCache.h"
#import "WKPCOnlineVC.h"
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
@property(nonatomic,strong) UIView *fixedHeaderContainer; // 固定在顶部的搜索栏+tab容器
@property(nonatomic,strong) NSArray<WKConversationDisplayItem *> *groupDisplayList; // 群聊 tab 展示列表

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
    self.currentLatencyMs = -1;

    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];

    // 先创建固定头部（搜索栏+tab），再创建 tableView（tableView frame 需要依赖固定头部高度）
    [self setupFixedHeader];
    [self.view addSubview:self.tableView];
    self.connectLock = [[NSLock alloc] init];
    self.conversationLock = [[NSRecursiveLock alloc] init];
    [self addDelegates];

    // 恢复上次选中的 tab
    NSInteger savedTab = [[NSUserDefaults standardUserDefaults] integerForKey:@"WKConversationTabIndex"];
    _conversationListVM.filterType = savedTab;
    [_conversationListVM restoreCollapsedSections];
    [self setupConversationTabView];

    // 加载当前 Space 信息
    [self loadCurrentSpace];

    // 加载最近会话列表数据
    __weak __typeof(self) weakSelf  = self;
    [_conversationListVM loadConversationList:^{
        // 先用当前 categoryList（可能为空）构建一次展示列表，确保群聊 tab 能立即显示内容
        [weakSelf rebuildGroupDisplayAndReload];
        [weakSelf refreshBadge];
        // 异步加载分组数据，完成后再次刷新
        [weakSelf loadCategories];
    }];

//    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(timerRefreshTable) userInfo:nil repeats:YES];
//
    // PC在线状态移到导航栏图标显示
    [self updatePCOnlineIcon:[WKOnlineStatusManager shared].pcOnline deviceFlag:[WKOnlineStatusManager shared].pcDeviceFlag];

    // 给导航栏标题添加点击手势以切换 Space
    [self setupTitleTapGesture];

    // 初始化标题（即使异步加载未完成也先显示默认标题）
    [self refreshTitle];
}

// 给标题添加点击手势
- (void)setupTitleTapGesture {
    // 给 titleLabel 添加点击手势
    self.navigationBar.titleLabel.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(spaceButtonTapped)];
    [self.navigationBar.titleLabel addGestureRecognizer:tapGesture];

    // 在导航栏上添加折叠箭头（标题右侧，默认向右，展开时向下）
    UIImage *arrowImg = [[WKApp shared] loadImage:@"arrow_right" moduleID:@"WuKongLogin"];
    _spaceArrowView = [[UIImageView alloc] initWithImage:arrowImg];
    _spaceArrowView.contentMode = UIViewContentModeScaleAspectFit;
    _spaceArrowView.frame = CGRectMake(0, 0, 12, 12);
    _spaceArrowView.hidden = NO;
    _spaceArrowView.userInteractionEnabled = YES;
    UITapGestureRecognizer *arrowTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(spaceButtonTapped)];
    [_spaceArrowView addGestureRecognizer:arrowTap];
    [self.navigationBar addSubview:_spaceArrowView];
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
    return true;
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

    // 从内存刷新 PC 在线状态
    BOOL pcOnline = [WKOnlineStatusManager shared].pcOnline;
    NSLog(@"[PCDebug] viewWillAppear: pcOnline=%d, setting pcOnlineBtn.hidden=%d", pcOnline, !pcOnline);
    self.pcOnlineBtn.hidden = !pcOnline;
    [self relayoutRightItems];

    // 频繁切换 tab 时节流，2 秒内不重复加载
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - self.lastLoadTime < 2) {
        return;
    }
    self.lastLoadTime = now;

    // 重新从 SDK 加载会话列表，确保新会话（如首次发消息）能显示出来
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
}

-(void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
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
}

-(void) removeDelegates {
    [[WKReminderManager shared] removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"WKShowCreateCategoryDialog" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"WKThreadCountBatchUpdated" object:nil];
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
        CGFloat gap = 12.0f;

        // 信号容器（图标+延迟文字）
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

        // PC 在线图标（默认隐藏）
        self.pcOnlineBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.pcOnlineBtn.frame = CGRectMake(0, 0, iconSize, iconSize);
        UIImage *pcImg = [self imageName:@"ConversationList/Index/PCOnline"];
        if (pcImg) {
            pcImg = [pcImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [self.pcOnlineBtn setImage:pcImg forState:UIControlStateNormal];
            [self.pcOnlineBtn setTintColor:[UIColor grayColor]];
        }
        [self.pcOnlineBtn addTarget:self action:@selector(pcOnlineIconTapped) forControlEvents:UIControlEventTouchUpInside];
        self.pcOnlineBtn.hidden = YES;

        // 加号按钮
        UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        addBtn.tag = 8888;
        addBtn.frame = CGRectMake(0, 0, 24, 24);
        UIImage *addImg = [self imageName:@"ConversationList/Index/Add"];
        addImg = [addImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [addBtn setImage:addImg forState:UIControlStateNormal];
        [addBtn setTintColor:WKApp.shared.config.navBarButtonColor];
        [addBtn addTarget:self action:@selector(rightAddPressed) forControlEvents:UIControlEventTouchUpInside];

        // 水平排列：信号 | PC图标 | 加号，所有元素垂直居中
        CGFloat x = 0;
        self.signalContainerView.frame = CGRectMake(x, 0, 60, itemH);
        x += 60 + gap;

        self.pcOnlineBtn.frame = CGRectMake(x, (itemH - iconSize) / 2, iconSize, iconSize);
        x += iconSize + gap;

        addBtn.frame = CGRectMake(x, (itemH - 24) / 2, 24, 24);
        x += 24;

        _rightAddItem = [[UIView alloc] initWithFrame:CGRectMake(0, 0, x, itemH)];
        [_rightAddItem addSubview:self.signalContainerView];
        [_rightAddItem addSubview:self.pcOnlineBtn];
        [_rightAddItem addSubview:addBtn];

        [self updateSignalViewForStatus:[WKSDK shared].connectionManager.connectStatus];

        // 初始化时默认隐藏，等 API 轮询或 CMD 推送更新
        self.pcOnlineBtn.hidden = YES;

        // 动态排列
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
    CGFloat gap = 12.0f;
    CGFloat addBtnSize = 24.0f;
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
        addBtn.frame = CGRectMake(x, (itemH - addBtnSize) / 2, addBtnSize, addBtnSize);
        x += addBtnSize;
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
    WKConnectStatus status = [WKSDK shared].connectionManager.connectStatus;
    [self.connectLock lock];

    // 参考 Web 端：优先显示 Space 名称，状态通过右侧信号图标展示
    if (self.currentSpaceName && self.currentSpaceName.length > 0) {
        self._title = self.currentSpaceName;
    } else {
        self._title = [WKApp shared].config.appName;
    }

    [self setCustomTitle:self._title];

    // 更新折叠箭头位置（始终显示）
    if (self.spaceArrowView) {
        self.spaceArrowView.hidden = NO;
        UILabel *titleLabel = self.navigationBar.titleLabel;
        CGFloat arrowX = titleLabel.lim_left + titleLabel.lim_width + 4;
        CGFloat arrowY = titleLabel.lim_top + (titleLabel.lim_height - 12) / 2.0;
        self.spaceArrowView.frame = CGRectMake(arrowX, arrowY, 12, 12);
    }

    [self.connectLock unlock];
}

// 切换箭头方向（展开=向下，收起=向右）
- (void)setSpaceArrowExpanded:(BOOL)expanded {
    if (!self.spaceArrowView || self.spaceArrowView.hidden) return;
    NSString *imgName = expanded ? @"ArrowDown" : @"arrow_right";
    UIImage *img = [[WKApp shared] loadImage:imgName moduleID:@"WuKongLogin"];
    [UIView transitionWithView:self.spaceArrowView duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.spaceArrowView.image = img;
    } completion:nil];
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

        // 检查是否是当前Space
        if ([space.space_id isEqualToString:weakSelf.currentSpaceId]) {
            NSLog(@"ℹ️ 选中的是当前Space，无需切换");
            return;
        }

        weakSelf.currentSpaceName = space.name;
        weakSelf.currentSpaceId = space.space_id;

        // 清除分组缓存
        [[WKCategoryService shared] invalidateCache];

        // 先保存新的 Space ID（conversation/sync 会从 NSUserDefaults 读取）
        [[NSUserDefaults standardUserDefaults] setObject:space.space_id forKey:@"currentSpaceId"];
        [[NSUserDefaults standardUserDefaults] setObject:space.space_id forKey:@"WKLastLoadedSpaceId"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        // 清空 space_unread / space_last_message 缓存（新空间会重新同步）
        [[WKSpaceConversationCache shared] clearAll];

        // 更新标题
        [weakSelf refreshTitle];

        // 参考 Web/Android 端：清空本地会话数据后重新从服务器同步
        // 1. 清空 VM 数据和本地会话数据库
        [weakSelf.conversationListVM reset];
        [[WKConversationDB shared] deleteAllConversation];

        // 2. 先刷新 UI 显示空列表
        [weakSelf rebuildGroupDisplayAndReload];

        // 3. 通过 syncConversationProvider 重新同步会话（会带上新的 space_id）
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
                NSLog(@"✅ Space会话同步成功");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.conversationListVM loadConversationList:^{
                        // sync完成后记录当前空间的合法群聊白名单
                        [weakSelf.conversationListVM snapshotSyncedGroupIds];
                        [weakSelf rebuildGroupDisplayAndReload];
                        [weakSelf refreshBadge];
                        // 加载新空间的分组
                        [weakSelf loadCategories];
                    }];
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
    };

    [popupView showFromView:self.navigationBar.titleLabel];
}

/// 创建固定在顶部的搜索栏容器（不随 tableView 滚动）
-(void) setupFixedHeader {
    CGFloat navBottom = self.navigationBar.lim_bottom;
    _fixedHeaderContainer = [[UIView alloc] initWithFrame:CGRectMake(0, navBottom, WKScreenWidth, 0)];
    _fixedHeaderContainer.backgroundColor = [WKApp shared].config.backgroundColor;

    // 搜索栏（与原来 WKConversationListHeaderView 中的保持一致：左右 15pt 间距，圆角 4pt）
    WKSearchbarView *searchbar = [[WKSearchbarView alloc] initWithFrame:CGRectMake(15, 6, WKScreenWidth - 30, 36)];
    searchbar.placeholder = LLang(@"搜索");
    searchbar.layer.cornerRadius = 4.0f;
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
        _conversationTabView.frame = CGRectMake(0, y, WKScreenWidth, 36);
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
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
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
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
        
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
        if (_conversationListVM.filterType == WKConversationFilterGroup) {
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

    // 空间隔离：过滤掉不属于当前空间的会话更新
    NSArray<WKConversation*> *filtered = [self filterConversationsBySpace:conversations];
    // 过滤子区：子区不独立显示在会话列表，但触发父群子区数量刷新 + 消息计数更新
    NSMutableArray<WKConversation*> *nonThreadFiltered = [NSMutableArray array];
    NSMutableSet<NSString*> *refreshGroupNos = [NSMutableSet set];
    for (WKConversation *conv in filtered) {
        if (conv.channel.channelType == WK_COMMUNITY_TOPIC) {
            NSString *threadChannelId = conv.channel.channelId;
            NSRange range = [threadChannelId rangeOfString:@"____"];
            if (range.location != NSNotFound) {
                NSString *groupNo = [threadChannelId substringToIndex:range.location];
                [refreshGroupNos addObject:groupNo];
            }
        } else {
            [nonThreadFiltered addObject:conv];
        }
    }
    // 刷新受影响的父群子区数量
    if (refreshGroupNos.count > 0) {
        [self.conversationListVM refreshThreadCountForGroups:refreshGroupNos];
    }
    filtered = nonThreadFiltered;
    if(filtered.count <= 0) {
        return;
    }

    // 同步 WK_PERSON 的 space 未读缓存：通过 space 过滤的消息属于当前空间，需递增 space_unread
    for (WKConversation *conversation in filtered) {
        if (conversation.channel.channelType == WK_PERSON) {
            WKConversationWrapModel *existingModel = [self.conversationListVM modelAtChannel:conversation.channel];
            if (existingModel) {
                NSInteger oldSDKUnread = [existingModel getConversation].unreadCount;
                NSInteger newSDKUnread = conversation.unreadCount;
                NSInteger delta = newSDKUnread - oldSDKUnread;
                if (delta > 0) {
                    [[WKSpaceConversationCache shared] incrementSpaceUnread:delta forChannel:conversation.channel];
                }
            }
        }
    }

    if(filtered.count>1) {
        for (WKConversation *conversation in filtered) {
            [self onlyAddOrUpdateConversation:conversation];
        }
        [self refreshTable];
        [self refreshBadge];
        [self updateGroupMentionBadge];
        // 批量更新后补拉子区数据（网络恢复等场景）
        [self.conversationListVM fetchThreadCountsForGroups];
        return;
    }

   WKConversation *conversation = filtered[0];
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
                        if (_conversationListVM.filterType == WKConversationFilterGroup) {
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
                        if (_conversationListVM.filterType == WKConversationFilterGroup) {
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
            [filtered addObject:conversation];
        } else {
            // 群聊不在列表中：检查白名单决定是否允许添加
            if(conversation.channel.channelType == WK_GROUP) {
                if([self.conversationListVM isGroupInWhitelist:channelId]) {
                    // 群聊在白名单中（通过sync或创建时添加），允许通过
                    [filtered addObject:conversation];
                } else {
                    // 群聊不在白名单中，可能是被人拉入的新群聊
                    // 收集起来，循环结束后统一后台验证
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
    NSLog(@"[@mention] reminderDidChange channel=%@_%d, reminders.count=%lu", channel.channelId, channel.channelType, (unsigned long)reminders.count);
    // 群聊：直接更新 model 的 reminders
    WKConversationWrapModel *model = [self.conversationListVM modelAtChannel:channel];
    if (model) {
        WKConversation *conv = [model getConversation];
        conv.reminders = reminders;
        NSLog(@"[@mention] 已更新 model reminders, simpleReminders.count=%lu", (unsigned long)model.simpleReminders.count);
    }
    // 子区：reminder 变化也需要刷新（子区的@提醒显示在父群组的预览行上）
    [self rebuildGroupDisplayAndReload];
}

/// 子区数量批量更新完成后统一刷新整个列表（避免大量逐行更新导致 tableView 卡死）
-(void) onThreadCountBatchUpdated:(NSNotification*)notification {
    [self rebuildGroupDisplayAndReload];
}

// 单个会话添加或更新
-(void) uiAddOrUpdateConversationForOne:(WKConversation*)conversation {
    WKConversationWrapModel *newModel = [self.conversationListVM getRealShowConversationWrap:[[WKConversationWrapModel alloc] initWithConversation:conversation]];

    NSInteger oldIndex = [self.conversationListVM indexAtChannel:newModel.channel];
    if(oldIndex != -1) {
        // 已存在：替换数据并重新排序
        [self.conversationListVM replaceAtChannel:newModel atChannel:newModel.channel];
        [self.conversationListVM sortConversationList];

        // 群聊 tab 使用分组展示，index 不匹配 tableView，直接全量刷新
        if (_conversationListVM.filterType == WKConversationFilterGroup) {
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

    // 系统通知和文件助手是全局的，始终显示
    if([channelId isEqualToString:[WKApp shared].config.systemUID] ||
       [channelId isEqualToString:[WKApp shared].config.fileHelperUID]) {
        return YES;
    }

    // BotFather是全局的（已有space_id消息过滤）
    if([channelId isEqualToString:[WKApp shared].config.botfatherUID]) {
        return YES;
    }

    // 群聊：检查白名单确定是否属于当前空间
    if(conversation.channel.channelType == WK_GROUP) {
        return [self.conversationListVM isGroupInWhitelist:conversation.channel.channelId];
    }

    // 个人聊天：检查最后一条消息的 space_id 是否匹配当前空间
    if(conversation.lastMessage) {
        NSString *msgSpaceId = conversation.lastMessage.content.contentDict[@"space_id"];
        if([msgSpaceId isKindOfClass:[NSString class]] && [msgSpaceId isEqualToString:spaceId]) {
            return YES; // 消息明确属于当前空间
        }
        // 消息没有 space_id 标记
        if(!msgSpaceId || [msgSpaceId isEqual:[NSNull null]] || ([msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length == 0)) {
            // Bot 消息无 space_id 时不放行（避免跨空间泄漏）
            WKChannelInfo *chInfo = [[WKSDK shared].channelManager getChannelInfo:conversation.channel];
            if (chInfo && chInfo.robot) {
                return NO;
            }
            return YES; // 普通人聊天兼容旧消息
        }
        // 消息有 space_id 但不匹配当前空间
        return NO;
    }

    // 无最后一条消息，允许显示（如空会话）
    return YES;
}

-(void) uiAddConversation:(WKConversation*)conversation {
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
    if (countAfter == countBefore + 1 && _conversationListVM.filterType != WKConversationFilterGroup) {
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
    // 子区不独立显示在会话列表
    if(conversation.channel.channelType == WK_COMMUNITY_TOPIC) {
        return;
    }
    WKConversationWrapModel *model =  [self.conversationListVM modelAtChannel:conversation.channel];
    if(model) {
        [model setConversation:conversation];
    }else {
        // 有活跃空间时，不自动添加不属于当前空间的新会话
        NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
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
    NSInteger index = [self.conversationListVM indexAtChannel:channel];
    if(index == -1) {
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

    WKConversationWrapModel *model = [self.conversationListVM modelAtIndex:index];
    model.unreadCount = unreadCount;
    // 同步更新 space 未读缓存（清零或设置具体值）
    if (channel.channelType == WK_PERSON) {
        [[WKSpaceConversationCache shared] setSpaceUnread:@(unreadCount) spaceLastMessage:nil forChannel:channel];
    }
    // 群聊 tab 使用分组展示，index 不匹配 tableView 行号，直接全量刷新
    if (_conversationListVM.filterType == WKConversationFilterGroup) {
        [self rebuildGroupDisplayAndReload];
    } else {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
        if ([cell isKindOfClass:[WKConversationListCell class]]) {
            [(WKConversationListCell *)cell refreshWithModel:model];
            [cell layoutSubviews];
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
    _conversationTabView = [[WKConversationTabView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, 36)];
    _conversationTabView.selectedIndex = _conversationListVM.filterType;

    __weak typeof(self) weakSelf = self;
    _conversationTabView.onTabChanged = ^(NSInteger index) {
        weakSelf.conversationListVM.filterType = index;
        [weakSelf.conversationListVM rebuildFilteredList];
        [weakSelf rebuildGroupDisplayAndReload];
        [weakSelf updateTabUnreadCounts];
        [[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"WKConversationTabIndex"];
    };

    // 将 tabView 添加到固定头部容器（不随 tableView 滚动）
    [self.fixedHeaderContainer addSubview:_conversationTabView];
    [self layoutFixedHeader];
}

-(void) updateTabUnreadCounts {
    [self.conversationTabView setGroupUnreadCount:[self.conversationListVM getGroupUnreadCount]];
    [self.conversationTabView setPrivateUnreadCount:[self.conversationListVM getPrivateUnreadCount]];
}

-(void) refreshBadge {
    // 不再显示 tabbar 和 tab 未读红点
    self.tabBarItem.badgeValue = nil;
}

#pragma mark - WKNetworkListenerDelegate

- (void)networkListenerStatusChange:(WKNetworkListener *)listener {
     [self showNetworkError:!listener.hasNetwork];
}

#pragma mark - WKChannelManagerDelegate

-(void) channelInfoUpdate:(WKChannelInfo *)channelInfo oldChannelInfo:(WKChannelInfo *)oldChannelInfo{
   //[self refreshTable];
    NSInteger index = [self.conversationListVM indexAtChannel:channelInfo.channel];
    if(index!= -1) {
        WKConversationWrapModel *oldModel = [self.conversationListVM modelAtIndex:index];
        // 更新 model 中缓存的 channelInfo，避免使用过期数据
        oldModel.channelInfo = channelInfo;
        WKConversation *conversation = [[oldModel getConversation] copy];
        conversation.mute = channelInfo.mute;
        conversation.stick = channelInfo.stick;
        if([self hasChange:channelInfo oldChannelInfo:oldChannelInfo]) {
            [self uiAddOrUpdateConversationForOne:conversation];
        }else{
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
            
//            WKConversationListCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
//            if(cell) {
//                WKConversationWrapModel *model = [self.conversationListVM modelAtIndex:index];
//                [cell refreshWithModel:model];
//            }
        }
        [self resetHeaderBottomEmptyBackgroundColor];
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
    if (_conversationListVM.filterType == WKConversationFilterGroup && self.groupDisplayList) {
        if (indexPath.row >= (NSInteger)self.groupDisplayList.count) return 48.0f;
        WKConversationDisplayItem *item = self.groupDisplayList[indexPath.row];
        if (item.isSectionHeader) return 36.0f;
        WKConversationWrapModel *model = item.conversation;
        if (model && model.threadPreviews.count > 0 && [WKApp shared].remoteConfig.threadOn) {
            return [WKConversationGroupThreadCell heightForModel:model];
        }
        // 有 @我 提醒时需要更高的行来显示预览
        if (model && model.simpleReminders.count > 0) {
            for (WKReminder *r in model.simpleReminders) {
                if (r.type == WKReminderTypeMentionMe) return 58.0f;
            }
        }
        return 48.0f;
    }
    // 私聊 tab
    WKConversationWrapModel *model = [_conversationListVM conversationAtIndex:indexPath.row];
    return 88.0f;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if (_conversationListVM.filterType == WKConversationFilterGroup && self.groupDisplayList) {
        return self.groupDisplayList.count;
    }
    return [_conversationListVM conversationCount];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    // 群聊 tab：使用分组展示列表
    if (_conversationListVM.filterType == WKConversationFilterGroup && self.groupDisplayList) {
        if (indexPath.row >= (NSInteger)self.groupDisplayList.count) {
            return [tableView dequeueReusableCellWithIdentifier:@"WKConversationListCell" forIndexPath:indexPath];
        }
        WKConversationDisplayItem *item = self.groupDisplayList[indexPath.row];
        if (item.isSectionHeader) {
            WKCategorySectionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WKCategorySectionCell" forIndexPath:indexPath];
            return cell;
        }
        WKConversationWrapModel *model = item.conversation;
        if (model && model.threadPreviews.count > 0 && [WKApp shared].remoteConfig.threadOn) {
            WKConversationGroupThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WKConversationGroupThreadCell" forIndexPath:indexPath];
            cell.swipeDelegate = self;
            return cell;
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
    // 群聊 tab
    if (_conversationListVM.filterType == WKConversationFilterGroup && self.groupDisplayList) {
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
            sectionCell.onLongPress = ^(NSString *sectionId, NSString *title, CGPoint pointInWindow) {
                [weakSelf showSectionManagePopup:sectionId title:title atPoint:pointInWindow];
            };
            return;
        }
        WKConversationWrapModel *conversationModel = item.conversation;
        if (!conversationModel) return;
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
        } else if ([cell isKindOfClass:[WKConversationListCell class]]) {
            [(WKConversationListCell *)cell refreshWithModel:conversationModel];
        }
        // 群聊 tab 会话 cell 添加长按手势
        [self addLongPressGestureToCell:cell forConversation:conversationModel];
        return;
    }
    // 私聊 tab
    WKConversationWrapModel *conversationModel = [_conversationListVM conversationAtIndex:indexPath.row];
    if (!conversationModel) return;
    WKConversationListCell *conversationListCell = (WKConversationListCell *)cell;
    [conversationListCell refreshWithModel:conversationModel];
    // 私聊 tab 添加长按手势
    [self addLongPressGestureToCell:cell forConversation:conversationModel];
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    WKConversationWrapModel *conversationModel = [_conversationListVM conversationAtIndex:indexPath.row];
    if(conversationModel) {
        [conversationModel cancelChannelRequest];
    }
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // 群聊 tab: section header 不进入聊天
    if (_conversationListVM.filterType == WKConversationFilterGroup && self.groupDisplayList) {
        if (indexPath.row >= (NSInteger)self.groupDisplayList.count) return;
        WKConversationDisplayItem *item = self.groupDisplayList[indexPath.row];
        if (item.isSectionHeader) return;
    }

     WKConversationWrapModel *conversationModel;
    if (_conversationListVM.filterType == WKConversationFilterGroup && self.groupDisplayList) {
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

#pragma mark - 会话长按弹窗菜单

-(void) addLongPressGestureToCell:(UITableViewCell *)cell forConversation:(WKConversationWrapModel *)model {
    // 移除旧的长按手势，避免重用导致重复添加
    for (UIGestureRecognizer *g in cell.gestureRecognizers.copy) {
        if ([g isKindOfClass:[UILongPressGestureRecognizer class]] && g.view == cell) {
            [cell removeGestureRecognizer:g];
        }
    }
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onConversationCellLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [cell addGestureRecognizer:longPress];
    objc_setAssociatedObject(cell, "conversationModel", model, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(void) onConversationCellLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UITableViewCell *cell = (UITableViewCell *)gesture.view;
    WKConversationWrapModel *model = objc_getAssociatedObject(cell, "conversationModel");
    if (!model) return;

    // 触觉反馈
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];

    CGPoint ptInCell = [gesture locationInView:cell];
    CGPoint ptInWindow = [cell convertPoint:ptInCell toView:nil];
    [self showConversationMenuForModel:model atPoint:ptInWindow];
}

-(void) showConversationMenuForModel:(WKConversationWrapModel *)model atPoint:(CGPoint)point {
    __weak typeof(self) weakSelf = self;
    NSMutableArray<NSDictionary *> *menuItems = [NSMutableArray array];

    // 1. 关闭/打开通知
    NSString *muteTitle = model.mute ? LLang(@"打开通知") : LLang(@"关闭通知");
    [menuItems addObject:@{
        @"title": muteTitle,
        @"icon": [WKConversationListVC iconMute:model.mute],
        @"action": ^{
            [[WKChannelSettingManager shared] channel:model.channel mute:!model.mute];
        }
    }];

    // 2. 置顶/取消置顶
    NSString *stickTitle = model.stick ? LLang(@"取消置顶") : LLang(@"置顶");
    [menuItems addObject:@{
        @"title": stickTitle,
        @"icon": [WKConversationListVC iconStick],
        @"action": ^{
            [[WKChannelSettingManager shared] channel:model.channel stick:!model.stick];
        }
    }];

    // 3. 移动分组（仅群聊）
    if (model.channel.channelType == WK_GROUP) {
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

// 创建信号条图标
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
    // 例如：https://api-test.example.com/api/v1/ -> https://api-test.example.com/
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
    self.groupDisplayList = [_conversationListVM buildGroupDisplayList];
    NSLog(@"[ConvDebug] rebuildGroupDisplayAndReload: filterType=%ld, groupDisplayList=%lu, conversationCount=%ld, callStack=%@", (long)_conversationListVM.filterType, (unsigned long)self.groupDisplayList.count, (long)[_conversationListVM conversationCount], [[NSThread callStackSymbols] subarrayWithRange:NSMakeRange(1, MIN(5, [NSThread callStackSymbols].count - 1))]);
    [self.tableView reloadData];
    [self updateGroupMentionBadge];
}

/// 检查群聊和子区中是否有未处理的@提醒，更新 tab 标识
-(void) updateGroupMentionBadge {
    BOOL hasMention = NO;
    // 检查群聊（用全量列表，不受当前 tab 过滤影响）
    for (WKConversationWrapModel *model in [_conversationListVM allConversations]) {
        if (model.channel.channelType != WK_GROUP) continue;
        if (model.simpleReminders.count > 0) {
            for (WKReminder *r in model.simpleReminders) {
                if (r.type == WKReminderTypeMentionMe) { hasMention = YES; break; }
            }
        }
        if (hasMention) break;
    }
    // 检查子区（子区不在会话列表中，从 SDK 会话里查）
    // 仅检查当前空间内群聊对应的子区，子区 channelId 格式为 {groupNo}____{threadId}
    if (!hasMention) {
        // 收集当前空间内的群聊 channelId 作为白名单（用全量列表）
        NSMutableSet<NSString *> *spaceGroupIds = [NSMutableSet set];
        for (WKConversationWrapModel *model in [_conversationListVM allConversations]) {
            if (model.channel.channelType == WK_GROUP) {
                [spaceGroupIds addObject:model.channel.channelId];
            }
        }
        NSArray<WKConversation *> *allConvs = [[WKSDK shared].conversationManager getConversationList];
        for (WKConversation *conv in allConvs) {
            if (conv.channel.channelType != WK_COMMUNITY_TOPIC) continue;
            // 提取子区的 groupNo 前缀，检查是否属于当前空间
            NSRange sep = [conv.channel.channelId rangeOfString:@"____"];
            if (sep.location == NSNotFound) continue;
            NSString *groupNo = [conv.channel.channelId substringToIndex:sep.location];
            if (![spaceGroupIds containsObject:groupNo]) continue;
            NSArray<WKReminder *> *reminders = [[WKReminderDB shared] getWaitDoneReminder:conv.channel];
            for (WKReminder *r in reminders) {
                if (r.type == WKReminderTypeMentionMe) { hasMention = YES; break; }
            }
            if (hasMention) break;
        }
    }
    [_conversationTabView setGroupHasMention:hasMention];
}

-(void) showCreateCategoryDialog {
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
        }).catch(^(NSError *error) {
            NSLog(@"创建分组失败: %@", error);
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void) showMoveToCategoryDialog:(NSString *)groupNo {
    NSArray<WKCategoryEntity *> *categories = _conversationListVM.categoryList;

    // 获取群组名称
    WKChannelInfo *groupInfo = [[WKSDK shared].channelManager getChannelInfo:[WKChannel groupWithChannelID:groupNo]];
    NSString *groupName = groupInfo ? groupInfo.displayName : groupNo;
    NSString *titleText = [NSString stringWithFormat:@"%@ \"%@\"", LLang(@"移动"), groupName];

    // 找到当前群聊所在分组
    NSString *currentCategoryId = nil;
    for (WKCategoryEntity *cat in categories) {
        if(!cat.category_id || cat.category_id.length == 0) continue;
        for (WKCategoryGroup *cg in cat.groups) {
            if([groupNo isEqualToString:cg.group_no]) {
                currentCategoryId = cat.category_id;
                break;
            }
        }
        if(currentCategoryId) break;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:titleText message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;

    // 默认分组选项
    BOOL isInDefault = (currentCategoryId == nil);
    NSString *defaultTitle = isInDefault ? [NSString stringWithFormat:@"✓ %@", LLang(@"不分组")] : LLang(@"不分组");
    [alert addAction:[UIAlertAction actionWithTitle:defaultTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        if(isInDefault) return;
        [[WKCategoryService shared] moveGroup:groupNo toCategoryId:nil].then(^(id r) {
            [weakSelf loadCategories];
        }).catch(^(NSError *e) { NSLog(@"移动分组失败: %@", e); });
    }]];

    // 各用户自建分组
    for (WKCategoryEntity *cat in categories) {
        if(!cat.category_id || cat.category_id.length == 0) continue;
        BOOL isCurrent = [cat.category_id isEqualToString:currentCategoryId];
        NSString *title = isCurrent ? [NSString stringWithFormat:@"✓ %@", cat.name] : cat.name;
        NSString *catId = cat.category_id;
        [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            if(isCurrent) return;
            [[WKCategoryService shared] moveGroup:groupNo toCategoryId:catId].then(^(id r) {
                [weakSelf loadCategories];
            }).catch(^(NSError *e) { NSLog(@"移动分组失败: %@", e); });
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
        [WKAlertUtil alert:LLang(@"删除后该分组内的群聊将不再归属任何分组，确定要删除？") buttonsStatement:@[LLang(@"取消"), LLang(@"删除")] chooseBlock:^(NSInteger buttonIdx) {
            if(buttonIdx == 1) {
                [[WKCategoryService shared] deleteCategory:spaceId categoryId:sectionId].then(^(id r) {
                    [weakSelf loadCategories];
                }).catch(^(NSError *e) { NSLog(@"删除分组失败: %@", e); });
            }
        }];
    } copy]}];

    // 创建悬浮菜单
    [self showFloatingMenu:menuItems atPoint:point];
}

/// 在指定位置显示悬浮菜单（带阴影、圆角、三角箭头）
-(void) showFloatingMenu:(NSArray<NSDictionary *> *)menuItems atPoint:(CGPoint)point {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if(!window) window = [UIApplication sharedApplication].windows.firstObject;

    // 半透明遮罩
    UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.15];
    overlay.alpha = 0;
    overlay.tag = 77700;
    [window addSubview:overlay];

    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissFloatingMenu)];
    [overlay addGestureRecognizer:dismissTap];

    // 菜单容器
    CGFloat menuWidth = 160;
    CGFloat rowHeight = 44;
    CGFloat menuHeight = menuItems.count * rowHeight;
    CGFloat cornerRadius = 12;

    UIView *menuContainer = [[UIView alloc] init];
    menuContainer.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    menuContainer.layer.cornerRadius = cornerRadius;
    menuContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    menuContainer.layer.shadowOpacity = 0.15;
    menuContainer.layer.shadowOffset = CGSizeMake(0, 4);
    menuContainer.layer.shadowRadius = 12;
    menuContainer.tag = 77701;

    // 计算位置：在手指上方显示，如果空间不够则显示在下方
    BOOL showAbove = (point.y - menuHeight - 12 > 60);
    CGFloat menuX = point.x - menuWidth / 2.0;
    if (menuX < 10) menuX = 10;
    if (menuX + menuWidth > window.lim_width - 10) menuX = window.lim_width - menuWidth - 10;
    CGFloat menuY = showAbove ? (point.y - menuHeight - 10) : (point.y + 10);

    menuContainer.frame = CGRectMake(menuX, menuY, menuWidth, menuHeight);

    // 菜单行
    for (NSInteger i = 0; i < (NSInteger)menuItems.count; i++) {
        NSDictionary *item = menuItems[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(0, i * rowHeight, menuWidth, rowHeight);
        btn.tag = 77710 + i;
        btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
        btn.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);

        [btn setTitle:item[@"title"] forState:UIControlStateNormal];
        UIImage *icon = item[@"icon"];
        if (icon) {
            [btn setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        }

        BOOL isDestructive = [item[@"isDestructive"] boolValue];
        btn.tintColor = isDestructive ? [UIColor redColor] : [WKApp shared].config.defaultTextColor;
        [btn setTitleColor:btn.tintColor forState:UIControlStateNormal];
        btn.titleLabel.font = [[WKApp shared].config appFontOfSize:15.0f];

        [btn addTarget:self action:@selector(floatingMenuItemTapped:) forControlEvents:UIControlEventTouchUpInside];
        [menuContainer addSubview:btn];

        // 分隔线（非最后一行）
        if (i < (NSInteger)menuItems.count - 1) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(16, (i + 1) * rowHeight - 0.5, menuWidth - 32, 0.5)];
            sep.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.15];
            [menuContainer addSubview:sep];
        }
    }

    // 保存 actions
    objc_setAssociatedObject(overlay, "menuActions", menuItems, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [overlay addSubview:menuContainer];

    // 弹出动画
    menuContainer.transform = CGAffineTransformMakeScale(0.8, 0.8);
    menuContainer.alpha = 0;
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        overlay.alpha = 1;
        menuContainer.transform = CGAffineTransformIdentity;
        menuContainer.alpha = 1;
    } completion:nil];
}

-(void) floatingMenuItemTapped:(UIButton *)btn {
    NSInteger index = btn.tag - 77710;
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIView *overlay = [window viewWithTag:77700];
    NSArray *menuItems = objc_getAssociatedObject(overlay, "menuActions");

    [self dismissFloatingMenu];

    if (index >= 0 && index < (NSInteger)menuItems.count) {
        void(^action)(void) = menuItems[index][@"action"];
        if (action) action();
    }
}

-(void) dismissFloatingMenu {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIView *overlay = [window viewWithTag:77700];
    if (!overlay) return;
    [UIView animateWithDuration:0.15 animations:^{
        overlay.alpha = 0;
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
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

@end
