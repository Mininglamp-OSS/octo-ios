//
//  WKMessageQueueManager.h
//  WuKongIMSDK
//
//  Created by tt on 2023/11/15.
//

#import <Foundation/Foundation.h>
#import "WKMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKMessageQueueManager : NSObject

+ (WKMessageQueueManager *)shared;

-(void) start;

-(void) stop;

- (void)sendMessage:(WKMessage *)message;

@end

NS_ASSUME_NONNULL_END
