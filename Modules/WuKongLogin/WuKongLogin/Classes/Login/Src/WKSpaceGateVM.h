// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKSpaceGateVM.h
//  WuKongLogin
//
//  Created by Claude on 2026/03/11.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKSpace : NSObject
@property(nonatomic,copy) NSString *spaceId;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,copy) NSString *spaceDescription;
@property(nonatomic,copy) NSString *logo;
@property(nonatomic,assign) NSInteger memberCount;
@property(nonatomic,assign) NSInteger maxUsers; // 0 means unlimited
@property(nonatomic,assign) NSInteger role; // 1: owner, 2: admin, 3: member
@property(nonatomic,copy) NSString *createdAt;
@end

@interface WKSpaceCreateResp : NSObject
@property(nonatomic,copy) NSString *spaceId;
@end

@interface WKInviteResp : NSObject
@property(nonatomic,copy) NSString *inviteCode;
@property(nonatomic,copy) NSString *inviteUrl;
@end

@interface WKSpaceGateVM : WKBaseVM

/// 获取我的空间列表
-(AnyPromise*) getMySpaces;

/// 创建新空间
/// @param name 空间名称
/// @param description 空间描述
-(AnyPromise*) createSpace:(NSString*)name description:(NSString*)description;

/// 加入空间
/// @param inviteCode 邀请码
-(AnyPromise*) joinSpace:(NSString*)inviteCode;

/// 创建邀请码
/// @param spaceId 空间ID
-(AnyPromise*) createInvite:(NSString*)spaceId;

@end

NS_ASSUME_NONNULL_END
