// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
#import "WKThreadMemberListVC.h"
#import "WKThreadService.h"
#import "WKAvatarUtil.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import "UIView+WKCommon.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKUserAvatar.h"

static NSString * const kCellId = @"WKThreadMemberCell";

@interface WKThreadMemberCell : UITableViewCell
@property (nonatomic, strong) WKUserAvatar *avatarView;
@property (nonatomic, strong) UILabel *nameLbl;
@end

@implementation WKThreadMemberCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        _avatarView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, 46.0f, 46.0f)];
        [self.contentView addSubview:_avatarView];

        _nameLbl = [[UILabel alloc] init];
        _nameLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
        [self.contentView addSubview:_nameLbl];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat leftSpace = 15.0f;
    self.avatarView.frame = CGRectMake(leftSpace, (self.contentView.lim_height - 46.0f) / 2.0f, 46.0f, 46.0f);
    self.nameLbl.frame = CGRectMake(self.avatarView.lim_right + 15.0f, 0, self.contentView.lim_width - self.avatarView.lim_right - 15.0f - 40.0f, self.contentView.lim_height);
}

- (void)refreshWithUid:(NSString *)uid name:(NSString *)name {
    NSString *displayName = name;
    NSString *avatarUrl = [WKAvatarUtil getAvatar:uid];

    WKChannelInfo *memberInfo = [[WKSDK shared].channelManager getChannelInfo:[[WKChannel alloc] initWith:uid channelType:WK_PERSON]];
    if (memberInfo) {
        if (memberInfo.remark.length > 0) {
            displayName = memberInfo.remark;
        } else if (memberInfo.displayName.length > 0) {
            displayName = memberInfo.displayName;
        }
        if (memberInfo.avatarCacheKey.length > 0 && avatarUrl) {
            NSString *sep = [avatarUrl containsString:@"?"] ? @"&" : @"?";
            avatarUrl = [NSString stringWithFormat:@"%@%@v=%@", avatarUrl, sep, memberInfo.avatarCacheKey];
        }
    }

    self.nameLbl.text = displayName;
    self.nameLbl.textColor = [WKApp shared].config.defaultTextColor;
    self.avatarView.url = avatarUrl;
    self.backgroundColor = [WKApp shared].config.cellBackgroundColor;
}

@end

#pragma mark -

@interface WKThreadMemberListVC () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *memberTableView;
@property (nonatomic, strong) NSArray *creators;
@property (nonatomic, strong) NSArray *commons;
@end

@implementation WKThreadMemberListVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LLang(@"子区成员");
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;

    self.creators = @[];
    self.commons = @[];

    CGFloat navBottom = [self getNavBottom];
    self.memberTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, navBottom, self.view.lim_width, self.view.lim_height - navBottom) style:UITableViewStyleGrouped];
    self.memberTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.memberTableView.dataSource = self;
    self.memberTableView.delegate = self;
    self.memberTableView.backgroundColor = [UIColor clearColor];
    self.memberTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.memberTableView.estimatedRowHeight = 0;
    self.memberTableView.estimatedSectionHeaderHeight = 0;
    self.memberTableView.estimatedSectionFooterHeight = 0;
    self.memberTableView.sectionHeaderHeight = 0.0f;
    self.memberTableView.sectionFooterHeight = 0.0f;
    self.memberTableView.tableFooterView = [[UIView alloc] init];
    [self.memberTableView registerClass:[WKThreadMemberCell class] forCellReuseIdentifier:kCellId];
    [self.view addSubview:self.memberTableView];

    [self loadMembers];
}

- (void)loadMembers {
    if (!self.groupNo || !self.shortId) return;
    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] getThreadMembers:self.groupNo shortId:self.shortId].then(^(NSArray *members) {
        NSMutableArray *c = [NSMutableArray array];
        NSMutableArray *m = [NSMutableArray array];
        for (NSUInteger i = 0; i < members.count; i++) {
            if (i == 0) {
                [c addObject:members[i]];
            } else {
                [m addObject:members[i]];
            }
        }
        weakSelf.creators = c;
        weakSelf.commons = m;
        [weakSelf.memberTableView reloadData];
    }).catch(^(NSError *error) {
        [weakSelf.view showMsg:error.domain];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger count = 0;
    if (self.creators.count > 0) count++;
    if (self.commons.count > 0) count++;
    return MAX(count, 1);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.creators.count > 0 && section == 0) return self.creators.count;
    return self.commons.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 70.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 20.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.01f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = (self.creators.count > 0 && section == 0) ? LLang(@"创建者") : LLang(@"成员");
    UIView *headView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.lim_width, 20.0f)];
    headView.backgroundColor = [WKApp shared].config.backgroundColor;
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, headView.lim_width, headView.lim_height)];
    titleLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
    titleLbl.textColor = [UIColor grayColor];
    titleLbl.text = title;
    [headView addSubview:titleLbl];
    return headView;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [[UIView alloc] init];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKThreadMemberCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellId forIndexPath:indexPath];
    NSArray *list = (self.creators.count > 0 && indexPath.section == 0) ? self.creators : self.commons;
    if (indexPath.row < (NSInteger)list.count) {
        NSDictionary *member = list[indexPath.row];
        NSString *uid = member[@"uid"] ?: @"";
        NSString *name = member[@"name"] ?: uid;
        [cell refreshWithUid:uid name:name];
    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *list = (self.creators.count > 0 && indexPath.section == 0) ? self.creators : self.commons;
    if (indexPath.row >= (NSInteger)list.count) return;

    NSDictionary *member = list[indexPath.row];
    NSString *uid = member[@"uid"] ?: @"";
    if (uid.length > 0) {
        [[WKApp shared] invoke:WKPOINT_USER_INFO param:@{@"uid": uid}];
    }
}

@end
