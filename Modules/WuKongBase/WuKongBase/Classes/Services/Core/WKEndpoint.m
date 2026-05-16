//
//  WKEndpoint.m
//  WuKongCore
//
//  Created by tt on 2019/12/1.
//

#import "WKEndpoint.h"

@implementation WKEndpoint

+(WKEndpoint*) initWithSid:(NSString*)sid handler:(id)handler category:(NSString* __nullable)category sort:(NSNumber* __nullable)sort {
    WKEndpoint *point = [[WKEndpoint alloc] init];
    point.sid = sid;
    point.handler = handler;
    point.category = category;
    point.sort = sort;
    return point;
}
+(WKEndpoint*) initWithSid:(NSString*)sid handler:(id)handler category:(NSString *)category {
    return [self initWithSid:sid handler:handler category:category sort:nil];
}

+(WKEndpoint*) initWithSid:(NSString*)sid handler:(id)handler {
    return [self initWithSid:sid handler:handler category:nil];
}

@end
