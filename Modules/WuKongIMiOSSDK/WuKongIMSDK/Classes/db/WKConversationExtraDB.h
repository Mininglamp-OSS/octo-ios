//
//  WKConversationExtraDB.h
//  WuKongIMSDK
//
//  Created by tt on 2022/4/23.
//

#import <Foundation/Foundation.h>
#import "WKConversationExtra.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConversationExtraDB : NSObject

+ (WKConversationExtraDB *)shared;

-(void) addOrUpdates:(NSArray<WKConversationExtra*>*)extras;

-(void) updateVersion:(WKChannel*)channel version:(int64_t)version;

-(int64_t) getMaxVersion;


@end

NS_ASSUME_NONNULL_END
