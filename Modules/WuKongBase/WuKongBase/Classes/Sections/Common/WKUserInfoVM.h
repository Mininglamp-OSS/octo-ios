// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKUserInfoVM.h
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import "WKBaseTableVM.h"
#import "WKFormSection.h"
@class WKUserInfoVM;
typedef void(^channelInfoCompletion)(void);

NS_ASSUME_NONNULL_BEGIN

@protocol WKUserInfoVMDelegate <NSObject>

@optional


/// 更新备注
/// @param vm <#vm description#>
-(void) userInfoVMUpdateRemark:(WKUserInfoVM*)vm;


/// 解除好友关系
/// @param vm <#vm description#>
-(void) userInfoVMFreeFriend:(WKUserInfoVM*)vm;


/// 添加黑名单
/// @param vm <#vm description#>
-(void) userInfoVMAddBlacklist:(WKUserInfoVM*)vm;

/// 移除黑名单
/// @param vm <#vm description#>
-(void) userInfoVMRemoveBlacklist:(WKUserInfoVM*)vm;

/// 举报
/// @param vm <#vm description#>
-(void) userInfoVMReport:(WKUserInfoVM*)vm;

@end

@interface WKUserInfoVM : WKBaseTableVM


@property(nonatomic,copy) NSString *uid;
@property(nonatomic,strong) WKChannelInfo *channelInfo;

/// 机器人创建者 uid（来自 /users/<uid> 响应顶层 `bot_creator_uid`，仅 robot=YES 时下发）。
/// VC 据此判定当前登录者是否为该 Bot 的创建者，控制头像页 3-dots 编辑入口可见性。
/// 对齐 Android `UserInfo.bot_creator_uid` + `isBotOwner` 计算
/// （wkuikit/.../user/UserDetailActivity.java:522-529）。
@property(nonatomic,copy,readonly,nullable) NSString *botCreatorUid;

@property(nonatomic,strong,nullable) WKChannel *fromChannel; // 从那个频道进入的用户信息页面
@property(nonatomic,strong) WKChannelInfo *fromChannelInfo; // 从那个频道过来的
@property(nonatomic,strong) WKChannelMember *memberOfUser; // 用户在频道内的成员对象（ 如果是从某个频道过来的，则有可能有此值）
@property(nonatomic,strong) WKChannelMember *memberOfMy; // 我在频道内的成员对象（ 如果是从某个频道过来的，则有可能有此值）

@property(nonatomic,assign,readonly) BOOL isBlacklist; // 是黑名单那用户
@property(nonatomic,assign) BOOL isActualFriend; // 服务器实际好友关系（通过 friend/relation API 检查）

@property(nonatomic,weak) id<WKUserInfoVMDelegate> delegate;

///加载个人频道信息（如果没有则去服务器请求）
/// @param uid <#uid description#>
-(void) loadPersonChannelInfo:(NSString*)uid completion:(channelInfoCompletion)completion;

/**
 申请好友

 @param uid 好友uid
 @param remark 申请备注
 @return <#return value description#>
 */
-(AnyPromise*) applyFriend:(NSString*)uid remark:(NSString*)remark vercode:(NSString*)vercode;


/// 修改备注
/// @param remark 备注
-(AnyPromise*) updateRemark:(NSString*)remark;


/// 删除好友
-(AnyPromise*) deleteFriend;

// 添加黑名单
-(AnyPromise*) addBlacklist;

/// 删除黑名单
-(AnyPromise*) deleteBlacklist;

/// 检查与指定用户的实际好友关系（通过 friend/relation API）
-(void) checkFriendRelation:(NSString*)uid completion:(void(^)(BOOL isFriend))completion;

/// : viewer-relative 判定「当前页面 uid 对当前观察者（currentSpaceId）是否外部」。
/// 规则对齐 web `resolveExternalForViewer` (PR #1013/#1091) 与 android
/// `ExternalViewerResolver` (PR #135)：
///   - 群内路径（有 memberOfUser.extra）：优先取 member.extra 里的
///     home_space_id / is_external 走 `WKExternalViewerResolver`
///   - 个人详情路径：走 loadPersonChannelInfo 缓存的 userHomeSpaceId /
///     userIsExternalLegacy（/users/<uid> 响应）
/// 用于 WKUserInfoVC 隐藏「申请加好友」按钮（外部成员仅限群内沟通）。
-(BOOL) isExternalForViewer;

-(void) initData;

@end

NS_ASSUME_NONNULL_END
