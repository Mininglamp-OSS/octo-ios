//
//  WKReceiptManager.h
//  WuKongIMSDK
//
//  Created by tt on 2021/4/9.
//

#import <Foundation/Foundation.h>
#import "WKMessage.h"
NS_ASSUME_NONNULL_BEGIN

// 消息已读
typedef void(^WKMessageReadedCallback)(NSError * __nullable error);
typedef void(^WKMessageReadedProvider)(WKChannel *channel,NSArray<WKMessage*>*messages,WKMessageReadedCallback callback);

@interface WKReceiptManager : NSObject

+ (WKReceiptManager *)shared;

/**
 添加需要已读回执的消息
 */
-(void) addReceiptMessages:(WKChannel*)channel messages:(NSArray<WKMessage*>*)messages;


/**
 flush到服务器
 */
//-(void) flush:(WKChannel*)channel complete:(void(^)(NSError *error))complete;

// 消息已读提供者
@property(nonatomic,copy) WKMessageReadedProvider messageReadedProvider;


@end

NS_ASSUME_NONNULL_END
