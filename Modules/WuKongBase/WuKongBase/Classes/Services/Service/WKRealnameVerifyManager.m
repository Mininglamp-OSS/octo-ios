//
//  WKRealnameVerifyManager.m
//  WuKongBase
//

#import "WKRealnameVerifyManager.h"
#import <SafariServices/SafariServices.h>
#import "WuKongBase.h"   // LLang + 常用类（WKAPIClient / WKLoginInfo / WKApp / 常量）
#import <PromiseKit/PromiseKit.h>

NSString *const WKRealnameVerifiedURLScheme = @"dmwork";
NSString *const WKRealnameVerifiedURLHost   = @"verified";

// Universal Link 降级白名单 host（必须精确匹配，不允许子串）
static NSString *const WKRealnameUniversalLinkHost = @"accounts.example.com";
static NSString *const WKRealnameUniversalLinkPath = @"/verified";

@implementation WKRealnameVerifyManager

+ (instancetype)shared {
    static WKRealnameVerifyManager *_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

#pragma mark - Callback detection

+ (BOOL)isVerifiedCallbackURL:(NSURL *)url {
    if(!url) return NO;
    NSString *scheme = url.scheme.lowercaseString;
    NSString *host   = url.host.lowercaseString;
    // 主路径：自定义 scheme octo://verified
    if([scheme isEqualToString:WKRealnameVerifiedURLScheme] &&
       [host isEqualToString:WKRealnameVerifiedURLHost]) {
        return YES;
    }
    // 降级：支持标准 Universal Link https://accounts.example.com/verified
    // host 严格白名单 + path 精确匹配，禁止 `evil.com/x/verified` 子串绕过。
    if([scheme isEqualToString:@"https"] &&
       [host isEqualToString:WKRealnameUniversalLinkHost] &&
       [url.path isEqualToString:WKRealnameUniversalLinkPath]) {
        return YES;
    }
    return NO;
}

+ (void)handleVerifiedCallback:(NSURL *)url {
    WKLogInfo(@"[Realname] received verified callback: %@", url);

    // 先关闭可能在前台的 SFSafariViewController
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
        UIViewController *top = root;
        while(top.presentedViewController) { top = top.presentedViewController; }
        if([top isKindOfClass:[SFSafariViewController class]]) {
            [top dismissViewControllerAnimated:YES completion:nil];
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

- (void)startVerificationFromVC:(UIViewController *)fromVC {
    if(!fromVC) {
        WKLogError(@"[Realname] startVerificationFromVC called with nil VC");
        return;
    }

    // iOS 11+ 才有 SFSafariViewController 的 dismissButtonStyle 等能力，
    // iOS 14 以下对 3p cookie 的支持有限，但 SFSafariViewController 自 iOS 9 就可用，
    // 这里与后端 verify-service 的最低要求对齐：iOS 11+。
    if(@available(iOS 11.0, *)) {
        // OK
    } else {
        [fromVC.view showMsg:LLang(@"实名认证需要 iOS 11 及以上版本")];
        return;
    }

    NSDictionary *params = @{
        @"return_to": [NSString stringWithFormat:@"%@://%@",
                       WKRealnameVerifiedURLScheme, WKRealnameVerifiedURLHost]
    };

    __weak typeof(fromVC) weakVC = fromVC;
    [[WKAPIClient sharedClient] POST:@"internal/verify-token"
                          parameters:params].then(^(id responseObj){
        NSDictionary *data = [responseObj isKindOfClass:[NSDictionary class]] ? responseObj : @{};
        NSString *verifyURLStr = data[@"verify_url"];
        if(![verifyURLStr isKindOfClass:[NSString class]] || verifyURLStr.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakVC.view showMsg:LLang(@"获取实名认证地址失败")];
            });
            return nil;
        }
        NSURL *verifyURL = [NSURL URLWithString:verifyURLStr];
        // 安全：verify_url 来自服务端响应，防御后端被篡改后返回恶意 URL。
        // 要求 https 类型 + host 必须在白名单内（当前只允许 accounts.example.com）。
        if(!verifyURL ||
           ![verifyURL.scheme.lowercaseString isEqualToString:@"https"] ||
           ![verifyURL.host.lowercaseString isEqualToString:WKRealnameUniversalLinkHost]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakVC.view showMsg:LLang(@"实名认证地址不合法")];
            });
            return nil;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:verifyURL];
            if(@available(iOS 11.0, *)) {
                safari.dismissButtonStyle = SFSafariViewControllerDismissButtonStyleClose;
            }
            safari.modalPresentationStyle = UIModalPresentationFormSheet;
            [weakVC presentViewController:safari animated:YES completion:nil];
        });
        return nil;
    }).catch(^(NSError *error){
        WKLogError(@"[Realname] verify-token failed: %@", error);
        // error.domain 通常是 NSURLErrorDomain 等系统字符串，不适合展示给用户。
        NSString *msg = error.localizedDescription.length > 0
            ? error.localizedDescription
            : LLang(@"获取实名认证地址失败");
        // .catch 同样可能在后台线程，showMsg 会触发 UIKit，必须派送主线。
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakVC.view showMsg:msg];
        });
    });
}

@end
