//
//  WKCardActionAPI.h
//  WuKongBase
//
//  互动卡片（octo/v2）动作提交 API。对应服务端 POST /v1/message/card/action。
//
#import <Foundation/Foundation.h>
#import "WKAPIClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKCardActionAPI : NSObject

/// 提交卡片 Action.Submit。
/// 注意：**不传 data**（服务端从存储帧提取，防伪造）。inputs 为 {inputId: value}。
/// 成功 resolve 响应字典（含 accepted/replay）；失败 reject NSError。
+ (AnyPromise *)submitCardAction:(NSString *)actionId
                       messageId:(NSString *)messageId
                       channelId:(NSString *)channelId
                     channelType:(uint8_t)channelType
                          inputs:(nullable NSDictionary *)inputs
                     clientToken:(NSString *)clientToken;

@end

NS_ASSUME_NONNULL_END
