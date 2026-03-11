//
//  WKSpaceEntity.m
//  WuKongBase
//
//  Created by Claude on 2026/03/11.
//

#import "WKSpaceEntity.h"

@implementation WKSpaceMember

+ (WKModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKSpaceMember *member = [WKSpaceMember new];
    member.uid = dictory[@"uid"] ?: @"";
    member.name = dictory[@"name"] ?: @"";
    member.role = [dictory[@"role"] integerValue];
    member.created_at = dictory[@"created_at"] ?: @"";
    return member;
}

- (NSDictionary *)toMap:(ModelMapType)type {
    return @{
        @"uid": self.uid ?: @"",
        @"name": self.name ?: @"",
        @"role": @(self.role),
        @"created_at": self.created_at ?: @""
    };
}

@end

@implementation WKSpaceEntity

+ (WKModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    if (!dictory || ![dictory isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    WKSpaceEntity *space = [WKSpaceEntity new];
    space.space_id = dictory[@"space_id"] ?: @"";
    space.name = dictory[@"name"] ?: @"";
    space.desc = dictory[@"description"] ?: @"";
    space.logo = dictory[@"logo"] ?: @"";
    space.creator = dictory[@"creator"] ?: @"";
    space.status = [dictory[@"status"] integerValue];
    space.role = [dictory[@"role"] integerValue];
    space.max_users = [dictory[@"max_users"] integerValue];
    space.member_count = [dictory[@"member_count"] integerValue];
    space.invite_code = dictory[@"invite_code"] ?: @"";
    space.created_at = dictory[@"created_at"] ?: @"";
    space.updated_at = dictory[@"updated_at"] ?: @"";

    return space;
}

- (NSDictionary *)toMap:(ModelMapType)type {
    return @{
        @"space_id": self.space_id ?: @"",
        @"name": self.name ?: @"",
        @"description": self.desc ?: @"",
        @"logo": self.logo ?: @"",
        @"creator": self.creator ?: @"",
        @"status": @(self.status),
        @"role": @(self.role),
        @"max_users": @(self.max_users),
        @"member_count": @(self.member_count),
        @"invite_code": self.invite_code ?: @"",
        @"created_at": self.created_at ?: @"",
        @"updated_at": self.updated_at ?: @""
    };
}

@end
