//
//  WKSendPacket.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import <Foundation/Foundation.h>
#import "WKPacket.h"
#import "WKPacketBodyCoder.h"
#import "WKSetting.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKSendPacket : WKPacket<WKPacketBodyCoder>

@property(nonatomic,strong) WKSetting *setting;

@property(nonatomic,assign) NSInteger expire; // 消息过期时长

// 客户端提供的序列号，在客户端内唯一
@property(nonatomic,assign) uint32_t clientSeq;

/// 客户端消息唯一编号
@property(nonatomic,copy) NSString *clientMsgNo;

//频道ID（如果是个人频道ChannelId为个人的UID）
@property(nonatomic,copy) NSString *channelId;
//频道类型（1.个人 2.群组）
@property(nonatomic,assign) uint8_t channelType;
// 话题
@property(nonatomic,copy) NSString *topic;
// 负荷数据
@property(nonatomic,strong) NSData *payload;

-(NSString*) veritifyString;

@end

NS_ASSUME_NONNULL_END
