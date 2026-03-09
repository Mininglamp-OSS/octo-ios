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
        self.appName = @"唐僧叨叨";
        self.shortName = @"WuKong ID";
        self.appID = @""; // appstore的id
        self.appSchemaPrefix = @"wukong";
        self.clusterOn = YES;
        
         // ---------- 基础配置 ----------
        self.themeColor = [UIColor colorWithRed:228.0f/255.0f green:99.0f/255.0f blue:66.0f/255.0f alpha:1.0]; // #2F70F5
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
        self.messageTextMaxBytes = 1024*2;
        
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

@end

@implementation WKAppRemoteConfig

-(void) requestConfig:(void(^)(NSError  * __nullable error))callback {
    
    __weak typeof(self) weakSelf = self;
    if(!self.requestSuccess && !self.startRequest) {
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
           
            
            weakSelf.requestSuccess = true;
            weakSelf.startRequest = false;
            if(callback) {
                callback(nil);
            }
        }).catch(^(NSError *error){
            WKLogError(@"请求远程配置失败！->%@",error);
            weakSelf.startRequest = false;
            if(callback) {
                callback(error);
            }
        });
    }
    if(!self.requestAppModuleSuccess && !self.startRequestAppModule) {
        self.startRequestAppModule = true;
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
