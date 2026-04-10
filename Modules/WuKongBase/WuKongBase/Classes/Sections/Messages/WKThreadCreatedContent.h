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

@end

NS_ASSUME_NONNULL_END
