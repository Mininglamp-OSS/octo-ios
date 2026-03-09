//
//  WKCMDDB.h
//  WuKongIMSDK-WuKongIMSDK
//
//  Created by tt on 2020/11/21.
//

#import <Foundation/Foundation.h>
#import "WKMessage.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKCMDMessage : NSObject

@property(nonatomic,assign) NSInteger mid;

/// 客户端消息唯一编号(相同clientMsgNo被认为是重复消息)
@property(nonatomic,copy) NSString *clientMsgNo;
// 消息ID（全局唯一）
@property(nonatomic,assign) uint64_t messageId;
// 消息序列号（用户唯一，有序）
@property(nonatomic,assign)  uint32_t messageSeq;
// 消息时间（服务器时间,单位秒）
@property(nonatomic,assign) NSInteger timestamp;

@property(nonatomic,copy) NSString *cmd;

@property(nonatomic,copy) NSString *param;

// 是否为系统cmd消息
-(BOOL) same:(WKCMDMessage*)cmdMessage;

+(WKCMDMessage*) fromMessage:(WKMessage*)message;


@end

@interface WKCMDDB : NSObject

+ (WKCMDDB *)shared;

-(uint32_t) getMaxMessageSeq;

-(void) replaceCMDMessages:(NSArray<WKCMDMessage*>*)messages;

-(NSArray<WKCMDMessage*>*) queryAllCMDMessages;

-(void) deleteCMDMessagesWithIDs:(NSArray<NSNumber*>*) ids;

@end

NS_ASSUME_NONNULL_END
