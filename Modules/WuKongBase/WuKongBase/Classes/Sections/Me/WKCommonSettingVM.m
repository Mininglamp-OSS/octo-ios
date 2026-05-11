//
//  WKCommonSettingVM.m
//  WuKongBase
//
//  Created by tt on 2020/6/21.
//

#import "WKCommonSettingVM.h"
#import "WKDarkModeVC.h"
//#import <FLEX/FLEX.h>
#import "WKLanguageVC.h"
#import "NSString+WKLocalized.h"
#import "WKModuleVC.h"
#import "WKAboutVC.h"
#import "WKDestroyAccountVC.h"
#import "WKRealnameVerifyManager.h"
#import "WKNavigationManager.h"

@interface WKCommonSettingVM ()

@property(nonatomic,strong) NSMutableDictionary *param;

@end

@implementation WKCommonSettingVM

- (instancetype)init
{
    self = [super init];
    if (self) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [self registerItems];
        });
    }
    return self;
}

-(void) registerItems {
    // 实名认证（OCTO）— 暂时隐藏入口
    /*
    [[WKApp shared] setMethod:WKPOINT_COMMONSETTING_REALNAME handler:^id _Nullable(id  _Nonnull param) {
        WKLoginInfo *loginInfo = [WKApp shared].loginInfo;
        BOOL verified = loginInfo.realnameVerified;

        NSString *valueText;
        if(verified) {
            // "已认证 · YYYY-MM"
            NSTimeInterval ts = loginInfo.realnameVerifiedAt;
            NSString *ym = @"";
            if(ts > 0) {
                NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
                fmt.dateFormat = @"yyyy-MM";
                ym = [fmt stringFromDate:[NSDate dateWithTimeIntervalSince1970:ts]];
            }
            if(ym.length > 0) {
                valueText = [NSString stringWithFormat:@"%@ · %@", LLang(@"已认证"), ym];
            } else {
                valueText = LLang(@"已认证");
            }
        } else {
            valueText = LLang(@"去认证");
        }

        id onClick;
        if(verified) {
            // 已认证不可再点
            onClick = [NSNull null];
        } else {
            onClick = ^{
                UIViewController *topVC = [WKNavigationManager shared].topViewController;
                if(!topVC) {
                    topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
                    while(topVC.presentedViewController) { topVC = topVC.presentedViewController; }
                }
                [[WKRealnameVerifyManager shared] startVerificationFromVC:topVC];
            };
        }

        return  @{
            @"height":WKSectionHeight,
            @"items":@[
                @{
                    @"class":WKLabelItemModel.class,
                    @"label":LLang(@"实名认证"),
                    @"value":valueText,
                    @"showArrow":@(!verified),
                    @"onClick":onClick,
                },
            ],
        };
    } category:WKPOINT_CATEGORY_COMMONSETTING sort:99000];
    */

    // 深色模式
    [[WKApp shared] setMethod:@"commonsetting.notify" handler:^id _Nullable(id  _Nonnull param) {
        BOOL supportDarkMode = NO;
        if (@available(iOS 13.0, *)) {
            supportDarkMode = YES;
        }
        NSString *darkDesc = LLang(@"打开");
        if([WKApp shared].config.darkModeWithSystem) {
            darkDesc = LLang(@"跟随系统");
        }else {
            darkDesc = WKApp.shared.config.style == WKSystemStyleDark?LLang(@"打开"):LLang(@"关闭");
        }
        return  @{
            @"height":WKSectionHeight,
            @"items":@[
                @{
                    @"class":WKLabelItemModel.class,
                    @"label":LLang(@"深色模式"),
                    @"value": darkDesc?:@"",
                    @"hidden":@(!supportDarkMode),
                    @"onClick":^{
                        
                        WKDarkModeVC *vc = [WKDarkModeVC new];
                        [[WKNavigationManager shared] pushViewController:vc animated:YES];
                        
                    }
                },
               ]

        };
    } category:WKPOINT_CATEGORY_COMMONSETTING sort:90000];
    
    // 清除缓存
    [[WKApp shared] setMethod:@"commonsetting.clearcache" handler:^id _Nullable(NSMutableDictionary   *param) {
        void(^reloadData)(void)  = param[@"reloadData"];
      
        BOOL cacheLoaded = false;
        NSUInteger cacheSize = 0;
        if(param[@"cacheLoaded"] && [param[@"cacheLoaded"] boolValue]) {
            cacheLoaded =  true;
            cacheSize = [ param[@"cacheSize"] intValue];
        }
        
        if(!cacheLoaded) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                
                NSUInteger cacheSize = [[SDImageCache sharedImageCache] totalDiskSize];
                NSError *err;
                unsigned long long videoCacheSize =  [WKApp.shared calculateVideoCachedSizeWithError:&err];
                cacheSize += videoCacheSize;
                
                cacheSize += [[WKSDK shared].mediaManager messageCacheSize];
                
                param[@"cacheSize"] = @(cacheSize);
                param[@"cacheLoaded"]=@(true);
                dispatch_async(dispatch_get_main_queue(), ^{
                    reloadData();
                });
                
            });
        }
        
        return  @{
            @"height":@(0.0f),
            @"items":@[
                @{
                    @"class":WKLabelItemModel.class,
                    @"label":LLang(@"清空图片/视频缓存"),
                    @"value": [self fileSizeWithInterge:cacheSize],
                    @"onClick":^{
                        WKActionSheetView2 *actionSheetView = [WKActionSheetView2 initWithTip:LLang(@"是否清除缓存")];
                        [actionSheetView addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLang(@"清空缓存") onClick:^{
                            [WKApp.shared cleanVideoCache]; // 清空视频缓存
                            
                            [[WKSDK shared].mediaManager cleanMessageCache]; // 消息缓存
                            // 清空图片缓存
                            [[SDImageCache sharedImageCache] clearDiskOnCompletion:^{
                                param[@"cacheLoaded"]=@(false);
                                reloadData();
                            }];
                           
                        }]];
                        [actionSheetView show];
                    }
                },
               ]

        };
    } category:WKPOINT_CATEGORY_COMMONSETTING sort:80000];
    
    // 聊天备份和恢复
//    [[WKApp shared] setMethod:@"commonsetting.chatbackup" handler:^id _Nullable(id  _Nonnull param) {
//        
//        return  @{
//            @"height":WKSectionHeight,
//            @"items":@[
//                    @{
//                        @"class":WKLabelItemModel.class,
//                        @"label":LLang(@"聊天记录备份"),
//                        @"onClick":^{
//                            WKChatBackupVC *vc = [[WKChatBackupVC alloc] init];
//                            [WKNavigationManager.shared pushViewController:vc animated:YES];
//                        }
//                    },
//                    @{
//                        @"class":WKLabelItemModel.class,
//                        @"label":LLang(@"聊天记录恢复"),
//                        @"onClick":^{
//                            WKChatRecoverVC *vc = [[WKChatRecoverVC alloc] init];
//                            [WKNavigationManager.shared pushViewController:vc animated:YES];
//                        }
//                    },
//            ],
//        };
//    } category:WKPOINT_CATEGORY_COMMONSETTING sort:79000];
    
    // 多语言
    [[WKApp shared] setMethod:@"commonsetting.lang" handler:^id _Nullable(id  _Nonnull param) {
        BOOL supportDarkMode = NO;
        if (@available(iOS 13.0, *)) {
            supportDarkMode = YES;
        }
        NSString *darkDesc = LLang(@"打开");
        if([WKApp shared].config.darkModeWithSystem) {
            darkDesc = LLang(@"跟随系统");
        }else {
            darkDesc = WKApp.shared.config.style == WKSystemStyleDark?LLang(@"打开"):LLang(@"关闭");
        }
        
        return  @{
            @"height":WKSectionHeight,
            @"items":@[
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLang(@"多语言"),
                        @"onClick":^{
                            WKLanguageVC *vc = [WKLanguageVC new];
                            [[WKNavigationManager shared] pushViewController:vc animated:YES];
                        }
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_COMMONSETTING sort:70000];
    
    // 模块（已隐藏）
//    [[WKApp shared] setMethod:@"commonsetting.modules" handler:^id _Nullable(id  _Nonnull param) {
//
//        return  @{
//            @"height":WKSectionHeight,
//            @"items":@[
//                    @{
//                        @"class":WKLabelItemModel.class,
//                        @"label":LLang(@"功能模块"),
//                        @"onClick":^{
//                            WKModuleVC *vc = [WKModuleVC new];
//                            [[WKNavigationManager shared] pushViewController:vc animated:YES];
//                        }
//                    },
//            ],
//        };
//    } category:WKPOINT_CATEGORY_COMMONSETTING sort:69000];
    
    // 版本信息
    [[WKApp shared] setMethod:@"commonsetting.version" handler:^id _Nullable(id  _Nonnull param) {
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *appVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
        NSString *buildNumber = [infoDictionary objectForKey:@"CFBundleVersion"];
        NSString *versionDisplay = [NSString stringWithFormat:@"%@（%@）", appVersion ?: @"", buildNumber ?: @""];

        return @{
            @"height":WKSectionHeight,
            @"items":@[
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLang(@"版本信息"),
                        @"value":versionDisplay,
                        @"onClick":^{
                            WKAboutVC *vc = [WKAboutVC new];
                            [[WKNavigationManager shared] pushViewController:vc animated:YES];
                        }
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_COMMONSETTING sort:60000];
    
    
    // 注销账号
    [[WKApp shared] setMethod:@"commonsetting.destroyaccount" handler:^id _Nullable(id  _Nonnull param) {
        return  @{
            @"height":WKSectionHeight,
            @"items":@[
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLang(@"注销账号"),
                        @"onClick":^{
                            WKDestroyAccountVC *vc = [WKDestroyAccountVC new];
                            [[WKNavigationManager shared] pushViewController:vc animated:YES];
                        }
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_COMMONSETTING sort:150];

    // 退出登陆
    [[WKApp shared] setMethod:@"commonsetting.logout" handler:^id _Nullable(id  _Nonnull param) {
        __weak typeof(self) weakSelf = self;
        return  @{
            @"height":WKSectionHeight,
            @"items":@[
                    @{
                        @"class":WKButtonItemModel.class,
                        @"title":LLang(@"退出登录"),
                        @"onClick":^{
                            WKActionSheetView2 *actionSheetView = [WKActionSheetView2 initWithTip:LLangW(@"退出后不会删除任何历史数据，下次登录依然可以使用本账号。",weakSelf)];
                            [actionSheetView addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLangW(@"退出登录",weakSelf) onClick:^{
                                [actionSheetView hide];
                                [[WKApp shared] logout];
                            }]];
                            [actionSheetView show];
                        }
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_COMMONSETTING sort:100];
}

- (NSArray<NSDictionary *> *)tableSectionMaps {
    __weak typeof(self) weakSelf = self;
    if(!self.param) {
        self.param = [NSMutableDictionary dictionaryWithDictionary:@{@"reloadData":^{
            [weakSelf reloadData];
        } }];
    }
   
    return  [WKApp.shared invokes:WKPOINT_CATEGORY_COMMONSETTING param:self.param];
    
}

//计算出大小
- (NSString *)fileSizeWithInterge:(NSInteger)size{
    if(size<1024) {
        return [NSString stringWithFormat:@"%ldB",(long)size];
    }else if (size < 1024 * 1024){// 小于1m
        CGFloat aFloat = size/1024;
        return [NSString stringWithFormat:@"%.0fK",aFloat];
    }else if (size < 1024 * 1024 * 1024){// 小于1G
        CGFloat aFloat = size/(1024 * 1024);
        return [NSString stringWithFormat:@"%.1fM",aFloat];
    }else{
        CGFloat aFloat = size/(1024*1024*1024);
        return [NSString stringWithFormat:@"%.1fG",aFloat];
    }
}
@end
