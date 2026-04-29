//
//  WKMessageUtil.h
//  WuKongBase
//
//  Created by tt on 2020/10/12.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKMessageUtil : NSObject

+(WKMessage*) toMessage:(NSDictionary*)messageDict;

+(WKMessageExtra*) toMessageExtra:(NSDictionary*)dataDict channel:(WKChannel*)channel;

+(WKReaction*) toReaction:(NSDictionary*)dataDict;

/**
 YUJ-131 — populate a decoded WKReply with the four external-group fields
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
