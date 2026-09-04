//
//  OctoSummaryGroupNotifyHelper.m
//  OctoContext
//

#import "OctoSummaryGroupNotifyHelper.h"
#import "OctoSummaryNotifyStore.h"
#import "OctoSummaryTipContent.h"
#import "OctoSummaryAPI.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <WuKongBase/WuKongBase.h>

@implementation OctoSummaryLookup
@end

@implementation OctoSummaryGroupNotifyHelper

#pragma mark - 本机发起标记

+ (void)markEligibleTaskId:(int64_t)taskId {
    [OctoSummaryNotifyStore markEligibleTaskId:taskId];
}

+ (BOOL)consumeEligibleTaskId:(int64_t)taskId {
    return [OctoSummaryNotifyStore consumeEligibleTaskId:taskId];
}

#pragma mark - 目标群 / 显示名

+ (NSArray<WKChannel *> *)resolveTargetChannelsForDetail:(OctoSummaryDetail *)detail {
    NSMutableArray<WKChannel *> *channels = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (OctoSourceItem *s in detail.sources) {
        if (s.sourceType != OctoSourceGroupChat) continue;
        if (s.sourceId.length == 0 || [seen containsObject:s.sourceId]) continue;
        WKChannel *ch = [WKChannel groupWithChannelID:s.sourceId];
        if (ch) { [channels addObject:ch]; [seen addObject:s.sourceId]; }
    }
    if (channels.count > 0) return channels;
    // sources 里确实有条目、只是没有群聊类型的 (纯私聊/纯子区), 不能再往下兜底——
    // origin_channel_id/type 是打开创建页那一刻冻结的值, 用户在选择器里改选了别的
    // source 之后不会跟着刷新 (OctoSummaryCreateVC acceptPickedChannels: 只重建
    // selectedSources, 不动 originChannelId/Type), 两个字段可能已经不一致。这里
    // 兜底原意是覆盖"detail 完全没有 sources"这一种情况, 不能被用来覆盖一个
    // 用户已经明确选过、只是不含群聊的 sources 列表——否则会把提示发到一个从来
    // 没被总结过的群里, 断言一件没发生的事, 而且不可撤回。
    if (detail.sources.count > 0) return channels;

    if (detail.originChannelId.length > 0) {
        // 显式列出群聊, 其余 (含 0/未知的默认值, 私聊, 子区) 都不兜底成群——本 PR 的
        // 意图就是"只往群聊发", 缺省值落进 default 会被误判成群聊, 往一个其实不是群
        // 的 channel 发消息。
        if ((OctoSourceType)detail.originChannelType == OctoSourceGroupChat) {
            WKChannel *ch = [WKChannel channelID:detail.originChannelId channelType:WK_GROUP];
            if (ch) [channels addObject:ch];
        }
    }
    return channels;
}

#pragma mark - 核心判定

+ (void)notifyIfNeededWithDetail:(OctoSummaryDetail *)detail {
    if (!detail) return;
    int64_t taskId = detail.taskId;
    if (taskId <= 0) return;
    // 前置校验: 非完成态一律不发 (对齐安卓 notifyIfNeeded 的 status 校验)。
    if (detail.status != OctoTaskStatusCompleted) return;

    WKConnectInfo *connectInfo = [WKSDK shared].options.connectInfo;
    NSString *selfUid = connectInfo.uid;
    // 创建者 uid: 后端两种字段名都返回过 (新版 creator_id, 旧版/部分接口 user_id),
    // 模型解析层已做 creator_id → user_id 兜底, 这里直接用 creatorId。
    NSString *creatorUid = detail.creatorId;
    if (selfUid.length == 0 || creatorUid.length == 0) {
        NSLog(@"[OctoSummaryGroupNotifyHelper] task=%lld 拦截: selfUid=%@ creatorUid=%@ 有一个缺失", taskId, selfUid, creatorUid);
        return;
    }
    // 谁创建谁发。eligible 标记只在本机发起时打, 这里是第二道保险
    // (譬如同一台设备切过账号, 标记还在但已经不是创建者了)。
    if (![creatorUid isEqualToString:selfUid]) {
        NSLog(@"[OctoSummaryGroupNotifyHelper] task=%lld 拦截: creatorUid=%@ 与本机 selfUid=%@ 不一致", taskId, creatorUid, selfUid);
        return;
    }

    NSArray<WKChannel *> *channels = [self resolveTargetChannelsForDetail:detail];
    if (channels.count == 0) {
        NSLog(@"[OctoSummaryGroupNotifyHelper] task=%lld 拦截: 目标群解析为空 (sources=%lu originChannelId=%@)",
              taskId, (unsigned long)detail.sources.count, detail.originChannelId);
        return;
    }

    // 显示名按优先级选取:
    //   1. [WKApp shared].loginInfo.displayName (业务登录信息: 已实名→真实姓名, 否则昵称)
    //   2. connectInfo.name (SDK 层, 登录流程下经常没填)
    // 两个都没有就不发——不能兜底成 selfUid 当文本发出去: WKSystemContent.getDisplayContent
    // 只把"查看者自己的 uid"替换成"你", 群里其他成员看到的是 extra[0].name 原文,
    // 兜底成 uid 就是把一个内部标识符原样发到群里。creator_name 也是可选字段, 普通
    // 用户任务通常不返回, 不把它放进主链路。
    NSString *name = [WKApp shared].loginInfo.displayName;
    if (name.length == 0) name = connectInfo.name;
    if (name.length == 0) {
        NSLog(@"[OctoSummaryGroupNotifyHelper] task=%lld 拦截: 无可用显示名, 不把 uid 当文本发出去", taskId);
        return;
    }

    for (WKChannel *ch in channels) {
        NSString *channelId = ch.channelId;
        if (channelId.length == 0) continue;
        // claim-before-send: 原子地"没发过就落账", 一把锁里做完查+写, 不依赖"两条触发
        // 链路都恰好在主线程上跑所以时序上能对齐"这条隐含前提。
        if (![OctoSummaryNotifyStore claimTaskId:taskId channelId:channelId]) {
            NSLog(@"[OctoSummaryGroupNotifyHelper] task=%lld channel=%@ 拦截: 已经发过", taskId, channelId);
            continue;
        }

        OctoSummaryTipContent *tip = [OctoSummaryTipContent tipWithUid:selfUid name:name];
        // WK_TIP 是"系统公告"式提示, 不该冲未读红点、也不该让发消息的这台设备给自己播
        // 新消息提示音/振动。contentToMessage: 默认 header.showUnread = true, 而
        // WKSystemMessageHandler.onRecvMessages: 的提醒分支只判 showUnread 和当前聊天
        // channel, 不排除 isSend==YES 的消息。必须在 sendMessage:(WKMessage*) 快照
        // 进 WKSendPacket 之前把 flag 改掉 —— 先 saveMessage: 落库、改 header、
        // 用 addOrUpdateMessages: 把改动写回 DB, 再拿这个已经是 NO 的 message 去发,
        // 否则 wire 包和 DB 行都还是发送时刻的 showUnread=true (sendMessage:content:channel:
        // 那个便捷方法内部是同步跑完 contentToMessage → sendMessage:message 的, 事后改
        // message.header 只影响内存对象, 改不动已经拷进 WKSendPacket 的那份快照)。
        WKMessage *message = [[WKSDK shared].chatManager saveMessage:tip channel:ch];
        if (!message) {
            NSLog(@"[OctoSummaryGroupNotifyHelper] task=%lld channel=%@ 拦截: saveMessage 落库失败", taskId, channelId);
            [OctoSummaryNotifyStore unmarkSentTaskId:taskId channelId:channelId];
            continue;
        }
        message.header.showUnread = NO;
        [[WKSDK shared].chatManager addOrUpdateMessages:@[message] notify:NO];
        message = [[WKSDK shared].chatManager sendMessage:message];
        if (!message) {
            // 防御性判断: sendMessage:(WKMessage*) 目前的实现不会返回 nil,
            // 但 DB 那份 (saveMessage: 那一步) 已经落上了, 真出现异常也要回滚落账。
            NSLog(@"[OctoSummaryGroupNotifyHelper] task=%lld channel=%@ 拦截: sendMessage 返回 nil (异常路径)", taskId, channelId);
            [OctoSummaryNotifyStore unmarkSentTaskId:taskId channelId:channelId];
            continue;
        }
        // chatManager sendMessage: 只落库 + 走网络发送, 不会通知当前正打开的聊天页面 UI ——
        // 那个插入动作平时由输入框发送流程自己调用 WKMessageListView.sendMessage: 完成,
        // 这里是脚本式后台发送, 没有对应的聊天页面实例可调。sendack 之后触发的 onMessageUpdate
        // 只会去更新 dataProvider 里"已存在"的行, 找不到就什么都不做, 所以本机永远看不到自己
        // 发的这条提示 (web 端能看到是因为对 web 来说这是走 onRecvMessages 收消息路径)。
        // WKMessageListView.handleRecvMessage: 本身已经支持 message.isSend==YES 的分支
        // (对应"账号在其他设备发的消息, 这台设备收到"的多端同步场景), 所以直接把这条本机发的
        // 消息也丢回 onRecvMessages 委托, 复用同一条已支持的路径, 让当前若打开着的聊天页面
        // 立即插入这条提示气泡。
        [[WKSDK shared].chatManager callRecvMessagesDelegate:@[message]];
    }
}

#pragma mark - 深链解析

/// `/s/<taskNo>` —— 单段路径, 允许尾斜杠。`/s/share/<shareId>` 是两段, 天然被排除。
static NSString *const kSummaryPathPattern = @"^/s/([A-Za-z0-9_-]+)/?$";

+ (nullable NSString *)firstQueryValueIn:(NSURLComponents *)comps keys:(NSArray<NSString *> *)keys {
    for (NSURLQueryItem *item in comps.queryItems) {
        for (NSString *key in keys) {
            if ([item.name caseInsensitiveCompare:key] == NSOrderedSame) {
                NSString *v = [item.value stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (v.length > 0) return v;
            }
        }
    }
    return nil;
}

+ (BOOL)isAllDigits:(NSString *)s {
    if (s.length == 0) return NO;
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return [s rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
}

/// task_no 允许的字符集, 与 `/s/<seg>` 路径分支的 kSummaryPathPattern 保持同一口径。
/// path 分支天然只能匹配这个字符集 (正则本身就是这么写的); query 分支 (?task_no=)
/// 来自任意被点击链接、不受这条正则约束, 必须单独校验 —— 否则一个形如
/// `?task_no=../../admin` 的链接会被 OctoSummaryAPI 里保留 "/" 的
/// URLPathAllowedCharacterSet 原样拼进请求路径, 打到 /summaries/ 之外的地方。
+ (BOOL)isValidTaskNo:(NSString *)taskNo {
    if (taskNo.length == 0) return NO;
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"] invertedSet];
    return [taskNo rangeOfCharacterFromSet:invalid].location == NSNotFound;
}

+ (OctoSummaryLookup *)lookupById:(int64_t)taskId {
    if (taskId <= 0) return nil;
    OctoSummaryLookup *l = [OctoSummaryLookup new];
    l.kind = OctoSummaryLookupKindById;
    l.taskId = taskId;
    return l;
}

+ (OctoSummaryLookup *)lookupByNo:(NSString *)taskNo {
    if (taskNo.length == 0) return nil;
    OctoSummaryLookup *l = [OctoSummaryLookup new];
    l.kind = OctoSummaryLookupKindByNo;
    l.taskNo = taskNo;
    return l;
}

+ (nullable OctoSummaryLookup *)lookupFromURLString:(NSString *)urlString {
    if (urlString.length == 0) return nil;
    NSString *normalized = [urlString stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (normalized.length == 0) return nil;
    // 文本消息里的链接经常是裸域名 (didLinkClick: 只在打开 WebView 时才补 scheme),
    // 不补 scheme 的话 NSURLComponents 会把整串当成 path, 下面的 ^/s/ 永远匹配不上。
    if ([normalized rangeOfString:@"://"].location == NSNotFound) {
        normalized = [@"http://" stringByAppendingString:normalized];
    }
    NSURLComponents *comps = [NSURLComponents componentsWithString:normalized];
    if (!comps) return nil;

    // query 优先: 显式带了 task_id / task_no 的链接语义最明确。
    NSString *qid = [self firstQueryValueIn:comps keys:@[@"task_id", @"taskId"]];
    if ([self isAllDigits:qid]) {
        OctoSummaryLookup *l = [self lookupById:qid.longLongValue];
        if (l) return l;
    }
    NSString *qno = [self firstQueryValueIn:comps keys:@[@"task_no", @"taskNo"]];
    if (qno.length > 0 && [self isValidTaskNo:qno]) return [self lookupByNo:qno];

    NSString *path = comps.percentEncodedPath ?: @"";
    if (path.length == 0) return nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:kSummaryPathPattern
                                                                       options:0
                                                                         error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:path
                                            options:0
                                              range:NSMakeRange(0, path.length)];
    if (!m || m.numberOfRanges < 2) return nil;
    NSString *seg = [path substringWithRange:[m rangeAtIndex:1]];
    // 纯数字段按 task_id 走, 其余 (形如 STxxx) 按 task_no 走。
    return [self isAllDigits:seg] ? [self lookupById:seg.longLongValue] : [self lookupByNo:seg];
}

+ (void)handleSummaryDeepLink:(NSString *)urlString {
    OctoSummaryLookup *lookup = [self lookupFromURLString:urlString];
    if (!lookup) return;
    if (lookup.kind == OctoSummaryLookupKindById) {
        [self notifyByTaskIdIfEligible:lookup.taskId];
    } else {
        [self notifyByTaskNoIfEligible:lookup.taskNo];
    }
}

#pragma mark - 深链判定 (拉详情 → 判定)

/// 详情回来后的公共收尾: 必须是完成态才消费 eligible 标记 —— 否则用户在任务还没跑完
/// 时点了一下卡片, 标记就白白烧掉, 真完成后反而发不出来了。
+ (void)notifyWithFetchedDetail:(id)result error:(NSError *)error {
    if (error || ![result isKindOfClass:OctoSummaryDetail.class]) return;
    OctoSummaryDetail *detail = result;
    if (detail.taskId <= 0) return;
    if (detail.status != OctoTaskStatusCompleted) return;
    if (![OctoSummaryNotifyStore consumeEligibleTaskId:detail.taskId]) return;
    [self notifyIfNeededWithDetail:detail];
}

+ (void)notifyByTaskIdIfEligible:(int64_t)taskId {
    if (taskId <= 0) return;
    // 有数字 id 就能先查一眼标记, 没资格直接免掉这次网络请求。
    if (![OctoSummaryNotifyStore isEligibleTaskId:taskId]) return;
    [[OctoSummaryAPI shared] getSummaryDetail:taskId callback:^(id _Nullable result, NSError *_Nullable error) {
        [OctoSummaryGroupNotifyHelper notifyWithFetchedDetail:result error:error];
    }];
}

+ (void)notifyByTaskNoIfEligible:(NSString *)taskNo {
    if (taskNo.length == 0) return;
    // task_no 拿不到数字 id, 没法精确预判标记。但只要本机一个未过期标记都没有, 这次
    // 判定必然发不出提示 —— 直接免掉请求, 顺带避免任意 /s/xxx 形状的普通链接被点一下
    // 就往后端打一发 404。
    if (![OctoSummaryNotifyStore hasAnyEligibleTask]) return;
    [[OctoSummaryAPI shared] getSummaryDetailByNo:taskNo callback:^(id _Nullable result, NSError *_Nullable error) {
        [OctoSummaryGroupNotifyHelper notifyWithFetchedDetail:result error:error];
    }];
}

@end
