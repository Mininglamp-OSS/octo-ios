//
//  OctoSummaryModels.m
//  OctoContext
//

#import "OctoSummaryModels.h"

@implementation OctoSummaryModelHelper

+ (NSInteger)integerFromValue:(id)v {
    if (!v || v == [NSNull null]) return 0;
    if ([v respondsToSelector:@selector(integerValue)]) return [v integerValue];
    return 0;
}
+ (int64_t)int64FromValue:(id)v {
    if (!v || v == [NSNull null]) return 0;
    if ([v respondsToSelector:@selector(longLongValue)]) return [v longLongValue];
    return 0;
}
+ (BOOL)boolFromValue:(id)v {
    if (!v || v == [NSNull null]) return NO;
    if ([v isKindOfClass:NSNumber.class]) return [v boolValue];
    if ([v isKindOfClass:NSString.class]) {
        NSString *s = [(NSString *)v lowercaseString];
        return [s isEqualToString:@"true"] || [s isEqualToString:@"1"] || [s isEqualToString:@"yes"];
    }
    return NO;
}
+ (NSString *)stringFromValue:(id)v {
    if (!v || v == [NSNull null]) return @"";
    if ([v isKindOfClass:NSString.class]) return v;
    return [NSString stringWithFormat:@"%@", v];
}
+ (nullable NSString *)nullableStringFromValue:(id)v {
    if (!v || v == [NSNull null]) return nil;
    if ([v isKindOfClass:NSString.class]) return v;
    return [NSString stringWithFormat:@"%@", v];
}

@end

#define IINT(k)   [OctoSummaryModelHelper integerFromValue:dict[k]]
#define I64(k)    [OctoSummaryModelHelper int64FromValue:dict[k]]
#define BBOOL(k)  [OctoSummaryModelHelper boolFromValue:dict[k]]
#define STR(k)    [OctoSummaryModelHelper stringFromValue:dict[k]]
#define NSTR(k)   [OctoSummaryModelHelper nullableStringFromValue:dict[k]]
// ARR: 服务端可能给 null / 缺字段 / 类型错位时, NSJSONSerialization 解出 NSNull 或非数组,
// 直接 for-in 走 countByEnumeratingWithState: 会立刻 unrecognized selector 崩。
// 守卫 NSArray 类型, 不是数组就当空数组, parse 路径不再因可选数组字段缺失而崩。
#define ARR(k)    ({ id _v = dict[k]; [_v isKindOfClass:NSArray.class] ? (NSArray *)_v : (NSArray *)@[]; })

#pragma mark - SourceItem

@implementation OctoSourceItem
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoSourceItem *m = [OctoSourceItem new];
    m.sourceType = (OctoSourceType)IINT(@"source_type");
    m.sourceId   = STR(@"source_id");
    m.sourceName = NSTR(@"source_name");
    return m;
}
- (NSDictionary *)toDict {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"source_type"] = @(self.sourceType);
    d[@"source_id"]   = self.sourceId ?: @"";
    if (self.sourceName.length > 0) d[@"source_name"] = self.sourceName;
    return d;
}
@end

#pragma mark - Participant

@implementation OctoParticipant
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoParticipant *m = [OctoParticipant new];
    m.userId      = STR(@"user_id");
    m.userName    = NSTR(@"user_name");
    m.status      = (OctoParticipantStatus)IINT(@"status");
    m.confirmedAt = NSTR(@"confirmed_at");
    return m;
}
@end

#pragma mark - Citation

@implementation OctoCitationContextMessage
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoCitationContextMessage *m = [OctoCitationContextMessage new];
    m.sender     = STR(@"sender");
    m.content    = STR(@"content");
    m.sentAt     = STR(@"sent_at");
    m.messageSeq = (uint32_t)IINT(@"message_seq");
    return m;
}
@end

@implementation OctoCitationItem
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoCitationItem *m = [OctoCitationItem new];
    m.index       = IINT(@"index");
    m.sender      = STR(@"sender");
    m.content     = STR(@"content");
    m.sentAt      = STR(@"sent_at");
    m.source      = NSTR(@"source");
    m.channelId   = NSTR(@"channel_id");
    m.messageSeq  = (uint32_t)IINT(@"message_seq");
    m.channelType = IINT(@"channel_type");

    NSMutableArray *bef = [NSMutableArray array];
    for (NSDictionary *d in ARR(@"context_before")) {
        if ([d isKindOfClass:NSDictionary.class]) {
            OctoCitationContextMessage *cm = [OctoCitationContextMessage modelFromDict:d];
            if (cm) [bef addObject:cm];
        }
    }
    m.contextBefore = bef;

    NSMutableArray *aft = [NSMutableArray array];
    for (NSDictionary *d in ARR(@"context_after")) {
        if ([d isKindOfClass:NSDictionary.class]) {
            OctoCitationContextMessage *cm = [OctoCitationContextMessage modelFromDict:d];
            if (cm) [aft addObject:cm];
        }
    }
    m.contextAfter = aft;
    return m;
}
@end

#pragma mark - Result types

@implementation OctoSummaryResult
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoSummaryResult *m = [OctoSummaryResult new];
    m.content        = STR(@"content");
    m.totalMsgCount  = IINT(@"total_msg_count");
    m.totalTokenUsed = IINT(@"total_token_used");
    m.modelVersion   = NSTR(@"model_version");
    m.version        = IINT(@"version");
    m.generatedAt    = NSTR(@"generated_at");
    NSMutableArray *cs = [NSMutableArray array];
    for (NSDictionary *d in ARR(@"citations")) {
        if ([d isKindOfClass:NSDictionary.class]) {
            OctoCitationItem *c = [OctoCitationItem modelFromDict:d];
            if (c) [cs addObject:c];
        }
    }
    m.citations = cs;
    return m;
}
@end

@implementation OctoPersonalResult
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoPersonalResult *m = [OctoPersonalResult new];
    m.workerStatus = IINT(@"worker_status");
    m.content      = NSTR(@"content");
    m.submittedAt  = NSTR(@"submitted_at");
    m.generatedAt  = NSTR(@"generated_at");
    m.msgCount     = IINT(@"msg_count");
    NSMutableArray *cs = [NSMutableArray array];
    for (NSDictionary *d in ARR(@"citations")) {
        if ([d isKindOfClass:NSDictionary.class]) {
            OctoCitationItem *c = [OctoCitationItem modelFromDict:d];
            if (c) [cs addObject:c];
        }
    }
    m.citations = cs;
    return m;
}
@end

@implementation OctoMemberStatus
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoMemberStatus *m = [OctoMemberStatus new];
    m.userId      = STR(@"user_id");
    m.userName    = STR(@"user_name");
    m.status      = STR(@"status");
    m.submittedAt = NSTR(@"submitted_at");
    m.content     = NSTR(@"content");
    NSMutableArray *cs = [NSMutableArray array];
    for (NSDictionary *d in ARR(@"citations")) {
        if ([d isKindOfClass:NSDictionary.class]) {
            OctoCitationItem *c = [OctoCitationItem modelFromDict:d];
            if (c) [cs addObject:c];
        }
    }
    m.citations = cs;
    return m;
}
@end

#pragma mark - List & Detail

static NSArray<OctoSourceItem *> *parseSources(NSDictionary *dict) {
    NSMutableArray *arr = [NSMutableArray array];
    for (NSDictionary *d in ARR(@"sources")) {
        if ([d isKindOfClass:NSDictionary.class]) {
            OctoSourceItem *s = [OctoSourceItem modelFromDict:d];
            if (s) [arr addObject:s];
        }
    }
    return arr;
}

static NSArray<OctoParticipant *> *parseParticipants(NSDictionary *dict) {
    NSMutableArray *arr = [NSMutableArray array];
    for (NSDictionary *d in ARR(@"participants")) {
        if ([d isKindOfClass:NSDictionary.class]) {
            OctoParticipant *p = [OctoParticipant modelFromDict:d];
            if (p) [arr addObject:p];
        }
    }
    return arr;
}

@implementation OctoSummaryListItem
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoSummaryListItem *m = [OctoSummaryListItem new];
    m.taskId            = I64(@"task_id");
    m.taskNo            = NSTR(@"task_no");
    m.title             = STR(@"title");
    m.summaryMode       = (OctoSummaryMode)IINT(@"summary_mode");
    m.status            = (OctoTaskStatus)IINT(@"status");
    m.triggerType       = (OctoTriggerType)IINT(@"trigger_type");
    id sched            = dict[@"schedule_id"];
    m.scheduleId        = (sched && sched != [NSNull null]) ? @([OctoSummaryModelHelper int64FromValue:sched]) : nil;
    m.timeRangeStart    = NSTR(@"time_range_start");
    m.timeRangeEnd      = NSTR(@"time_range_end");
    m.sources           = parseSources(dict);
    m.participants      = parseParticipants(dict);
    m.totalMsgCount     = IINT(@"total_msg_count");
    m.creatorName       = NSTR(@"creator_name");
    m.originChannelId   = NSTR(@"origin_channel_id");
    m.originChannelType = IINT(@"origin_channel_type");
    m.createdAt         = NSTR(@"created_at");
    m.completedAt       = NSTR(@"completed_at");
    return m;
}
@end

@implementation OctoSummaryPermissions
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoSummaryPermissions *m = [OctoSummaryPermissions new];
    m.canEdit = BBOOL(@"can_edit");
    return m;
}
@end

@implementation OctoSummaryDetail
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoSummaryDetail *m = [OctoSummaryDetail new];
    m.taskId            = I64(@"task_id");
    m.taskNo            = NSTR(@"task_no");
    m.title             = STR(@"title");
    m.summaryMode       = (OctoSummaryMode)IINT(@"summary_mode");
    m.status            = (OctoTaskStatus)IINT(@"status");
    m.triggerType       = (OctoTriggerType)IINT(@"trigger_type");
    m.timeRangeStart    = NSTR(@"time_range_start");
    m.timeRangeEnd      = NSTR(@"time_range_end");
    m.sources           = parseSources(dict);
    m.participants      = parseParticipants(dict);
    NSDictionary *res   = dict[@"result"];
    m.result            = ([res isKindOfClass:NSDictionary.class]) ? [OctoSummaryResult modelFromDict:res] : nil;
    m.errorMessage      = NSTR(@"error_message");
    id sched            = dict[@"schedule_id"];
    m.scheduleId        = (sched && sched != [NSNull null]) ? @([OctoSummaryModelHelper int64FromValue:sched]) : nil;
    m.originChannelId   = NSTR(@"origin_channel_id");
    m.originChannelType = IINT(@"origin_channel_type");
    m.createdAt         = NSTR(@"created_at");
    m.updatedAt         = NSTR(@"updated_at");
    id rid              = dict[@"result_id"];
    m.resultId          = (rid && rid != [NSNull null]) ? @([OctoSummaryModelHelper int64FromValue:rid]) : nil;
    m.resultEditedAt    = NSTR(@"result_edited_at");
    m.resultIsEdited    = BBOOL(@"result_is_edited");
    NSDictionary *perm  = dict[@"permissions"];
    m.permissions       = ([perm isKindOfClass:NSDictionary.class]) ? [OctoSummaryPermissions modelFromDict:perm] : nil;
    return m;
}
@end

@implementation OctoBatchStatusItem
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoBatchStatusItem *m = [OctoBatchStatusItem new];
    m.taskId    = I64(@"id");
    m.status    = (OctoTaskStatus)IINT(@"status");
    m.progress  = IINT(@"progress");
    m.updatedAt = NSTR(@"updated_at");
    return m;
}
@end

#pragma mark - Candidates / Templates

@implementation OctoChatCandidate
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoChatCandidate *m = [OctoChatCandidate new];
    m.chatId        = STR(@"chat_id");
    m.chatType      = STR(@"chat_type");
    m.name          = STR(@"name");
    id mc           = dict[@"member_count"];
    m.memberCount   = (mc && mc != [NSNull null]) ? @([OctoSummaryModelHelper integerFromValue:mc]) : nil;
    m.parentGroupNo = NSTR(@"parent_group_no");
    m.isBot         = BBOOL(@"is_bot");
    m.isArchived    = BBOOL(@"is_archived");
    return m;
}
@end

@implementation OctoMemberCandidate
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoMemberCandidate *m = [OctoMemberCandidate new];
    m.userId     = STR(@"user_id");
    m.name       = STR(@"name");
    m.avatar     = NSTR(@"avatar");
    m.department = NSTR(@"department");
    return m;
}
@end

@implementation OctoTopicTemplatePlaceholder
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoTopicTemplatePlaceholder *m = [OctoTopicTemplatePlaceholder new];
    m.key   = STR(@"key");
    m.label = STR(@"label");
    NSArray *p = dict[@"position"];
    if ([p isKindOfClass:NSArray.class] && p.count == 2) m.position = p;
    return m;
}
@end

@implementation OctoTopicTemplate
+ (instancetype)modelFromDict:(NSDictionary *)dict {
    if (!dict) return nil;
    OctoTopicTemplate *m = [OctoTopicTemplate new];
    m.templateId = STR(@"id");
    m.label      = STR(@"label");
    m.icon       = NSTR(@"icon");
    m.desc       = NSTR(@"description");
    m.type       = STR(@"type");
    m.pattern    = STR(@"pattern");
    NSMutableArray *ps = [NSMutableArray array];
    for (NSDictionary *d in ARR(@"placeholders")) {
        if ([d isKindOfClass:NSDictionary.class]) {
            OctoTopicTemplatePlaceholder *p = [OctoTopicTemplatePlaceholder modelFromDict:d];
            if (p) [ps addObject:p];
        }
    }
    m.placeholders = ps;
    return m;
}
@end
