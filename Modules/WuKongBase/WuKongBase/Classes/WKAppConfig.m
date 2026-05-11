//
//  WKAppConfig.m
//  WuKongBase
//
//  Created by tt on 2021/8/25.
//

#import "WKAppConfig.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import <ZLPhotoBrowser/ZLPhotoBrowser-Swift.h>


@interface WKAppConfig ()

@property(nonatomic,assign) WKSystemStyle innerStyle;
@property(nonatomic,strong) NSNumber *innerdarkModeWithSystem;

@property(nonatomic,copy) NSString  *innerLangue;
@property(nonatomic,copy) NSString *innerReportUrl;

@end

@implementation WKAppConfig


-(instancetype) init {
    self = [super init];
    if(self) {
        self.appName = @"Octo";
        self.shortName = @"Octo ID";
        self.appID = @""; // appstore的id
        self.appSchemaPrefix = @"wukong";
        self.clusterOn = YES;
        
         // ---------- 基础配置 ----------
        self.themeColor = [UIColor colorWithRed:119.0f/255.0f green:97.0f/255.0f blue:244.0f/255.0f alpha:1.0]; // #7761F4
        self.backgroundColor = [self navBackgroudColorWithAlpha:1.0f];
        self.footerTipFontSize = 12.0f;
        self.defaultAvatar = [self imageName:@"Common/Index/DefaultAvatar"];
        self.defaultPlaceholder = [self placeholderImageWithSize:CGSizeMake(114.0f, 114.0f) image:[self imageName:@"Common/Index/Placeholder"]];
        
        self.defaultStickerPlaceholder = [self placeholderImageWithSize:CGSizeMake(114.0f, 114.0f) image:[self imageName:@"Common/Index/Placeholder"]];
        
        self.defaultTextColor = [UIColor colorWithRed:49.0f/255.0f green:49.0f/255.0f blue:49.0f/255.0f alpha:1.0f];
        self.imageCacheDir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"image"];
        
        self.fileStorageDir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"wukongfiles"];
        
        self.imageMaxLimitBytes = 1024 * 500;
        
        self.warnColor = [UIColor colorWithRed:200.0f/255.0f green:70.0f/255.0f blue:70.0f/255.0f alpha:1.0f];
        self.defaultFont = [self appFontOfSize:16.0f];
         // ---------- 消息相关 ----------
        self.messageTextFontSize = 16.0f;
        self.messageTipTimeFontSize = 14.0f;
        self.messageAvatarSize = CGSizeMake(40.0f, 40.0f);
        self.smallAvatarSize = CGSizeMake(24.0f, 24.0f);
        self.middleAvatarSize = CGSizeMake(48.0f, 48.0f);
        self.bigAvatarSize = CGSizeMake(96.0f, 96.0f);
        self.messageListAvatarSize =  CGSizeMake(64.0f, 64.0f);
        self.messageContentMaxWidth = WKScreenWidth - (10.0f + self.messageAvatarSize.width + 10.0f) * 2;
        self.systemMessageContentMaxWidth = WKScreenWidth - 60.0f;
        self.messageTipColor = [UIColor colorWithRed:255.0f/255.0f green:255.0f/255.0f blue:255.0f/255.0f alpha:0.5f];
        self.unkownMessageText = @"[不支持的消息类型，或许可升级版本后查看]";
        self.signalErrorMessageText = @"[消息无法解密，因为双方密钥有发送变更]";
        self.messageTipTimeInterval = 60 * 5;
        self.messageTextMaxBytes = 1024*10;
        
        // ---------- 导航栏相关 ----------
//        self.navBarButtonColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
        self.navBarTitleFont =  [self appFontOfSizeMedium:17.0f];
        self.navBackgroudColor =[self navBackgroudColorWithAlpha:1.0f];
        self.settingMemberAvatarSize = CGSizeMake(32.0f, 32.0f);
        self.tipColor = [UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0f];
        self.navHeight = 44.0f + [UIApplication sharedApplication].statusBarFrame.size.height;
        
        // 数据每页默认请求大小
        self.pageSize = 20;
        // 每页消息数量
        self.eachPageMsgLimit = 30;
        CGRect statusFrame = [UIApplication sharedApplication].statusBarFrame;
        if (@available(iOS 11.0, *)) {
            UIEdgeInsets safeAreaInsets = [UIApplication sharedApplication].keyWindow.safeAreaInsets;
            UIEdgeInsets insets = UIEdgeInsetsMake(statusFrame.origin.y+statusFrame.size.height, 0.0f, safeAreaInsets.bottom, 0.0f);
            self.visibleEdgeInsets = insets;
        }
        
        self.inviteMsg = [NSString stringWithFormat:@"我正在使用【%@】app，体验还不错。你也赶快来下载玩玩吧！https://www.githubim.cn",self.appName];
        NSString *tempDir= NSTemporaryDirectory();
        self.videoCacheDir = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"wukong_video_cache"]];
        [WKFileUtil createDirectoryIfNotExist: self.videoCacheDir];
        
        self.systemUID = @"u_10000";
        self.fileHelperUID = @"fileHelper";
        self.botfatherUID = @"botfather";
        // YUJ-219-A4: default when backend appconfig.system_bot_uids is missing
        // (e.g. A2 backend not deployed). Keep these three UIDs treated as
        // system bots so per-Space filtering still works locally.
        self.systemBotUIDs = @[@"botfather", @"u_10000", @"fileHelper"];
        
        self.contextMenu = [[WKThemeContextMenu alloc] init];
        
        self.defaultAnimationDuration = 0.25f;
    }
    return self;
}

- (void)setStyle:(WKSystemStyle)style {
    _innerStyle = style;
    if(style == WKSystemStyleDark) {
        [WKApp shared].loginInfo.extra[@"systemStyle"] = @"dark";
        [[WKApp shared].loginInfo save];
        if (@available(iOS 13.0, *)) {
            [UIApplication sharedApplication].statusBarStyle =   UIStatusBarStyleLightContent;
            [UIApplication sharedApplication].keyWindow.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        }
    }else {
        [WKApp shared].loginInfo.extra[@"systemStyle"] = @"light";
        [[WKApp shared].loginInfo save];
        if (@available(iOS 13.0, *)) {
            [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDarkContent;
            [UIApplication sharedApplication].keyWindow.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WK_NOTIFY_STYLE_CHANGE" object:nil];
}

- (NSString *)bundleID {
    if(!_bundleID) {
        _bundleID =  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    }
    return _bundleID;
}

- (WKSystemStyle)style {
    if(_innerStyle == WKSystemStyleUnknown) {
       NSString *mode = [WKApp shared].loginInfo.extra[@"systemStyle"];
        if(mode && [mode isEqualToString:@"dark"]) {
            _innerStyle = WKSystemStyleDark;
        }else {
            _innerStyle = WKSystemStyleLight;
        }
    }
    return _innerStyle;
}

- (UIColor *)lineColor {
    
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:16.0f/255.0f green:16.0f/255.0f blue:16.0f/255.0f alpha:1.0f];
            }
            return  [UIColor colorWithRed:243/255.0 green:243/255.0 blue:243/255.0 alpha:1.0];
        }];
    } else {
        return  [UIColor colorWithRed:243/255.0 green:243/255.0 blue:243/255.0 alpha:1.0];
    }
    
}

// 跟随系统
- (BOOL)darkModeWithSystem {
    if(!self.innerdarkModeWithSystem) {
        NSString *darkModeWithSystem = [WKApp shared].loginInfo.extra[@"darkModeWithSystem"];
        if((darkModeWithSystem && [darkModeWithSystem isEqualToString:@"on"]) || !darkModeWithSystem || [darkModeWithSystem isEqualToString:@""]) {
            self.innerdarkModeWithSystem = @(true);
        }
    }
   
    return self.innerdarkModeWithSystem.boolValue;
    
}

- (void)setDarkModeWithSystem:(BOOL)darkModeWithSystem {
    self.innerdarkModeWithSystem = @(darkModeWithSystem);
    
    [WKApp shared].loginInfo.extra[@"darkModeWithSystem"] = darkModeWithSystem?@"on":@"off";
    [[WKApp shared].loginInfo save];
}

- (UIColor *)navBackgroudColor {
    
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:16.0f/255.0f green:16.0f/255.0f blue:16.0f/255.0f alpha:1.0f];
            }
            return self->_navBackgroudColor;
        }];
    } else {
        return _navBackgroudColor;
    }
}

- (UIColor *)backgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:16.0f/255.0f green:16.0f/255.0f blue:16.0f/255.0f alpha:1.0f];
            }
            return self->_backgroundColor;
        }];
    } else {
        return _backgroundColor;
    }
}

- (UIColor *)cellBackgroundColor {
    
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor secondarySystemBackgroundColor];
            }
            return [UIColor whiteColor];;
        }];
    } else {
        return [UIColor whiteColor];
    }
}

- (UIColor *)defaultTextColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:208.0f/255.0f green:209.0f/255.0f blue:210.0f/255.0f alpha:1.0f];
            }
            return self->_defaultTextColor;
        }];
    } else {
        return _defaultTextColor;
    }
    
}
- (UIColor *)navBarTitleColor {
    if(!_navBarTitleColor) {
        return [self defaultTextColor];
    }
    return _navBarTitleColor;
}

- (UIColor *)navBarSubtitleColor {
    if(!_navBarSubtitleColor) {
        return [self tipColor];
    }
    return _navBarSubtitleColor;
}

- (UIColor *)navBarButtonColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return   [UIColor whiteColor];
            }
            return [UIColor colorWithRed:49.0f/255.0f green:49.0f/255.0f blue:49.0f/255.0f alpha:1.0f];
        }];
    } else {
        return [UIColor colorWithRed:49.0f/255.0f green:49.0f/255.0f blue:49.0f/255.0f alpha:1.0f];
    }
}


- (UIColor *)messageSendTextColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return   [UIColor colorWithRed:250.0f/255.0f green:250.0f/255.0f blue:250.0f/255.0f alpha:1.0f];
            }
            return [UIColor colorWithRed:250.0f/255.0f green:250.0f/255.0f blue:250.0f/255.0f alpha:1.0f];
        }];
    } else {
        return [UIColor colorWithRed:250.0f/255.0f green:250.0f/255.0f blue:250.0f/255.0f alpha:1.0f];
    }
}
- (UIColor *)messageRecvTextColor {
    
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark || self.style == WKSystemStyleDark) {
                return  [UIColor colorWithRed:250.0f/255.0f green:250.0f/255.0f blue:250.0f/255.0f alpha:1.0f];
            }
            return   [UIColor colorWithRed:49.0f/255.0f green:49.0f/255.0f blue:49.0f/255.0f alpha:1.0f];
        }];
    } else {
        return   [UIColor colorWithRed:49.0f/255.0f green:49.0f/255.0f blue:49.0f/255.0f alpha:1.0f];
    }
}

- (void)setReportUrl:(NSString *)reportUrl {
    _innerReportUrl = reportUrl;
}

- (NSString *)reportUrl {
    if(_innerReportUrl) {
        if([_innerReportUrl containsString:@"?"]) {
            return [NSString stringWithFormat:@"%@&lang=%@&uid=%@&token=%@&mode=%@",_innerReportUrl,self.langue,[WKApp shared].loginInfo.uid,[WKApp shared].loginInfo.token,self.style==WKSystemStyleDark?@"dark":@"light"];
        }
        return [NSString stringWithFormat:@"%@?lang=%@&uid=%@&token=%@&mode=%@",_innerReportUrl,self.langue,[WKApp shared].loginInfo.uid,[WKApp shared].loginInfo.token,self.style==WKSystemStyleDark?@"dark":@"light"];
    }
    return _innerReportUrl;
}


/**
 传入需要的占位图尺寸 获取占位图

 @param size 需要的站位图尺寸
 @return 占位图
 */
- (UIImage *)placeholderImageWithSize:(CGSize)size image:(UIImage*)image{
    
    // 占位图的背景色
    UIColor *backgroundColor = [UIColor whiteColor];
    // 根据占位图需要的尺寸 计算 中间LOGO的宽高
    CGFloat logoWH = (size.width > size.height ? size.height : size.width) * 0.5;
    CGSize logoSize = CGSizeMake(logoWH, logoWH);
    // 打开上下文
    UIGraphicsBeginImageContextWithOptions(size,0, [UIScreen mainScreen].scale);
    // 绘图
    [backgroundColor set];
    UIRectFill(CGRectMake(0,0, size.width, size.height));
    CGFloat imageX = (size.width / 2) - (logoSize.width / 2);
    CGFloat imageY = (size.height / 2) - (logoSize.height / 2);
    [image drawInRect:CGRectMake(imageX, imageY, logoSize.width, logoSize.height)];
    UIImage *resImage =UIGraphicsGetImageFromCurrentImageContext();
    // 关闭上下文
    UIGraphicsEndImageContext();
    
    return resImage;
    
}

-(UIFont*) appFontOfSize:(CGFloat)size {
    return [UIFont fontWithName:@"PingFangSC-Regular" size:size];
}
-(UIFont*) appFontOfSizeSemibold:(CGFloat)size {
    return [UIFont fontWithName:@"PingFangSC-Semibold" size:size];
}
-(UIFont*) appFontOfSizeMedium:(CGFloat)size {
    return [UIFont fontWithName:@"PingFangSC-Medium" size:size];
}

- (NSString *)fileBrowseUrl {
    if(!_fileBrowseUrl) {
        return _fileBaseUrl;
    }
    return _fileBrowseUrl;
}

-(NSString*) scanURLPrefix {
    if(!_scanURLPrefix) {
        return [NSString stringWithFormat:@"%@%@",_apiBaseUrl,@"qrcode/"];
    }
    return _scanURLPrefix;
}
-(UIImage*) imageName:(NSString*)name {
//    NSBundle *bundle = [WKResource.shared imageBundleInClass:self.class];
    return [WKResource.shared imageNamed:name inClass:self.class];
//    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

- (UIColor *)navBackgroudColorWithAlpha:(CGFloat) alpha{
    
    return  [UIColor colorWithRed:246.0f/255.0f green:246.0f/255.0f blue:246.0f/255.0f alpha:alpha];
}

//    zh-Hans 中文 en 英语  俄罗斯语  ru  蒙古语 mn  bo-CN 藏语   fr 法语
//    kk-KZ 哈萨克语
//    tk-TM 土耳其语  ky-KG 柯尔克孜 ug 维吾尔语
//    it-CH 意大利语简称
- (NSString *)langue {
    if(!_innerLangue) {
        NSString *lang = [[NSUserDefaults standardUserDefaults] objectForKey:@"lim_langue"];
        if(!lang || [lang isEqualToString:@""]) {
            return @"zh-Hans";
        }
        _innerLangue = lang;
    }
    return _innerLangue;
}

- (void)setLangue:(NSString *)langue {
    BOOL needNotify = false;
    if(!_innerLangue && langue) {
        needNotify = true;
    }
    if(_innerLangue && langue && ![_innerLangue isEqualToString:langue]) {
        needNotify = true;
    }
    _innerLangue = langue;
    [[NSUserDefaults standardUserDefaults] setObject:langue forKey:@"lim_langue"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if(needNotify) {
        [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_LANG_CHANGE object:nil];
    }
    if(langue && [langue isEqualToString:@"zh-Hans"]) {
        [ZLPhotoUIConfiguration default].languageType = ZLLanguageTypeChineseSimplified;
    }else{
        [ZLPhotoUIConfiguration default].languageType = ZLLanguageTypeEnglish;
    }
    
}

-(void) setThemeStyleButton:(UIButton*)btn {
//    NSString *name = @"btn_theme_layer";
//    CAGradientLayer *gl = [CAGradientLayer layer];
//    gl.name = name;
//    gl.frame =btn.bounds;
//    gl.startPoint = CGPointMake(0, 0);
//    gl.endPoint = CGPointMake(1, 1);
//    if(self.style == WKSystemStyleDark) {
//        gl.colors = @[(__bridge id)[UIColor colorWithRed:63/255.0 green:64/255.0 blue:185/255.0 alpha:1.0].CGColor, (__bridge id)[UIColor colorWithRed:113/255.0 green:68/255.0 blue:178/255.0 alpha:1.0].CGColor];
//        gl.locations = @[@(0), @(1.0f)];
//    }else {
//        gl.colors = @[(__bridge id)[UIColor colorWithRed:78/255.0 green:80/255.0 blue:252/255.0 alpha:1.0].CGColor, (__bridge id)[UIColor colorWithRed:149/255.0 green:85/255.0 blue:241/255.0 alpha:1.0].CGColor];
//        gl.locations = @[@(0), @(1.0f)];
//    }
//
//    NSArray<CALayer*> *layers = [btn.layer sublayers];
//    if(layers) {
//        for (CALayer *layer in layers) {
//            if(layer.name && [layer.name isEqualToString:name]) {
//                [layer removeFromSuperlayer];
//                break;
//            }
//        }
//    }
//    [btn.layer insertSublayer:gl atIndex:0];
}

-(void) setThemeStyleNavigation:(UIView*)view {
//    NSString *name = @"btn_theme_layer";
//    CAGradientLayer *gl = [CAGradientLayer layer];
//    gl.name = name;
//    gl.frame =view.bounds;
//    gl.startPoint = CGPointMake(0, 0);
//    gl.endPoint = CGPointMake(1, 1);
//    if(self.style == WKSystemStyleDark) {
//        gl.colors = @[(__bridge id)[UIColor colorWithRed:63/255.0 green:64/255.0 blue:185/255.0 alpha:1.0].CGColor, (__bridge id)[UIColor colorWithRed:113/255.0 green:68/255.0 blue:178/255.0 alpha:1.0].CGColor];
//        gl.locations = @[@(0), @(1.0f)];
//    }else {
//        gl.colors = @[(__bridge id)[UIColor colorWithRed:78/255.0 green:80/255.0 blue:252/255.0 alpha:1.0].CGColor, (__bridge id)[UIColor colorWithRed:149/255.0 green:85/255.0 blue:241/255.0 alpha:1.0].CGColor];
//        gl.locations = @[@(0), @(1.0f)];
//    }
//
//    NSArray<CALayer*> *layers = [view.layer sublayers];
//    if(layers) {
//        for (CALayer *layer in layers) {
//            if(layer.name && [layer.name isEqualToString:name]) {
//                [layer removeFromSuperlayer];
//                break;
//            }
//        }
//    }
//    [view.layer insertSublayer:gl atIndex:0];
}


@end

@interface WKAppRemoteConfig ()

@property(nonatomic,assign) BOOL startRequest;

@property(nonatomic,assign) BOOL startRequestAppModule;

/// 入队等 config 请求完成的 callback 队列（YUJ-396 R3 / Jerry-Xin #112 warning）。
/// 老实现 startRequest==YES 时会丢掉后来者的 callback; 现在统一用一个队列,
/// 请求完成（成功 / 失败）时一次性 drain。线程语义: 调用点基本是 main thread（UI
/// 入口），但防御性地加 @synchronized(self) 保证跨线程安全。
@property(nonatomic,strong) NSMutableArray<void(^)(NSError * __nullable)> *pendingConfigCallbacks;

@end

@implementation WKAppRemoteConfig

// Cache key for oidc_providers raw array（王立涛 develop_fix commit 625cc7c 引入）。
// Hydrate at init 让登录页冷启动的 first frame 即可渲染 SSO 按钮,
// 不必等 appconfig API 返回。2026-05-11 阶段 1.2 合并 develop_fix 后
// 实现采用 王立涛的缓存语义 + develop (YUJ-396) 的强类型 parseArray:。
static NSString * const kOidcProvidersCacheKey = @"WKOidcProvidersCacheV1";

- (instancetype)init {
    if(self = [super init]) {
        // YUJ-396: 冷启动 appconfig 未到时不能是 nil, 否则调用侧需要 nil-check。
        // 空数组语义即「没有可用 provider」, 实名认证入口走 toast 兜底。
        _oidcProviders = @[];
        _pendingConfigCallbacks = [NSMutableArray array];
        // 从持久化缓存 hydrate oidcProviders（王立涛 develop_fix commit 625cc7c 引入）:
        // 登录页 first frame 即可渲染 SSO 按钮, 不用等 appconfig 请求返回。
        // requestConfig: 成功后会覆盖为最新数据。
        NSArray *cachedRaw = [[NSUserDefaults standardUserDefaults] arrayForKey:kOidcProvidersCacheKey];
        if([cachedRaw isKindOfClass:[NSArray class]]) {
            NSArray<WKOidcProviderConfig*> *cached = [WKOidcProviderConfig parseArray:cachedRaw];
            if(cached.count > 0) {
                _oidcProviders = cached;
            }
        }
    }
    return self;
}

/// Drain + fire 所有入队的 config 请求 callback, 传入最终结果 error (nil 成功)。
/// 在请求的 then/catch 终点调用一次。拷出后清空队列再逐个 fire, 避免回调里再
/// 调 requestConfig: 进入再入风险。
- (void)_fireAndClearPendingConfigCallbacks:(NSError * _Nullable)error {
    NSArray<void(^)(NSError * _Nullable)> *callbacks;
    @synchronized(self) {
        callbacks = [self.pendingConfigCallbacks copy];
        [self.pendingConfigCallbacks removeAllObjects];
    }
    for(void(^cb)(NSError * _Nullable) in callbacks) {
        cb(error);
    }
}

/// 王立涛 develop_fix 625cc7c 引入: 绕过 requestSuccess 缓存强制刷新 appconfig,
/// 用于网络恢复 / 手动刷新 SSO 按钮等场景。配合 develop (YUJ-396) 的 pending queue,
/// 不会破坏已入队 callback; startRequest 的去重仍然有效。
-(void) refreshConfig:(void(^__nullable)(NSError  * __nullable error))callback {
    self.requestSuccess = NO;
    [self requestConfig:callback];
}

-(void) requestConfig:(void(^)(NSError  * __nullable error))callback {

    // ========== appconfig 路径（YUJ-396 R3 callback 队列化） ==========
    // 已加载成功 → 立刻 callback。
    if(self.requestSuccess) {
        if(callback) {
            callback(nil);
        }
    } else {
        // 未加载 / in-flight —— 统一把 callback 入队, 请求完成时一次性 drain。
        // 解决 Jerry-Xin #112 Round 3 warning: 老实现在 startRequest==YES 时
        // 整个 if 块被跳过, 后来者的 callback 被静默丢弃, 调用侧（如
        // WKRealnameVerifyManager.startVerificationFromVC:）无法等 loading 完成。
        if(callback) {
            @synchronized(self) {
                [self.pendingConfigCallbacks addObject:[callback copy]];
            }
        }

        __weak typeof(self) weakSelf = self;
        if(!self.startRequest) {
            self.startRequest = true;
            [[WKAPIClient sharedClient] GET:@"common/appconfig" parameters:@{}].then(^(NSDictionary *resultDict){
                weakSelf.webURL =  resultDict[@"web_url"]?:@"";
                if(resultDict[@"phone_search_off"]) {
                    weakSelf.phoneSearchOff = [resultDict[@"phone_search_off"] boolValue];
                }
                if(resultDict[@"shortno_edit_off"]) {
                    weakSelf.shortnoEditOff = [resultDict[@"shortno_edit_off"] boolValue];
                }
                if(resultDict[@"revoke_second"]) {
                    weakSelf.revokeSecond = [resultDict[@"revoke_second"] integerValue];
                }
                if(resultDict[@"register_invite_on"]) {
                    weakSelf.registerInviteOn = [resultDict[@"register_invite_on"] boolValue];
                }

                if(resultDict[@"invite_system_account_join_group_on"]) {
                    weakSelf.inviteSystemAccountJoinGroupOn =  [resultDict[@"invite_system_account_join_group_on"] boolValue];
                }
                if(resultDict[@"register_user_must_complete_info_on"]) {
                    weakSelf.registerUserMustCompleteInfoOn = [resultDict[@"register_user_must_complete_info_on"] boolValue];
                }
                if(resultDict[@"thread_on"]) {
                    weakSelf.threadOn = [resultDict[@"thread_on"] boolValue];
                }

                // YUJ-219-A4: consume system_bot_uids from backend appconfig.
                // Response shape (A2): {"system_bot_uids": ["botfather", "u_10000", "fileHelper"]}.
                // When the field is missing (A2 not deployed), keep the fallback
                // configured in WKAppConfig's -init.
                id systemBotUIDsRaw = resultDict[@"system_bot_uids"];
                if([systemBotUIDsRaw isKindOfClass:[NSArray class]]) {
                    NSMutableArray<NSString*> *uids = [NSMutableArray array];
                    for(id item in (NSArray*)systemBotUIDsRaw) {
                        if([item isKindOfClass:[NSString class]] && ((NSString*)item).length > 0) {
                            [uids addObject:item];
                        }
                    }
                    if(uids.count > 0) {
                        [WKApp shared].config.systemBotUIDs = [uids copy];
                    }
                }

                // YUJ-396 + develop_fix 625cc7c 合并:
                // - parseArray: 强类型解析 (YUJ-396, Aegis 实名认证 accountUrl 链消费)
                // - raw array 持久化缓存 (王立涛 develop_fix, 登录页冷启动即可渲染 SSO 按钮)
                id oidcProvidersRaw = resultDict[@"oidc_providers"];
                if([oidcProvidersRaw isKindOfClass:[NSArray class]]) {
                    weakSelf.oidcProviders = [WKOidcProviderConfig parseArray:oidcProvidersRaw];
                    [[NSUserDefaults standardUserDefaults] setObject:oidcProvidersRaw forKey:kOidcProvidersCacheKey];
                } else {
                    weakSelf.oidcProviders = @[];
                    // Server explicitly dropped the field (admin disabled SSO) — drop cache too.
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kOidcProvidersCacheKey];
                }

                weakSelf.requestSuccess = true;
                weakSelf.startRequest = false;
                // Notify SSO 登录页等待 remote config 的观察者（王立涛 develop_fix）
                [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_REMOTECONFIG_LOADED object:nil];
                // Drain pending config callbacks queue (develop YUJ-396)
                [weakSelf _fireAndClearPendingConfigCallbacks:nil];
            }).catch(^(NSError *error){
                WKLogError(@"请求远程配置失败！->%@",error);
                weakSelf.startRequest = false;
                [weakSelf _fireAndClearPendingConfigCallbacks:error];
            });
        }
        // startRequest==YES 的情况: callback 已入队, 等 in-flight 请求的 then/catch
        // 统一 drain。这里什么都不做。
    }

    // ========== appmodule 路径（legacy, 本 PR 不改语义） ==========
    // 注意: 这里的 `callback` 是本次 requestConfig: 调用的参数闭包;
    // 老实现会在 startRequestAppModule==NO 时挂到 appmodule 请求的 then/catch,
    // 这意味着 appconfig 和 appmodule 都可能各触发一次同一个 callback。
    // 与 YUJ-396 无关, 保留原行为不引入回归。
    if(!self.requestAppModuleSuccess && !self.startRequestAppModule) {
        self.startRequestAppModule = true;
        __weak typeof(self) weakSelf = self;
        [WKAPIClient.sharedClient GET:@"common/appmodule" parameters:@{} model:WKAppModuleResp.class].then(^(NSArray<WKAppModuleResp*> *models){
            weakSelf.modules = models;
            weakSelf.requestAppModuleSuccess = true;
            weakSelf.startRequestAppModule = false;
            if(callback) {
                callback(nil);
            }
        }).catch(^(NSError *error){
            weakSelf.startRequestAppModule = false;
            WKLogError(@"请求app模块失败！->%@",error);
            if(callback) {
                callback(error);
            }
        });
    }
    
    
}

-(void) modules:(NSString*)sid on:(BOOL)on {
    NSString *enableKey = @"modules_enable";
    NSString *disableKey = @"modules_disable";
    
    NSArray<NSString*> *enableModules =  WKApp.shared.loginInfo.extra[enableKey];
    
    NSArray<NSString*> *disableModules =  WKApp.shared.loginInfo.extra[disableKey];
    NSMutableArray *newEnableModules = [NSMutableArray arrayWithArray:enableModules];
    NSMutableArray *newDisableModules = [NSMutableArray arrayWithArray:disableModules];
    if(on) {
        if(![newEnableModules containsObject:sid]) {
            [newEnableModules addObject:sid];
        }
        if([newDisableModules containsObject:sid]) {
            [newDisableModules removeObject:sid];
        }
        WKApp.shared.loginInfo.extra[enableKey] = newEnableModules;
        WKApp.shared.loginInfo.extra[disableKey] = newDisableModules;
    }else {
        if(![newDisableModules containsObject:sid]) {
            [newDisableModules addObject:sid];
        }
        if([newEnableModules containsObject:sid]) {
            [newEnableModules removeObject:sid];
        }
        WKApp.shared.loginInfo.extra[enableKey] = newEnableModules;
        WKApp.shared.loginInfo.extra[disableKey] = newDisableModules;
    }
    [WKApp.shared.loginInfo save];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_MODULE_CHANGE object:nil];
}

- (BOOL)moduleOn:(NSString *)sid {
    NSArray<NSString*> *modules =  WKApp.shared.loginInfo.extra[@"modules_enable"];
    if(modules && [modules containsObject:sid]) {
        return true;
    }
    NSArray<NSString*> *disableModules = WKApp.shared.loginInfo.extra[@"modules_disable"];
    if(disableModules && [disableModules containsObject:sid]) {
        return false;
    }
//    return [self mustModule:sid];
    if(self.modules && self.modules.count>0) {
        WKAppModuleResp *existResp;
        for (WKAppModuleResp *resp in self.modules) {
            if([resp.sid isEqualToString:sid]) {
                existResp = resp;
                break;
            }
        }
        if(!existResp) {
            return true;
        }
        return existResp.status != WKAppModuleStatusDisable;
    }
    return true;
}

// 是否是必须支持的模块
static NSMutableArray *mustSupportModules;
-(BOOL) mustModule:(NSString*)sid {
    if(!mustSupportModules) {
        mustSupportModules = [NSMutableArray arrayWithArray:@[@"WuKongBase",@"WuKongLogin",@"WuKongContacts"]];
    }
    return [mustSupportModules containsObject:sid];
}

- (BOOL)moduleHasSetting:(NSString *)sid {
    NSArray<NSString*> *enableModules =  WKApp.shared.loginInfo.extra[@"modules_enable"];
    if(enableModules && [enableModules containsObject:sid]) {
        return true;
    }
    NSArray<NSString*> *disableModules = WKApp.shared.loginInfo.extra[@"modules_disable"];
    if(disableModules && [disableModules containsObject:sid]) {
        return true;
    }
    return false;
}

@end

@implementation WKThemeContextMenu

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (UIColor *)primaryColor {
    if(WKApp.shared.config.style == WKSystemStyleDark) {
        return [UIColor colorWithRed:255.0f green:255.0f blue:255.0f alpha:1.0f];
    }
    return [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
}


@end

@implementation WKAppModuleResp

+ (WKModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKAppModuleResp *resp = [WKAppModuleResp new];
    
    NSString *sid = dictory[@"sid"]?:@"";
    if([sid isEqualToString:@"base"]) {
        sid = @"WuKongBase";
    }else if([sid isEqualToString:@"login"]) {
        sid = @"WuKongLogin";
    }else if([sid isEqualToString:@"scan"]) {
        sid = @"WuKongScan";
        resp.hidden = YES;
    }else if([sid isEqualToString:@"push"]) {
        sid = @"WuKongPush";
        resp.hidden = YES;
    }else if([sid isEqualToString:@"rtc"]) {
        sid = @"WuKongRTC";
    }else if([sid isEqualToString:@"moment"]) {
        sid = @"WuKongMoment";
    }else if([sid isEqualToString:@"sticker"]) {
        sid = @"WuKongStickerStore";
    }else if([sid isEqualToString:@"advanced"]) {
        sid = @"WuKongAdvanced";
    }else if([sid isEqualToString:@"groupManager"]) {
        sid = @"WuKongGroupManager";
    }else if([sid isEqualToString:@"wallet"]) {
        sid = @"WuKongWallet";
    }else if([sid isEqualToString:@"redpacket"]) {
        sid = @"WuKongRedPackets";
    }else if([sid isEqualToString:@"transfer"]) {
        sid = @"WuKongTransfer";
    }else if([sid isEqualToString:@"security"]) {
        sid = @"WuKongSecurity";
        resp.hidden = YES;
    }else if([sid isEqualToString:@"video"]) {
        sid = @"WuKongSmallVideo";
    }else if([sid isEqualToString:@"favorite"]) {
        sid = @"WuKongFavorite";
    }else if([sid isEqualToString:@"file"]) {
        sid = @"WuKongFile";
    }else if([sid isEqualToString:@"map"]) {
        sid = @"WuKongLocation";
    }else if([sid isEqualToString:@"customerService"]) {
        sid = @"WuKongCustomerService";
    }else if([sid isEqualToString:@"rich"]) {
        sid = @"WuKongRichTextEditor";
    }else if([sid isEqualToString:@"label"]) {
        sid = @"WuKongLabel";
    }
    resp.sid = sid;
    resp.name = dictory[@"name"]?:@"";
    resp.status = [dictory[@"status"] integerValue];
    resp.desc = dictory[@"desc"]?:@"";
    return resp;
}
@end

@implementation WKOidcProviderConfig

@end
