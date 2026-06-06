//
//  WKGroupAdminManageVC.m
//  WuKongBase
//

#import "WKGroupAdminManageVC.h"
#import "WuKongBase.h"
#import "WKUserAvatar.h"
#import "WKMemberListVC.h"
#import "WKActionSheetView2.h"
#import "WKActionSheetItem2.h"
#import "WKChannelUtil.h"

#pragma mark - Cells (private)

@interface WKGroupAdminMemberCell : UITableViewCell
@property(nonatomic, strong) WKUserAvatar *avatar;
@property(nonatomic, strong) UILabel *nameLbl;
@property(nonatomic, strong) UILabel *roleTagLbl; // 群主 / 管理员 / 机器人
@property(nonatomic, strong) UIImageView *removeIconView;
@property(nonatomic, assign) BOOL canRemove;
- (void)refreshWithMember:(WKChannelMember *)member roleText:(NSString *)roleText roleColor:(UIColor *)roleColor canRemove:(BOOL)canRemove;
@end

@implementation WKGroupAdminMemberCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        _avatar = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        [self.contentView addSubview:_avatar];

        _nameLbl = [UILabel new];
        _nameLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
        _nameLbl.textColor = [WKApp shared].config.defaultTextColor;
        [self.contentView addSubview:_nameLbl];

        _roleTagLbl = [UILabel new];
        _roleTagLbl.font = [[WKApp shared].config appFontOfSize:11.0f];
        _roleTagLbl.textAlignment = NSTextAlignmentCenter;
        _roleTagLbl.layer.cornerRadius = 4.0f;
        _roleTagLbl.layer.masksToBounds = YES;
        _roleTagLbl.hidden = YES;
        [self.contentView addSubview:_roleTagLbl];

        _removeIconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 22, 22)];
        _removeIconView.image = [[WKApp shared] loadImage:@"Conversation/Setting/MemberDelete" moduleID:@"WuKongBase"];
        _removeIconView.contentMode = UIViewContentModeScaleAspectFit;
        _removeIconView.hidden = YES;
        [self.contentView addSubview:_removeIconView];
    }
    return self;
}

- (void)refreshWithMember:(WKChannelMember *)member roleText:(NSString *)roleText roleColor:(UIColor *)roleColor canRemove:(BOOL)canRemove {
    self.avatar.url = [WKApp.shared getImageFullUrl:member.memberAvatar].absoluteString;
    self.nameLbl.text = member.memberRemark.length > 0 ? member.memberRemark : member.memberName;

    if (roleText.length > 0) {
        self.roleTagLbl.hidden = NO;
        self.roleTagLbl.text = [NSString stringWithFormat:@" %@ ", roleText];
        self.roleTagLbl.textColor = [UIColor whiteColor];
        self.roleTagLbl.backgroundColor = roleColor;
    } else {
        self.roleTagLbl.hidden = YES;
    }
    self.canRemove = canRemove;
    self.removeIconView.hidden = !canRemove;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat leftPad = 16.0f;
    CGFloat rightPad = 16.0f;
    self.avatar.frame = CGRectMake(leftPad, (self.contentView.lim_height - 40) / 2.0f, 40, 40);

    CGFloat removeRight = self.contentView.lim_width - rightPad;
    if (self.canRemove) {
        self.removeIconView.frame = CGRectMake(removeRight - 22, (self.contentView.lim_height - 22) / 2.0f, 22, 22);
        removeRight = self.removeIconView.lim_left - 8;
    }

    CGFloat nameLeft = self.avatar.lim_right + 12;
    CGFloat nameAvailable = removeRight - nameLeft;

    [self.nameLbl sizeToFit];
    CGFloat nameW = MIN(self.nameLbl.lim_width, nameAvailable);
    if (!self.roleTagLbl.hidden) {
        [self.roleTagLbl sizeToFit];
        CGFloat tagW = self.roleTagLbl.lim_width + 4;
        if (tagW > 60) tagW = 60;
        self.roleTagLbl.frame = CGRectMake(0, 0, tagW, 18);
        nameW = MIN(nameW, nameAvailable - tagW - 6);
        if (nameW < 0) nameW = 0;
        self.nameLbl.frame = CGRectMake(nameLeft, (self.contentView.lim_height - 22) / 2.0f, nameW, 22);
        self.roleTagLbl.frame = CGRectMake(self.nameLbl.lim_right + 6, (self.contentView.lim_height - 18) / 2.0f, tagW, 18);
    } else {
        self.nameLbl.frame = CGRectMake(nameLeft, (self.contentView.lim_height - 22) / 2.0f, nameW, 22);
    }
}

@end

@interface WKGroupAdminActionCell : UITableViewCell
@property(nonatomic, strong) UILabel *titleLbl;
@property(nonatomic, strong) UILabel *iconLbl;
- (void)refreshWithTitle:(NSString *)title;
@end

@implementation WKGroupAdminActionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        _iconLbl = [UILabel new];
        _iconLbl.font = [[WKApp shared].config appFontOfSize:24.0f];
        _iconLbl.text = @"+";
        _iconLbl.textColor = [WKApp shared].config.themeColor;
        _iconLbl.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_iconLbl];

        _titleLbl = [UILabel new];
        _titleLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
        _titleLbl.textColor = [WKApp shared].config.themeColor;
        [self.contentView addSubview:_titleLbl];
    }
    return self;
}

- (void)refreshWithTitle:(NSString *)title {
    self.titleLbl.text = title;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat leftPad = 16.0f;
    self.iconLbl.frame = CGRectMake(leftPad, 0, 40, self.contentView.lim_height);
    [self.titleLbl sizeToFit];
    self.titleLbl.frame = CGRectMake(self.iconLbl.lim_right + 12, (self.contentView.lim_height - 22) / 2.0f, self.contentView.lim_width - self.iconLbl.lim_right - 12 - 16, 22);
}

@end

#pragma mark - VC

typedef NS_ENUM(NSInteger, WKGroupAdminSection) {
    WKGroupAdminSectionManagers = 0,
    WKGroupAdminSectionBotAdmins,
    WKGroupAdminSectionCount,
};

static NSString *const kMemberCellId = @"WKGroupAdminMemberCell";
static NSString *const kActionCellId = @"WKGroupAdminActionCell";
static CGFloat const kRowHeight = 64.0f;
static CGFloat const kHeaderHeight = 38.0f;

@interface WKGroupAdminManageVC ()<UITableViewDelegate, UITableViewDataSource, WKGroupAdminManageVMDelegate>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UILabel *emptyLabel;
@end

@implementation WKGroupAdminManageVC

- (instancetype)init {
    if (self = [super init]) {
        self.viewModel = [WKGroupAdminManageVM new];
        self.viewModel.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    self.viewModel.channel = self.channel;
    [super viewDidLoad];

    self.title = LLang(@"群管理");
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;

    [self.view addSubview:self.tableView];
    [self.view addSubview:self.emptyLabel];

    [self.viewModel reload];
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:[self visibleRect] style:UITableViewStyleGrouped];
        _tableView.backgroundColor = [WKApp shared].config.backgroundColor;
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        [_tableView registerClass:WKGroupAdminMemberCell.class forCellReuseIdentifier:kMemberCellId];
        [_tableView registerClass:WKGroupAdminActionCell.class forCellReuseIdentifier:kActionCellId];
    }
    return _tableView;
}

- (UILabel *)emptyLabel {
    if (!_emptyLabel) {
        _emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 120, self.view.lim_width - 40, 40)];
        _emptyLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
        _emptyLabel.textColor = [UIColor grayColor];
        _emptyLabel.textAlignment = NSTextAlignmentCenter;
        _emptyLabel.text = LLang(@"群管理员可以协助群主管理群成员");
        _emptyLabel.hidden = YES;
        _emptyLabel.numberOfLines = 0;
    }
    return _emptyLabel;
}

#pragma mark - VM delegate

- (void)groupAdminReload {
    BOOL noManagers = (self.viewModel.creator == nil) && (self.viewModel.managers.count == 0);
    self.emptyLabel.hidden = !noManagers || self.viewModel.loading;
    [self.tableView reloadData];
}

#pragma mark - DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return WKGroupAdminSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == WKGroupAdminSectionManagers) {
        NSInteger n = (self.viewModel.creator ? 1 : 0) + self.viewModel.managers.count;
        if (self.isCreator) n += 1; // + 添加
        return n;
    }
    if (section == WKGroupAdminSectionBotAdmins) {
        NSInteger n = self.viewModel.botAdmins.count;
        if (self.isCreator) n += 1; // + 添加
        return n;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kRowHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if ([self tableView:tableView numberOfRowsInSection:section] == 0) {
        return CGFLOAT_MIN;
    }
    return kHeaderHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if ([self tableView:tableView numberOfRowsInSection:section] == 0) {
        return CGFLOAT_MIN;
    }
    return 10.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if ([self tableView:tableView numberOfRowsInSection:section] == 0) {
        return [[UIView alloc] initWithFrame:CGRectZero];
    }
    return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = @"";
    if (section == WKGroupAdminSectionManagers) {
        title = LLang(@"群主和管理员");
    } else if (section == WKGroupAdminSectionBotAdmins) {
        title = LLang(@"Bot 管理员");
    }
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.lim_width, kHeaderHeight)];
    header.backgroundColor = [UIColor clearColor];
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, tableView.lim_width - 32, 22)];
    titleLbl.text = title;
    titleLbl.font = [[WKApp shared].config appFontOfSize:13.0f];
    titleLbl.textColor = [UIColor grayColor];
    [header addSubview:titleLbl];
    return header;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == WKGroupAdminSectionManagers) {
        NSInteger memberRows = (self.viewModel.creator ? 1 : 0) + self.viewModel.managers.count;
        if (self.isCreator && indexPath.row == memberRows) {
            WKGroupAdminActionCell *cell = [tableView dequeueReusableCellWithIdentifier:kActionCellId];
            [cell refreshWithTitle:LLang(@"添加管理员")];
            return cell;
        }
        WKChannelMember *member = [self managerAtRow:indexPath.row];
        WKGroupAdminMemberCell *cell = [tableView dequeueReusableCellWithIdentifier:kMemberCellId];
        BOOL isCreator = (member.role == WKMemberRoleCreator);
        NSString *roleText = isCreator ? LLang(@"群主") : LLang(@"管理员");
        UIColor *roleColor = isCreator
            ? [UIColor colorWithRed:0xF7/255.0 green:0xA5/255.0 blue:0x00/255.0 alpha:1.0]   // 橙
            : [UIColor colorWithRed:0x3B/255.0 green:0x82/255.0 blue:0xF6/255.0 alpha:1.0]; // 蓝
        BOOL canRemove = self.isCreator && !isCreator;
        [cell refreshWithMember:member roleText:roleText roleColor:roleColor canRemove:canRemove];
        // 群主行禁止点击（无法移除、也不进个人页）
        cell.selectionStyle = isCreator ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
        return cell;
    }
    if (indexPath.section == WKGroupAdminSectionBotAdmins) {
        if (self.isCreator && indexPath.row == (NSInteger)self.viewModel.botAdmins.count) {
            WKGroupAdminActionCell *cell = [tableView dequeueReusableCellWithIdentifier:kActionCellId];
            [cell refreshWithTitle:LLang(@"添加 Bot 管理员")];
            return cell;
        }
        WKChannelMember *bot = self.viewModel.botAdmins[indexPath.row];
        WKGroupAdminMemberCell *cell = [tableView dequeueReusableCellWithIdentifier:kMemberCellId];
        UIColor *botColor = [UIColor colorWithRed:0x10/255.0 green:0xB9/255.0 blue:0x81/255.0 alpha:1.0]; // 绿
        [cell refreshWithMember:bot roleText:LLang(@"Bot") roleColor:botColor canRemove:self.isCreator];
        return cell;
    }
    return [UITableViewCell new];
}

- (WKChannelMember *)managerAtRow:(NSInteger)row {
    if (self.viewModel.creator) {
        if (row == 0) return self.viewModel.creator;
        return self.viewModel.managers[row - 1];
    }
    return self.viewModel.managers[row];
}

#pragma mark - Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == WKGroupAdminSectionManagers) {
        NSInteger memberRows = (self.viewModel.creator ? 1 : 0) + self.viewModel.managers.count;
        if (self.isCreator && indexPath.row == memberRows) {
            [self pickAddManager];
            return;
        }
        WKChannelMember *member = [self managerAtRow:indexPath.row];
        if (member.role == WKMemberRoleCreator) {
            return; // 群主行不可点
        }
        if (member.role == WKMemberRoleManager && self.isCreator) {
            [self confirmRemoveManager:member];
        } else {
            [self openMemberProfile:member];
        }
        return;
    }

    if (indexPath.section == WKGroupAdminSectionBotAdmins) {
        if (self.isCreator && indexPath.row == (NSInteger)self.viewModel.botAdmins.count) {
            [self pickAddBotAdmin];
            return;
        }
        WKChannelMember *bot = self.viewModel.botAdmins[indexPath.row];
        if (self.isCreator) {
            [self confirmRemoveBotAdmin:bot];
        } else {
            [self openMemberProfile:bot];
        }
    }
}

- (void)openMemberProfile:(WKChannelMember *)member {
    if (!member) return;
    NSString *vercode = @"";
    if (member.extra && member.extra[@"vercode"]) {
        vercode = member.extra[@"vercode"];
    }
    [[WKApp shared] invoke:WKPOINT_USER_INFO param:@{
        @"channel": self.channel ?: [NSNull null],
        @"uid": member.memberUid ?: @"",
        @"vercode": vercode,
    }];
}

#pragma mark - Actions

- (void)pickAddManager {
    __weak typeof(self) weakSelf = self;
    WKMemberListVC *vc = [WKMemberListVC new];
    vc.title = LLang(@"添加管理员");
    vc.channel = self.channel;
    vc.edit = YES;
    // 隐藏：自己 + 已是 owner/manager + 机器人成员（机器人通过 Bot 管理员管理）
    NSMutableArray<NSString*> *hidden = [NSMutableArray array];
    if ([WKApp shared].loginInfo.uid) [hidden addObject:[WKApp shared].loginInfo.uid];
    [hidden addObjectsFromArray:self.viewModel.ownerAndManagerUids];
    [hidden addObjectsFromArray:self.viewModel.robotUids];
    vc.hiddenUsers = hidden;
    vc.onFinishedSelect = ^(NSArray<NSString *> *uids) {
        if (uids.count == 0) return;
        [[WKNavigationManager shared].topViewController.view showHUD];
        [[WKGroupManager shared] groupNo:weakSelf.channel.channelId membersToManager:uids complete:^(NSError *error) {
            [[WKNavigationManager shared].topViewController.view hideHud];
            if (error) {
                [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
                return;
            }
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
            [weakSelf.view showMsg:LLang(@"已添加")];
            [weakSelf.viewModel reload];
        }];
    };
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

- (void)confirmRemoveManager:(WKChannelMember *)member {
    __weak typeof(self) weakSelf = self;
    NSString *name = member.memberRemark.length > 0 ? member.memberRemark : member.memberName;
    NSString *tip = [NSString stringWithFormat:LLang(@"是否将 %@ 设为普通成员？"), name ?: @""];
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:tip cancel:LLang(@"取消")];
    [sheet addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLang(@"移除管理员") onClick:^{
        [[WKNavigationManager shared].topViewController.view showHUD];
        [[WKGroupManager shared] groupNo:weakSelf.channel.channelId managersToMember:@[member.memberUid ?: @""] complete:^(NSError *error) {
            [[WKNavigationManager shared].topViewController.view hideHud];
            if (error) {
                [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
                return;
            }
            [weakSelf.view showMsg:LLang(@"已移除")];
            [weakSelf.viewModel reload];
        }];
    }]];
    [sheet show];
}

- (void)pickAddBotAdmin {
    __weak typeof(self) weakSelf = self;
    WKMemberListVC *vc = [WKMemberListVC new];
    vc.title = LLang(@"添加 Bot 管理员");
    vc.channel = self.channel;
    vc.edit = YES;
    // 隐藏：自己 + 已是 bot admin + 所有非机器人成员（只有机器人能升为 Bot 管理员）
    NSMutableArray<NSString*> *hidden = [NSMutableArray array];
    if ([WKApp shared].loginInfo.uid) [hidden addObject:[WKApp shared].loginInfo.uid];
    [hidden addObjectsFromArray:self.viewModel.botAdminUids];
    [hidden addObjectsFromArray:self.viewModel.nonRobotUids];
    vc.hiddenUsers = hidden;
    vc.onFinishedSelect = ^(NSArray<NSString *> *uids) {
        if (uids.count == 0) return;
        // 仅取第一个，符合 web 行为；若多选会逐个调用
        [[WKNavigationManager shared].topViewController.view showHUD];
        __block NSInteger remaining = (NSInteger)uids.count;
        __block NSError *firstError = nil;
        void(^onOne)(NSError *) = ^(NSError *err) {
            if (err && !firstError) firstError = err;
            remaining -= 1;
            if (remaining > 0) return;
            [[WKNavigationManager shared].topViewController.view hideHud];
            if (firstError) {
                [[WKNavigationManager shared].topViewController.view showMsg:firstError.domain];
                return;
            }
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
            [weakSelf.view showMsg:LLang(@"已添加")];
            [weakSelf.viewModel reload];
        };
        for (NSString *uid in uids) {
            [[WKGroupManager shared] groupNo:weakSelf.channel.channelId addBotAdmin:uid complete:onOne];
        }
    };
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

- (void)confirmRemoveBotAdmin:(WKChannelMember *)bot {
    __weak typeof(self) weakSelf = self;
    NSString *name = bot.memberRemark.length > 0 ? bot.memberRemark : bot.memberName;
    NSString *tip = [NSString stringWithFormat:LLang(@"是否移除 Bot 管理员 %@？"), name ?: @""];
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:tip cancel:LLang(@"取消")];
    [sheet addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLang(@"移除 Bot 管理员") onClick:^{
        [[WKNavigationManager shared].topViewController.view showHUD];
        [[WKGroupManager shared] groupNo:weakSelf.channel.channelId removeBotAdmin:bot.memberUid ?: @"" complete:^(NSError *error) {
            [[WKNavigationManager shared].topViewController.view hideHud];
            if (error) {
                [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
                return;
            }
            [weakSelf.view showMsg:LLang(@"已移除")];
            [weakSelf.viewModel reload];
        }];
    }]];
    [sheet show];
}

@end
