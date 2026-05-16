// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMeVM.m
//  WuKongBase
//
//  Created by tt on 2020/6/9.
//

#import "WKMeVM.h"
#import "WKTableSectionUtil.h"
#import "WKMeItemCell.h"
#import "WKMePushSettingVC.h"
#import "WKCommonSettingVC.h"
#import "WKMeItem.h"
#import "WKOnlineStatusManager.h"
@implementation WKMeVM

- (NSArray<NSDictionary *> *)tableSectionMaps {
    NSArray<WKMeItem*> *itemModels = [[WKApp shared] invokes:WKPOINT_CATEGORY_ME param:nil];
    if(!itemModels || itemModels.count<=0) {
        return @[];
    }
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *currentGroup = [NSMutableArray array];

    BOOL isDark = (WKApp.shared.config.style == WKSystemStyleDark);
    NSDictionary *darkModeItem = @{
        @"class": WKSwitchItemModel.class,
        @"label": LLang(@"深色模式"),
        @"on": @(isDark),
        @"bottomLeftSpace":@(0.0f),
        @"showBottomLine":@(NO),
        @"showTopLine":@(NO),
        @"onSwitch":^(BOOL on){
            if(on) {
                WKApp.shared.config.style = WKSystemStyleDark;
            } else {
                WKApp.shared.config.style = WKSystemStyleLight;
            }
            WKApp.shared.config.darkModeWithSystem = NO;
        }
    };
    [currentGroup addObject:darkModeItem];

    for (NSInteger i = 0; i < itemModels.count; i++) {
        WKMeItem *meItem = itemModels[i];
        NSMutableDictionary *itemDict = [NSMutableDictionary dictionaryWithDictionary:@{
            @"class":WKMeItemModel.class,
            @"title":meItem.title?:@"",
            @"bottomLeftSpace":@(0.0f),
            @"showBottomLine":@(NO),
            @"showTopLine":@(NO),
            @"onClick":^(BOOL on){
                if(meItem.onClick) {
                    meItem.onClick();
                }
            }
        }];
        if(meItem.icon) {
            itemDict[@"icon"] = meItem.icon;
        }
        if([meItem.title isEqualToString:LLang(@"网页端")]) {
            BOOL pcOnline = [WKOnlineStatusManager shared].pcOnline;
            itemDict[@"detail"] = pcOnline ? LLang(@"已连接") : @"";
        }
        [currentGroup addObject:itemDict];
        BOOL isLast = (i == itemModels.count - 1);
        BOOL hasGroupBreak = (meItem.nextSectionHeight > 0);
        if(hasGroupBreak || isLast) {
            [sections addObject:@{
                @"height":@(10.0f),
                @"items":[currentGroup copy]
            }];
            currentGroup = [NSMutableArray array];
        }
    }
    return sections;
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
