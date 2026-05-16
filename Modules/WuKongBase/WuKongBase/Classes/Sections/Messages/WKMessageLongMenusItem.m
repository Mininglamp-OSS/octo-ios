//
//  WKMessageLongMenusItem.m
//  WuKongBase
//
//  Created by tt on 2020/1/28.
//

#import "WKMessageLongMenusItem.h"

@implementation WKMessageLongMenusItem

+(instancetype) initWithTitle:(NSString*)title onTap:(void(^)(id<WKConversationContext> context)) onTap {
    WKMessageLongMenusItem *item = [WKMessageLongMenusItem new];
    item.title = title;
    item.onTap = onTap;
    return item;
}

+(instancetype) initWithTitle:(NSString*)title icon:(UIImage*)icon onTap:(void(^)(id<WKConversationContext> context)) onTap {
    WKMessageLongMenusItem *item = [WKMessageLongMenusItem new];
    item.title = title;
    item.onTap = onTap;
    item.icon = icon;
    return item;
}

@end
