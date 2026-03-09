//
//  WKForgetPasswordVM.h
//  WuKongLogin
//
//  Created by tt on 2020/10/27.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKForgetPasswordVM : WKBaseVM


/// 发送验证码
/// @param zone 手机区号
/// @param phone 手机号
-(AnyPromise*) sendCode:(NSString*)zone phone:(NSString*)phone;


/// 设置新密码
/// @param zone <#zone description#>
/// @param phone <#phone description#>
/// @param pwd <#pwd description#>
-(AnyPromise*) setNewPwd:(NSString*)zone phone:(NSString*)phone code:(NSString*)code pwd:(NSString*)pwd;

@end

NS_ASSUME_NONNULL_END
