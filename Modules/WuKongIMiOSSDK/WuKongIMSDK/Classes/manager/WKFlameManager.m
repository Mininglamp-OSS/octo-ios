//
//  WKViewedManager.m
//  WuKongIMSDK
//
//  Created by tt on 2022/8/17.
//

#import "WKFlameManager.h"
#import "WKMessageDB.h"
#import "WKSDK.h"
@implementation WKFlameManager


static WKFlameManager *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKFlameManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(void) didViewed:(NSArray<WKMessage*>*) messages {
    if(!messages || messages.count == 0) {
        return;
    }
    messages = [[WKMessageDB shared] updateViewed:messages];
    
    for (WKMessage *message in messages) {
        [WKSDK.shared.chatManager callMessageUpdateDelegate:message];
    }
}

-(NSArray<WKMessage*>*) getMessagesOfNeedFlame {
    return [WKMessageDB.shared getMessagesOfNeedFlame];
}

@end
