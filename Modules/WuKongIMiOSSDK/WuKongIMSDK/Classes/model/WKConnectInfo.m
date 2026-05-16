//
//  WKConnectInfo.m
//  WuKongIMSDK
//
//  Created by tt on 2020/2/7.
//

#import "WKConnectInfo.h"

@implementation WKConnectInfo

+(instancetype) initWithUID:(NSString*)uid token:(NSString*)token name:(NSString*)name avatar:(NSString*)avatar {
    WKConnectInfo *connectInfo = [WKConnectInfo new];
    connectInfo.uid = uid;
    connectInfo.name = name;
    connectInfo.token = token;
    connectInfo.avatar = avatar;
    return connectInfo;
}
@end
