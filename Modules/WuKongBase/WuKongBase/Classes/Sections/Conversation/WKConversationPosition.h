//
//  WKConversationPosition.h
//  WuKongBase
//
//  Created by tt on 2021/8/11.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

// 最近会话位置类型
typedef enum : NSInteger {
    WKConversationPositionTypeScrollToBottom = -1, // 滚动到底部（特殊位置）
    WKConversationPositionTypeUnreadFirst = 0, // 第一条未读消息位置
    WKConversationPositionTypeMention = 1, // 已确认
    WKConversationPositionTypeApplyJoinGroup = 2, // 申请进群
} WKConversationPositionType;


NS_ASSUME_NONNULL_BEGIN

@interface WKConversationPosition : NSObject

@property(nonatomic,assign) WKConversationPositionType positionType;

@property(nonatomic,assign) uint32_t orderSeq; // 消息的orderSeq

@property(nonatomic,assign) int offset; // 基于此消息的偏移位置

+(WKConversationPosition*) orderSeq:(uint32_t)orderSeq offset:(int)offset type:(WKConversationPositionType)type;

+(WKConversationPosition*) orderSeq:(uint32_t)orderSeq offset:(int)offset;

@end

@interface WKConversationPositionManager : NSObject

+ (WKConversationPositionManager *)shared;

-(void) reload;

-(void) channel:(WKChannel*)channel position:(WKConversationPosition* )position;

-(void) removePositions:(WKChannel*)channel;

-(void) removePositions:(WKChannel*)channel type:(WKConversationPositionType)type;

-(NSArray<WKConversationPosition*>*) position:(WKChannel*)channel;

@end

NS_ASSUME_NONNULL_END
