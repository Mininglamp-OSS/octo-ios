//
//  WKSpaceConversationCache.h
//  WuKongBase
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

/// 缓存 server 下发的 `space_last_message`，仅用于会话列表按当前空间展示"最后一条消息"。
/// 不再维护客户端 `space_unread`：unread 由 SDK DB 持久化，UI 按 lastMessage.space_id 过滤跨空间污染。
@interface WKSpaceConversationCache : NSObject

+ (instancetype)shared;

- (void)setSpaceLastMessage:(WKMessage *)lastMessage forChannel:(WKChannel *)channel;
- (WKMessage * _Nullable)spaceLastMessageForChannel:(WKChannel *)channel;
- (void)clearAll;

@end

NS_ASSUME_NONNULL_END
