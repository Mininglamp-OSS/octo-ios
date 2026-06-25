//
//  WKMessageListView+Fold.m
//  WuKongBase
//

#import "WKMessageListView+Fold.h"
#import "WKBotFoldSessionCell.h"
#import "WKMessageListDataProvider.h"
#import "WKMessageModel.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <objc/runtime.h>

// 调试用开关：NSUserDefaults `WKBotFoldDebug` = YES 时打开冗长 NSLog；
// 用于复现"折叠开启后部分气泡渲染异常"等问题——发布前关闭。
//
// 合规 CLAUDE.md「调试工具的生命周期」：仅排障期间打开，定位完即去 default 关；
// 上线版本严禁默认 YES。
static BOOL WKFoldDebugLog(void) {
    static BOOL on = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        on = [[NSUserDefaults standardUserDefaults] boolForKey:@"WKBotFoldDebug"];
    });
    return on;
}
#define WK_FOLD_LOG(fmt, ...) do { if (WKFoldDebugLog()) NSLog(@"[FoldDbg] " fmt, ##__VA_ARGS__); } while (0)

NSString * const WKBotFoldDisabledUserDefaultsKey = @"WKBotFoldDisabled";

#pragma mark - 状态容器（associated object）

@interface WKMessageListViewFoldState : NSObject
@property(nonatomic, strong) WKBotFoldEngine *engine;
@property(nonatomic, strong) NSMutableSet<NSString *> *regularIDs;       // "停留期间已普通展示"
@property(nonatomic, strong) NSMutableSet<NSString *> *expandedMessageIDs; // 已展开会话内"每一条" clientMsgNo（跨 pulldown/pullup 稳定，与 first-id 方案不同）
@property(nonatomic, assign) BOOL pageVisible;
@property(nonatomic, strong, nullable) NSArray<NSArray<WKBotFoldRenderItem *> *> *renderItemsBySection;
@property(nonatomic, copy, nullable) NSString *cacheToken;
@end

@implementation WKMessageListViewFoldState
- (instancetype)init {
    if (self = [super init]) {
        _engine = [WKBotFoldEngine new];
        _regularIDs = [NSMutableSet set];
        _expandedMessageIDs = [NSMutableSet set];
        _pageVisible = NO;
        _renderItemsBySection = nil;
        _cacheToken = nil;
    }
    return self;
}
@end

#pragma mark - Category 实现

@implementation WKMessageListView (Fold)

static char kFoldStateKey;

- (WKMessageListViewFoldState *)wk_fold_state {
    WKMessageListViewFoldState *s = objc_getAssociatedObject(self, &kFoldStateKey);
    if (!s) {
        s = [WKMessageListViewFoldState new];
        objc_setAssociatedObject(self, &kFoldStateKey, s, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return s;
}

#pragma mark 外部入口

- (void)wk_fold_applyPageVisible:(BOOL)visible {
    WKMessageListViewFoldState *s = [self wk_fold_state];
    if (s.pageVisible == visible) return;
    s.pageVisible = visible;
    // 不立刻清 regularIDs：已经"普通展示"的消息保持原状（防抖动）。
    // 但需要让下一次重算尊重新的 visible 状态（虽然 visible 只影响 noteIncoming 这一侧，
    // 不直接进 engine config，这里不需 invalidate cache）。
}

- (void)wk_fold_noteIncomingMessages:(NSArray<WKMessageModel *> *)messages {
    if (messages.count == 0) return;
    WKMessageListViewFoldState *s = [self wk_fold_state];
    if (!s.pageVisible) return;     // 不在页面，按 web 等价规则折叠
    // app 进后台 / 非 Active → 用户事实上已离开页面，不算"停留"
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;
    if (![self wk_fold_isEnabled]) return;
    // 一键关闭开关命中 → 完全不参与状态机，退化为 web 等价（全部按规则折叠）
    if ([[NSUserDefaults standardUserDefaults] boolForKey:WKBotFoldDisabledUserDefaultsKey]) return;

    BOOL added = NO;
    for (WKMessageModel *m in messages) {
        if (m.clientMsgNo.length == 0) continue;
        if (![WKBotFoldEngine isFoldableBotMessage:m]) continue;
        if (![s.regularIDs containsObject:m.clientMsgNo]) {
            [s.regularIDs addObject:m.clientMsgNo];
            added = YES;
        }
    }
    if (added) {
        s.renderItemsBySection = nil;
        s.cacheToken = nil;
        NSLog(@"[FoldDbg] noteIncomingMessages INVALIDATE — regularIDs.count=%lu", (unsigned long)s.regularIDs.count);
    }
}

- (void)wk_fold_invalidate {
    WKMessageListViewFoldState *s = [self wk_fold_state];
    s.renderItemsBySection = nil;
    s.cacheToken = nil;
}

#pragma mark 启用判定

- (BOOL)wk_fold_isEnabled {
    // 必须是群（含子区），单聊不启用。
    // 注意：iOS 的 channelInfo.robot 只对单聊 bot 频道（1v1）为 YES；群里 channel
    // 本身**永远** robot=NO（bot 标记落在群成员 memberOfFrom.robot 上），所以这里
    // 不再叠加 channelInfo.robot 检查——否则群里永远不启用折叠。
    // 群里实际是否有 bot 消息由 engine 的 botMessageJudge 逐条判定；没有 bot
    // 消息时 engine 自然 pass-through，零开销。
    WKChannel *ch = self.channel;
    if (!ch || ch.channelType == WK_PERSON) return NO;
    return YES;
}

#pragma mark cache 重建

/// 构造 token 用于判断是否需要重算。changes in dataProvider 时 token 变化；
/// regularIDs / expandedMessageIDs 变化也需要 token 失效（已在调用处把 cache 清空）。
- (NSString *)wk_fold_buildCacheToken {
    NSInteger dateCount = [self.dataProvider dateCount];
    WKMessageModel *last = nil;
    if ([self.dataProvider respondsToSelector:@selector(lastMessage)]) {
        last = [self.dataProvider lastMessage];
    }
    NSInteger msgCount = [self.dataProvider messageCount];
    WKMessageListViewFoldState *s = [self wk_fold_state];
    return [NSString stringWithFormat:@"dc%ld-mc%ld-last%@-r%lu-e%lu",
            (long)dateCount,
            (long)msgCount,
            last.clientMsgNo ?: @"-",
            (unsigned long)s.regularIDs.count,
            (unsigned long)s.expandedMessageIDs.count];
}

- (void)wk_fold_ensureCache {
    WKMessageListViewFoldState *s = [self wk_fold_state];
    NSString *now = [self wk_fold_buildCacheToken];
    if (s.renderItemsBySection && [now isEqualToString:s.cacheToken]) return;

    WKBotFoldEngineConfig *cfg = [WKBotFoldEngineConfig defaultConfig];
    cfg.isChannelGroup = (self.channel.channelType != WK_PERSON);
    cfg.isChannelRobot = YES; // 不再用 channel-level robot 闸（见 wk_fold_isEnabled 注释）；
                              // 真正的 bot 判定由下面的 botMessageJudge 逐条做。
    cfg.disabled = NO; // 折叠功能本身始终启用（受频道前置约束）；一键开关仅控制"停留"状态机
    cfg.referenceTimestamp = [NSDate date].timeIntervalSince1970;
    cfg.expandedMessageIDs = [s.expandedMessageIDs copy]; // engine 直接处理展开态，无需 dry-run
    __weak typeof(self) weakSelf = self;
    cfg.botMessageJudge = ^BOOL(WKMessageModel *m) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return NO;
        // 群里 bot 主路径：群成员表上的 robot 标记（工程其它地方判 bot 也用这个，
        // 见 WKMessageCell.m:547/676/819）
        if (m.memberOfFrom && m.memberOfFrom.robot) return YES;
        // fallback 1：from（发送者频道信息）的 robot 字段（单聊 bot 或全局 bot 标记）
        if (m.from && m.from.robot) return YES;
        // fallback 2：消息正文带 robotID
        if (m.message.content.robotID.length > 0) return YES;
        return NO;
    };

    NSInteger dateCount = [self.dataProvider dateCount];
    NSMutableArray<NSArray<WKBotFoldRenderItem *> *> *out = [NSMutableArray arrayWithCapacity:dateCount];
    for (NSInteger sec = 0; sec < dateCount; sec++) {
        NSArray<WKMessageModel *> *msgs = [self.dataProvider messagesAtSection:sec];
        NSArray<WKBotFoldRenderItem *> *items = [s.engine buildRenderItemsForMessages:msgs
                                                                                config:cfg
                                                                alreadyShownAsRegular:s.regularIDs];
        [out addObject:(items ?: @[])];
    }
    s.renderItemsBySection = out;
    s.cacheToken = now;

    NSMutableString *secInfo = [NSMutableString string];
    for (NSInteger sec = 0; sec < dateCount; sec++) {
        [secInfo appendFormat:@" s%ld=%lu", (long)sec, (unsigned long)out[sec].count];
    }
    NSLog(@"[FoldDbg] ensureCache REBUILT token=%@%@", now, secInfo);
}

#pragma mark dataSource 查询

- (NSInteger)wk_fold_renderItemsCountInSection:(NSInteger)section {
    if (![self wk_fold_isEnabled]) {
        WK_FOLD_LOG(@"countInSection sec=%ld → NSNotFound (fold disabled)", (long)section);
        return NSNotFound;
    }
    [self wk_fold_ensureCache];
    WKMessageListViewFoldState *s = [self wk_fold_state];
    NSInteger out;
    if (section < 0 || section >= (NSInteger)s.renderItemsBySection.count) {
        out = 0;
    } else {
        out = s.renderItemsBySection[section].count;
    }
    WK_FOLD_LOG(@"countInSection sec=%ld → %ld (raw=%ld)", (long)section, (long)out,
                (long)[self.dataProvider messagesAtSection:section].count);
    return out;
}

- (WKBotFoldRenderItem *)wk_fold_renderItemAtIndexPath:(NSIndexPath *)indexPath {
    if (![self wk_fold_isEnabled]) return nil;
    [self wk_fold_ensureCache];
    WKMessageListViewFoldState *s = [self wk_fold_state];
    if (indexPath.section < 0 || indexPath.section >= (NSInteger)s.renderItemsBySection.count) {
        WK_FOLD_LOG(@"renderItemAt %ld,%ld → nil (section out of range, sectionsInCache=%lu)",
                    (long)indexPath.section, (long)indexPath.row,
                    (unsigned long)s.renderItemsBySection.count);
        return nil;
    }
    NSArray<WKBotFoldRenderItem *> *items = s.renderItemsBySection[indexPath.section];
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)items.count) {
        WK_FOLD_LOG(@"renderItemAt %ld,%ld → nil (row out of range, rowsInSection=%lu)",
                    (long)indexPath.section, (long)indexPath.row, (unsigned long)items.count);
        return nil;
    }
    return items[indexPath.row];
}

#pragma mark cell / height

- (UITableViewCell *)wk_fold_dequeueCellForSession:(WKBotFoldSession *)session
                                          tableView:(UITableView *)tableView
                                          indexPath:(NSIndexPath *)indexPath {
    WKBotFoldSessionCell *cell = [tableView dequeueReusableCellWithIdentifier:kWKBotFoldSessionCellReuseId];
    if (!cell) {
        cell = [[WKBotFoldSessionCell alloc] initWithStyle:UITableViewCellStyleDefault
                                            reuseIdentifier:kWKBotFoldSessionCellReuseId];
    }
    [cell configureWithSession:session expanded:session.expanded];
    // tap 只在 cell 的 titleRow 上响应（cell 内自己装的 gesture）→ 回调到这里 → toggle。
    // 不再让 didSelectRowAtIndexPath: 触发——避免 UITableView 默认 cell tap 跟 cell 内
    // 自己的 gesture 双触发，导致 expandedMessageIDs 状态在 0/N 之间反复振荡。
    __weak typeof(self) wself = self;
    cell.onToggleExpand = ^(WKBotFoldSession *s) {
        [wself wk_fold_toggleExpandForSession:s];
    };
    return cell;
}

- (CGFloat)wk_fold_heightForSession:(WKBotFoldSession *)session {
    CGFloat w = self.tableView.bounds.size.width;
    if (w <= 0) w = [UIScreen mainScreen].bounds.size.width;
    return [WKBotFoldSessionCell heightForSession:session tableViewWidth:w expanded:session.expanded];
}

#pragma mark - 锚点 clientMsgNo（pulldown/pullup 位置还原用）

- (NSString *)wk_fold_anchorClientMsgNoAtTableIndexPath:(NSIndexPath *)ip {
    if (!ip) return nil;
    if (![self wk_fold_isEnabled]) return nil;
    [self wk_fold_ensureCache];
    WKMessageListViewFoldState *s = [self wk_fold_state];
    if (ip.section < 0 || ip.section >= (NSInteger)s.renderItemsBySection.count) return nil;
    NSArray<WKBotFoldRenderItem *> *items = s.renderItemsBySection[ip.section];
    if (ip.row < 0 || ip.row >= (NSInteger)items.count) return nil;
    WKBotFoldRenderItem *it = items[ip.row];
    if (it.type == WKBotFoldRenderItemTypeMessage) {
        return it.message.clientMsgNo;
    }
    return it.foldSession.messages.firstObject.clientMsgNo;
}

- (NSArray<WKMessageModel *> *)wk_fold_coveredMessagesForTableIndexPath:(NSIndexPath *)ip {
    if (!ip) return @[];
    if (![self wk_fold_isEnabled]) return @[];
    [self wk_fold_ensureCache];
    WKMessageListViewFoldState *s = [self wk_fold_state];
    if (ip.section < 0 || ip.section >= (NSInteger)s.renderItemsBySection.count) return @[];
    NSArray<WKBotFoldRenderItem *> *items = s.renderItemsBySection[ip.section];
    if (ip.row < 0 || ip.row >= (NSInteger)items.count) return @[];
    WKBotFoldRenderItem *it = items[ip.row];
    if (it.type == WKBotFoldRenderItemTypeMessage) {
        return it.message ? @[it.message] : @[];
    }
    return it.foldSession.messages ?: @[];
}

- (BOOL)wk_fold_shouldForceShowAvatarAtTableIndexPath:(NSIndexPath *)ip {
    if (!ip) return NO;
    if (![self wk_fold_isEnabled]) return NO;
    [self wk_fold_ensureCache];
    WKMessageListViewFoldState *s = [self wk_fold_state];
    if (ip.section < 0 || ip.section >= (NSInteger)s.renderItemsBySection.count) return NO;
    NSArray<WKBotFoldRenderItem *> *items = s.renderItemsBySection[ip.section];
    if (ip.row < 0 || ip.row >= (NSInteger)items.count) return NO;
    WKBotFoldRenderItem *it = items[ip.row];
    if (it.type != WKBotFoldRenderItemTypeMessage) return NO;

    WKMessageModel *target = it.message;
    if (target.clientMsgNo.length == 0) return NO;

    // 向上找最近的 FoldSession，并验证 target 是其成员
    WKBotFoldSession *belongTo = nil;
    NSInteger foldRow = -1;
    for (NSInteger r = ip.row - 1; r >= 0; r--) {
        WKBotFoldRenderItem *prev = items[r];
        if (prev.type == WKBotFoldRenderItemTypeFoldSession) {
            for (WKMessageModel *m in prev.foldSession.messages) {
                if ([m.clientMsgNo isEqualToString:target.clientMsgNo]) {
                    belongTo = prev.foldSession;
                    foldRow = r;
                    break;
                }
            }
            break;
        }
    }
    if (!belongTo) return NO;

    // 收起态：target 是折叠卡之后那条"最后一条预览"，必须显示头像（不然分辨不出发送方）
    if (!belongTo.expanded) return YES;

    // 展开态：target 是该展开块内"该 bot 的首条"
    // - 紧贴 fold 卡（ip.row == foldRow+1）→ YES
    // - 否则看上一条 Message 的 fromUid 是否不同 → 不同则 YES
    if (ip.row - 1 == foldRow) return YES;
    WKBotFoldRenderItem *prevItem = items[ip.row - 1];
    if (prevItem.type == WKBotFoldRenderItemTypeMessage
        && ![prevItem.message.fromUid isEqualToString:(target.fromUid ?: @"")]) {
        return YES;
    }
    return NO;
}

#pragma mark - 跨折叠 indexPath 翻译

- (NSIndexPath *)wk_fold_translatedIndexPathForDataProviderIndexPath:(NSIndexPath *)dpIndexPath
                                                       expandIfNeeded:(BOOL)expand {
    if (!dpIndexPath) return nil;
    if (![self wk_fold_isEnabled]) return nil;
    // 取出 dataProvider 上对应的消息——折叠改变的是渲染拓扑，dataProvider 行号未变
    WKMessageModel *target = [self.dataProvider messageAtIndexPath:dpIndexPath];
    if (!target || target.clientMsgNo.length == 0) return nil;

    [self wk_fold_ensureCache];
    WKMessageListViewFoldState *s = [self wk_fold_state];
    NSInteger section = dpIndexPath.section;
    if (section < 0 || section >= (NSInteger)s.renderItemsBySection.count) return nil;

    NSArray<WKBotFoldRenderItem *> *items = s.renderItemsBySection[section];
    for (NSInteger row = 0; row < (NSInteger)items.count; row++) {
        WKBotFoldRenderItem *it = items[row];
        if (it.type == WKBotFoldRenderItemTypeMessage) {
            if ([it.message.clientMsgNo isEqualToString:target.clientMsgNo]) {
                return [NSIndexPath indexPathForRow:row inSection:section];
            }
        } else {
            // FoldSession：判断该组是否包含目标
            BOOL containsTarget = NO;
            for (WKMessageModel *m in it.foldSession.messages) {
                if ([m.clientMsgNo isEqualToString:target.clientMsgNo]) {
                    containsTarget = YES;
                    break;
                }
            }
            if (!containsTarget) continue;
            // 该组已展开 → 真正的 Message 行就在本 FoldSession 之后，let loop find it
            if (it.foldSession.expanded) continue;
            // 折叠态且不需要展开 → 返回折叠卡所在行
            if (!expand) {
                return [NSIndexPath indexPathForRow:row inSection:section];
            }
            NSString *firstId = it.foldSession.messages.firstObject.clientMsgNo;
            if (firstId.length == 0) {
                return [NSIndexPath indexPathForRow:row inSection:section];
            }
            // 标记整组为展开：把所有 clientMsgNo 加进集合（per-message，跨 reload 稳定）。
            // **注意**：这里只更新数据 + 失效 cache，**不主动调 reloadData**——
            // 该方法可能在 scrollToIndex 等正进行 UITableView 布局的栈里被调用，
            // 同步 reloadData 会触发 NSInternalInconsistencyException。
            // 由调用方在合适时机自行 reloadData。
            BOOL needsRebuild = NO;
            for (WKMessageModel *mm in it.foldSession.messages) {
                if (mm.clientMsgNo.length > 0 && ![s.expandedMessageIDs containsObject:mm.clientMsgNo]) {
                    [s.expandedMessageIDs addObject:mm.clientMsgNo];
                    needsRebuild = YES;
                }
            }
            if (needsRebuild) {
                s.renderItemsBySection = nil;
                s.cacheToken = nil;
            }
            return [self wk_fold_translatedIndexPathForDataProviderIndexPath:dpIndexPath
                                                               expandIfNeeded:NO];
        }
    }
    return nil;
}

#pragma mark - 增量更新（pullup / pulldown 路径用，避免 reloadData 闪屏）

- (NSArray<NSArray<WKBotFoldRenderItem *> *> *)wk_fold_snapshotRenderItemsBySection {
    if (![self wk_fold_isEnabled]) return nil;
    [self wk_fold_ensureCache];
    WKMessageListViewFoldState *s = [self wk_fold_state];
    // 深拷外层数组（内层 NSArray 不可变可共享）
    return [s.renderItemsBySection copy];
}

// 判定"身份相同"：用于 LCP / LCS——Message 看 clientMsgNo；FoldSession 看首条 cmn（组身份）
- (BOOL)wk_fold_item:(WKBotFoldRenderItem *)a sameIdentityAs:(WKBotFoldRenderItem *)b {
    if (!a || !b || a.type != b.type) return NO;
    if (a.type == WKBotFoldRenderItemTypeMessage) {
        NSString *ac = a.message.clientMsgNo;
        NSString *bc = b.message.clientMsgNo;
        if (ac.length == 0 || bc.length == 0) return NO;
        return [ac isEqualToString:bc];
    }
    NSString *af = a.foldSession.messages.firstObject.clientMsgNo;
    NSString *bf = b.foldSession.messages.firstObject.clientMsgNo;
    if (af.length == 0 || bf.length == 0) return NO;
    return [af isEqualToString:bf];
}

// 判定"内容完全相同"：身份相同 + 折叠组的 count/expanded/isActive/lastCmn 全一致 → 不用 reload
- (BOOL)wk_fold_item:(WKBotFoldRenderItem *)a fullyEqualsTo:(WKBotFoldRenderItem *)b {
    if (![self wk_fold_item:a sameIdentityAs:b]) return NO;
    if (a.type == WKBotFoldRenderItemTypeMessage) return YES;
    WKBotFoldSession *sa = a.foldSession, *sb = b.foldSession;
    if (sa.messages.count != sb.messages.count) return NO;
    if (sa.expanded != sb.expanded) return NO;
    if (sa.isActive != sb.isActive) return NO;
    NSString *al = sa.messages.lastObject.clientMsgNo;
    NSString *bl = sb.messages.lastObject.clientMsgNo;
    if (al.length == 0 || bl.length == 0) return NO;
    return [al isEqualToString:bl];
}

- (NSInteger)wk_fold_commonPrefixLengthOfOld:(NSArray<WKBotFoldRenderItem *> *)old andNew:(NSArray<WKBotFoldRenderItem *> *)new_ {
    NSInteger n = MIN(old.count, new_.count);
    for (NSInteger i = 0; i < n; i++) {
        if (![self wk_fold_item:old[i] sameIdentityAs:new_[i]]) return i;
    }
    return n;
}

- (NSInteger)wk_fold_commonSuffixLengthOfOld:(NSArray<WKBotFoldRenderItem *> *)old andNew:(NSArray<WKBotFoldRenderItem *> *)new_ {
    NSInteger n = MIN(old.count, new_.count);
    for (NSInteger i = 0; i < n; i++) {
        NSInteger oi = (NSInteger)old.count - 1 - i;
        NSInteger ni = (NSInteger)new_.count - 1 - i;
        if (![self wk_fold_item:old[oi] sameIdentityAs:new_[ni]]) return i;
    }
    return n;
}

- (void)wk_fold_applyPullupIncrementalWithOldItemsBySection:(NSArray<NSArray<WKBotFoldRenderItem *> *> *)oldItemsBySection
                                              oldSectionCount:(NSInteger)oldSecCount
                                            newSectionsAdded:(NSInteger)newSectionsAdded
                                                   completion:(void(^)(void))completion {
    void (^runCompletion)(void) = ^{ if (completion) completion(); };
    NSLog(@"[FoldDbg] applyPullupIncremental ENTER oldSec=%ld newSecAdded=%ld snapshot=%@ enabled=%d",
          (long)oldSecCount, (long)newSectionsAdded,
          oldItemsBySection ? @"yes" : @"NIL", [self wk_fold_isEnabled]);
    if (!oldItemsBySection || ![self wk_fold_isEnabled]) {
        runCompletion();
        return;
    }

    // 竞态防御：snapshot 拍下到 apply 之间，可能被其它路径（典型：handleRecvMessage
    // 命中 inSync=NO → reloadData → fold cache rebuild）刷掉了。此时 tableView 的"老行数"
    // 已经不是 snapshot 这一份，强行 incremental 会让 oldCount + insert - delete 算错 →
    // UIKit assert → 即便 @try 兜底也会污染 layout → 后续 cell 渲染失败。
    // 检查当前 cache 是否还和 snapshot 对得上；不对就 fallback 到 reloadData。
    WKMessageListViewFoldState *s = [self wk_fold_state];
    BOOL snapshotStale = NO;
    if (s.renderItemsBySection == nil
        || s.renderItemsBySection.count != oldItemsBySection.count) {
        snapshotStale = YES;
    } else {
        for (NSInteger i = 0; i < (NSInteger)oldItemsBySection.count; i++) {
            if (((NSArray *)oldItemsBySection[i]).count != ((NSArray *)s.renderItemsBySection[i]).count) {
                snapshotStale = YES;
                break;
            }
        }
    }
    if (snapshotStale) {
        // 详细 diagnostic：列出 snapshot 与 current 每 section 的 row 数对比，定位是哪里改了
        NSMutableString *detail = [NSMutableString string];
        NSInteger maxN = MAX((NSInteger)oldItemsBySection.count, (NSInteger)s.renderItemsBySection.count);
        for (NSInteger i = 0; i < maxN; i++) {
            NSInteger oc = i < (NSInteger)oldItemsBySection.count ? (NSInteger)((NSArray *)oldItemsBySection[i]).count : -1;
            NSInteger cc = i < (NSInteger)s.renderItemsBySection.count ? (NSInteger)((NSArray *)s.renderItemsBySection[i]).count : -1;
            [detail appendFormat:@" s%ld(o=%ld c=%ld)", (long)i, (long)oc, (long)cc];
        }
        NSLog(@"[FoldDbg][WARN] pullup snapshot stale (oldSec=%lu currentSec=%lu)%@ — falling back to reloadData",
              (unsigned long)oldItemsBySection.count,
              (unsigned long)s.renderItemsBySection.count,
              detail);
        [self wk_fold_invalidate];
        BOOL wasAtBottom = self.positionAtBottom;
        [UIView performWithoutAnimation:^{ [self.tableView reloadData]; }];
        // reloadData 后 contentSize 可能变小（dataProvider 被别的路径重置成新窗口），
        // 老 contentOffset 留在旧位置 → 屏幕显示空区域。若用户原本在底部，强制重新
        // 滚到新底部，避免空白屏。
        if (wasAtBottom) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView layoutIfNeeded];
                [self scrollToBottom:NO];
            });
        }
        runCompletion();
        return;
    }

    // 刷新 fold cache → 拿 newItemsBySection
    [self wk_fold_invalidate];
    [self wk_fold_ensureCache];
    NSArray<NSArray<WKBotFoldRenderItem *> *> *newItemsBySection =
        [self wk_fold_state].renderItemsBySection;

    NSMutableArray<NSIndexPath *> *toDelete = [NSMutableArray array];
    NSMutableArray<NSIndexPath *> *toInsert = [NSMutableArray array];
    NSMutableArray<NSIndexPath *> *toReload = [NSMutableArray array];

    // pullup：旧 sections [0..oldSecCount) 对应新 sections 相同 index；新 sections 在 [oldSecCount..)
    for (NSInteger s = 0; s < oldSecCount; s++) {
        NSArray<WKBotFoldRenderItem *> *oldItems = (s < (NSInteger)oldItemsBySection.count) ? oldItemsBySection[s] : @[];
        NSArray<WKBotFoldRenderItem *> *newItems = (s < (NSInteger)newItemsBySection.count) ? newItemsBySection[s] : @[];
        NSInteger prefix = [self wk_fold_commonPrefixLengthOfOld:oldItems andNew:newItems];
        for (NSInteger i = 0; i < prefix; i++) {
            if (![self wk_fold_item:oldItems[i] fullyEqualsTo:newItems[i]]) {
                [toReload addObject:[NSIndexPath indexPathForRow:i inSection:s]];
            }
        }
        for (NSInteger i = prefix; i < (NSInteger)oldItems.count; i++) {
            [toDelete addObject:[NSIndexPath indexPathForRow:i inSection:s]];
        }
        for (NSInteger i = prefix; i < (NSInteger)newItems.count; i++) {
            [toInsert addObject:[NSIndexPath indexPathForRow:i inSection:s]];
        }
    }
    NSIndexSet *newSections = newSectionsAdded > 0
        ? [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(oldSecCount, newSectionsAdded)]
        : nil;

    NSLog(@"[FoldDbg] applyPullupIncremental DIFF delete=%lu insert=%lu reload=%lu newSec=%ld",
          (unsigned long)toDelete.count, (unsigned long)toInsert.count,
          (unsigned long)toReload.count, (long)newSectionsAdded);

    if (toDelete.count == 0 && toInsert.count == 0 && toReload.count == 0 && !newSections) {
        NSLog(@"[FoldDbg] applyPullupIncremental NO-OP — completion fired immediately");
        runCompletion();
        return;
    }

    // 预检 1：UIKit 缓存 vs snapshot 的行数。`-[UITableView numberOfRowsInSection:]`
    // 返回 tableView 内部缓存（上一次 batch 结果或 reloadData 后定型的值），不是 dataSource
    // 当下的回答。若不等于 snapshot.count，说明 dataProvider 在上一次 batch 之后被外部路径
    // 静默改过——典型场景：SDK `onTyping` 直接 addMessage 加 typing 但不 insertRows，
    // mc 涨了但 tableView 不知道。再走 performBatchUpdates 必然在
    // _endCellAnimationsWithContext: 抛行数断言。直接 reloadData 让 UIKit 重新对齐
    // dataSource，跳过 batch，永不让 UIKit 抛 assert。
    BOOL uikitInSync = YES;
    for (NSInteger sec = 0; sec < oldSecCount; sec++) {
        NSInteger uiCached = [self.tableView numberOfRowsInSection:sec];
        NSInteger snapRows = (sec < (NSInteger)oldItemsBySection.count) ? (NSInteger)((NSArray *)oldItemsBySection[sec]).count : 0;
        if (uiCached != snapRows) {
            NSLog(@"[FoldDbg][WARN] applyPullupIncremental UIKIT-STALE sec=%ld uikitCached=%ld snapRows=%ld — typing/streaming changed dataProvider outside batch; falling back to reloadData",
                  (long)sec, (long)uiCached, (long)snapRows);
            uikitInSync = NO;
            break;
        }
    }
    if (!uikitInSync) {
        [UIView performWithoutAnimation:^{ [self.tableView reloadData]; }];
        runCompletion();
        return;
    }

    // 预检 2：per-section 自洽性。"snapshot.count + 该 section 的插 - 该 section 的删 = new.count"。
    // 引擎自身的折叠规则在某些不可调和的中间态下也可能产出不自洽的 diff，预检 2 兜底。
    NSMutableDictionary<NSNumber *, NSNumber *> *perSecDelete = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSNumber *, NSNumber *> *perSecInsert = [NSMutableDictionary dictionary];
    for (NSIndexPath *ip in toDelete) {
        NSNumber *k = @(ip.section);
        perSecDelete[k] = @((perSecDelete[k].integerValue) + 1);
    }
    for (NSIndexPath *ip in toInsert) {
        NSNumber *k = @(ip.section);
        perSecInsert[k] = @((perSecInsert[k].integerValue) + 1);
    }
    BOOL mathOk = YES;
    for (NSInteger sec = 0; sec < oldSecCount; sec++) {
        NSInteger oldRows = (sec < (NSInteger)oldItemsBySection.count) ? (NSInteger)((NSArray *)oldItemsBySection[sec]).count : 0;
        NSInteger newRows = (sec < (NSInteger)newItemsBySection.count) ? (NSInteger)((NSArray *)newItemsBySection[sec]).count : 0;
        NSInteger del = perSecDelete[@(sec)].integerValue;
        NSInteger ins = perSecInsert[@(sec)].integerValue;
        if (oldRows + ins - del != newRows) {
            NSLog(@"[FoldDbg][WARN] applyPullupIncremental MATH MISMATCH sec=%ld old=%ld ins=%ld del=%ld new=%ld — falling back to reloadData",
                  (long)sec, (long)oldRows, (long)ins, (long)del, (long)newRows);
            mathOk = NO;
            break;
        }
    }
    if (!mathOk) {
        [UIView performWithoutAnimation:^{ [self.tableView reloadData]; }];
        runCompletion();
        return;
    }

    [UIView performWithoutAnimation:^{
        @try {
            NSLog(@"[FoldDbg] applyPullupIncremental performBatchUpdates BEGIN");
            [self.tableView performBatchUpdates:^{
                if (toDelete.count) [self.tableView deleteRowsAtIndexPaths:toDelete withRowAnimation:UITableViewRowAnimationNone];
                if (toReload.count) [self.tableView reloadRowsAtIndexPaths:toReload withRowAnimation:UITableViewRowAnimationNone];
                if (toInsert.count) [self.tableView insertRowsAtIndexPaths:toInsert withRowAnimation:UITableViewRowAnimationNone];
                if (newSections)   [self.tableView insertSections:newSections withRowAnimation:UITableViewRowAnimationNone];
            } completion:^(BOOL finished) {
                NSLog(@"[FoldDbg] applyPullupIncremental performBatchUpdates COMPLETION finished=%d", finished);
                runCompletion();
            }];
            NSLog(@"[FoldDbg] applyPullupIncremental performBatchUpdates SUBMITTED");
        } @catch (NSException *ex) {
            NSLog(@"[FoldDbg][ERROR] applyPullupIncremental performBatchUpdates THREW: %@ — falling back to reloadData", ex);
            [self.tableView reloadData];
            runCompletion();
        }
    }];
}

- (void)wk_fold_applyPulldownIncrementalWithOldItemsBySection:(NSArray<NSArray<WKBotFoldRenderItem *> *> *)oldItemsBySection
                                              oldSectionCount:(NSInteger)oldSecCount
                                            newSectionsAdded:(NSInteger)newSectionsAdded
                                                   completion:(void(^)(void))completion {
    if (!oldItemsBySection || ![self wk_fold_isEnabled]) {
        if (completion) completion();
        return;
    }

    // 竞态防御：见 pullup 同名注释。snapshot 失效就 fallback reloadData。
    WKMessageListViewFoldState *s = [self wk_fold_state];
    BOOL snapshotStale = NO;
    if (s.renderItemsBySection == nil
        || s.renderItemsBySection.count != oldItemsBySection.count) {
        snapshotStale = YES;
    } else {
        for (NSInteger i = 0; i < (NSInteger)oldItemsBySection.count; i++) {
            if (((NSArray *)oldItemsBySection[i]).count != ((NSArray *)s.renderItemsBySection[i]).count) {
                snapshotStale = YES;
                break;
            }
        }
    }
    if (snapshotStale) {
        NSLog(@"[FoldDbg][WARN] pulldown snapshot stale (oldSec=%lu currentSec=%lu) — falling back to reloadData",
              (unsigned long)oldItemsBySection.count,
              (unsigned long)s.renderItemsBySection.count);
        [self wk_fold_invalidate];
        BOOL wasAtBottom = self.positionAtBottom;
        [UIView performWithoutAnimation:^{ [self.tableView reloadData]; }];
        // 同 pullup 路径：reloadData 后若用户在底部，强制滚到新底部避免空屏
        if (wasAtBottom) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView layoutIfNeeded];
                [self scrollToBottom:NO];
            });
        }
        if (completion) completion();
        return;
    }

    [self wk_fold_invalidate];
    [self wk_fold_ensureCache];
    NSArray<NSArray<WKBotFoldRenderItem *> *> *newItemsBySection =
        [self wk_fold_state].renderItemsBySection;

    NSMutableArray<NSIndexPath *> *toDelete = [NSMutableArray array];
    NSMutableArray<NSIndexPath *> *toInsert = [NSMutableArray array];
    NSMutableArray<NSIndexPath *> *toReload = [NSMutableArray array];

    // pulldown：旧 section s → 新 section (s + newSectionsAdded)；新 sections 在 [0..newSectionsAdded)
    for (NSInteger s = 0; s < oldSecCount; s++) {
        NSInteger newS = s + newSectionsAdded;
        NSArray<WKBotFoldRenderItem *> *oldItems = (s < (NSInteger)oldItemsBySection.count) ? oldItemsBySection[s] : @[];
        NSArray<WKBotFoldRenderItem *> *newItems = (newS < (NSInteger)newItemsBySection.count) ? newItemsBySection[newS] : @[];
        NSInteger suffix = [self wk_fold_commonSuffixLengthOfOld:oldItems andNew:newItems];
        for (NSInteger i = 0; i < suffix; i++) {
            NSInteger oi = (NSInteger)oldItems.count - 1 - i;
            NSInteger ni = (NSInteger)newItems.count - 1 - i;
            if (![self wk_fold_item:oldItems[oi] fullyEqualsTo:newItems[ni]]) {
                [toReload addObject:[NSIndexPath indexPathForRow:oi inSection:s]];
            }
        }
        for (NSInteger i = 0; i < (NSInteger)oldItems.count - suffix; i++) {
            [toDelete addObject:[NSIndexPath indexPathForRow:i inSection:s]];
        }
        for (NSInteger i = 0; i < (NSInteger)newItems.count - suffix; i++) {
            [toInsert addObject:[NSIndexPath indexPathForRow:i inSection:newS]];
        }
    }
    NSIndexSet *newSections = newSectionsAdded > 0
        ? [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, newSectionsAdded)]
        : nil;

    void (^runCompletion)(void) = ^{
        if (completion) completion();
    };
    if (toDelete.count == 0 && toInsert.count == 0 && toReload.count == 0 && !newSections) {
        runCompletion();
        return;
    }

    // 预检：UIKit 缓存 vs snapshot 行数一致性（typing/streaming 等外部静默 addMessage
    // 会让 UIKit 缓存的旧 section 行数过时；不预检的话 performBatchUpdates 会触发
    // _endCellAnimationsWithContext: 行数断言）。注意 pulldown 新增的 section 在
    // [0..newSectionsAdded)，老 section 在 tableView 里仍是 [0..oldSecCount)，对它们查询缓存。
    BOOL uikitInSync = YES;
    for (NSInteger sec = 0; sec < oldSecCount; sec++) {
        NSInteger uiCached = [self.tableView numberOfRowsInSection:sec];
        NSInteger snapRows = (sec < (NSInteger)oldItemsBySection.count) ? (NSInteger)((NSArray *)oldItemsBySection[sec]).count : 0;
        if (uiCached != snapRows) {
            NSLog(@"[FoldDbg][WARN] applyPulldownIncremental UIKIT-STALE sec=%ld uikitCached=%ld snapRows=%ld — falling back to reloadData",
                  (long)sec, (long)uiCached, (long)snapRows);
            uikitInSync = NO;
            break;
        }
    }
    if (!uikitInSync) {
        [UIView performWithoutAnimation:^{ [self.tableView reloadData]; }];
        runCompletion();
        return;
    }

    [UIView performWithoutAnimation:^{
        @try {
            [self.tableView performBatchUpdates:^{
                if (newSections)   [self.tableView insertSections:newSections withRowAnimation:UITableViewRowAnimationNone];
                if (toDelete.count) [self.tableView deleteRowsAtIndexPaths:toDelete withRowAnimation:UITableViewRowAnimationNone];
                if (toInsert.count) [self.tableView insertRowsAtIndexPaths:toInsert withRowAnimation:UITableViewRowAnimationNone];
                if (toReload.count) [self.tableView reloadRowsAtIndexPaths:toReload withRowAnimation:UITableViewRowAnimationNone];
            } completion:^(BOOL finished) {
                runCompletion();
            }];
        } @catch (NSException *ex) {
            NSLog(@"[FoldDbg] pulldown incremental FAILED: %@ — falling back to reloadData", ex);
            [self.tableView reloadData];
            runCompletion();
        }
    }];
}

#pragma mark - 展开/收起

- (void)wk_fold_toggleExpandForSession:(WKBotFoldSession *)session {
    if (session.messages.count == 0) return;
    WKMessageListViewFoldState *s = [self wk_fold_state];

    // 是否已展开：本组任一消息 clientMsgNo 在集合中即视为已展开
    BOOL currentlyExpanded = NO;
    for (WKMessageModel *m in session.messages) {
        if (m.clientMsgNo.length > 0 && [s.expandedMessageIDs containsObject:m.clientMsgNo]) {
            currentlyExpanded = YES;
            break;
        }
    }

    if (currentlyExpanded) {
        // 收起：把本组所有 clientMsgNo 从集合移除
        for (WKMessageModel *m in session.messages) {
            if (m.clientMsgNo.length > 0) [s.expandedMessageIDs removeObject:m.clientMsgNo];
        }
    } else {
        // 展开：把本组所有 clientMsgNo 加入集合（per-message 而非 first-id；
        // 跨 pulldown/pullup 新加入的同组成员只要任一旧 id 还在集合里就保持展开）
        for (WKMessageModel *m in session.messages) {
            if (m.clientMsgNo.length > 0) [s.expandedMessageIDs addObject:m.clientMsgNo];
        }
    }
    s.renderItemsBySection = nil;
    s.cacheToken = nil;

    // 异步派发 reload：toggle 由 didSelectRowAtIndexPath: 触发，UITableView 还在
    // 处理选中流程；同步 reloadData 在某些 iOS 版本会让 UIKit 内部状态错乱（崩或
    // 渲染漂移）。dispatch_async 让 reload 走到下一拍 runloop 才执行，避开冲突。
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [UIView transitionWithView:strongSelf.tableView
                          duration:0.18
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{ [strongSelf.tableView reloadData]; }
                        completion:nil];
    });
}

@end
