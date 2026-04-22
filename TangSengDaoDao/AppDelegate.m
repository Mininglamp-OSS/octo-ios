//
//  AppDelegate.m
//  TangSengDaoDao
//
//  Created by tt on 2019/11/30.
//  Copyright © 2019 xinbida. All rights reserved.
//

#import "AppDelegate.h"
#import <WuKongBase/WuKongBase.h>
#import <WuKongBase/WKLocalNotificationManager.h>
#import "WKMainTabController.h"
@import WuKongContacts;
#import <WuKongBase/WKSyncService.h>
#import "WKMeVC.h"

#import "SELUpdateAlert.h"
#import "WKDBRepairViewController.h"
#import <WuKongIMSDK/WKDB.h>
#import <Bugly/Bugly.h>
#import <WebKit/WebKit.h>

#ifdef DEBUG
#import <DoraemonKit/DoraemonManager.h>
#endif


#define SERVER_IP [WKServerConfig serverIP]
#define HTTPS_ON [WKServerConfig httpsOn]


#define BASE_URL [NSString stringWithFormat:@"%@://%@/api/v1/",HTTPS_ON?@"https":@"http",SERVER_IP]
#define WEB_URL [NSString stringWithFormat:@"%@://%@/web/",HTTPS_ON?@"https":@"http",SERVER_IP]
// api基地址
#define API_BASE_URL  BASE_URL
// 文件基地址
#define FILE_BASE_URL BASE_URL
// 文件预览地址
#define FILE_BROWSE_URL BASE_URL
// 图片预览地址
#define IMAGE_BROWSE_URL BASE_URL

// 举报地址
#define REPORT_URL  [NSString stringWithFormat:@"%@://%@/web/report.html",HTTPS_ON?@"https":@"http",SERVER_IP]




@interface AppDelegate ()<UITabBarControllerDelegate>

@property(nonatomic,strong) WKConversationListVC *conversationList;
//@property(nonatomic,strong)  WKContactsVC *contactVC;
@property(nonatomic,strong) WKMeVC *meVC;


@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // 必须在 didFinishLaunchingWithOptions 返回前设置，否则冷启动点击通知无法触发回调
    [[WKLocalNotificationManager shared] registerAsNotificationDelegate];

    // 监听 IM 数据库健康检查失败，在 UI 就绪后呈现修复页面
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onIMDBHealthCheckFailed:)
                                                 name:WKIMDBHealthCheckFailedNotification
                                               object:nil];

    // DoKit 性能监控（仅 Debug 模式）
#ifdef DEBUG
    [[DoraemonManager shareInstance] installWithPid:@""];
#endif

    // Bugly 崩溃 + 卡顿采集
    BuglyConfig *buglyConfig = [[BuglyConfig alloc] init];
    buglyConfig.channel = @"TestFlight";
    buglyConfig.blockMonitorEnable = YES;       // 开启卡顿监控
    buglyConfig.blockMonitorTimeout = 1.0;      // 主线程卡顿超过 1 秒上报堆栈
    [Bugly startWithAppId:@"a66cf95f92" config:buglyConfig];

    // 预热 WKWebView：首次初始化会启动 WebKit 进程（~200-500ms），
    // 提前在启动时完成，后续聊天中表格渲染不再卡顿
    dispatch_async(dispatch_get_main_queue(), ^{
        WKWebView *warmup = [[WKWebView alloc] initWithFrame:CGRectZero];
        [warmup loadHTMLString:@"" baseURL:nil];
        // warmup 会被 ARC 自动释放，WebKit 进程保持运行
    });

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor grayColor];
    [self.window makeKeyAndVisible];

    // 加载登录信息
    [[WKApp shared].loginInfo load];
    // 设置 Bugly 用户标识（方便崩溃追踪）
    [self updateBuglyUserId];
    // 监听登录成功通知，及时更新 Bugly 用户标识
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLoginInfoSaved) name:@"WKLoginInfoDidSave" object:nil];

    // app配置
    WKAppConfig *config = [WKAppConfig new];
    config.apiBaseUrl = API_BASE_URL; // api地址
    config.fileBaseUrl = FILE_BASE_URL; // 文件上传地址
    config.fileBrowseUrl = FILE_BROWSE_URL; // 文件预览地址
    config.imageBrowseUrl = IMAGE_BROWSE_URL; // 图片预览地址
    config.reportUrl = [NSString stringWithFormat:@"%@report/html",API_BASE_URL]; //举报地址
    config.privacyAgreementUrl = [NSString stringWithFormat:@"%@privacy_policy.html",WEB_URL]; //隐私协议
    config.userAgreementUrl = [NSString stringWithFormat:@"%@user_agreement.html",WEB_URL]; //用户协议
    [WKApp shared].config = config;
    
    // app首页设置
    [WKApp shared].getHomeViewController = ^UIViewController * _Nonnull{
        WKMainTabController *homeViewController =  [WKMainTabController new];
        return homeViewController;
    };

   
    // app初始化
    [[WKApp shared] appInit];
    
    if (@available(iOS 13.0, *)) {
        if([WKApp shared].config.style == WKSystemStyleDark) {
            self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        }else{
            self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
        }
    }
   
    // 冷启动也检查版本更新
    [self checkAppVersionOrUpdate];

    return YES;
}

-(void) applicationWillEnterForeground:(UIApplication *)application {
    [self updateBuglyUserId];
    [self checkAppVersionOrUpdate];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    NSLog(@"内存警告");
}

-(void) checkAppVersionOrUpdate {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *appVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    NSString *appBuild = [infoDictionary objectForKey:@"CFBundleVersion"];
    [[WKAPIClient sharedClient] GET:[NSString stringWithFormat:@"common/appversion/iOS/%@",appVersion] parameters:nil].then(^(NSDictionary *resultDict){
        NSString *rawVersion = resultDict[@"app_version"];
        if(!rawVersion || [rawVersion isEqualToString:@""]) {
            return;
        }

        // 解析服务端版本：支持 "1.0.0(28)"、"1.0.0" 两种格式
        NSString *remoteVersion = rawVersion;
        NSString *remoteBuild = @"";
        NSRange parenRange = [rawVersion rangeOfString:@"("];
        if (parenRange.location != NSNotFound) {
            remoteVersion = [rawVersion substringToIndex:parenRange.location];
            NSRange endRange = [rawVersion rangeOfString:@")"];
            if (endRange.location != NSNotFound && endRange.location > parenRange.location) {
                remoteBuild = [rawVersion substringWithRange:NSMakeRange(parenRange.location + 1, endRange.location - parenRange.location - 1)];
            }
        }

        // 先比较版本号
        BOOL needUpdate = NO;
        NSInteger remoteVer = [self versionStrToInt:remoteVersion];
        NSInteger localVer = [self versionStrToInt:appVersion];
        if (remoteVer > localVer) {
            needUpdate = YES;
        } else if (remoteVer == localVer && remoteBuild.length > 0 && appBuild.length > 0) {
            // 版本号相同，比较 build 号
            if ([remoteBuild integerValue] > [appBuild integerValue]) {
                needUpdate = YES;
            }
        }

        if (needUpdate) {
            NSString *updateDesc = resultDict[@"update_desc"];
            BOOL isForce = resultDict[@"is_force"] ? [resultDict[@"is_force"] boolValue] : NO;
            NSString *downloadURL = resultDict[@"download_url"];
            [SELUpdateAlert showUpdateAlertWithVersion:rawVersion Description:updateDesc downloadURL:downloadURL forceUpdate:isForce];
        }
    });
}

/// 版本号转整数：1.0.0 → 10000, 1.0.1 → 10001, 1.2.3 → 10203（每段补两位）
-(NSInteger) versionStrToInt:(NSString*)versionStr {
    NSArray *parts = [versionStr componentsSeparatedByString:@"."];
    NSInteger result = 0;
    for (NSInteger i = 0; i < parts.count && i < 3; i++) {
        result = result * 100 + [parts[i] integerValue];
    }
    // 不足3段补齐
    for (NSInteger i = parts.count; i < 3; i++) {
        result = result * 100;
    }
    return result;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    if (!deviceToken || ![deviceToken isKindOfClass:[NSData class]] || deviceToken.length==0) {
        return;
    }
    NSString *(^getDeviceToken)(void) = ^() {
            if (@available(iOS 13.0, *)) {
                const unsigned char *dataBuffer = (const unsigned char *)deviceToken.bytes;
                NSMutableString *myToken  = [NSMutableString stringWithCapacity:(deviceToken.length * 2)];
                for (int i = 0; i < deviceToken.length; i++) {
                    [myToken appendFormat:@"%02x", dataBuffer[i]];
                }
                return (NSString *)[myToken copy];
            } else {
                NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:@"<>"];
                NSString *myToken = [[deviceToken description] stringByTrimmingCharactersInSet:characterSet];
                return [myToken stringByReplacingOccurrencesOfString:@" " withString:@""];
            }
        };
    NSString *myToken = getDeviceToken();
    NSLog(@"myToken----------->%@",myToken);
    [WKApp shared].loginInfo.deviceToken = myToken;
    [[WKApp shared].loginInfo save];
   NSString *bundleID = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    [[WKAPIClient sharedClient] POST:@"user/device_token" parameters:@{@"device_token":myToken,@"device_type":@"IOS",@"bundle_id":bundleID}].catch(^(NSError *error){
        WKLogError(@"上传设备token失败！-> %@",error);
    });
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    NSLog(@"didReceiveRemoteNotification------>");
    [WKApp.shared application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
}


- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    WKLogError(@"注册远程通知失败->%@",error);
}
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    
    return [[WKApp shared] appOpenURL:url options:options];
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    
    return [[WKApp shared] appContinueUserActivity:userActivity restorationHandler:restorationHandler];
}

/// 登录成功后立即更新 Bugly 用户标识（参考 Android LoginModel）
- (void)onLoginInfoSaved {
    [self updateBuglyUserId];
}

/// IM 数据库健康检查失败 → 弹确认 Alert → 进入修复页面
- (void)onIMDBHealthCheckFailed:(NSNotification *)notification {
    NSString *imDBPath = notification.userInfo[@"imDBPath"] ?: @"";
    NSString *uid      = notification.userInfo[@"uid"] ?: @"";

    // 等待根 VC 就绪（switchDB 发生在 appInit 内，此时 window 刚建立）
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"数据库损坏"
            message:@"本地数据库无法读取，历史消息暂时不可见。\n点击「立即修复」将自动清空重建，消息可在修复后从服务器同步恢复。"
            preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"立即修复"
                                                 style:UIAlertActionStyleDestructive
                                               handler:^(UIAlertAction *action) {
            [self presentRepairVCWithIMDBPath:imDBPath uid:uid];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"稍后再说"
                                                 style:UIAlertActionStyleCancel
                                               handler:nil]];

        UIViewController *rootVC = self.window.rootViewController;
        // 如果已有弹窗在展示，找到最顶层再 present
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

- (void)presentRepairVCWithIMDBPath:(NSString *)imDBPath uid:(NSString *)uid {
    WKDBRepairViewController *repairVC = [WKDBRepairViewController new];
    repairVC.imDBPath = imDBPath;
    repairVC.uid      = uid;
    repairVC.modalPresentationStyle = UIModalPresentationFullScreen;
    repairVC.modalTransitionStyle   = UIModalTransitionStyleCrossDissolve;

    UIViewController *rootVC = self.window.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    [rootVC presentViewController:repairVC animated:YES completion:nil];
}

/// 设置 Bugly 用户标识（参考 Android WKBaseApplication + LoginModel）
- (void)updateBuglyUserId {
    NSString *shortNo = [WKApp shared].loginInfo.extra[@"short_no"];
    NSString *uid = [WKApp shared].loginInfo.uid;
    NSString *name = [WKApp shared].loginInfo.extra[@"name"];

    // userId：优先 short_no（Octo 号），fallback uid
    if (shortNo.length > 0) {
        [Bugly setUserIdentifier:shortNo];
    } else if (uid.length > 0) {
        [Bugly setUserIdentifier:uid];
    }
    // 附加字段
    if (uid.length > 0) {
        [Bugly setUserValue:uid forKey:@"uid"];
    }
    if (name.length > 0) {
        [Bugly setUserValue:name forKey:@"name"];
    }
}

@end

