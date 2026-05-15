//
//  WKContactsSelectVC.m
//  WuKongContacts
//
//  Created by tt on 2019/12/7.
//

#import "WKContactsSelectVC.h"
#import "WKContactsSelectCell.h"
#import "WKChineseSort.h"
#import "WKContactsManager.h"
#import "WKBarUserSearchView.h"
#import "WKContacts.h"
#import "WKRealnamePrefetcher.h"
#import  "UIBarButtonItem+WK.h"
#import "WKAPIClient.h"
#import "WKAvatarUtil.h"
//头部视图高度
#define HEAD_VIEW_HEIGHT 50
#define FILTER_TAB_HEIGHT 50

@interface WKContactsSelectVC ()<UITableViewDataSource,UITableViewDelegate,WKContactsManagerDelegate>

@property(nonatomic,strong) NSArray *sectionTitleArr; //排序后的出现过的拼音首字母数组
@property(nonatomic,strong) NSMutableArray<NSArray*> *items;
// Generation token: 每次 parseData 重置时 +1，sortAndGroup 异步回调写入前对比,
// 只接受最新 generation 的结果。避免快速搜索时旧异步回调把过期数据混进新 items 容器,
// 造成 sectionTitleArr 与 items 不一致或列表显示错误联系人。
// (Jerry-Xin R3 review fix, YUJ-418)
@property(nonatomic,assign) NSInteger parseGeneration;
/// 默认被选中的用户集合
@property(nonatomic, strong) NSMutableArray<WKContactsSelect*> *selectedArray;

@property(nonatomic, strong) WKBarUserSearchView *searchBar;

@property(nonatomic,strong) UIView *mentionAllHeader;

@property(nonatomic,assign) BOOL notGetChannel; // 不去获取频道的名字

@property(nonatomic, assign) NSInteger contactsFilter; // 0=全部 1=人类 2=AI
@property(nonatomic, strong) UIView *filterTabView;

@end

@implementation WKContactsSelectVC

-(instancetype) init {
    self = [super init];
    if(self) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if(self.showBack) {
        [self.navigationBar setShowBackButton:YES];
    }

    self.items = [NSMutableArray array];

    [self refreshRightItem];
    //添加搜索bar
    [self.view addSubview:self.searchBar];
    // 添加过滤tab
    [self.view addSubview:self.filterTabView];

    [self requestData];

    [self rebuildFilterTabView];
    [self applyFilterAndSearch];
    if (!self.maxSelectMembers) {
        self.maxSelectMembers = self.data.count;
    }

    // YUJ-381 (#118 review fix): 选人列表也要听 prefetcher 回写通知。
    // WKContactsSelectCell 在 person 缓存无 realname 时触发 prefetch，
    // /users/<uid> 返回前 cell 已经渲染完，没这个监听就要等 cell 被回收
    // 重建才能看见徽章 —— 复现「选人列表覆盖不可靠」review 评论。
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(realnameVerifiedUpdated:)
                                                 name:WKRealnameVerifiedUpdatedNotification
                                               object:nil];
}

-(void) realnameVerifiedUpdated:(NSNotification *)noti {
    NSString *uid = noti.userInfo[@"uid"];
    if (uid.length == 0) return;
    NSMutableArray<NSIndexPath *> *paths = [NSMutableArray array];
    for (NSInteger s = 0; s < (NSInteger)self.items.count; s++) {
        NSArray *section = self.items[s];
        for (NSInteger r = 0; r < (NSInteger)section.count; r++) {
            id obj = section[r];
            if ([obj isKindOfClass:[WKContactsSelect class]]) {
                WKContactsSelect *m = (WKContactsSelect *)obj;
                if ([m.uid isEqualToString:uid]) {
                    [paths addObject:[NSIndexPath indexPathForRow:r inSection:s]];
                }
            }
        }
    }
    if (paths.count > 0) {
        [self.tableView reloadRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (NSString *)langTitle {
    return self.title;
}

-(void) requestData {
    if(!self.data) {
        self.data = [[WKApp shared] invoke:WKPOINT_CONTACTS_SELECT_DATA param:nil];
    }
    if(self.data && self.data.count>0) {
        for (WKContactsSelect *contactsSelect in self.data) {
            contactsSelect.selected = self.selecteds?[self.selecteds containsObject:contactsSelect.uid]:contactsSelect.selected;
            contactsSelect.disable = self.disables?[self.disables containsObject:contactsSelect.uid]:contactsSelect.disable;
            contactsSelect.mode = self.mode;
        }
    }
    // Space 模式下，异步过滤 robot 联系人，只保留当前空间已添加的 AI
    // 与通讯录 WKBotListVM.requestBots 逻辑保持一致
    [self filterRobotContactsForCurrentSpace];
}

/// 选人页 robot 过滤口径（YUJ-xxx 修复）：
/// 1. 系统账号（fileHelperUID / systemUID）永久排除 —— 即便 DB 里 robot=YES。
/// 2. Space 模式下，初始就把所有 robot 从 self.data 剔除（兜底防御），
///    避免 API 未返回/失败时短暂或长期看到「全部 AI」。
/// 3. 三个接口求并集 = my_bots ∪ space_bots(status=added) ∪ space.members(robot=YES)，
///    与通讯录页 myBotCount 计数口径对齐，覆盖「我添加的别人的 AI（作为 space 成员）」。
/// 4. 任一接口失败时不退化到「保留全部」，只把已成功接口拿到的 added 加回；
///    全部失败则 AI 列表为空 —— 用户重进页面会重试。
/// 5. 用户没进过通讯录页时 DB 里没有 my_bots 的 channelInfo —— 此时
///    根据 API 返回的 name/avatar 现场构造 WKContactsSelect 补入，避免缺项。
- (void)filterRobotContactsForCurrentSpace {
    // 永久排除系统账号（与 Space 模式无关）
    if (self.data && self.data.count > 0) {
        NSMutableArray *withoutSystem = [NSMutableArray array];
        for (WKContactsSelect *item in self.data) {
            if ([[WKApp shared] isSystemAccount:item.uid]) continue;
            [withoutSystem addObject:item];
        }
        if (withoutSystem.count != self.data.count) {
            self.data = withoutSystem;
        }
    }

    NSString *spaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (!spaceId || spaceId.length == 0) {
        // 非 Space 模式，不再过滤 robot
        return;
    }

    // Space 模式：先抽出所有 robot 暂存，self.data 立刻只剩 human + 0 AI。
    // 这样在 API 回来之前，「已添加 AI」分组不会出现任何错乱数据。
    NSMutableArray<WKContactsSelect*> *originalRobots = [NSMutableArray array];
    NSMutableArray<WKContactsSelect*> *humansOnly = [NSMutableArray array];
    for (WKContactsSelect *item in self.data) {
        if (item.robot) {
            [originalRobots addObject:item];
        } else {
            [humansOnly addObject:item];
        }
    }
    self.data = humansOnly;
    [self rebuildFilterTabView];
    [self applyFilterAndSearch];

    __weak typeof(self) weakSelf = self;
    dispatch_group_t group = dispatch_group_create();
    // 串行队列保证对 addedUids / uidInfo 的写操作无竞争
    dispatch_queue_t safeQ = dispatch_queue_create("com.wk.filterRobots", DISPATCH_QUEUE_SERIAL);
    __block NSMutableSet *addedUids = [NSMutableSet set];
    // uid -> {name, avatar?} 用于 DB 缺项时现场构造 WKContactsSelect。
    // 不同接口先后到达时直接覆盖，最后一个赢即可（字段都是 bot 自身属性，与 space 无关）。
    __block NSMutableDictionary<NSString*, NSDictionary*> *uidInfo = [NSMutableDictionary dictionary];

    // 1) my_bots：当前用户在该 space 下添加的 AI（含「我添加的别人的 AI」）
    dispatch_group_enter(group);
    [[WKAPIClient sharedClient] taskGET:@"robot/my_bots"
                             parameters:@{@"space_id": spaceId}
                               callback:^(NSError *error, id result) {
        dispatch_async(safeQ, ^{
            if (!error && [result isKindOfClass:[NSArray class]]) {
                for (id item in (NSArray *)result) {
                    NSDictionary *m = [item isKindOfClass:[NSDictionary class]] ? item : nil;
                    NSString *uid = m[@"uid"];
                    if (uid.length == 0) continue;
                    [addedUids addObject:uid];
                    uidInfo[uid] = @{ @"name": m[@"name"] ?: @"" };
                }
            }
            dispatch_group_leave(group);
        });
    }];

    // 2) space_bots：只取 status=added
    dispatch_group_enter(group);
    [[WKAPIClient sharedClient] taskGET:@"robot/space_bots"
                             parameters:@{@"space_id": spaceId}
                               callback:^(NSError *error, id result) {
        dispatch_async(safeQ, ^{
            if (!error && [result isKindOfClass:[NSArray class]]) {
                for (id item in (NSArray *)result) {
                    NSDictionary *bot = [item isKindOfClass:[NSDictionary class]] ? item : nil;
                    NSString *uid = bot[@"uid"];
                    NSString *status = bot[@"status"];
                    if (uid.length == 0 || ![status isEqualToString:@"added"]) continue;
                    [addedUids addObject:uid];
                    if (!uidInfo[uid]) uidInfo[uid] = @{ @"name": bot[@"name"] ?: @"" };
                }
            }
            dispatch_group_leave(group);
        });
    }];

    // 3) space members：覆盖「别人的 AI」作为 space 共享成员的情况
    dispatch_group_enter(group);
    NSString *membersPath = [NSString stringWithFormat:@"space/%@/members", spaceId];
    [[WKAPIClient sharedClient] taskGET:membersPath
                             parameters:@{@"page": @"1", @"limit": @"10000"}
                               callback:^(NSError *error, id result) {
        dispatch_async(safeQ, ^{
            if (!error && [result isKindOfClass:[NSArray class]]) {
                for (id item in (NSArray *)result) {
                    NSDictionary *m = [item isKindOfClass:[NSDictionary class]] ? item : nil;
                    NSString *uid = m[@"uid"];
                    BOOL isRobot = m[@"robot"] ? [m[@"robot"] boolValue] : NO;
                    if (uid.length == 0 || !isRobot) continue;
                    [addedUids addObject:uid];
                    if (!uidInfo[uid]) {
                        NSMutableDictionary *info = [NSMutableDictionary dictionary];
                        info[@"name"] = m[@"name"] ?: @"";
                        if ([m[@"avatar"] isKindOfClass:[NSString class]] && [m[@"avatar"] length] > 0) {
                            info[@"avatar"] = m[@"avatar"];
                        }
                        uidInfo[uid] = info;
                    }
                }
            }
            dispatch_group_leave(group);
        });
    }];

    // 三个请求都完成后，在主线程把命中 addedUids 的 robot 加回 self.data。
    // 优先用 originalRobots（有 displayName/avatar 等已初始化字段），
    // 对 DB 缺失的 uid 用 API 返回字段现场构造。
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        // [Space race] 三个 API 飞行期间用户可能切了 Space —— 此时 NSUserDefaults
        // 里的 currentSpaceId 已变，但本次回调里 addedUids 还是旧 Space 的 Bot 集合。
        // 直接 apply 会让旧 Space 的 AI 列表写入新 Space 的视图。
        // 检测到不一致就丢弃本次结果；新 Space 的视图重建会重新触发本方法。
        NSString *nowSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
        if (![nowSpaceId isEqualToString:spaceId]) {
            NSLog(@"[ContactsSelect] Space switched mid-flight (%@ -> %@), drop stale robot list",
                  spaceId, nowSpaceId);
            return;
        }
        if (addedUids.count == 0) {
            // 全部接口失败或返回空 —— 保持 0 AI 状态，用户重进页面会重试
            return;
        }

        NSMutableArray<WKContactsSelect*> *robotsToAdd = [NSMutableArray array];
        NSMutableSet<NSString*> *includedUids = [NSMutableSet set];

        for (WKContactsSelect *item in originalRobots) {
            if ([addedUids containsObject:item.uid] && ![includedUids containsObject:item.uid]) {
                [robotsToAdd addObject:item];
                [includedUids addObject:item.uid];
            }
        }

        // 用 API 数据补 DB 缺项（典型场景：用户没进过通讯录页，DB 里没有「我添加的别人的 AI」）
        for (NSString *uid in addedUids) {
            if ([includedUids containsObject:uid]) continue;
            if ([[WKApp shared] isSystemAccount:uid]) continue;
            NSDictionary *info = uidInfo[uid];
            if (!info) continue;

            WKContactsSelect *contacts = [[WKContactsSelect alloc] init];
            contacts.uid = uid;
            contacts.name = info[@"name"] ?: @"";
            contacts.displayName = info[@"name"] ?: @"";
            NSString *apiAvatar = info[@"avatar"];
            if (apiAvatar.length > 0) {
                contacts.avatar = apiAvatar;
            } else {
                contacts.avatar = [WKAvatarUtil getAvatar:uid];
            }
            contacts.robot = YES;
            contacts.selected = strongSelf.selecteds ? [strongSelf.selecteds containsObject:uid] : NO;
            contacts.disable = strongSelf.disables ? [strongSelf.disables containsObject:uid] : NO;
            contacts.mode = strongSelf.mode;
            [robotsToAdd addObject:contacts];
            [includedUids addObject:uid];
        }

        if (robotsToAdd.count == 0) return;

        NSMutableArray *newData = [NSMutableArray arrayWithArray:strongSelf.data];
        [newData addObjectsFromArray:robotsToAdd];
        strongSelf.data = newData;
        [strongSelf rebuildFilterTabView];
        [strongSelf applyFilterAndSearch];
        if (!strongSelf.maxSelectMembers || strongSelf.maxSelectMembers < (NSInteger)strongSelf.data.count) {
            strongSelf.maxSelectMembers = strongSelf.data.count;
        }
    });
}

// 请求有效联系人数据
-(void) parseData:(NSArray<WKContactsSelect*>*) data {
    // Bump generation 方初始化,异步回调将根据 gen 识别老结果
    // (Jerry-Xin R3 fix, YUJ-418)
    NSInteger gen = ++self.parseGeneration;
    self.items = [NSMutableArray array];
    self.sectionTitleArr = @[];
    [self.tableView reloadData];
    if(data) {
        NSMutableArray *newData = [NSMutableArray array];
        for (WKContactsSelect *contactsSelect in data) {
            if(self.hiddenUsers && [self.hiddenUsers containsObject:contactsSelect.uid]) {
                continue;
            }
            [newData addObject:contactsSelect];
            
            if(!self.notGetChannel) {
               WKChannelInfo *channelInfo = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:contactsSelect.uid]]; // TODO: 成员多了 这里可能会影响性能
                if(channelInfo) {
                    contactsSelect.displayName = channelInfo.displayName;
                }
            }
        }
        [self sortAndGroup:newData generation:gen];
    }
}

- (WKBarUserSearchView *)searchBar {
    if(!_searchBar) {
        _searchBar = [[WKBarUserSearchView alloc] initWithFrame:CGRectMake(0, self.navigationBar.lim_bottom, WKScreenWidth, HEAD_VIEW_HEIGHT)];
        [_searchBar setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        __weak typeof(self) weakSelf = self;
        [_searchBar setRemoveIconBlock:^(WKBarUserSearchModel *model) {
            if(weakSelf.selectedArray) {
                for (WKContactsSelect *contactsSelect in weakSelf.selectedArray) {
                    if([contactsSelect.uid isEqualToString:model.sid]) {
                        contactsSelect.selected = false;
                        [weakSelf removeOrAddSelectedContacts:contactsSelect];
                        [weakSelf refreshRightItem];
                        [weakSelf.tableView reloadData];
                        break;
                    }
                }
            }
        }];
        [_searchBar setSearchDidChangeBlock:^(NSString *keyword) {
            [weakSelf searchTextChange:keyword];
        }];
    }
    return _searchBar;
}

-(void) searchTextChange:(NSString*)text {
    // 防抖：取消上一次搜索排序，避免信号量并发释放崩溃
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(doSearch:) object:nil];
    [self performSelector:@selector(doSearch:) withObject:text afterDelay:0.3];
}

-(void) doSearch:(NSString*)text {
    NSArray *baseData = [self filteredData];
    NSArray *data;
    if(!text || [text isEqualToString:@""]) {
        data = baseData;
    }else {
        data = [baseData filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name CONTAINS[c] %@ OR displayName CONTAINS[c] %@",text,text]];
    }

    [self parseData:data];
}

// 联系人排序和分组
// 采用 generation token 解决 Jerry-Xin R3 review 指出的 race:
// parseData 每次 bump generation 并传入此方法,异步 finish block 返回时对比
// weakSelf.parseGeneration 是否等于当初的 gen,不等则丢弃旧结果,
// 避免快速搜索时旧搜索回调污染新 items/sectionTitleArr。
// (YUJ-418)
-(void) sortAndGroup:(NSArray<WKContactsSelect*>*)items generation:(NSInteger)gen {
    __weak typeof(self) weakSelf = self;
    [WKChineseSort sortAndGroup:items key:@"displayName" finish:^(bool isSuccess, NSMutableArray *unGroupArr, NSMutableArray *sectionTitleArr, NSMutableArray<NSMutableArray *> *sortedObjArr) {
        if(!isSuccess || !weakSelf) return;
        // Generation check: 丢弃旧 generation 的回调
        if (weakSelf.parseGeneration != gen) return;
        weakSelf.sectionTitleArr = sectionTitleArr;
        [weakSelf.items addObjectsFromArray:sortedObjArr];
        [weakSelf.tableView reloadData];
    }];
}

// Legacy 入口 - 为兼容旧调用点留一个默认 gen=0 版本
// (实际当前 parseData 已全走带 gen 版本, 无外部调用, 保留仅为安全网)
-(void) sortAndGroup:(NSArray<WKContactsSelect*>*)items{
    [self sortAndGroup:items generation:self.parseGeneration];
}


-(void) backPressed {
    if(_showBack) {
        if (self.presentingViewController) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        else {
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }
    }
    else{
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    }
}


#pragma mark - table
-(UITableView *)tableView{
    if(!_tableView){
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0,HEAD_VIEW_HEIGHT + FILTER_TAB_HEIGHT +[self visibleRect].origin.y, self.view.lim_width, [self visibleRect].size.height - HEAD_VIEW_HEIGHT - FILTER_TAB_HEIGHT) style:UITableViewStyleGrouped];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        UIEdgeInsets separatorInset = _tableView.separatorInset;
        separatorInset.right = 0;
        _tableView.separatorInset = separatorInset;
        _tableView.backgroundColor=[UIColor clearColor];
        _tableView.sectionIndexColor = [UIColor blackColor];
        _tableView.sectionIndexBackgroundColor = [UIColor clearColor];
        
        _tableView.sectionIndexBackgroundColor = [UIColor clearColor];
        _tableView.tableFooterView = [[UIView alloc] init];
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.sectionHeaderHeight = 0.0f;
        _tableView.sectionFooterHeight = 0.0f;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        if(self.mentionAll) {
            _tableView.tableHeaderView = self.mentionAllHeader;
        }
        [_tableView registerClass:WKContactsSelectCell.class forCellReuseIdentifier:[WKContactsSelectCell cellId]];
        
        _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    }
    return _tableView;
}

-(UIView*) mentionAllHeader {
    if(!_mentionAllHeader) {
        _mentionAllHeader = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 60.0f)];
        _mentionAllHeader.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 45.0f, 45.0f)];
        [icon setImage:[self imageName:@"Conversation/Panel/MentionAll"]];
        
        [_mentionAllHeader addSubview:icon];
        icon.lim_centerY_parent = _mentionAllHeader;
        icon.lim_left = 15.0f;
        
        UILabel *nameLbl = [[UILabel alloc] init];
        nameLbl.text = LLang(@"@所有人");
        nameLbl.textColor = [WKApp shared].config.defaultTextColor;
        [nameLbl sizeToFit];
        
        nameLbl.lim_centerY_parent = _mentionAllHeader;
        nameLbl.lim_left = icon.lim_right + 10.0f;
        [_mentionAllHeader addSubview:nameLbl];
        
        _mentionAllHeader.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onMentionAllTap)];
        [_mentionAllHeader addGestureRecognizer:tap];
    }
    return  _mentionAllHeader;
}

-(void) onMentionAllTap {
    if(self.onFinishedSelect) {
        self.onFinishedSelect(@[@"all"]);
    }
}

-(void) loadView{
    [super loadView];
    [self.view addSubview:self.tableView];
}

// 头部字母部分
-(UIView*) headView:(NSString*)title headHeight:(CGFloat)headHheght color:(UIColor*)color{
    
    UIView *headView =[[UIView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, headHheght)];
    [headView setBackgroundColor: [WKApp shared].config.backgroundColor];
    UILabel  *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, headView.lim_width, headView.lim_height)];
    [titleLbl setFont:[[WKApp shared].config appFontOfSize:14.0f]];
    [titleLbl setTextColor:color];
    [titleLbl setText:title];
    [headView addSubview:titleLbl];
    return headView;
}

- (NSMutableArray *)selectedArray {
    NSMutableArray *items = [NSMutableArray array];
    for (WKContactsSelect *contact in self.data) {
        if(contact.selected) {
            [items addObject:contact];
        }
    }
    return items;
}

-(void) selectContacts:(WKContactsSelect*) contacts {
    
    [self removeOrAddSelectedContacts:contacts];
    [self removeOrAddBarUser:contacts];
    [self refreshRightItem];
    
}

-(void) refreshRightItem {
    if(self.mode == WKContactsModeSingle) {
        return;
    }
    if ([[self selectedArray] count] > 0) {
        NSString *rightTitle =
        [NSString stringWithFormat:@"%@(%i)", LLang(@"完成"),
         (int)[[self selectedArray] count]];
        [self setRightBarItem:rightTitle
               withDisable:false];
    } else {
        [self setRightBarItem:LLang(@"完成") withDisable:true];
    }
}

- (void) setRightBarItem:(NSString *)title
          withDisable:(BOOL)disable {
    
    if(disable) {
        self.rightView =
        [self barButtonItemWithTitle:title
                          titleColor:[[WKApp shared].config.navBarButtonColor colorWithAlphaComponent:0.5f] action:nil];
    }else {
        self.rightView =
        [self barButtonItemWithTitle:title
                          titleColor:[WKApp shared].config.navBarButtonColor
                              action:@selector(nextBtnPress)];
    }
    
    
}

-(void) removeOrAddSelectedContacts:(WKContactsSelect*) contacts {
    if (self.selectedArray.count >= _maxSelectMembers+1) {
        contacts.selected = false;
        [self.tableView reloadData];
        NSString * alertString = [NSString stringWithFormat:@"最多选择%ld人!",(long)_maxSelectMembers];
        [self.view showMsg:alertString];
        return;
    }
}

-(void) removeOrAddBarUser:(WKContactsSelect*) contacts {
    WKBarUserSearchModel *barmodel =
    [[WKBarUserSearchModel alloc] initWithSid:contacts.uid];
    barmodel.icon = contacts.avatar;
    if (contacts.selected) {
        [self.searchBar addModel:barmodel];
    } else {
        [self.searchBar removeModel:barmodel];
    }
}


//带标题的按钮样式
- (UIButton *)barButtonItemWithTitle:(NSString *)title
                                 titleColor:(UIColor *)titleColor
                                     action:(SEL)selector {
//    UIBarButtonItem *barBtnItem =
//    [UIBarButtonItem itemWithTarget:self
//                             action:selector
//                              title:title
//                         titleColor:titleColor
//                    titleEdgeInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
//    return barBtnItem;
    UIButton *barBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, 0.0f)];
    [barBtn addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [barBtn setTitle:title forState:UIControlStateNormal];
    [barBtn setTitleColor:titleColor forState:UIControlStateNormal];
//    [barBtn setBackgroundColor:[UIColor redColor]];
    [barBtn sizeToFit];
    return barBtn;
}
// 下一步点击
-(void) nextBtnPress  {
    NSMutableArray *uids = [NSMutableArray array];
    if(self.selectedArray) {
        for (WKContactsSelect *contactsSelect in self.selectedArray) {
            [uids addObject:contactsSelect.uid];
        }
    }
    if(self.onFinishedSelect) {
        self.onFinishedSelect(uids);
    }
}

#pragma mark UITableDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if (section >= (NSInteger)self.items.count) return 0;
    return  self.items[section].count;
}
-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section >= (NSInteger)self.items.count || indexPath.row >= (NSInteger)self.items[indexPath.section].count) {
        return [tableView dequeueReusableCellWithIdentifier:[WKContactsSelectCell cellId]] ?: [[UITableViewCell alloc] init];
    }
    id model =  self.items[indexPath.section][indexPath.row];
    WKContactsSelectCell *cell =  [tableView dequeueReusableCellWithIdentifier:[WKContactsSelectCell cellId]];
    WKContactsSelect *contactsSelectModel = (WKContactsSelect*)model;
    contactsSelectModel.first = indexPath.row == 0;
    contactsSelectModel.last = self.items[indexPath.section].count-1 == indexPath.row;
    contactsSelectModel.mode = self.mode;
    [cell refreshWithModel:model];
    __weak typeof(self) weakSelf =self;
    [cell setStateChangeCheckBk:^(WKContactsSelect * _Nonnull model) {
        [weakSelf clearSearch];
        [weakSelf selectContacts:model];
    }];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    return  60.0;
}

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section >= (NSInteger)self.sectionTitleArr.count) return 0;
    return 20.0f;
}
-(UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    if (section >= (NSInteger)self.sectionTitleArr.count) return nil;
    NSString *title = [self.sectionTitleArr objectAtIndex:section];
    return [self headView:title headHeight:20.0f color:[UIColor grayColor]];
}

//点击右侧索引表项时调用 索引与section的对应关系
- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return index;
}
//
//section右侧index数组
-(NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView{
    return self.sectionTitleArr;
}
//
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return self.sectionTitleArr.count;
}
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.section >= (NSInteger)self.items.count || indexPath.row >= (NSInteger)self.items[indexPath.section].count) return;
    WKContactsSelect *model =  self.items[indexPath.section][indexPath.row];
    if(model.mode == WKContactsModeSingle) {
        if(model && !model.disable) {
            if(self.onFinishedSelect) {
                self.onFinishedSelect(@[model.uid]);
            }
        }
       
    }else {
        if(model && !model.disable) {
            [self clearSearch];
           
            model.selected = !model.selected;
            [self.tableView reloadData];
            [self selectContacts:model];
           
        }
    }
   
}

-(void) clearSearch {
    if(![self.searchBar.searchFd.text isEqualToString:@""]) {
        self.searchBar.searchFd.text = @"";
        [self searchTextChange:@""];
    }
}

//- (UITabBarItem *)tabBarItem {
//    UITabBarItem *tabbarItem = [super tabBarItem];
//    int count = [[WKContactsManager shared] getFriendRequestUnreadCount];
//    if(count>0) {
//        tabbarItem.badgeValue = [NSString stringWithFormat:@"%d", [[WKContactsManager shared] getFriendRequestUnreadCount]];
//    }
//    return tabbarItem;
//}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

#pragma mark - Filter Tab

-(UIView*) filterTabView {
    if (!_filterTabView) {
        _filterTabView = [[UIView alloc] initWithFrame:CGRectMake(0, self.navigationBar.lim_bottom + HEAD_VIEW_HEIGHT, WKScreenWidth, FILTER_TAB_HEIGHT)];
        _filterTabView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    }
    return _filterTabView;
}

-(void) rebuildFilterTabView {
    for (UIView *sub in self.filterTabView.subviews) {
        [sub removeFromSuperview];
    }

    NSInteger totalCount = self.data ? self.data.count : 0;
    NSInteger aiCount = 0;
    NSInteger humanCount = 0;
    for (WKContactsSelect *item in self.data) {
        if (item.robot) aiCount++; else humanCount++;
    }

    NSArray *titles = @[
        [NSString stringWithFormat:@"%@ · %ld", LLang(@"全部"), (long)totalCount],
        [NSString stringWithFormat:@"%@ · %ld", LLang(@"人类"), (long)humanCount],
        [NSString stringWithFormat:@"%@ · %ld", LLang(@"已添加AI"), (long)aiCount]
    ];

    CGFloat hPad = 14.0f;
    CGFloat pillH = 34.0f;
    CGFloat pillY = (FILTER_TAB_HEIGHT - pillH) / 2.0f;

    UIView *pillBg = [[UIView alloc] initWithFrame:CGRectMake(hPad, pillY, WKScreenWidth - hPad * 2, pillH)];
    pillBg.backgroundColor = [self filterBgElevColor];
    pillBg.layer.cornerRadius = 10.0f;
    [self.filterTabView addSubview:pillBg];

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
            btn.backgroundColor = [WKApp shared].config.cellBackgroundColor;
            btn.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightBold];
            [btn setTitleColor:[WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
            btn.layer.shadowColor = [UIColor blackColor].CGColor;
            btn.layer.shadowOpacity = 0.08f;
            btn.layer.shadowOffset = CGSizeMake(0, 1);
            btn.layer.shadowRadius = 3.0f;
        } else {
            btn.backgroundColor = [UIColor clearColor];
            btn.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightMedium];
            [btn setTitleColor:[WKApp shared].config.tipColor forState:UIControlStateNormal];
            btn.layer.shadowOpacity = 0;
        }

        [pillBg addSubview:btn];
    }
}

-(UIColor*) filterBgElevColor {
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
    if (self.contactsFilter == sender.tag) return;
    self.contactsFilter = sender.tag;
    [self rebuildFilterTabView];
    [self applyFilterAndSearch];
}

-(NSArray<WKContactsSelect*>*) filteredData {
    if (!self.data) return @[];
    if (self.contactsFilter == 1) { // 人类
        NSMutableArray *result = [NSMutableArray array];
        for (WKContactsSelect *item in self.data) {
            if (!item.robot) [result addObject:item];
        }
        return result;
    } else if (self.contactsFilter == 2) { // AI
        NSMutableArray *result = [NSMutableArray array];
        for (WKContactsSelect *item in self.data) {
            if (item.robot) [result addObject:item];
        }
        return result;
    }
    return self.data;
}

-(void) applyFilterAndSearch {
    NSString *text = self.searchBar.searchFd.text;
    [self doSearch:text];
}

- (void)dealloc {
    NSLog(@"WKContactsSelectVC dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKRealnameVerifiedUpdatedNotification object:nil];
    if(self.onDealloc) {
        self.onDealloc();
    }
}
@end
