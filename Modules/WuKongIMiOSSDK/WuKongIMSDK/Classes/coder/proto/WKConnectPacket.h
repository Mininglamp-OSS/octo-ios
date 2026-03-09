//
//  WKConnectPacket.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//

#import <Foundation/Foundation.h>
#import "WKPacket.h"
#import "WKPacketBodyCoder.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConnectPacket : WKPacket<WKPacketBodyCoder>

// 协议版本号
@property(nonatomic,assign) uint8_t version;
// 客户端KEY (base64编码的DH公钥)
@property(nonatomic,copy) NSString *clientKey;
// 用户的唯一uid
@property(nonatomic,copy) NSString *uid;
// 连接凭证token
@property(nonatomic,copy) NSString *token;
// 设备标示 0.app 1.pc
@property(nonatomic,assign) uint8_t deviceFlag;
// 设备ID
@property(nonatomic,copy) NSString *deviceId;
// 客户端当前时间戳(13位时间戳,到毫秒)
@property(nonatomic,assign) uint64_t clientTimestamp;

@end

NS_ASSUME_NONNULL_END
