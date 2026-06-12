//
//  OctoSummaryModels.h
//  OctoContext
//
//  对齐 octo-web/packages/dmworksummary/src/types/summary.ts。
//  所有 snake_case 字段 → Obj-C camelCase property,
//  字符串通过 +modelFromDict: 工厂方法解析。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Enums

typedef NS_ENUM(NSInteger, OctoSummaryMode) {
    OctoSummaryModeByGroup  = 1,
    OctoSummaryModeByPerson = 2,
};

typedef NS_ENUM(NSInteger, OctoTaskStatus) {
    OctoTaskStatusPending         = 0,
    OctoTaskStatusWaitingConfirm  = 1,
    OctoTaskStatusProcessing      = 2,
    OctoTaskStatusCompleted       = 3,
    OctoTaskStatusFailed          = 4,
    OctoTaskStatusCancelled       = 5,
};

typedef NS_ENUM(NSInteger, OctoTriggerType) {
    OctoTriggerManual    = 1,
    OctoTriggerScheduled = 2,
};

typedef NS_ENUM(NSInteger, OctoSourceType) {
    OctoSourceGroupChat     = 1,
    OctoSourceThread        = 2,
    OctoSourceDirectMessage = 3,
};

typedef NS_ENUM(NSInteger, OctoParticipantStatus) {
    OctoParticipantPending   = 0,
    OctoParticipantConfirmed = 1,
    OctoParticipantDeclined  = 2,
};

#pragma mark - Source / Participant

@interface OctoSourceItem : NSObject
@property(nonatomic, assign) OctoSourceType sourceType;
@property(nonatomic, copy) NSString *sourceId;
@property(nonatomic, copy, nullable) NSString *sourceName;
+ (instancetype)modelFromDict:(NSDictionary *)dict;
- (NSDictionary *)toDict;
@end

@interface OctoParticipant : NSObject
@property(nonatomic, copy) NSString *userId;
@property(nonatomic, copy, nullable) NSString *userName;
@property(nonatomic, assign) OctoParticipantStatus status;
@property(nonatomic, copy, nullable) NSString *confirmedAt;
+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

#pragma mark - Citation

@interface OctoCitationContextMessage : NSObject
@property(nonatomic, copy) NSString *sender;
@property(nonatomic, copy) NSString *content;
@property(nonatomic, copy) NSString *sentAt;
@property(nonatomic, assign) uint32_t messageSeq;
+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

@interface OctoCitationItem : NSObject
@property(nonatomic, assign) NSInteger index;
@property(nonatomic, copy) NSString *sender;
@property(nonatomic, copy) NSString *content;
@property(nonatomic, copy) NSString *sentAt;
@property(nonatomic, copy, nullable) NSString *source;       // 显示用 channel 名
@property(nonatomic, copy, nullable) NSString *channelId;
@property(nonatomic, assign) uint32_t messageSeq;
@property(nonatomic, assign) NSInteger channelType;
@property(nonatomic, strong) NSArray<OctoCitationContextMessage *> *contextBefore;
@property(nonatomic, strong) NSArray<OctoCitationContextMessage *> *contextAfter;
+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

#pragma mark - Result

@interface OctoSummaryResult : NSObject
@property(nonatomic, copy) NSString *content;
@property(nonatomic, assign) NSInteger totalMsgCount;
@property(nonatomic, assign) NSInteger totalTokenUsed;
@property(nonatomic, copy, nullable) NSString *modelVersion;
@property(nonatomic, assign) NSInteger version;
@property(nonatomic, copy, nullable) NSString *generatedAt;
@property(nonatomic, strong) NSArray<OctoCitationItem *> *citations;
+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

/// BY_PERSON 个人总结结果
@interface OctoPersonalResult : NSObject
@property(nonatomic, assign) NSInteger workerStatus;     // 0/1/2/3
@property(nonatomic, copy, nullable) NSString *content;
@property(nonatomic, strong) NSArray<OctoCitationItem *> *citations;
@property(nonatomic, copy, nullable) NSString *submittedAt;
@property(nonatomic, copy, nullable) NSString *generatedAt;
@property(nonatomic, assign) NSInteger msgCount;
+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

@interface OctoMemberStatus : NSObject
@property(nonatomic, copy) NSString *userId;
@property(nonatomic, copy) NSString *userName;
@property(nonatomic, copy) NSString *status;             // pending / processing / completed / submitted
@property(nonatomic, copy, nullable) NSString *submittedAt;
@property(nonatomic, copy, nullable) NSString *content;
@property(nonatomic, strong) NSArray<OctoCitationItem *> *citations;
+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

#pragma mark - List & Detail

@interface OctoSummaryListItem : NSObject
@property(nonatomic, assign) int64_t taskId;
@property(nonatomic, copy, nullable) NSString *taskNo;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, assign) OctoSummaryMode summaryMode;
@property(nonatomic, assign) OctoTaskStatus status;
@property(nonatomic, assign) OctoTriggerType triggerType;
@property(nonatomic, copy, nullable) NSNumber *scheduleId;
@property(nonatomic, copy, nullable) NSString *timeRangeStart;
@property(nonatomic, copy, nullable) NSString *timeRangeEnd;
@property(nonatomic, strong) NSArray<OctoSourceItem *> *sources;
@property(nonatomic, strong) NSArray<OctoParticipant *> *participants;
@property(nonatomic, assign) NSInteger totalMsgCount;
@property(nonatomic, copy, nullable) NSString *creatorName;
@property(nonatomic, copy, nullable) NSString *originChannelId;
@property(nonatomic, assign) NSInteger originChannelType;
@property(nonatomic, copy, nullable) NSString *createdAt;
@property(nonatomic, copy, nullable) NSString *completedAt;

/// 列表卡片摘要预览(取 result.content 前 N 字)。本地拼接,不走 API。
@property(nonatomic, copy, nullable) NSString *summaryPreview;

+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

@interface OctoSummaryPermissions : NSObject
@property(nonatomic, assign) BOOL canEdit;
+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

@interface OctoSummaryDetail : NSObject
@property(nonatomic, assign) int64_t taskId;
@property(nonatomic, copy, nullable) NSString *taskNo;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, assign) OctoSummaryMode summaryMode;
@property(nonatomic, assign) OctoTaskStatus status;
@property(nonatomic, assign) OctoTriggerType triggerType;
@property(nonatomic, copy, nullable) NSString *timeRangeStart;
@property(nonatomic, copy, nullable) NSString *timeRangeEnd;
@property(nonatomic, strong) NSArray<OctoSourceItem *> *sources;
@property(nonatomic, strong) NSArray<OctoParticipant *> *participants;
@property(nonatomic, strong, nullable) OctoSummaryResult *result;
@property(nonatomic, copy, nullable) NSString *errorMessage;
@property(nonatomic, copy, nullable) NSNumber *scheduleId;
@property(nonatomic, copy, nullable) NSString *originChannelId;
@property(nonatomic, assign) NSInteger originChannelType;
@property(nonatomic, copy, nullable) NSString *createdAt;
@property(nonatomic, copy, nullable) NSString *updatedAt;
@property(nonatomic, copy, nullable) NSNumber *resultId;
@property(nonatomic, copy, nullable) NSString *resultEditedAt;
@property(nonatomic, assign) BOOL resultIsEdited;
@property(nonatomic, strong, nullable) OctoSummaryPermissions *permissions;
+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

@interface OctoBatchStatusItem : NSObject
@property(nonatomic, assign) int64_t taskId;     // dict 里键名是 "id"
@property(nonatomic, assign) OctoTaskStatus status;
@property(nonatomic, assign) NSInteger progress;
@property(nonatomic, copy, nullable) NSString *updatedAt;
+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

#pragma mark - Candidates / Templates

@interface OctoChatCandidate : NSObject
@property(nonatomic, copy) NSString *chatId;
@property(nonatomic, copy) NSString *chatType;          // group / direct / thread
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy, nullable) NSNumber *memberCount;
@property(nonatomic, copy, nullable) NSString *parentGroupNo;
@property(nonatomic, assign) BOOL isBot;
@property(nonatomic, assign) BOOL isArchived;
+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

@interface OctoMemberCandidate : NSObject
@property(nonatomic, copy) NSString *userId;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy, nullable) NSString *avatar;
@property(nonatomic, copy, nullable) NSString *department;
+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

@interface OctoTopicTemplatePlaceholder : NSObject
@property(nonatomic, copy) NSString *key;
@property(nonatomic, copy) NSString *label;
@property(nonatomic, copy, nullable) NSArray<NSNumber *> *position;  // [start, end]
+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

@interface OctoTopicTemplate : NSObject
@property(nonatomic, copy) NSString *templateId;
@property(nonatomic, copy) NSString *label;
@property(nonatomic, copy, nullable) NSString *icon;
@property(nonatomic, copy, nullable) NSString *desc;
@property(nonatomic, copy) NSString *type;              // fixed / parameterized
@property(nonatomic, copy) NSString *pattern;
@property(nonatomic, strong, nullable) NSArray<OctoTopicTemplatePlaceholder *> *placeholders;
+ (instancetype)modelFromDict:(NSDictionary *)dict;
@end

#pragma mark - Helpers

@interface OctoSummaryModelHelper : NSObject

/// 安全把 NSNumber / NSString 转成 NSInteger,nil/NSNull 返回 0。
+ (NSInteger)integerFromValue:(id)v;
+ (int64_t)int64FromValue:(id)v;
+ (BOOL)boolFromValue:(id)v;
+ (NSString *)stringFromValue:(id)v;            // nil/NSNull → @""
+ (nullable NSString *)nullableStringFromValue:(id)v;

@end

NS_ASSUME_NONNULL_END
