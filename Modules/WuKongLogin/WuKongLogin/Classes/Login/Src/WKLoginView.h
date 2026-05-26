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
// - 有 `oidcProviders` → SSO-only 形态: app logo + 居中欢迎标题 + 主 SSO 按钮 + helper
// - 无 `oidcProviders` → 标准布局: 表单 + 登录 + 注册入口
// (历史注释提到的 `loginEnable` / `registerEnable` 字段在 WKAppRemoteConfig 上并不存在,
//  当前形态切换只看 oidcProviders 是否非空; 如未来要单独控制 Octo 自有账号入口,
//  需先在 WKAppRemoteConfig 上加字段, 这里再扩展.)
// Safe to call repeatedly; idempotent.
- (void)refreshDynamicConfig;
@end

NS_ASSUME_NONNULL_END
