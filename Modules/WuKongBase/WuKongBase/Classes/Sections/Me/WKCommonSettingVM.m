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
    
    // 模块
    [[WKApp shared] setMethod:@"commonsetting.modules" handler:^id _Nullable(id  _Nonnull param) {
    
        return  @{
            @"height":WKSectionHeight,
            @"items":@[
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLang(@"功能模块"),
                        @"onClick":^{
                            WKModuleVC *vc = [WKModuleVC new];
                            [[WKNavigationManager shared] pushViewController:vc animated:YES];
                        }
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_COMMONSETTING sort:69000];
    
    // 版本信息
    [[WKApp shared] setMethod:@"commonsetting.version" handler:^id _Nullable(id  _Nonnull param) {
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *appVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
        
        return @{
            @"height":WKSectionHeight,
            @"items":@[
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLang(@"版本信息"),
                        @"value":appVersion?:@"",
                        @"onClick":^{
                            if (@available(iOS 10.0, *)) {
                                if([WKApp shared].config.appID && ![[WKApp shared].config.appID isEqualToString:@""]) {
                                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://itunes.apple.com/us/app/id/%@",[WKApp shared].config.appID]] options:@{} completionHandler:nil];
                                }
                               
                            } else {
                                // Fallback on earlier versions
                            }
                        }
                    },
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLang(@"用户协议"),
                        @"onClick":^{
                            WKWebViewVC *vc = [[WKWebViewVC alloc] init];
                            vc.url = [NSURL URLWithString:WKApp.shared.config.userAgreementUrl];
                            [WKNavigationManager.shared pushViewController:vc animated:YES];
                        }
                    },
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLang(@"隐私政策"),
                        @"onClick":^{
                            WKWebViewVC *vc = [[WKWebViewVC alloc] init];
                            vc.url = [NSURL URLWithString:WKApp.shared.config.privacyAgreementUrl];
                            [WKNavigationManager.shared pushViewController:vc animated:YES];
                        }
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_COMMONSETTING sort:60000];
    
    
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
