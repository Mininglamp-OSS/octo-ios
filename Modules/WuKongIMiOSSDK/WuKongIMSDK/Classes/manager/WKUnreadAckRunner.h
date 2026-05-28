//
//  WKUnreadAckRunner.h
//  WuKongIMSDK
//
//  Drain WKUnreadAckQueueDB and upload mark-read events to server with
//  exponential backoff. Kicked by WKUnreadStore.markLocalRead and by
//  WKConnectionManager when WKConnected fires.
//
//  Upload provider is injected from above (DataSource layer holds the
//  HTTP client). SDK does not depend on Base / DataSource.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"

NS_ASSUME_NONNULL_BEGIN

/// 上报 provider: 由 DataSource 注入. complete(nil) 视为成功 → dequeue.
/// complete(error) 视为失败 → backoff 重试.
typedef void(^WKUnreadAckProvider)(WKChannel *channel,
                                   uint32_t lastReadSeq,
                                   void(^complete)(NSError * _Nullable error));

@interface WKUnreadAckRunner : NSObject
+ (instancetype) shared;

/// 注入上报 provider. 必须在登录后/首次 kick 之前设置.
-(void) setUploadProvider:(WKUnreadAckProvider)provider;

/// 尝试 drain 一轮: 拉所有 due 的条目,挨个上传, 成功 dequeue / 失败 backoff.
/// 同一时刻只允许一轮在跑,重复 kick 安全.
-(void) kick;

@end

NS_ASSUME_NONNULL_END
