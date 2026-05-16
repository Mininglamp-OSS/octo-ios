// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
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

- (AnyPromise *)emailSendCode:(NSString*)email codeType:(NSInteger)codeType {
    return [[WKAPIClient sharedClient] POST:@"user/email/sendcode" parameters:@{@"email":email?:@"",@"code_type":@(codeType)}];
}

- (AnyPromise *)registerByPhone:(NSString *)zone phone:(NSString *)phone code:(NSString *)code inviteCode:(NSString*)inviteCode password:(NSString *)password {
    // flag: 0=app(旧版), 1=pc/web, 2=Android, 3=iOS
    return [[WKAPIClient sharedClient] POST:@"user/register" parameters:@{@"zone":zone?:@"",@"phone":phone?:@"",@"code":code?:@"",@"invite_code":inviteCode?:@"",@"password":password?:@"",@"flag":@(3),@"device":@{@"device_id":[UIDevice getUUID],@"device_name":[UIDevice getDeviceName],@"device_model":[UIDevice getDeviceModel]}} model:WKLoginResp.class];
}

- (AnyPromise *)emailRegister:(NSString *)email code:(NSString *)code name:(NSString *)name password:(NSString *)password inviteCode:(NSString *)inviteCode {
    // flag: 0=app(旧版), 1=pc/web, 2=Android, 3=iOS
    return [[WKAPIClient sharedClient] POST:@"user/emailregister" parameters:@{@"email":email?:@"",@"code":code?:@"",@"name":name?:@"",@"password":password?:@"",@"invite_code":inviteCode?:@"",@"flag":@(3),@"device":@{@"device_id":[UIDevice getUUID],@"device_name":[UIDevice getDeviceName],@"device_model":[UIDevice getDeviceModel]}} model:WKLoginResp.class];
}

-(AnyPromise*) updateName:(NSString*)name {
    return [[WKAPIClient sharedClient] PUT:@"user/current" parameters:@{@"name":name?:@""}];
}

@end
