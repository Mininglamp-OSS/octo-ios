//
//  WKMePushSettingVM.m
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import "WKMePushSettingVM.h"
#import "WKTableSectionUtil.h"
#import "WKLabelItemCell.h"
#import "WKSwitchItemCell.h"
#import "WKMySettingManager.h"
@implementation WKMePushSettingVM


- (NSArray<NSDictionary *> *)tableSectionMaps {
    BOOL newMsgNotice = [WKMySettingManager shared].newMsgNotice; // 新消息通知
    BOOL msgShowDetail = [WKMySettingManager shared].msgShowDetail; // 通知是否显示详情
    BOOL voiceOn = [WKMySettingManager shared].voiceOn; // 声音开启
    BOOL shockOn = [WKMySettingManager shared].shockOn; // 震动开启
    BOOL depDisabled = !newMsgNotice; // 主开关关闭时，子项禁用

    __weak typeof(self) weakSelf = self;
    return @[
        @{
            @"height":@(0.0f),
            @"items":@[
                [self switchItem:LLang(@"新消息通知") on:newMsgNotice disabled:NO showBottom:YES onSwitch:^(BOOL on){
                    [[WKMySettingManager shared] newMsgNotice:on];
                    [weakSelf reloadData];
                }],
                [self switchItem:LLang(@"通知显示消息详情") on:msgShowDetail disabled:depDisabled showBottom:YES onSwitch:^(BOOL on){
                    [[WKMySettingManager shared] msgShowDetail:on];
                }],
                [self switchItem:LLang(@"声音") on:voiceOn disabled:depDisabled showBottom:YES onSwitch:^(BOOL on){
                    [[WKMySettingManager shared] voiceOn:on];
                }],
                [self switchItem:LLang(@"震动") on:shockOn disabled:depDisabled showBottom:NO onSwitch:^(BOOL on){
                    [[WKMySettingManager shared] shockOn:on];
                }],
            ],
        },
    ];
}

- (NSDictionary *)switchItem:(NSString *)label on:(BOOL)on disabled:(BOOL)disabled showBottom:(BOOL)showBottom onSwitch:(void(^)(BOOL))handler {
    return @{
        @"class":WKSwitchItemModel.class,
        @"label":label,
        @"on":@(on),
        @"disable":@(disabled),
        @"showBottomLine":@(showBottom),
        @"bottomLeftSpace":@(17.0f),
        @"bottomRightSpace":@(17.0f),
        @"cellHeight":@(52.0f),
        @"onSwitch":handler ?: ^(BOOL on){},
    };
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
