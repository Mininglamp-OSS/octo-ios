//
//  WKSpaceConversationCache.h
//  WuKongBase
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKSpaceConversationCache : NSObject

+ (instancetype)shared;

- (void)setSpaceUnread:(NSNumber * _Nullable)unread spaceLastMessage:(WKMessage * _Nullable)lastMessage forChannel:(WKChannel *)channel;
- (NSNumber * _Nullable)spaceUnreadForChannel:(WKChannel *)channel;
- (WKMessage * _Nullable)spaceLastMessageForChannel:(WKChannel *)channel;
/// 递增当前空间的未读数（实时消息到达时调用）
- (void)incrementSpaceUnread:(NSInteger)delta forChannel:(WKChannel *)channel;
- (void)clearAll;

@end

NS_ASSUME_NONNULL_END
