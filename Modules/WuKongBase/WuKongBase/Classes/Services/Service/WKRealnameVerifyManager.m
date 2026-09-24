//
//  WKRealnameVerifyManager.m
//  WuKongBase
//
//  / Aegis Phase 2c — 「去认证」入口直跳 Aegis 账户页
//  / — 按环境从 appconfig.oidc_providers[].account_url
//                                 读取 Aegis 域名, 不再硬编码 prod URL
//  Round 2 / Jerry-Xin #112 review blocking 2 — 移除 Universal Link
//                                 fallback, 回跳只走 dmwork:// custom scheme
//

#import "WKRealnameVerifyManager.h"
#import "WuKongBase.h"   // LLang + 常用类（WKAPIClient / WKLoginInfo / WKApp / 常量 / WKWebViewVC / WKNavigationManager）
#import "WKAppConfig.h"  // WKAppRemoteConfig.oidcProviders
#import "WKOidcProviderConfig.h"
#import <PromiseKit/PromiseKit.h>

// 自定义回跳 scheme：默认从 Info.plist 的 OCTOURLScheme 读
// （来自 OctoConfig.xcconfig 的 OCTO_URL_SCHEME 变量替换），
// 缺省值为 "octo"。改这个需要同步更新后端 return_to 配置。
NSString *const WKRealnameVerifiedURLHost   = @"verified";

static NSString *_WKResolveURLScheme(void) {
    NSString *fromPlist = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"OCTOURLScheme"];
    if (fromPlist.length > 0 && ![fromPlist isEqualToString:@"$(OCTO_URL_SCHEME)"]) {
        return fromPlist;
    }
    return @"octo";
}

NSString *WKRealnameVerifiedURLScheme;

__attribute__((constructor))
static void _WKRealnameVerifiedURLSchemeInit(void) {
    WKRealnameVerifiedURLScheme = _WKResolveURLScheme();
}

// Aegis 账户页实名认证锚点路径。domain 部分从 appconfig 读, 拼接规则
// 与 Web 端 resolveRealnameVerifyUrl 对齐（路径 / fragment 口径一致）。
static NSString *const WKAegisAccountVerificationPath = @"/profile/info?anchor=verification";

// _resolveProviderAndLaunchFromVC: push 出去的页面 + push 前的锚点页（一般是
// 设置页）。弱引用, 不影响正常的 VC 生命周期。
//
// 用途 (PR #101 review P1): WKWebViewVC 只有在「页面内导航到 <scheme>://verified
// 且 openURL: 成功」时才会自己 popViewControllerAnimated:。但用户可能点了页面
// 右上角「更多 → 在浏览器中打开」在系统 Safari 里完成认证——这种情况下回跳信号
// 根本不经过这个页面自己的导航拦截, 容器不会自己关, 也没有任何 observer 会替它
// 关（WKMeVC / WKMeInfoVC / WKCommonSettingVC 收到认证完成通知只 reloadData）。
// 这里在 handleVerifiedCallback: 里主动兜底关闭, 不依赖容器自己关。
static __weak WKWebViewVC *s_realnameWebVC;
static __weak UIViewController *s_realnameAnchorVC;

@implementation WKRealnameVerifyManager

+ (instancetype)shared {
    static WKRealnameVerifyManager *_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

#pragma mark - appconfig 读取

/// 从当前 appconfig.oidc_providers 里挑第一个 account_url 非空的 provider,
/// 返回其 account_url 字符串。无可用 provider 时返 nil。
///
/// 选择策略：iOS 当前不像 Web 那样在 loginInfo 上跟踪 login_provider（登录
/// 流程尚未支持多 provider）, 所以按「first provider with non-empty account_url」
/// 选。生产环境每个部署实例下发的 oidc_providers 通常只有一条 entry, 一致。
/// 若未来 iOS 登录流支持多 provider, 这里改为按登录时保存的 provider id 精确匹配。
+ (nullable NSString *)primaryAegisAccountUrl {
    NSArray<WKOidcProviderConfig*> *providers = [WKApp shared].remoteConfig.oidcProviders;
    if(![providers isKindOfClass:[NSArray class]]) return nil;
    for(WKOidcProviderConfig *p in providers) {
        if(p.accountUrl.length > 0) return p.accountUrl;
    }
    return nil;
}

/// 把 accountUrl 末尾多余斜杠剥掉, 防 `//profile/...` 协议相对 URL（等价于 Web
/// 端 resolveRealnameVerifyUrl 里的 `replace(/\/+$/,'')`）。
+ (NSString *)stripTrailingSlashes:(NSString *)url {
    if(url.length == 0) return url;
    NSInteger end = url.length;
    while(end > 0 && [url characterAtIndex:end-1] == '/') end--;
    return [url substringToIndex:end];
}

#pragma mark - Callback detection

+ (BOOL)isVerifiedCallbackURL:(NSURL *)url {
    if(!url) return NO;
    NSString *scheme = url.scheme.lowercaseString;
    NSString *host   = url.host.lowercaseString;
    // 仅支持自定义 scheme `<scheme>://verified`（scheme 由 OCTO_URL_SCHEME 决定,
    // 默认 octo, 见 WKRealnameVerifiedURLScheme）, 不支持 Universal Link 降级。
    //
    // Round 2 决定（见本文件头部注释 + PR #112 review blocking 2）:
    // UL 降级会要求 entitlement applinks:* 列出所有 Aegis host, 但 Aegis host
    // 是按环境后端动态下发的, 静态 entitlement 与动态配置 在架构上冲突, 同时
    // Aegis 侧还要持 AASA 文件, 运维成本高。Aegis return_to 现在统一用
    // <scheme>://verified app scheme 回跳 —— 与 Android、Web 的 `?verified=1`
    // 一致, 0 entitlement 维护成本, 未来新增环境 0 发版成本。
    return [scheme isEqualToString:WKRealnameVerifiedURLScheme] &&
           [host isEqualToString:WKRealnameVerifiedURLHost];
}

+ (void)handleVerifiedCallback:(NSURL *)url {
    WKLogInfo(@"[Realname] received verified callback: %@", url);

    // 实名认证页跑在 App 私有 WKWebViewVC 里（见 _resolveProviderAndLaunchFromVC:），
    // 页面内导航到 <scheme>://verified 时 WKWebViewVC.decidePolicyForNavigationAction
    // 通常会自己 popViewControllerAnimated:。但如果用户是从页面「更多 → 在浏览器中
    // 打开」跳去系统 Safari 完成的认证，回跳不会经过那段逻辑，容器不会自己关——这里
    // 主动兜底一次，页面还在导航栈上就关掉它。
    dispatch_async(dispatch_get_main_queue(), ^{
        WKWebViewVC *webVC = s_realnameWebVC;
        UIViewController *anchor = s_realnameAnchorVC;
        if(webVC && anchor) {
            [[WKNavigationManager shared] popToViewController:anchor animated:NO];
        }
    });

    // 重新拉取 user/current，服务器会返回带 realname_verified + real_name 的最新资料
    [[WKAPIClient sharedClient] GET:@"user/current" parameters:nil].then(^(id responseObj){
        NSDictionary *data = [responseObj isKindOfClass:[NSDictionary class]] ? responseObj : @{};

        WKLoginInfo *login = [WKApp shared].loginInfo;
        BOOL verified = NO;
        id vVal = data[@"realname_verified"];
        if(vVal) verified = [vVal boolValue];

        NSString *realName = nil;
        id rnVal = data[@"real_name"];
        if([rnVal isKindOfClass:[NSString class]]) realName = (NSString *)rnVal;

        NSTimeInterval ts = 0;
        id tsVal = data[@"realname_verified_at"];
        if(tsVal) ts = [tsVal doubleValue];

        login.realnameVerified   = verified;
        login.realName           = realName;
        if(ts > 0) login.realnameVerifiedAt = ts;
        if(verified && ts <= 0) {
            // 没下发时间戳时用当前时间兜底，保证"已认证 · {年-月}"能显示
            login.realnameVerifiedAt = [[NSDate date] timeIntervalSince1970];
        }
        [login save];

        // 主线程派送通知：PromiseKit .then 默认在主线程，但 AFNetworking 的 completion
        // 可能在后台 queue 上 resolve。observer（WKMeVC / WKMeInfoVC / WKCommonSettingVC）收到通知
        // 后会调 `[self reloadData]` 触发 UIKit，必须显式派送主线避免 undefined behavior。
        // object: 传 self 符合 NSNotification 语义（sender），附加数据走 userInfo:。
        NSDictionary *userInfo = @{
            @"verified": @(verified),
            @"real_name": realName ?: @""
        };
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_REALNAME_VERIFIED
                                                                object:[WKRealnameVerifyManager shared]
                                                              userInfo:userInfo];
        });
        return nil;
    }).catch(^(NSError *error){
        WKLogError(@"[Realname] refresh user/current failed: %@", error);
    });
}

#pragma mark - Start verification

/// 按 accountUrl 拼 Aegis 实名认证 URL。accountUrl 空 / 非 https / host 空 /
/// 带 query / 带 fragment → nil （调用侧应 toast 兜底）。
/// 等价于 Web 端 resolveRealnameVerifyUrl(ok=true) 分支。
///
/// query / fragment 的守卫与 WKOidcProviderConfig.sanitizeHttpsURL: 同语义, 这里
/// 是深层防御（defense-in-depth, R3 suggestion 1）—— 该方法是 public
/// header 导出的, 允许外部调用者传入 parser 层之外的 accountUrl 值, 即使 parser
/// 层改了也不能让 builder 拼出语义歧义的 URL。
+ (nullable NSURL *)buildVerifyURLFromAccountUrl:(nullable NSString *)accountUrl {
    if(accountUrl.length == 0) return nil;
    // query/fragment 守卫: 拼 `<base>/profile/info?anchor=verification`, 若 base
    // 本身就带 ?query 或 #fragment, 拼出来 URL 同时出现两个 '?' 或 '#' 语义歧义。
    NSURLComponents *comp = [NSURLComponents componentsWithString:accountUrl];
    if(comp.query != nil || comp.fragment != nil) return nil;

    NSString *trimmed = [self stripTrailingSlashes:accountUrl];
    if(trimmed.length == 0) return nil;
    NSString *full = [NSString stringWithFormat:@"%@%@", trimmed, WKAegisAccountVerificationPath];
    NSURL *url = [NSURL URLWithString:full];
    if(!url) return nil;
    // scheme=https 安全守卫（accountUrl 理论已经过 parseArray 过滤, 这里是双保险）
    if(![url.scheme.lowercaseString isEqualToString:@"https"]) return nil;
    if(url.host.length == 0) return nil;
    return url;
}

- (void)startVerificationFromVC:(UIViewController *)fromVC {
    if(!fromVC) {
        WKLogError(@"[Realname] startVerificationFromVC called with nil VC");
        return;
    }

    // R3 / Jerry-Xin #112 warning: 区分「appconfig 仍在加载」vs「appconfig
    // 已加载但没下发 provider」。之前实现把两者都当「未配置」→ 首次冷启动 /
    // 慢网下看到错误 toast 但实际只是请求没回来。
    //
    // 新行为:
    //   - remoteConfig.requestSuccess == YES → 已加载完成, 走原判断逻辑
    //   - == NO → 显示 loading HUD, 调 [remoteConfig requestConfig:] 挂 callback
    //     等完成（队列化, 见 WKAppRemoteConfig.requestConfig: 注释）, 拿到结果后
    //     再走原判断。如果请求失败 → "网络不稳定" toast（不是"未配置"）。
    WKAppRemoteConfig *remoteConfig = [WKApp shared].remoteConfig;
    if(remoteConfig.requestSuccess) {
        [self _resolveProviderAndLaunchFromVC:fromVC];
        return;
    }

    WKLogInfo(@"[Realname] appconfig not loaded yet, waiting for requestConfig callback");
    [fromVC.view showHUD:LLang(@"加载中...")];
    __weak typeof(self) weakSelf = self;
    __weak typeof(fromVC) weakVC = fromVC;
    [remoteConfig requestConfig:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        __strong typeof(weakVC) strongVC = weakVC;
        if(!strongSelf || !strongVC) return;
        // VC 可能已经 pop / dismiss, 不应在空壳上弹 toast。
        if(strongVC.isBeingDismissed || strongVC.view.window == nil) {
            [strongVC.view hideHud];
            return;
        }
        [strongVC.view hideHud];
        if(error) {
            WKLogError(@"[Realname] requestConfig failed while starting realname verification: %@", error);
            [strongVC.view showMsg:LLang(@"网络不稳定，请稍后再试")];
            return;
        }
        [strongSelf _resolveProviderAndLaunchFromVC:strongVC];
    }];
}

/// 在 appconfig 已加载完成的前提下, 读 provider → 拼 URL → push App 私有网页容器。
/// 抽出来是为了 startVerificationFromVC: 的「已加载」与「加载后回调」两条路径
/// 共享同一套「拿不到可用 accountUrl / URL 拼坏」的 toast 兜底, 不让分支漂移。
- (void)_resolveProviderAndLaunchFromVC:(UIViewController *)fromVC {
    // : 从 appconfig.oidc_providers 里读 accountUrl; 未登录 / 无 provider /
    // provider 未配 accountUrl → 明确 toast, 不跳 prod 域。
    NSString *accountUrl = [WKRealnameVerifyManager primaryAegisAccountUrl];
    if(accountUrl.length == 0) {
        WKLogError(@"[Realname] no Aegis account_url from appconfig.oidc_providers; aborting");
        [fromVC.view showMsg:LLang(@"当前环境未配置实名认证入口，请联系管理员")];
        return;
    }

    NSURL *verifyURL = [WKRealnameVerifyManager buildVerifyURLFromAccountUrl:accountUrl];
    if(!verifyURL) {
        WKLogError(@"[Realname] failed to build Aegis verify URL from accountUrl=%@", accountUrl);
        [fromVC.view showMsg:LLang(@"实名认证地址不合法")];
        return;
    }

    // 用 App 私有 WKWebViewVC（与登录 SSO 页共享同一个 WKProcessPool / 默认
    // WKWebsiteDataStore）而不是 SFSafariViewController（系统 Safari 的 Cookie
    // 罐，与 App 内登录会话不共享）打开，这样 Aegis 账户页能看到 SSO 登录时
    // 建立的会话 Cookie，不会被误判成未登录再跳它自己的登录页。
    WKLogInfo(@"[Realname] opening Aegis account page: %@", verifyURL);
    WKWebViewVC *webVC = [WKWebViewVC new];
    webVC.url = verifyURL;
    s_realnameWebVC = webVC;
    s_realnameAnchorVC = fromVC;
    [[WKNavigationManager shared] pushViewController:webVC animated:YES];
}

@end
