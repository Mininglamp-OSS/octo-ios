//
//  WKCMDContent.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/31.
//

#import "WKMediaMessageContent.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKCMDContent : WKMessageContent


/**
 cmd
 */
@property(nonatomic,copy) NSString *cmd;

/**
 cmd参数
 */
@property(nonatomic,copy) id param;

// cmd验证字段 ，校验是否是服务端下发
@property(nonatomic,copy) NSString *sign; // 签名字符串签出来的sign

@end

NS_ASSUME_NONNULL_END
