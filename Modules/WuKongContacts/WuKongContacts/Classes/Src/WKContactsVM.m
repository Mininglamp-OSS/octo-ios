//
//  WKContactsVM.m
//  WuKongContacts
//
//  Created by tt on 2019/12/7.
//

#import "WKContactsVM.h"
#import "WKContactsAddFunctionItemCell.h"
#import "WKContactsAddMyShortCell.h"
#import "WKMeQRCodeVC.h"
#import "WKScanVC.h"
#import "WKContactsFriendVC.h"
@implementation WKContactsVM

-(AnyPromise*) searchFriend:(NSString*)keyword {
    return [[WKAPIClient sharedClient] GET:@"user/search" parameters:@{@"keyword":keyword} model:WKUserSearchResp.class];
}

- (NSArray<NSDictionary *> *)tableSectionMaps {
    return @[
        @{
            @"height":@(5.0f),
            @"items": @[
                    @{
                        @"class": WKContactsAddMyShortModel.class,
                        @"value": [WKApp shared].loginInfo.extra[@"short_no"]?:@"",
                        @"onQRCode":^{
                            [[WKNavigationManager shared] pushViewController:[WKMeQRCodeVC new] animated:YES];
                        },
                    }
            ]
        },
        @{
            @"height":@(30.0f),
            @"items": @[
                    @{
                        @"class": WKContactsAddFunctionItemModel.class,
                        @"title": LLang(@"扫一扫"),
                        @"subtitle":LLang(@"扫描二维码名片"),
                        @"icon": [self imageName:@"Contacts/Others/Scan"],
                        @"onClick":^{
                            [[WKNavigationManager shared] pushViewController:[WKScanVC new] animated:YES];
                        },
                    }
            ]
        },
        @{
            @"height":@(0.0f),
            @"items": @[
                    @{
                        @"class": WKContactsAddFunctionItemModel.class,
                        @"title": LLang(@"手机联系人"),
                        @"subtitle":LLang(@"添加通讯录中的朋友"),
                        @"icon": [self imageName:@"Contacts/Others/Contacts"],
                        @"onClick":^{
                            WKContactsFriendVC *vc = [WKContactsFriendVC new];
                            [[WKNavigationManager shared] pushViewController:vc animated:YES];
                        },
                    }
            ]
        }
    ];
}

-(UIImage*) imageName:(NSString*)name {
    return [[WKApp shared] loadImage:name moduleID:@"WuKongContacts"];
}


@end

@implementation WKUserSearchResp

+(WKUserSearchResp*) fromMap:(NSDictionary*)dictory type:(ModelMapType)type {
    WKUserSearchResp *resp = [WKUserSearchResp new];
    
     NSInteger exist =  [dictory[@"exist"] integerValue];
    resp.exist = exist==1;
    if(resp.exist) {
        resp.user = (WKUserResp*)[WKUserResp fromMap:dictory[@"data"] type:type];
    }
    return resp;
}

@end

@implementation WKUserResp

+(WKUserResp*) fromMap:(NSDictionary*)dictory type:(ModelMapType)type {
    WKUserResp *resp = [WKUserResp new];
    resp.uid = dictory[@"uid"];
    resp.name = dictory[@"name"];
    resp.vercode = dictory[@"vercode"];
    resp.avatar = dictory[@"avatar"];
    return resp;
}

@end
