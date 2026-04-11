//
//  WKThreadSettingVC.m
//  WuKongBase
//

#import "WKThreadSettingVC.h"
#import "WKThreadService.h"
#import "WKThreadModel.h"
#import "WKSettingMemberGridView.h"
#import "WKNavigationManager.h"
#import "WKAvatarUtil.h"
#import "WKUserAvatar.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import "WKApp.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

@interface WKThreadSettingVC () <WKSettingMemberGridViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) WKSettingMemberGridView *memberGridView;

@property (nonatomic, copy) NSString *groupNo;
@property (nonatomic, copy) NSString *shortId;
@property (nonatomic, copy) NSString *threadName;

@property (nonatomic, strong) NSArray *members; // API 返回的成员字典数组
@property (nonatomic, assign) BOOL isMember;   // 当前用户是否在子区成员中

@end

@implementation WKThreadSettingVC

#define MEMBER_GRID_TOP 20.0f
#define MEMBER_LIMIT 20

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = LLang(@"子区详情");
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;

    // 解析 groupNo 和 shortId
    [self parseChannelId];

    self.members = @[];

    [self.view addSubview:self.tableView];
    self.tableView.tableHeaderView = self.headerView;
    self.tableView.tableFooterView = [[UIView alloc] init];

    [self loadThreadInfo];
    [self loadMembers];
}

- (void)parseChannelId {
    NSString *channelId = self.channel.channelId;
    NSRange range = [channelId rangeOfString:@"____"];
    if (range.location != NSNotFound) {
        self.groupNo = [channelId substringToIndex:range.location];
        self.shortId = [channelId substringFromIndex:range.location + range.length];
    }
}

#pragma mark - Data Loading

- (void)loadThreadInfo {
    if (!self.groupNo || !self.shortId) return;
    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] getThread:self.groupNo shortId:self.shortId].then(^(WKThreadModel *thread) {
        weakSelf.threadName = thread.name;
        [weakSelf.tableView reloadData];
    }).catch(^(NSError *error) {
        // 从 channelInfo 获取名称作为备选
        WKChannelInfo *info = [[WKChannelManager shared] getChannelInfo:weakSelf.channel];
        if (info) {
            weakSelf.threadName = info.displayName;
            [weakSelf.tableView reloadData];
        }
    });
}

- (void)loadMembers {
    if (!self.groupNo || !self.shortId) return;
    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] getThreadMembers:self.groupNo shortId:self.shortId].then(^(NSArray *members) {
        weakSelf.members = members ?: @[];
        BOOL hasMore = (weakSelf.members.count > MEMBER_LIMIT);
        weakSelf.memberGridView.hasMore = hasMore;
        // 判断当前用户是否在成员列表中
        NSString *myUid = [WKSDK shared].options.connectInfo.uid;
        weakSelf.isMember = NO;
        for (NSDictionary *m in weakSelf.members) {
            if ([myUid isEqualToString:m[@"uid"]]) {
                weakSelf.isMember = YES;
                break;
            }
        }
        [weakSelf refreshMemberGrid];
    }).catch(^(NSError *error) {
        [weakSelf.view showMsg:error.domain];
    });
}

- (void)refreshMemberGrid {
    [self.memberGridView reloadData];
    self.headerView.lim_height = [self.memberGridView viewHeight] + MEMBER_GRID_TOP;
    self.tableView.tableHeaderView = self.headerView;
    [self.tableView reloadData];
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat navBottom = [self getNavBottom];
    self.tableView.frame = CGRectMake(0, navBottom, self.view.lim_width, self.view.lim_height - navBottom);
}

#pragma mark - WKSettingMemberGridViewDelegate

- (NSInteger)numberOfSettingMemberGridView:(WKSettingMemberGridView *)settingMemberGridView {
    NSInteger count = self.members.count;
    if (count > MEMBER_LIMIT) count = MEMBER_LIMIT;
    return count;
}

- (UIView *)settingMemberGridView:(WKSettingMemberGridView *)settingMemberGridView size:(CGSize)size atIndex:(NSInteger)index {
    if (index >= self.members.count) return [[UIView alloc] init];
    NSDictionary *memberDict = self.members[index];
    return [self memberAvatarView:size memberDict:memberDict];
}

- (void)settingMemberGridView:(WKSettingMemberGridView *)settingMemberGridView didSelect:(NSInteger)index {
    if (index >= self.members.count) return;
    NSDictionary *memberDict = self.members[index];
    NSString *uid = memberDict[@"uid"] ?: @"";
    if (uid.length > 0) {
        [[WKApp shared] invoke:WKPOINT_USER_INFO param:@{@"uid": uid}];
    }
}

- (UIView *)memberAvatarView:(CGSize)size memberDict:(NSDictionary *)memberDict {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];

    NSString *uid = memberDict[@"uid"] ?: @"";
    NSString *name = memberDict[@"name"] ?: @"";

    // 头像
    WKUserAvatar *avatarView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, 54.0f, 54.0f)];
    NSString *avatarUrl = [WKAvatarUtil getAvatar:uid];
    WKChannelInfo *memberChannelInfo = [[WKSDK shared].channelManager getChannelInfo:[[WKChannel alloc] initWith:uid channelType:WK_PERSON]];
    if (memberChannelInfo && memberChannelInfo.avatarCacheKey.length > 0) {
        NSString *separator = [avatarUrl containsString:@"?"] ? @"&" : @"?";
        avatarUrl = [NSString stringWithFormat:@"%@%@v=%@", avatarUrl, separator, memberChannelInfo.avatarCacheKey];
    }
    [avatarView setUrl:avatarUrl];
    [view addSubview:avatarView];
    avatarView.lim_left = view.lim_width / 2.0f - avatarView.lim_width / 2.0f;

    // 名称（优先显示好友备注）
    UILabel *nameLbl = [UILabel new];
    if (memberChannelInfo && memberChannelInfo.remark.length > 0) {
        nameLbl.text = memberChannelInfo.remark;
    } else {
        nameLbl.text = name;
    }
    nameLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
    nameLbl.textColor = [WKApp shared].config.defaultTextColor;
    nameLbl.textAlignment = NSTextAlignmentCenter;
    nameLbl.lim_width = avatarView.lim_width;
    nameLbl.lim_height = 17.0f;
    [view addSubview:nameLbl];
    nameLbl.lim_top = avatarView.lim_bottom + 5.0f;
    nameLbl.lim_left = view.lim_width / 2.0f - nameLbl.lim_width / 2.0f;

    return view;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.isMember ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        // 子区名称
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"NameCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"NameCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        cell.textLabel.text = LLang(@"子区名称");
        cell.textLabel.font = [[WKApp shared].config appFontOfSize:16.0f];
        cell.textLabel.textColor = [WKApp shared].config.defaultTextColor;
        cell.detailTextLabel.text = self.threadName ?: @"";
        cell.detailTextLabel.font = [[WKApp shared].config appFontOfSize:15.0f];
        cell.detailTextLabel.textColor = [UIColor grayColor];
        cell.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        return cell;
    } else {
        // 退出子区按钮
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LeaveCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LeaveCell"];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
        }
        cell.textLabel.text = LLang(@"退出子区");
        cell.textLabel.font = [[WKApp shared].config appFontOfSize:16.0f];
        cell.textLabel.textColor = [UIColor redColor];
        cell.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        return cell;
    }
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 10.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *v = [[UIView alloc] init];
    v.backgroundColor = [UIColor clearColor];
    return v;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        [self confirmLeaveThread];
    }
}

#pragma mark - Actions

- (void)confirmLeaveThread {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"退出子区")
                                                                  message:LLang(@"确定退出该子区？")
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"退出") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[WKThreadService shared] leaveThread:weakSelf.shortId].then(^(id result) {
            // pop 两层：设置页 + 子区聊天页，回到群组聊天页
            UINavigationController *nav = [WKNavigationManager shared].topViewController.navigationController;
            NSArray *vcs = nav.viewControllers;
            if (vcs.count >= 3) {
                [nav popToViewController:vcs[vcs.count - 3] animated:YES];
            } else {
                [nav popToRootViewControllerAnimated:YES];
            }
        }).catch(^(NSError *error) {
            [weakSelf.view showMsg:error.domain];
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Lazy Init

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        _tableView.backgroundColor = [WKApp shared].config.backgroundColor;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    return _tableView;
}

- (UIView *)headerView {
    if (!_headerView) {
        _headerView = [[UIView alloc] init];
        _headerView.lim_width = self.view.lim_width;
        _headerView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        [_headerView addSubview:self.memberGridView];
        self.memberGridView.lim_top = MEMBER_GRID_TOP;
    }
    return _headerView;
}

- (WKSettingMemberGridView *)memberGridView {
    if (!_memberGridView) {
        _memberGridView = [WKSettingMemberGridView initWithMaxWidth:self.view.lim_width - 10.0f numberOfLine:5 hasMore:NO];
        _memberGridView.delegate = self;
        _memberGridView.lim_left = 5.0f;
        __weak typeof(self) weakSelf = self;
        [_memberGridView setOnMore:^{
            // 查看全部成员 - 暂时重新加载全部
            [weakSelf loadMembers];
        }];
    }
    return _memberGridView;
}

@end
