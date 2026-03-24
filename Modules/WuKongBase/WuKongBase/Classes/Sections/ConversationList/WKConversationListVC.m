//
//  WKConversationListVC.m
//  WuKongBase
//
//  Created by tt on 2019/12/15.
//

#import "WKConversationListVC.h"
#import "WKConversationListVM.h"
#import "WKConversationListCell.h"
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
#import "WKOnlineStatusManager.h"
#import "WKMD5Util.h"
#import "WKSpaceModel.h"
#import "WKSpacePopupView.h"
#import "WKSyncService.h"
@interface WKConversationListVC ()<UITableViewDelegate,UITableViewDataSource,UISearchControllerDelegate,WKConnectionManagerDelegate,WKChannelManagerDelegate,WKConversationManagerDelegate,WKNetworkListenerDelegate,WKChatManagerDelegate,WKTypingManagerDelegate,SwipeTableViewCellDelegate,WKOnlineStatusManagerDelegate>
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

// 网络信号监控
@property(nonatomic,assign) NSTimeInterval connectedAtTime; // 连接成功的时间
@property(nonatomic,assign) NSInteger currentLatencyMs; // 当前延迟（毫秒）
@property(nonatomic,strong) NSTimer *pingTimer; // ping定时器
@property(nonatomic,strong) UIView *signalContainerView; // 信号显示容器
@property(nonatomic,strong) UIImageView *signalImageView; // 信号图标
@property(nonatomic,strong) UILabel *latencyLabel; // 延迟标签

// Space 切换
@property(nonatomic,copy) NSString *currentSpaceName; // 当前 Space 名称
@property(nonatomic,copy) NSString *currentSpaceId; // 当前 Space ID
@property(nonatomic,assign) BOOL spaceListLoaded; // Space列表是否已加载
@property(nonatomic,assign) NSInteger spaceCount; // Space总数
@property(nonatomic,strong) UIImageView *spaceArrowView; // Space标题右侧折叠箭头
@property(nonatomic,strong) NSMutableSet<NSString*> *spaceChannelKeys; // Space 会话白名单（channelId_channelType）

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

    [self.view addSubview:self.tableView];
    self.connectLock = [[NSLock alloc] init];
    self.conversationLock = [[NSRecursiveLock alloc] init];
    [self addDelegates];

    // 加载当前 Space 信息
    [self loadCurrentSpace];

    // 加载最近会话列表数据
    __weak __typeof(self) weakSelf  = self;
    [_conversationListVM loadConversationList:^{
        if([weakSelf.conversationListVM hasConversationTop]) {
            [weakSelf.tableHeader.tableHeaderBottomEmptyView setBackgroundColor:[WKApp shared].config.backgroundColor];
        }else {
            [weakSelf.tableHeader.tableHeaderBottomEmptyView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        }
        [weakSelf.tableView reloadData];
        [weakSelf refreshBadge];
        // 初始加载后建立 Space 白名单
        [weakSelf rebuildSpaceChannelKeys];
    }];

//    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(timerRefreshTable) userInfo:nil repeats:YES];
//
    self.tableHeader.pcDeviceFlag = [WKOnlineStatusManager shared].pcDeviceFlag;
    self.tableHeader.showPCOnline = [WKOnlineStatusManager shared].pcOnline;

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

    // 检测空间是否发生变化（切换服务器或切换空间后重启 App）
    NSString *lastSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"WKLastLoadedSpaceId"];
    if (self.currentSpaceId && self.currentSpaceId.length > 0) {
        if (!lastSpaceId || ![lastSpaceId isEqualToString:self.currentSpaceId]) {
            // 空间变化，清空旧会话数据，等待新的同步数据
            NSLog(@"🔄 Space 变化: %@ -> %@，清空旧会话", lastSpaceId, self.currentSpaceId);
            [self.conversationListVM reset];
            [[WKConversationDB shared] deleteAllConversation];
            self.spaceChannelKeys = nil; // 清空白名单，等待新 sync 重建
            [self.tableView reloadData];
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
    [self refreshTableNoSort];
    [self hiddenRightItem:NO];
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
}

-(void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if(self.refreshTimer) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }

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
}

-(void) removeDelegates {
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
}

-(UIView*) rightAddItem {
    if (!_rightAddItem) {
        // 创建容器视图，宽度增加以容纳信号显示
        _rightAddItem = [[UIView alloc] initWithFrame:CGRectMake(0.0f , 0.0f, 120.0f, 32.0f)];

        // 添加信号显示容器（参考 Web 端：始终显示）
        self.signalContainerView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 5.0f, 68.0f, 22.0f)];
        self.signalContainerView.hidden = NO; // 始终显示，不隐藏

        // 创建点击手势
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(signalTapped)];
        [self.signalContainerView addGestureRecognizer:tapGesture];
        self.signalContainerView.userInteractionEnabled = YES;

        // 信号图标
        self.signalImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 4.0f, 16.0f, 14.0f)];
        self.signalImageView.image = [self createSignalBarsImage];
        [self.signalContainerView addSubview:self.signalImageView];

        // 延迟标签
        self.latencyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 0.0f, 48.0f, 22.0f)];
        self.latencyLabel.font = [UIFont systemFontOfSize:11.0f];
        self.latencyLabel.textAlignment = NSTextAlignmentLeft;
        [self.signalContainerView addSubview:self.latencyLabel];

        [_rightAddItem addSubview:self.signalContainerView];

        // 添加按钮（调整位置以在信号显示右侧）
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button addTarget:self action:@selector(rightAddPressed) forControlEvents:UIControlEventTouchUpInside];
        button.frame = CGRectMake(88.0f , 5.0f, 32.0f, 32.0f);
        UIImage *img = [self imageName:@"ConversationList/Index/Add"];
        img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [button setImage:img forState:UIControlStateNormal];
        [button setBackgroundColor:[UIColor clearColor]];
        [button setTintColor:WKApp.shared.config.navBarButtonColor];
        [_rightAddItem addSubview:button];

        // 初始化时立即更新信号显示
        [self updateSignalViewForStatus:[WKSDK shared].connectionManager.connectStatus];
    }
    return _rightAddItem;
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

        // 先保存新的 Space ID（conversation/sync 会从 NSUserDefaults 读取）
        [[NSUserDefaults standardUserDefaults] setObject:space.space_id forKey:@"currentSpaceId"];
        [[NSUserDefaults standardUserDefaults] setObject:space.space_id forKey:@"WKLastLoadedSpaceId"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        // 更新标题
        [weakSelf refreshTitle];

        // 参考 Web/Android 端：清空本地会话数据后重新从服务器同步
        // 1. 清空 VM 数据、本地会话数据库和 Space 白名单
        [weakSelf.conversationListVM reset];
        [[WKConversationDB shared] deleteAllConversation];
        weakSelf.spaceChannelKeys = nil; // 清空白名单，sync 期间不过滤

        // 2. 先刷新 UI 显示空列表
        [weakSelf.tableView reloadData];

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
                        [weakSelf.tableView reloadData];
                        [weakSelf refreshBadge];
                        // Sync 完成后重建 Space 白名单
                        [weakSelf rebuildSpaceChannelKeys];
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
        _tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
        _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(-0.1f, 0.0f, 0.0f, 0.0f);
        _tableView.tableFooterView = [[UIView alloc] init];
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.sectionHeaderHeight = 0.0f;
        _tableView.sectionFooterHeight = 0.0f;
        
        _tableView.tableHeaderView = self.tableHeader;
        
        [_tableView registerClass:[WKConversationListCell class] forCellReuseIdentifier:@"WKConversationListCell"];
    }
    return _tableView;
}


#define networkErrorViewHeight 50.0f
-(WKConversationListHeaderView*) tableHeader {
    if(!_tableHeader) {
        _tableHeader = [[WKConversationListHeaderView alloc] init];
        _tableHeader.showPCOnline = [WKOnlineStatusManager shared].pcOnline;
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
    [self.tableView reloadData];
     
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
    
    self.tableHeader.pcDeviceFlag = status.deviceFlag;
    self.tableHeader.showPCOnline = status.online;
    
    [self.tableView reloadData];
    
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
        WKConversationListCell *cell =  [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
        [cell refreshWithModel:conversation];
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
        // 连接成功，重新加载 Space 信息
        [self loadCurrentSpace];

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

    // Space 推送过滤：当 currentSpaceId 已设置且白名单已建立时，
    // 只处理属于当前 Space 的会话，过滤掉其他 Space 的推送
    NSArray<WKConversation*> *filteredConversations = conversations;
    if (self.currentSpaceId && self.currentSpaceId.length > 0 && self.spaceChannelKeys) {
        NSMutableArray *filtered = [NSMutableArray array];
        for (WKConversation *conv in conversations) {
            NSString *key = [self channelKeyForChannel:conv.channel];
            if ([self.spaceChannelKeys containsObject:key]) {
                [filtered addObject:conv];
            }
        }
        filteredConversations = filtered;
        if (filteredConversations.count == 0) {
            return;
        }
    }

    if(filteredConversations.count>1) { // 同时更新的会话大于1 则直接reloadData,等于1 则可以走insertRowsAtIndexPaths或moveRowAtIndexPath这样有动画效果 用户体验好
        for (WKConversation *conversation in filteredConversations) {
            [self onlyAddOrUpdateConversation:conversation];
        }
        [self refreshTable];
        [self refreshBadge];
        return;
    }
   
   WKConversation *conversation = filteredConversations[0];
    [self uiAddOrUpdateConversationForOne:conversation];
    [self refreshBadge];
    
}
// 单个会话添加或更新(大量会话不要使用此方法，容易卡顿)
-(void) uiAddOrUpdateConversationForOne:(WKConversation*)conversation {
    WKConversationWrapModel *newModel = [self.conversationListVM getRealShowConversationWrap:[[WKConversationWrapModel alloc] initWithConversation:conversation]];
    
    NSInteger oldIndex =[self.conversationListVM indexAtChannel:newModel.channel];
    if(oldIndex!=-1) {
        
        NSInteger insertPlace =  [self.conversationListVM findInsertPlace:newModel];
        if(oldIndex==insertPlace) {
            [self.conversationListVM replaceAtChannel:newModel atChannel:newModel.channel];
            WKConversationListCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:oldIndex inSection:0]];
            if(cell) {
                [cell refreshWithModel:newModel];
            }
            return;
        }
        
        if(oldIndex>self.conversationListVM.conversationCount || insertPlace>self.conversationListVM.conversationCount) {
            return;
        }
       
        [self.conversationListVM removeAtIndex:oldIndex];
        [self.conversationListVM insert:newModel atIndex:insertPlace];
        @try {
            [self.tableView beginUpdates];
            [self.tableView moveRowAtIndexPath:[NSIndexPath indexPathForRow:oldIndex inSection:0] toIndexPath:[NSIndexPath indexPathForRow:insertPlace inSection:0]];
            [self.tableView endUpdates];
        } @catch (NSException *exception) { // moveRowAtIndexPath 有时会引起异常。原因还没找到
            WKLogError(@"moveRowAtIndexPath is error -> %@",exception);
            [self.tableView reloadData];
        }
       
        WKConversationListCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:insertPlace inSection:0]];
        if(cell) {
            [cell refreshWithModel:newModel];
        }
        
        
    }else {
        [self uiAddConversation:conversation];
    }
}


-(void) uiAddConversation:(WKConversation*)conversation {
    WKConversationWrapModel *model = [[WKConversationWrapModel alloc] initWithConversation:conversation];
    NSInteger insertPlace = [self.conversationListVM insert:model];
    [self.tableView insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:insertPlace inSection:0] ] withRowAnimation:UITableViewRowAnimationFade];
}
// 删除最近会话
- (void)onConversationDelete:(WKChannel *)channel {
    [self.conversationListVM removeAtChannnel:channel];
    [self refreshTable];
    [self refreshBadge];
}

-(void) onlyAddOrUpdateConversation:(WKConversation*)conversation {
    WKConversationWrapModel *model =  [self.conversationListVM modelAtChannel:conversation.channel];
    if(model) {
        [model setConversation:conversation];
    }else {
        [self.conversationListVM insert:[[WKConversationWrapModel alloc] initWithConversation:conversation] atIndex:0];
    }
}
// 更新最近会话未读数
- (void)onConversationUnreadCountUpdate:(WKChannel*)channel unreadCount:(NSInteger)unreadCount {
    
    NSInteger index = [self.conversationListVM indexAtChannel:channel];
    if(index!=-1) {
        WKConversationListCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
        if(cell) {
           WKConversationWrapModel *model = [self.conversationListVM modelAtIndex:index];
            model.unreadCount = unreadCount;
            [cell refreshWithModel:model];
            [cell layoutSubviews];
            [self refreshBadge];
        }
       
    }
}
// 删除所有最近会话
- (void)onConversationAllDelete {
    [self.conversationListVM removeAll];
    [self refreshTable];
    [self refreshBadge];
}


-(void) refreshBadge {
    NSInteger unreadCount = [self.conversationListVM getAllUnreadCount];
    if(unreadCount>0) {
        self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%ld",(long)unreadCount];
    }else {
        self.tabBarItem.badgeValue = nil;
    }
    
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

    return 88.0f;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    
    return [_conversationListVM conversationCount];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    WKConversationListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WKConversationListCell" forIndexPath:indexPath];
    cell.swipeDelegate = self;
    
//    [cell setDisplaySeparator:YES];
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    WKConversationListCell *conversationListCell = (WKConversationListCell*)cell;
    WKConversationWrapModel *conversationModel = [_conversationListVM conversationAtIndex:indexPath.row];
    if(conversationModel) {
        [conversationListCell refreshWithModel:conversationModel];
    }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    WKConversationWrapModel *conversationModel = [_conversationListVM conversationAtIndex:indexPath.row];
    if(conversationModel) {
        [conversationModel cancelChannelRequest];
    }
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
     WKConversationWrapModel *conversationModel = [_conversationListVM conversationAtIndex:indexPath.row];
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

    WKConversationWrapModel *conversationModel = [self.conversationListVM conversationAtIndex:indexPath.row];
    
    // ---------- 免打扰 ----------
    NSString *muteTitle;
    NSString *muteAnimationNamed;
    if(conversationModel.mute) {
        muteTitle = LLang(@"打开通知");
        muteAnimationNamed = @"Other/list_icon_sound_on";
    }else {
        muteTitle = LLang(@"关闭通知");
        muteAnimationNamed = @"Other/list_icon_sound_off";
    }
    
    SwipeButton *muteBtn = [self swipeButton:muteTitle backgroundColor:[UIColor colorWithRed:252.0f/255.0f green:174.0f/255.0f blue:66.0f/255.0f alpha:1.0f] animationNamed:muteAnimationNamed touchBlock:^{
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[WKChannelSettingManager shared] channel:conversationModel.channel mute:!conversationModel.mute];
        });
    }];
    
    // ---------- 置顶 ----------
    NSString *stickTitle;
    NSString *stickAnimationNamed;
    if(conversationModel.stick) {
        stickTitle = LLang(@"取消置顶");
        stickAnimationNamed = @"Other/list_icon_toppin";
    }else {
        stickTitle = LLang(@"置顶");
        stickAnimationNamed = @"Other/list_icon_toppin";
    }
    
    SwipeButton *stickBtn = [self swipeButton:stickTitle backgroundColor:[UIColor colorWithRed:37.0f/255.0f green:167.0f/255.0f blue:90.0f/255.0f alpha:1.0f] animationNamed:stickAnimationNamed touchBlock:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[WKChannelSettingManager shared] channel:conversationModel.channel stick:!conversationModel.stick];
        });
    }];
    
    // ---------- 删除 ----------
    
    __weak typeof(self) weakSelf =  self;
    SwipeButton *deleteBtn = [self swipeButton:LLang(@"删除") backgroundColor:[UIColor redColor] animationNamed:@"Other/list_icon_delete" touchBlock:^{
        WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:nil];
        [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"清空聊天记录") onClick:^{
            WKConversationWrapModel *conversationModel = [weakSelf.conversationListVM conversationAtIndex:indexPath.row];
            [[WKMessageManager shared] clearMessages:conversationModel.channel];
        }]];
        [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"确认删除") onClick:^{
            WKConversationWrapModel *conversationModel = [weakSelf.conversationListVM conversationAtIndex:indexPath.row];
            [weakSelf.conversationListVM removeConversationAtIndex:indexPath.row];
            [weakSelf.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            if(conversationModel) {
                [[WKSDK shared].conversationManager deleteConversation:conversationModel.channel];
            }
        }]];
        [sheet show];
    }];
    
    
    
    return @[deleteBtn,stickBtn,muteBtn];
}

- (NSArray<SwipeButton *> *)tableView:(UITableView *)tableView leftSwipeButtonsAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

-(SwipeButton*) swipeButton:(NSString*)title backgroundColor:(UIColor*)backgroundColor animationNamed:(NSString*)animationNamed touchBlock:(void(^)(void))touchBlock {
    SwipeButton *spBtn = [SwipeButton createSwipeButtonWithTitle:title font:14.0f textColor:[UIColor whiteColor] backgroundColor:backgroundColor image:[self imageName:@"ConversationList/Index/PlaceHo"] touchBlock:touchBlock];
    
    LOTAnimationView *spAnimationView = [LOTAnimationView animationNamed:animationNamed inBundle:[WKApp.shared resourceBundle:@"WuKongBase"]];
    spAnimationView.loopAnimation = NO;
    spAnimationView.contentMode = UIViewContentModeScaleAspectFit;
    [spBtn.imageView addSubview:spAnimationView];
    [spAnimationView play];
    
    return spBtn;
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
    [self.tableView reloadData];
}

-(void) refreshTable {
    [self.conversationListVM sortConversationList];
    [self refreshHeader];
    [self.tableView reloadData];
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

#pragma mark - Space 推送过滤

/// 生成会话的 channel key（格式：channelId_channelType）
- (NSString *)channelKeyForChannel:(WKChannel *)channel {
    return [NSString stringWithFormat:@"%@_%hhu", channel.channelId, channel.channelType];
}

/// 从当前 VM 会话列表重建 Space 白名单
/// 调用时机：loadConversationList 完成后（sync 结果已入库）
- (void)rebuildSpaceChannelKeys {
    if (!self.currentSpaceId || self.currentSpaceId.length == 0) {
        // 无 Space 模式，不过滤
        self.spaceChannelKeys = nil;
        return;
    }
    NSMutableSet *keys = [NSMutableSet set];
    for (WKConversationWrapModel *model in [self.conversationListVM conversationList]) {
        [keys addObject:[self channelKeyForChannel:model.channel]];
    }
    self.spaceChannelKeys = keys;
    NSLog(@"🔑 Space 白名单重建: %lu 个会话", (unsigned long)keys.count);
}

-(void) dealloc {
    NSLog(@"WKConversationListVC dealloc ....");
    [self removeDelegates];
    [self stopPingMonitoring];
}

@end
