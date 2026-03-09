//
//  WKRegisterVM.h
//  WuKongLogin
//
//  Created by tt on 2020/6/18.
//

#import <WuKongBase/WuKongBase.h>
#import "WKLoginVM.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKRegisterVM : WKBaseVM



/// 发送验证码
/// @param zone 手机区号
/// @param phone 手机号
-(AnyPromise*) sendCode:(NSString*)zone phone:(NSString*)phone;



/// 通过手机号注册
/// @param zone 区号
/// @param phone 手机号
/// @param code 短信验证码
/// @param inviteCode 邀请码
/// @param password 密码
-(AnyPromise*) registerByPhone:(NSString*)zone phone:(NSString*)phone code:(NSString*)code inviteCode:(NSString*)inviteCode password:(NSString*)password;


/// 更新用户的名字
/// @param name <#name description#>
-(AnyPromise*) updateName:(NSString*)name;

@end

NS_ASSUME_NONNULL_END
