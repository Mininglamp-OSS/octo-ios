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

/// 从 /api/v1/space/my 的原始返回里挑出"用户实际是成员"的第一个 Space。
///
/// 服务端语义：role==0 表示该 Space 仅对当前用户可见/可加入，**不是成员**；
/// 进一步访问 /space/{id}/members、/conversation/sync?space_id=... 会被服务端 403。
/// role>0 才是成员（owner/admin/member 任一种角色都行）。
///
/// 历史坑：登录回落逻辑曾经直接 spaces[0]，aegis 切账号场景下挑到了 role=0 的
/// 空间，整个 IM 接口全 403，UI 显示空白。
/// 注意 WKSpaceEntity.h / WKSpace 类里的 role 注释和服务端实际语义不一致，以
/// 实际行为为准。
+(nullable NSDictionary*) pickJoinedSpace:(nullable NSArray*)spaces;

@end

NS_ASSUME_NONNULL_END
