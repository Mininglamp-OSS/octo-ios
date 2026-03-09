//
//  WKModuleVM.m
//  WuKongBase
//
//  Created by tt on 2023/2/23.
//

#import "WKModuleVM.h"

@implementation WKModuleVM

- (NSArray<NSDictionary *> *)tableSectionMaps {
    __weak typeof(self) weakSelf = self;
    if(!WKApp.shared.remoteConfig.requestAppModuleSuccess) {
        [WKApp.shared.remoteConfig requestConfig:^(NSError * _Nullable error) {
            [weakSelf reloadData];
        }];
    }
    NSArray<WKAppModuleResp*> *modules = WKApp.shared.remoteConfig.modules;
    
    NSMutableArray<NSDictionary*> *items = [NSMutableArray array];
    if(modules && modules.count>0) {
        for (WKAppModuleResp *resp in modules) {
            if(resp.hidden) {
                continue;
            }
            BOOL disable = false;
            BOOL on = false;
            if(resp.status == WKAppModuleStatusDisable) {
                on = false;
                disable = true;
            }else if(resp.status == WKAppModuleStatusEdit) {
                on = true;
                disable = false;
            }else if(resp.status == WKAppModuleStatusNoEdit) {
                on = true;
                disable = true;
            }
            if(!disable) {
                on = [WKApp.shared.remoteConfig moduleOn:resp.sid];
            }
            
            NSString *title = @"";
            NSNumber *sectionHeight = WKSectionHeight;
           
            
            [items addObject:@{
                @"height":sectionHeight,
                @"title":title,
                @"remark":resp.desc?:@"",
                @"items": @[
                    @{
                        @"class":WKSwitchItemModel.class,
                        @"label":resp.name?:@"",
                        @"on":@(on),
                        @"disable": @(disable),
                        @"onSwitch":^(BOOL on){
                            [WKApp.shared.remoteConfig modules:resp.sid on:on];
                            [weakSelf reloadData];
                            weakSelf.settingChange = true;
                        }
                    }
                ],
            }];
        }
    }
    
    return items;
}

@end
