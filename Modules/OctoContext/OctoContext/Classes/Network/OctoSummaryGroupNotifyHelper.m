//
//  OctoSummaryGroupNotifyHelper.m
//  OctoContext
//

#import "OctoSummaryGroupNotifyHelper.h"
#import "OctoSummaryTipContent.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <WuKongBase/WuKongBase.h>

static NSString *const kOctoSummaryNotifiedTaskIdsKey = @"OctoSummaryNotifiedTaskIds";

@implementation OctoSummaryGroupNotifyHelper

+ (BOOL)isTaskIdNotified:(int64_t)taskId {
    NSArray<NSString *> *ids = [[NSUserDefaults standardUserDefaults] arrayForKey:kOctoSummaryNotifiedTaskIdsKey];
    return [ids containsObject:[NSString stringWithFormat:@"%lld", taskId]];
}

+ (void)markTaskIdNotified:(int64_t)taskId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray<NSString *> *ids = [defaults arrayForKey:kOctoSummaryNotifiedTaskIdsKey];
    NSString *key = [NSString stringWithFormat:@"%lld", taskId];
    if ([ids containsObject:key]) return;
    NSMutableArray<NSString *> *next = ids ? [ids mutableCopy] : [NSMutableArray array];
    [next addObject:key];
    [defaults setObject:next forKey:kOctoSummaryNotifiedTaskIdsKey];
}

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

+ (void)notifyIfNeeded:(OctoSummaryDetail *)detail {
    if (!detail) return;
    if (detail.status != OctoTaskStatusCompleted) return;

    WKConnectInfo *connectInfo = [WKSDK shared].options.connectInfo;
    NSString *selfUid = connectInfo.uid;
    // 后端两种创建者字段都返回过: 新版 creator_id, 旧版/部分接口 user_id。模型解析时
    // 已经在 modelFromDict 里做了 creator_id → user_id 兜底, 这里直接用 creatorId 即可。
    // 之前直接读 detail.creatorId 且模型没做 user_id 兜底, 对旧接口返回值永远为 nil,
    // 在第一个 early-return 就被拦掉, 提示消息永远发不出去。
    NSString *creatorUid = detail.creatorId;
    if (selfUid.length == 0 || creatorUid.length == 0) return;
    if (![creatorUid isEqualToString:selfUid]) return;

    if ([self isTaskIdNotified:detail.taskId]) return;

    NSArray<WKChannel *> *channels = [self resolveTargetChannelsForDetail:detail];
    if (channels.count == 0) return;

    [self markTaskIdNotified:detail.taskId];

    // 显示名按优先级选取:
    //   1. [WKApp shared].loginInfo.displayName (业务登录信息: 已实名→真实姓名, 否则昵称)
    //   2. connectInfo.name (SDK 层, 登录流程下经常没填)
    //   3. selfUid (兜底, 避免出现"总结了群聊内容"空名字)
    // creator_name 也是可选字段,普通用户任务通常不返回,不把它放进主链路。
    NSString *name = [WKApp shared].loginInfo.displayName;
    if (name.length == 0) name = connectInfo.name;
    if (name.length == 0) name = selfUid;

    OctoSummaryTipContent *tip = [OctoSummaryTipContent tipWithUid:selfUid name:name];
    for (WKChannel *ch in channels) {
        WKMessage *message = [[WKSDK shared].chatManager sendMessage:tip channel:ch];
        // chatManager sendMessage: 只落库 + 走网络发送, 不会通知当前正打开的聊天页面 UI ——
        // 那个插入动作平时由输入框发送流程自己调用 WKMessageListView.sendMessage: 完成,
        // 这里是脚本式后台发送, 没有对应的聊天页面实例可调。sendack 之后触发的 onMessageUpdate
        // 只会去更新 dataProvider 里"已存在"的行, 找不到就什么都不做, 所以本机永远看不到自己
        // 发的这条提示 (web 端能看到是因为对 web 来说这是走 onRecvMessages 收消息路径)。
        // WKMessageListView.handleRecvMessage: 本身已经支持 message.isSend==YES 的分支
        // (对应"账号在其他设备发的消息, 这台设备收到"的多端同步场景), 所以直接把这条本机发的
        // 消息也丢回 onRecvMessages 委托, 复用同一条已支持的路径, 让当前若打开着的聊天页面
        // 立即插入这条提示气泡。
        if (message) {
            [[WKSDK shared].chatManager callRecvMessagesDelegate:@[message]];
        }
    }
}

@end
