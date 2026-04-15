//
//  WKCategoryEntity.m
//  WuKongBase
//

#import "WKCategoryEntity.h"

static NSString* safeString(id value) {
    if (!value || [value isKindOfClass:[NSNull class]]) return @"";
    if ([value isKindOfClass:[NSString class]]) return value;
    return [NSString stringWithFormat:@"%@", value];
}

@implementation WKCategoryGroup

+ (instancetype)fromDict:(NSDictionary *)dict {
    WKCategoryGroup *g = [[WKCategoryGroup alloc] init];
    g.group_no = safeString(dict[@"group_no"]);
    g.name = safeString(dict[@"name"]);
    g.category_sort = [dict[@"category_sort"] integerValue];
    return g;
}

@end

@implementation WKCategoryEntity

+ (instancetype)fromDict:(NSDictionary *)dict {
    WKCategoryEntity *e = [[WKCategoryEntity alloc] init];
    e.category_id = safeString(dict[@"category_id"]);
    e.name = safeString(dict[@"name"]);
    e.sort = [dict[@"sort"] integerValue];
    NSArray *groupsArr = dict[@"groups"];
    if ([groupsArr isKindOfClass:[NSArray class]]) {
        NSMutableArray *groups = [NSMutableArray array];
        for (NSDictionary *gd in groupsArr) {
            if ([gd isKindOfClass:[NSDictionary class]]) {
                [groups addObject:[WKCategoryGroup fromDict:gd]];
            }
        }
        e.groups = groups;
    }
    return e;
}

+ (NSArray<WKCategoryEntity *> *)fromDictArray:(NSArray *)array {
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *dict in array) {
        if ([dict isKindOfClass:[NSDictionary class]]) {
            [result addObject:[WKCategoryEntity fromDict:dict]];
        }
    }
    return result;
}

@end
