//
//  WKOidcProviderConfig.h
//  WuKongBase
//
//  / — 后端 /v1/common/appconfig 返回的
//  oidc_providers[] 数组的 entry 模型。字段跟 dmworkim
//  modules/common/api.go 的下发口径对齐:
//    { id, name, authorize_path, account_url, reset_password_url }
//
//  account_url 会因环境不同而不同（im-test → accounts-test.imocto.cn;
//  im-prod → accounts.example.com）。客户端把 Aegis 账户页 / 实名认证入口
//  的域名读点全部收敛到这个模型, 不再允许任何 hardcoded prod 常量。
//
//  Required / Optional（review suggestion 1 后对齐）:
//    required: id, authorize_path（authorize_path 必须 '/' 开头且不以 '//' 开头）
//    optional: name, account_url, reset_password_url
//  name 只是 UI 展示字段, 缺失时调用侧应 fallback 到 id 显示; account_url
//  是实名认证的核心字段但也允许 entry 无此字段（该 provider 不支持 Aegis
//  账户页入口, 调用侧 toast 兜底, 不跳转）。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKOidcProviderConfig : NSObject

/// 后端下发的 provider id（如 "xming"）。**Required**; 空 id 的 entry 被 parse 时跳过。
@property(nonatomic,copy) NSString *providerId;

/// 展示名（"xming" 等）。**Optional** — 缺失的 entry 仍保留, 调用侧 UI 可 fallback
/// 到 providerId 展示。P-S1: 修复原实现 required-else-skip 与注释矛盾。
@property(nonatomic,copy,nullable) NSString *name;

/// OIDC authorize 的服务端相对路径（如 "/auth/oidc/xming/authorize"）。**Required**,
/// 仅放行 '/' 开头且不以 '//' 开头的 path, 防 protocol 跳出注入。格式不合法 entry 跳过。
@property(nonatomic,copy,nullable) NSString *authorizePath;

/// Aegis 账户中心 URL 基址（如 "https://accounts-test.imocto.cn" 或
/// "https://accounts.example.com"）。**Optional**, 仅接受 https 协议的 URL,
/// javascript:/data: 等协议的值被 parse 时置 nil（entry 保留但字段 nil）。
/// 此字段是「基址 URL」语义, 带 query (?...) 或 fragment (#...) 均判为配置错误,
/// parser 同样置 nil（避免 buildVerifyURLFromAccountUrl: 拼出 `base?x=1/path?anchor=...`
/// 之类语义歧义的 URL; Round 2 / suggestion）。
/// 这个字段是按环境下发的核心点, 无此字段时调用侧 toast 兜底不跳转。
@property(nonatomic,copy,nullable) NSString *accountUrl;

/// 重置密码 URL, **Optional**。同样只接受 https, 非法值置 nil。
@property(nonatomic,copy,nullable) NSString *resetPasswordUrl;

/// 把后端下发的 NSArray<NSDictionary*> 解析成模型数组。
///
/// 跳过 entry 的情形（与上文 Required 对齐）:
///   - raw 不是数组 / item 不是 dict
///   - id 缺失 / 非 NSString / 空串
///   - authorize_path 不是 '/' 开头 / 以 '//' 开头 / 非 NSString
///
/// 保留 entry 但字段置 nil 的情形:
///   - name 缺失（P-S1: 改了, 保留 entry; 原先会跳）
///   - account_url / reset_password_url 为非 https 协议 / 无 host
///
/// 整个 appconfig 接口不会因单条 provider 配置坏而整体降级。
+ (NSArray<WKOidcProviderConfig*> *)parseArray:(nullable NSArray *)raw;

/// 拼 OIDC authorize URL (WKLoginView / WKRegisterVC 共用 helper, R1 fix)。
///
/// 引入背景: Jerry-Xin R1 给 PR #114 指出 authorize URL 用
/// URLQueryAllowedCharacterSet 手拼 query 时, 逻辑符 `&`/`=`/`+` 不会被转义
/// → authcode / device_name 中出现特殊字符会产生参数截断或注入。
/// 本方法改用 NSURLComponents + NSURLQueryItem, 由系统第一方做 RFC 3986
/// 安全转义。
///
/// path 解析三种情形对齐旧实现（WKLoginView / WKRegisterVC）:
///   • https://绝对URL   → 直用
///   • /v1/..  origin-relative   → relativeToURL:apiBase 拼主机
///   • user/x  API-relative     → append to apiBase
/// flag=3, device_* 三元组保留原语义 (iOS SDK CONNECT deviceFlag=3)。
///
/// 返 nil 情形: authorize_path 空 / apiBase 空 / 拼出的 base 不是合法 URL。
///
/// 无完整 URL 日志泄露 — 仅 host/path 级别 debug 日志, authcode/device_* 脱敏。
+ (nullable NSURL *)buildAuthorizeURLForProvider:(WKOidcProviderConfig *)provider
                                         authcode:(NSString *)authcode
                                          apiBase:(NSString *)apiBase
                                         deviceId:(nullable NSString *)deviceId
                                       deviceName:(nullable NSString *)deviceName
                                      deviceModel:(nullable NSString *)deviceModel;

/// 递归剩定任意 NSArray / NSDictionary 中的 NSNull, 产出 plist-safe 副本用于
/// 安全写 NSUserDefaults / Info.plist 等 plist-支持的存储。
///
/// R3 fix (Jerry-Xin PR #114 Critical): 后端 /common/appconfig 下发的
/// oidc_providers[].{name, account_url, reset_password_url} 等 optional 字段若下发
/// 为 JSON null, NSJSONSerialization 会映射为 NSNull。NSNull 不是 plist 类型,
/// 直接 setObject: 到 NSUserDefaults 会抛 NSInvalidArgumentException。
///
/// 此方法 deep-clean 后返回新对象:
///   - NSArray/NSDictionary: 递归展开
///   - NSNull: 从 array 中跳过, 从 dict 中删除 key
///   - 其它非 plist 类型 (如 NSDate 以外的自定义类): 关错跳过
///   - plist-原生类型 (NSString/NSNumber/NSData/NSDate): 原样保留
///
/// 主要调用点: WKAppConfig.m requestConfig: success 分支缓存 oidc_providers。
+ (nullable id)plistSanitize:(nullable id)value;

@end

NS_ASSUME_NONNULL_END
