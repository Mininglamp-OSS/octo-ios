//
//  WKUUIDUtil.m
//  WuKongIMSDK
//
//  Created by tt on 2020/5/28.
//

#import "WKUUIDUtil.h"
#import "WKNOGeneraterUtil.h"
@implementation WKUUIDUtil

+ (NSString*)getUUID{
    CFUUIDRef uuidRef =CFUUIDCreate(NULL);
    CFStringRef uuidStringRef =CFUUIDCreateString(NULL, uuidRef);
    NSString *uniqueId = (__bridge NSString *)(uuidStringRef);
    return [uniqueId stringByReplacingOccurrencesOfString:@"-" withString:@""];

}

+(NSString*) getClientMsgNo:(NSInteger)clientMsgDeviceId {
    return [NSString stringWithFormat:@"%@_%ld_%@",[self getUUID],(long)clientMsgDeviceId,@"2"]; // clientMsgNo后面加一位 表示客户端标识 0.系统 1.android 2.iOS 3.Web
}
@end
