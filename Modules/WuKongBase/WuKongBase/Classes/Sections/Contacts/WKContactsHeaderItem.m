//
//  ContactsHeaderItem.m
//  WuKongBase
//
//  Created by tt on 2020/1/4.
//

#import "WKContactsHeaderItem.h"

@implementation WKContactsHeaderItem

+(WKContactsHeaderItem*) initWithSid:(NSString*)sid title:(NSString*)title icon:(NSString*)icon moduleID:(NSString*)moduleID onClick:(WKContactsHeaderItemClick)onClick{
    WKContactsHeaderItem *item = [[WKContactsHeaderItem alloc] init];
    item.sid = sid;
    item.title = title;
    item.icon = icon;
    item.moduleID = moduleID;
    item.onClick = onClick;
    return item;
}
@end
