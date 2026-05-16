//
//  WKForgetPasswordVM.m
//  WuKongLogin
//
//  Created by tt on 2020/10/27.
//

#import "WKForgetPasswordVM.h"

@implementation WKForgetPasswordVM


- (AnyPromise *)sendCode:(NSString*)zone phone:(NSString*)phone {
    return [[WKAPIClient sharedClient] POST:@"user/sms/forgetpwd" parameters:@{@"zone":zone?:@"",@"phone":phone}];
}

- (AnyPromise *)emailSendCode:(NSString*)email codeType:(NSInteger)codeType {
    return [[WKAPIClient sharedClient] POST:@"user/email/sendcode" parameters:@{@"email":email?:@"",@"code_type":@(codeType)}];
}

- (AnyPromise *)setNewPwd:(NSString *)zone phone:(NSString *)phone code:(NSString *)code pwd:(NSString *)pwd {
    return [[WKAPIClient sharedClient] POST:@"user/pwdforget" parameters:@{@"zone":zone?:@"",@"phone":phone,@"code":code,@"pwd":pwd}];
}

- (AnyPromise *)emailForgetPwd:(NSString *)email code:(NSString *)code pwd:(NSString *)pwd {
    return [[WKAPIClient sharedClient] POST:@"user/email/forgetpwd" parameters:@{@"email":email?:@"",@"code":code?:@"",@"new_password":pwd?:@""}];
}
@end
