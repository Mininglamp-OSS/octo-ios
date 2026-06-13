//
//  WKMessageUtil.h
//  WuKongBase
//
//  Created by tt on 2020/10/12.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
@class FMDatabase;
NS_ASSUME_NONNULL_BEGIN

@interface WKMessageUtil : NSObject

+(WKMessage*) toMessage:(NSDictionary*)messageDict;

/**
 toMessage: 的 db 透传变体。当此 toMessage 调用本身处于一次 FMDB 事务内（典型场景：
 WKMergeForwardContent 解码时被 WKMessageDB.toMessage:db: → decodeContent:data:db: 链路
 一路带进来），把当前事务持有的 FMDatabase 透下去给嵌套 message 的 content decode，
 嵌套 decodeReply 查 ChannelInfo 时就走 -queryChannelInfo:db: 复用连接，不再
 [FMDatabaseQueue inDatabase:] 重入触发 FMDB 反重入断言导致 SIGABRT。

 db == nil 时走与 +toMessage: 完全相同的路径，行为一致。
 */
+(WKMessage*) toMessage:(NSDictionary*)messageDict db:(FMDatabase * _Nullable)db;

+(WKMessageExtra*) toMessageExtra:(NSDictionary*)dataDict channel:(WKChannel*)channel;

+(WKReaction*) toReaction:(NSDictionary*)dataDict;

/**
 — populate a decoded WKReply with the four external-group fields
 carried on the reply sub-dict (`from_home_space_id`, `from_home_space_name`,
 `from_is_external`, `from_source_space_name`). The naming mirrors the
 msg-level fields handled in +toMessage: so UI layers can use a single
 `resolveWithHomeSpaceId:...` branch for both the message bubble and the
 quoted-reply preview.

 Passing a nil/empty dict or a nil reply is a no-op. Empty strings are
 treated as "field missing" so the WKExternalViewerResolver legacy-fallback
 path stays usable (matches web `resolveExternalForViewer`).
 */
+ (void)applyMsgLevelExternalFieldsToReply:(WKReply*)reply dict:(NSDictionary*)dict;

@end

NS_ASSUME_NONNULL_END
