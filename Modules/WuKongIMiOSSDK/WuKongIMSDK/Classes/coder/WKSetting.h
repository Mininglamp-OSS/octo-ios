//
//  WKSetting.h
//  WuKongIMSDK
//
//  Created by tt on 2021/4/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKSetting : NSObject


@property (nonatomic,assign) BOOL receiptEnabled; //  消息是否需要发送已读回执

//@property(nonatomic,assign) BOOL signal; // 是否signal加密

@property(nonatomic,assign) BOOL topic; // 是否存在话题

@property(nonatomic,assign) BOOL streamOn; // 是否开启流式消息

@property(nonatomic,assign) NSInteger expire; // 消息过期时长（单位秒）


-(uint8_t) toUint8;

+(WKSetting*) fromUint8:(uint8_t)v;

@end

NS_ASSUME_NONNULL_END
