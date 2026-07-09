//
//  WKChannelHistorySenderPickerVC.m
//

#import "WKChannelHistorySenderPickerVC.h"
#import "WKApp.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import "WKAvatarUtil.h"
#import "WKUserAvatar.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKGroupManager.h"

@implementation WKChannelHistorySenderEntry
@end

#pragma mark - Cell

@interface WKChannelHistorySenderCell : UITableViewCell
@property (nonatomic, strong) WKUserAvatar *avatarView;
@property (nonatomic, strong) UILabel *nameLbl;
@property (nonatomic, strong) UIImageView *checkView;
@end

@implementation WKChannelHistorySenderCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        _avatarView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(16, 8, 36, 36)];
        [self.contentView addSubview:_avatarView];
        _nameLbl = [UILabel new];
        _nameLbl.font = [[WKApp shared].config appFontOfSize:15.0f];
        _nameLbl.textColor = [WKApp shared].config.defaultTextColor;
        [self.contentView addSubview:_nameLbl];
        _checkView = [[UIImageView alloc] init];
        _checkView.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.1];
        _checkView.layer.cornerRadius = 10.0f;
        _checkView.layer.masksToBounds = YES;
        _checkView.contentMode = UIViewContentModeCenter;
        [self.contentView addSubview:_checkView];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.lim_width;
    self.avatarView.frame = CGRectMake(16, (52 - 36) / 2.0f, 36, 36);
    self.checkView.frame = CGRectMake(w - 16 - 20, (52 - 20) / 2.0f, 20, 20);
    self.nameLbl.frame = CGRectMake(CGRectGetMaxX(self.avatarView.frame) + 12, 0, w - 16 - 20 - 12 - CGRectGetMaxX(self.avatarView.frame) - 8, 52);
}
- (void)applyEntry:(WKChannelHistorySenderEntry *)e selected:(BOOL)selected {
    self.nameLbl.text = e.displayName ?: @"";
    NSString *url = e.avatarUrl.length > 0
        ? [WKAvatarUtil getFullAvatarWIthPath:e.avatarUrl]
        : [WKAvatarUtil getAvatar:e.uid];
    self.avatarView.url = url;
    self.checkView.backgroundColor = selected
        ? [WKApp shared].config.themeColor
        : [[UIColor grayColor] colorWithAlphaComponent:0.1];
    self.checkView.tintColor = [UIColor whiteColor];
    // 选中用一个"✓"字符标识，避免依赖图片资源
    for (UIView *sub in [self.checkView.subviews copy]) [sub removeFromSuperview];
    if (selected) {
        UILabel *t = [UILabel new];
        t.text = @"✓";
        t.textAlignment = NSTextAlignmentCenter;
        t.textColor = [UIColor whiteColor];
        t.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightBold];
        t.frame = self.checkView.bounds;
        [self.checkView addSubview:t];
    }
}
@end

#pragma mark - VC

@interface WKChannelHistorySenderPickerVC () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<WKChannelHistorySenderEntry *> *entries;
@property (nonatomic, strong) NSMutableSet<NSString *> *selected;
// 搜索请求单调计数器: 快速打字时 searchMembers: 是异步的, 慢完成的老 keyword
// 结果不能覆盖新 keyword 已经清空的 entries (PR #64 review 3 位 reviewer 独立命中)。
// 与 WKChannelHistorySearchVM.reqIdCounter 同款模式。
@property (nonatomic, assign) NSInteger reqIdCounter;
@end

@implementation WKChannelHistorySenderPickerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    self.title = LLang(@"选择发送人");
    self.entries = [NSMutableArray array];
    self.selected = [NSMutableSet setWithArray:self.selectedUids ?: @[]];

    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:LLang(@"完成")
                                                              style:UIBarButtonItemStyleDone
                                                             target:self
                                                             action:@selector(onDone)];
    self.navigationItem.rightBarButtonItem = done;

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = LLang(@"搜索成员");
    self.searchBar.delegate = self;
    self.searchBar.backgroundImage = [UIImage new];
    [self.view addSubview:self.searchBar];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 52.0f;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [WKApp shared].config.backgroundColor;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.tableView registerClass:WKChannelHistorySenderCell.class forCellReuseIdentifier:@"sender"];
    [self.view addSubview:self.tableView];

    [self loadEntriesWithKeyword:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = self.navigationController.navigationBar.lim_bottom;
    if (top == 0) top = 44 + (self.view.window.windowScene.statusBarManager.statusBarFrame.size.height ?: 20);
    self.searchBar.frame = CGRectMake(0, top, self.view.lim_width, 44);
    self.tableView.frame = CGRectMake(0, self.searchBar.lim_bottom, self.view.lim_width, self.view.lim_height - self.searchBar.lim_bottom);
}

- (void)onDone {
    if ([self.delegate respondsToSelector:@selector(senderPickerVC:didFinishWithUids:)]) {
        [self.delegate senderPickerVC:self didFinishWithUids:[self.selected.allObjects copy]];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - load

- (void)loadEntriesWithKeyword:(nullable NSString *)keyword {
    [self.entries removeAllObjects];
    self.reqIdCounter += 1;
    NSInteger reqId = self.reqIdCounter;
    if (self.channel.channelType == WK_PERSON) {
        // 自己 + 对方
        NSString *myUid = [WKSDK shared].options.connectInfo.uid;
        WKChannelInfo *peer = [[WKSDK shared].channelManager getChannelInfo:self.channel];
        WKChannelHistorySenderEntry *me = [WKChannelHistorySenderEntry new];
        me.uid = myUid ?: @"";
        me.displayName = LLang(@"我");
        if (me.uid.length > 0) [self.entries addObject:me];

        WKChannelHistorySenderEntry *p = [WKChannelHistorySenderEntry new];
        p.uid = self.channel.channelId ?: @"";
        p.displayName = peer ? (peer.remark.length > 0 ? peer.remark : peer.name) : self.channel.channelId;
        p.avatarUrl = peer.logo;
        if (p.uid.length > 0) [self.entries addObject:p];

        if (keyword.length > 0) {
            NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(WKChannelHistorySenderEntry *e, id b) {
                return [e.displayName.lowercaseString containsString:keyword.lowercaseString];
            }];
            [self.entries filterUsingPredicate:pred];
        }
        [self.tableView reloadData];
        return;
    }

    // 群 / 子区：用 WKGroupManager.searchMembers (子区使用父群)
    WKChannel *lookupChannel = self.channel;
    if (self.channel.channelType == WK_COMMUNITY_TOPIC) {
        NSRange r = [self.channel.channelId rangeOfString:@"____"];
        if (r.location != NSNotFound) {
            NSString *groupNo = [self.channel.channelId substringToIndex:r.location];
            lookupChannel = [[WKChannel alloc] initWith:groupNo channelType:WK_GROUP];
        }
    }
    __weak typeof(self) ws = self;
    [WKGroupManager.shared searchMembers:lookupChannel
                                  keyword:keyword ?: @""
                                     page:1
                                    limit:200
                          requestStrategy:WKRequestStrategyOnlyNetwork
                                 complete:^(WKChannelMemberCacheType cacheType, NSArray<WKChannelMember *> * _Nonnull members) {
        __strong typeof(ws) ss = ws;
        if (!ss) return;
        // 只有 reqId 仍是最新一轮的才 append; 慢完成的老 keyword 结果直接丢弃。
        if (reqId != ss.reqIdCounter) return;
        for (WKChannelMember *m in members) {
            WKChannelHistorySenderEntry *e = [WKChannelHistorySenderEntry new];
            e.uid = m.memberUid ?: @"";
            e.displayName = m.memberName.length > 0 ? m.memberName : (m.memberRemark.length > 0 ? m.memberRemark : m.memberUid);
            e.avatarUrl = nil;
            if (e.uid.length > 0) [ss.entries addObject:e];
        }
        [ss.tableView reloadData];
    }];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKChannelHistorySenderCell *c = [tableView dequeueReusableCellWithIdentifier:@"sender" forIndexPath:indexPath];
    WKChannelHistorySenderEntry *e = self.entries[indexPath.row];
    [c applyEntry:e selected:[self.selected containsObject:e.uid]];
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    WKChannelHistorySenderEntry *e = self.entries[indexPath.row];
    if ([self.selected containsObject:e.uid]) {
        [self.selected removeObject:e.uid];
    } else {
        if (self.selected.count >= 50) {
            [self.view showMsg:LLang(@"最多选择 50 人")];
            return;
        }
        [self.selected addObject:e.uid];
    }
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - UISearchBar

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadByKeyword:) object:nil];
    [self performSelector:@selector(reloadByKeyword:) withObject:searchText afterDelay:0.16];
}

- (void)reloadByKeyword:(NSString *)kw {
    [self loadEntriesWithKeyword:kw];
}

- (void)dealloc {
    // performSelector:afterDelay: 会强引用 self 直到 selector 触发, 用户在
    // 0.16s 打字 debounce 窗口内快速 pop VC 时, pending 调度会撞到 dealloc-ing
    // self 上 (PR #64 review Octo-Q P2)。dealloc 里主动清一次, 无副作用。
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadByKeyword:) object:nil];
}

@end
