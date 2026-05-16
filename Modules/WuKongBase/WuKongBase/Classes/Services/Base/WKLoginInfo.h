// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKLoginInfo.h
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN



@interface WKLoginInfo : NSObject<NSCoding>
+ (WKLoginInfo *)shared;
/**
 用户唯一ID
 */
@property(nonatomic,copy) NSString *uid;

@property(nonatomic,copy) NSString *deviceUUID; // 设备唯一ID，卸载app将会改变

/**
 用户token
 */
@property(nonatomic,copy) NSString *token;

// im token
@property(nonatomic,copy) NSString *imToken;


// 设备token 推送用的
@property(nonatomic,copy) NSString *deviceToken;


/**
 扩展数据
 */
@property(nonatomic,strong) NSMutableDictionary *extra;

#pragma mark - 实名认证（OCTO OCTO realname verification）

/// 是否已完成实名认证（后端 /v1/internal/verification/complete 回写）
/// 存储位置：extra[@"realname_verified"]
@property(nonatomic,assign) BOOL realnameVerified;

/// 真实姓名（仅在 realnameVerified == YES 时有值）
/// 存储位置：extra[@"real_name"]
@property(nonatomic,copy,nullable) NSString *realName;

/// 实名认证通过的时间（unix 秒，用于"已认证 · {年-月}"展示）
/// 存储位置：extra[@"realname_verified_at"]
@property(nonatomic,assign) NSTimeInterval realnameVerifiedAt;

/// 展示名：
///   - 已实名：real_name（非空）
///   - 未实名 / 降级：extra[@"name"]
/// 所有原先使用 `loginInfo.extra[@"name"]` 的 UI 路径应迁移到此接口。
@property(nonatomic,copy,readonly) NSString *displayName;

-(void) save;

-(void) load;
// 清空所有登录信息
-(void) clear;
// 清除核心数据
-(void) clearMainData;

@end

NS_ASSUME_NONNULL_END
