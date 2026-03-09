//
//  WKFormSection.m
//  WuKongBase
//
//  Created by tt on 2020/1/21.
//

#import "WKFormSection.h"

@implementation WKFormSection

+(instancetype) withItems:(NSArray<WKFormItemModel*>*)items height:(CGFloat)height {
    return [WKFormSection withItems:items height:height headView:nil];
}
+(instancetype) withItems:(NSArray<WKFormItemModel*>*)items height:(CGFloat)height headView:(UIView*)headView{
    WKFormSection *section = [WKFormSection new];
    section.items = items;
    section.height = height;
    section.headView = headView;
    return section;
}

@end
