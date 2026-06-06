// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRichTextMentionPickerVC.m
//  WuKongBase
//

#import "WKRichTextMentionPickerVC.h"
#import "WKMentionUserCell.h"
#import "WKGroupManager.h"
#import "WKAvatarUtil.h"
#import "WuKongBase.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

@interface WKRichTextMentionPickerVC () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property(nonatomic, strong) WKChannel *channel;
@property(nonatomic, copy) NSString *initialKeyword;
@property(nonatomic, copy) NSString *currentKeyword;
@property(nonatomic, strong) UISearchBar *searchBar;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, copy) NSArray<WKMentionUserCellModel *> *items;
@property(nonatomic, assign) BOOL settled;
@end

@implementation WKRichTextMentionPickerVC

- (instancetype)initWithChannel:(WKChannel *)channel keyword:(NSString *)keyword {
    if (self = [super init]) {
        _channel = channel;
        _initialKeyword = [keyword copy];
        _currentKeyword = [keyword copy] ?: @"";
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }
    [self buildTopBar];
    [self buildTable];
    [self reload];
}

- (void)buildTopBar {
    UIView *bar = [UIView new];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:bar];

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    cancel.translatesAutoresizingMaskIntoConstraints = NO;
    [cancel setTitle:LLang(@"取消") forState:UIControlStateNormal];
    [cancel setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
    cancel.titleLabel.font = [UIFont systemFontOfSize:16];
    [cancel addTarget:self action:@selector(onCancel) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:cancel];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = LLang(@"选择提醒的人");
    title.font = [UIFont boldSystemFontOfSize:17];
    title.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) { title.textColor = [UIColor labelColor]; }
    else { title.textColor = [UIColor blackColor]; }
    [bar addSubview:title];

    UISearchBar *sb = [UISearchBar new];
    sb.translatesAutoresizingMaskIntoConstraints = NO;
    sb.delegate = self;
    sb.placeholder = LLang(@"搜索");
    sb.searchBarStyle = UISearchBarStyleMinimal;
    sb.text = self.initialKeyword ?: @"";
    self.searchBar = sb;
    [bar addSubview:sb];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bar.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [bar.heightAnchor constraintEqualToConstant:96],

        [cancel.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:16],
        [cancel.topAnchor constraintEqualToAnchor:bar.topAnchor constant:8],
        [cancel.heightAnchor constraintEqualToConstant:32],

        [title.centerXAnchor constraintEqualToAnchor:bar.centerXAnchor],
        [title.centerYAnchor constraintEqualToAnchor:cancel.centerYAnchor],

        [sb.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:8],
        [sb.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-8],
        [sb.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-4],
        [sb.heightAnchor constraintEqualToConstant:44],
    ]];
}

- (void)buildTable {
    UITableView *tv = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    tv.dataSource = self;
    tv.delegate = self;
    tv.rowHeight = 56;
    tv.tableFooterView = [UIView new];
    [tv registerClass:[WKMentionUserCell class] forCellReuseIdentifier:@"WKMentionUserCell"];
    [self.view addSubview:tv];
    self.tableView = tv;

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [tv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tv.topAnchor constraintEqualToAnchor:safe.topAnchor constant:96],
        [tv.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
    ]];
}

#pragma mark - Data

- (void)reload {
    // 与主聊天 WKConversationContextImpl -getMentionUserListWithKeyword: 行为对齐：
    // 不按 channelType 短路，直接 searchMembers——子区/话题(WK_COMMUNITY_TOPIC)依赖
    // SDK 自己回退父群，DM 自然返回空。assembleItems 里 sentinel 仍会展示。
    if (!self.channel) {
        self.items = [self assembleItems:@[]];
        [self.tableView reloadData];
        return;
    }
    __weak typeof(self) weakSelf = self;
    NSString *kw = self.currentKeyword ?: @"";
    [[WKGroupManager shared] searchMembers:self.channel keyword:kw limit:10000 complete:^(WKChannelMemberCacheType cacheType, NSArray<WKChannelMember *> * _Nonnull members) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.items = [strongSelf assembleItems:members];
            [strongSelf.tableView reloadData];
        });
    }];
}

// 按 WKConversationContextImpl.membersToMentionUsers 同款规则装配：sentinel + 真实成员。
- (NSArray<WKMentionUserCellModel *> *)assembleItems:(NSArray<WKChannelMember *> *)members {
    NSString *kw = self.currentKeyword ?: @"";
    NSMutableArray<WKMentionUserCellModel *> *list = [NSMutableArray array];
    // @所有人 仅在群/子区里有意义, 1v1 DM 不应该出现 group-wide sentinel (PR #32 review)。
    BOOL isDM = (self.channel.channelType == WK_PERSON);
    NSString *allStr = LLang(@"所有人");
    if (!isDM && (kw.length == 0 || [allStr containsString:kw])) {
        [list addObject:[WKMentionUserCellModel uid:@"all" name:allStr]];
    }
    NSString *aisStr = LLang(@"所有AI");
    if (kw.length == 0 || [aisStr containsString:kw]) {
        [list addObject:[WKMentionUserCellModel uid:@"__ais__"
                                               name:aisStr
                                          avatarURL:nil
                                              robot:NO
                                             extras:nil]];
    }
    NSString *loginUid = [WKApp shared].loginInfo.uid;
    for (WKChannelMember *m in members) {
        if ([m.memberUid isEqualToString:loginUid]) continue;
        NSString *name = m.displayName ?: @"";
        if (kw.length > 0 && ![name containsString:kw]) continue;
        [list addObject:[WKMentionUserCellModel uid:m.memberUid
                                               name:name
                                          avatarURL:[NSURL URLWithString:[WKAvatarUtil getAvatar:m.memberUid]]
                                              robot:m.robot
                                             extras:m.extra]];
    }
    return list;
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.currentKeyword = searchText ?: @"";
    [self reload];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKMentionUserCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WKMentionUserCell"];
    if (indexPath.row < (NSInteger)self.items.count) {
        [cell refresh:self.items[indexPath.row]];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.settled || indexPath.row >= (NSInteger)self.items.count) return;
    self.settled = YES;
    WKMentionUserCellModel *picked = self.items[indexPath.row];
    void (^cb)(WKMentionUserCellModel *) = self.onSelect;
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(picked);
    }];
}

- (void)onCancel {
    if (self.settled) return;
    self.settled = YES;
    void (^cb)(WKMentionUserCellModel *) = self.onSelect;
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(nil);
    }];
}

@end
