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
#import "WKWebViewVC.h"
#import "UIView+WKCommon.h"

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

#pragma mark - 行样式辅助

// 通用行：12px row 高度 52，左右 inset 17 的底部分隔线，可选 showBottomLine
- (NSMutableDictionary *)rowBase {
    return [NSMutableDictionary dictionaryWithDictionary:@{
        @"cellHeight":@(52.0f),
        @"bottomLeftSpace":@(17.0f),
        @"bottomRightSpace":@(17.0f),
    }];
}

-(void) registerItems {
    // 实名认证（OCTO）
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

        NSMutableDictionary *item = @{
            @"class":WKLabelItemModel.class,
            @"label":LLang(@"实名认证"),
            @"value":valueText,
            @"showArrow":@(!verified),
            @"onClick":onClick,
        }.mutableCopy;
        [item addEntriesFromDictionary:@{
            @"cellHeight":@(52.0f),
            @"bottomLeftSpace":@(17.0f),
            @"bottomRightSpace":@(17.0f),
        }];

        return  @{
            @"height":WKSectionHeight,
            @"items":@[ item ],
        };
    } category:WKPOINT_CATEGORY_COMMONSETTING sort:99000];

    // 深色模式 —— 已搬到「我的」页，此处不再展示
    [[WKApp shared] setMethod:@"commonsetting.notify" handler:^id _Nullable(id  _Nonnull param) {
        return nil;
    } category:WKPOINT_CATEGORY_COMMONSETTING sort:90000];

    // 语言 / 存储空间 / 隐私 —— 合并为一个 card
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

        // 当前语言
        NSString *langKey = [WKApp shared].config.langue;
        NSString *langDisplay = [langKey isEqualToString:@"en"] ? @"English" : @"简体中文";

        NSDictionary *langItem = @{
            @"class":WKLabelItemModel.class,
            @"label":LLang(@"语言"),
            @"value":langDisplay,
            @"cellHeight":@(52.0f),
            @"bottomLeftSpace":@(17.0f),
            @"bottomRightSpace":@(17.0f),
            @"showBottomLine":@(YES),
            @"onClick":^{
                WKLanguageVC *vc = [WKLanguageVC new];
                [[WKNavigationManager shared] pushViewController:vc animated:YES];
            }
        };

        NSString *cacheText;
        if(!cacheLoaded) {
            cacheText = @"";          // 仍在异步计算中，留空
        } else if(cacheSize <= 0) {
            cacheText = @"0KB";       // 已计算完成且无缓存，显示 0KB
        } else if(cacheSize < 1024) {
            cacheText = [NSString stringWithFormat:@"%luB", (unsigned long)cacheSize];
        } else if(cacheSize < 1024 * 1024) {
            cacheText = [NSString stringWithFormat:@"%.0fK", cacheSize/1024.0];
        } else if(cacheSize < 1024 * 1024 * 1024) {
            cacheText = [NSString stringWithFormat:@"%.1fM", cacheSize/(1024.0*1024.0)];
        } else {
            cacheText = [NSString stringWithFormat:@"%.1fG", cacheSize/(1024.0*1024.0*1024.0)];
        }
        NSDictionary *storageItem = @{
            @"class":WKLabelItemModel.class,
            @"label":LLang(@"存储空间"),
            @"value":cacheText,
            @"cellHeight":@(52.0f),
            @"bottomLeftSpace":@(17.0f),
            @"bottomRightSpace":@(17.0f),
            @"showBottomLine":@(YES),
            @"onClick":^{
                WKActionSheetView2 *actionSheetView = [WKActionSheetView2 initWithTip:LLang(@"是否清除缓存")];
                [actionSheetView addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLang(@"清空缓存") onClick:^{
                    UIView *topView = [WKNavigationManager shared].topViewController.view;
                    [topView showHUD:LLang(@"缓存清理中")];
                    @try {
                        [WKApp.shared cleanVideoCache];
                        [[WKSDK shared].mediaManager cleanMessageCache];
                        [[SDImageCache sharedImageCache] clearDiskOnCompletion:^{
                            param[@"cacheLoaded"]=@(false);
                            reloadData();
                            [topView switchHUDSuccess:LLang(@"清理成功")];
                        }];
                    } @catch (NSException *exception) {
                        [topView switchHUDError:LLang(@"清理失败")];
                    }
                }]];
                [actionSheetView show];
            }
        };

        NSDictionary *privacyItem = @{
            @"class":WKLabelItemModel.class,
            @"label":LLang(@"隐私"),
            @"cellHeight":@(52.0f),
            @"bottomLeftSpace":@(17.0f),
            @"bottomRightSpace":@(17.0f),
            @"onClick":^{
                // 走 [WKApp shared].config.octoPrivacyURL (静态 CDN PDF, 由
                // OctoConfig.xcconfig 的 OCTO_PRIVACY_URL 注入)。不走 server 端
                // privacyAgreementUrl —— 部分部署被 Aegis SSO 接管会跳登录。
                NSString *urlStr = [WKApp shared].config.octoPrivacyURL;
                NSURL *u = [NSURL URLWithString:urlStr];
                if (!u) return;
                WKWebViewVC *vc = [WKWebViewVC new];
                vc.url = u;
                [[WKNavigationManager shared] pushViewController:vc animated:YES];
            }
        };

        return  @{
            @"height":@(12.0f),
            @"items":@[ langItem, storageItem, privacyItem ],
        };
    } category:WKPOINT_CATEGORY_COMMONSETTING sort:80000];

    // 多语言 —— 已并入上方 commonsetting.clearcache
    [[WKApp shared] setMethod:@"commonsetting.lang" handler:^id _Nullable(id  _Nonnull param) {
        return nil;
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

    // 关于（原"版本信息"）
    [[WKApp shared] setMethod:@"commonsetting.version" handler:^id _Nullable(id  _Nonnull param) {
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *appVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
        NSString *buildNumber = [infoDictionary objectForKey:@"CFBundleVersion"];
        NSString *versionDisplay = [NSString stringWithFormat:@"v%@（%@）", appVersion ?: @"", buildNumber ?: @""];

        return @{
            @"height":@(12.0f),
            @"items":@[
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLang(@"关于"),
                        @"value":versionDisplay,
                        @"cellHeight":@(52.0f),
                        @"bottomLeftSpace":@(17.0f),
                        @"bottomRightSpace":@(17.0f),
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
            @"height":@(12.0f),
            @"items":@[
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLang(@"注销账号"),
                        @"cellHeight":@(52.0f),
                        @"bottomLeftSpace":@(17.0f),
                        @"bottomRightSpace":@(17.0f),
                        @"onClick":^{
                            WKDestroyAccountVC *vc = [WKDestroyAccountVC new];
                            [[WKNavigationManager shared] pushViewController:vc animated:YES];
                        }
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_COMMONSETTING sort:150];

    // 退出登录（红色描边按钮）
    [[WKApp shared] setMethod:@"commonsetting.logout" handler:^id _Nullable(id  _Nonnull param) {
        __weak typeof(self) weakSelf = self;
        UIColor *brandRed = [UIColor colorWithRed:0xF6/255.0 green:0x5E/255.0 blue:0x58/255.0 alpha:1.0];
        return  @{
            @"height":@(16.0f),
            @"items":@[
                    @{
                        @"class":WKButtonItemModel.class,
                        @"title":LLang(@"退出登录"),
                        @"color":brandRed,
                        @"cellHeight":@(48.0f),
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
