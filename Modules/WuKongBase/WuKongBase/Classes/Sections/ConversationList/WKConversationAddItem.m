//
//  WKConversationAddItem.m
//  WuKongBase
//
//  Created by tt on 2020/12/16.
//

#import "WKConversationAddItem.h"

@implementation WKConversationAddItem

+(WKConversationAddItem*) title:(NSString*)title icon:(UIImage*)icon onClick:(ConversationAddClick)click {
    WKConversationAddItem *item = [WKConversationAddItem new];
    item.title = title;
    item.icon = icon;
    item.onClick = click;
    return item;
}

@end
