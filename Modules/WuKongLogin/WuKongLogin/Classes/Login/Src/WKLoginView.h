//
//  WKLogicView.h
//  WuKongLogin
//
//  Created by tt on 2019/12/2.
//

#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase.h>
NS_ASSUME_NONNULL_BEGIN

typedef void(^onLogin)(NSString*mobile,NSString*password,NSString *country);
@interface WKLoginView : UIView

@property(nonatomic,copy) onLogin onLogin;

@property(nonatomic,strong) NSString *country;
@property(nonatomic,strong) NSString *mobile;

- (void)viewConfigChange:(WKViewConfigChangeType)type;

// Refresh the login page UI based on the current `WKAppRemoteConfig`:
// - `loginEnable` / `registerEnable` (新): 是否展示 Octo 自有账号密码登录 / 注册入口
// - `oidcProviders` (老): 是否展示 Aegis SSO 按钮
// 三个开关组合出三种形态:
//   A) loginEnable=YES         → 现状布局（含 SSO 按钮可选）, 表单 + 登录 + 可选注册 + 可选 SSO
//   B) loginEnable=NO + 有 SSO → SSO-only 形态: app logo + 居中欢迎标题 + 主 SSO 按钮 + helper
//   C) loginEnable=NO + 无 SSO → 兜底回到 A 避免登录页全空白
// Safe to call repeatedly; idempotent.
- (void)refreshDynamicConfig;
@end

NS_ASSUME_NONNULL_END
