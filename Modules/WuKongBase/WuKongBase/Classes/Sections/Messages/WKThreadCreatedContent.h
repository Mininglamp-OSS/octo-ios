//
//  WKThreadCreatedContent.h
//  WuKongBase
//

#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKThreadCreatedContent : WKMessageContent

@property (nonatomic, copy)   NSString *threadName;
@property (nonatomic, copy)   NSString *threadShortId;
@property (nonatomic, copy)   NSString *threadChannelId;
@property (nonatomic, assign) uint8_t   threadChannelType;
@property (nonatomic, copy)   NSString *creatorUid;
@property (nonatomic, copy)   NSString *creatorName;
@property (nonatomic, assign) NSInteger messageCount;
@property (nonatomic, copy, nullable) NSString *sourceMessageId;

/// 已创建子区的源消息ID集合（用于判断消息是否已创建过子区）
+ (NSMutableSet<NSString *> *)sourceMessageIdSet;

/// 源消息ID → 子区信息映射（用于在源消息 cell 内绘制子区指示条）
+ (NSMutableDictionary<NSString *, WKThreadCreatedContent *> *)sourceMessageThreadMap;

/// 子区消息数量缓存：threadChannelId -> @(messageCount)
+ (NSMutableDictionary<NSString *, NSNumber *> *)messageCountCache;

/// 子区已关闭/不存在 → 把源消息从 set / map 里清掉。
/// 长按菜单依赖这两个集合判断"已建过子区 → 进入子区"，清掉后菜单会回到"创建子区"。
/// sourceMessageId 为空时 no-op。
+ (void)markThreadClosedForSourceMessageId:(nullable NSString *)sourceMessageId;

/// 通知名：子区消息数量更新
extern NSString * const WKThreadMessageCountUpdatedNotification;

@end

NS_ASSUME_NONNULL_END
