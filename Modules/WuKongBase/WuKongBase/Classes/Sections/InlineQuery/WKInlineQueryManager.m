//
//  WKInlineQueryManager.m
//  WuKongBase
//
//  Created by tt on 2021/11/9.
//

#import "WKInlineQueryManager.h"
#import "WKGifResultPanel.h"
@implementation WKInlineQueryManager

+ (instancetype)shared{
    static WKInlineQueryManager *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[WKInlineQueryManager alloc] init];
    });
    return _shared;
}

-(WKResultPanel*) createResultPanel:(WKInlineQueryResult*)result context:(id<WKConversationContext>)context{
    if([result.type isEqualToString:@"gif"]) {
        WKGifResultPanel *gifPanel = [WKGifResultPanel result:result context:context];
        return gifPanel;
    }
    return nil;
}

@end
