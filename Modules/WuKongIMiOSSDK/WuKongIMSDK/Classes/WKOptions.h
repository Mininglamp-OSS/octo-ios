//
//  WKOptions.h
//  CocoaAsyncSocket
//
//  Created by tt on 2019/11/23.
//

#import <Foundation/Foundation.h>
#import "WKConnectInfo.h"
#import "WKConst.h"
NS_ASSUME_NONNULL_BEGIN


typedef enum : NSUInteger {
    WKModeWrite, // 写扩散模式
    WKModeRead, // 读扩散模式
} WKMode;


typedef WKConnectInfo*_Nonnull(^WKConnectInfoCallback)(void);


@interface WKOptions : NSObject


/**
 IM的host
 */
@property(nonatomic,copy) NSString *host;

/**
 IM的端口
 */
@property(nonatomic,assign) uint16_t port;


/**
 连接信息回调
 */
@property(nonatomic,copy) WKConnectInfoCallback connectInfoCallback;


/**
连接信息
 */
@property(nullable,nonatomic,strong) WKConnectInfo *connectInfo;
/**
 是否是debug模式
 */
@property(nonatomic,assign) bool isDebug;


/**
 是否有登录信息

 @return <#return value description#>
 */
-(BOOL) hasLogin;

/**
 心跳间隔 （ 单位秒）
 */
@property(nonatomic,assign) NSTimeInterval heartbeatInterval;

/**
 数据库的存储目录
 */
@property(nonatomic,copy) NSString *dbDir;


/// db前缀
@property(nonatomic,copy) NSString *dbPrefix;

// 消息文件根目录
@property(nonatomic,copy) NSString *messageFileRootDir;


/**
 在每次发送消息中是否携带发送者的用户信息。
 */
@property(nonatomic,assign) bool enableMessageAttachUserInfo;

/**
 消息重试间隔 (单位秒)
 */
@property(nonatomic,assign) NSTimeInterval messageRetryInterval;
// 编辑后的消息正文上传重试间隔  (单位秒)
@property(nonatomic,assign) NSTimeInterval contentEditRetryInterval;

// reminder已done的数据上传过期时间（超过这个时间将设置为上传失败） (单位秒)
@property(nonatomic,assign) NSTimeInterval reminderDoneUploadExpire;

@property(nonatomic,assign) NSTimeInterval reminderRetryInterval; // 提醒项重试间隔
@property(nonatomic,assign) NSInteger reminderRetryCount; // 提醒项重试次数

/**
 消息重试次数
 */
@property(nonatomic,assign) NSInteger messageRetryCount;

//  消息正文重试次数
@property(nonatomic,assign) NSInteger contentEditRetryCount;

/**
 已读回执flush到服务器的间隔
 */
@property(nonatomic,assign) NSTimeInterval receiptFlushInterval;

/**
 离线消息每次拉取数量
 */
@property(nonatomic,assign) NSInteger offlineMessageLimit;


/// 发送图片的时候图片最大大小，大于这个大小将自动压缩
@property(nonatomic,assign) long imageMaxBytes;


/// SDK使用消息协议版本（默认使用最新的协议，如果使用旧协议需要手动设置值）
@property(nonatomic,assign) uint8_t protoVersion;



/// 同步频道消息每次大小
@property(nonatomic,assign) NSInteger syncChannelMessageLimit;

/// 协议类型
@property(nonatomic,assign) WKProto proto;


@property(nonatomic,assign) NSInteger messageExtraSyncLimit; // 同步扩展消息每次数量限制

@property(nonatomic,assign) NSInteger channelRequestMaxLimit; // 同时发起请求频道数据的最大数量

// 是否追踪db日志
@property(nonatomic,assign) BOOL traceDBLog;

@property(nonatomic,assign) NSInteger expireMsgCheckInterval; // 过期消息检查间隔 单位秒
@property(nonatomic,assign) NSInteger expireMsgLimit; // 过期消息每次查询数量

@property(nonatomic,assign) NSInteger sendFrequency; // 消息发送延迟时间 单位毫秒
@property(nonatomic,assign) NSInteger sendMaxCountOfEach; // 消息每次发送最大数量

// 客户端消息设备id，如果设置了每条消息的clientMsgNo里将带这个标记
@property(nonatomic,assign) NSInteger clientMsgDeviceId;

@end

NS_ASSUME_NONNULL_END
