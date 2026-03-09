//
//  WKRegisterVM.m
//  WuKongLogin
//
//  Created by tt on 2020/6/18.
//

#import "WKRegisterVM.h"

@implementation WKRegisterVM

- (AnyPromise *)sendCode:(NSString*)zone phone:(NSString*)phone {
    return [[WKAPIClient sharedClient] POST:@"user/sms/registercode" parameters:@{@"zone":zone?:@"",@"phone":phone}];
}

- (AnyPromise *)registerByPhone:(NSString *)zone phone:(NSString *)phone code:(NSString *)code inviteCode:(NSString*)inviteCode password:(NSString *)password {
    return [[WKAPIClient sharedClient] POST:@"user/register" parameters:@{@"zone":zone?:@"",@"phone":phone?:@"",@"code":code?:@"",@"invite_code":inviteCode?:@"",@"password":password?:@"",@"device":@{@"device_id":[UIDevice getUUID],@"device_name":[UIDevice getDeviceName],@"device_model":[UIDevice getDeviceModel]}} model:WKLoginResp.class];
}

-(AnyPromise*) updateName:(NSString*)name {
    return [[WKAPIClient sharedClient] PUT:@"user/current" parameters:@{@"name":name?:@""}];
}

@end
