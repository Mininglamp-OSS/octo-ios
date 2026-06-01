//
//  WKGroupAdminManageVC.h
//  WuKongBase
//
//  群管理：群主可增/删管理员、管理 Bot 管理员；管理员仅可只读查看。
//

#import "WKBaseVC.h"
#import "WKGroupAdminManageVM.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKGroupAdminManageVC : WKBaseVC<WKGroupAdminManageVM*>

@property(nonatomic, strong) WKChannel *channel;

/// 当前用户是否为群主。群主可增删管理员/机器人管理员；管理员仅可查看。
@property(nonatomic, assign) BOOL isCreator;

@end

NS_ASSUME_NONNULL_END
