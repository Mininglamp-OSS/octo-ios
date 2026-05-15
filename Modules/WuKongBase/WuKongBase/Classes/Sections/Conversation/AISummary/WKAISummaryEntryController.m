//
//  WKAISummaryEntryController.m
//  WuKongBase
//

#import "WKAISummaryEntryController.h"
#import "WKAISummaryFloatingButton.h"
#import "WKAITextIngestor.h"
#import "WKAISummaryCyberpunkTransition.h"
#import "WKAISummaryActionMenu.h"
#import "WKAISummaryPromptEditor.h"
#import "WKAISummaryPromptStore.h"
#import "WKConversationVC.h"
#import "WKNavigationManager.h"
#import "WKMessageListView.h"
#import "WKConversationPositionBarView.h"
#import "WKApp.h"
#import "WKConstant.h"
#import "WKSpaceBotRegistry.h"
#import "WKSpaceFilter.h"
#import <WuKongBase/WuKongBase-Swift.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <WuKongIMSDK/WKTextContent.h>
#import <objc/runtime.h>

#pragma mark - 常量

static const CGFloat kButtonSize    = 44.0;
static const CGFloat kRightMargin   = 14.0;
static const CGFloat kAboveBarGap   = 8.0;
static const NSInteger kButtonTag   = 0x9F1;

static const NSTimeInterval kReevalDebounce = 0.20;
// 时间档位：仅保留 1 天 / 3 天 / 全部，外加未读 / 自定义
static const NSInteger kRangeUnread = 0;
static const NSInteger kRange1d     = 24 * 3600;
static const NSInteger kRange3d     = 3 * 24 * 3600;
static const NSInteger kRangeAll    = NSIntegerMax;

#pragma mark - Owner

@interface _WKAISummaryEntryOwner : NSObject <WKOnlineStatusManagerDelegate>
@property(nonatomic, weak)   WKMessageListView *host;
@property(nonatomic, strong) WKChannel *channel;
@property(nonatomic, strong) WKAISummaryFloatingButton *button;
@property(nonatomic, strong) WKAITextIngestor *ingestor;

@property(nonatomic, copy)   NSArray<NSString *> *candidateBotUIDs;  // 当前候选 Bot UID 列表
@property(nonatomic, copy)   NSString *selectedBotUID;               // 当前选中 Bot
@property(nonatomic, assign) BOOL chargingUp;
@property(nonatomic, assign) NSInteger reevalGen;
@property(nonatomic, assign) NSInteger pendingHideGen;               // 防抖：sticky hide 用

// 已发出过总结的目标 Bot；命中后短按只 push 不再发，避免重复请求。
// 长按选时间档位仍然走完整发送流程（用户的"再来一份"显式动作）。
@property(nonatomic, strong, nullable) WKChannel *pendingReopenChannel;
@end

@implementation _WKAISummaryEntryOwner

#pragma mark - Lifecycle

- (instancetype)initWithHost:(WKMessageListView *)mlv channel:(WKChannel *)channel {
    if ((self = [super init])) {
        _host = mlv;
        _channel = channel;
    }
    return self;
}

- (void)attach {
    if (self.button) return;
    [self installButton];
    [self subscribeNotifications];
    // 初值：先做一次同步评估
    [self reevaluateNow];
    // 异步再评估几次：群成员/Registry/Online 都是异步加载，多打两枪兜底
    [self scheduleReevalAfter:0.5];
    [self scheduleReevalAfter:1.5];
    [self scheduleReevalAfter:3.0];
}

- (void)detach {
    [self.ingestor stop];
    self.ingestor = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[WKOnlineStatusManager shared] removeDelegate:self];
    [self.button removeFromSuperview];
    self.button = nil;
}

- (void)dealloc { [self detach]; }

#pragma mark - Button install

- (void)installButton {
    WKMessageListView *mlv = self.host;
    if (!mlv) return;
    WKAISummaryFloatingButton *btn = [[WKAISummaryFloatingButton alloc] initWithFrame:CGRectZero];
    btn.tag = kButtonTag;
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.alpha = 0;     // 默认隐藏，候选集到位再显
    btn.hidden = YES;
    [mlv addSubview:btn];

    WKConversationPositionBarView *bar = mlv.conversationPositionBarView;
    NSMutableArray<NSLayoutConstraint *> *cons = [NSMutableArray array];
    [cons addObjectsFromArray:@[
        [btn.widthAnchor  constraintEqualToConstant:kButtonSize],
        [btn.heightAnchor constraintEqualToConstant:kButtonSize],
        [btn.trailingAnchor constraintEqualToAnchor:mlv.trailingAnchor constant:-kRightMargin],
    ]];
    if (bar) {
        [cons addObject:[btn.bottomAnchor constraintEqualToAnchor:bar.topAnchor constant:-kAboveBarGap]];
    } else {
        [cons addObject:[btn.bottomAnchor constraintEqualToAnchor:mlv.bottomAnchor constant:-130]];
    }
    [NSLayoutConstraint activateConstraints:cons];

    [btn addTarget:self action:@selector(onTap) forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
                                        initWithTarget:self action:@selector(onLongPress:)];
    lp.minimumPressDuration = 0.45;
    [btn addGestureRecognizer:lp];

    self.button = btn;
    self.ingestor = [[WKAITextIngestor alloc] initWithMessageListView:mlv
                                                            tableView:mlv.tableView
                                                          destination:btn];
    // ingestor.start() 等候选集就绪、按钮显示后再起
}

#pragma mark - 监听

- (void)subscribeNotifications {
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    [nc addObserver:self selector:@selector(onMemberUpdate:)        name:WKNOTIFY_GROUP_MEMBERUPDATE       object:nil];
    [nc addObserver:self selector:@selector(onSpaceRegistryLoad:)   name:WKSpaceBotRegistryDidLoadNotification object:nil];
    [nc addObserver:self selector:@selector(onOnlineStatusUpdate:)  name:WKCMDOnlineStatus                  object:nil];
    // 当宿主 ConversationView 重新出现（从通讯录 / 其他页面回来），强制重评一次
    [nc addObserver:self selector:@selector(onChatReappear:)        name:@"WKConversationViewDidAppear"     object:nil];
    // OnlineStatusManager delegate 是另一条路径，双保险
    [[WKOnlineStatusManager shared] addDelegate:self];
}

- (void)onMemberUpdate:(NSNotification *)n        { [self scheduleReevalDebounced]; }
- (void)onSpaceRegistryLoad:(NSNotification *)n   { [self scheduleReevalDebounced]; }
- (void)onOnlineStatusUpdate:(NSNotification *)n  { [self scheduleReevalDebounced]; }
- (void)onlineStatusManagerChange:(WKOnlineStatusManager *)m status:(WKOnlineStatusResp *)s { [self scheduleReevalDebounced]; }

- (void)onChatReappear:(NSNotification *)n {
    if (!self.host || self.host.window == nil) return;
    // 立即取消任何 pending hide，给重评一个机会
    [self cancelPendingHide];
    [self reevaluateNow];
    // 再补几次异步重评，覆盖回页面后的数据回填窗口
    [self scheduleReevalAfter:0.3];
    [self scheduleReevalAfter:1.0];
}

#pragma mark - 重评估调度

- (void)scheduleReevalDebounced {
    self.reevalGen++;
    NSInteger gen = self.reevalGen;
    __weak typeof(self) ws = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kReevalDebounce * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(ws) ss = ws;
        if (!ss || ss.reevalGen != gen) return;
        [ss reevaluateNow];
    });
}

- (void)scheduleReevalAfter:(NSTimeInterval)delay {
    __weak typeof(self) ws = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [ws reevaluateNow]; });
}

#pragma mark - 候选集计算

- (void)reevaluateNow {
    if (!self.host || !self.channel) return;

    // 群聊 + 子区都允许（子区跟随父群的判定）
    WKChannel *groupChannel = [self effectiveGroupChannel];
    if (!groupChannel) {
        [self setCandidates:@[]];
        return;
    }

    // 父群成员里的 robot
    NSArray<WKChannelMember *> *members = [[WKChannelMemberDB shared] getMembersWithChannel:groupChannel];
    NSMutableArray<WKChannelMember *> *botMembers = [NSMutableArray array];
    for (WKChannelMember *m in members) {
        if (m.robot && !m.isDeleted) [botMembers addObject:m];
    }
    if (botMembers.count == 0) { [self setCandidates:@[]]; return; }

    NSString *spaceId = [[WKSpaceFilter shared] currentSpaceId];

    // ∩ 当前 Space 已添加 ∩ 在线
    NSMutableArray<NSString *> *qualified = [NSMutableArray array];
    for (WKChannelMember *b in botMembers) {
        NSString *uid = b.memberUid;
        if (uid.length == 0) continue;
        WKSpaceBotMembership ms = [[WKSpaceBotRegistry shared] membershipForBotUID:uid inSpace:spaceId];
        if (ms != WKSpaceBotMembershipMember) continue;
        // 在线判定：读 person channelInfo.online
        WKChannel *botCh = [WKChannel personWithChannelID:uid];
        WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:botCh];
        if (info.online) [qualified addObject:uid];
    }

    [self setCandidates:qualified];
}

/// 把当前 channel 解析为"用于候选 Bot 判定的群"：
///   - WK_GROUP            → 自身
///   - WK_COMMUNITY_TOPIC  → 沿着 channelInfo.parentChannel；若未加载，回退到从 channelId 用
///                            "____" 分隔符抽出 groupNo（与 WKVoicePanel.parentGroupChannel:
///                            同款规则）
///   - 其他                 → nil（不显示按钮）
- (WKChannel *)effectiveGroupChannel {
    if (self.channel.channelType == WK_GROUP) return self.channel;
    if (self.channel.channelType != WK_COMMUNITY_TOPIC) return nil;

    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:self.channel];
    if (info.parentChannel) return info.parentChannel;

    NSRange sep = [self.channel.channelId rangeOfString:@"____"];
    if (sep.location != NSNotFound) {
        NSString *groupNo = [self.channel.channelId substringToIndex:sep.location];
        return [WKChannel groupWithChannelID:groupNo];
    }
    return nil;
}

- (void)setCandidates:(NSArray<NSString *> *)uids {
    BOOL was = self.candidateBotUIDs.count > 0;
    BOOL now = uids.count > 0;
    self.candidateBotUIDs = uids;
    if (now && [uids indexOfObject:self.selectedBotUID] == NSNotFound) {
        self.selectedBotUID = uids.firstObject;
    }
    if (!now) self.selectedBotUID = nil;

    if (now) {
        // 候选集回来：取消任何 pending hide + 立刻显示
        [self cancelPendingHide];
        [self showButton];
    } else if (was) {
        // 候选集刚清空：sticky-hide，给"重载中瞬时空集"一个 3s 缓冲
        // 通讯录页面会触发 my_bots/space_bots 网络刷新，期间瞬时可能为空
        [self scheduleHideAfter:3.0];
    } else {
        // 一直没有候选 → 按原逻辑直接 hide
        [self hideButton];
    }
}

#pragma mark - Sticky hide 防抖

- (void)scheduleHideAfter:(NSTimeInterval)delay {
    self.pendingHideGen++;
    NSInteger gen = self.pendingHideGen;
    __weak typeof(self) ws = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(ws) ss = ws;
        if (!ss || ss.pendingHideGen != gen) return;
        if (ss.candidateBotUIDs.count == 0) [ss hideButton];
    });
}

- (void)cancelPendingHide {
    self.pendingHideGen++;
}

- (void)showButton {
    WKAISummaryFloatingButton *btn = self.button;
    if (!btn) return;
    if (!btn.hidden && btn.alpha > 0.95) return; // 已经完整显示
    btn.hidden = NO;
    if (btn.alpha < 0.5) {
        btn.alpha = 0;
        btn.transform = CGAffineTransformMakeTranslation(kButtonSize, 0);
    }
    [UIView animateWithDuration:0.40 delay:0 usingSpringWithDamping:0.78
          initialSpringVelocity:0.6 options:UIViewAnimationOptionCurveEaseOut animations:^{
        btn.alpha = 1.0;
        btn.transform = CGAffineTransformIdentity;
    } completion:nil];
    [self.ingestor start];
}

- (void)hideButton {
    WKAISummaryFloatingButton *btn = self.button;
    if (!btn || btn.hidden) return;
    [self.ingestor stop];
    [UIView animateWithDuration:0.20 animations:^{
        btn.alpha = 0;
    } completion:^(BOOL finished) {
        btn.hidden = YES;
    }];
}

#pragma mark - 短按 / 长按

- (void)onTap {
    if (self.chargingUp) return;
    // 已发过 → 短按只是回去看，不重复发
    if (self.pendingReopenChannel) {
        [[WKApp shared] pushConversation:self.pendingReopenChannel];
        return;
    }
    // 优先级：自定义提示词 > 上次时间档位 > 未读 / 1 天 兜底
    if ([self hasCustomPrompt]) {
        [self triggerSummaryWithCustomPrompt];
    } else {
        [self triggerSummaryWithRange:[self defaultRangeSeconds]];
    }
}

- (void)onLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    if (self.chargingUp) return;
    [self presentRangePicker];
}

- (BOOL)hasCustomPrompt {
    return [WKAISummaryPromptStore hasCustomPromptForChannel:self.channel];
}

- (NSInteger)defaultRangeSeconds {
    // 1) 上次保存过 → 用上次的
    NSInteger saved = [WKAISummaryPromptStore lastRangeForChannel:self.channel];
    if (saved != 0 && saved != kRangeUnread) return saved;
    // 2) 未读 > 0 → 默认未读
    if ([self currentUnreadCount] > 0) return kRangeUnread;
    // 3) 兜底 1 天
    return kRange1d;
}

- (NSInteger)currentUnreadCount {
    WKConversation *c = [[WKSDK shared].conversationManager getConversation:self.channel];
    return c ? c.unreadCount : 0;
}

#pragma mark - 时间档位选择（Cyber 风格菜单）

- (void)presentRangePicker {
    NSInteger unread = [self currentUnreadCount];
    BOOL hasUnread = unread > 0;
    NSInteger savedRange = [WKAISummaryPromptStore lastRangeForChannel:self.channel];
    BOOL hasCustom = [self hasCustomPrompt];
    NSString *customText = [WKAISummaryPromptStore customPromptForChannel:self.channel];

    NSMutableArray<WKAISummaryActionItem *> *items = [NSMutableArray array];

    // —— 自定义提示词置顶（如有）——
    if (hasCustom) {
        NSString *preview = [self previewOfPrompt:customText];
        WKAISummaryActionItem *it = [WKAISummaryActionItem itemWithKind:WKAISummaryActionKindCustomPrompt
                                                                  itemId:0
                                                                   title:@"使用自定义提示词"
                                                                subtitle:preview
                                                             highlighted:YES];
        [items addObject:it];
    }
    // —— 未读（如有）——
    BOOL highlightUnread = !hasCustom && hasUnread && (savedRange == 0 || savedRange == kRangeUnread);
    if (hasUnread) {
        NSString *st = [NSString stringWithFormat:@"%ld 条", (long)unread];
        [items addObject:[WKAISummaryActionItem itemWithKind:WKAISummaryActionKindRange
                                                       itemId:kRangeUnread
                                                        title:@"总结未读消息"
                                                     subtitle:st
                                                  highlighted:highlightUnread]];
    }

    // —— 提示词管理 ——
    NSString *editTitle = hasCustom ? @"编辑提示词" : @"添加自定义提示词";
    [items addObject:[WKAISummaryActionItem itemWithKind:WKAISummaryActionKindEditPrompt
                                                   itemId:0
                                                    title:editTitle
                                                 subtitle:nil
                                              highlighted:NO]];
    if (hasCustom) {
        WKAISummaryActionItem *del = [WKAISummaryActionItem itemWithKind:WKAISummaryActionKindDeletePrompt
                                                                   itemId:0
                                                                    title:@"删除自定义提示词"
                                                                 subtitle:nil
                                                              highlighted:NO];
        del.destructive = YES;
        [items addObject:del];
    }

    // —— Footer：切换 Bot ——
    WKAISummaryActionItem *footer = nil;
    if (self.candidateBotUIDs.count > 1) {
        NSString *st = [NSString stringWithFormat:@"当前 %@", [self botDisplayName:self.selectedBotUID] ?: @""];
        footer = [WKAISummaryActionItem itemWithKind:WKAISummaryActionKindSwitchBot
                                               itemId:0
                                                title:@"切换 Bot"
                                             subtitle:st
                                          highlighted:NO];
    }

    NSString *subtitle = [self pickerSubtitle];
    __weak typeof(self) ws = self;
    [WKAISummaryActionMenu presentFromView:self.button
                                     title:@"AI 一键总结"
                                  subtitle:subtitle
                                     items:items
                                footerItem:footer
                                  onSelect:^(WKAISummaryActionItem *item) {
        __strong typeof(ws) ss = ws;
        if (!ss || !item) return;
        switch (item.kind) {
            case WKAISummaryActionKindRange:
                [WKAISummaryPromptStore saveLastRange:item.itemId forChannel:ss.channel];
                ss.pendingReopenChannel = nil; // 显式选择新档位 → 视为重发
                [ss triggerSummaryWithRange:item.itemId];
                break;
            case WKAISummaryActionKindCustomPrompt:
                ss.pendingReopenChannel = nil;
                [ss triggerSummaryWithCustomPrompt];
                break;
            case WKAISummaryActionKindEditPrompt:
                [ss presentPromptEditor];
                break;
            case WKAISummaryActionKindDeletePrompt:
                [WKAISummaryPromptStore saveCustomPrompt:nil forChannel:ss.channel];
                ss.pendingReopenChannel = nil; // 删完短按要重新走默认逻辑
                [ss presentRangePicker];   // 删完回到菜单看新状态
                break;
            case WKAISummaryActionKindSwitchBot:
                [ss presentBotPicker];
                break;
            default: break;
        }
    }];
}

- (NSString *)previewOfPrompt:(NSString *)text {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    // 单行换行去掉
    NSString *flat = [trimmed stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSInteger n = 0;
    NSMutableString *acc = [NSMutableString string];
    NSInteger limit = 50; // 给 2 行 13pt 留足空间，够看清意图
    for (NSInteger i = 0; i < (NSInteger)flat.length;) {
        NSRange r = [flat rangeOfComposedCharacterSequenceAtIndex:i];
        [acc appendString:[flat substringWithRange:r]];
        i = NSMaxRange(r);
        n++;
        if (n >= limit) {
            [acc appendString:@"…"];
            break;
        }
    }
    return acc;
}

- (NSString *)pickerSubtitle {
    NSString *botName = [self botDisplayName:self.selectedBotUID];
    if (botName.length == 0) return nil;
    if (self.candidateBotUIDs.count > 1) {
        return [NSString stringWithFormat:@"%@ · 共 %lu 个可用",
                botName, (unsigned long)self.candidateBotUIDs.count];
    }
    return botName;
}

- (void)presentBotPicker {
    NSMutableArray<WKAISummaryActionItem *> *items = [NSMutableArray array];
    NSInteger idx = 0;
    for (NSString *uid in self.candidateBotUIDs) {
        NSString *title = [self botDisplayName:uid] ?: uid;
        BOOL isCurrent = [uid isEqualToString:self.selectedBotUID];
        WKAISummaryActionItem *it = [WKAISummaryActionItem itemWithKind:WKAISummaryActionKindBotPick
                                                                  itemId:idx
                                                                   title:title
                                                                subtitle:isCurrent ? @"使用中" : nil
                                                             highlighted:isCurrent];
        [items addObject:it];
        idx++;
    }

    __weak typeof(self) ws = self;
    [WKAISummaryActionMenu presentFromView:self.button
                                     title:@"选择 Bot"
                                  subtitle:nil
                                     items:items
                                footerItem:nil
                                  onSelect:^(WKAISummaryActionItem *item) {
        __strong typeof(ws) ss = ws;
        if (!ss || !item) return;
        if (item.kind == WKAISummaryActionKindBotPick &&
            item.itemId >= 0 && item.itemId < (NSInteger)ss.candidateBotUIDs.count) {
            ss.selectedBotUID = ss.candidateBotUIDs[item.itemId];
        }
        [ss presentRangePicker];
    }];
}

#pragma mark - 提示词编辑器

- (void)presentPromptEditor {
    NSString *prefix = [self customPromptPrefix];
    NSString *initial = [WKAISummaryPromptStore customPromptForChannel:self.channel];
    NSString *hint = [NSString stringWithFormat:@"提示词将以 %@ 开头，下面填入要让 AI 做的事", prefix];
    __weak typeof(self) ws = self;
    [WKAISummaryPromptEditor presentFromView:self.button
                                   prefixHint:hint
                                  initialText:initial
                                       onSave:^(NSString *text) {
        __strong typeof(ws) ss = ws;
        if (!ss) return;
        if (text == nil) return;        // 取消
        NSString *clean = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (clean.length == 0) {
            // 保存空 = 删除
            [WKAISummaryPromptStore saveCustomPrompt:nil forChannel:ss.channel];
        } else {
            [WKAISummaryPromptStore saveCustomPrompt:text forChannel:ss.channel];
        }
        // 提示词改了 → 短按要按新提示词重新发，不能命中 reopen 短路
        ss.pendingReopenChannel = nil;
        // 回到主菜单看新状态
        [ss presentRangePicker];
    }];
}

#pragma mark - 触发总结

- (void)triggerSummaryWithRange:(NSInteger)rangeSec {
    [self triggerSummaryWithPromptBuilder:^NSString *{
        return [self buildPromptForRange:rangeSec];
    }];
}

- (void)triggerSummaryWithCustomPrompt {
    [self triggerSummaryWithPromptBuilder:^NSString *{
        return [self buildPromptForCustom];
    }];
}

- (void)triggerSummaryWithPromptBuilder:(NSString *(^)(void))builder {
    if (self.selectedBotUID.length == 0) return;
    self.chargingUp = YES;
    [self playChargeUpAndAttract];

    NSString *prompt = builder();
    NSString *botUID = self.selectedBotUID;
    WKChannel *botChannel = [WKChannel personWithChannelID:botUID];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.95 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        WKTextContent *txt = [[WKTextContent alloc] init];
        txt.content = prompt;
        WKMessage *sentMsg = [[WKSDK shared].chatManager sendMessage:txt channel:botChannel];

        UIView *src = [self findHostViewController].view ?: self.host.window;
        [WKAISummaryCyberpunkTransition performFromView:src pushBlock:^{
            WKConversationVC *botVC = [WKConversationVC new];
            botVC.channel = botChannel;
            // 强制 push 后落到最新一条（即我们刚发的 prompt）
            uint32_t targetSeq = sentMsg.orderSeq;
            if (targetSeq == 0) {
                WKMessage *last = [[WKSDK shared].chatManager getLastMessage:botChannel];
                if (last) targetSeq = last.orderSeq;
            }
            if (targetSeq > 0) botVC.locationAtOrderSeq = targetSeq;
            [[WKNavigationManager shared] pushViewController:botVC animated:NO];
        }];

        self.chargingUp = NO;
        self.pendingReopenChannel = botChannel;
    });

    NSLog(@"[AISummary] trigger: bot=%@ prompt=%@", botUID, prompt);
}

#pragma mark - Prompt 构造

/// 群/子区前缀，如 「迟到挨打的小学生」群「番外」子区。固定部分。
///
/// 子区判定依据 channelType（WK_COMMUNITY_TOPIC），与 effectiveGroupChannel 同款规则：
/// channelInfo.parentChannel 没加载完时，从 channelId 的 "____" 分隔符抽 groupNo 兜底，
/// 避免子区刚进入时把"子区名"误当成"群名"导出 prefix（旧 bug）。
- (NSString *)customPromptPrefix {
    if (self.channel.channelType == WK_COMMUNITY_TOPIC) {
        WKChannel *parentGroup = [self effectiveGroupChannel];
        NSString *groupName = @"当前群";
        if (parentGroup) {
            NSString *n = [self channelDisplayName:parentGroup];
            if (n.length > 0) groupName = n;
        }
        NSString *topicName = [self channelDisplayName:self.channel] ?: @"当前子区";
        return [NSString stringWithFormat:@"在「%@」群「%@」子区", groupName, topicName];
    }
    NSString *groupName = [self groupDisplayName] ?: @"当前群";
    return [NSString stringWithFormat:@"在「%@」群", groupName];
}

- (NSString *)channelDisplayName:(WKChannel *)channel {
    if (!channel) return nil;
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:channel];
    if (info.displayName.length > 0) return info.displayName;
    if (info.name.length > 0) return info.name;
    return nil;
}

- (NSString *)buildPromptForCustom {
    NSString *user = [WKAISummaryPromptStore customPromptForChannel:self.channel] ?: @"";
    NSString *prefix = [self customPromptPrefix];
    return [NSString stringWithFormat:@"%@，%@", prefix, user];
}

- (NSString *)buildPromptForRange:(NSInteger)rangeSec {
    NSString *prefix = [self customPromptPrefix];
    NSString *rangePhrase;
    if (rangeSec == kRangeUnread) {
        NSInteger n = [self currentUnreadCount];
        rangePhrase = [NSString stringWithFormat:@"未读 %ld 条", (long)n];
    } else if (rangeSec == kRangeAll) {
        rangePhrase = @"所有";
    } else if (rangeSec == kRange1d) {
        rangePhrase = @"最近 1 天";
    } else if (rangeSec == kRange3d) {
        rangePhrase = @"最近 3 天";
    } else {
        rangePhrase = @"最近 1 天";
    }
    return [NSString stringWithFormat:@"请总结%@里%@的聊天内容，以 markdown 格式发给我。",
            prefix, rangePhrase];
}

#pragma mark - 充能（按钮内特效）—— 不再做"气泡吸入"

- (void)playChargeUpAndAttract {
    WKAISummaryFloatingButton *btn = self.button;
    if (!btn) return;

    [self.ingestor stop];
    [btn playChargeUp];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.ingestor start];
    });
}

#pragma mark - Helpers

- (NSString *)groupDisplayName {
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:self.channel];
    return info.displayName.length > 0 ? info.displayName : info.name;
}

- (NSString *)botDisplayName:(NSString *)uid {
    if (uid.length == 0) return nil;
    WKChannel *ch = [WKChannel personWithChannelID:uid];
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:ch];
    if (info.displayName.length > 0) return info.displayName;
    if (info.name.length > 0) return info.name;
    return uid;
}

- (UIViewController *)findHostViewController {
    UIResponder *r = self.host;
    while ((r = r.nextResponder)) {
        if ([r isKindOfClass:UIViewController.class]) return (UIViewController *)r;
    }
    return nil;
}

@end

#pragma mark - Public class

@implementation WKAISummaryEntryController

+ (void)attachToMessageListView:(WKMessageListView *)mlv channel:(WKChannel *)channel {
    if (!mlv || !channel) return;
    if ([mlv viewWithTag:kButtonTag]) return; // already attached
    _WKAISummaryEntryOwner *o = [[_WKAISummaryEntryOwner alloc] initWithHost:mlv channel:channel];
    [o attach];
    objc_setAssociatedObject(mlv, (__bridge const void *)[WKAISummaryEntryController class],
                             o, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[AISummary] EntryController attached, channel=%@/%d", channel.channelId, channel.channelType);
}

+ (void)detachFromMessageListView:(WKMessageListView *)mlv {
    if (!mlv) return;
    _WKAISummaryEntryOwner *o = objc_getAssociatedObject(mlv, (__bridge const void *)[WKAISummaryEntryController class]);
    [o detach];
    objc_setAssociatedObject(mlv, (__bridge const void *)[WKAISummaryEntryController class],
                             nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
