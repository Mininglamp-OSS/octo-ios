//
//  WKThreadModel.h
//  WuKongBase
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WKThreadStatus) {
    WKThreadStatusActive   = 1, // 活跃
    WKThreadStatusArchived = 2, // 已归档
    WKThreadStatusDeleted  = 3, // 已删除
};

@interface WKThreadModel : NSObject

@property (nonatomic, copy)   NSString *shortId;
@property (nonatomic, copy)   NSString *groupNo;
@property (nonatomic, copy)   NSString *channelId;       // groupNo____shortId
@property (nonatomic, assign) uint8_t   channelType;     // WK_COMMUNITY_TOPIC = 5
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, copy)   NSString *creatorUid;
@property (nonatomic, copy)   NSString *creatorName;
@property (nonatomic, assign) NSInteger status;           // WKThreadStatus
@property (nonatomic, assign) NSInteger memberCount;
@property (nonatomic, assign) NSInteger messageCount;
@property (nonatomic, assign) NSInteger unreadCount;
@property (nonatomic, assign) BOOL      isMember;
@property (nonatomic, assign) BOOL      isDeleted;
@property (nonatomic, copy, nullable) NSString *lastMessageContent;
@property (nonatomic, copy, nullable) NSString *lastMessageSenderName;
@property (nonatomic, copy, nullable) NSString *sourceMessageId;
@property (nonatomic, copy)   NSString *createdAt;
@property (nonatomic, copy)   NSString *updatedAt;

+ (instancetype)fromDict:(NSDictionary *)dict;
+ (NSArray<WKThreadModel *> *)fromDictArray:(NSArray<NSDictionary *> *)array;

/// 转为 WKChannel (channelType = WK_COMMUNITY_TOPIC)
- (WKChannel *)toChannel;

@end

NS_ASSUME_NONNULL_END
