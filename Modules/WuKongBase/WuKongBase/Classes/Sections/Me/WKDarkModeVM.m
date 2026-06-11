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
    // 实际 UI 由 WKDarkModeVC 自绘 cardView 提供（tableHeaderView），
    // 这里返回空，避免旧的"跟随系统/普通模式/深色模式"开关行残留。
    return @[];
}

@end
