//
//  WKChannelDataManager.m
//  25519
//
//  Created by tt on 2022/12/2.
//

#import "WKChannelDataManager.h"

@implementation WKChannelDataManager

static WKChannelDataManager *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKChannelDataManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (void)members:(WKChannel *)channel keyword:(NSString *)keyword page:(NSInteger)page limit:(NSInteger)limit complete:(void (^)(NSError *error,NSArray<WKChannelMember *> * _Nonnull))complete {
    if(_delegate && [_delegate respondsToSelector:@selector(channelDataManager:members:keyword:page:limit:complete:)]) {
        [_delegate channelDataManager:self members:channel keyword:keyword page:page limit:limit complete:complete];
    }
}



@end
