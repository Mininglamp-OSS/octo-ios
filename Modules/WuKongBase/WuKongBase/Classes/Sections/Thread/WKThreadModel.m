//
//  WKThreadModel.m
//  WuKongBase
//

#import "WKThreadModel.h"
#import "WKConst.h"

@implementation WKThreadModel

+ (instancetype)fromDict:(NSDictionary *)dict {
    WKThreadModel *model = [[WKThreadModel alloc] init];
    model.shortId              = dict[@"short_id"] ?: @"";
    model.groupNo              = dict[@"group_no"] ?: @"";
    model.channelId            = dict[@"channel_id"] ?: @"";
    model.channelType          = [dict[@"channel_type"] unsignedCharValue];
    model.name                 = dict[@"name"] ?: @"";
    model.creatorUid           = dict[@"creator_uid"] ?: @"";
    model.creatorName          = dict[@"creator_name"] ?: @"";
    model.status               = [dict[@"status"] integerValue];
    model.memberCount          = [dict[@"member_count"] integerValue];
    model.messageCount         = [dict[@"message_count"] integerValue];
    model.unreadCount          = [dict[@"unread_count"] integerValue];
    model.isMember             = [dict[@"is_member"] boolValue];
    model.isDeleted            = [dict[@"is_deleted"] boolValue];
    model.lastMessageContent   = dict[@"last_message_content"];
    model.lastMessageSenderName = dict[@"last_message_sender_name"];
    model.sourceMessageId      = dict[@"source_message_id"] ? [NSString stringWithFormat:@"%@", dict[@"source_message_id"]] : nil;
    model.createdAt            = dict[@"created_at"] ?: @"";
    model.updatedAt            = dict[@"updated_at"] ?: @"";
    model.hasThreadMd          = [dict[@"has_thread_md"] boolValue];
    model.threadMdVersion      = [dict[@"thread_md_version"] integerValue];
    return model;
}

+ (NSArray<WKThreadModel *> *)fromDictArray:(NSArray<NSDictionary *> *)array {
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:array.count];
    for (id item in array) {
        if ([item isKindOfClass:[NSDictionary class]]) {
            [results addObject:[WKThreadModel fromDict:item]];
        }
    }
    return [results copy];
}

- (WKChannel *)toChannel {
    return [WKChannel channelID:self.channelId channelType:WK_COMMUNITY_TOPIC];
}

@end
