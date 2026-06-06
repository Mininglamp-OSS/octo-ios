//
//  WKContactsVC.m
//  WuKongContacts
//
//  Created by tt on 2019/12/7.
//

#import "WKContactsVC.h"
#import "WKContactsCell.h"
#import "WKContactFollowHelper.h"
#import <Masonry/Masonry.h>
#import "WKChineseSort.h"
#import "WKContactsHeaderItemCell.h"
#import "WKContactsManager.h"
#import "WKContactsSync.h"
#import "WKAvatarUtil.h"
#import "WKSearchbarView.h"
#import "WKGlobalSearchResultController.h"
#import <WuKongBase/WKFollowedKeysStore.h>

@interface WKContactsVC ()<UITableViewDataSource,UITableViewDelegate,WKContactsManagerDelegate,WKChannelManagerDelegate>
@property(nonatomic,strong) UITableView *tableView;
@property(nonatomic,strong) NSMutableArray *sectionTitleArr; //排序后的出现过的拼音首字母数组
@property(nonatomic,strong) NSMutableArray<NSMutableArray*> *items;
@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,strong) WKSearchbarView *searchbarView;
@property(nonatomic,strong) UIView *tableHeader;
// 顶部固定栏（搜索 + 全部/AI/人类 tab），不随 tableView 滚动
@property(nonatomic,strong) UIView *topStickyView;
@property(nonatomic,strong) UIView *filterTabContainer; // tab 区子容器，filter 切换时只重建它的 subview

@property(nonatomic,strong) UILabel *contactsCountLbl; // 联系人数量

@property(nonatomic,strong) UILabel *sectionIndexIndicator; // 右侧索引字母指示器

@property(nonatomic,copy) NSString *currentContactsFingerprint; // 当前显示的联系人数据指纹

// 联系人过滤
@property(nonatomic,assign) NSInteger contactsFilter; // 0=全部 1=AI 2=人类
@property(nonatomic,strong) NSArray<WKChannelInfo*> *allContactInfos; // 完整联系人列表
@property(nonatomic,assign) NSInteger groupCount; // 群聊数量
@property(nonatomic,assign) NSInteger myBotCount; // 已添加AI数量（仅 space/members 中的 bot）
@property(nonatomic,assign) BOOL isUpdating;     // 整个更新管道是否在执行中（含API请求+对比+刷新）
@property(nonatomic,assign) BOOL dataLoaded;     // 数据是否已加载过
@property(nonatomic,assign) BOOL isBatchUpdating; // 批量写DB期间，屏蔽逐条通知
@property(nonatomic,assign) NSTimeInterval lastLoadTime; // 上次加载完成时间
@property(nonatomic,assign) NSInteger sortGeneration; // 排序序号，防止异步回调错乱
@property(nonatomic,copy) NSString *lastSpaceId;  // 上次加载的空间ID，用于检测空间切换
@property(nonatomic,strong) NSSet<NSString*> *lastHumanUids; // 上一次的人类 uid 快照（用于对比）
@property(nonatomic,assign) NSInteger lastHumanCount; // 上一次的人类数量

@end

@implementation WKContactsVC

-(instancetype) init {
    self = [super init];
    if(self) {
        [[WKContactsManager shared] addDelegate:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshTaBarItemBadgeValue) name:WK_NOTIFY_CONTACTS_TAB_REDDOT_UPDATE object:nil];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.items = [NSMutableArray array];

    self.navigationBar.title = LLang(@"联系人");

    [[WKSDK shared].channelManager addDelegate:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contactsUpdate:) name:WK_NOTIFY_CONTACTS_UPDATE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshContactsHeader) name:WK_NOTIFY_CONTACTS_HEADER_UPDATE object:nil];
    // FollowedKeysStore 任何 reload 都广播这个通知（关注/取消关注后由 helper 触发 reload）
    // → 重画可见 cell 的金色五角星。
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFollowedKeysUpdate) name:kWKFollowedKeysStoreDidUpdateNotification object:nil];

    // 长按 cell → 弹"关注 / 取消关注"菜单。挂在 tableView 而不是 cell 上，
    // 这样 cell reuse 不会重复挂 gesture。
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onContactLongPress:)];
    lp.minimumPressDuration = 0.4;
    [self.tableView addGestureRecognizer:lp];

    // 先从DB缓存加载旧数据显示，再异步拉取API最新数据
    [self loadFromDBCacheThenFetchAPI];
}

// 加载：先读DB缓存立即显示，再异步拉取API最新数据（首次启动和空间切换都会调用）
-(void) loadFromDBCacheThenFetchAPI {
    // 记录当前空间ID
    self.lastSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"] ?: @"";

    // 1. 立即构建 header section
    NSArray *headerItems = [self buildHeaderItemsWithCounts];
    if (self.items.count == 0) {
        [self.items insertObject:[NSMutableArray arrayWithArray:headerItems] atIndex:0];
    } else {
        // 空间切换时 items 可能有旧数据，重置为只有 header
        NSMutableArray *newItems = [NSMutableArray array];
        [newItems addObject:[NSMutableArray arrayWithArray:headerItems]];
        self.items = newItems;
        self.sectionTitleArr = [NSMutableArray array];
    }
    [self.tableView reloadData];

    // 2. 后台线程读取DB缓存
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<WKChannelInfo*> *cachedInfos = [[WKChannelInfoDB shared]
            queryChannelInfosWithStatusAndFollow:WKChannelStatusNormal
                                         follow:WKChannelInfoFollowFriend];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!weakSelf) return;
            if (cachedInfos && cachedInfos.count > 0) {
                // 有缓存数据，先显示（首次加载允许全量reloadData，因为表是空的）
                weakSelf.allContactInfos = cachedInfos;
                [weakSelf logContactsCounts:@"SET(dbCache)"];
                [weakSelf rebuildTableData];
            }
            weakSelf.dataLoaded = YES;

            // 3. 缓存显示完成后，异步拉取API最新数据
            [weakSelf requestData];
        });
    });
}

- (void)viewWillAppear:(BOOL)animated {
    CFAbsoluteTime _vwaStart = CFAbsoluteTimeGetCurrent();
    [super viewWillAppear:animated];
    self.navigationBar.title = LLang(@"联系人");

    // 检测空间切换：spaceId 变化后清除旧数据，强制重新加载
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"] ?: @"";
    NSString *lastSpace = self.lastSpaceId ?: @"";
    if (![currentSpaceId isEqualToString:lastSpace]) {
        // 空间切换了，清除旧数据并强制重新加载
        self.lastSpaceId = currentSpaceId;
        self.allContactInfos = nil;
        [self logContactsCounts:@"SET(spaceSwitch=nil)"];
        self.currentContactsFingerprint = nil;
        self.groupCount = 0;
        self.myBotCount = 0;
        self.lastLoadTime = 0;
        self.isUpdating = NO;
        [self loadFromDBCacheThenFetchAPI];
        NSLog(@"[TabPerf] ContactsVC.viewWillAppear SPACE_SWITCH %.1fms", (CFAbsoluteTimeGetCurrent() - _vwaStart) * 1000);
        return;
    }

    // 后台静默同步（节流：5秒内不重复请求，避免频繁切 tab 触发不必要的 API 调用和 reloadData）
    if (self.dataLoaded) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (now - self.lastLoadTime >= 5) {
            self.lastLoadTime = now;
            // 延迟到动画结束后再请求，避免 API 回调在动画期间触发 reloadData
            id<UIViewControllerTransitionCoordinator> coordinator = self.transitionCoordinator;
            if (coordinator) {
                __weak typeof(self) weakSelf = self;
                [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
                    if (!context.isCancelled) {
                        [weakSelf requestData];
                    }
                }];
            } else {
                [self requestData];
            }
        }
    }
    NSLog(@"[TabPerf] ContactsVC.viewWillAppear %.1fms dataLoaded=%d", (CFAbsoluteTimeGetCurrent() - _vwaStart) * 1000, self.dataLoaded);
}



- (void)dealloc {
    NSLog(@"WKContactsVC dealloc...");
    [[WKSDK shared].channelManager removeDelegate:self];
    [[WKContactsManager shared] removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WK_NOTIFY_CONTACTS_UPDATE object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WK_NOTIFY_CONTACTS_HEADER_UPDATE object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WK_NOTIFY_CONTACTS_TAB_REDDOT_UPDATE object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kWKFollowedKeysStoreDidUpdateNotification object:nil];
}

// 开启大标题模式
- (BOOL)largeTitle {
    return true;
}

- (WKSearchbarView *)searchbarView {
    if(!_searchbarView) {
        _searchbarView = [[WKSearchbarView alloc] initWithFrame:CGRectMake(14.0f, 10.0f, WKScreenWidth - 28.0f, 36.0f)];
        _searchbarView.placeholder = LLang(@"搜索联系人、AI、群聊");
        _searchbarView.onClick = ^{
            WKGlobalSearchResultController *vc = [WKGlobalSearchResultController new];
            // 通讯录入口：搜索页默认选中"联系人"tab（会话列表入口走默认的"聊天"tab）。
            vc.searchType = WKHistoryMessageSearchTypeContacts;
            [[WKNavigationManager shared] pushViewController:vc animated:NO];
        };
    }
    return _searchbarView;
}

// 联系人数据更新通知（委托给节流的 requestData，避免频繁全量查询）
-(void) contactsUpdate:(NSNotification*)notify {
    if (self.isBatchUpdating) return; // 批量写DB期间忽略
    if (self.isUpdating) return;
    if (!self.dataLoaded) return;
    // 走节流的 requestData，会被5秒节流保护
    [self requestData];
}

-(void) refreshContactsHeader {
    if(self.items.count>0) {
        [self updateHeaderCountsIfNeeded];
    }
    [self refreshTaBarItemBadgeValue:self.tabBarItem];
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    if(type == WKViewConfigChangeTypeLang || type == WKViewConfigChangeTypeModule) {
        [self refreshContactsHeader];
    }
}

// 生成联系人数据指纹（uid + name 排序后拼接）
-(NSString*) fingerprintForContactInfos:(NSArray<WKChannelInfo*>*)infos {
    NSMutableArray<NSString*> *parts = [NSMutableArray array];
    for (WKChannelInfo *info in infos) {
        NSString *uid = info.channel.channelId ?: @"";
        NSString *name = info.name ?: @"";
        [parts addObject:[NSString stringWithFormat:@"%@:%@:%d", uid, name, info.robot]];
    }
    [parts sortUsingSelector:@selector(compare:)];
    return [parts componentsJoinedByString:@","];
}

// 用联系人数组刷新列表（会对比指纹，无变化则跳过刷新）
-(void) refreshContactsList:(NSArray<WKChannelInfo*>*)channelInfos {
    NSString *newFingerprint = [self fingerprintForContactInfos:channelInfos];
    if (self.currentContactsFingerprint && [self.currentContactsFingerprint isEqualToString:newFingerprint]) {
        NSLog(@"[TabPerf] ContactsVC.refreshContactsList SKIPPED (fingerprint match) count=%lu", (unsigned long)channelInfos.count);
        return; // 数据无变化，跳过刷新
    }
    self.currentContactsFingerprint = newFingerprint;
    self.allContactInfos = channelInfos;
    [self logContactsCounts:@"SET(refreshContactsList)"];
    [self rebuildTableData];
}

// 根据当前 filter 过滤联系人
-(NSArray<WKChannelInfo*>*) filteredContactInfos {
    if(!self.allContactInfos) return @[];
    if(self.contactsFilter == 1) { // AI
        NSMutableArray *result = [NSMutableArray array];
        for(WKChannelInfo *info in self.allContactInfos) {
            if(info.robot) [result addObject:info];
        }
        return result;
    } else if(self.contactsFilter == 2) { // 人类
        NSMutableArray *result = [NSMutableArray array];
        for(WKChannelInfo *info in self.allContactInfos) {
            if(!info.robot) [result addObject:info];
        }
        return result;
    }
    return self.allContactInfos; // 全部
}

// 重新应用过滤（tab 切换时调用）
-(void) applyFilter {
    [self rebuildTableData];
}

-(void) logContactsCounts:(NSString*)tag {
    NSInteger total = self.allContactInfos.count;
    NSInteger robots = 0;
    NSMutableSet<NSString*> *currentHumanUids = [NSMutableSet set];
    for (WKChannelInfo *info in self.allContactInfos) {
        if (info.robot) {
            robots++;
        } else {
            [currentHumanUids addObject:info.channel.channelId ?: @"nil"];
        }
    }
    NSInteger humans = total - robots;
    NSLog(@"[ContactsBug] %@ total=%ld robot=%ld human=%ld", tag, (long)total, (long)robots, (long)humans);

    if (self.lastHumanUids && humans != self.lastHumanCount) {
        NSMutableSet *added = [currentHumanUids mutableCopy];
        [added minusSet:self.lastHumanUids];
        NSMutableSet *removed = [self.lastHumanUids mutableCopy];
        [removed minusSet:currentHumanUids];
        NSLog(@"[ContactsBug] ⚠️ 人类数量变化 %ld→%ld, 新增=%@, 移除=%@",
              (long)self.lastHumanCount, (long)humans,
              added.count > 0 ? [added.allObjects componentsJoinedByString:@","] : @"无",
              removed.count > 0 ? [removed.allObjects componentsJoinedByString:@","] : @"无");
        if (added.count > 0) {
            for (NSString *uid in added) {
                WKChannelInfo *info = [self channelInfoForUid:uid];
                NSLog(@"[ContactsBug]   新增人类详情: uid=%@ name=%@ robot=%d follow=%d category=%@",
                      uid, info.displayName, info.robot, info.follow, info.category ?: @"nil");
            }
        }
    }
    self.lastHumanUids = currentHumanUids;
    self.lastHumanCount = humans;
}

-(WKChannelInfo*) channelInfoForUid:(NSString*)uid {
    for (WKChannelInfo *info in self.allContactInfos) {
        if ([info.channel.channelId isEqualToString:uid]) return info;
    }
    return nil;
}

// 统一的列表重建方法（所有列表更新都走这里，用 generation 防止异步竞争）
-(void) rebuildTableData {
    CFAbsoluteTime _rtStart = CFAbsoluteTimeGetCurrent();
    self.sortGeneration++;
    NSInteger currentGeneration = self.sortGeneration;

    // 顶部 filter pill 计数/选中态跟随数据变化刷新（pill 已迁到固定栏，不会被 reloadData 触达）
    [self refreshFilterTabContainer];

#if DEBUG
    // 去重检测：检查 allContactInfos 是否有重复 uid（仅 DEBUG，避免主线程上抓 callStackSymbols）
    {
        NSMutableDictionary<NSString*, NSNumber*> *uidCounts = [NSMutableDictionary dictionary];
        for (WKChannelInfo *info in self.allContactInfos) {
            NSString *uid = info.channel.channelId;
            uidCounts[uid] = @([uidCounts[uid] integerValue] + 1);
        }
        for (NSString *uid in uidCounts) {
            if ([uidCounts[uid] integerValue] > 1) {
                NSLog(@"[ContactsBug] ⚠️ 重复uid: %@ 出现%@次, allContactInfos.count=%lu, robot=%d, callStack:\n%@",
                      uid, uidCounts[uid], (unsigned long)self.allContactInfos.count,
                      [self channelInfoForUid:uid].robot,
                      [[NSThread callStackSymbols] subarrayWithRange:NSMakeRange(1, MIN(6, [NSThread callStackSymbols].count - 1))]);
            }
        }
    }
#endif

    NSArray<WKChannelInfo*> *filtered = [self filteredContactInfos];
    NSString *suffix = (self.contactsFilter == 1) ? @" AI" : LLang(@"联系人");
    self.contactsCountLbl.text = [NSString stringWithFormat:@"%@ %ld %@%@", LLang(@"共"), (long)filtered.count, LLang(@"位"), suffix];

    NSMutableArray *cellModels = [NSMutableArray array];
    for (WKChannelInfo *info in filtered) {
        [cellModels addObject:[self toContactsCellModel:info]];
    }

    NSArray *headerItems = [self buildHeaderItemsWithCounts];

    if (cellModels.count == 0) {
        // 无数据，保留 section 0（header）+ section 1（空联系人，tab header view 需要显示）
        NSMutableArray *newItems = [NSMutableArray array];
        [newItems addObject:[NSMutableArray arrayWithArray:headerItems]];
        [newItems addObject:[NSMutableArray array]]; // 空的联系人 section
        self.sectionTitleArr = [NSMutableArray arrayWithObject:@""]; // 占位，确保 numberOfSections = 2
        self.items = newItems;
        [self.tableView reloadData];
        return;
    }

    // 异步排序，回调时检查 generation
    __weak typeof(self) weakSelf = self;
    [WKChineseSort sortAndGroup:cellModels key:@"name" finish:^(bool isSuccess, NSMutableArray *unGroupArr, NSMutableArray *sectionTitleArr, NSMutableArray<NSMutableArray *> *sortedObjArr) {
        if (!weakSelf) return;
        if (currentGeneration != weakSelf.sortGeneration) return; // 已过时，丢弃
        if (!isSuccess) return;

        // 原子性重建 items = header + 排序分组
        NSMutableArray *newItems = [NSMutableArray array];
        [newItems addObject:[NSMutableArray arrayWithArray:headerItems]];
        [newItems addObjectsFromArray:sortedObjArr];
        weakSelf.sectionTitleArr = sectionTitleArr;
        weakSelf.items = newItems;

        // 动画期间延迟 reloadData，避免 layout pass 阻塞 tab 切换动画
        id<UIViewControllerTransitionCoordinator> coordinator = weakSelf.transitionCoordinator;
        if (coordinator && coordinator.isAnimated) {
            [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
                [weakSelf.tableView reloadData];
                NSLog(@"[TabPerf] ContactsVC.rebuildTableData: DEFERRED reloadData count=%lu total=%.1fms",
                      (unsigned long)filtered.count, (CFAbsoluteTimeGetCurrent() - _rtStart) * 1000);
            }];
        } else {
            [weakSelf.tableView reloadData];
            NSLog(@"[TabPerf] ContactsVC.rebuildTableData: reloadData count=%lu total=%.1fms",
                  (unsigned long)filtered.count, (CFAbsoluteTimeGetCurrent() - _rtStart) * 1000);
        }
    }];
}

// 构建带计数的 header items
-(NSArray*) buildHeaderItemsWithCounts {
    NSArray *headerItems = [[WKApp shared] invokes:WKPOINT_CATEGORY_CONTACTSITEM param:nil];
    for (WKContactsHeaderItem *item in headerItems) {
        if([item.sid isEqualToString:@"groups"]) {
            item.countValue = [NSString stringWithFormat:@"(%ld)", (long)self.groupCount];
        } else if([item.sid isEqualToString:@"bot"]) {
            item.countValue = [NSString stringWithFormat:@"(%ld)", (long)self.myBotCount];
        }
    }
    return headerItems;
}

// 请求联系人数据（互斥保护，DB 写入在后台线程不阻塞 UI）
-(void) requestData{
    NSLog(@"[TabPerf] ContactsVC.requestData called, isUpdating=%d", self.isUpdating);
    // 互斥：更新管道正在执行中，拒绝新请求
    if (self.isUpdating) return;

    self.isUpdating = YES;

    // 确保 items 至少有 header section
    if (self.items.count == 0) {
        NSArray *headerItems = [[WKApp shared] invokes:WKPOINT_CATEGORY_CONTACTSITEM param:nil];
        [self.items insertObject:[NSMutableArray arrayWithArray:headerItems] atIndex:0];
        [self.tableView reloadData];
    }

    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (currentSpaceId && currentSpaceId.length > 0) {
        [self fetchAllDataWithSpaceId:currentSpaceId];
    } else {
        [self fetchFriendContacts];
    }
}

// 包装Promise使其永不reject：失败时返回 NSNull 作为哨兵值
-(AnyPromise*) safePromise:(AnyPromise*)promise name:(NSString*)name {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        promise.then(^(id result) {
            resolve(result ?: @[]);
        }).catch(^(NSError *error) {
            WKLogError(@"[Contacts] %@ API请求失败（跳过该数据）: %@", name, error);
            resolve([NSNull null]); // 标记为失败，后续处理跳过
        });
    }];
}

// Space 模式：并行请求 members + space_bots + my_bots + groups
// 每个接口独立容错，失败的跳过，成功的正常处理
-(void) fetchAllDataWithSpaceId:(NSString*)spaceId {
    __weak typeof(self) weakSelf = self;

    NSString *membersPath = [NSString stringWithFormat:@"space/%@/members", spaceId];
    AnyPromise *membersPromise = [self safePromise:[[WKAPIClient sharedClient] GET:membersPath parameters:@{@"page":@"1", @"limit":@"10000"}] name:@"members"];
    AnyPromise *spaceBotsPromise = [self safePromise:[[WKAPIClient sharedClient] GET:@"robot/space_bots" parameters:@{@"space_id": spaceId}] name:@"space_bots"];
    AnyPromise *myBotsPromise = [self safePromise:[[WKAPIClient sharedClient] GET:@"robot/my_bots" parameters:@{@"space_id": spaceId}] name:@"my_bots"];
    NSMutableDictionary *groupParams = [NSMutableDictionary dictionaryWithDictionary:@{@"page_size":@(1000), @"space_id": spaceId}];
    AnyPromise *groupsPromise = [self safePromise:[[WKAPIClient sharedClient] GET:@"group/my" parameters:groupParams] name:@"groups"];

    PMKWhen(@[membersPromise, spaceBotsPromise, groupsPromise, myBotsPromise]).then(^(NSArray *results) {
        // 数据处理放到后台线程，避免阻塞 UI
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *nowSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
            if (![spaceId isEqualToString:nowSpaceId]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.isUpdating = NO;
                    weakSelf.lastLoadTime = [[NSDate date] timeIntervalSince1970];
                });
                return;
            }

            // 取出各接口结果，NSNull 表示该接口失败
            id rawMembers   = results.count > 0 ? results[0] : [NSNull null];
            id rawSpaceBots = results.count > 1 ? results[1] : [NSNull null];
            id rawGroups    = results.count > 2 ? results[2] : [NSNull null];
            id rawMyBots    = results.count > 3 ? results[3] : [NSNull null];

            BOOL membersOK   = rawMembers != [NSNull null] && [rawMembers isKindOfClass:[NSArray class]];
            BOOL spaceBotsOK = rawSpaceBots != [NSNull null] && [rawSpaceBots isKindOfClass:[NSArray class]];
            BOOL groupsOK    = rawGroups != [NSNull null] && [rawGroups isKindOfClass:[NSArray class]];
            BOOL myBotsOK    = rawMyBots != [NSNull null] && [rawMyBots isKindOfClass:[NSArray class]];

            NSLog(@"[Contacts] API状态: members=%@, space_bots=%@, groups=%@, my_bots=%@",
                  membersOK ? @"OK" : @"FAIL", spaceBotsOK ? @"OK" : @"FAIL",
                  groupsOK ? @"OK" : @"FAIL", myBotsOK ? @"OK" : @"FAIL");

            // 如果所有接口都失败，直接结束
            if (!membersOK && !spaceBotsOK && !groupsOK && !myBotsOK) {
                WKLogError(@"[Contacts] 所有API均失败，跳过本次更新");
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.dataLoaded = YES;
                    weakSelf.lastLoadTime = [[NSDate date] timeIntervalSince1970];
                    weakSelf.isUpdating = NO;
                });
                return;
            }

            NSString *myUid = [WKApp shared].loginInfo.uid;
            // UI 渲染数据：含全部 space_bots（含 not_added/pending），保证「AI」tab 显示空间内全部 AI。
            // DB 写入数据：仅含「已添加」的（members、my_bots、space_bots(added)），
            // 避免选人页通过 follow=Friend 查 DB 时拿到「全部 AI」。
            NSMutableArray<WKChannelInfo*> *uiInfos = [NSMutableArray array];
            NSMutableArray<WKChannelInfo*> *dbInfos = [NSMutableArray array];
            NSMutableSet *addedUids = [NSMutableSet set];
            NSInteger myBotCount = 0;

            // 日志：打印成功接口返回数量
            NSLog(@"[Contacts] members=%lu, space_bots=%lu, groups=%lu, my_bots=%lu",
                  (unsigned long)(membersOK ? [(NSArray*)rawMembers count] : 0),
                  (unsigned long)(spaceBotsOK ? [(NSArray*)rawSpaceBots count] : 0),
                  (unsigned long)(groupsOK ? [(NSArray*)rawGroups count] : 0),
                  (unsigned long)(myBotsOK ? [(NSArray*)rawMyBots count] : 0));

            // space_bots 里 status 分布
            if (spaceBotsOK) {
                NSInteger added = 0, notAdded = 0, pending = 0, other = 0;
                for (NSDictionary *b in (NSArray*)rawSpaceBots) {
                    NSString *s = b[@"status"];
                    if ([s isEqualToString:@"added"]) added++;
                    else if ([s isEqualToString:@"not_added"]) notAdded++;
                    else if ([s isEqualToString:@"pending"]) pending++;
                    else other++;
                }
                NSLog(@"[Contacts] space_bots status: added=%ld, not_added=%ld, pending=%ld, other=%ld", (long)added, (long)notAdded, (long)pending, (long)other);
            }

            // 处理 members（成功时才处理）
            if (membersOK) {
                for (NSDictionary *m in (NSArray*)rawMembers) {
                    NSString *uid = m[@"uid"];
                    if (!uid || [uid isEqualToString:myUid]) continue;
                    [addedUids addObject:uid];

                    WKChannelInfo *channelInfo = [WKChannelInfo new];
                    channelInfo.channel = [[WKChannel alloc] initWith:uid channelType:WK_PERSON];
                    channelInfo.name = m[@"name"] ?: @"";
                    channelInfo.logo = m[@"avatar"] ?: @"";
                    if (!channelInfo.logo || [channelInfo.logo isEqualToString:@""]) {
                        channelInfo.logo = [NSString stringWithFormat:@"users/%@/avatar", uid];
                    }
                    channelInfo.follow = WKChannelInfoFollowFriend;
                    channelInfo.status = 1;
                    channelInfo.robot = m[@"robot"] ? [m[@"robot"] boolValue] : NO;
                    if (channelInfo.robot) myBotCount++;
                    if (m[@"category"] && ![m[@"category"] isEqual:[NSNull null]]) {
                        channelInfo.category = m[@"category"];
                    }
                    [uiInfos addObject:channelInfo];
                    [dbInfos addObject:channelInfo];
                }
            }

            // 处理 space_bots（成功时才处理）
            // - 全部 status 都进 uiInfos —— 通讯录「AI」tab 需要显示空间内所有 AI（含 not_added/pending）。
            // - 仅 status=added 进 dbInfos —— 避免选人页通过 follow=Friend 查 DB 时拿到「全部 AI」。
            // - myBotCount 同样只算 added，与 header「已添加 AI」语义一致。
            if (spaceBotsOK) {
                for (NSDictionary *bot in (NSArray*)rawSpaceBots) {
                    NSString *uid = bot[@"uid"];
                    NSString *status = bot[@"status"];
                    if (!uid || [addedUids containsObject:uid]) continue;
                    [addedUids addObject:uid];

                    WKChannelInfo *channelInfo = [WKChannelInfo new];
                    channelInfo.channel = [[WKChannel alloc] initWith:uid channelType:WK_PERSON];
                    channelInfo.name = bot[@"name"] ?: @"";
                    channelInfo.logo = [NSString stringWithFormat:@"users/%@/avatar", uid];
                    channelInfo.follow = WKChannelInfoFollowFriend;
                    channelInfo.status = 1;
                    channelInfo.robot = YES;
                    [uiInfos addObject:channelInfo];
                    if ([status isEqualToString:@"added"]) {
                        myBotCount++;
                        [dbInfos addObject:channelInfo];
                    }
                }
            }

            // 处理 my_bots（成功时才处理，去重合并）
            if (myBotsOK) {
                for (id item in (NSArray*)rawMyBots) {
                    NSDictionary *bot = nil;
                    if ([item isKindOfClass:[NSDictionary class]]) {
                        bot = (NSDictionary *)item;
                    }
                    if (!bot) continue;
                    NSString *uid = bot[@"uid"];
                    if (!uid || [addedUids containsObject:uid]) continue;
                    [addedUids addObject:uid];

                    WKChannelInfo *channelInfo = [WKChannelInfo new];
                    channelInfo.channel = [[WKChannel alloc] initWith:uid channelType:WK_PERSON];
                    channelInfo.name = bot[@"name"] ?: @"";
                    channelInfo.logo = [NSString stringWithFormat:@"users/%@/avatar", uid];
                    channelInfo.follow = WKChannelInfoFollowFriend;
                    channelInfo.status = 1;
                    channelInfo.robot = YES;
                    myBotCount++;
                    [uiInfos addObject:channelInfo];
                    [dbInfos addObject:channelInfo];
                }
            }

            // 处理群聊数量（成功时才更新，失败时保留旧值）
            NSInteger groupCount = weakSelf.groupCount; // 默认保留旧值
            if (groupsOK) {
                groupCount = [(NSArray*)rawGroups count];
            }

            // DB 写入在后台线程完成，避免阻塞主线程
            // 仅写 dbInfos —— 不把 not_added/pending 的 space_bots 写入 follow=Friend，
            // 否则会污染选人页（拉群成员）的好友查询。
            //
            // [本地态保留] 通讯录 API 返回里**没有** online/lastOffline/deviceFlag/stick/mute
            // 等字段，直接 addOrUpdate 会把这些字段全部 reset 成默认值。后果分别是：
            //   - online=NO：污染 AI 总结按钮 / 在线小绿点
            //   - stick=NO：用户切到通讯录再回会话列表，私聊置顶突然消失（DM 偶发掉置顶
            //     根因，因为只有 DM 走通讯录这条 channelInfo 写回路径；群在
            //     group_setting 路径上有兜底）
            //   - mute=NO：静音同理
            // 这里在批写前把所有上游 API 不维护、但本地权威的字段全部 merge 回去。
            for (WKChannelInfo *info in dbInfos) {
                WKChannelInfo *old = [[WKSDK shared].channelManager getChannelInfo:info.channel];
                if (!old) continue;
                info.online = old.online;
                info.lastOffline = old.lastOffline;
                info.deviceFlag = old.deviceFlag;
                info.stick = old.stick;
                info.mute = old.mute;
            }
            weakSelf.isBatchUpdating = YES;
            [[WKSDK shared].channelManager addOrUpdateChannelInfos:dbInfos];
            weakSelf.isBatchUpdating = NO;

            // 回主线程更新 UI
            dispatch_async(dispatch_get_main_queue(), ^{
                // 只有对应接口成功时才更新计数，失败时保留旧值
                if (membersOK || spaceBotsOK || myBotsOK) {
                    weakSelf.myBotCount = myBotCount;
                }
                if (groupsOK) {
                    weakSelf.groupCount = groupCount;
                }
                // UI 用 uiInfos —— 「AI」tab 渲染包含 not_added/pending 的全部 AI。
                [weakSelf applyIncrementalUpdate:uiInfos];
                weakSelf.dataLoaded = YES;
                weakSelf.lastLoadTime = [[NSDate date] timeIntervalSince1970];
                weakSelf.isUpdating = NO;
            });
        });
    });
}

// 个人模式：从 API 拉取好友列表
-(void) fetchFriendContacts {
    __weak typeof(self) weakSelf = self;
    NSString *cacheKey = [NSString stringWithFormat:@"%@_%@",[WKApp shared].loginInfo.uid,@"friend_version"];
    NSString *friendMaxVersion = [[NSUserDefaults standardUserDefaults] stringForKey:cacheKey];
    NSMutableDictionary *syncParams = [NSMutableDictionary dictionaryWithDictionary:@{@"version":friendMaxVersion?:@"",@"api_version":@"1",@"limit":@(200)}];
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (currentSpaceId && currentSpaceId.length > 0) {
        syncParams[@"space_id"] = currentSpaceId;
    }
    [[WKAPIClient sharedClient] GET:@"friend/sync" parameters:syncParams].then(^(NSArray<NSDictionary*>* contacts){
        // 数据处理放到后台线程，避免阻塞 UI（与 fetchAllDataWithSpaceId 对齐）
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (contacts && contacts.count > 0) {
                NSMutableArray *channelInfos = [NSMutableArray array];
                for (NSDictionary *dict in contacts) {
                    BOOL isDeleted = dict[@"is_deleted"] ? [dict[@"is_deleted"] boolValue] : NO;
                    if(isDeleted) {
                        WKChannel *channel = [[WKChannel alloc] initWith:dict[@"uid"] channelType:WK_PERSON];
                        [[WKSDK shared].channelManager deleteChannelInfo:channel];
                    } else {
                        [channelInfos addObject:[WKChannelUtil toChannelInfo:dict]];
                    }
                }
                long long version = [contacts.lastObject[@"version"] longLongValue];
                // iOS 12+ 系统会自动调度落盘，去掉主动 synchronize 以减少阻塞
                [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%lld",version] forKey:cacheKey];
                // [本地态保留] friend/sync 同样不返 online/stick/mute 等字段，
                // 全部从旧 channelInfo merge 回来（详见上面 fetchAllDataWithSpaceId 同款注释）。
                for (WKChannelInfo *info in channelInfos) {
                    WKChannelInfo *old = [[WKSDK shared].channelManager getChannelInfo:info.channel];
                    if (!old) continue;
                    info.online = old.online;
                    info.lastOffline = old.lastOffline;
                    info.deviceFlag = old.deviceFlag;
                    info.stick = old.stick;
                    info.mute = old.mute;
                }
                weakSelf.isBatchUpdating = YES;
                [[WKSDK shared].channelManager addOrUpdateChannelInfos:channelInfos];
                weakSelf.isBatchUpdating = NO;
            }
            // 从数据库重新加载（API 可能只返回增量数据）
            NSArray<WKChannelInfo*> *allInfos = [[WKChannelInfoDB shared] queryChannelInfosWithStatusAndFollow:WKChannelStatusNormal follow:WKChannelInfoFollowFriend];

            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf applyIncrementalUpdate:allInfos ?: @[]];
                weakSelf.dataLoaded = YES;
                weakSelf.lastLoadTime = [[NSDate date] timeIntervalSince1970];
                weakSelf.isUpdating = NO;
            });
        });
    }).catch(^(NSError *error){
        WKLogError(@"拉取好友联系人失败:%@", error);
        weakSelf.dataLoaded = YES;
        weakSelf.lastLoadTime = [[NSDate date] timeIntervalSince1970];
        weakSelf.isUpdating = NO;
    });
}

-(WKContactsCellModel*) toContactsCellModel:(WKChannelInfo*)channelInfo {
    WKContactsCellModel *contactsCellModel = [[WKContactsCellModel alloc] init];
    contactsCellModel.uid =channelInfo.channel.channelId;
    contactsCellModel.name = channelInfo.displayName;
    contactsCellModel.online = channelInfo.online;
    contactsCellModel.lastOffline = channelInfo.lastOffline;
    contactsCellModel.channelInfo = channelInfo;
    contactsCellModel.isGroup = NO; // 通讯录 cell 永远是 person，已关注图标走 WKFollowTargetTypeDM
    
    contactsCellModel.robot = channelInfo.robot;
    if(channelInfo.logo) {
        NSString *key = (channelInfo.avatarCacheKey.length > 0) ? channelInfo.avatarCacheKey : @"0";
        NSString *fullUrl = [WKAvatarUtil getFullAvatarWIthPath:channelInfo.logo];
        NSString *separator = [fullUrl containsString:@"?"] ? @"&" : @"?";
        contactsCellModel.avatar = [NSString stringWithFormat:@"%@%@v=%@", fullUrl, separator, key];
    } else {
        contactsCellModel.avatar = [WKAvatarUtil getAvatar:channelInfo.channel.channelId cacheKey:channelInfo.avatarCacheKey];
    }
    if([channelInfo.displayName isEqualToString:@"系统通知"]) {
        NSLog(@"[DEBUG] 系统通知 头像URL: %@, logo: %@, uid: %@", contactsCellModel.avatar, channelInfo.logo, channelInfo.channel.channelId);
    }
    return contactsCellModel;
}

// 联系人排序和分组
// sortAndGroup 已统一到 rebuildTableData 中



#pragma mark - 长按关注菜单

- (void)onContactLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint pInTable = [gesture locationInView:self.tableView];
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:pInTable];
    if (!ip) return;
    if (ip.section <= 0 || ip.section >= (NSInteger)self.items.count) return; // section 0 是 header items
    NSArray *sectionItems = self.items[ip.section];
    if (ip.row >= (NSInteger)sectionItems.count) return;
    id model = sectionItems[ip.row];
    if (![model isKindOfClass:[WKContactsCellModel class]]) return;
    WKContactsCellModel *contact = model;
    if (contact.uid.length == 0) return;

    UIWindow *window = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    CGPoint pInWindow = [self.tableView convertPoint:pInTable toView:window];
    WKChannel *channel = [[WKChannel alloc] initWith:contact.uid channelType:WK_PERSON];
    [WKContactFollowHelper showFollowMenuForChannel:channel
                                     atPointInWindow:pInWindow
                                       presentingVC:self
                                        onDidChange:nil]; // 状态变化由 FollowedKeysStore 通知统一刷
}

- (void)onFollowedKeysUpdate {
    // 仅刷新可见的 contact cell — header section 0 不动；contact cell 的关注图标根据
    // store 的最新状态重画。整表 reloadData 也行，但仅重画可见的避免触发字母索引重计算。
    NSArray<NSIndexPath *> *visible = self.tableView.indexPathsForVisibleRows;
    NSMutableArray<NSIndexPath *> *contactPaths = [NSMutableArray array];
    for (NSIndexPath *ip in visible) {
        if (ip.section == 0) continue;
        [contactPaths addObject:ip];
    }
    if (contactPaths.count == 0) return;
    @try {
        [self.tableView reloadRowsAtIndexPaths:contactPaths withRowAnimation:UITableViewRowAnimationNone];
    } @catch (NSException *ex) {
        [self.tableView reloadData];
    }
}

#pragma mark table

-(UIView*) tableHeader {
    if(!_tableHeader) {
        CGFloat topPad = 8.0f;
        CGFloat bottomPad = 10.0f;
        _tableHeader = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, self.searchbarView.frame.size.height + topPad + bottomPad)];
        self.searchbarView.frame = CGRectMake(14.0f, topPad, WKScreenWidth - 28.0f, 36.0f);
        [_tableHeader addSubview:self.searchbarView];
    }
    return _tableHeader;
}

#pragma mark - 顶部固定栏（搜索 + 全部/AI/人类 tab，不随 tableView 滚动）

-(UIView*) topStickyView {
    if(!_topStickyView) {
        CGFloat searchTop = 8.0f;
        CGFloat searchH   = 36.0f;
        CGFloat searchBottom = 10.0f;
        CGFloat filterH   = 50.0f;
        CGFloat totalH    = searchTop + searchH + searchBottom + filterH;
        CGFloat top       = self.navigationBar.lim_bottom;
        _topStickyView = [[UIView alloc] initWithFrame:CGRectMake(0, top, WKScreenWidth, totalH)];
        _topStickyView.backgroundColor = WKApp.shared.config.cellBackgroundColor;

        // 搜索栏
        self.searchbarView.frame = CGRectMake(14.0f, searchTop, WKScreenWidth - 28.0f, searchH);
        [_topStickyView addSubview:self.searchbarView];

        // filter tab 容器（pill 内容由 refreshFilterTabContainer 重建）
        _filterTabContainer = [[UIView alloc] initWithFrame:CGRectMake(0, searchTop + searchH + searchBottom, WKScreenWidth, filterH)];
        _filterTabContainer.backgroundColor = WKApp.shared.config.cellBackgroundColor;
        [_topStickyView addSubview:_filterTabContainer];

        [self refreshFilterTabContainer];
    }
    return _topStickyView;
}

-(void) refreshFilterTabContainer {
    if(!_filterTabContainer) return;
    for(UIView *v in _filterTabContainer.subviews) [v removeFromSuperview];
    UIView *pill = [self contactsFilterHeaderView];
    pill.frame = CGRectMake(0, 0, _filterTabContainer.lim_width, _filterTabContainer.lim_height);
    [_filterTabContainer addSubview:pill];
}

-(UITableView *)tableView{
    if(!_tableView){
        // tableView 起点 = 顶部固定栏底部，避开 searchbar + filter tab 区域
        CGRect r = [self visibleRect];
        CGFloat stickyH = self.topStickyView.frame.size.height;
        r.origin.y    += stickyH;
        r.size.height -= stickyH;
        _tableView = [[UITableView alloc] initWithFrame:r style:UITableViewStyleGrouped];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        UIEdgeInsets separatorInset   = _tableView.separatorInset;
        separatorInset.right          = 0;
        _tableView.separatorInset = separatorInset;
        _tableView.backgroundColor=[UIColor clearColor];

        _tableView.sectionIndexBackgroundColor = [UIColor clearColor];
//        _tableView.tableFooterView = [[UIView alloc] init];
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.sectionHeaderHeight = 0.0f;
        _tableView.sectionFooterHeight = 0.0f;
        _tableView.sectionIndexColor = WKApp.shared.config.themeColor;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        // tabbar高度 + 额外边距，确保最后一行完整显示
        CGFloat tabBarHeight = self.tabBarController.tabBar.frame.size.height ?: 49;
        _tableView.contentInset = UIEdgeInsetsMake(0, 0, tabBarHeight + 10, 0);
        [_tableView registerClass:WKContactsCell.class forCellReuseIdentifier:[WKContactsCell cellId]];
        [_tableView registerClass:WKContactsHeaderItemCell.class forCellReuseIdentifier:[WKContactsHeaderItemCell cellId]];

        // 1pt 占位 tableHeaderView：消掉 grouped style 顶部 ~35pt 系统默认 padding
        _tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, 0.01f)];
        _tableView.tableFooterView = [self tableFooterView];

    }
    return _tableView;
}

-(void) loadView{
    [super loadView];
    [self.view addSubview:self.topStickyView]; // 顺序：sticky 在底层、tableView 在上层（tableView 高度从 sticky 之下开始，不会重叠）
    [self.view addSubview:self.tableView];
}

-(UIView*) tableFooterView {
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.lim_width, 44.0f)];
    [footerView addSubview:self.contactsCountLbl];
    self.contactsCountLbl.frame = footerView.frame;
    footerView.backgroundColor = WKApp.shared.config.backgroundColor;
    return footerView;
}

-(UILabel*) contactsCountLbl {
    if(!_contactsCountLbl) {
        _contactsCountLbl = [[UILabel alloc] init];
        _contactsCountLbl.textColor = WKApp.shared.config.tipColor;
        _contactsCountLbl.font = [WKApp.shared.config appFontOfSize:WKApp.shared.config.footerTipFontSize];
        [_contactsCountLbl setTextAlignment:NSTextAlignmentCenter];
    }
    return _contactsCountLbl;
}

-(UILabel*) sectionIndexIndicator {
    if(!_sectionIndexIndicator) {
        CGFloat size = 72.0f;
        _sectionIndexIndicator = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, size, size)];
        _sectionIndexIndicator.textAlignment = NSTextAlignmentCenter;
        _sectionIndexIndicator.font = [UIFont systemFontOfSize:36.0f weight:UIFontWeightMedium];
        _sectionIndexIndicator.textColor = [UIColor whiteColor];
        _sectionIndexIndicator.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.6f];
        _sectionIndexIndicator.layer.cornerRadius = 10.0f;
        _sectionIndexIndicator.layer.masksToBounds = YES;
        _sectionIndexIndicator.alpha = 0;
        [self.view addSubview:_sectionIndexIndicator];
        _sectionIndexIndicator.center = CGPointMake(self.view.lim_width / 2.0f, self.view.lim_height / 2.0f);
    }
    return _sectionIndexIndicator;
}


// 头部字母部分
-(UIView*) headView:(NSString*)title headHeight:(CGFloat)headHheght color:(UIColor*)color{
    UIView *headView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, headHheght)];
    [headView setBackgroundColor:[self bgElevColor]];
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, headView.lim_width - 16, headView.lim_height)];
    [titleLbl setFont:[UIFont systemFontOfSize:12.0f weight:UIFontWeightSemibold]];
    [titleLbl setTextColor:WKApp.shared.config.tipColor];
    [titleLbl setText:title];
    [headView addSubview:titleLbl];
    return headView;
}

#pragma mark UITableDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if(section >= (NSInteger)self.items.count) return 0;
    return  self.items[section].count;
}
-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(self.items.count<=indexPath.section || self.items[indexPath.section].count<=indexPath.row) {
        return [[UITableViewCell alloc] init];
    }
    id model =  self.items[indexPath.section][indexPath.row];
    if([model isKindOfClass:[WKContactsCellModel class]]) {
        WKContactsCellModel *contactsCellModel = (WKContactsCellModel*)model;
        if(indexPath.row == 0) {
            NSString *title = [self.sectionTitleArr objectAtIndex:indexPath.section-1];
            contactsCellModel.first = indexPath.row == 0;
            contactsCellModel.firstLetter = title;
        }
        contactsCellModel.last = self.items[indexPath.section].count-1 == indexPath.row;
        WKContactsCell *cell =  [tableView dequeueReusableCellWithIdentifier:[WKContactsCell cellId]];
        [cell refresh:contactsCellModel];
        return cell;
    } else if([model isKindOfClass:[WKContactsHeaderItem class]]) {
        WKContactsHeaderItemCell *cell =  [tableView dequeueReusableCellWithIdentifier:[WKContactsHeaderItemCell cellId]];
        WKContactsHeaderItem *headerItem =  model;
        [cell refresh:headerItem];
        return cell;
    }
    return [[UITableViewCell alloc] init];
   
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    if(indexPath.section == 0) {
        return 56.0f;
    }
    return 52.0f;
}

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if(section == 0) {
        // section 0 的 filter tab 已迁到 topStickyView 固定栏，不再走 tableView header
        return 0.0f;
    }
    return 24.0f;
}
-(UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    if(section == 0) {
        return nil;
    }
    if (!self.sectionTitleArr || self.sectionTitleArr.count == 0) {
        return nil;
    }
    NSString *title = [self.sectionTitleArr objectAtIndex:section-1];
    return [self headView:title headHeight:24.0f color:WKApp.shared.config.tipColor];
}

// 全部联系人 section header — iOS-style segment control
-(UIView*) contactsFilterHeaderView {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, 50.0f)];
    container.backgroundColor = WKApp.shared.config.cellBackgroundColor;

    NSInteger totalCount = self.allContactInfos ? self.allContactInfos.count : 0;
    NSInteger aiCount = 0;
    NSInteger humanCount = 0;
    for (WKChannelInfo *info in self.allContactInfos) {
        if(info.robot) aiCount++; else humanCount++;
    }

    NSArray *titles = @[
        [NSString stringWithFormat:@"%@ · %ld", LLang(@"全部"), (long)totalCount],
        [NSString stringWithFormat:@"AI · %ld", (long)aiCount],
        [NSString stringWithFormat:@"%@ · %ld", LLang(@"人类"), (long)humanCount]
    ];

    CGFloat hPad = 14.0f;
    CGFloat pillH = 34.0f;
    CGFloat pillY = (50.0f - pillH) / 2.0f;

    // Pill background
    UIColor *bgElevColor = [self bgElevColor];
    UIView *pillBg = [[UIView alloc] initWithFrame:CGRectMake(hPad, pillY, WKScreenWidth - hPad * 2, pillH)];
    pillBg.backgroundColor = bgElevColor;
    pillBg.layer.cornerRadius = 10.0f;
    [container addSubview:pillBg];

    CGFloat segPad = 2.0f;
    CGFloat segW = (pillBg.lim_width - segPad * 2) / 3.0f;
    CGFloat segH = pillH - segPad * 2;

    for (NSInteger i = 0; i < 3; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:titles[i] forState:UIControlStateNormal];
        btn.tag = i;
        [btn addTarget:self action:@selector(filterTabTapped:) forControlEvents:UIControlEventTouchUpInside];

        btn.frame = CGRectMake(segPad + segW * i, segPad, segW, segH);
        btn.layer.cornerRadius = 8.0f;

        if (self.contactsFilter == i) {
            btn.backgroundColor = WKApp.shared.config.cellBackgroundColor;
            btn.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightBold];
            [btn setTitleColor:WKApp.shared.config.defaultTextColor forState:UIControlStateNormal];
            btn.layer.shadowColor = [UIColor blackColor].CGColor;
            btn.layer.shadowOpacity = 0.08f;
            btn.layer.shadowOffset = CGSizeMake(0, 1);
            btn.layer.shadowRadius = 3.0f;
        } else {
            btn.backgroundColor = [UIColor clearColor];
            btn.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightMedium];
            [btn setTitleColor:WKApp.shared.config.tipColor forState:UIControlStateNormal];
            btn.layer.shadowOpacity = 0;
        }

        [pillBg addSubview:btn];
    }

    return container;
}

-(UIColor*) bgElevColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark || WKApp.shared.config.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:23/255.0f green:24/255.0f blue:29/255.0f alpha:1.0f];
            }
            return [UIColor colorWithRed:245/255.0f green:246/255.0f blue:248/255.0f alpha:1.0f];
        }];
    }
    return [UIColor colorWithRed:245/255.0f green:246/255.0f blue:248/255.0f alpha:1.0f];
}

-(void) filterTabTapped:(UIButton*)sender {
    self.contactsFilter = sender.tag;
    [self refreshFilterTabContainer]; // 立即反馈选中态，不等异步排序完
    self.currentContactsFingerprint = nil; // 强制刷新
    [self applyFilter];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.0f;
}
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return nil;
}

//点击右侧索引表项时调用 索引与section的对应关系
- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    // 显示字母指示器
    self.sectionIndexIndicator.text = title;
    self.sectionIndexIndicator.alpha = 1.0;
    // 延迟隐藏
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideSectionIndexIndicator) object:nil];
    [self performSelector:@selector(hideSectionIndexIndicator) withObject:nil afterDelay:0.5];
    return index+1;
}

-(void) hideSectionIndexIndicator {
    [UIView animateWithDuration:0.3 animations:^{
        self.sectionIndexIndicator.alpha = 0;
    }];
}
//
//section右侧index数组
-(NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView{
    return self.sectionTitleArr;
}


//
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return self.sectionTitleArr.count + 1;
}
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    id model =  self.items[indexPath.section][indexPath.row];
    if([model isKindOfClass:[WKContacts class]]) {
        WKContacts *contacts = model;
        // 显示个人名片
        [[WKApp shared] invoke:WKPOINT_USER_INFO param:@{@"uid": contacts.uid}];
    }else if([model isKindOfClass:[WKContactsHeaderItem class]]) {
        WKContactsHeaderItem *headerItem = model;
        if(headerItem.onClick) {
            headerItem.onClick();
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if(self.items.count<=indexPath.section || self.items[indexPath.section].count <= indexPath.row) {
        return false;
    }
    id model =  self.items[indexPath.section][indexPath.row];
    if([model isKindOfClass:[WKContacts class]]) {
        return true;
    }
    return false;
}


- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak typeof(self)weakSelf = self;
    WKContacts *contacts =  self.items[indexPath.section][indexPath.row];
    UITableViewRowAction *settingRemarkAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"设置备注" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [weakSelf toSettingRemark:contacts];

    }];
    if(WKApp.shared.config.style == WKSystemStyleDark) {
        settingRemarkAction.backgroundColor = [WKApp shared].config.backgroundColor;
    } else {
        settingRemarkAction.backgroundColor = [UIColor colorWithRed:200.0f/255.0f green:200.0f/255.0f blue:200.0f/255.0f alpha:1.0f];
    }
    

    return @[settingRemarkAction];
}

-(void) toSettingRemark:(WKContacts*)contacts {
    WKInputVC *inputVC = [WKInputVC new];
    inputVC.title = LLang(@"修改备注");
    inputVC.maxLength = 10;
    WKChannel *channel = [WKChannel personWithChannelID:contacts.uid];
    NSString *name = contacts.name;
    inputVC.defaultValue = name;
    [inputVC setOnFinish:^(NSString * _Nonnull value) {
        
        [[WKChannelSettingManager shared] channel:channel remark:value?:@""];
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    }];
    [[WKNavigationManager shared] pushViewController:inputVC animated:YES];
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
}

#pragma mark  -- WKContactsManagerDelegate
-(void) contactsManager:(WKContactsManager*)manager lastFriendRequest:(WKFriendRequestDBModel*)friendRequestDBModel {
   
}
-(void) contactsManager:(WKContactsManager*)manager friendRequestUnreadCount:(int)unreadCount {
    [self refreshContactsHeader];
}

// 好友邀请被接受
-(void) contactsManager:(WKContactsManager *)manager friendAccepted:(NSDictionary*)param {
    NSString *toUID = param[@"to_uid"];
    if(toUID) {
        // 更新状态
        [[WKContactsManager shared] updateFriendRequestStatus:toUID status:WKFriendRequestStatusSured];
        
        [self refreshTaBarItemBadgeValue];
    }
    // 开始同步联系人
    [[[WKContactsSync alloc] init] sync:^(NSError *error) {
        if(!error) {
            NSString *fromUID = param[@"from_uid"];
            if(fromUID) {
                [[WKSDK shared].channelManager fetchChannelInfo:[WKChannel personWithChannelID:fromUID]];
            }
        }
        
    }];
}

-(void) refreshTaBarItemBadgeValue {
    [self refreshTaBarItemBadgeValue:self.tabBarItem];
}

-(void) refreshTaBarItemBadgeValue:(UITabBarItem*)tabbarItem {
    int count = [[WKContactsManager shared] getFriendRequestUnreadCount];
    NSArray<NSNumber*> *reddots = [[WKApp shared] invokes:WK_CONTACTS_CATEGORY_TAB_REDDOT param:nil];
    BOOL hasReddot = false;
    if(reddots && reddots.count>0) {
        for (NSNumber *number in reddots) {
            if(number.intValue== - 1) {
                hasReddot = true;
            }else{
                count += number.intValue;
            }
        }
    }
    if (@available(iOS 10.0, *)) {
        tabbarItem.badgeColor = [UIColor redColor];
        [tabbarItem setBadgeTextAttributes:nil forState:UIControlStateNormal];
    }
    if(count>0) {
        tabbarItem.badgeValue = [NSString stringWithFormat:@"%d",count];
    }else if(hasReddot) {
        tabbarItem.badgeValue = @"●";
        if (@available(iOS 10.0, *)) {
            tabbarItem.badgeColor = [UIColor clearColor];
            [tabbarItem setBadgeTextAttributes:@{NSForegroundColorAttributeName:[UIColor redColor]} forState:UIControlStateNormal];
        }else{
            tabbarItem.badgeValue = @"";
        }
    }else{
        tabbarItem.badgeValue = nil;
    }
}

- (UITabBarItem *)tabBarItem {
    UITabBarItem *tabbarItem = [super tabBarItem];
    [self refreshTaBarItemBadgeValue:tabbarItem];
    return tabbarItem;
}

// Bugly build55 兜底：channelInfoUpdate / channelInfoDelete 是 IM 异步回调，
// 可能在 self.items 已被另一路径（applyIncrementalUpdate / rebuildTableData）改动
// 但 tableView 还没 reloadData 的间隙抵达。直接走 insert/delete/reloadRows 会触发
// UITableView 内部 NSInternalInconsistencyException → SIGABRT。
// 调用任何增量 API 之前先用这个 helper 自检；不一致就降级为 reloadData。
-(BOOL) isTableViewInSyncWithItems {
    if (!self.tableView) return NO;
    if ((NSInteger)self.items.count != [self.tableView numberOfSections]) return NO;
    for (NSInteger s = 0; s < (NSInteger)self.items.count; s++) {
        NSArray *arr = self.items[s];
        if ((NSInteger)arr.count != [self.tableView numberOfRowsInSection:s]) return NO;
    }
    return YES;
}

-(void) addOrUpdateContactsWithChannelInfo:(WKChannelInfo*)channelInfo {
    if(self.items.count<=1) {
        return;
    }

    // 先在 allContactInfos 中检查是否已存在（避免因过滤tab导致误判为新联系人）
    BOOL existsInAll = NO;
    if (self.allContactInfos) {
        for (WKChannelInfo *info in self.allContactInfos) {
            if ([info.channel.channelId isEqualToString:channelInfo.channel.channelId]) {
                existsInAll = YES;
                break;
            }
        }
    }

    // 在当前显示的 items 中查找（用于定位 cell 做局部刷新）
    WKContactsCellModel *existCellModel;
    NSIndexPath *existIndexPath;
    for (NSInteger i=1; i<self.items.count; i++) {
        NSMutableArray *contactsItems = self.items[i];
        NSInteger k = 0;
        for (WKContactsCellModel *cellModel in contactsItems) {
            if([channelInfo.channel.channelId isEqualToString:cellModel.uid]) {
                existCellModel = cellModel;
                existIndexPath = [NSIndexPath indexPathForRow:k inSection:i];
                break;
            }
            k++;
        }
    }

    if(!existCellModel) {
        if (existsInAll) {
            // 已存在于 allContactInfos 但不在当前过滤视图中（如AI tab下收到人类联系人更新）
            // 不修改 allContactInfos（避免DB版本的robot等字段污染计数），等下次API更新时统一处理
            return;
        }
        // 真正的新联系人：由 addContactsWithChannelInfo 内部处理 UI 插入
        [self addContactsWithChannelInfo:channelInfo];
        return;
    }
    BOOL hasChange = false;
    if(![channelInfo.displayName isEqualToString:existCellModel.name]) {
        existCellModel.name = channelInfo.displayName;
        existCellModel.channelInfo = channelInfo;
        hasChange = true;
    }

    if(channelInfo.online != existCellModel.online || channelInfo.lastOffline != existCellModel.lastOffline || channelInfo.deviceFlag !=existCellModel.channelInfo.deviceFlag) {
        existCellModel.online = channelInfo.online;
        existCellModel.lastOffline = channelInfo.lastOffline;
        existCellModel.channelInfo = channelInfo;
        hasChange = true;
    }
    if(channelInfo.avatarCacheKey && ![channelInfo.avatarCacheKey isEqualToString:existCellModel.channelInfo.avatarCacheKey ?: @""]) {
        existCellModel.channelInfo = channelInfo;
        if(channelInfo.logo) {
            NSString *key = channelInfo.avatarCacheKey.length > 0 ? channelInfo.avatarCacheKey : @"0";
            NSString *fullUrl = [WKAvatarUtil getFullAvatarWIthPath:channelInfo.logo];
            NSString *separator = [fullUrl containsString:@"?"] ? @"&" : @"?";
            existCellModel.avatar = [NSString stringWithFormat:@"%@%@v=%@", fullUrl, separator, key];
        } else {
            existCellModel.avatar = [WKAvatarUtil getAvatar:channelInfo.channel.channelId cacheKey:channelInfo.avatarCacheKey];
        }
        hasChange = true;
    }
    // ：实名状态变化也要触发局部刷新。WKRealnamePrefetcher 把 realname_verified
    // 写进 person 缓存后会回调 channelInfoUpdate；如果只比 name/online/avatar 那几项，
    // 拉取来的实名 @YES 会被吞掉 → cell 不更新 → 用户看不到徽章（除非打开名片）。
    {
        id newFlag = channelInfo.extra[@"realname_verified"];
        id oldFlag = existCellModel.channelInfo.extra[@"realname_verified"];
        BOOL same = (newFlag == oldFlag) || (newFlag && oldFlag && [newFlag isEqual:oldFlag]);
        if (!same) {
            existCellModel.channelInfo = channelInfo;
            hasChange = true;
        }
    }
    if(hasChange && existIndexPath) {
        // 局部刷新单行，不做全量 reloadData
        // Bugly build55 兜底：tv/items 漂移时 reloadRows 会触发 NSInternalInconsistencyException
        if (![self isTableViewInSyncWithItems]) {
            [self.tableView reloadData];
        } else {
            @try {
                [self.tableView reloadRowsAtIndexPaths:@[existIndexPath]
                                      withRowAnimation:UITableViewRowAnimationNone];
            } @catch (NSException *ex) {
                NSLog(@"[WKContactsVC] update reloadRows drift caught: %@, fallback reloadData", ex);
                [self.tableView reloadData];
            }
        }
    }
    // 注意：不更新 allContactInfos。allContactInfos 只由 applyIncrementalUpdate（API数据）维护，
    // 避免 DB 版本的 robot 等字段与 API 不一致导致计数错误。cellModel 已更新，显示是对的。
}

-(void) addContactsWithChannelInfo:(WKChannelInfo*)channelInfo {
    NSInteger i = 0;
    NSString *newFirstLetter = [WKChineseSort getFirstLetter:channelInfo.displayName];
    if(!newFirstLetter) {
        newFirstLetter = @"#";
    }
    BOOL has = false;
    for (NSString *letter in self.sectionTitleArr) {
        if([newFirstLetter isEqualToString:letter]) {
            NSMutableArray *items = self.items[i+1];
            WKContactsCellModel *cellModel = [self toContactsCellModel:channelInfo];

            // Bugly build55 兜底：mutate items 前先校验 tv/items 是否同步。
            // 不同步就 mutate 后 reloadData 收敛；同步则走 insertRows + @try 兜底。
            BOOL inSyncBefore = [self isTableViewInSyncWithItems];
            [items insertObject:cellModel atIndex:0];
            has = true;

            if (!inSyncBefore) {
                [self.tableView reloadData];
            } else {
                NSIndexPath *insertPath = [NSIndexPath indexPathForRow:0 inSection:i+1];
                @try {
                    [self.tableView insertRowsAtIndexPaths:@[insertPath]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                } @catch (NSException *ex) {
                    NSLog(@"[WKContactsVC] insertRows drift caught: %@, fallback reloadData", ex);
                    [self.tableView reloadData];
                }
            }
            break;
        }
        i++;
    }
    if(!has) {
        // 没有对应的字母索引，需要新 section，降级为全量重建
        if (self.allContactInfos) {
            BOOL alreadyExists = NO;
            for (WKChannelInfo *info in self.allContactInfos) {
                if ([info.channel.channelId isEqualToString:channelInfo.channel.channelId]) {
                    alreadyExists = YES;
                    break;
                }
            }
            if (!alreadyExists) {
                NSMutableArray *mutable = [self.allContactInfos mutableCopy];
                [mutable addObject:channelInfo];
                self.allContactInfos = mutable;
                [self logContactsCounts:[NSString stringWithFormat:@"SET(addContact-noSection uid=%@)", channelInfo.channel.channelId]];
            }
            [self rebuildTableData];
            return;
        }
    }

    // 维护 allContactInfos 数组（防重复）
    if (self.allContactInfos) {
        BOOL alreadyExists = NO;
        for (WKChannelInfo *info in self.allContactInfos) {
            if ([info.channel.channelId isEqualToString:channelInfo.channel.channelId]) {
                alreadyExists = YES;
                break;
            }
        }
        if (!alreadyExists) {
            NSLog(@"[ContactsBug] addContactsWithChannelInfo ADD uid=%@ robot=%d isUpdating=%d isBatch=%d allCount=%lu→%lu",
                  channelInfo.channel.channelId, channelInfo.robot, self.isUpdating, self.isBatchUpdating,
                  (unsigned long)self.allContactInfos.count, (unsigned long)self.allContactInfos.count + 1);
            NSMutableArray *mutable = [self.allContactInfos mutableCopy];
            [mutable addObject:channelInfo];
            self.allContactInfos = mutable;
            [self logContactsCounts:[NSString stringWithFormat:@"SET(addContact uid=%@)", channelInfo.channel.channelId]];
        }
    }
    // 局部更新 header 计数
    [self updateHeaderCountsIfNeeded];
}

-(void) removeContacts:(NSString*)uid {
    if(!uid || self.items.count<=1) {
        return;
    }
    NSIndexPath *existIndexPath;
    for (NSInteger i=1; i<self.items.count; i++) {
        NSMutableArray *contactsItems = self.items[i];
        NSInteger k = 0;
        for (WKContactsCellModel *cellModel in contactsItems) {
            if([uid isEqualToString:cellModel.uid]) {
                existIndexPath = [NSIndexPath indexPathForRow:k inSection:i];
                break;
            }
            k++;
        }
    }
    if(existIndexPath) {
        NSMutableArray *contactsItems = self.items[existIndexPath.section];
        if(contactsItems.count > existIndexPath.row) {
            [contactsItems removeObjectAtIndex:existIndexPath.row];
        }

        // Bugly build55 兜底：mutate 前 tv/items 漂移就直接 reloadData，不再走增量 delete。
        // （注意：上面 contactsItems 已经 remove，但 reloadData 会以最新 items 重建，无碍）
        BOOL inSyncForDelete = ((NSInteger)contactsItems.count + 1 == [self.tableView numberOfRowsInSection:existIndexPath.section]);

        if(contactsItems.count == 0) {
            // section 清空：需要同时删除行和 section
            if (self.items.count > existIndexPath.section) {
                [self.items removeObjectAtIndex:existIndexPath.section];
            }
            if (self.sectionTitleArr.count > existIndexPath.section-1) {
                [self.sectionTitleArr removeObjectAtIndex:existIndexPath.section-1];
            }

            if (!inSyncForDelete) {
                [self.tableView reloadData];
            } else {
                @try {
                    [self.tableView beginUpdates];
                    [self.tableView deleteRowsAtIndexPaths:@[existIndexPath]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                    [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:existIndexPath.section]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
                    [self.tableView endUpdates];
                } @catch (NSException *ex) {
                    NSLog(@"[WKContactsVC] delete rows+section drift caught: %@, fallback reloadData", ex);
                    [self.tableView reloadData];
                }
            }
        } else {
            // 局部删除单行
            if (!inSyncForDelete) {
                [self.tableView reloadData];
            } else {
                @try {
                    [self.tableView deleteRowsAtIndexPaths:@[existIndexPath]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                } @catch (NSException *ex) {
                    NSLog(@"[WKContactsVC] delete rows drift caught: %@, fallback reloadData", ex);
                    [self.tableView reloadData];
                }
            }
        }

        // 维护 allContactInfos 数组
        if (self.allContactInfos) {
            NSMutableArray *mutable = [self.allContactInfos mutableCopy];
            NSInteger idx = NSNotFound;
            for (NSInteger i = 0; i < mutable.count; i++) {
                WKChannelInfo *info = mutable[i];
                if ([info.channel.channelId isEqualToString:uid]) {
                    idx = i;
                    break;
                }
            }
            if (idx != NSNotFound) {
                NSString *removedUid = ((WKChannelInfo *)mutable[idx]).channel.channelId;
                [mutable removeObjectAtIndex:idx];
                self.allContactInfos = mutable;
                [self logContactsCounts:[NSString stringWithFormat:@"SET(removeContact uid=%@)", removedUid]];
            }
        }
        // 局部更新 header 计数
        [self updateHeaderCountsIfNeeded];
    }
}

#pragma mark - WKChannelManagerDelegate

- (void)channelInfoUpdate:(WKChannelInfo *)channelInfo oldChannelInfo:(WKChannelInfo *)oldChannelInfo {
    if (self.isBatchUpdating) return;
    if (self.isUpdating) return;
    if(channelInfo.channel.channelType == WK_PERSON && channelInfo.follow == WKChannelInfoFollowFriend) {
        if ([channelInfo.channel.channelId isEqualToString:[WKApp shared].loginInfo.uid]) return;
        [self addOrUpdateContactsWithChannelInfo:channelInfo];
    }
}

- (void)channelInfoDelete:(WKChannel *)channel oldChannelInfo:(WKChannelInfo *)oldChannelInfo {
    if(channel.channelType == WK_PERSON && oldChannelInfo.follow == WKChannelInfoFollowFriend) {
        [self removeContacts:channel.channelId];
    }
}

#pragma mark - 增量对比更新

// 比较两个 WKChannelInfo 的UI相关属性是否相同
-(BOOL) isContactInfoEqual:(WKChannelInfo*)a to:(WKChannelInfo*)b {
    if (a.robot != b.robot) return NO;
    if (![a.displayName isEqualToString:b.displayName ?: @""]) return NO;
    if (a.online != b.online) return NO;
    if (a.lastOffline != b.lastOffline) return NO;
    if (![(a.logo ?: @"") isEqualToString:(b.logo ?: @"")]) return NO;
    if (![(a.avatarCacheKey ?: @"") isEqualToString:(b.avatarCacheKey ?: @"")]) return NO;
    if (![(a.category ?: @"") isEqualToString:(b.category ?: @"")]) return NO;
    return YES;
}

// 增量对比更新核心方法：对比新旧数据，只做局部插入/更新/删除
-(void) applyIncrementalUpdate:(NSArray<WKChannelInfo*>*)newInfos {
    NSAssert([NSThread isMainThread], @"applyIncrementalUpdate must be on main thread");

    // 防御性去重：按 uid 去重，保留最后出现的（防止上游数据源偶发重复）
    NSMutableDictionary<NSString*, WKChannelInfo*> *dedup = [NSMutableDictionary dictionaryWithCapacity:newInfos.count];
    NSMutableArray<NSString*> *order = [NSMutableArray arrayWithCapacity:newInfos.count];
    for (WKChannelInfo *info in newInfos) {
        NSString *uid = info.channel.channelId;
        if (!uid) continue;
        if (!dedup[uid]) [order addObject:uid];
        dedup[uid] = info;
    }
    if (dedup.count != newInfos.count) {
        NSLog(@"[ContactsBug] ⚠️ applyIncrementalUpdate 检测到重复！原始=%lu 去重后=%lu",
              (unsigned long)newInfos.count, (unsigned long)dedup.count);
        NSMutableDictionary<NSString*, NSNumber*> *uidCounts = [NSMutableDictionary dictionary];
        for (WKChannelInfo *info in newInfos) {
            NSString *uid = info.channel.channelId ?: @"nil";
            uidCounts[uid] = @([uidCounts[uid] integerValue] + 1);
        }
        for (NSString *uid in uidCounts) {
            if ([uidCounts[uid] integerValue] > 1) {
                NSLog(@"[ContactsBug]   重复uid: %@ ×%@", uid, uidCounts[uid]);
            }
        }
        NSMutableArray<WKChannelInfo*> *dedupedInfos = [NSMutableArray arrayWithCapacity:order.count];
        for (NSString *uid in order) {
            [dedupedInfos addObject:dedup[uid]];
        }
        newInfos = dedupedInfos;
    }

    NSArray<WKChannelInfo*> *oldInfos = self.allContactInfos ?: @[];

    // 建立 uid -> WKChannelInfo 映射表（O(1) 查找）
    NSMutableDictionary<NSString*, WKChannelInfo*> *oldMap = [NSMutableDictionary dictionaryWithCapacity:oldInfos.count];
    for (WKChannelInfo *info in oldInfos) {
        oldMap[info.channel.channelId] = info;
    }
    NSMutableDictionary<NSString*, WKChannelInfo*> *newMap = dedup;

    // 分类变化
    NSMutableArray<WKChannelInfo*> *toInsert = [NSMutableArray array];
    NSMutableArray<WKChannelInfo*> *toUpdate = [NSMutableArray array];
    NSMutableArray<NSString*>      *toDelete = [NSMutableArray array];

    for (WKChannelInfo *info in newInfos) {
        WKChannelInfo *oldInfo = oldMap[info.channel.channelId];
        if (!oldInfo) {
            [toInsert addObject:info];
        } else if (![self isContactInfoEqual:info to:oldInfo]) {
            [toUpdate addObject:info];
        }
    }
    for (WKChannelInfo *info in oldInfos) {
        if (!newMap[info.channel.channelId]) {
            [toDelete addObject:info.channel.channelId];
        }
    }

    // 更新主列表
    self.allContactInfos = newInfos;
    [self logContactsCounts:@"SET(applyIncrementalUpdate)"];

    // 无任何变化时只更新 header 计数
    if (toInsert.count == 0 && toUpdate.count == 0 && toDelete.count == 0) {
        [self updateHeaderCountsIfNeeded];
        return;
    }

    NSLog(@"[Contacts] 增量更新: insert=%lu, update=%lu, delete=%lu",
          (unsigned long)toInsert.count, (unsigned long)toUpdate.count, (unsigned long)toDelete.count);

    BOOL needsFullRebuild = NO;

    // 处理删除
    if (toDelete.count > 0) {
        [self performBatchDeletes:toDelete needsFullRebuild:&needsFullRebuild];
    }

    // 处理更新（名字变化可能导致首字母变化，需要 rebuild）
    if (toUpdate.count > 0 && !needsFullRebuild) {
        [self performBatchUpdates:toUpdate needsFullRebuild:&needsFullRebuild];
    }

    // 处理插入
    if (toInsert.count > 0 && !needsFullRebuild) {
        [self performBatchInserts:toInsert needsFullRebuild:&needsFullRebuild];
    }

    if (needsFullRebuild) {
        self.currentContactsFingerprint = nil;
        [self rebuildTableData];
    }

    // 更新 header 计数
    [self updateHeaderCountsIfNeeded];
}

// 批量更新已有联系人（原地更新 cellModel）
-(void) performBatchUpdates:(NSArray<WKChannelInfo*>*)updates needsFullRebuild:(BOOL*)needsRebuild {
    NSMutableArray<NSIndexPath*> *indexPathsToReload = [NSMutableArray array];

    for (WKChannelInfo *info in updates) {
        NSString *newFirstLetter = [WKChineseSort getFirstLetter:info.displayName] ?: @"#";

        // 在 items 中查找已有 cell
        NSIndexPath *existingPath = nil;
        WKContactsCellModel *existingModel = nil;
        for (NSInteger s = 1; s < (NSInteger)self.items.count; s++) {
            NSMutableArray *section = self.items[s];
            for (NSInteger r = 0; r < (NSInteger)section.count; r++) {
                WKContactsCellModel *model = section[r];
                if ([model.uid isEqualToString:info.channel.channelId]) {
                    existingPath = [NSIndexPath indexPathForRow:r inSection:s];
                    existingModel = model;
                    break;
                }
            }
            if (existingPath) break;
        }

        if (!existingPath || !existingModel) continue;

        // 检查首字母是否变化（名字改变可能导致分组变化）
        NSString *oldFirstLetter = (existingPath.section - 1 < (NSInteger)self.sectionTitleArr.count)
            ? self.sectionTitleArr[existingPath.section - 1] : @"#";

        if (![newFirstLetter isEqualToString:oldFirstLetter]) {
            *needsRebuild = YES;
            return;
        }

        // 原地更新 model 属性
        existingModel.name = info.displayName;
        existingModel.online = info.online;
        existingModel.lastOffline = info.lastOffline;
        existingModel.channelInfo = info;
        existingModel.robot = info.robot;
        if (info.logo) {
            NSString *key = (info.avatarCacheKey.length > 0) ? info.avatarCacheKey : @"0";
            NSString *fullUrl = [WKAvatarUtil getFullAvatarWIthPath:info.logo];
            NSString *separator = [fullUrl containsString:@"?"] ? @"&" : @"?";
            existingModel.avatar = [NSString stringWithFormat:@"%@%@v=%@", fullUrl, separator, key];
        } else {
            existingModel.avatar = [WKAvatarUtil getAvatar:info.channel.channelId cacheKey:info.avatarCacheKey];
        }

        [indexPathsToReload addObject:existingPath];
    }

    if (indexPathsToReload.count > 0) {
        [self.tableView reloadRowsAtIndexPaths:indexPathsToReload
                              withRowAnimation:UITableViewRowAnimationNone];
    }
}

// 批量插入新联系人
-(void) performBatchInserts:(NSArray<WKChannelInfo*>*)inserts needsFullRebuild:(BOOL*)needsRebuild {
    // 按首字母分组
    NSMutableDictionary<NSString*, NSMutableArray<WKChannelInfo*>*> *grouped = [NSMutableDictionary dictionary];
    for (WKChannelInfo *info in inserts) {
        NSString *letter = [WKChineseSort getFirstLetter:info.displayName] ?: @"#";
        if (!grouped[letter]) grouped[letter] = [NSMutableArray array];
        [grouped[letter] addObject:info];
    }

    // 检查所有目标 section 是否已存在
    NSSet<NSString*> *existingLetters = [NSSet setWithArray:self.sectionTitleArr ?: @[]];
    for (NSString *letter in grouped.allKeys) {
        if (![existingLetters containsObject:letter]) {
            // 需要新 section，降级为全量重建
            *needsRebuild = YES;
            return;
        }
    }

    // 所有目标 section 都存在，执行批量插入
    [self.tableView beginUpdates];

    NSMutableArray<NSIndexPath*> *insertPaths = [NSMutableArray array];

    for (NSString *letter in grouped) {
        NSInteger sectionIdx = [self.sectionTitleArr indexOfObject:letter];
        if (sectionIdx == NSNotFound) {
            *needsRebuild = YES;
            [self.tableView endUpdates];
            return;
        }
        NSInteger tableSection = sectionIdx + 1; // +1 跳过 header section

        NSMutableArray *sectionItems = self.items[tableSection];

        for (WKChannelInfo *info in grouped[letter]) {
            WKContactsCellModel *cellModel = [self toContactsCellModel:info];
            [sectionItems insertObject:cellModel atIndex:0];
            [insertPaths addObject:[NSIndexPath indexPathForRow:0 inSection:tableSection]];
        }
    }

    [self.tableView insertRowsAtIndexPaths:insertPaths
                          withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView endUpdates];
}

// 批量删除联系人
-(void) performBatchDeletes:(NSArray<NSString*>*)deleteUids needsFullRebuild:(BOOL*)needsRebuild {
    NSSet<NSString*> *deleteSet = [NSSet setWithArray:deleteUids];

    NSMutableArray<NSIndexPath*> *deletePaths = [NSMutableArray array];
    NSMutableIndexSet *emptySections = [NSMutableIndexSet indexSet];

    // 查找所有要删除的 indexPath，并从数据源移除
    for (NSInteger s = 1; s < (NSInteger)self.items.count; s++) {
        NSMutableArray *section = self.items[s];
        NSMutableIndexSet *rowsToRemove = [NSMutableIndexSet indexSet];

        for (NSInteger r = 0; r < (NSInteger)section.count; r++) {
            WKContactsCellModel *model = section[r];
            if ([deleteSet containsObject:model.uid]) {
                [deletePaths addObject:[NSIndexPath indexPathForRow:r inSection:s]];
                [rowsToRemove addIndex:r];
            }
        }

        [section removeObjectsAtIndexes:rowsToRemove];

        if (section.count == 0) {
            [emptySections addIndex:s];
        }
    }

    if (deletePaths.count == 0) return;

    if (emptySections.count > 0) {
        [self.tableView beginUpdates];
        [self.tableView deleteRowsAtIndexPaths:deletePaths
                              withRowAnimation:UITableViewRowAnimationAutomatic];
        // 倒序移除空 section（保持索引正确）
        [emptySections enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop) {
            [self.items removeObjectAtIndex:idx];
            if (idx - 1 < self.sectionTitleArr.count) {
                [self.sectionTitleArr removeObjectAtIndex:idx - 1];
            }
        }];
        [self.tableView deleteSections:emptySections
                      withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView endUpdates];
    } else {
        [self.tableView deleteRowsAtIndexPaths:deletePaths
                              withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

// 局部更新 header 计数（section 0 的 header items + section 1 的过滤计数 + footer 文字）
-(void) updateHeaderCountsIfNeeded {
    if (self.items.count == 0) return;

    // 重建 header items（带最新计数）
    NSArray *newHeaderItems = [self buildHeaderItemsWithCounts];
    [self.items replaceObjectAtIndex:0 withObject:[NSMutableArray arrayWithArray:newHeaderItems]];

    // 局部刷新 section 0（header items 行）
    NSMutableArray<NSIndexPath*> *headerPaths = [NSMutableArray array];
    for (NSInteger r = 0; r < (NSInteger)self.items[0].count; r++) {
        [headerPaths addObject:[NSIndexPath indexPathForRow:r inSection:0]];
    }
    [self.tableView reloadRowsAtIndexPaths:headerPaths
                          withRowAnimation:UITableViewRowAnimationNone];

    // 刷新 section 1 的 header view（过滤按钮上的 全部/AI/人类 数字）
    if (self.items.count > 1) {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                      withRowAnimation:UITableViewRowAnimationNone];
    }

    // filter pill 已迁到顶部固定栏，count 变化要单独刷新
    [self refreshFilterTabContainer];

    // 更新 footer 联系人数量文字
    NSArray<WKChannelInfo*> *filtered = [self filteredContactInfos];
    NSString *fSuffix = (self.contactsFilter == 1) ? @" AI" : LLang(@"联系人");
    self.contactsCountLbl.text = [NSString stringWithFormat:@"%@ %ld %@%@", LLang(@"共"), (long)filtered.count, LLang(@"位"), fSuffix];

    [self refreshTaBarItemBadgeValue:self.tabBarItem];
}

@end
