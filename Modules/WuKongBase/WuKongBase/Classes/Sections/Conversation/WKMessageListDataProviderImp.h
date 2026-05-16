//
//  WKMessageListDataProviderImp.h
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import <Foundation/Foundation.h>
#import "WKMessageListDataProvider.h"
NS_ASSUME_NONNULL_BEGIN


@interface WKMessageListDataProviderImp : NSObject<WKMessageListDataProvider>

-(instancetype) initWithChannel:(WKChannel*)channel conversationContext:(id<WKConversationContext>)conversationContext;




@end

NS_ASSUME_NONNULL_END
