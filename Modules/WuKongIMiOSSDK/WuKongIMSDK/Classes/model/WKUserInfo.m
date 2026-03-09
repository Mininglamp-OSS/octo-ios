//
//  WKUser.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/29.
//

#import "WKUserInfo.h"

@implementation WKUserInfo
-(instancetype) initWithUid:(NSString*)uid name:(NSString*)name avatar:(NSString*)avatar {
    self = [super init];
    if(self) {
        self.uid = uid?:@"";
        self.name = name?:@"";
        self.avatar = avatar?:@"";
    }
    return self;
}

-(instancetype) initWithUid:(NSString*)uid name:(NSString*)name {
    return [self initWithUid:uid name:name avatar:nil];
}


@end
