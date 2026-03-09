//
//  WKInlineQueryManager.h
//  WuKongBase
//
//  Created by tt on 2021/11/9.
//

#import <Foundation/Foundation.h>
#import "WKResultPanel.h"
#import "WKInlineQueryResult.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKInlineQueryManager : NSObject

+ (instancetype _Nonnull )shared;

-(WKResultPanel*) createResultPanel:(WKInlineQueryResult*)result context:(id<WKConversationContext> __nonnull)context;

@end

NS_ASSUME_NONNULL_END
