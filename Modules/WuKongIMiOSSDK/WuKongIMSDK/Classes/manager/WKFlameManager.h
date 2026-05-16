//
//  WKViewedManager.h
//  WuKongIMSDK
//
//  Created by tt on 2022/8/17.
//

#import <Foundation/Foundation.h>
#import "WKMessage.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKFlameManager : NSObject

+ (WKFlameManager *)shared;

/**
  标记为已读
 */
-(void) didViewed:(NSArray<WKMessage*>*) messages;

/**
  获取需要焚烧的消息（阅后即焚）
 */
-(NSArray<WKMessage*>*) getMessagesOfNeedFlame;

@end

NS_ASSUME_NONNULL_END
