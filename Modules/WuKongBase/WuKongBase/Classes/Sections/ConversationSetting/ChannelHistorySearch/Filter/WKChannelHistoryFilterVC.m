//
//  WKChannelHistoryFilterVC.m
//

#import "WKChannelHistoryFilterVC.h"
#import "WKChannelHistorySenderPickerVC.h"
#import "WKGlobalSearchPickerVC.h"
#import "WKApp.h"
#import "WKAvatarUtil.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKChannelInfoDB.h"
#import "WKSpaceFilter.h"
#import "WKConversationListVM.h"
#import "WKGroupManager.h"

#define kRowHeight 52.0f

/// section 类型。会话内搜索只用 Sender/Date/Sort；全局搜索追加 Channels/Members/ChatType +
/// ContentType(消息) / FileType(文件)。用动态 sectionKinds 数组驱动，避免固定 index 脆弱。
typedef NS_ENUM(NSInteger, WKCHFilterKind) {
    WKCHFilterKindSender = 0,
    WKCHFilterKindChannels,
    WKCHFilterKindMembers,
    WKCHFilterKindChatType,
    WKCHFilterKindContentType,
    WKCHFilterKindFileType,
    WKCHFilterKindDate,
    WKCHFilterKindSort,
};

@interface WKChannelHistoryFilterVC () <
    UITableViewDataSource, UITableViewDelegate,
    WKChannelHistorySenderPickerVCDelegate
>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *resetBtn;
@property (nonatomic, strong) UIButton *applyBtn;

/// 已加载的发送人简要展示文本缓存（避免每次 cellForRow 都查 channel manager）。
@property (nonatomic, copy) NSString *senderSummaryText;

/// 是否展示"发送人"section。会话内搜索无频道（channel==nil）时隐藏；全局搜索始终展示
/// （走好友候选，见 WKGlobalSearchPickerVC）。
@property (nonatomic, assign) BOOL showSender;

/// 当前 section 顺序（元素为 WKCHFilterKind 装箱）。
@property (nonatomic, copy) NSArray<NSNumber *> *sectionKinds;

@end

@implementation WKChannelHistoryFilterVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    self.title = LLang(@"筛选");
    if (!self.draft) self.draft = [WKChannelHistorySearchFilter new];
    self.showSender = self.globalMode || (self.channel != nil);
    [self rebuildSections];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(onCancel)];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = kRowHeight;
    self.tableView.backgroundColor = [WKApp shared].config.backgroundColor;
    [self.view addSubview:self.tableView];

    self.bottomBar = [UIView new];
    self.bottomBar.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    [self.view addSubview:self.bottomBar];

    self.resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.resetBtn setTitle:LLang(@"重置") forState:UIControlStateNormal];
    [self.resetBtn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    self.resetBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:16.0f];
    self.resetBtn.layer.borderWidth = 0.5f;
    self.resetBtn.layer.borderColor = [[UIColor grayColor] colorWithAlphaComponent:0.3].CGColor;
    self.resetBtn.layer.cornerRadius = 22.0f;
    [self.resetBtn addTarget:self action:@selector(onReset) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.resetBtn];

    self.applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.applyBtn setTitle:LLang(@"应用") forState:UIControlStateNormal];
    [self.applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.applyBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:16.0f];
    self.applyBtn.backgroundColor = [WKApp shared].config.themeColor;
    self.applyBtn.layer.cornerRadius = 22.0f;
    [self.applyBtn addTarget:self action:@selector(onApply) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.applyBtn];

    [self refreshSenderSummary];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat barH = 64.0f;
    CGFloat safe = self.view.safeAreaInsets.bottom;
    CGFloat barY = self.view.lim_height - safe - barH;
    self.tableView.frame = CGRectMake(0, 0, self.view.lim_width, barY);
    self.bottomBar.frame = CGRectMake(0, barY, self.view.lim_width, barH + safe);
    CGFloat btnW = (self.view.lim_width - 16 * 3) / 2.0f;
    self.resetBtn.frame = CGRectMake(16, 10, btnW, 44);
    self.applyBtn.frame = CGRectMake(self.view.lim_width - 16 - btnW, 10, btnW, 44);
}

#pragma mark - sender summary

- (void)refreshSenderSummary {
    NSArray<NSString *> *uids = self.draft.senderUids ?: @[];
    if (uids.count == 0) {
        self.senderSummaryText = LLang(@"全部成员");
        return;
    }
    // 简单显示数量；多人时不在此 fetch 头像名，避免拖慢
    self.senderSummaryText = [NSString stringWithFormat:LLang(@"已选 %ld 人"), (long)uids.count];
}

#pragma mark - sections

- (void)rebuildSections {
    NSMutableArray<NSNumber *> *k = [NSMutableArray array];
    if (self.showSender) [k addObject:@(WKCHFilterKindSender)];
    if (self.globalMode) {
        [k addObject:@(WKCHFilterKindChannels)];
        [k addObject:@(WKCHFilterKindMembers)];
        [k addObject:@(WKCHFilterKindChatType)];
    }
    if (self.showContentTypes) [k addObject:@(WKCHFilterKindContentType)];
    if (self.showFileTypes) [k addObject:@(WKCHFilterKindFileType)];
    [k addObject:@(WKCHFilterKindDate)];
    [k addObject:@(WKCHFilterKindSort)];
    self.sectionKinds = k;
}

- (WKCHFilterKind)kindForSection:(NSInteger)section {
    if (section < 0 || section >= (NSInteger)self.sectionKinds.count) return WKCHFilterKindDate;
    return (WKCHFilterKind)[self.sectionKinds[section] integerValue];
}

- (NSInteger)sectionForKind:(WKCHFilterKind)kind {
    NSInteger i = [self.sectionKinds indexOfObject:@(kind)];
    return i == NSNotFound ? -1 : i;
}

- (void)reloadKind:(WKCHFilterKind)kind {
    NSInteger s = [self sectionForKind:kind];
    if (s >= 0) [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:s] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - 选项常量

+ (NSArray<NSDictionary *> *)contentTypeOptions {
    static NSArray *opts = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        opts = @[ @{@"label": LLang(@"文字"), @"value": @1},
                  @{@"label": LLang(@"图片"), @"value": @2},
                  @{@"label": LLang(@"视频"), @"value": @5},
                  @{@"label": LLang(@"文件"), @"value": @8},
                  @{@"label": LLang(@"合并转发"), @"value": @11},
                  @{@"label": LLang(@"图文"), @"value": @14} ];
    });
    return opts;
}

+ (NSArray<NSDictionary *> *)fileCategoryOptions {
    static NSArray *opts = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        opts = @[ @{@"label": LLang(@"文档"), @"exts": @[@"doc", @"docx"]},
                  @{@"label": LLang(@"表格"), @"exts": @[@"xls", @"xlsx"]},
                  @{@"label": @"PDF", @"exts": @[@"pdf"]},
                  @{@"label": LLang(@"压缩包"), @"exts": @[@"zip", @"rar", @"7z", @"tar", @"gz"]},
                  @{@"label": LLang(@"网页"), @"exts": @[@"html", @"htm"]},
                  @{@"label": LLang(@"文本"), @"exts": @[@"txt"]},
                  @{@"label": @"Markdown", @"exts": @[@"md"]},
                  @{@"label": @"GIF", @"exts": @[@"gif"]},
                  @{@"label": LLang(@"视频"), @"exts": @[@"mp4", @"avi", @"mov", @"mkv", @"webm"]} ];
    });
    return opts;
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.sectionKinds.count; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ([self kindForSection:section]) {
        case WKCHFilterKindSender:      return 1;
        case WKCHFilterKindChannels:    return 1;
        case WKCHFilterKindMembers:     return 1;
        case WKCHFilterKindChatType:    return 2; // 单聊 / 群聊
        case WKCHFilterKindContentType: return [[self class] contentTypeOptions].count;
        case WKCHFilterKindFileType:    return [[self class] fileCategoryOptions].count;
        case WKCHFilterKindDate:        return 3; // 起始 / 结束 / 快速
        case WKCHFilterKindSort:        return 2; // 倒序 / 正序
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return 32.0f; }

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *v = [UIView new];
    v.backgroundColor = [WKApp shared].config.backgroundColor;
    UILabel *t = [UILabel new];
    t.frame = CGRectMake(16, 8, 300, 22);
    t.font = [[WKApp shared].config appFontOfSize:13.0f];
    t.textColor = [UIColor grayColor];
    switch ([self kindForSection:section]) {
        case WKCHFilterKindSender:      t.text = LLang(@"发送者"); break;
        case WKCHFilterKindChannels:    t.text = LLang(@"所在群聊或子区"); break;
        case WKCHFilterKindMembers:     t.text = LLang(@"包含成员"); break;
        case WKCHFilterKindChatType:    t.text = LLang(@"聊天类型"); break;
        case WKCHFilterKindContentType: t.text = LLang(@"消息类型"); break;
        case WKCHFilterKindFileType:    t.text = LLang(@"文件类型"); break;
        case WKCHFilterKindDate:        t.text = LLang(@"日期范围"); break;
        case WKCHFilterKindSort:        t.text = LLang(@"排序"); break;
    }
    [v addSubview:t];
    return v;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"row"];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.font = [[WKApp shared].config appFontOfSize:15.0f];
    cell.textLabel.textColor = [WKApp shared].config.defaultTextColor;
    cell.detailTextLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
    cell.detailTextLabel.textColor = [UIColor grayColor];

    static NSDateFormatter *dateFmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dateFmt = [NSDateFormatter new];
        dateFmt.dateFormat = @"yyyy/MM/dd";
    });

    switch ([self kindForSection:indexPath.section]) {
        case WKCHFilterKindSender:
            cell.textLabel.text = LLang(@"选择发送人");
            cell.detailTextLabel.text = self.senderSummaryText;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        case WKCHFilterKindChannels:
            cell.textLabel.text = LLang(@"选择群聊或子区");
            cell.detailTextLabel.text = [self countSummary:self.draft.channels.count unit:LLang(@"个")];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        case WKCHFilterKindMembers:
            cell.textLabel.text = LLang(@"选择成员");
            cell.detailTextLabel.text = [self countSummary:self.draft.memberUids.count unit:LLang(@"人")];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        case WKCHFilterKindChatType: {
            BOOL on = (indexPath.row == 0)
                ? [self.draft.channelTypes containsObject:@1]
                : ([self.draft.channelTypes containsObject:@2] || [self.draft.channelTypes containsObject:@5]);
            cell.textLabel.text = (indexPath.row == 0) ? LLang(@"单聊") : LLang(@"群聊");
            cell.detailTextLabel.text = on ? @"✓" : @"";
            cell.detailTextLabel.textColor = [WKApp shared].config.themeColor;
            break;
        }
        case WKCHFilterKindContentType: {
            NSDictionary *opt = [[self class] contentTypeOptions][indexPath.row];
            cell.textLabel.text = opt[@"label"];
            cell.detailTextLabel.text = [self.draft.contentTypes containsObject:opt[@"value"]] ? @"✓" : @"";
            cell.detailTextLabel.textColor = [WKApp shared].config.themeColor;
            break;
        }
        case WKCHFilterKindFileType: {
            NSDictionary *opt = [[self class] fileCategoryOptions][indexPath.row];
            cell.textLabel.text = opt[@"label"];
            cell.detailTextLabel.text = [self isFileCategorySelected:opt] ? @"✓" : @"";
            cell.detailTextLabel.textColor = [WKApp shared].config.themeColor;
            break;
        }
        case WKCHFilterKindDate:
            if (indexPath.row == 0) {
                cell.textLabel.text = LLang(@"起始日期");
                cell.detailTextLabel.text = self.draft.startDate ? [dateFmt stringFromDate:self.draft.startDate] : LLang(@"不限");
            } else if (indexPath.row == 1) {
                cell.textLabel.text = LLang(@"结束日期");
                cell.detailTextLabel.text = self.draft.endDate ? [dateFmt stringFromDate:self.draft.endDate] : LLang(@"不限");
            } else {
                cell.textLabel.text = LLang(@"快速选择");
                cell.detailTextLabel.text = LLang(@"今天 / 7 天 / 30 天 / 全部");
            }
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        case WKCHFilterKindSort: {
            NSInteger curSort = self.draft.sort;
            BOOL selected = (indexPath.row == 0 && curSort == WKChannelHistorySearchSortTimeDesc)
                          || (indexPath.row == 1 && curSort == WKChannelHistorySearchSortTimeAsc);
            cell.textLabel.text = indexPath.row == 0 ? LLang(@"时间倒序（最新在前）") : LLang(@"时间正序（最早在前）");
            cell.detailTextLabel.text = selected ? @"✓" : @"";
            cell.detailTextLabel.textColor = [WKApp shared].config.themeColor;
            break;
        }
    }
    return cell;
}

- (NSString *)countSummary:(NSInteger)n unit:(NSString *)unit {
    if (n <= 0) return LLang(@"不限");
    return [NSString stringWithFormat:LLang(@"已选 %ld %@"), (long)n, unit];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch ([self kindForSection:indexPath.section]) {
        case WKCHFilterKindSender:   [self openSenderPicker]; break;
        case WKCHFilterKindChannels: [self openChannelPicker]; break;
        case WKCHFilterKindMembers:  [self openMemberPicker]; break;
        case WKCHFilterKindChatType:
            [self toggleChatTypeRow:indexPath.row];
            [self reloadKind:WKCHFilterKindChatType];
            break;
        case WKCHFilterKindContentType:
            [self toggleContentTypeAt:indexPath.row];
            [self reloadKind:WKCHFilterKindContentType];
            break;
        case WKCHFilterKindFileType:
            [self toggleFileTypeAt:indexPath.row];
            [self reloadKind:WKCHFilterKindFileType];
            break;
        case WKCHFilterKindDate:
            if (indexPath.row == 0) [self showDatePickerForStart:YES];
            else if (indexPath.row == 1) [self showDatePickerForStart:NO];
            else [self showPresetSheet];
            break;
        case WKCHFilterKindSort:
            self.draft.sort = (indexPath.row == 0) ? WKChannelHistorySearchSortTimeDesc : WKChannelHistorySearchSortTimeAsc;
            [self reloadKind:WKCHFilterKindSort];
            break;
    }
}

#pragma mark - 发送者 / 群聊子区 / 成员 选择

- (void)openSenderPicker {
    if (!self.globalMode) {
        // 会话内搜索：仍走花名册作用域的发送人选择器。
        WKChannelHistorySenderPickerVC *p = [WKChannelHistorySenderPickerVC new];
        p.channel = self.channel;
        p.selectedUids = self.draft.senderUids ?: @[];
        p.delegate = self;
        [self.navigationController pushViewController:p animated:YES];
        return;
    }
    __weak typeof(self) ws = self;
    WKGlobalSearchPickerVC *p = [WKGlobalSearchPickerVC new];
    p.navTitle = LLang(@"发送者");
    p.searchPlaceholder = LLang(@"搜索成员");
    p.preselected = [self entriesForUids:self.draft.senderUids];
    p.candidateProvider = ^(NSString *kw, void (^done)(NSArray<WKGlobalSearchPickEntry *> *)) { [ws provideFriendCandidates:kw completion:done]; };
    p.onFinish = ^(NSArray<WKGlobalSearchPickEntry *> *sel) {
        ws.draft.senderUids = [ws uidsFromEntries:sel];
        [ws refreshSenderSummary];
        [ws reloadKind:WKCHFilterKindSender];
    };
    [self.navigationController pushViewController:p animated:YES];
}

- (void)openMemberPicker {
    __weak typeof(self) ws = self;
    WKGlobalSearchPickerVC *p = [WKGlobalSearchPickerVC new];
    p.navTitle = LLang(@"包含成员");
    p.searchPlaceholder = LLang(@"搜索成员");
    p.preselected = [self entriesForUids:self.draft.memberUids];
    p.candidateProvider = ^(NSString *kw, void (^done)(NSArray<WKGlobalSearchPickEntry *> *)) { [ws provideFriendCandidates:kw completion:done]; };
    p.onFinish = ^(NSArray<WKGlobalSearchPickEntry *> *sel) {
        ws.draft.memberUids = [ws uidsFromEntries:sel];
        [ws reloadKind:WKCHFilterKindMembers];
    };
    [self.navigationController pushViewController:p animated:YES];
}

- (void)openChannelPicker {
    __weak typeof(self) ws = self;
    WKGlobalSearchPickerVC *p = [WKGlobalSearchPickerVC new];
    p.navTitle = LLang(@"所在群聊或子区");
    p.searchPlaceholder = LLang(@"搜索群聊");
    p.preselected = [self entriesForChannels:self.draft.channels];
    p.candidateProvider = ^(NSString *kw, void (^done)(NSArray<WKGlobalSearchPickEntry *> *)) { [ws provideGroupCandidates:kw completion:done]; };
    p.onFinish = ^(NSArray<WKGlobalSearchPickEntry *> *sel) {
        NSMutableArray<NSDictionary *> *chs = [NSMutableArray array];
        for (WKGlobalSearchPickEntry *e in sel) {
            if (e.identifier.length == 0) continue;
            [chs addObject:@{ @"channel_id": e.identifier,
                              @"channel_type": @(e.channelType > 0 ? e.channelType : WK_GROUP),
                              @"name": e.name ?: @"" }];
        }
        ws.draft.channels = chs.count > 0 ? chs : nil;
        [ws reloadKind:WKCHFilterKindChannels];
    };
    [self.navigationController pushViewController:p animated:YES];
}

- (NSArray<NSString *> *)uidsFromEntries:(NSArray<WKGlobalSearchPickEntry *> *)entries {
    NSMutableArray<NSString *> *uids = [NSMutableArray array];
    for (WKGlobalSearchPickEntry *e in entries) { if (e.identifier.length > 0) [uids addObject:e.identifier]; }
    return uids.count > 0 ? uids : nil;
}

- (NSArray<WKGlobalSearchPickEntry *> *)entriesForUids:(NSArray<NSString *> *)uids {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *uid in uids) {
        if (uid.length == 0) continue;
        [out addObject:[WKGlobalSearchPickEntry entryWithId:uid name:uid avatarUrl:[WKAvatarUtil getAvatar:uid] channelType:0]];
    }
    return out;
}

- (NSArray<WKGlobalSearchPickEntry *> *)entriesForChannels:(NSArray<NSDictionary *> *)channels {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *c in channels) {
        NSString *cid = c[@"channel_id"];
        if (![cid isKindOfClass:[NSString class]] || cid.length == 0) continue;
        NSInteger ct = [c[@"channel_type"] integerValue];
        NSString *name = [c[@"name"] isKindOfClass:[NSString class]] ? c[@"name"] : cid;
        [out addObject:[WKGlobalSearchPickEntry entryWithId:cid name:name avatarUrl:[WKAvatarUtil getGroupAvatar:cid] channelType:ct]];
    }
    return out;
}

/// 好友候选（发送者/成员）：本地 DB 关键词搜索，离线可用（与 web 本地兜底同源）。
- (void)provideFriendCandidates:(NSString *)keyword completion:(void (^)(NSArray<WKGlobalSearchPickEntry *> *))done {
    NSArray<WKChannelInfo *> *list = [[WKChannelInfoDB shared] queryChannelInfoWithFriend:(keyword ?: @"") limit:50];
    NSMutableArray<WKGlobalSearchPickEntry *> *out = [NSMutableArray array];
    for (WKChannelInfo *info in list) {
        NSString *uid = info.channel.channelId;
        if (uid.length == 0) continue;
        // Space 隔离：与 WKGlobalSearchVM 同款过滤，避免其它空间的好友泄漏进候选。
        if (![self channelInCurrentSpace:uid type:WK_PERSON]) continue;
        NSString *name = info.remark.length > 0 ? info.remark : (info.name.length > 0 ? info.name : uid);
        [out addObject:[WKGlobalSearchPickEntry entryWithId:uid name:name avatarUrl:[WKAvatarUtil getAvatar:uid] channelType:0]];
    }
    if (done) done(out);
}

/// 群聊/子区候选：本地 DB 群频道关键词搜索（子区枚举首版从略，与 web v1 一致）。
- (void)provideGroupCandidates:(NSString *)keyword completion:(void (^)(NSArray<WKGlobalSearchPickEntry *> *))done {
    NSArray<WKChannelInfo *> *list = [[WKChannelInfoDB shared] queryChannelInfoWithType:(keyword ?: @"") channelType:WK_GROUP limit:50];
    NSMutableArray<WKGlobalSearchPickEntry *> *out = [NSMutableArray array];
    for (WKChannelInfo *info in list) {
        NSString *cid = info.channel.channelId;
        if (cid.length == 0) continue;
        if (![self channelInCurrentSpace:cid type:WK_GROUP]) continue;
        NSString *name = info.remark.length > 0 ? info.remark : (info.name.length > 0 ? info.name : cid);
        [out addObject:[WKGlobalSearchPickEntry entryWithId:cid name:name avatarUrl:[WKAvatarUtil getGroupAvatar:cid] channelType:WK_GROUP]];
    }
    if (done) done(out);
}

/// 候选是否属于当前 Space。逐字对齐 WKGlobalSearchVM.isChannelInCurrentSpace: 语义
/// （currentSpaceId 为空=单空间不过滤；群 Keep→YES/Skip→NO/FailOpen→会话列表白名单且未初始化 fail-closed；
///  人/Bot 仅 Skip 才排除，缺 space_id 的历史私聊向前兼容放行）。
- (BOOL)channelInCurrentSpace:(NSString *)channelId type:(uint8_t)type {
    if (channelId.length == 0) return NO;
    NSString *sid = [[WKSpaceFilter shared] currentSpaceId];
    if (sid.length == 0) return YES;
    if (type == WK_GROUP || type == WK_COMMUNITY_TOPIC) {
        NSString *groupId = channelId;
        if (type == WK_COMMUNITY_TOPIC) {
            NSRange sep = [channelId rangeOfString:@"____"];
            if (sep.location != NSNotFound) groupId = [channelId substringToIndex:sep.location];
        }
        WKSpaceFilterDecision d = [[WKSpaceFilter shared] decideChannel:groupId channelType:WK_GROUP];
        if (d == WKSpaceFilterDecisionKeep) return YES;
        if (d == WKSpaceFilterDecisionSkip) return NO;
        WKConversationListVM *vm = [WKConversationListVM shared];
        if (![vm isGroupWhitelistInitialized]) return NO; // 白名单未初始化期 fail-closed
        return [vm isGroupInWhitelist:groupId];
    }
    return [[WKSpaceFilter shared] decideChannel:channelId channelType:type] != WKSpaceFilterDecisionSkip;
}

- (void)toggleChatTypeRow:(NSInteger)row {
    NSMutableArray<NSNumber *> *cur = [self.draft.channelTypes mutableCopy] ?: [NSMutableArray array];
    if (row == 0) {
        // 单聊 = [1]
        if ([cur containsObject:@1]) [cur removeObject:@1]; else [cur addObject:@1];
    } else {
        // 群聊 = [2,5]（子区随群）
        BOOL on = [cur containsObject:@2] || [cur containsObject:@5];
        [cur removeObject:@2]; [cur removeObject:@5];
        if (!on) { [cur addObject:@2]; [cur addObject:@5]; }
    }
    self.draft.channelTypes = cur.count > 0 ? cur : nil;
}


#pragma mark - 类型多选

- (BOOL)isFileCategorySelected:(NSDictionary *)opt {
    NSArray<NSString *> *exts = opt[@"exts"];
    if (exts.count == 0) return NO;
    NSArray<NSString *> *cur = self.draft.fileExts ?: @[];
    for (NSString *e in exts) {
        if (![cur containsObject:e]) return NO;
    }
    return YES;
}

- (void)toggleContentTypeAt:(NSInteger)row {
    NSDictionary *opt = [[self class] contentTypeOptions][row];
    NSNumber *val = opt[@"value"];
    NSMutableArray *cur = [self.draft.contentTypes mutableCopy] ?: [NSMutableArray array];
    if ([cur containsObject:val]) [cur removeObject:val]; else [cur addObject:val];
    self.draft.contentTypes = cur.count > 0 ? cur : nil;
}

- (void)toggleFileTypeAt:(NSInteger)row {
    NSDictionary *opt = [[self class] fileCategoryOptions][row];
    NSArray<NSString *> *exts = opt[@"exts"];
    NSMutableArray *cur = [self.draft.fileExts mutableCopy] ?: [NSMutableArray array];
    if ([self isFileCategorySelected:opt]) {
        for (NSString *e in exts) [cur removeObject:e];
    } else {
        for (NSString *e in exts) { if (![cur containsObject:e]) [cur addObject:e]; }
    }
    self.draft.fileExts = cur.count > 0 ? cur : nil;
}

#pragma mark - date

- (void)showDatePickerForStart:(BOOL)isStart {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:isStart ? LLang(@"起始日期") : LLang(@"结束日期")
                                                                 message:@"\n\n\n\n\n\n\n\n\n"
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 30, ac.view.lim_width - 20, 200)];
    picker.datePickerMode = UIDatePickerModeDate;
    if (@available(iOS 14.0, *)) picker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    NSDate *initial = isStart ? self.draft.startDate : self.draft.endDate;
    if (!initial) initial = [NSDate date];
    picker.date = initial;
    [ac.view addSubview:picker];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"清除") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        if (isStart) self.draft.startDate = nil; else self.draft.endDate = nil;
        [self reloadKind:WKCHFilterKindDate];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"确定") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        if (isStart) self.draft.startDate = picker.date; else self.draft.endDate = picker.date;
        // 守卫：开始 > 结束 时自动交换，避免请求体两个日期顺序倒挂导致服务端返回空。
        if (self.draft.startDate && self.draft.endDate
            && [self.draft.startDate compare:self.draft.endDate] == NSOrderedDescending) {
            NSDate *tmp = self.draft.startDate;
            self.draft.startDate = self.draft.endDate;
            self.draft.endDate = tmp;
        }
        [self reloadKind:WKCHFilterKindDate];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    // iPad 上 actionSheet 走 popover, 必须有非 nil 的 sourceView + sourceRect。
    // 起/止日期两个日期入口都是从 filter 表格里的日期 cell 点触发, 直接锚到 self.view 中心。
    if (ac.popoverPresentationController) {
        ac.popoverPresentationController.sourceView = self.view;
        ac.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2,
                                                                 self.view.bounds.size.height / 2, 0, 0);
        ac.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)showPresetSheet {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:LLang(@"快速选择")
                                                                 message:nil
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    void(^apply)(NSInteger) = ^(NSInteger days) {
        NSDate *end = [NSDate date];
        NSDate *start;
        if (days <= 0) {
            start = nil;
        } else if (days == 1) {
            // "今天" 特化: 起点为今日 00:00, 不做 24h 回退。API 只发 yyyy-MM-dd (见
            // WKChannelHistorySearchModels.toApiDict), now-24h 会拿到昨日日期使
            // sent_at_from 跨两个自然日 (PR #64 review yujiawei 命中)。
            start = [[NSCalendar currentCalendar] startOfDayForDate:end];
        } else {
            start = [end dateByAddingTimeInterval:-(days * 24 * 3600)];
        }
        self.draft.startDate = start;
        self.draft.endDate = days > 0 ? end : nil;
        [self reloadKind:WKCHFilterKindDate];
    };
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"今天") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { apply(1); }]];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"最近 7 天") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { apply(7); }]];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"最近 30 天") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { apply(30); }]];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"全部时间") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { apply(0); }]];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    if (ac.popoverPresentationController) {
        ac.popoverPresentationController.sourceView = self.view;
        ac.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2,
                                                                 self.view.bounds.size.height / 2, 0, 0);
        ac.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - sender picker delegate

- (void)senderPickerVC:(WKChannelHistorySenderPickerVC *)vc didFinishWithUids:(NSArray<NSString *> *)uids {
    self.draft.senderUids = uids;
    [self refreshSenderSummary];
    [self reloadKind:WKCHFilterKindSender];
}

#pragma mark - bottom

- (void)onReset {
    self.draft = [WKChannelHistorySearchFilter new];
    [self refreshSenderSummary];
    [self.tableView reloadData];
}

- (void)onApply {
    if ([self.delegate respondsToSelector:@selector(channelHistoryFilterVC:didApplyFilter:)]) {
        [self.delegate channelHistoryFilterVC:self didApplyFilter:self.draft];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)onCancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
