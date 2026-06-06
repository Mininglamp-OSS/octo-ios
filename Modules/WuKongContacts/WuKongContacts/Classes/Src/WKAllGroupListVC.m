//
//  WKAllGroupListVC.m
//  WuKongContacts
//

#import "WKAllGroupListVC.h"
#import "WKAllGroupListVM.h"
#import "WKContactsCell.h"
#import "WKChineseSort.h"
#import "WKContactFollowHelper.h"
#import <WuKongBase/WKFollowedKeysStore.h>

@interface WKAllGroupListVC () <UITableViewDataSource, UITableViewDelegate>

@property(nonatomic,strong) UITableView *tableView;
@property(nonatomic,strong) WKAllGroupListVM *vm;
@property(nonatomic,strong) NSMutableArray *sectionTitleArr;
@property(nonatomic,strong) NSMutableArray<NSMutableArray*> *items;

@end

@implementation WKAllGroupListVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationBar.title = LLang(@"我的群组");
    self.vm = [WKAllGroupListVM new];
    self.items = [NSMutableArray array];
    self.sectionTitleArr = [NSMutableArray array];
    [self.view addSubview:self.tableView];

    // 长按 cell → 弹"关注 / 取消关注"菜单（与联系人 tab 同款 helper，Group 走
    // refollowChannel + moveGroup 链）
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onGroupLongPress:)];
    lp.minimumPressDuration = 0.4;
    [self.tableView addGestureRecognizer:lp];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(onFollowedKeysUpdate)
                                                  name:kWKFollowedKeysStoreDidUpdateNotification
                                                object:nil];

    [self requestData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:[self visibleRect] style:UITableViewStyleGrouped];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.sectionIndexBackgroundColor = [UIColor clearColor];
        _tableView.sectionIndexColor = WKApp.shared.config.themeColor;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.sectionHeaderHeight = 0.0f;
        _tableView.sectionFooterHeight = 0.0f;
        [_tableView registerClass:WKContactsCell.class forCellReuseIdentifier:[WKContactsCell cellId]];
    }
    return _tableView;
}

- (void)requestData {
    __weak typeof(self) weakSelf = self;
    [self.vm requestGroups].then(^(NSArray<WKMyGroupResp*>* groups) {
        NSMutableArray *cellModels = [NSMutableArray array];
        for (WKMyGroupResp *group in groups) {
            WKContactsCellModel *model = [WKContactsCellModel new];
            model.uid = group.groupNo;
            model.name = group.displayName;
            model.isGroup = YES; // 让 cell 的关注图标走 WKFollowTargetTypeChannel
            WKChannelInfo *channelInfo = [[WKSDK shared].channelManager getChannelInfo:[[WKChannel alloc] initWith:group.groupNo channelType:WK_GROUP]];
            NSString *cacheKey = (channelInfo && channelInfo.avatarCacheKey.length > 0) ? channelInfo.avatarCacheKey : nil;
            model.avatar = [WKAvatarUtil getGroupAvatar:group.groupNo cacheKey:cacheKey];
            [cellModels addObject:model];
        }
        [weakSelf sortAndGroup:cellModels];
    }).catch(^(NSError *error) {
        NSLog(@"WKAllGroupListVC requestData error: %@", error);
    });
}

- (void)sortAndGroup:(NSArray *)items {
    __weak typeof(self) weakSelf = self;
    [WKChineseSort sortAndGroup:items key:@"name" finish:^(bool isSuccess, NSMutableArray *unGroupArr, NSMutableArray *sectionTitleArr, NSMutableArray<NSMutableArray *> *sortedObjArr) {
        if (isSuccess) {
            weakSelf.sectionTitleArr = sectionTitleArr;
            weakSelf.items = sortedObjArr;
            [weakSelf.tableView reloadData];
        }
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sectionTitleArr.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.items.count <= indexPath.section || self.items[indexPath.section].count <= indexPath.row) {
        return [[UITableViewCell alloc] init];
    }
    WKContactsCellModel *model = self.items[indexPath.section][indexPath.row];
    model.first = indexPath.row == 0;
    model.last = self.items[indexPath.section].count - 1 == indexPath.row;
    if (indexPath.row == 0) {
        model.firstLetter = self.sectionTitleArr[indexPath.section];
    }
    WKContactsCell *cell = [tableView dequeueReusableCellWithIdentifier:[WKContactsCell cellId]];
    [cell refresh:model];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 70.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 20.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = self.sectionTitleArr[section];
    UIView *headView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, 20.0f)];
    [headView setBackgroundColor:WKApp.shared.config.cellBackgroundColor];
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, headView.lim_width, headView.lim_height)];
    [titleLbl setFont:[[WKApp shared].config appFontOfSize:12.0f]];
    [titleLbl setTextColor:WKApp.shared.config.themeColor];
    [titleLbl setText:title];
    [headView addSubview:titleLbl];
    return headView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return nil;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return self.sectionTitleArr;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return index;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.items.count <= indexPath.section || self.items[indexPath.section].count <= indexPath.row) return;
    WKContactsCellModel *model = self.items[indexPath.section][indexPath.row];
    [[WKApp shared] pushConversation:[[WKChannel alloc] initWith:model.uid channelType:WK_GROUP]];
}

#pragma mark - 长按关注菜单

- (void)onGroupLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint pInTable = [gesture locationInView:self.tableView];
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:pInTable];
    if (!ip) return;
    if (ip.section >= (NSInteger)self.items.count) return;
    NSArray *sectionItems = self.items[ip.section];
    if (ip.row >= (NSInteger)sectionItems.count) return;
    WKContactsCellModel *model = sectionItems[ip.row];
    if (![model isKindOfClass:[WKContactsCellModel class]] || model.uid.length == 0) return;

    UIWindow *window = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    CGPoint pInWindow = [self.tableView convertPoint:pInTable toView:window];
    WKChannel *channel = [[WKChannel alloc] initWith:model.uid channelType:WK_GROUP];
    [WKContactFollowHelper showFollowMenuForChannel:channel
                                     atPointInWindow:pInWindow
                                       presentingVC:self
                                        onDidChange:nil];
}

- (void)onFollowedKeysUpdate {
    NSArray<NSIndexPath *> *visible = self.tableView.indexPathsForVisibleRows;
    if (visible.count == 0) return;
    @try {
        [self.tableView reloadRowsAtIndexPaths:visible withRowAnimation:UITableViewRowAnimationNone];
    } @catch (NSException *ex) {
        [self.tableView reloadData];
    }
}

@end
