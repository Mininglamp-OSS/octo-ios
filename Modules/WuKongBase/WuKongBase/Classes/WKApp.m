//
//  WKApp.m
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//
#import <UserNotifications/UserNotifications.h>
#import <WebKit/WebKit.h>
#import <ImageIO/ImageIO.h>

#import "WKApp.h"
#import "WKEndpointManager.h"
#import "WKModuleManager.h"
#import "WKConstant.h"
#import "WKConversationVC.h"
#import "WKNavigationManager.h"
#import "WKLocalNotificationManager.h"
#import "WKRealnameVerifyManager.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKMessageRegistry.h"
#import "WKTextMessageCell.h"
#import "WKEmojiPanel.h"
#import "WKMorePanel2.h"
#import "WKUnkownMessageCell.h"
#import "WKMoreItemModel.h"
#import "WKResource.h"
#import "WKMoreItemClickEvent.h"
#import "WKImageMessageCell.h"
#import "WKConversationContext.h"
#import "WKSpaceFilter.h"
#import "WKVoicePanel.h"
#import "WKVoiceMessageCell.h"
#import "WKGroupManager.h"
#import "WKSystemMessageCell.h"
#import "WKConversationPersonSettingVC.h"
#import "WKConversationGroupSettingVC.h"
#import "WKContactsSelectVC.h"
#import "WKMessageManager.h"
#import "WKEmojiContentView.h"
#import "WKStickerGIFContentView.h"
#import "WKGIFMessageCell.h"
#import "WKGIFContent.h"
#import "WKForwardSelectVC.h"
#import "WKSyncService.h"
#import "WKSpaceModel.h"
#import "WKSpaceConvSyncCache.h"
#import "WKNavigationManager.h"
#import "WKPanelDefaultFuncItem.h"
#import "WKScanVC.h"
#import "WKWebViewVC.h"
#import "WKCardContent.h"
#import "WKCardCell.h"
#import "WKRichTextContent.h"
#import "WKRichTextCell.h"
#import "WKUserInfoVC.h"
#import "WKMeInfoVC.h"
#import "WKMeItem.h"
#import "WKMePushSettingVC.h"
#import "WKCommonSettingVC.h"
#import "WKNetworkListener.h"
#import "WKTypingMessageCell.h"
#import "WKTypingContent.h"
#import "WKOnlineStatusManager.h"
#import "WKTypingManager.h"
#import "WKHistorySplitTipCell.h"
#import "WKHistorySplitTipContent.h"
#import "WKMergeForwardContent.h"
#import "WKMergeForwardCell.h"
#import "WKGroupScanJoinVC.h"
#import "WKScreenshotCell.h"
#import "WKScreenshotContent.h"
#import "WKThreadCreatedCell.h"
#import "WKThreadCreatedContent.h"
#import "WKThreadService.h"
#import "WKThreadModel.h"
#import "WKThreadSettingVC.h"
#import "WKConversationAddItem.h"
#import "WKConversationContext.h"
#import <SDWebImageWebPCoder/SDWebImageWebPCoder.h>
#import "WKScreenPasswordVC.h"
#import "WKScreenProtectionView.h"
#import "WKMySettingManager.h"
#import "WKConversationPosition.h"
#import "WKWebClientInfoVC.h"
#import "WKLottieStickerCell.h"
#import "WKLottieStickerContent.h"
#import <SDWebImageLottieCoder/SDWebImageLottieCoder.h>
#import "WKAnimatedImageCoders.h"
#import "WKEndToEndEncryptHitContent.h"
#import "WKEndToEndEncryptHitCell.h"
#import "WKSignalErrorCell.h"
#import <WuKongIMSDK/WKSignalErrorContent.h>
#import "WKEmojiStickerCell.h"
#import "WKEmojiStickerContent.h"
#import "WKFileMessageCell.h"
#import <WuKongIMSDK/WKFileContent.h>
#import "WKSDImageLottieCoder.h"
#import "WKSecurityTipManager.h"
#import "WKConversationListVM.h"
#import <WuKongBase/WuKongBase-Swift.h>
#import "WKStickerCollectionVC.h"
#import "WKKeyboardService.h"
#import <ZLPhotoBrowser/ZLPhotoBrowser-Swift.h>
#import "WKSDWebImageDownloaderOperation.h"
// Bugly (腾讯崩溃统计) 是闭源 SDK。开源版默认禁用，启用方式见 AppDelegate.m 头部说明。
#ifdef OCTO_ENABLE_BUGLY
#import <Bugly/Bugly.h>
#endif
#import "WKMyInviteCodeVC.h"
#import "WKProhibitwordsService.h"
// #import "WKANRWatchdog.h"  // Disabled: 调试期完成使命，见 CLAUDE.md

@import FPSCounter.Swift;
//#import <PINRemoteImage/PINImageView+PINRemoteImage.h>
//#import <PINRemoteImage/PINRemoteImageCaching.h>
typedef void(^WKOnComplete)(id data,NSError *error);



@interface WKApp ()<WKNetworkListenerDelegate,WKConnectionManagerDelegate>

// 图文混排（RichText=14）发送私有方法（在 sendShareFiles: 之后定义，此处前置声明）。
-(void) sendRichTextMixedImages:(NSArray *)fileInfos extraText:(NSString *)extraText toChannel:(WKChannel *)channel;
// 上传核心：cleanup 在成功/失败终态都会执行，由调用方决定清理对象（分享目录 / 临时文件）；
// onFailure 仅在失败终态主线程回调（用于恢复输入框草稿等）；send 由调用方注入「内容就绪后
// 如何发送 + 插入列表」——分享入口走 forwardMessage:（无会话上下文），主聊天相册入口走
// [context sendMessage:]（保留回执/阅后即焚/spaceId/topic/reply/tracing/列表插入等全部会话语义）。
-(void) sendRichTextMixedImages:(NSArray *)fileInfos extraText:(NSString *)extraText toChannel:(WKChannel *)channel cleanup:(void(^_Nullable)(void))cleanup onFailure:(void(^_Nullable)(void))onFailure send:(void(^)(WKRichTextContent *content))send;
- (NSString *)richTextMimeForExtension:(NSString *)ext;
+ (NSString *)wk_richTextPlainTextOnly:(WKRichTextContent *)content;

/**
 *  用来存储所有添加j过的delegate
 *  NSHashTable 与 NSMutableSet相似，但NSHashTable可以持有元素的弱引用，而且在对象被销毁后能正确地将其移除。
 */
@property (strong, nonatomic) NSHashTable  *delegates;
/**
 *  delegateLock 用于给delegate的操作加锁，防止多线程同时调用
 */
@property (strong, nonatomic) NSLock  *delegateLock;

@property(nonatomic,strong) NSMutableArray<NSString*> *allowForwards; // 允许转发的消息类型集合
@property(nonatomic,strong) NSMutableArray<NSString*> *allowCopys; // 允许复制的消息类型集合
@property(nonatomic,strong) NSMutableArray<NSString*> *allowFavorites; // 允许收藏的消息类型集合

@property(nonatomic,assign) BOOL isShowLockScreenProtect; // 是否显示了锁屏密码
@property(nonatomic,assign) BOOL isShowScreenProtect; // 是否显示屏幕保护
@property(nonatomic,strong) WKScreenProtectionView *screenProtectionView; // 屏幕保护view



@end

@implementation WKApp

static WKApp *_instance;


+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKApp *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        
    });
    return _instance;
}

- (WKAppConfig *)config {
    if(!_config) {
        _config = [[WKAppConfig alloc] init];
    }
    return _config;
}

- (WKAppRemoteConfig *)remoteConfig {
    if(!_remoteConfig) {
        _remoteConfig = [[WKAppRemoteConfig alloc] init];
    }
    if(!_remoteConfig.requestSuccess || !_remoteConfig.requestAppModuleSuccess) {
        [_remoteConfig requestConfig:nil];
    }
    return _remoteConfig;
}

-(void) addNotifies {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    
    // 录屏
    if (@available(iOS 11.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenCapturedDidChange) name:UIScreenCapturedDidChangeNotification object:nil];
        
    }
    
}

- (void)dealloc { // 这里虽然不会执行，还是写上
    [[WKSDK shared].connectionManager removeDelegate:self];
    [[WKNetworkListener shared] removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    if (@available(iOS 11.0, *)) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIScreenCapturedDidChangeNotification object:nil];
    }
}

-(void) appDidReceiveMemoryWarning {
    WKLogWarn(@"内存警告------->");
    // 清空图片缓存
    [[SDImageCache sharedImageCache] clearMemory];
}

-(void) configSDWebImage {

    // webp格式支持
    SDImageWebPCoder *webPCoder = [SDImageWebPCoder sharedCoder];
    [[SDImageCodersManager sharedManager] addCoder:webPCoder];

    // lottie支持
    [[SDImageCodersManager sharedManager] addCoder:WKSDImageLottieCoder.sharedCoder];

    // GIF / APNG 延时矫正——继承官方 coder，仅把 ≤ 20ms 的"快帧" delay 强制到 100ms，
    // 对齐 Photos.app / Safari / 微信。否则 SDAnimatedImageView 会真按 20-30ms
    // 原始 delay 播，看起来比别处快 1-2 倍。详见 WKAnimatedImageCoders.h 注释。
    // SDImageCodersManager 按 reverseObjectEnumerator 匹配，越晚 addCoder 优先级越高。
    [[SDImageCodersManager sharedManager] addCoder:WKImageAPNGCoder.sharedCoder];
    [[SDImageCodersManager sharedManager] addCoder:WKImageGIFCoder.sharedCoder];
    
    [SDImageCacheConfig defaultCacheConfig].maxMemoryCost = 400 * 1024 * 1024; // 400M
    
    SDWebImageDownloader.sharedDownloader.config.operationClass = WKSDWebImageDownloaderOperation.class;
    
}

-(void) registerMessages {
    // 注册消息
    [self.messageRegitry registerCellClass:[WKTextMessageCell class] forMessageContentClass:[WKTextContent class]]; // 文本
    [self.messageRegitry registerCellClass:[WKUnkownMessageCell class] forMessageContentClass:[WKUnknownContent class]]; // 未知消息
    [self.messageRegitry registerCellClass:[WKImageMessageCell class] forMessageContentClass:[WKImageContent class]]; // 图片消息
    [self.messageRegitry registerCellClass:[WKVoiceMessageCell class] forMessageContentClass:[WKVoiceContent class]]; // 语音消息
//    [self.messageRegitry registerCellClass:[WKSystemMessageCell class] forMessageContentClass:[WKSystemContent class]]; // 系统消息
    [self.messageRegitry registerCellClass:[WKGIFMessageCell class] forMessageContentClass:[WKGIFContent class]]; // GIF消息
    [self.messageRegitry registerCellClass:[WKCardCell class] forMessageContentClass:[WKCardContent class]]; // 名片消息
     [self.messageRegitry registerCellClass:[WKTypingMessageCell class] forMessageContentClass:[WKTypingContent class]]; // 输入中...
    [self.messageRegitry registerCellClass:WKMergeForwardCell.class forMessageContentClass:WKMergeForwardContent.class];
    // 历史消息分割线
    [self.messageRegitry registerCellClass:[WKHistorySplitTipCell class] forMessageContentClass:[WKHistorySplitTipContent class]];
    [self.messageRegitry registerCellClass:[WKEndToEndEncryptHitCell class] forMessageContentClass:[WKEndToEndEncryptHitContent class]]; // 端对端加密提示
    [self.messageRegitry registerCellClass:[WKSignalErrorCell class] forMessageContentClass:[WKSignalErrorContent class]]; // 解密失败
    [self.messageRegitry registerCellClass:WKScreenshotCell.class forMessageContentClass:WKScreenshotContent.class]; // 截屏通知
    [self.messageRegitry registerCellClass:WKLottieStickerCell.class forMessageContentClass:WKLottieStickerContent.class]; // lottie格式的贴图
    [self.messageRegitry registerCellClass:WKEmojiStickerCell.class forMessageContentClass:WKEmojiStickerContent.class];
    [self.messageRegitry registerCellClass:[WKFileMessageCell class] forMessageContentClass:[WKFileContent class]]; // 文件消息
    [self.messageRegitry registerCellClass:[WKThreadCreatedCell class] forMessageContentClass:[WKThreadCreatedContent class]]; // 子区创建通知
    [self.messageRegitry registerCellClass:[WKRichTextCell class] forMessageContentClass:[WKRichTextContent class]]; // 图文混排（RichText=14）
}

-(void) traceConfig {
#ifdef OCTO_ENABLE_BUGLY
    // Bugly 是进程级单例: 主 App 在 didFinishLaunching 已经
    // [Bugly startWithAppId:OCTOBuglyAppIdMain] 启动过, 这里**不要**
    // 再 startWithAppId — 否则后调的会覆盖 AppID, 把崩溃从 Main 项目
    // (OCTOBuglyAppIdMain) 改报到 SDK 项目 (OCTOBuglyAppIdSDK), 后台
    // Main 看板就会从那一刻起看不到对应版本了 (build 59 → build 62
    // 期间观察到这个症状).
    //
    // 历史上加 OCTOBuglyAppIdSDK 是想让 SDK 内部崩溃单独报到一个独立
    // 看板, 但 Bugly 单例机制下"两 AppID 并存"做不到. 这里只同步用户
    // 标识就够了, 让所有崩溃统一汇到 Main 看板.
    if ([WKApp shared].isLogined) {
        [Bugly setUserIdentifier:[WKApp shared].loginInfo.uid];
    }
#endif
}

-(void) debugSetting {
#ifndef __OPTIMIZE__ // DEBUG模式
    [FPSCounter showInStatusBarWithApplication:[UIApplication sharedApplication] runloop:NSRunLoop.mainRunLoop mode:NSRunLoopCommonModes];
#else
    
#endif
}

-(BOOL) appOpenURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    // 处理 Share Extension 跳转：跨进程 URL 走 `<OCTO_URL_SCHEME>://share`
    // (与实名回跳同 scheme，通过 host 区分入口)。scheme 由 OctoConfig.xcconfig
    // 的 OCTO_URL_SCHEME 决定，默认 `octo`。历史上写死 `botgate`，
    // 见 PR #121 Allen review 🟡 #2。
    if ([url.scheme isEqualToString:WKRealnameVerifiedURLScheme] && [url.host isEqualToString:@"share"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self handleShareExtensionData];
        });
        return YES;
    }
    // 实名认证回跳 <OCTO_URL_SCHEME>://verified
    if([WKRealnameVerifyManager isVerifiedCallbackURL:url]) {
        [WKRealnameVerifyManager handleVerifiedCallback:url];
        return YES;
    }
    return [[WKSwiftModuleManager shared] didOpen:url options:options];
}

-(BOOL) appContinueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    // 实名认证回跳不走 Universal Link (Round 2 / blocking 2):
    // Aegis return_to 统一走 `<scheme>://verified` 自定义 scheme (由
    // appDidOpenURL:options: 处理), 本入口不再识别 Aegis host 的 web URL。
    // 调用 isVerifiedCallbackURL: 仍然保留做防御（万一老版本 Aegis 回跳
    // 仍下发 https）, 但该方法现在只认 dmwork:// scheme, 对 web URL 永远返 NO。
    if([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        NSURL *url = userActivity.webpageURL;
        if([WKRealnameVerifyManager isVerifiedCallbackURL:url]) {
            [WKRealnameVerifyManager handleVerifiedCallback:url];
            return YES;
        }
    }
    return [[WKSwiftModuleManager shared] didContinue:userActivity restorationHandler:restorationHandler];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    
    [WKSwiftModuleManager.shared moduleDidReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
    
    
}

-(void) appInit {
    
    // 配置api
    [self configApi];
    
    if([self.config.langue isEqualToString:@"zh-Hans"]) {
        [ZLPhotoUIConfiguration default].languageType = ZLLanguageTypeChineseSimplified;
    }else{
        [ZLPhotoUIConfiguration default].languageType = ZLLanguageTypeEnglish;
    }
    
    [WKKeyboardService.shared setup];
    [WKSwiftModuleManager.shared didModuleInit];
//    [WKModuleManager.shared didModuleInit]; // 模块初始化
    
//    [self debugSetting];
    
    [self traceConfig];
  
    [self configSDWebImage];

    [self addNotifies];
    
   
    [[WKNetworkListener shared] addDelegate:self];
    // 开启网络监听
    [[WKNetworkListener shared] start];
    // Disabled: ANR 主线程卡死检测 (调试工具，见 CLAUDE.md)
    // [[WKANRWatchdog shared] startWithThreshold:3.0];
    // 初始化日志
    [WKLogsManager setup:nil];
    
    // 加载登录信息
    [[WKApp shared].loginInfo load];
    
    
    // 开始处理系统消息
    [[WKSystemMessageHandler shared] handle];
    
    // 初始化系统的point
    [self initPointMethods];
    // 注册自定义消息
    [self registerMessages];
    
    // 配置IM SDK
    [WKSDK shared].connectURL =self.config.connectURL;
    
    WKSDK.shared.options.syncChannelMessageLimit = [WKApp shared].config.eachPageMsgLimit;
    
    // 设置IM连接信息回调（当IM需要取连接信息时会调用此方法）
    __weak typeof(self) weakSelf = self;
    [[WKSDK shared].options setConnectInfoCallback:^WKConnectInfo * _Nonnull{
        WKConnectInfo *connectInfo = [WKConnectInfo new];
        connectInfo.uid = weakSelf.loginInfo.uid;
        connectInfo.token = weakSelf.loginInfo.imToken;
        return  connectInfo;
    }];

    [[WKSDK shared].connectionManager addDelegate:self];
    // 设置连接地址
    if([WKApp shared].config.clusterOn) {
       [[WKSDK shared].connectionManager setGetConnectAddr:^(void (^ _Nonnull complete)(NSString * __nullable)) {
           [[WKAPIClient sharedClient] GET:[NSString stringWithFormat:@"users/%@/im",weakSelf.loginInfo.uid] parameters:nil].then(^(NSDictionary *addrDict){
               if(!addrDict) {
                   complete(nil);
                   return;
               }
               // 客户端只走 WebSocket（TCP 已下线）。
               // 地址优先级：wss_addr > ws_addr。其他地址字段（如旧的 TCP 地址）一律忽略。
               NSString *addr = nil;
               id wssAddr = addrDict[@"wss_addr"];
               if ([wssAddr isKindOfClass:[NSString class]] && ((NSString *)wssAddr).length > 0) {
                   addr = wssAddr;
               } else {
                   id wsAddr = addrDict[@"ws_addr"];
                   if ([wsAddr isKindOfClass:[NSString class]] && ((NSString *)wsAddr).length > 0) {
                       addr = wsAddr;
                   }
               }
               complete(addr.length > 0 ? addr : nil);

           }).catch(^(NSError *error){
               complete(nil);
               WKLogError(@"获取IM连接地址失败！-> %@",error);
           });
       }];
    }
   
    // 设置登录成功回调
    [self setMethod:WKPOINT_LOGIN_SUCCESS handler:^id _Nullable(id  _Nonnull param) {
        // 切换数据库
        [[WKKitDB shared] switchDB:[WKApp shared].loginInfo.uid];

        // Defense-in-depth: 清掉上一次登录可能残留的 conv-sync space 内存缓存。
        // 主清理路径在 logout，这里再清一次防止异常退出 / kill app 后切账号读到旧用户数据。
        // key 是 channelId-channelType 不含 UID，必须在新账号 sync 前归零。
        [[WKSpaceConvSyncCache shared] clearAll];

        // 重新加载最近会话保持的位置
        [[WKConversationPositionManager shared] reload];

        // 显示首页
        if(weakSelf.getHomeViewController) {
            [[WKNavigationManager shared] resetRootViewController:weakSelf.getHomeViewController()];
        }

        // 同步联系人
        [[WKSyncService shared] sync:^(NSError * _Nonnull error) {
            // 更新频道在线状态，如果需要
            [WKOnlineStatusManager shared].needUpdate = YES;
            [[WKOnlineStatusManager shared] requestUpdateChannelOnlineStatusIfNeed];
            // 连接到IM
            [[[WKSDK shared] connectionManager] connect];
        }];
        // 注册远程通知
       [weakSelf registerForNotification];
        
        // 调用登录成功的委托
        [weakSelf callAppLoginSuccessDelegate];
        
        // 同步安全提醒敏感词
        [[WKSecurityTipManager shared] syncIfNeed];
        
        [weakSelf enterApp];
        
        return nil;
    }];
    
    
    // 设置登出回调
    [[WKApp shared] setMethod:WKPOINT_LOGIN_LOGOUT handler:^id _Nullable(id  _Nonnull param) {
        // 断开IM连接
        [[WKSDK shared].connectionManager logout];

        // 清除 Space 相关数据
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentSpaceId"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WKSpaceGateCompleted"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[WKSpaceModel shared] invalidateCache];

        // 清掉 conv-sync 内存里的 space_id / my_source_space_id 缓存。
        // 该 cache 是 singleton, key 不含 UID, 不清的话下个账号登录后
        // 同 channelId-channelType 会读到上一个用户的 Space 数据 (跨登录泄漏)。
        [[WKSpaceConvSyncCache shared] clearAll];

        // 显示登录页面
        [[WKApp shared] invoke:WKPOINT_LOGIN_SHOW param:nil];

        weakSelf.isShowScreenProtect = false;
        weakSelf.isShowLockScreenProtect = false;

        // 调用登出的委托
        [self callAppLogoutDelegate];
        return nil;
    }];
    
    if([WKApp shared].isLogined) {
        // 检查是否有已加入的空间
        NSString *cachedSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
        BOOL spaceGateCompleted = [[NSUserDefaults standardUserDefaults] boolForKey:@"WKSpaceGateCompleted"];

        if(cachedSpaceId && cachedSpaceId.length > 0 && spaceGateCompleted) {
            // 有空间且已完成引导，正常进入主页
            [[WKKitDB shared] switchDB:[WKApp shared].loginInfo.uid];
            if(weakSelf.getHomeViewController) {
                [[WKNavigationManager shared] resetRootViewController:weakSelf.getHomeViewController()];
            }
            [[WKSyncService shared] sync];
            [self enterApp];
            [self registerForNotification];
            [[[WKSDK shared] connectionManager] connect];
            [[WKSecurityTipManager shared] syncIfNeed];
        } else {
            // 没有空间或未完成引导：清除登录信息，回到登录页
            // 登录时会通过 space/my 判断是否需要显示空间引导
            [[WKLoginInfo shared] clear];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentSpaceId"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WKSpaceGateCompleted"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[WKApp shared] invoke:WKPOINT_LOGIN_SHOW param:nil];
        }
    }else {
        [[WKApp shared] invoke:WKPOINT_LOGIN_SHOW param:nil];
    }

    // 模块启动...
    [[WKSwiftModuleManager shared] didFinishLaunching];
    WKLogDebug(@"=====> 程序启动！<=====");
    if(![AFNetworkReachabilityManager sharedManager].reachable) {
        [self showScreenProtectIfNeed]; // 显示断网屏幕保护
    }
   
    [self showLockScreenProtectIfNeed];
    
    [self remoteConfig]; // 获取下远程配置
    
    // 收藏的表情加载
    [self loadCollectStickersIfNeed];
    
    // 图片换成key设置
//    [[SDWebImageManager sharedManager] setCacheKeyFilter:[[SDWebImageCacheKeyFilter alloc] initWithBlock:^NSString * _Nullable(NSURL * _Nonnull url) {
//        return [url absoluteString];
//    }]];
}

// 进入app
-(void) enterApp {
    [WKAPIClient.sharedClient GET:[NSString stringWithFormat:@"user/devices/%@",[UIDevice getUUID]] parameters:nil].then(^(NSDictionary *result){
        NSLog(@"result---->%@",result);
        if(result && result[@"id"]) {
            [WKSDK.shared.options setClientMsgDeviceId: [result[@"id"] integerValue]];
        }
    });
}

- (void)registerForNotification {
    UIUserNotificationType types =
    (UIUserNotificationTypeAlert | UIUserNotificationTypeSound |
     UIUserNotificationTypeBadge);
    UIUserNotificationSettings *settings;
    settings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    // 注册本地通知点击处理
    [[WKLocalNotificationManager shared] registerAsNotificationDelegate];

    if (@available(iOS 11.0, *)) {
        UNUserNotificationCenter *center =
        [UNUserNotificationCenter currentNotificationCenter];
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionBadge |
                                                 UNAuthorizationOptionSound |
                                                 UNAuthorizationOptionAlert)
                              completionHandler:^(BOOL granted,
                                                  NSError *_Nullable error) {
                                  if (!granted) {
                                      //                [[UIApplication
                                      //                sharedApplication].keyWindow
                                      //                makeToast:@"请开启推送功能否则无法收到推送通知"
                                      //                duration:0.5
                                      //                position:CSToastPositionCenter];
                                  }
                              }];
    } else if ([[[UIDevice currentDevice] systemVersion] doubleValue] >= 10) {
        if (@available(iOS 10.0, *)) {
            UNUserNotificationCenter *center =
            [UNUserNotificationCenter currentNotificationCenter];
            [center requestAuthorizationWithOptions:UNAuthorizationOptionCarPlay |
            UNAuthorizationOptionSound |
            UNAuthorizationOptionBadge |
            UNAuthorizationOptionAlert
                                 completionHandler:^(BOOL granted,
                                                     NSError *_Nullable error) {
                                     if (granted) {
                                         WKLogDebug(@" iOS 10 request notification success");
                                     } else {
                                         WKLogDebug(@" iOS 10 request notification fail");
                                     }
                                 }];
        } else {
            // Fallback on earlier versions
        }
        
    } else if ([[[UIDevice currentDevice] systemVersion] doubleValue] > 7.99) {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings
                                                settingsForTypes:UIUserNotificationTypeSound |
                                                UIUserNotificationTypeBadge |
                                                UIUserNotificationTypeAlert
                                                categories:nil];
        [[UIApplication sharedApplication]
         registerUserNotificationSettings:settings];
        //        UIUserNotificationSettings* notificationSettings =
        //        [UIUserNotificationSettings
        //        settingsForTypes:UIUserNotificationTypeAlert |
        //        UIUserNotificationTypeBadge | UIUserNotificationTypeSound
        //        categories:nil];
        //        [[UIApplication sharedApplication]
        //        registerUserNotificationSettings:notificationSettings];
    } else {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings
                                                settingsForTypes:UIUserNotificationTypeSound |
                                                UIUserNotificationTypeBadge |
                                                UIUserNotificationTypeAlert
                                                categories:nil];
        [[UIApplication sharedApplication]
         registerUserNotificationSettings:settings];
    }
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}


// api 配置
-(void) configApi{
    WKAPIClientConfig *config = [[WKAPIClientConfig alloc] init];
    [config setBaseUrl:self.config.apiBaseUrl];
    // http公用头部
    [config setPublicHeaderBLock:^NSDictionary *{
        NSMutableDictionary *header = [NSMutableDictionary dictionary];
        [header setObject:[self config].bundleID forKey:@"bundle_id"];
        if([WKApp shared].isLogined) {
            [header setObject:[WKApp shared].loginInfo.token forKey:@"token"];
        }
        // X-Space-Id header — 动态注入（对齐 dmwork-web PR #1039）
        // 每次请求都读 WKSpaceFilter.currentSpaceId，Space 切换立即生效。
        // 空值时以空字串标记，由 WKAPIClient resetPublicHeader 负责移除 stale header。
        NSString *currentSpaceId = [[WKSpaceFilter shared] currentSpaceId];
        [header setObject:(currentSpaceId.length > 0 ? currentSpaceId : @"") forKey:@"X-Space-Id"];
        return  header;

    }];
    // 路径替换
    [config setRequestPathReplace:^NSString *(NSString *requestPath) {
        if([WKApp shared].isLogined) {
            return [requestPath stringByReplacingOccurrencesOfString:@"{uid}" withString:[WKApp shared].loginInfo.uid];
        }
        return requestPath;
        
    }];
    // 统一错误处理
    [config setErrorHandler:^NSError *(id respObj, NSError *error) {
        if(error) {
            NSHTTPURLResponse *response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
            if(response && response.statusCode == 401 && [WKApp shared].isLogined) { // 401表示token失效，跳转到登录页面
                WKLogWarn(@"401token失效，跳转到登录页面");
                [[WKApp shared] immediatelyLogout];

            }else {
                NSData *errorData =  error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
                if(errorData) {
                    WKLogError(@"error->%@",[[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding]);
                }
                
                if(response.statusCode == 400) {
                    if(errorData) {
                        NSDictionary *errorDic = [NSJSONSerialization JSONObjectWithData:errorData options:NSJSONReadingMutableLeaves error:nil];
                        if(errorDic) {
                            return [NSError errorWithDomain:errorDic[@"msg"] code:[errorDic[@"status"] integerValue] userInfo:errorDic];
                        }
                    }else {
                        return [NSError errorWithDomain:error.localizedDescription code:error.code userInfo:error.userInfo];
                    }
                }else {
                    return [NSError errorWithDomain:[[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] code:error.code userInfo:error.userInfo];
                }
                
            }
        }
        return nil;
    }];
    [[WKAPIClient sharedClient] setConfig:config];
    
}

- (WKEndpointManager *)endpointManager {
    if(!_endpointManager) {
        _endpointManager = [WKEndpointManager new];
    }
    return _endpointManager;
}

- (SDImageCache *)imageCache {
    if(!_imageCache) {
        SDImageCacheConfig *config = SDImageCacheConfig.defaultCacheConfig;
        
        _imageCache = [[SDImageCache alloc] initWithNamespace:@"" diskCacheDirectory:self.config.imageCacheDir config:config];
    }
    return _imageCache;
}

/**
 是否已登录

 @return <#return value description#>
 */
-(BOOL) isLogined {

    return [WKLoginInfo shared].token && ![[WKLoginInfo shared].token isEqualToString:@""];
}

-(void) logout {
    [[WKAPIClient sharedClient] DELETE:@"user/device_token" parameters:nil].then(^{
        [self immediatelyLogout];
    }).catch(^(NSError *error){
        WKLogError(@"注销设备token失败！-> %@",error);
        // 退出登录
        [self immediatelyLogout];
    });
   
}

-(void) immediatelyLogout {
    // 清楚登录信息
    [[WKLoginInfo shared] clearMainData];
    // 清掉 WKWebView 共享的 cookie / 本地存储，防止 Aegis 等 OIDC SSO 会话 cookie 遗留
    // 导致下次点「使用 Aegis 登录」被自动授权进去。data store 是全 app 共享的，
    // 清的范围只是 cookie + localStorage + sessionStorage，不动缓存/indexedDB。
    NSSet *dataTypes = [NSSet setWithArray:@[
        WKWebsiteDataTypeCookies,
        WKWebsiteDataTypeLocalStorage,
        WKWebsiteDataTypeSessionStorage,
    ]];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes
                                               modifiedSince:[NSDate distantPast]
                                           completionHandler:^{
        WKLogDebug(@"[logout] cleared WKWebView cookies/storage");
    }];
    // 调用登出
    [self invoke:WKPOINT_LOGIN_LOGOUT param:nil];
}

- (void)appDidEnterBackground:(NSNotification *)notification   {
    if([WKApp shared].isLogined) {
        NSInteger unreadCount = [[WKConversationListVM shared] getAllUnreadCount];
           [[UIApplication sharedApplication] setApplicationIconBadgeNumber:unreadCount];
           [[WKAPIClient sharedClient] POST:@"user/device_badge" parameters:@{@"badge":@(unreadCount)}].catch(^(NSError *error){
               WKLogError(@"上传红点数量失败！-> %@",error);
           });
    }else {
          [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    }

    [WKApp shared].loginInfo.extra[@"enter_background_time"] = @([[NSDate date] timeIntervalSince1970]);
}



-(void) appWillEnterForeground:(NSNotification*) notification {
    WKLogDebug(@"appWillEnterForeground--->");
    [self showLockScreenProtectIfNeed];
    
    [self showScreenProtectIfNeed];
}

-(void) appWillResignActive:(NSNotification*) notification  {
    WKLogDebug(@"appWillResignActive---->");
}

-(void) appWillTerminate:(NSNotification*)notification {
    WKLogDebug(@"appWillTerminate---------------------------->");
}

- (void)appDidBecomeActive:(NSNotification *)notification  {
    WKLogDebug(@"appDidBecomeActive--->");

    if([self isLogined]) {
        // 回到前台时强制刷新在线状态（参考Android的onFront方案）
        // 解决网页端异常断开后iOS端仍显示"网页端在线"的问题
        [WKOnlineStatusManager shared].needUpdate = YES;
        [[WKOnlineStatusManager shared] requestUpdateChannelOnlineStatusIfNeed];
    }

    // 回前台时无任何 typing reset 机制，叠加后台期间 bot 回复经 conversation-sync 绕过
    // typing 清除路径，会导致 typing indicator 永久卡死。这里统一清掉所有残留 typing；
    // 若对方确实仍在输入，下一个 typing CMD 到达后会自然恢复。
    for (WKMessage *typingMsg in [[WKTypingManager shared] getAllTypingMessages]) {
        [[WKTypingManager shared] removeTypingByChannel:typingMsg.channel newMessage:nil];
    }
    // 连接
    if([[WKSDK shared] connectionManager].connectStatus == WKDisconnected  && [WKApp shared].isLogined) {
        [[[WKSDK shared] connectionManager] connect];
    }
    
    if([WKApp shared].config.darkModeWithSystem) {
        if (@available(iOS 13.0, *)) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                if(UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    [WKApp shared].config.style = WKSystemStyleDark;
                }else{
                    [WKApp shared].config.style = WKSystemStyleLight;
                }
            });
        }
    }else{
        [WKApp shared].config.style =  [WKApp shared].config.style;
    }
}

// 录屏
-(void) screenCapturedDidChange {
    if (@available(iOS 11.0, *)) {
        if([WKMySettingManager shared].offlineProtection) {
            [self showScreenProtect:[UIScreen mainScreen].isCaptured];
        }
    }
}


-(WKLoginInfo*) loginInfo {
    
    return [WKLoginInfo shared];
}

- (WKMessageRegistry *)messageRegitry {
    return [WKMessageRegistry shared];
}

-(void) registerEndpoint:(WKEndpoint*)endpoint {
    [self.endpointManager registerEndpoint:endpoint];
}

-(void) unregisterEndpointWithCategory:(NSString*)category {
    [self.endpointManager unregisterEndpointWithCategory:category];
}

-(WKEndpoint*) getEndpoint:(NSString*)sid {
    return [self.endpointManager getEndpointWithSid:sid];
}

-(id) invoke:(NSString*)endpointSID param:(id)param{
   WKEndpoint *endpoint = [self.endpointManager getEndpointWithSid:endpointSID];
    if(endpoint) {
       return  endpoint.handler(param);
    }
    return nil;
}

-(NSArray*) invokes:(NSString*)category param:(id)param{
    NSArray<WKEndpoint*> *endpoints = [self.endpointManager getEndpointsWithCategory:category];
    if(endpoints) {
        NSMutableArray *items = [NSMutableArray array];
        for (WKEndpoint *endpoint in endpoints) {
            id obj = endpoint.handler(param);
            if(obj) {
                [items addObject:obj];
            }
            
        }
        return items;
    }
    return nil;
}

-(NSArray<WKEndpoint*>*) getEndpointsWithCategory:(NSString*)category {
    return  [self.endpointManager getEndpointsWithCategory:category];
}

-(void) setMethod:(NSString*)sid handler:(WKHandler) handler{
    [self setMethod:sid handler:handler category:nil];
}

-(BOOL) hasMethod:(NSString*)sid {
    return  [self.endpointManager getEndpointWithSid:sid]!=nil;
}

-(void) setMethod:(NSString*)sid handler:(WKHandler) handler category:(NSString*)category{
    [self registerEndpoint:[WKEndpoint initWithSid:sid handler:handler category:category]];
}
-(void) setMethod:(NSString*)sid handler:(WKHandler) handler category:(NSString* __nullable)category sort:(int)sort {
     [self registerEndpoint:[WKEndpoint initWithSid:sid handler:handler category:category sort:@(sort)]];
}

-(void) registerCellClass:(Class)cellClass forMessageContntClass:(Class)messageContentClass {
    [[WKMessageRegistry shared] registerCellClass:cellClass forMessageContentClass:messageContentClass];
}
-(void) registerCellClass:(Class)cellClass contentType:(NSInteger)contentType {
    [[WKMessageRegistry shared] registerCellClass:cellClass forContentType:contentType];
}

-(Class) getMessageCell:(NSInteger)contentType {
    return [[WKMessageRegistry shared] getMessageCell:contentType];
}

-(UIImage*) loadImage:(NSString*)name moduleID:(NSString*)moduleID{
   return  [[[WKSwiftModuleManager shared] getModuleWithId:moduleID] ImageForResource:name];
}

// 解析顺序与老 WKAboutVC 实现保持一致, 详见 WKApp.h 注释。
// 实现链路敏感: Xcode 14+ 默认 CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName
// 是 "AppIcon"（asset catalog 自动注入）, 但 [UIImage imageNamed:@"AppIcon"] 在运
// 行时可能返回 nil（系统未把 launcher icon 导出到 main bundle）, 所以最后还要兜底
// lanch_logo。
+ (nullable UIImage *)appLaunchIcon {
    UIImage *appIcon = nil;
    NSDictionary *infoDic = [[NSBundle mainBundle] infoDictionary];
    NSString *iconName = infoDic[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconName"];
    if (iconName) {
        appIcon = [UIImage imageNamed:iconName];
    }
    if (!appIcon) {
        NSArray *iconFiles = infoDic[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"];
        if (iconFiles.count > 0) {
            appIcon = [UIImage imageNamed:iconFiles.lastObject];
        }
    }
    if (!appIcon) {
        appIcon = [UIImage imageNamed:@"AppIcon"];
    }
    if (!appIcon) {
        appIcon = [UIImage imageNamed:@"lanch_logo"];
    }
    return appIcon;
}

-(NSBundle*) resourceBundle:(NSString*)moduleID {
    return [[[WKSwiftModuleManager shared] getModuleWithId:moduleID] resourceBundle];
}

-(NSBundle*) resourceBundleWithClass:(Class)cls {
    NSBundle *bundle = [NSBundle bundleForClass:cls];
    NSString *moduleName = bundle.infoDictionary[@"CFBundleExecutable"];
    return [self resourceBundle:moduleName];
}

// 从 apiBaseUrl 推导出服务器 origin（不含 /api/v1/ 路径）
-(NSString*) serverOrigin {
    NSString *baseUrl = [WKApp shared].config.apiBaseUrl;
    NSRange apiRange = [baseUrl rangeOfString:@"/api/"];
    if (apiRange.location != NSNotFound) {
        return [baseUrl substringToIndex:apiRange.location];
    }
    // fallback: 去掉末尾路径
    NSURL *url = [NSURL URLWithString:baseUrl];
    if (url) {
        return [NSString stringWithFormat:@"%@://%@", url.scheme, url.host];
    }
    return baseUrl;
}

-(NSURL*) getImageFullUrl:(NSString*)path{
    if (!path || path.length == 0) return nil;
    if([path hasPrefix:@"http"]) {
        return [NSURL URLWithString:path];
    }
    // file/preview/ 路径使用服务器公共文件地址（与 web 端一致）
    if ([path hasPrefix:@"file/preview/"]) {
        NSString *filePath = [path stringByReplacingCharactersInRange:NSMakeRange(0, [@"file/preview/" length]) withString:@"file/"];
        NSString *encodedPath = [filePath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
        NSString *urlStr = [NSString stringWithFormat:@"%@/%@", [self serverOrigin], encodedPath];
        return [NSURL URLWithString:urlStr];
    }
    NSString *encodePath = [path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
    if(encodePath) {
        NSString *newPath = [encodePath copy];
        if([newPath hasPrefix:@"/"]) {
            newPath = [newPath substringFromIndex:1];
        }
        NSString *urlStr =[NSString stringWithFormat:@"%@%@",[WKApp shared].config.imageBrowseUrl,newPath];
        return [NSURL URLWithString:urlStr];
    }
    return nil;
}
-(NSURL*) getFileFullUrl:(NSString*)path{
    if (!path || path.length == 0) return nil;
    if([path hasPrefix:@"http"]) {
        return [NSURL URLWithString:path];
    }
    // file/preview/ 路径使用服务器公共文件地址（与 web 端一致）
    if ([path hasPrefix:@"file/preview/"]) {
        NSString *filePath = [path stringByReplacingCharactersInRange:NSMakeRange(0, [@"file/preview/" length]) withString:@"file/"];
        NSString *encodedPath = [filePath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
        NSString *urlStr = [NSString stringWithFormat:@"%@/%@", [self serverOrigin], encodedPath];
        return [NSURL URLWithString:urlStr];
    }
    NSString *encodePath = [path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
    if(encodePath) {
        NSString *newPath = [encodePath copy];
        if([newPath hasPrefix:@"/"]) {
            newPath = [newPath substringFromIndex:1];
        }
        NSString *urlStr =[NSString stringWithFormat:@"%@%@",[WKApp shared].config.fileBrowseUrl,newPath];
        return [NSURL URLWithString:urlStr];
    }
    return nil;
}

-(void) addMessageAllowForward:(NSInteger)contentType {
    [self.allowForwards addObject:[NSString stringWithFormat:@"%ld",(long)contentType]];
}

/// RichText(=14) 仅文本拼接（跳过 image 占位）。供「复制」菜单使用——wire 的 [图片] 占位
/// 进 clipboard 没意义，用户期望复制到的是真实的文字。空串表示纯图消息无可复制内容。
+ (NSString *)wk_richTextPlainTextOnly:(WKRichTextContent *)content {
    NSMutableString *buffer = [NSMutableString string];
    for (WKRichTextBlock *block in content.content) {
        if (block.type == WKRichTextBlockTypeText && block.text.length > 0) {
            if (buffer.length > 0) {
                [buffer appendString:@"\n"];
            }
            [buffer appendString:block.text];
        }
    }
    return buffer;
}

- (void)addMessageAllowCopy:(NSInteger)contentType {
    [self.allowCopys addObject:[NSString stringWithFormat:@"%ld",(long)contentType]];
}

- (void)addMessageAllowFavorite:(NSInteger)contentType {
    [self.allowFavorites addObject:[NSString stringWithFormat:@"%ld",(long)contentType]];
}

- (BOOL)allowMessageCopy:(NSInteger)contentType {
    return [self.allowCopys containsObject:[NSString stringWithFormat:@"%ld",(long)contentType]];
}

- (BOOL)allowMessageForward:(NSInteger)contentType {
    return [self.allowForwards containsObject:[NSString stringWithFormat:@"%ld",(long)contentType]];
}

- (BOOL)allowMessageFavorite:(NSInteger)contentType {
    return [self.allowFavorites containsObject:[NSString stringWithFormat:@"%ld",(long)contentType]];
}

- (NSMutableArray<NSString *> *)allowForwards {
    if(!_allowForwards) {
        _allowForwards = [NSMutableArray array];
    }
    return _allowForwards;
}

- (NSMutableArray<NSString *> *)allowCopys {
    if(!_allowCopys) {
        _allowCopys = [NSMutableArray array];
    }
    return _allowCopys;
}

- (NSMutableArray<NSString *> *)allowFavorites {
    if(!_allowFavorites) {
        _allowFavorites = [NSMutableArray array];
    }
    return _allowFavorites;
}


- (unsigned long long)calculateVideoCachedSizeWithError:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cacheDirectory = [self.config videoCacheDir];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:error];
    unsigned long long size = 0;
    if (files) {
        for (NSString *path in files) {
            NSString *filePath = [cacheDirectory stringByAppendingPathComponent:path];
            NSDictionary<NSFileAttributeKey, id> *attribute = [fileManager attributesOfItemAtPath:filePath error:error];
            if (!attribute) {
                size = -1;
                break;
            }
            
            size += [attribute fileSize];
        }
    }
    return size;
}

-(void) cleanVideoCache {
    NSString *cacheDirectory = [self.config videoCacheDir];
    [WKFileUtil removeFileOfPath:cacheDirectory];
    [WKFileUtil createDirectoryIfNotExist:cacheDirectory];
}


// 跳到聊天页面
-(void) pushConversation:(WKChannel*)channel {
   NSArray<WKEndpoint*> *endpoints = [self.endpointManager getEndpointsWithCategory:WKPOINT_CATEGORY_CONVERSATION_SHOW];
    if(endpoints && endpoints.count>0) {
        for (WKEndpoint *endpoint in endpoints) {
           id value = endpoint.handler(@{@"channel":channel});
            if(value && [value boolValue]) {
                break;
            }
        }
    }
}

// 初始化Point方法
-(void) initPointMethods {
    
    __weak typeof(self) weakSelf = self;
    
    [self setMethod:WKPOINT_SYNC_PROHIBITWORDS handler:^id _Nullable(id  _Nonnull param) {
        return WKProhibitwordsService.shared;
    } category:WKPOINT_CATEGORY_SYNC];
    
    // 显示聊天UI
    [self setMethod:WKPOINT_CONVERSATION_SHOW handler:^id _Nullable(id  _Nonnull param) {
         WKConversationVC *conversationVC =  [WKConversationVC new];
        conversationVC.channel = param;
        [[WKNavigationManager shared] pushViewController:conversationVC animated:YES];
        return nil;
    }];
    
    [self setMethod:WKPOINT_CONVERSATION_SHOW_DEFAULT handler:^id _Nullable(id  _Nonnull param) {
        WKChannel *channel = (WKChannel*)param[@"channel"];
        if(channel.channelType == WK_GROUP || channel.channelType == WK_PERSON || channel.channelType == WK_COMMUNITY_TOPIC) {
            WKConversationVC *conversationVC =  [WKConversationVC new];
           conversationVC.channel = channel;
           [[WKNavigationManager shared] pushViewController:conversationVC animated:YES];
            return @(true);
        }
        return @(false);
    } category:WKPOINT_CATEGORY_CONVERSATION_SHOW];
    
    // 联系人选择
    [self setMethod:WKPOINT_CONTACTS_SELECT handler:^id _Nullable(id  _Nonnull param) {
        WKContactsMode mode = WKContactsModeMulti;
        if(param[@"mode"]&&[param[@"mode"] isEqualToString:@"single"]) {
            mode = WKContactsModeSingle;
        }
        WKContactsSelectVC *vc = [WKContactsSelectVC new];
        NSString *title = param[@"title"];
        if(!title) {
            title = LLangW(@"联系人选择", weakSelf);
        }
        vc.mode = mode;
        vc.title = title;
        NSArray *selecteds = param[@"selecteds"];
        if(selecteds && selecteds.count>0) {
            vc.selecteds = [NSMutableArray arrayWithArray:selecteds];
        }
        vc.mentionAll = param[@"mention_all"];
        vc.onFinishedSelect = param[@"on_finished"];
        vc.disables = param[@"disables"];
        vc.data = param[@"data"];
        vc.hiddenUsers = param[@"hidden_users"];
        if(param[@"hidden_systemuser"]) {
            NSMutableArray *hiddenUsers = [NSMutableArray array];
            if(vc.hiddenUsers) {
                [hiddenUsers addObjectsFromArray:vc.hiddenUsers];
            }
            [hiddenUsers addObject:WKApp.shared.config.fileHelperUID];
            [hiddenUsers addObject:WKApp.shared.config.systemUID];
            
            vc.hiddenUsers = hiddenUsers;
            
        }
        if(param[@"on_cancel"]) {
            vc.onDealloc = param[@"on_cancel"];
        }
        if(!param[@"no_push"]) {
            [[WKNavigationManager shared] pushViewController:vc animated:YES];
        }
       
        return vc;
    }];
    
    // 开始聊天
    [self setMethod:WKPOINT_CONVERSATION_STARTCHAT handler:^id _Nullable(id  _Nonnull param) {
        WKOnComplete complete = param[@"on_complete"];
        [weakSelf invoke:WKPOINT_CONTACTS_SELECT param:@{@"on_finished":^(NSArray<NSString*>*members){
            if(members.count==1) {
                if(complete) {
                     [[WKNavigationManager shared] popViewControllerAnimated:YES];
                     complete([[WKChannel alloc] initWith:members[0] channelType:WK_PERSON],nil);
                }else {
                     [[WKNavigationManager shared] popViewControllerAnimated:YES];
                    // 跳到聊天页面
                    [weakSelf pushConversation:[[WKChannel alloc] initWith:members[0] channelType:WK_PERSON]];
                }
                return;
            }
            
             UIView *topView = [WKNavigationManager shared].topViewController.view;
             [topView showHUD];
            [[WKGroupManager shared] createGroup:members object:nil complete:^(NSString *groupNo,NSError *error){
                 [topView hideHud];
                if(error) {
                    if(complete) {
                        complete(nil,error);
                    }else {
                         [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
                    }
                    return;
                }
                if(complete) {
                    complete([[WKChannel alloc] initWith:groupNo channelType:WK_GROUP],nil);
                    
                }else {
                    [[WKNavigationManager shared] popViewControllerAnimated:YES];
                    // 跳到聊天页面
                    [weakSelf pushConversation:[[WKChannel alloc] initWith:groupNo channelType:WK_GROUP]];
                }
               
            }];
        }}];
        return nil;
    }];
    // 扫一扫
    [self setMethod:WKPOINT_CONVERSATION_SCAN handler:^id _Nullable(id  _Nonnull param) {
        WKScanVC *scanVC = [WKScanVC new];
        [[WKNavigationManager shared] pushViewController:scanVC animated:YES];
        return nil;
    }];
    
    // 聊天页面设置
    [self setMethod:WKPOINT_CONVERSATION_SETTING handler:^id _Nullable(id  _Nonnull param) {
        WKChannel *channel = param[@"channel"];
        id<WKConversationContext> context = param[@"context"];
        if(channel.channelType == WK_GROUP) {
            WKConversationGroupSettingVC *vc = [WKConversationGroupSettingVC new];
            vc.channel = channel;
            vc.context = context;
            [[WKNavigationManager shared] pushViewController:vc animated:YES];
        } else if(channel.channelType == WK_COMMUNITY_TOPIC) {
            WKThreadSettingVC *vc = [WKThreadSettingVC new];
            vc.channel = channel;
            [[WKNavigationManager shared] pushViewController:vc animated:YES];
        } else {
            WKConversationPersonSettingVC *vc = [WKConversationPersonSettingVC new];
            vc.channel = channel;
            vc.context = context;
            [[WKNavigationManager shared] pushViewController:vc animated:YES];
        }
       
        return nil;
    }];
    
    // ---------- 消息面板相关 ----------
    
    // emoji面板
    [self setMethod:WKPOINT_PANEL_EMOJI handler:^id _Nullable(id  _Nonnull param) {
        id<WKConversationContext> context = param[@"context"];
        return [[WKEmojiPanel alloc] initWithContext:context];
    } category:WKPOINT_CATEGORY_PANEL];
    
    
    // emoji
    [self setMethod:WKPOINT_CATEGORY_PANELFUNCITEM_EMOJI handler:^id _Nullable(id  _Nonnull param) {
       
        WKPanelDefaultFuncItem *item = [[WKPanelEmojiFuncItem alloc] init];
        item.sort = 1000;
        return item;
    } category:WKPOINT_CATEGORY_PANELFUNCITEM];
    
    // voice
    [self setMethod:WKPOINT_CATEGORY_PANELFUNCITEM_VOICE handler:^id _Nullable(id  _Nonnull param) {
        WKPanelDefaultFuncItem *item = [[WKPanelVoiceFuncItem alloc] init];
        item.sort = 2000;
        return item;
    } category:WKPOINT_CATEGORY_PANELFUNCITEM];
    
    // image
    [self setMethod:WKPOINT_CATEGORY_PANELFUNCITEM_IMAGE handler:^id _Nullable(id  _Nonnull param) {
        WKPanelDefaultFuncItem *item = [[WKPanelImageFuncItem alloc] init];
        item.sort = 3000;
        return item;
    } category:WKPOINT_CATEGORY_PANELFUNCITEM];
    
    // @
    [self setMethod:WKPOINT_CATEGORY_PANELFUNCITEM_MENTION handler:^id _Nullable(id  _Nonnull param) {
        id<WKConversationContext> context = param[@"context"];
        if(context.channel.channelType != WK_GROUP && context.channel.channelType != WK_COMMUNITY_TOPIC) {
            return nil;
        }
        WKPanelDefaultFuncItem *item = [[WKPanelMentionFuncItem alloc] init];
        item.sort = 4000;
        item.channelType = context.channel.channelType;
        return item;
    } category:WKPOINT_CATEGORY_PANELFUNCITEM];
    
    // card
    [self setMethod:WKPOINT_CATEGORY_PANELFUNCITEM_CARD handler:^id _Nullable(id  _Nonnull param) {
        WKPanelCardFuncItem *item = [[WKPanelCardFuncItem alloc] init];
        item.sort = 5000;
        return item;
    } category:WKPOINT_CATEGORY_PANELFUNCITEM];

    // file
    [self setMethod:WKPOINT_CATEGORY_PANELFUNCITEM_FILE handler:^id _Nullable(id  _Nonnull param) {
        WKPanelFileFuncItem *item = [[WKPanelFileFuncItem alloc] init];
        item.sort = 5500;
        return item;
    } category:WKPOINT_CATEGORY_PANELFUNCITEM];

    // more
    [self setMethod:WKPOINT_CATEGORY_PANELFUNCITEM_MORE handler:^id _Nullable(id  _Nonnull param) {
        return [[WKPanelMoreFuncItem alloc] init];
    } category:WKPOINT_CATEGORY_PANELFUNCITEM];
    
    
    // emoji正文
    [self setMethod:WKPOINT_PANELCONTENT_EMOJI handler:^id _Nullable(id  _Nonnull param) {
        return [WKEmojiContentView new];
    } category:WKPOINT_CATEGORY_PANELCONTENT sort:4000];
   
    
//    // 面板正文 - gif热图
//    [self setMethod:WKPOINT_PANELCONTENT_HOT handler:^id _Nullable(id  _Nonnull param) {
//        WKStickerGIFContentView *gifContentView = [[WKStickerGIFContentView alloc] initWithKeyword:LLangW(@"热图", weakSelf)];
//        gifContentView.tabIcon = [weakSelf imageName:@"icon_face_emoji"];
//        return gifContentView;
//    } category:WKPOINT_CATEGORY_PANELCONTENT sort:3000];
//    
//    // 面板正文 - gif热图
//    [self setMethod:@"gif002" handler:^id _Nullable(id  _Nonnull param) {
//        WKStickerGIFContentView *gifContentView =[[WKStickerGIFContentView alloc] initWithKeyword:LLangW(@"卖萌",weakSelf)];
//        gifContentView.tabIcon = [weakSelf imageName:@"icon_face_emoji"];
//        return gifContentView;
//    } category:WKPOINT_CATEGORY_PANELCONTENT sort:2000];
//    
//    // 面板正文 - gif热图
//    [self setMethod:@"gif003" handler:^id _Nullable(id  _Nonnull param) {
//        WKStickerGIFContentView *gifContentView = [[WKStickerGIFContentView alloc] initWithKeyword:LLangW(@"搞笑", weakSelf)];
//        gifContentView.tabIcon = [weakSelf imageName:@"icon_face_emoji"];
//        return gifContentView;
//    } category:WKPOINT_CATEGORY_PANELCONTENT sort:1000];
    
    // 跳到表情收藏
    [self setMethod:WKPOINT_TO_STICKER_COLLECTION handler:^id _Nullable(id  _Nonnull param) {
        WKStickerCollectionVC *vc = [WKStickerCollectionVC new];
        [vc setDataArray:param[@"data"]];
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
        return nil;
    }];
    
    
    // 更多面板
    [self setMethod:WKPOINT_PANEL_MORE handler:^id _Nullable(id  _Nonnull param) {
        id<WKConversationContext> context = param[@"context"];
        return [[WKMorePanel2 alloc] initWithContext:context];
    } category:WKPOINT_CATEGORY_PANEL];
    
    // 录音
    [self setMethod:WKPOINT_PANEL_VOICE handler:^id _Nullable(id  _Nonnull param) {
        id<WKConversationContext> context = param[@"context"];
        return [[WKVoicePanel alloc] initWithContext:context];
    } category:WKPOINT_CATEGORY_PANEL];
    
    
    // 输入框输入emoji或删除emoji的响应 （删除字符时 emoji是一次删除好几个字符）
    [self setMethod:WKPOINT_EMOJI_INPUT_TEXT_RESPOND handler:^id _Nullable(id  _Nonnull param) {
        return [WKEmojiInputChangeTextRespond new];
    } category:WKPOINT_CATEGORY_CONVERSATION_INPUT_TEXT_RESPOND];
    
    // ---------- 消息长按菜单 ----------
    //收藏表情
    [self setMethod:WKPOINT_LONGMENUS_ADDEMOJI handler:^id _Nullable(id  _Nonnull param) {
        WKMessageModel *message = param[@"message"];
        NSString *path;
        if(message.message.contentType == WK_GIF) {
            WKGIFContent *gifContent = (WKGIFContent*)message.content;
            path = gifContent.url;
        }else if(message.message.contentType == WK_LOTTIE_STICKER) {
            WKLottieStickerContent *content = (WKLottieStickerContent *)message.content;
            path = content.url;
        }
        if(!path) {
            return nil;
        }
        
        // 判断此表情是否已收藏
       NSArray<WKSticker*> *stickers = WKApp.shared.collectStickers;
        if(stickers && stickers.count>0) {
            for (WKSticker *sticker in stickers) {
                if([sticker.path isEqualToString:path]) {
                    return nil;
                }
            }
        }

        UIImage *icon = [GenerateImageUtils generateTintedImgWithImage:[weakSelf imageName:@"Conversation/ContextMenu/Favorites"] color:weakSelf.config.contextMenu.primaryColor backgroundColor:nil];
        return [WKMessageLongMenusItem initWithTitle:LLangW(@"添加表情", weakSelf) icon:icon onTap:^(id<WKConversationContext> context){
            [[WKMessageManager shared] collectExpressions:message];
        }];
        return nil;
    } category:WKPOINT_CATEGORY_MESSAGE_LONGMENUS sort:5000];
    
    // 回复
    [self setMethod:WKPOINT_LONGMENUS_REPLY handler:^id _Nullable(id  _Nonnull param) {
        WKMessageModel *message = param[@"message"];
        if(message.status != WK_MESSAGE_SUCCESS) {
            return nil;
        }
        if(message.messageId == 0) {
            return nil;
        }
        UIImage *icon = [GenerateImageUtils generateTintedImgWithImage:[weakSelf imageName:@"Conversation/ContextMenu/Reply"] color:weakSelf.config.contextMenu.primaryColor backgroundColor:nil];
        return [WKMessageLongMenusItem initWithTitle:LLangW(@"回复", weakSelf) icon:icon onTap:^(id<WKConversationContext> context){
            [context replyTo:message.message];
        }];
    } category:WKPOINT_CATEGORY_MESSAGE_LONGMENUS sort:4000];
    
    
    // 复制
    [[WKApp shared] addMessageAllowCopy:WK_TEXT];
    [[WKApp shared] addMessageAllowCopy:WK_RICHTEXT];
    [self setMethod:WKPOINT_LONGMENUS_COPY handler:^id _Nullable(id  _Nonnull param) {
        WKMessageModel *message = param[@"message"];

        if(![[WKApp shared] allowMessageCopy:message.contentType]) {
            return nil;
        }
        UIImage *icon = [GenerateImageUtils generateTintedImgWithImage:[weakSelf imageName:@"Conversation/ContextMenu/Copy"] color:weakSelf.config.contextMenu.primaryColor backgroundColor:nil];
        return [WKMessageLongMenusItem initWithTitle:LLangW(@"复制", weakSelf) icon:icon onTap:^(id<WKConversationContext> context){
            NSString *newContent = nil;
            if ([message.content isKindOfClass:[WKRichTextContent class]]) {
                // 图文混排：菜单复制使用 text-only 拼接（跳过 [图片] wire 占位），那个占位
                // 上 clipboard 没意义。用户拖动选区 + 系统 Copy 走的是 UITextView selectedText
                // 路径，不经过这里——这里只服务"全文复制"路径。
                NSString *plainText = [WKApp wk_richTextPlainTextOnly:(WKRichTextContent*)message.content];
                newContent = plainText.length > 0 ? plainText : (((WKRichTextContent*)message.content).plain ?: @"");
            } else {
                WKTextContent *textConent =  (WKTextContent*)message.content;
                NSRegularExpression *regularExpretion=[NSRegularExpression regularExpressionWithPattern:@"<[^>]*>|\n"
                                                        options:0
                                                         error:nil];
                newContent=[regularExpretion stringByReplacingMatchesInString:textConent.content options:NSMatchingReportProgress range:NSMakeRange(0, textConent.content.length) withTemplate:@""];
            }
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = newContent;
            UIView *topView = [WKNavigationManager shared].topViewController.view;
            [topView showHUDWithHide:LLangW(@"已复制", weakSelf)];
        }];
    } category:WKPOINT_CATEGORY_MESSAGE_LONGMENUS sort:3000];
    
    // 撤回
    [self setMethod:WKPOINT_LONGMENUS_REVOKE handler:^id _Nullable(id  _Nonnull param) {
        WKMessageModel *message = param[@"message"];

        if(message.status != WK_MESSAGE_SUCCESS) {
            return nil;
        }
        if(message.messageId == 0) { // 本地消息
            return nil;
        }

        // 撤回按钮可见性：
        //   群聊 (WK_GROUP) ——
        //     · 自己发的消息：显示（仍受撤回时窗限制）
        //     · 群主：对任何人显示，不受时窗限制
        //     · 管理员：仅对普通成员显示，对其他管理员/群主隐藏（避免越权）
        //     · 普通成员：仅对自己的消息显示
        //   子区 (WK_COMMUNITY_TOPIC) —— 同群聊；以父群（channelId 形如
        //     "<groupNo>____<shortId>"，取 ____ 前一段）的成员角色为判断依据,
        //     与 WKThreadSettingVC 里 isGroupAdmin 同源。子区消息的 fromUid 也是
        //     父群成员，所以 target 角色直接查父群即可。
        //   Bot 创建者 —— TODO: 待后端把 bot_creator_uid 下放到 channel_member.extra
        //     后，在此追加「self == from.bot_creator」分支让 Bot 拥有者可撤回该 Bot 消息。
        NSString *loginUid = [WKApp shared].loginInfo.uid;
        BOOL isManager = false;
        WKChannel *roleChannel = nil;
        if(message.channel.channelType == WK_GROUP) {
            roleChannel = message.channel;
        } else if(message.channel.channelType == WK_COMMUNITY_TOPIC) {
            NSRange sep = [message.channel.channelId rangeOfString:@"____"];
            if(sep.location != NSNotFound) {
                NSString *groupNo = [message.channel.channelId substringToIndex:sep.location];
                if(groupNo.length > 0) {
                    roleChannel = [[WKChannel alloc] initWith:groupNo channelType:WK_GROUP];
                }
            }
        }
        if(roleChannel) {
            WKChannelMember *selfMember = [[WKSDK shared].channelManager getMember:roleChannel uid:loginUid];
            WKMemberRole selfRole = selfMember ? selfMember.role : WKMemberRoleCommon;
            if(selfRole == WKMemberRoleCreator) {
                // 群主：对任何人显示
                isManager = true;
            } else if(selfRole == WKMemberRoleManager) {
                // 管理员：仅对普通成员显示，对其他管理员/群主隐藏。
                // 优先用 channel cache; 缓存未命中时回退到 message.memberOfFrom.role; 仍未知
                // 则 fail-closed (不放行) —— 不能默认当成 Common, 否则缓存未同步时管理员会得到
                // 撤群主消息的权限。
                // 注意: memberOfFrom 是消息发送时的角色快照, 对方后续升管理员后快照仍是
                // Common, 沿用快照会让管理员仍能撤群主消息 (PR #32 R3 review)。
                // 此处选择最保守策略: cache miss 一律 fail-closed, 不依赖快照, 避免越权;
                // 副作用是缓存还没同步好的瞬间, 管理员对自己成员的撤回也会不见, 等成员列表
                // 刷一次就恢复, 可接受。
                WKChannelMember *targetMember = [[WKSDK shared].channelManager getMember:roleChannel uid:message.fromUid];
                if (targetMember) {
                    isManager = (targetMember.role == WKMemberRoleCommon);
                } else {
                    isManager = false;
                }
            }
        }
        if(!isManager) {
            if(![message isSend]) {
                return nil;
            }
            NSInteger revokeSecond = 2*60;
            if(WKApp.shared.remoteConfig.revokeSecond == -1) {
                revokeSecond = -1;
            } else if(WKApp.shared.remoteConfig.revokeSecond>0) {
                revokeSecond = WKApp.shared.remoteConfig.revokeSecond;
            }

            if(revokeSecond>0) {
                if(  [[NSDate date] timeIntervalSince1970] - message.timestamp > revokeSecond) { // 超过两分钟则不显示撤回
                    return nil;
                }
            }
        }
        UIImage *icon = [GenerateImageUtils generateTintedImgWithImage:[weakSelf imageName:@"Conversation/ContextMenu/Revoke"] color:weakSelf.config.contextMenu.primaryColor backgroundColor:nil];
        return [WKMessageLongMenusItem initWithTitle:LLangW(@"撤回", weakSelf) icon:icon onTap:^(id<WKConversationContext> context){
            [[WKMessageManager shared] revokeMessage:message complete:^(NSError * _Nonnull error) {
                if(error) {
                    [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
                }
            }];
        }];
    } category:WKPOINT_CATEGORY_MESSAGE_LONGMENUS sort:3000];
    
    // 转发
    [[WKApp shared] addMessageAllowForward:WK_TEXT];
    [[WKApp shared] addMessageAllowForward:WK_IMAGE];
    [[WKApp shared] addMessageAllowForward:WK_GIF];
    [[WKApp shared] addMessageAllowForward:WK_FILE];
    [[WKApp shared] addMessageAllowForward:WK_SMALLVIDEO];
    [[WKApp shared] addMessageAllowForward:WK_MERGEFORWARD];
    [[WKApp shared] addMessageAllowForward:WK_RICHTEXT]; // 图文混排（RichText=14）：与接收 cell 注册对称，长按需出现「转发」
    [self setMethod:WKPOINT_LONGMENUS_FORWARD handler:^id _Nullable(id  _Nonnull param) {
        WKMessageModel *message = param[@"message"];
        
        if(![[WKApp shared] allowMessageForward:message.contentType]) {
            return nil;
        }
        UIImage *icon = [GenerateImageUtils generateTintedImgWithImage:[weakSelf imageName:@"Conversation/ContextMenu/Forward"] color:weakSelf.config.contextMenu.primaryColor backgroundColor:nil];
        return [WKMessageLongMenusItem initWithTitle:LLangW(@"转发", weakSelf) icon:icon onTap:^(id<WKConversationContext> context){
            WKForwardSelectVC *vc = [WKForwardSelectVC new];
            vc.title = LLangW(@"选择聊天", weakSelf);
            vc.singleSelectMode = YES;
            [vc setOnSingleConfirm:^(WKChannel *channel, NSString *extraText) {
                // ForwardSelectVC 确认后会自动 pop，这里不再重复 pop
                if([channel isEqual:context.channel]) {
                    [context forwardMessage:message.content];
                } else {
                    [[WKSDK shared].chatManager forwardMessage:message.content channel:channel];
                }
                if (extraText.length > 0) {
                    if([channel isEqual:context.channel]) {
                        WKTextContent *tc = [[WKTextContent alloc] initWithContent:extraText];
                        [context forwardMessage:tc];
                    } else {
                        WKTextContent *tc = [[WKTextContent alloc] initWithContent:extraText];
                        [[WKSDK shared].chatManager forwardMessage:tc channel:channel];
                    }
                }
                [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLangW(@"发送成功",weakSelf)];
            }];
            [[WKNavigationManager shared] pushViewController:vc animated:YES];
        }];
    } category:WKPOINT_CATEGORY_MESSAGE_LONGMENUS sort:2900];
    
    
   
    
    // 删除
    [self setMethod:WKPOINT_LONGMENUS_DELETE handler:^id _Nullable(id  _Nonnull param) {
        WKMessageModel *message = param[@"message"];
        if([message isSend] &&  [[NSDate date] timeIntervalSince1970] - message.timestamp < 2*60) { // 显示撤回就不显示删除
            return nil;
        }
        UIImage *icon = [GenerateImageUtils generateTintedImgWithImage:[weakSelf imageName:@"Conversation/ContextMenu/Delete"] color:weakSelf.config.contextMenu.primaryColor backgroundColor:nil];
        return [WKMessageLongMenusItem initWithTitle:LLangW(@"删除",weakSelf) icon:icon onTap:^(id<WKConversationContext> context){
            [[WKMessageManager shared] deleteMessages:@[message]];
        }];
    } category:WKPOINT_CATEGORY_MESSAGE_LONGMENUS sort:990];

    
    // 多选
    [self setMethod:WKPOINT_LONGMENUS_MULTIPLE handler:^id _Nullable(id  _Nonnull param) {
        WKMessageModel *message = param[@"message"];
        UIImage *icon = [GenerateImageUtils generateTintedImgWithImage:[weakSelf imageName:@"Conversation/ContextMenu/Select"] color:weakSelf.config.contextMenu.primaryColor backgroundColor:nil];
        return [WKMessageLongMenusItem initWithTitle:LLangW(@"多选", weakSelf) icon:icon onTap:^(id<WKConversationContext> context){
            [context setMultipleOn:YES selectedMessage:message];
        }];
    } category:WKPOINT_CATEGORY_MESSAGE_LONGMENUS sort:980];

    // 创建子区
    [self setMethod:WKPOINT_LONGMENUS_THREAD handler:^id _Nullable(id  _Nonnull param) {
        WKMessageModel *message = param[@"message"];
        // 仅群聊 + 非系统消息 + threadOn 开关 + 未创建过子区
        if(message.channel.channelType != WK_GROUP) return nil;
        if([[WKSDK shared] isSystemMessage:message.contentType]) return nil;
        if(![WKApp shared].remoteConfig.threadOn) return nil;
        // 该消息已创建过子区，不再显示
        NSString *msgIdStr = [NSString stringWithFormat:@"%llu", message.message.messageId];
        if([[WKThreadCreatedContent sourceMessageIdSet] containsObject:msgIdStr]) return nil;
        UIImage *icon = [GenerateImageUtils generateTintedImgWithImage:[weakSelf imageName:@"Conversation/ContextMenu/Forward"] color:weakSelf.config.contextMenu.primaryColor backgroundColor:nil];
        return [WKMessageLongMenusItem initWithTitle:LLangW(@"创建子区", weakSelf) icon:icon onTap:^(id<WKConversationContext> context){
            // 弹出创建子区对话框
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLangW(@"创建子区", weakSelf)
                                                                          message:nil
                                                                   preferredStyle:UIAlertControllerStyleAlert];
            [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
                tf.placeholder = LLangW(@"子区名称 (最多50字)", weakSelf);
                // 默认取消息前10个字符
                NSString *digest = [message.content conversationDigest];
                if(digest.length > 10) {
                    digest = [digest substringToIndex:10];
                }
                tf.text = digest;
            }];
            UIAlertAction *createAction = [UIAlertAction actionWithTitle:LLangW(@"创建", weakSelf) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                NSString *name = alert.textFields.firstObject.text;
                if(name.length == 0) return;
                if(name.length > 50) name = [name substringToIndex:50];
                NSString *msgId = [NSString stringWithFormat:@"%llu", message.message.messageId];
                // 构建消息正文 payload（与 web 端一致）
                NSMutableDictionary *payload = [NSMutableDictionary dictionary];
                if (message.content.contentDict) {
                    [payload addEntriesFromDictionary:message.content.contentDict];
                }
                payload[@"type"] = @(message.contentType);
                [[WKThreadService shared] createThread:message.channel.channelId name:name sourceMessageId:msgId sourceMessagePayload:payload].then(^(WKThreadModel *thread) {
                    [[WKThreadService shared] joinThread:thread.shortId].then(^(id result) {
                        [[WKApp shared] invoke:WKPOINT_CONVERSATION_SHOW param:[thread toChannel]];
                    }).catch(^(NSError *error) {
                        [[WKApp shared] invoke:WKPOINT_CONVERSATION_SHOW param:[thread toChannel]];
                    });
                }).catch(^(NSError *error) {
                    [[[WKNavigationManager shared] topViewController].view showMsg:error.domain];
                });
            }];
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:LLangW(@"取消", weakSelf) style:UIAlertActionStyleCancel handler:nil];
            [alert addAction:cancelAction];
            [alert addAction:createAction];
            [[[WKNavigationManager shared] topViewController] presentViewController:alert animated:YES completion:nil];
        }];
    } category:WKPOINT_CATEGORY_MESSAGE_LONGMENUS sort:970];

    // 个人资料
    [self setMethod:WKPOINT_USER_INFO handler:^id _Nullable(id  _Nonnull param) {
        NSString *uid = param[@"uid"];
//        if([uid isEqualToString:[WKApp shared].loginInfo.uid]) {
//            [[WKNavigationManager shared] pushViewController:[WKMeInfoVC new] animated:YES];
//            return nil;
//        }
        WKUserInfoVC *vc = [WKUserInfoVC new];
        vc.uid = uid;
        vc.vercode = param[@"vercode"]?:@"";
        vc.fromChannel = param[@"channel"];
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
        return nil;
    }];
    
    // ---------- 扫一扫  ----------
    
    // 扫码进群
    [self setMethod:WKPOINT_SCAN_HANDLER_JOIN_GROUP handler:^id _Nullable(id  _Nonnull param) {
        return [WKScanHandler handle:^BOOL(WKScanResult * _Nonnull result, void (^ _Nonnull reScanBlock)(void)) {
            if(![result.type isEqualToString:@"group"]) {
                return false;
            }
            WKGroupScanJoinVC *vc = [WKGroupScanJoinVC new];
            vc.groupNo = result.data[@"group_no"] ?: @"";
            vc.authCode = result.data[@"auth_code"] ?: @"";
            vc.groupName = result.data[@"name"] ?: @"";
            vc.groupAvatar = result.data[@"avatar"] ?: @"";
            vc.memberCount = [result.data[@"member_count"] integerValue];
            vc.isMember = [result.data[@"is_member"] boolValue];
            // : 扫码/邀请链接携带的目标 Space 上下文（后端契约：space_id / space_name）。
            // 允许字段缺失 — 缺失时走 legacy 同 Space 路径，不弹切换 dialog。
            vc.targetSpaceId = [result.data[@"space_id"] isKindOfClass:[NSString class]] ? result.data[@"space_id"] : nil;
            vc.targetSpaceName = [result.data[@"space_name"] isKindOfClass:[NSString class]] ? result.data[@"space_name"] : nil;
            [[WKNavigationManager shared] replacePushViewController:vc animated:YES];
            return true;
        }];
    } category:WKPOINT_CATEGORY_SCAN_HANDLER];
    
    // 扫码加好友(跳到用户信息界面)
    [self setMethod:WKPOINT_SCAN_HANDLER_ADD_FRIEND handler:^id _Nullable(id  _Nonnull param) {
        return [WKScanHandler handle:^BOOL(WKScanResult * _Nonnull result, void (^ _Nonnull reScanBlock)(void)) {
            if(![result.type isEqualToString:@"userInfo"]) {
                return false;
            }
            if([result.data[@"uid"] isEqualToString:[WKApp shared].loginInfo.uid]) {
                [[WKNavigationManager shared] replacePushViewController:[WKMeInfoVC new] animated:YES];
                return true;
            }
            WKUserInfoVC *vc = [WKUserInfoVC new];
            vc.uid = result.data[@"uid"]?:@"";
            vc.vercode = result.data[@"vercode"]?:@"";
            [[WKNavigationManager shared] replacePushViewController:vc animated:YES];
            return true;
        }];
    } category:WKPOINT_CATEGORY_SCAN_HANDLER];
    
    // webview
    [self setMethod:WKPOINT_SCAN_HANDLER_WEBVIEW handler:^id _Nullable(id  _Nonnull param) {
        return [WKScanHandler handle:^BOOL(WKScanResult * _Nonnull result, void (^ _Nonnull reScanBlock)(void)) {
            if(![result.type isEqualToString:@"webview"]) {
                return false;
            }
            WKWebViewVC *vc = [WKWebViewVC new];
            vc.url = [NSURL URLWithString:result.data[@"url"]];
            [[WKNavigationManager shared] replacePushViewController:vc animated:YES];
            return true;
        }];
    } category:WKPOINT_CATEGORY_SCAN_HANDLER];
    
    // ---------- 最近会话列表的+  ----------
    
    [self setMethod:WKPOINT_CONVERSATION_ADD_STARTCHAT handler:^id _Nullable(id  _Nonnull param) {
        return [WKConversationAddItem title:LLangW(@"发起群聊", weakSelf) icon:[weakSelf imageName:@"ConversationList/Popmenus/StartChat"] onClick:^{
            [[WKApp shared] invoke:WKPOINT_CONVERSATION_STARTCHAT param:nil];
        }];
    } category:WKPOINT_CATEGORY_CONVERSATION_ADD sort:9000];

    [self setMethod:WKPOINT_CONVERSATION_ADD_CREATECATEGORY handler:^id _Nullable(id  _Nonnull param) {
        return [WKConversationAddItem title:LLangW(@"创建分组", weakSelf) icon:[WKApp createCategoryIcon] onClick:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"WKShowCreateCategoryDialog" object:nil];
        }];
    } category:WKPOINT_CATEGORY_CONVERSATION_ADD sort:8500];

    [self setMethod:WKPOINT_CONVERSATION_ADD_ADDFRIEND handler:^id _Nullable(id  _Nonnull param) {
        return [WKConversationAddItem title:LLangW(@"添加朋友", weakSelf) icon:[weakSelf imageName:@"ConversationList/Popmenus/FriendAdd"] onClick:^{
            [[WKApp shared] invoke:WKPOINT_CONVERSATION_ADDCONTACTS param:nil];
        }];
    } category:WKPOINT_CATEGORY_CONVERSATION_ADD sort:8000];
    
    [self setMethod:WKPOINT_CONVERSATION_ADD_SCAN handler:^id _Nullable(id  _Nonnull param) {
        return [WKConversationAddItem title:LLangW(@"扫一扫", weakSelf) icon:[weakSelf imageName:@"ConversationList/Popmenus/Scan"] onClick:^{
            [[WKApp shared] invoke:WKPOINT_CONVERSATION_SCAN param:nil];
        }];
    } category:WKPOINT_CATEGORY_CONVERSATION_ADD sort:7000];
    
    
    // ---------- 我的  ----------
    // PC端
    [self setMethod:WKPOINT_ME_WEB handler:^id _Nullable(id  _Nonnull param) {
        return [WKMeItem initWithTitle:LLangW(@"网页端",weakSelf) icon:[weakSelf imageName:@"Me/Index/IconPC"] nextSectionHeight:10.0f onClick:^{
            [[WKNavigationManager shared] pushViewController:[WKWebClientInfoVC new] animated:YES];
        }];
    } category:WKPOINT_CATEGORY_ME sort:18000];
    // 新消息通知
    [self setMethod:WKPOINT_ME_NEWMSGNOTICE handler:^id _Nullable(id  _Nonnull param) {
        return [WKMeItem initWithTitle:LLangW(@"新消息通知",weakSelf) icon:[weakSelf imageName:@"Me/Index/IconNotify"] onClick:^{
             [[WKNavigationManager shared] pushViewController:[WKMePushSettingVC new] animated:YES];
        }];
    } category:WKPOINT_CATEGORY_ME sort:8000];
    
    // 我的邀请码
    [self setMethod:WKPOINT_ME_INVITE handler:^id _Nullable(id  _Nonnull param) {
        if(!WKApp.shared.remoteConfig.registerInviteOn) {
            return nil;
        }
        return [WKMeItem initWithTitle:LLangW(@"我的邀请码",weakSelf) icon:[weakSelf imageName:@"Me/Index/IconInviteCode"] onClick:^{
             [[WKNavigationManager shared] pushViewController:[WKMyInviteCodeVC new] animated:YES];
        }];
    } category:WKPOINT_CATEGORY_ME sort:7900];
   
   
   
    // 通用
    [self setMethod:WKPOINT_ME_COMMON handler:^id _Nullable(id  _Nonnull param) {
        return [WKMeItem initWithTitle:LLangW(@"通用",weakSelf) icon:[weakSelf imageName:@"Me/Index/IconSetting"] onClick:^{
             [[WKNavigationManager shared] pushViewController:[WKCommonSettingVC new] animated:YES];
        }];
    } category:WKPOINT_CATEGORY_ME sort:6000];
   
    
    // 截屏通知
    [[WKSDK shared].chatManager addMessageStoreBeforeIntercept:@"screent" intercept:^BOOL(WKMessage * _Nonnull message) {
        if(message.contentType == WK_SCREENSHOT) {
           WKChannelInfo *channelInfo =   [[WKSDK shared].channelManager getChannelInfo:message.channel];
            if(channelInfo) {
                if(![channelInfo settingForKey:WKChannelExtraKeyScreenshot defaultValue:YES]) {
                    return NO;
                }
            }
        }
        return YES;
    }];
   
}

#pragma mark - WKNetworkListenerDelegate

- (void)networkListenerStatusChange:(WKNetworkListener *)listener {
    // Network restored: refresh appconfig so the login page's Aegis SSO button
    // state recovers when the user was offline on app launch. Runs before the
    // `isLogined` early-return so the logged-out case is also covered.
    if(listener.hasNetwork) {
        [[self remoteConfig] refreshConfig:nil];
    }
    if(![[WKApp shared] isLogined]) {
        return;
    }
    WKLogDebug(@"网络发生变化...");
    if(listener.hasNetwork) {
        [[WKSDK shared].connectionManager connect];
    }else {
        [[WKSDK shared].connectionManager disconnect:YES];
    }
}

#pragma mark -- WKConnectionManagerDelegate

- (void)onConnectStatus:(WKConnectStatus)status reasonCode:(WKReason)reasonCode{
    if(![UIScreen mainScreen].isCaptured) {
        if(![WKApp shared].isLogined || ![WKMySettingManager shared].offlineProtection) {
            [self hiddenScreenProtect];
            return;
        }
    }
    
    if(status != WKConnected && reasonCode != WK_REASON_AUTHFAIL && reasonCode != WK_REASON_KICK) {
        [self performSelector:@selector(showScreenProtect) withObject:nil afterDelay:1.0f];
    }else {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showScreenProtect) object:nil];
        if(![UIScreen mainScreen].isCaptured) {
            [self hiddenScreenProtect];
        }
        
    }
}


// 显示锁屏保护 如果需要
-(void) showLockScreenProtectIfNeed {
    if(! [[WKApp shared] isLogined]) {
        return;
    }
    NSNumber *lockAfterMinute =  [WKApp shared].loginInfo.extra[@"lock_after_minute"]?:@(0);
    NSString *lockScreenPwd = [WKApp shared].loginInfo.extra[@"lock_screen_pwd"];
    BOOL lockScreenOn = false;
    if(lockScreenPwd && ![lockScreenPwd isEqualToString:@""]) {
        lockScreenOn = true;
    }
    if(lockScreenOn) {
        if(lockAfterMinute.integerValue>0) {
           NSNumber *enterBgTime = [WKApp shared].loginInfo.extra[@"enter_background_time"];
            if(enterBgTime && [[NSDate date] timeIntervalSince1970] - enterBgTime.integerValue>lockAfterMinute.integerValue*60) {
                [self showLockScreenProtect];
            }
        }else{
            [self showLockScreenProtect];
        }
    }
    [WKApp shared].loginInfo.extra[@"enter_background_time"] = @(0);
}
-(void) showLockScreenProtect {
    if(self.isShowLockScreenProtect) {
        return;
    }
    self.isShowLockScreenProtect = true;
    WKScreenPasswordVC *vc = [WKScreenPasswordVC new];
    vc.modalPresentationStyle  = UIModalPresentationFullScreen;
    __weak typeof(vc) weakVC = vc;
    __weak typeof(self) weakSelf = self;
    vc.onFinished = ^(NSString * _Nonnull pwd) {
        weakSelf.isShowLockScreenProtect = false;
        [weakVC dismissViewControllerAnimated:YES completion:nil];
    };
    [[WKNavigationManager shared].topViewController presentViewController:vc animated:NO completion:nil];
}

// ---------- 断网屏幕保护 ----------

- (WKScreenProtectionView *)screenProtectionView {
    if(!_screenProtectionView) {
        _screenProtectionView = [[WKScreenProtectionView alloc] init];
    }
    return _screenProtectionView;
}


-(void) showScreenProtectIfNeed {

    BOOL showProtect = false;
    if([WKMySettingManager shared].offlineProtection) {
        if( [UIScreen mainScreen].isCaptured) {
            showProtect = true;
        }else if([WKSDK shared].connectionManager.connectStatus != WKConnected) {
            showProtect = true;
        }
    }
    
    if(showProtect) {
        [self showScreenProtect];
    }
}

- (UIWindow*) findWindow {
    if(WKKeyboardService.shared.keyboardIsVisible) {
        for (UIWindow *win in [UIApplication sharedApplication].windows) {
            if([win isKindOfClass:NSClassFromString(@"UIRemoteKeyboardWindow")]) {
                return win;
            }
        }
    }
    
    
    return [UIApplication sharedApplication].keyWindow;
}
//
//- (UIView *)findKeyboard
//{
//    UIView *keyboardView = nil;
//    NSArray *windows = [[UIApplication sharedApplication] windows];
//    for (UIWindow *window in [windows reverseObjectEnumerator])//逆序效率更高，因为键盘总在上方
//    {
//        keyboardView = [self findKeyboardInView:window];
//        if (keyboardView)
//        {
//            return keyboardView;
//        }
//    }
//    return nil;
//}
//
//- (UIView *)findKeyboardInView:(UIView *)view
//{
//    for (UIView *subView in [view subviews])
//    {
//        NSLog(@" 打印信息:%s",object_getClassName(subView));
//        if (strstr(object_getClassName(subView), "UIInputSetHostView"))
//        {
//            return subView;
//        }
//        else
//        {
//            UIView *tempView = [self findKeyboardInView:subView];
//            if (tempView)
//            {
//                return tempView;
//            }
//        }
//    }
//    return nil;
//}

-(void) showScreenProtect {
    [self showScreenProtect:true];
}

-(void) hiddenScreenProtect {
    [self showScreenProtect:false];
}

-(void) showScreenProtect:(BOOL)show {
    if(show && self.isShowScreenProtect) {
        return;
    }
    self.isShowScreenProtect = show;
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if(show) {
        [window addSubview:self.screenProtectionView];
    }else{
        [self.screenProtectionView removeFromSuperview];
    }
    if(show) {
        [window endEditing:true];
    }
   
    
}

- (NSLock *)delegateLock {
    if (_delegateLock == nil) {
        _delegateLock = [[NSLock alloc] init];
    }
    return _delegateLock;
}

-(NSHashTable*) delegates {
    if (_delegates == nil) {
        _delegates = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    }
    return _delegates;
}

-(void) addDelegate:(id<WKAppDelegate>) delegate{
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates addObject:delegate];
    [self.delegateLock unlock];
}
- (void)removeDelegate:(id<WKAppDelegate>) delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates removeObject:delegate];
    [self.delegateLock unlock];
}


- (void)callAppLogoutDelegate {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(appLogout)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate appLogout];
                });
            }else {
                 [delegate appLogout];
            }
        }
    }
}
- (void)callAppLoginSuccessDelegate {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(appLoginSuccess)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate appLoginSuccess];
                });
            }else {
                 [delegate appLoginSuccess];
            }
        }
    }
}

-(void) addChannelAvatarUpdateNotify:(id)observer selector:(SEL)sel{
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:sel name:WKNOTIFY_CHANNEL_AVATAR_UPDATE object:nil];
}

-(void) removeChannelAvatarUpdateNotify:(id)observer {
    [[NSNotificationCenter defaultCenter] removeObserver:observer name:WKNOTIFY_CHANNEL_AVATAR_UPDATE object:nil];
}

-(void) notifyChannelAvatarUpdate:(WKChannel*)channel {
    [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_CHANNEL_AVATAR_UPDATE object:channel];
}

- (NSArray<WKSticker *> *)collectStickers {
    if(!_collectStickers) {
        _collectStickers = [NSArray array];
    }
    return _collectStickers;
}


// 根据需要加载收藏的表情
-(AnyPromise*) loadCollectStickersIfNeed {
    if(self.collectStickerRequested) {
        return [AnyPromise promiseWithValue:self.collectStickers];
    }
    __weak typeof(self) weakSelf = self;
   return [self loadCollectStickers].then(^(){
        weakSelf.collectStickerRequested = true;
   });
}

-(AnyPromise*) loadCollectStickers {
    __weak typeof(self) weakSelf = self;
   return [[WKAPIClient sharedClient] GET:@"sticker/user" parameters:nil model:WKSticker.class].then(^(NSArray *stickerArray) {
        weakSelf.collectStickers = stickerArray;
       return stickerArray;
    }).catch(^(NSError *error){
        NSLog(@"加载收藏的表情失败！");
    });
}

-(BOOL) isSystemAccount:(NSString*)uid {
    if([uid isEqualToString:self.config.fileHelperUID] || [uid isEqualToString:self.config.systemUID]) {
        return true;
    }
    return false;
}

#pragma mark - Share Extension

// PR #121 round 4 review 🟡: app group 由 OctoConfig.xcconfig 的 OCTO_APP_GROUP
// 注入到 Info.plist 的 OCTOAppGroup 字段。外部团队签名必须改成自己
// provision 过的 group，不允许 hardcode example-app 字符串。
// 默认回退保持 group.com.example.octo 仅用于本地构建。
static NSString *_OctoShareAppGroupId(void) {
    NSString *fromPlist = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"OCTOAppGroup"];
    if (fromPlist.length > 0 && ![fromPlist hasPrefix:@"$("]) {
        return fromPlist;
    }
    return @"group.com.example.octo";
}
static NSString *const kShareDataKey = @"WKShareExtensionData";
static NSString *const kShareDirName = @"ShareExtensionFiles";

-(void) handleShareExtensionData {
    if (![WKApp shared].isLogined) return;

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:_OctoShareAppGroupId()];
    NSArray *fileInfos = [shared objectForKey:kShareDataKey];
    if (!fileInfos || fileInfos.count == 0) return;

    // 清除数据，防止重复处理
    [shared removeObjectForKey:kShareDataKey];
    [shared synchronize];

    // 单选模式：点击会话弹确认面板，可附带文本
    WKForwardSelectVC *vc = [WKForwardSelectVC new];
    vc.title = LLang(@"选择聊天");
    vc.singleSelectMode = YES;
    vc.shareFileInfos = fileInfos;
    __weak typeof(self) weakSelf = self;
    [vc setOnSingleConfirm:^(WKChannel *channel, NSString *extraText) {
        [weakSelf sendShareFiles:fileInfos toChannel:channel extraText:extraText];
    }];

    // 先关闭所有 modal（如 PDF 浏览器），再 push 转发页面
    UIViewController *topVC = [WKNavigationManager shared].topViewController;
    if (topVC.presentedViewController) {
        [topVC dismissViewControllerAnimated:NO completion:^{
            [[WKNavigationManager shared] pushViewController:vc animated:YES];
        }];
    } else if (topVC) {
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
    }
}

-(void) sendShareFiles:(NSArray *)fileInfos toChannel:(WKChannel *)channel extraText:(NSString *)extraText {
    // 图文混排（RichText=14）：分享条目全为图片、且附带了文本时，聚合成单条 type=14
    // 消息（image blocks 按序在前 + text block 在后，沿用本入口「图在前文在后」的阅读
    // 顺序），而不是拆成多条独立消息。任一其它条目（file/video/audio/link/text）或无
    // 附带文本时仍走下方逐条发送路径，纯图/纯文/含文件零回归。
    NSString *trimmedExtra = [extraText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL hasText = trimmedExtra.length > 0;
    BOOL hasImage = NO;
    BOOL hasNonImage = NO;
    for (NSDictionary *info in fileInfos) {
        if ([info[@"type"] isEqualToString:@"image"]) {
            hasImage = YES;
        } else {
            hasNonImage = YES;
        }
    }
    if (hasText && hasImage && !hasNonImage) {
        [self sendRichTextMixedImages:fileInfos extraText:extraText toChannel:channel];
        return;
    }

    NSMutableArray<WKMessage *> *sentMessages = [NSMutableArray array];

    // 先发送文件/图片（文件在前，文本在后，符合阅读习惯）
    for (NSDictionary *info in fileInfos) {
        NSString *type = info[@"type"];

        if ([type isEqualToString:@"link"]) {
            // 链接分享：发送为 [链接] JSON 格式
            NSString *url = info[@"url"] ?: @"";
            NSString *title = info[@"title"] ?: @"";
            NSString *icon = info[@"icon"] ?: @"";
            NSDictionary *cardData = @{@"title": title, @"url": url, @"icon": icon};
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:cardData options:0 error:nil];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            NSString *content = [NSString stringWithFormat:@"[链接]%@", jsonStr];
            WKTextContent *textContent = [[WKTextContent alloc] initWithContent:content];
            WKMessage *msg = [[WKSDK shared].chatManager forwardMessage:textContent channel:channel];
            if (msg) [sentMessages addObject:msg];
        } else if ([type isEqualToString:@"text"]) {
            NSString *content = info[@"content"];
            if (content.length > 0) {
                WKTextContent *textContent = [[WKTextContent alloc] initWithContent:content];
                WKMessage *msg = [[WKSDK shared].chatManager forwardMessage:textContent channel:channel];
                if (msg) [sentMessages addObject:msg];
            }
        } else if ([type isEqualToString:@"image"]) {
            NSString *path = info[@"path"];
            if (path) {
                UIImage *image = [UIImage imageWithContentsOfFile:path];
                if (image) {
                    WKImageContent *imageContent = [WKImageContent initWithImage:image];
                    // 图片也是媒体消息，用 sendMessage 触发上传
                    WKMessage *msg = [[WKSDK shared].chatManager sendMessage:imageContent channel:channel];
                    if (msg) [sentMessages addObject:msg];
                }
            }
        } else {
            // 文件/视频/音频：先复制到 App 文档目录（共享目录会被清理，导致文件打不开）
            NSString *path = info[@"path"];
            if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
                NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
                NSString *shareDir = [docDir stringByAppendingPathComponent:@"ShareFiles"];
                [[NSFileManager defaultManager] createDirectoryAtPath:shareDir withIntermediateDirectories:YES attributes:nil error:nil];
                NSString *destPath = [shareDir stringByAppendingPathComponent:[path lastPathComponent]];
                // 避免重名
                if ([[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
                    NSString *name = [[path lastPathComponent] stringByDeletingPathExtension];
                    NSString *ext = [path pathExtension];
                    destPath = [shareDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@.%@", name, [[NSUUID UUID] UUIDString], ext]];
                }
                [[NSFileManager defaultManager] copyItemAtPath:path toPath:destPath error:nil];
                NSURL *fileURL = [NSURL fileURLWithPath:destPath];
                NSLog(@"[ShareExt] 文件已复制: src=%@ -> dest=%@, exists=%d, size=%lld",
                      path, destPath,
                      [[NSFileManager defaultManager] fileExistsAtPath:destPath],
                      [[[NSFileManager defaultManager] attributesOfItemAtPath:destPath error:nil] fileSize]);
                WKFileContent *fileContent = [WKFileContent initWithFileURL:fileURL];
                NSLog(@"[ShareExt] WKFileContent: name=%@, ext=%@, fileSize=%lld, dataLen=%lu",
                      fileContent.name, fileContent.fileExtension, fileContent.fileSize,
                      (unsigned long)[[fileContent valueForKey:@"fileData"] length]);
                // 文件消息必须用 sendMessage（会触发媒体上传），不能用 forwardMessage（直接发协议包，跳过上传）
                WKMessage *msg = [[WKSDK shared].chatManager sendMessage:fileContent channel:channel];
                NSLog(@"[ShareExt] sendMessage result: clientMsgNo=%@, status=%ld",
                      msg.clientMsgNo, (long)msg.status);
                if (msg) [sentMessages addObject:msg];
            }
        }
    }

    // 文件发完后立即发附带文本（orderSeq 已保持创建顺序，不会被 sendack 覆盖）
    if (extraText && extraText.length > 0) {
        WKTextContent *textContent = [[WKTextContent alloc] initWithContent:extraText];
        WKMessage *textMsg = [[WKSDK shared].chatManager forwardMessage:textContent channel:channel];
        if (textMsg) [sentMessages addObject:textMsg];
        NSLog(@"[ShareExt] 附带文本已发送: clientMsgNo=%@", textMsg.clientMsgNo);
    }

    // 统一通知聊天页面刷新
    NSLog(@"[ShareExt] 全部消息发送完成, channel=%@_%d, 消息数=%lu", channel.channelId, channel.channelType, (unsigned long)sentMessages.count);
    if (sentMessages.count > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"WKShareExtensionMessageSent" object:channel userInfo:@{@"messages": [sentMessages copy]}];
        });
    }

    [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"发送成功")];

    // 清理共享目录
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        NSURL *container = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:_OctoShareAppGroupId()];
        NSURL *dir = [container URLByAppendingPathComponent:kShareDirName];
        [[NSFileManager defaultManager] removeItemAtURL:dir error:nil];
    });
}

#pragma mark - 图文混排发送（RichText=14）

// 图文 URL scheme allowlist：仅 http/https 且 host 非空，阻断 javascript:/data:/
// file: 注入与无 host 的畸形 URL，与接收侧（octo-lib 契约 §1.4）对称。
static BOOL _WKRichTextIsSafeImageURL(NSString *url) {
    if (url.length == 0) return NO;
    NSURLComponents *c = [NSURLComponents componentsWithString:url];
    NSString *scheme = c.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return NO;
    return c.host.length > 0;
}

// 不解码整图、仅读图片元数据拿像素尺寸（避免 share 多图时整图解码撑爆内存）。
static CGSize _WKRichTextImagePixelSize(NSString *path) {
    CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
    if (!src) return CGSizeZero;
    CGSize size = CGSizeZero;
    NSDictionary *props = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(src, 0, NULL);
    NSNumber *w = props[(__bridge NSString *)kCGImagePropertyPixelWidth];
    NSNumber *h = props[(__bridge NSString *)kCGImagePropertyPixelHeight];
    if (w && h) size = CGSizeMake(w.doubleValue, h.doubleValue);
    CFRelease(src);
    return size;
}

/**
 * 图文混排发送：把分享的图片 + 附带文本聚合成单条 RichText(=14) 消息。
 *
 * 仅在「分享条目全为图片、且有附带文本」时由 sendShareFiles: 调用。schema 复用接收侧
 * #16 WKRichTextContent（imageBlock/textBlock/contentWithBlocks），wire-format 与
 * octo-lib 权威 schema 字节对齐。
 *
 * - 原子性：单条 RichText 是整体，任一图片上传失败 / URL 不安全 / 本地尺寸读取失败 →
 *   整条中止并提示，绝不「发一半」（契约 §5.1）。
 * - 图片尺寸取**本地文件**（与纯图片发送一致），不依赖刚上传的 downloadUrl，避免 CDN
 *   read-after-write 延迟导致 width/height=0 违反 image schema 必填>0。
 * - 上传成功后图片 URL 走 http/https allowlist 校验，与接收侧对称。
 * - plain 由 contentWithBlocks 本地填非本地化占位（image→[图片]），server #232 Finalize
 *   重算覆盖。
 * - 上传/网络在后台线程链式串行，全部就绪后回主线程构造并发送一条消息。
 */
-(void) sendRichTextMixedImages:(NSArray *)fileInfos extraText:(NSString *)extraText toChannel:(WKChannel *)channel {
    // 分享入口：终态清理拷进 App Group 的分享目录（成功/失败都清，与原逐条路径对称）。
    // 分享入口无输入框草稿，onFailure 传 nil（失败已由 HUD 提示）。
    // 分享入口没有活跃会话上下文（从系统分享面板拉起），无法走 context.sendMessage:，
    // 故 send 用 forwardMessage:（裸 save+send）+ 通知驱动列表插入——这是分享场景的既有
    // 行为，会话语义（回执/阅后即焚/topic 等）在分享入口本就不适用。
    [self sendRichTextMixedImages:fileInfos extraText:extraText toChannel:channel cleanup:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
            NSURL *container = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:_OctoShareAppGroupId()];
            NSURL *dir = [container URLByAppendingPathComponent:kShareDirName];
            [[NSFileManager defaultManager] removeItemAtURL:dir error:nil];
        });
    } onFailure:nil send:^(WKRichTextContent *content) {
        WKMessage *msg = [[WKSDK shared].chatManager forwardMessage:content channel:channel];
        if (msg) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"WKShareExtensionMessageSent" object:channel userInfo:@{@"messages": @[msg]}];
            });
        }
    }];
}

-(void) sendRichTextMixedImages:(NSArray *)fileInfos extraText:(NSString *)extraText toChannel:(WKChannel *)channel cleanup:(void(^)(void))cleanup onFailure:(void(^)(void))onFailure send:(void(^)(WKRichTextContent *content))send {
    UIView *topView = [WKNavigationManager shared].topViewController.view;
    [topView showHUD:LLang(@"发送中")];

    // 只挑出图片条目（调用方已保证全为图片，这里防御性再过滤一次）。
    NSMutableArray<NSDictionary *> *images = [NSMutableArray array];
    for (NSDictionary *info in fileInfos) {
        if ([info[@"type"] isEqualToString:@"image"]) {
            [images addObject:info];
        }
    }

    __weak typeof(self) weakSelf = self;
    // 串行上传每张图片，收集 image block；任一失败 → fail block 中止整条。
    NSMutableArray<WKRichTextBlock *> *imageBlocks = [NSMutableArray array];

    // 终态守卫：finish/fail 只允许触发一次。上传/promise 回调异步到达，已进入的回调
    // 可能在 uploadNext 置 nil 后仍调用 finish/fail，故用一次性 flag 拦截竞态。
    __block BOOL settled = NO;
    // uploadNext 自持有（completion block 强捕获自身，保证 async 回调期间链不被释放），
    // 终态显式置 nil 打破 retain cycle，避免泄漏。
    __block void (^uploadNext)(NSUInteger) = nil;

    // 终态清理：成功/失败都执行调用方注入的 cleanup（分享目录 / 临时文件），避免残留。
    void (^cleanupShareDir)(void) = ^{
        if (cleanup) cleanup();
    };

    void (^fail)(void) = ^{
        if (settled) return;
        settled = YES;
        // 退链（打破 uploadNext↔completion 的 retain cycle）必须推迟到主线程 async block 内：
        // fail/finish 经由 uploadNext 调到，此刻 uploadNext 往往是 fail/finish 自身唯一的强持有
        // 者；若在此处同步 `uploadNext = nil`，会把正在执行的 fail/finish 块（及其捕获的
        // cleanupShareDir/topView 等）当场释放，随后构造的 async block 捕获到的就是悬垂指针，
        // 异步执行到 cleanupShareDir() 时 call 野 block → EXC_BAD_ACCESS（崩在 block_invoke_2）。
        // 放进 async block：① 内层 block 独立 retain 住 cleanupShareDir/topView 等捕获，与
        // uploadNext 生命周期解耦；② 退链发生在 fail/finish 早已返回之后，绝不自释放执行中的块。
        dispatch_async(dispatch_get_main_queue(), ^{
            uploadNext = nil;
            [topView hideHud];
            [topView showHUDWithHide:LLang(@"发送失败")];
            // 失败先恢复草稿（图文聚合发送整条中止 → 文字不能丢），再清理临时资源。
            if (onFailure) onFailure();
            cleanupShareDir();
        });
    };

    // 全部图片就绪后：主线程构造单条 RichText 并通过调用方注入的 send 发送。
    // send 决定走哪条发送路径：分享入口 forwardMessage:（无会话上下文）；主聊天相册入口
    // [context sendMessage:]（保留全部会话语义）。本核心方法只负责「装配内容 + 终态收口」，
    // 不再硬编码 forwardMessage:，避免相册聚合路径绕过会话发送装饰（footgun 修复核心）。
    void (^finish)(void) = ^{
        if (settled) return;
        settled = YES;
        // 退链推迟到主线程 async block 内（同 fail 注释的根因）：在此处同步 `uploadNext = nil`
        // 会释放正在执行的 finish 块本体，其捕获的 cleanupShareDir/topView 等随之悬垂，async
        // block 异步执行到 2306 `cleanupShareDir()` 时 call 野 block → EXC_BAD_ACCESS。
        dispatch_async(dispatch_get_main_queue(), ^{
            uploadNext = nil;
            NSMutableArray<WKRichTextBlock *> *blocks = [imageBlocks mutableCopy];
            [blocks addObject:[WKRichTextContent textBlock:extraText]];
            WKRichTextContent *content = [WKRichTextContent contentWithBlocks:blocks];
            // 异步收尾时 topViewController 可能已切换（用户发完立即退会话/切频道），topView 与
            // 当前 topViewController.view 已不是同一个；hideHud/showHUD 都用捕获的 topView 快照，
            // 不再二次取 [WKNavigationManager shared].topViewController.view，避免对已易主的 UI
            // 误操作。topView 为 strong 捕获，async 执行期间稳定存活，nil 时消息无副作用。
            [topView hideHud];
            [topView showHUDWithHide:LLang(@"发送成功")];
            if (send) send(content);
            cleanupShareDir();
        });
    };

    uploadNext = ^(NSUInteger index) {
        if (index >= images.count) {
            finish();
            return;
        }
        NSDictionary *info = images[index];
        NSString *path = info[@"path"];
        if (path.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            fail();
            return;
        }
        // 1. 仅读图片元数据拿像素尺寸（schema 必填>0，不受 CDN 延迟影响；不整图解码，
        //    避免 share 多图时内存峰值把扩展进程拉爆）。
        CGSize px = _WKRichTextImagePixelSize(path);
        NSInteger w = (NSInteger)lround(px.width);
        NSInteger h = (NSInteger)lround(px.height);
        if (w <= 0 || h <= 0) {
            fail();
            return;
        }
        // 文件字节大小走 NSFileManager 属性，不把整图读进内存。
        NSNumber *sizeNum = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil][NSFileSize];
        NSInteger fileSize = sizeNum.integerValue;
        NSString *fileName = [path lastPathComponent];
        NSString *ext = [[path pathExtension] lowercaseString];
        if (ext.length == 0) ext = @"jpg";
        NSString *contentType = [weakSelf richTextMimeForExtension:ext];
        NSString *uuid = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
        NSString *objectKey = [NSString stringWithFormat:@"/%d/%@/%@.%@", channel.channelType, channel.channelId, uuid, ext];

        // 2. 取凭证 → PUT 直传 → 拿 downloadUrl（与 WKFileUploadTask / sticker 同套两步）。
        AnyPromise *credPromise = [[WKAPIClient sharedClient] getUploadCredentialsForPath:objectKey
                                                                                     type:@"chat"
                                                                                 filename:fileName
                                                                              contentType:contentType
                                                                                 fileSize:(long long)fileSize];
        credPromise.then(^(NSDictionary *result){
            NSString *uploadUrl = result[@"uploadUrl"];
            NSString *downloadUrl = result[@"downloadUrl"];
            NSString *signedContentType = result[@"contentType"] ?: contentType;
            NSString *contentDisposition = result[@"contentDisposition"];
            if (uploadUrl.length == 0 || downloadUrl.length == 0) {
                fail();
                return;
            }
            NSURLSessionUploadTask *task = [[WKAPIClient sharedClient]
                createFileUploadPutTask:uploadUrl
                                fileURL:path
                            contentType:signedContentType
                     contentDisposition:contentDisposition
                               progress:nil
                       completeCallback:^(NSInteger statusCode, NSError * _Nullable error) {
                           if (error) {
                               fail();
                               return;
                           }
                           // 3. 安全：图片 URL 走 http/https allowlist，与接收侧对称。
                           if (!_WKRichTextIsSafeImageURL(downloadUrl)) {
                               fail();
                               return;
                           }
                           [imageBlocks addObject:[WKRichTextContent imageBlock:downloadUrl
                                                                          width:w
                                                                         height:h
                                                                           size:fileSize
                                                                           name:fileName]];
                           // 强捕获 uploadNext：async 回调期间保持链存活（终态会置 nil）。
                           if (uploadNext) {
                               uploadNext(index + 1);
                           }
                       }];
            if (task) {
                [task resume];
            } else {
                fail();
            }
        }).catch(^(NSError *error){
            fail();
        });
    };
    uploadNext(0);
}

// 由扩展名取 MIME（与 sticker 上传一致），用于上传凭证 contentType。
- (NSString *)richTextMimeForExtension:(NSString *)ext {
    if ([ext isEqualToString:@"png"])  return @"image/png";
    if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"]) return @"image/jpeg";
    if ([ext isEqualToString:@"gif"])  return @"image/gif";
    if ([ext isEqualToString:@"webp"]) return @"image/webp";
    if ([ext isEqualToString:@"heic"]) return @"image/heic";
    return @"image/jpeg";
}

// 由图片二进制内容嗅探扩展名（相册回调给的是已压缩 NSData，没有文件名/路径）。
// 用于构造临时文件名与上传 MIME，未知格式回退 jpg（与上传 MIME 默认一致）。
static NSString *_WKRichTextExtForImageData(NSData *data) {
    SDImageFormat fmt = [NSData sd_imageFormatForImageData:data];
    switch (fmt) {
        case SDImageFormatPNG:  return @"png";
        case SDImageFormatGIF:  return @"gif";
        case SDImageFormatWebP: return @"webp";
        case SDImageFormatHEIC:
        case SDImageFormatHEIF: return @"heic";
        case SDImageFormatJPEG:
        default:                return @"jpg";
    }
}

+ (BOOL)shouldAggregateAlbumImagesWithText:(BOOL)allImages
                                assetCount:(NSUInteger)assetCount
                               pendingText:(NSString *)pendingText {
    if (!allImages || assetCount == 0) return NO;
    // 决策基于用户实际选中的图片资产数（assetCount），不看压缩结果数：只要选了图且输入框
    // 有非空白文本就接管。绝不能因压缩丢图退回原逐条路径——否则文本被原路径丢掉（#21
    // footgun），且原 loop 会按 assets 下标索引压缩后的 images 数组越界崩溃。压缩丢图的
    // 原子性校验在 sendRichTextMixedImageDatas: 内做（imageDatas.count != assetCount →
    // 整条失败 + 恢复草稿）。
    NSString *trimmed = [pendingText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length > 0;
}

-(void) sendRichTextMixedImageDatas:(NSArray<NSData*>*)imageDatas
                         assetCount:(NSUInteger)assetCount
                          extraText:(NSString*)extraText
                          inContext:(id<WKConversationContext>)context
                          onFailure:(void(^)(void))onFailure {
    [self sendRichTextMixedImageDatas:imageDatas
                            assetCount:assetCount
                             extraText:extraText
                              mentions:nil
                              entities:nil
                         mentionedInfo:nil
                             inContext:context
                             onFailure:onFailure];
}

-(void) sendRichTextMixedImageDatas:(NSArray<NSData*>*)imageDatas
                         assetCount:(NSUInteger)assetCount
                          extraText:(NSString*)extraText
                           mentions:(NSArray<WKInputMentionItem*>*)mentions
                           entities:(NSArray<WKMessageEntity*>*)entities
                      mentionedInfo:(WKMentionedInfo*)mentionedInfo
                          inContext:(id<WKConversationContext>)context
                          onFailure:(void(^)(void))onFailure {
    // 主聊天「相册选图 + 输入框有文本」：先把每张已压缩图片落临时文件（上传链路与分享
    // 入口共用，按文件路径走，不依赖内存里的 NSData），再聚合成单条 RichText(=14)。
    // 失败统一收口：弹「发送失败」HUD + 回调 onFailure 恢复草稿（文字绝不静默丢）。
    // selectCompressImageBlock 可能在后台压缩回调线程触发本方法，UI/草稿恢复一律切主线程。
    void (^failEarly)(void) = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"发送失败")];
            if (onFailure) onFailure();
        });
    };

    NSString *trimmed = [extraText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // 原子性闸门（Critical 2）：无文本/无图/无上下文，或压缩阶段丢了图
    // （imageDatas.count != assetCount）→ 整条失败，绝不只发部分图。
    if (trimmed.length == 0 || imageDatas.count == 0 || context == nil || imageDatas.count != assetCount) {
        failEarly();
        return;
    }

    NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                        [NSString stringWithFormat:@"richtext-album-%@", [[NSUUID UUID] UUIDString]]];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:nil];

    // 原子性（Critical 2）：每一张选中图都必须有非空数据且成功落盘，任一张失败 → 整条
    // 中止、清理临时目录、恢复草稿。绝不静默丢掉失败那张只发其余（违反原子性声明）。
    NSMutableArray<NSDictionary *> *fileInfos = [NSMutableArray array];
    BOOL allWritten = YES;
    for (NSUInteger i = 0; i < imageDatas.count; i++) {
        NSData *data = imageDatas[i];
        if (data.length == 0) { allWritten = NO; break; }
        NSString *ext = _WKRichTextExtForImageData(data);
        NSString *fileName = [NSString stringWithFormat:@"image_%lu.%@", (unsigned long)i, ext];
        NSString *path = [tmpDir stringByAppendingPathComponent:fileName];
        if ([data writeToFile:path atomically:YES]) {
            [fileInfos addObject:@{@"type": @"image", @"path": path}];
        } else {
            allWritten = NO;
            break;
        }
    }

    // 任一图片数据为空或落盘失败：整条中止，恢复草稿（文字绝不丢），清理临时目录后返回。
    if (!allWritten || fileInfos.count != imageDatas.count) {
        [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:nil];
        failEarly();
        return;
    }

    // 终态清理：删整个临时目录（成功/失败都执行），与分享入口清理对称；失败时回调
    // onFailure 让调用方恢复输入框草稿。
    // send：相册入口在活跃会话上下文内发送，走 [context sendMessage:]——与原相册单图发送
    // 同一路径，保留回执/阅后即焚 expiry/spaceId/父子频道 topic/reply 元数据/本地
    // tracing + 列表插入等全部会话语义（Critical 1 修复核心：不走 forwardMessage: 绕过）。
    [self sendRichTextMixedImages:fileInfos extraText:extraText toChannel:context.channel cleanup:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
            [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:nil];
        });
    } onFailure:onFailure send:^(WKRichTextContent *content) {
        // caption 上的 @人/@AI：装到 RichText 顶层的 WKMessageContent.entities / mentionedInfo
        // —— 与 WKTextContent 走同一份序列化路径（base class 的 encodeMentionInfo:），
        // server / 对端按既有 mention.uids / humans / ais / entities 协议处理，与文本消息对齐。
        if (entities.count > 0) {
            content.entities = entities;
        }
        if (mentionedInfo) {
            content.mentionedInfo = mentionedInfo;
        }
        [context sendMessage:content];
    }];
}


-(UIImage*) imageName:(NSString*)name {
    return [self loadImage:name moduleID:@"WuKongBase"];
}

/// 程序化绘制"创建分组"图标（columns-2: 圆角矩形 + 竖线）
+ (UIImage *)createCategoryIcon {
    CGSize size = CGSizeMake(24, 24);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return nil;

    UIColor *color = [UIColor colorWithWhite:0.2 alpha:1.0];
    [color setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    // 圆角矩形 (x=3, y=3, w=18, h=18, rx=2)
    UIBezierPath *rect = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 3, 18, 18) cornerRadius:2];
    rect.lineWidth = 1.5;
    [rect stroke];

    // 竖线 (x=12, y1=3, y2=21)
    CGContextMoveToPoint(ctx, 12, 3);
    CGContextAddLineToPoint(ctx, 12, 21);
    CGContextStrokePath(ctx);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end


// 扩展字段的key
NSString * const WKChannelExtraKeyScreenshot = @"screenshot"; // 截屏通知
NSString * const WKChannelExtraKeyShortNo = @"short_no"; // 短编码
NSString * const  WKChannelExtraKeyForbiddenAddFriend = @"forbidden_add_friend"; // 禁止互加好友
NSString * const WKChannelExtraKeyJoinGroupRemind = @"join_group_remind"; // 进群提醒
NSString * const WKChannelExtraKeyChatPwd = @"chat_pwd_on"; // 聊天密码
NSString * const WKChannelExtraKeySource = @"source"; // 来源
NSString * const WKChannelExtraKeyVercode = @"vercode"; // 加好友验证码
NSString * const WKChannelExtraKeyAllowViewHistoryMsg = @"allow_view_history_msg"; // 允许新成员查看群历史消息
NSString * const WKChannelExtraKeyRemark = @"remark"; // 备注
