//
//  WKContactsVC.m
//  WuKongContacts
//
//  Created by tt on 2019/12/7.
//

#import "WKContactsVC.h"
#import "WKContactsCell.h"
#import <Masonry/Masonry.h>
#import "WKChineseSort.h"
#import "WKContactsHeaderItemCell.h"
#import "WKContactsManager.h"
#import "WKContactsSync.h"
#import "WKAvatarUtil.h"
#import "WKSearchbarView.h"
#import "WKGlobalSearchResultController.h"

@interface WKContactsVC ()<UITableViewDataSource,UITableViewDelegate,WKContactsManagerDelegate,WKChannelManagerDelegate>
@property(nonatomic,strong) UITableView *tableView;
@property(nonatomic,strong) NSMutableArray *sectionTitleArr; //排序后的出现过的拼音首字母数组
@property(nonatomic,strong) NSMutableArray<NSMutableArray*> *items;
@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,strong) WKSearchbarView *searchbarView;
@property(nonatomic,strong) UIView *tableHeader;

@property(nonatomic,strong) UILabel *contactsCountLbl; // 联系人数量

@property(nonatomic,strong) UILabel *sectionIndexIndicator; // 右侧索引字母指示器

@property(nonatomic,copy) NSString *currentContactsFingerprint; // 当前显示的联系人数据指纹

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
    // Do any additional setup after loading the view.
    
    self.navigationBar.title = LLang(@"联系人");
    [self requestData];
    
    [[WKSDK shared].channelManager addDelegate:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contactsUpdate:) name:WK_NOTIFY_CONTACTS_UPDATE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshContactsHeader) name:WK_NOTIFY_CONTACTS_HEADER_UPDATE object:nil];
   
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationBar.title = LLang(@"联系人");
    // 每次切换到通讯录时重新从数据库加载最新联系人数据
    [self requestData];
}



- (void)dealloc {
    NSLog(@"WKContactsVC dealloc...");
    [[WKSDK shared].channelManager removeDelegate:self];
    [[WKContactsManager shared] removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WK_NOTIFY_CONTACTS_UPDATE object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WK_NOTIFY_CONTACTS_HEADER_UPDATE object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WK_NOTIFY_CONTACTS_TAB_REDDOT_UPDATE object:nil];
}

// 开启大标题模式
- (BOOL)largeTitle {
    return true;
}

- (WKSearchbarView *)searchbarView {
    if(!_searchbarView) {
        _searchbarView = [[WKSearchbarView alloc] initWithFrame:CGRectMake(15.0f, 10.0f, WKScreenWidth - 30.0f, 36.0f)];
        _searchbarView.placeholder = LLang(@"搜索");
        _searchbarView.onClick = ^{
            WKGlobalSearchResultController *vc = [WKGlobalSearchResultController new];
            [[WKNavigationManager shared] pushViewController:vc animated:NO];
        };
    }
    return _searchbarView;
}

// 联系人数据更新（仅从本地 DB 刷新，不触发 API 请求，避免循环）
-(void) contactsUpdate:(NSNotification*)notify {
    NSArray<WKChannelInfo*> *dbInfos = [[WKChannelInfoDB shared] queryChannelInfosWithStatusAndFollow:WKChannelStatusNormal follow:WKChannelInfoFollowFriend];
    [self refreshContactsList:dbInfos ?: @[]];
}

-(void) refreshContactsHeader {
    if(self.items.count>0) {
        NSArray *headerItems = [[WKApp shared] invokes:WKPOINT_CATEGORY_CONTACTSITEM param:nil];
        if(self.items.count>0) {
            [self.items replaceObjectAtIndex:0 withObject:[NSMutableArray arrayWithArray:headerItems]];
        }
        [self.tableView reloadData];
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
        return; // 数据无变化，跳过刷新
    }
    self.currentContactsFingerprint = newFingerprint;

    self.contactsCountLbl.text = [NSString stringWithFormat:LLang(@"%ld个朋友"),(long)channelInfos.count];
    NSMutableArray *items = [NSMutableArray array];
    for (WKChannelInfo *info in channelInfos) {
        [items addObject:[self toContactsCellModel:info]];
    }
    // 重建 items（保留 header）
    NSArray *headerItems = [[WKApp shared] invokes:WKPOINT_CATEGORY_CONTACTSITEM param:nil];
    self.items = [NSMutableArray array];
    self.sectionTitleArr = [NSMutableArray array];
    [self.items insertObject:[NSMutableArray arrayWithArray:headerItems] atIndex:0];
    if (items.count > 0) {
        [self sortAndGroup:items];
    } else {
        [self.tableView reloadData];
    }
}

// 请求有效联系人数据（从 API 拉取最新数据）
-(void) requestData{
    // 确保 items 至少有 header section（防止空数组越界崩溃）
    if (self.items.count == 0) {
        NSArray *headerItems = [[WKApp shared] invokes:WKPOINT_CATEGORY_CONTACTSITEM param:nil];
        [self.items insertObject:[NSMutableArray arrayWithArray:headerItems] atIndex:0];
    }

    // 首次加载（无指纹）时先用本地数据快速显示
    if (!self.currentContactsFingerprint) {
        NSArray<WKChannelInfo*> *dbInfos = [[WKChannelInfoDB shared] queryChannelInfosWithStatusAndFollow:WKChannelStatusNormal follow:WKChannelInfoFollowFriend];
        if (dbInfos && dbInfos.count > 0) {
            [self refreshContactsList:dbInfos];
        }
    }

    // 从 API 拉取最新数据
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (currentSpaceId && currentSpaceId.length > 0) {
        [self fetchSpaceMembers:currentSpaceId];
    } else {
        [self fetchFriendContacts];
    }
}

// Space 模式：从 API 拉取成员列表
-(void) fetchSpaceMembers:(NSString*)spaceId {
    __weak typeof(self) weakSelf = self;
    NSString *path = [NSString stringWithFormat:@"space/%@/members", spaceId];
    [[WKAPIClient sharedClient] GET:path parameters:@{@"page":@"1", @"limit":@"10000"}].then(^(NSArray<NSDictionary*>* members){
        NSString *nowSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
        if (![spaceId isEqualToString:nowSpaceId]) return;

        NSMutableArray<WKChannelInfo*> *channelInfos = [NSMutableArray array];
        if (members && members.count > 0) {
            for (NSDictionary *m in members) {
                NSString *uid = m[@"uid"];
                if (!uid || [uid isEqualToString:[WKApp shared].loginInfo.uid]) continue;

                WKChannel *channel = [[WKChannel alloc] initWith:uid channelType:WK_PERSON];
                WKChannelInfo *channelInfo = [[WKSDK shared].channelManager getChannelInfo:channel];
                if (!channelInfo) {
                    channelInfo = [WKChannelInfo new];
                    channelInfo.channel = channel;
                }
                channelInfo.name = m[@"name"] ?: @"";
                channelInfo.logo = m[@"avatar"] ?: @"";
                if (!channelInfo.logo || [channelInfo.logo isEqualToString:@""]) {
                    channelInfo.logo = [NSString stringWithFormat:@"users/%@/avatar", uid];
                }
                channelInfo.follow = WKChannelInfoFollowFriend;
                channelInfo.status = 1;
                channelInfo.robot = m[@"robot"] ? [m[@"robot"] boolValue] : NO;
                if (m[@"category"] && ![m[@"category"] isEqual:[NSNull null]]) {
                    channelInfo.category = m[@"category"];
                }
                [channelInfos addObject:channelInfo];
            }
        }
        [[WKSDK shared].channelManager addOrUpdateChannelInfos:channelInfos];
        [weakSelf refreshContactsList:channelInfos];
    }).catch(^(NSError *error){
        WKLogError(@"拉取Space联系人失败:%@", error);
    });
}

// 个人模式：从 API 拉取好友列表
-(void) fetchFriendContacts {
    __weak typeof(self) weakSelf = self;
    NSString *cacheKey = [NSString stringWithFormat:@"%@_%@",[WKApp shared].loginInfo.uid,@"friend_version"];
    NSString *friendMaxVersion = [[NSUserDefaults standardUserDefaults] stringForKey:cacheKey];
    [[WKAPIClient sharedClient] GET:@"friend/sync" parameters:@{@"version":friendMaxVersion?:@"",@"api_version":@"1",@"limit":@(200)}].then(^(NSArray<NSDictionary*>* contacts){
        if(contacts && contacts.count > 0) {
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
            [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%lld",version] forKey:cacheKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[WKSDK shared].channelManager addOrUpdateChannelInfos:channelInfos];
        }
        // 从数据库重新加载（API 可能只返回增量数据）
        NSArray<WKChannelInfo*> *allInfos = [[WKChannelInfoDB shared] queryChannelInfosWithStatusAndFollow:WKChannelStatusNormal follow:WKChannelInfoFollowFriend];
        [weakSelf refreshContactsList:allInfos ?: @[]];
    }).catch(^(NSError *error){
        WKLogError(@"拉取好友联系人失败:%@", error);
    });
}

-(WKContactsCellModel*) toContactsCellModel:(WKChannelInfo*)channelInfo {
    WKContactsCellModel *contactsCellModel = [[WKContactsCellModel alloc] init];
    contactsCellModel.uid =channelInfo.channel.channelId;
    contactsCellModel.name = channelInfo.displayName;
    contactsCellModel.online = channelInfo.online;
    contactsCellModel.lastOffline = channelInfo.lastOffline;
    contactsCellModel.channelInfo = channelInfo;
    
    contactsCellModel.robot = channelInfo.robot;
    if(channelInfo.logo) {
        NSString *avatarURL = [[NSURL URLWithString:[WKAvatarUtil getFullAvatarWIthPath:channelInfo.logo]] absoluteString];
        contactsCellModel.avatar =avatarURL;
    }
    if([channelInfo.displayName isEqualToString:@"系统通知"]) {
        NSLog(@"[DEBUG] 系统通知 头像URL: %@, logo: %@, uid: %@", contactsCellModel.avatar, channelInfo.logo, channelInfo.channel.channelId);
    }
    return contactsCellModel;
}

// 联系人排序和分组
-(void) sortAndGroup:(NSArray*)items{
    __weak typeof(self) weakSelf = self;
    [WKChineseSort sortAndGroup:items key:@"name" finish:^(bool isSuccess, NSMutableArray *unGroupArr, NSMutableArray *sectionTitleArr, NSMutableArray<NSMutableArray *> *sortedObjArr) {
        if(isSuccess) {
            weakSelf.sectionTitleArr = sectionTitleArr;
            [weakSelf.items addObjectsFromArray:sortedObjArr];
            [weakSelf.tableView reloadData];
        }
    }];
}



#pragma mark - table

-(UIView*) tableHeader {
    if(!_tableHeader) {
        CGFloat emptyHeight = 15.0f;
        CGFloat emptyToSearchbarSpace = 10.0f;
        CGFloat searchbarViewTopSpace = 10.0f;
        _tableHeader = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, self.searchbarView.frame.size.height+emptyHeight + emptyToSearchbarSpace + searchbarViewTopSpace)];
        [_tableHeader addSubview:self.searchbarView];
        
        
        UIView *bottomEmptyView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.searchbarView.lim_bottom + emptyToSearchbarSpace, WKScreenWidth, emptyHeight)];
        [bottomEmptyView setBackgroundColor:WKApp.shared.config.cellBackgroundColor];
        [_tableHeader addSubview:bottomEmptyView];
    }
    return _tableHeader;
}

-(UITableView *)tableView{
    if(!_tableView){
        _tableView = [[UITableView alloc] initWithFrame:[self visibleRect] style:UITableViewStyleGrouped];
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
        [_tableView registerClass:WKContactsCell.class forCellReuseIdentifier:[WKContactsCell cellId]];
        [_tableView registerClass:WKContactsHeaderItemCell.class forCellReuseIdentifier:[WKContactsHeaderItemCell cellId]];
        
         _tableView.tableHeaderView = self.tableHeader;
        
        _tableView.tableFooterView = [self tableFooterView];
        
    }
    return _tableView;
}

-(void) loadView{
    [super loadView];
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
    
    UIView *headView =[[UIView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, headHheght)];
    [headView setBackgroundColor: WKApp.shared.config.cellBackgroundColor];
    UILabel  *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, headView.lim_width, headView.lim_height)];
    [titleLbl setFont:[[WKApp shared].config appFontOfSize:12.0f]];
    [titleLbl setTextColor:color];
    [titleLbl setText:title];
    [headView addSubview:titleLbl];

//    UIView *lineView = [[UIView alloc] init];
//    lineView.lim_left = 15.0f;
//    lineView.lim_height = 1.0f;
//    lineView.lim_width = self.view.lim_width-15.0f;
//    [lineView setBackgroundColor:[UIColor colorWithRed:248.0f/255.0f green:248.0f/255.0f blue:248.0f/255.0f alpha:1.0f]];
//    lineView.lim_top = headHheght - 1;
//    [headView addSubview:lineView];
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
        return 70.0f;
    }
    
    return  70.0;
}

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if(section == 0) {
        return 0.0f;
    }
    return 20.0f;
}
-(UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    if(section == 0) {
        return nil;
    }
    if (!self.sectionTitleArr || self.sectionTitleArr.count == 0) {
        return nil;
    }
    NSString *title = [self.sectionTitleArr objectAtIndex:section-1];
    return [self headView:title headHeight:20.0f color:WKApp.shared.config.themeColor];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
   if(section == 0) {
       return 10.0f;
    }
    return 0.0f;
}
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if(section == 0) {
       UIView *footer = [[UIView alloc] init];
        [footer setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
       return footer;
    }
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
    return self.sectionTitleArr.count+1;
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

-(void) addOrUpdateContactsWithChannelInfo:(WKChannelInfo*)channelInfo {
    if(self.items.count<=1) {
        return;
    }
    
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
        [self addContactsWithChannelInfo:channelInfo];
        [self.tableView reloadData];
        return;
    }
    BOOL hasChange = false;
    if(![channelInfo.displayName isEqualToString:existCellModel.name]) { // 改变了名字
        [self requestData];
    }
    
    if(channelInfo.online != existCellModel.online || channelInfo.lastOffline != existCellModel.lastOffline || channelInfo.deviceFlag !=existCellModel.channelInfo.deviceFlag) { // 上线或离线状态改变
        existCellModel.online = channelInfo.online;
        existCellModel.lastOffline = channelInfo.lastOffline;
        existCellModel.channelInfo = channelInfo;
        hasChange = true;
    }
    if(hasChange) {
        [self.tableView reloadData];
    }
   
    
}

-(void) addContactsWithChannelInfo:(WKChannelInfo*)channelInfo {
    NSInteger i= 0;
    NSString *newFirstLetter = [WKChineseSort getFirstLetter:channelInfo.displayName];
    if(!newFirstLetter) {
        newFirstLetter = @"#";
    }
    BOOL has = false;
    for (NSString *letter in self.sectionTitleArr) {
        if([newFirstLetter isEqualToString:letter]) {
           NSMutableArray *items = self.items[i+1];
            [items insertObject:[self toContactsCellModel:channelInfo] atIndex:0];
            has = true;
            break;
        }
        i++;
    }
    if(!has) { // 没有添加成功应该是没有对应的字母索引，所以这里直接重新请求
        [self requestData];
    }
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
        if(contactsItems.count>existIndexPath.row) {
            [contactsItems removeObjectAtIndex:existIndexPath.row];
        }
        if(contactsItems.count == 0) {
            if(self.items.count>existIndexPath.section) {
                [self.items removeObjectAtIndex:existIndexPath.section];
            }
            if(self.sectionTitleArr.count>existIndexPath.section-1) {
                [self.sectionTitleArr removeObjectAtIndex:existIndexPath.section-1];
            }
            [self.tableView reloadData];
        }
    }
    
}

#pragma mark - WKChannelManagerDelegate

- (void)channelInfoUpdate:(WKChannelInfo *)channelInfo oldChannelInfo:(WKChannelInfo *)oldChannelInfo {
    if(channelInfo.channel.channelType == WK_PERSON && channelInfo.follow == WKChannelInfoFollowFriend) {
        [self addOrUpdateContactsWithChannelInfo:channelInfo];
    }
}

- (void)channelInfoDelete:(WKChannel *)channel oldChannelInfo:(WKChannelInfo *)oldChannelInfo {
    if(channel.channelType == WK_PERSON && oldChannelInfo.follow == WKChannelInfoFollowFriend) {
        [self removeContacts:channel.channelId];
    }
}

@end
