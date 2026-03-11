//
//  WKSpaceEntity.m
//  WuKongBase
//
//  Created by Claude on 2026/03/11.
//

#import "WKSpaceEntity.h"

@implementation WKSpaceMember

@end

@implementation WKSpaceEntity

+ (NSDictionary *)modelCustomPropertyMapper {
    return @{
        @"desc": @"description"
    };
}

@end
