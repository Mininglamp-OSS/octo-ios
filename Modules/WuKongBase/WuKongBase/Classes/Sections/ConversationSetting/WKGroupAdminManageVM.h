//
//  WKGroupAdminManageVM.h
//  WuKongBase
//
//  群管理（群主/管理员/机器人管理员）页面 VM
//

#import "WKBaseVM.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@protocol WKGroupAdminManageVMDelegate <NSObject>
- (void)groupAdminReload;
@end

@interface WKGroupAdminManageVM : WKBaseVM

@property(nonatomic, weak) id<WKGroupAdminManageVMDelegate> delegate;

@property(nonatomic, strong) WKChannel *channel;

@property(nonatomic, assign, readonly) BOOL loading;

/// 群主（最多一个）
@property(nonatomic, strong, readonly, nullable) WKChannelMember *creator;
/// 普通管理员
@property(nonatomic, strong, readonly) NSArray<WKChannelMember*> *managers;
/// 机器人管理员
@property(nonatomic, strong, readonly) NSArray<WKChannelMember*> *botAdmins;

/// 已是 owner / manager 的 uid，用于添加管理员时禁用
@property(nonatomic, strong, readonly) NSArray<NSString*> *ownerAndManagerUids;
/// 已是 bot admin 的 uid
@property(nonatomic, strong, readonly) NSArray<NSString*> *botAdminUids;
/// 群里所有机器人成员 uid（用于过滤添加 Bot 管理员的可选范围）
@property(nonatomic, strong, readonly) NSArray<NSString*> *robotUids;
/// 群里所有非机器人成员 uid（用于过滤添加普通管理员的可选范围）
@property(nonatomic, strong, readonly) NSArray<NSString*> *nonRobotUids;

- (void)reload;

@end

NS_ASSUME_NONNULL_END
