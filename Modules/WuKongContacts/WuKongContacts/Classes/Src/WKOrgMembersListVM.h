// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKOrgMembersListVM.h
//  WuKongContacts
//

#import <WuKongBase/WuKongBase.h>
@class WKOrgMemberResp;
NS_ASSUME_NONNULL_BEGIN

@interface WKOrgMembersListVM : NSObject

/// 请求组织成员列表（过滤机器人和当前用户）
-(AnyPromise*) requestMembers;

@end

@interface WKOrgMemberResp : WKModel

@property(nonatomic,copy) NSString *uid;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,copy) NSString *avatar;
@property(nonatomic,assign) NSInteger role;
@property(nonatomic,assign) BOOL robot;

@end

NS_ASSUME_NONNULL_END
