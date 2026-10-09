//
//  WKMeInfoVM.m
//  WuKongBase
//
//  Created by tt on 2020/6/23.
//

#import "WKMeInfoVM.h"
#import "WKIconItemCell.h"
#import "WKMeAvatarCell.h"
#import "WKMeAvatarVC.h"
#import "WKMeQRCodeVC.h"
@implementation WKMeInfoVM

- (NSArray<NSDictionary *> *)tableSectionMaps {
    WKLoginInfo *loginInfo = [WKApp shared].loginInfo;
    NSString *sexName = LLang(@"男");
    NSInteger sex = 0;
    if(loginInfo.extra[@"sex"]) {
        sex = [loginInfo.extra[@"sex"] integerValue];
    }
    if(sex == 0) {
        sexName = LLang(@"女");
    }else if (sex == 1) {
        sexName = LLang(@"男");
    }else{
        sexName = LLang(@"未设置");
    }
    BOOL canSettingShortNo = false;
    if((loginInfo.extra[@"short_status"] && [loginInfo.extra[@"short_status"] boolValue]) || WKApp.shared.remoteConfig.shortnoEditOff) {
        canSettingShortNo = false;
    }else {
        canSettingShortNo = true;
    }
    __weak typeof(self) weakSelf = self;

    id onShortNoClick;
    if(!canSettingShortNo) {
        onShortNoClick = [NSNull null];
    }else {
        onShortNoClick = ^{
            if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(meInfoVMUpdateShortNo:)]) {
                [weakSelf.delegate meInfoVMUpdateShortNo:weakSelf];
            }
        };
    }

    NSMutableArray *section1Items = [NSMutableArray array];
    [section1Items addObject:@{
        @"class":WKMeAvatarModel.class,
        @"label":LLang(@"头像"),
        @"showBottomLine":@(YES),
        @"bottomLeftSpace":@(17.0f),
        @"bottomRightSpace":@(17.0f),
        @"cellHeight":@(52.0f),
        @"onClick":^{
            [[WKNavigationManager shared] pushViewController:[WKMeAvatarVC new] animated:YES];
        }
    }];
    [section1Items addObject:@{
        @"class":WKLabelItemModel.class,
        @"label":LLang(@"姓名"),
        @"value":loginInfo.displayName?:@"",
        @"showBottomLine":@(YES),
        @"bottomLeftSpace":@(17.0f),
        @"bottomRightSpace":@(17.0f),
        @"cellHeight":@(52.0f),
        @"onClick":^{
            if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(meInfoVMUpdateName:)]) {
                [weakSelf.delegate meInfoVMUpdateName:weakSelf];
            }
        }
    }];
    // 手机号/邮箱还没拉取成功时（请求中或请求失败）整行不展示，不沿用上一次看到的值
    if(self.phoneEmailLoaded) {
        NSString *phoneValue = self.phone.length>0?[self phoneDisplayValue]:LLang(@"未绑定");
        NSMutableDictionary *phoneItem = [@{
            @"class":WKLabelItemModel.class,
            @"label":LLang(@"手机号"),
            @"value":phoneValue,
            @"showBottomLine":@(YES),
            @"bottomLeftSpace":@(17.0f),
            @"bottomRightSpace":@(17.0f),
            @"cellHeight":@(52.0f),
        } mutableCopy];
        if(self.phone.length>0) {
            phoneItem[@"showArrow"] = @(NO);
            phoneItem[@"onClick"] = ^(WKFormItemModel *model,NSIndexPath *indexPath){
                [weakSelf copyToPasteboard:phoneValue];
            };
        }
        [section1Items addObject:phoneItem];

        NSString *emailValue = self.email.length>0?self.email:LLang(@"未绑定");
        NSMutableDictionary *emailItem = [@{
            @"class":WKLabelItemModel.class,
            @"label":LLang(@"邮箱"),
            @"value":emailValue,
            @"showBottomLine":@(YES),
            @"bottomLeftSpace":@(17.0f),
            @"bottomRightSpace":@(17.0f),
            @"cellHeight":@(52.0f),
        } mutableCopy];
        if(self.email.length>0) {
            emailItem[@"showArrow"] = @(NO);
            emailItem[@"onClick"] = ^(WKFormItemModel *model,NSIndexPath *indexPath){
                [weakSelf copyToPasteboard:emailValue];
            };
        }
        [section1Items addObject:emailItem];
    }
    [section1Items addObject:@{
        @"class":WKLabelItemModel.class,
        @"label":[NSString stringWithFormat:LLang(@"%@号"),[WKApp shared].config.appName],
        @"value":loginInfo.extra[@"short_no"]?:@"",
        @"valueCopy":@(true),
        @"showArrow":@(canSettingShortNo),
        @"showBottomLine":@(YES),
        @"bottomLeftSpace":@(17.0f),
        @"bottomRightSpace":@(17.0f),
        @"cellHeight":@(52.0f),
        @"onClick":onShortNoClick,
    }];
    [section1Items addObject:@{
         @"class":WKIconItemModel.class,
         @"label":LLang(@"我的二维码"),
         @"icon":[self imageName:@"Me/Index/Qrcode"],
         @"width":@(16.0f),
         @"height":@(16.0f),
         @"cellHeight":@(52.0f),
         @"onClick":^{
             [[WKNavigationManager shared] pushViewController:[WKMeQRCodeVC new] animated:YES];
         }
    }];

    return @[
        @{
            @"height":@(0.1f),
            @"items":section1Items,
        },
        @{
            @"height":@(12.0f),
            @"items":@[
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLang(@"性别"),
                        @"value":sexName,
                        @"cellHeight":@(52.0f),
                        @"onClick":^{
                            if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(meInfoVMUpdateSex:)]) {
                                 [weakSelf.delegate meInfoVMUpdateSex:weakSelf];
                             }
                        }
                    },
            ],
        },
    ];
}

-(AnyPromise*) updateInfo:(NSString*)field value:(NSString*)value {
    NSMutableDictionary *paramDict = [[NSMutableDictionary alloc] init];
    [paramDict setObject:value forKey:field];
    return [[WKAPIClient sharedClient] PUT:@"user/current" parameters:paramDict];
}

-(AnyPromise*) fetchPhoneEmail {
    __weak typeof(self) weakSelf = self;
    self.phoneEmailLoaded = NO;
    self.phone = nil;
    self.email = nil;
    NSString *uid = [WKApp shared].loginInfo.uid;
    return [[WKAPIClient sharedClient] GET:[NSString stringWithFormat:@"users/%@", uid] parameters:@{@"group_no":@""}].then(^(NSDictionary *result){
        weakSelf.phone = result[@"phone"] ?: @"";
        weakSelf.email = result[@"email"] ?: @"";
        weakSelf.phoneEmailLoaded = YES;
    });
}

// 本人名片的手机号前面带区号，取登录缓存里的区号（形如"0086"），削掉前导零后拼成"(+86) 手机号"
-(NSString*) phoneDisplayValue {
    NSString *zone = [WKApp shared].loginInfo.extra[@"zone"];
    if(![zone isKindOfClass:NSString.class] || zone.length == 0) {
        return self.phone;
    }
    NSUInteger idx = 0;
    while(idx < zone.length - 1 && [zone characterAtIndex:idx] == '0') {
        idx++;
    }
    NSString *dialCode = [zone substringFromIndex:idx];
    if(dialCode.length == 0) {
        return self.phone;
    }
    return [NSString stringWithFormat:@"(+%@) %@", dialCode, self.phone];
}

-(void) copyToPasteboard:(NSString*)text {
    [UIPasteboard generalPasteboard].string = text;
    [[WKNavigationManager shared].topViewController.view showMsg:LLang(@"已复制")];
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
