//
//  WKMeItem.m
//  WuKongBase
//
//  Created by tt on 2020/7/14.
//

#import "WKMeItem.h"

@implementation WKMeItem

+(WKMeItem*) initWithTitle:(NSString*)title icon:(UIImage*)icon onClick:(void(^)(void))onClick {
    WKMeItem *item = [WKMeItem new];
    item.title = title;
    item.icon = icon;
    item.onClick = onClick;
    return item;
}


+(WKMeItem*) initWithTitle:(NSString*)title icon:(UIImage*)icon sectionHeight:(CGFloat)sectionHeight onClick:(void(^)(void))onClick {
    WKMeItem *item = [WKMeItem new];
    item.title = title;
    item.sectionHeight = sectionHeight;
    item.icon = icon;
    item.onClick = onClick;
    return item;
}

+(WKMeItem*) initWithTitle:(NSString*)title icon:(UIImage*)icon nextSectionHeight:(CGFloat)nextSectionHeight onClick:(void(^)(void))onClick {
    WKMeItem *item = [WKMeItem new];
    item.title = title;
    item.nextSectionHeight = nextSectionHeight;
    item.icon = icon;
    item.onClick = onClick;
    return item;
}
@end
