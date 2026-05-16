// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKSpaceEntity.h
//  WuKongBase
//
//  Created by Claude on 2026/03/11.
//

#import <Foundation/Foundation.h>
#import "WKModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKSpaceMember : WKModel

@property(nonatomic,copy) NSString *uid;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,assign) NSInteger role; // 0=member, 1=admin, 2=owner
@property(nonatomic,copy) NSString *created_at;

@end

@interface WKSpaceEntity : WKModel

@property(nonatomic,copy) NSString *space_id;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,copy) NSString *desc;  // 对应API的description
@property(nonatomic,copy) NSString *logo;
@property(nonatomic,copy) NSString *creator;  // 对应API的creator
@property(nonatomic,assign) NSInteger status;
@property(nonatomic,assign) NSInteger role;  // 当前用户在该Space的角色：0=member, 1=owner, 2=admin
@property(nonatomic,assign) NSInteger max_users;  // 最大成员数，0表示无限制
@property(nonatomic,assign) NSInteger member_count;
@property(nonatomic,copy) NSString *invite_code;
@property(nonatomic,copy) NSString *created_at;
@property(nonatomic,copy) NSString *updated_at;

@end

NS_ASSUME_NONNULL_END
