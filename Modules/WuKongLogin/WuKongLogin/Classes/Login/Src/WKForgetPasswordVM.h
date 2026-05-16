// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
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

/// 发送邮箱验证码
/// @param email 邮箱
/// @param codeType 验证码类型 0-注册 2-忘记密码
-(AnyPromise*) emailSendCode:(NSString*)email codeType:(NSInteger)codeType;

/// 设置新密码
/// @param zone <#zone description#>
/// @param phone <#phone description#>
/// @param pwd <#pwd description#>
-(AnyPromise*) setNewPwd:(NSString*)zone phone:(NSString*)phone code:(NSString*)code pwd:(NSString*)pwd;

/// 邮箱忘记密码
/// @param email 邮箱
/// @param code 验证码
/// @param pwd 新密码
-(AnyPromise*) emailForgetPwd:(NSString*)email code:(NSString*)code pwd:(NSString*)pwd;

@end

NS_ASSUME_NONNULL_END
