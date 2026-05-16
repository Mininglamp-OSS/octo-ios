//
//  WKThreadSettingVC.m
//  WuKongBase
//

#import "WKThreadSettingVC.h"
#import "WKThreadService.h"
#import "WKThreadModel.h"
#import "WKSettingMemberGridView.h"
#import "WKThreadMemberListVC.h"
#import "WKNavigationManager.h"
#import "WKAvatarUtil.h"
#import "WKUserAvatar.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import "WKApp.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKGroupMdVC.h"
#import "WKChannelUtil.h"
#import "WKRealnamePrefetcher.h"

@interface WKThreadSettingVC () <WKSettingMemberGridViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) WKSettingMemberGridView *memberGridView;

@property (nonatomic, copy) NSString *groupNo;
@property (nonatomic, copy) NSString *shortId;
@property (nonatomic, copy) NSString *threadName;
@property (nonatomic, strong) WKThreadModel *thread;
@property (nonatomic, assign) BOOL isCreator;  // 当前用户是否是子区创建者
@property (nonatomic, assign) BOOL isGroupAdmin; // 当前用户是否是父群群主或管理员

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

    // ：实名状态预拉取回写后局部刷宫格（uid 命中本子区成员才刷）
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(realnameVerifiedUpdated:)
                                                 name:WKRealnameVerifiedUpdatedNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKRealnameVerifiedUpdatedNotification object:nil];
}

- (void)realnameVerifiedUpdated:(NSNotification *)noti {
    NSString *uid = noti.userInfo[@"uid"];
    if (uid.length == 0) return;
    BOOL hit = NO;
    for (NSDictionary *m in self.members) {
        if ([m[@"uid"] isEqualToString:uid]) {
            hit = YES;
            break;
        }
    }
    if (!hit) return;
    [self.memberGridView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
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
        weakSelf.thread = thread;
        weakSelf.threadName = thread.name;
        NSString *myUid = [WKSDK shared].options.connectInfo.uid;
        weakSelf.isCreator = (myUid.length > 0 && [thread.creatorUid isEqualToString:myUid]);
        // 同步 thread md 状态到 channelInfo.extra
        WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:weakSelf.channel];
        if (info) {
            info.extra[@"has_thread_md"] = @(thread.hasThreadMd);
            info.extra[@"thread_md_version"] = @(thread.threadMdVersion);
            [[WKSDK shared].channelManager updateChannelInfo:info];
        }
        // 检查当前用户是否是父群的群主或管理员
        WKChannel *groupChannel = [[WKChannel alloc] initWith:weakSelf.groupNo channelType:WK_GROUP];
        NSString *myUid2 = [WKSDK shared].options.connectInfo.uid;
        WKChannelMember *myMember = [[WKSDK shared].channelManager getMember:groupChannel uid:myUid2];
        weakSelf.isGroupAdmin = (myMember && (myMember.role == WKMemberRoleCreator || myMember.role == WKMemberRoleManager));

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

    // 实名 ✓ 徽章（子区宫格，与 WKConversationGroupSettingVC 同款节奏）。
    // 子区 member dict 自身不带 realname_verified，直接读 person 缓存；缺数据
    // 时由 WKRealnamePrefetcher 补一次，回写后会发 WKRealnameVerifiedUpdatedNotification
    // —— 本 VC 听这个通知后 reload 一次宫格即可。
    NSNumber *flag = [WKChannelUtil isRealnameVerifiedFromExtra:memberChannelInfo.extra];
    BOOL realnameVerified = flag.boolValue;
    if (realnameVerified) {
        const CGFloat kBadgeW = 10.0f;
        const CGFloat kBadgeGap = 2.0f;
        const CGFloat kSidePad = 2.0f;

        nameLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        nameLbl.numberOfLines = 1;
        nameLbl.textAlignment = NSTextAlignmentLeft;

        CGFloat textW = 0.0f;
        if (nameLbl.attributedText.length > 0) {
            textW = [nameLbl.attributedText size].width;
        } else if (nameLbl.text.length > 0 && nameLbl.font) {
            textW = [nameLbl.text sizeWithAttributes:@{NSFontAttributeName: nameLbl.font}].width;
        }
        // 可用宽度按 cell 宽 view.lim_width 算（≈73pt），不卡死在 avatar 54pt。
        CGFloat usableW = view.lim_width - kSidePad * 2;
        CGFloat maxNameW = usableW - kBadgeGap - kBadgeW;
        if (maxNameW < 0) maxNameW = 0;
        CGFloat usedW = MIN(textW, maxNameW);
        CGFloat totalW = usedW + kBadgeGap + kBadgeW;
        nameLbl.lim_width = usedW;
        nameLbl.lim_left = view.lim_width / 2.0f - totalW / 2.0f;
        if (nameLbl.lim_left < kSidePad) nameLbl.lim_left = kSidePad;

        UIImageView *badge = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, kBadgeW, kBadgeW)];
        badge.contentMode = UIViewContentModeScaleAspectFit;
        badge.image = [WKApp.shared loadImage:@"Common/ic_realname_verified_mini" moduleID:@"WuKongBase"];
        [view addSubview:badge];
        badge.lim_left = nameLbl.lim_left + nameLbl.lim_width + kBadgeGap;
        badge.lim_top = nameLbl.lim_top + (nameLbl.lim_height - kBadgeW) / 2.0f;
        // 兜底：徽章一定要在 cell 内
        CGFloat maxBadgeLeft = view.lim_width - kSidePad - kBadgeW;
        if (badge.lim_left > maxBadgeLeft) {
            badge.lim_left = maxBadgeLeft;
            CGFloat nameMaxRight = badge.lim_left - kBadgeGap;
            if (nameLbl.lim_left + nameLbl.lim_width > nameMaxRight) {
                nameLbl.lim_width = MAX(0, nameMaxRight - nameLbl.lim_left);
            }
        }
    } else if (uid.length > 0) {
        [WKRealnamePrefetcher ensureFetched:uid];
    }

    return view;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.isMember ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == 0) {
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
    } else if (indexPath.section == 0 && indexPath.row == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MdCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"MdCell"];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.textLabel.text = @"GROUP.md";
        cell.textLabel.font = [[WKApp shared].config appFontOfSize:16.0f];
        cell.textLabel.textColor = [WKApp shared].config.defaultTextColor;
        WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:self.channel];
        BOOL hasMd = [info.extra[@"has_thread_md"] boolValue];
        NSInteger mdVersion = [info.extra[@"thread_md_version"] integerValue];
        cell.detailTextLabel.text = hasMd ? [NSString stringWithFormat:@"%@ v%ld", LLang(@"已配置"), (long)mdVersion] : LLang(@"未配置");
        cell.detailTextLabel.font = [[WKApp shared].config appFontOfSize:15.0f];
        cell.detailTextLabel.textColor = [UIColor grayColor];
        cell.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LeaveCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LeaveCell"];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
        }
        cell.textLabel.text = self.isCreator ? LLang(@"关闭子区") : LLang(@"退出子区");
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
    if (indexPath.section == 0 && indexPath.row == 1) {
        WKGroupMdVC *vc = [WKGroupMdVC new];
        vc.channel = self.channel;
        vc.canEdit = self.isCreator || self.isGroupAdmin;
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
    } else if (indexPath.section == 1) {
        if (self.isCreator) {
            [self confirmCloseThread];
        } else {
            [self confirmLeaveThread];
        }
    }
}

#pragma mark - Actions

- (void)confirmCloseThread {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"关闭子区")
                                                                  message:LLang(@"确定关闭该子区？关闭后所有成员将无法再访问。")
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"关闭") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[WKThreadService shared] deleteThread:weakSelf.groupNo shortId:weakSelf.shortId].then(^(id result) {
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
        _memberGridView.moreBtnTitle = LLang(@"查看更多子区成员");
        __weak typeof(self) weakSelf = self;
        [_memberGridView setOnMore:^{
            [weakSelf showAllThreadMembers];
        }];
    }
    return _memberGridView;
}

- (void)showAllThreadMembers {
    WKThreadMemberListVC *memberVC = [WKThreadMemberListVC new];
    memberVC.groupNo = self.groupNo;
    memberVC.shortId = self.shortId;
    [WKNavigationManager.shared pushViewController:memberVC animated:YES];
}

@end
