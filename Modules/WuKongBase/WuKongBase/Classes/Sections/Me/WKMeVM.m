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

    for (NSInteger i = 0; i < itemModels.count; i++) {
        WKMeItem *meItem = itemModels[i];
        BOOL isPCRow = [meItem.title isEqualToString:LLang(@"网页端")];
        BOOL pcOnline = [WKOnlineStatusManager shared].pcOnline;

        NSMutableDictionary *itemDict = [NSMutableDictionary dictionaryWithDictionary:@{
            @"class":WKMeItemModel.class,
            @"title":meItem.title?:@"",
            @"cellHeight":@(52.0f),
            @"bottomLeftSpace":@(17.0f),
            @"bottomRightSpace":@(17.0f),
            @"onClick":^(BOOL on){
                if(meItem.onClick) {
                    meItem.onClick();
                }
            }
        }];
        if(meItem.icon) {
            itemDict[@"icon"] = meItem.icon;
        }
        if(isPCRow) {
            itemDict[@"detail"] = pcOnline ? LLang(@"已连接") : @"";
            // 网页端：HTML 设计无 chevron，仅显示状态文字
            itemDict[@"showArrow"] = @(NO);
        } else if(meItem.detail.length > 0) {
            itemDict[@"detail"] = meItem.detail;
        }

        [currentGroup addObject:itemDict];
        BOOL isLast = (i == itemModels.count - 1);
        BOOL hasGroupBreak = (meItem.nextSectionHeight > 0);

        // 分组内最后一行不画底部分隔线
        if(hasGroupBreak || isLast) {
            // 应用到 currentGroup 的所有行：前 n-1 行 showBottomLine=YES，最后一行 NO
            for (NSInteger r = 0; r < currentGroup.count; r++) {
                NSMutableDictionary *rowDict = currentGroup[r];
                rowDict[@"showBottomLine"] = @(r < currentGroup.count - 1);
            }
            [sections addObject:@{
                @"height":@(12.0f),
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
