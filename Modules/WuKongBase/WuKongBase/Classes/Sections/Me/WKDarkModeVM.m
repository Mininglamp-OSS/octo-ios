//
//  WKDarkModeVM.m
//  WuKongBase
//
//  Created by tt on 2020/12/11.
//

#import "WKDarkModeVM.h"
#import "WKSwitchItemCell.h"

@interface WKDarkModeVM ()


@end

@implementation WKDarkModeVM

- (NSArray<NSDictionary *> *)tableSectionMaps {
    
    NSMutableArray *items = [NSMutableArray array];
    
    
    __weak typeof(self) weakSelf = self;
    [items addObject:@{
        @"height": @(0.0f),
        @"remark": LLang(@"开启后，将跟随系统打开或关闭深色模式"),
        @"items": @[
                @{
                    @"class": WKSwitchItemModel.class,
                    @"label": LLang(@"跟随系统"),
                    @"on": @(WKApp.shared.config.darkModeWithSystem),
                    @"onSwitch":^(BOOL on){
                        WKApp.shared.config.darkModeWithSystem = on;
                        if(on) {
                            if (@available(iOS 13.0, *)) {
                                if(UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                                    WKApp.shared.config.style = WKSystemStyleDark;
                                }else{
                                    WKApp.shared.config.style = WKSystemStyleLight;
                                }
                               
                            }
                        }
                        [weakSelf reloadData];
                    }
                }
        ],
    }];
    if(!WKApp.shared.config.darkModeWithSystem) {
        [items addObjectsFromArray:@[
            @{
                @"height":@(10.0f),
                @"items": @[
                        @{
                                @"class": WKLabelItemSelectModel.class,
                                @"label":LLang(@"普通模式"),
                                @"selected": @(WKApp.shared.config.style==WKSystemStyleLight),
                                @"onClick":^{
                                    WKApp.shared.config.style = WKSystemStyleLight;
                                    [weakSelf reloadData];
                                }
                        },
                        @{
                                @"class": WKLabelItemSelectModel.class,
                                @"label":LLang(@"深色模式"),
                                @"selected": @(WKApp.shared.config.style==WKSystemStyleDark),
                                @"onClick":^{
                                    WKApp.shared.config.style = WKSystemStyleDark;
                                    [weakSelf reloadData];
                                }
                        }
                ]
            },
        ]];
    }
    
    return items;
}

@end
