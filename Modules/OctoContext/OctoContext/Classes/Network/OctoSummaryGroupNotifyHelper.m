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

    if (detail.originChannelId.length > 0) {
        NSInteger ct;
        switch ((OctoSourceType)detail.originChannelType) {
            case OctoSourceDirectMessage: ct = WK_PERSON; break;
            case OctoSourceThread:        ct = WK_COMMUNITY_TOPIC; break;
            default:                      ct = WK_GROUP; break;
        }
        if (ct == WK_GROUP) {
            WKChannel *ch = [WKChannel channelID:detail.originChannelId channelType:ct];
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
    if (selfUid.length == 0 || creatorUid.length == 0) return;
    // 谁创建谁发。eligible 标记只在本机发起时打, 这里是第二道保险
    // (譬如同一台设备切过账号, 标记还在但已经不是创建者了)。
    if (![creatorUid isEqualToString:selfUid]) return;

    NSArray<WKChannel *> *channels = [self resolveTargetChannelsForDetail:detail];
    if (channels.count == 0) return;

    // 显示名按优先级选取:
    //   1. [WKApp shared].loginInfo.displayName (业务登录信息: 已实名→真实姓名, 否则昵称)
    //   2. connectInfo.name (SDK 层, 登录流程下经常没填)
    //   3. selfUid (兜底, 避免出现"总结了群聊内容"空名字)
    // creator_name 也是可选字段, 普通用户任务通常不返回, 不把它放进主链路。
    NSString *name = [WKApp shared].loginInfo.displayName;
    if (name.length == 0) name = connectInfo.name;
    if (name.length == 0) name = selfUid;
    if (name.length == 0) return;

    for (WKChannel *ch in channels) {
        NSString *channelId = ch.channelId;
        if (channelId.length == 0) continue;
        if ([OctoSummaryNotifyStore hasSentTaskId:taskId channelId:channelId]) continue;

        // claim-before-send: 先落账再发。两条触发链路 (详情页轮询 / 卡片点击) 可能
        // 在很近的时间里都判定通过, 先落账能让后到的那条直接被上面的 hasSent 挡掉。
        [OctoSummaryNotifyStore markSentTaskId:taskId channelId:channelId];

        OctoSummaryTipContent *tip = [OctoSummaryTipContent tipWithUid:selfUid name:name];
        WKMessage *message = [[WKSDK shared].chatManager sendMessage:tip channel:ch];
        if (!message) {
            // 落库都没成功 —— 回滚落账, 下次再进详情页还有机会补发。
            [OctoSummaryNotifyStore unmarkSentTaskId:taskId channelId:channelId];
            continue;
        }
        // WK_TIP 是"系统公告"式提示, 不该冲未读红点、也不该让发消息的这台设备给自己播
        // 新消息提示音/振动。contentToMessage: 默认 header.showUnread = true, 而
        // WKSystemMessageHandler.onRecvMessages: 的提醒分支只判 showUnread 和当前聊天
        // channel, 不排除 isSend==YES 的消息 —— 不改的话, 用户没停留在这个群的聊天页
        // 时, 下面那行本地回显会给自己播"新消息来了"的声音。
        message.header.showUnread = NO;
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
    if (qno.length > 0) return [self lookupByNo:qno];

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
