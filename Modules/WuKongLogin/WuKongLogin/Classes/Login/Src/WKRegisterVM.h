// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
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

/// 发送邮箱验证码
/// @param email 邮箱
/// @param codeType 验证码类型 0-注册 2-忘记密码
-(AnyPromise*) emailSendCode:(NSString*)email codeType:(NSInteger)codeType;

/// 通过手机号注册
/// @param zone 区号
/// @param phone 手机号
/// @param code 短信验证码
/// @param inviteCode 邀请码
/// @param password 密码
-(AnyPromise*) registerByPhone:(NSString*)zone phone:(NSString*)phone code:(NSString*)code inviteCode:(NSString*)inviteCode password:(NSString*)password;

/// 通过邮箱注册
/// @param email 邮箱
/// @param code 邮箱验证码
/// @param name 昵称
/// @param password 密码
/// @param inviteCode 邀请码
-(AnyPromise*) emailRegister:(NSString*)email code:(NSString*)code name:(NSString*)name password:(NSString*)password inviteCode:(NSString*)inviteCode;

/// 更新用户的名字
/// @param name <#name description#>
-(AnyPromise*) updateName:(NSString*)name;

@end

NS_ASSUME_NONNULL_END
