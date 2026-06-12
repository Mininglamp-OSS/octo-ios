//
//  OctoSummaryAPI.h
//  OctoContext
//
//  对齐 octo-web/packages/dmworksummary/src/api/summaryApi.ts。
//  baseURL = WKApp.config.apiBaseUrl + "/summary/api/v1"。
//  request header 注入 token / X-Space-Id / Accept-Language。
//  response envelope: { code, message, data } —— 已在底层解开 .data。
//
//  V1 不实现 schedule CRUD 与 Matters 转发(对应推 v2 / v3)。
//

#import <Foundation/Foundation.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^OctoSummaryCallback)(id _Nullable result, NSError *_Nullable error);

@interface OctoSummaryAPI : NSObject

+ (instancetype)shared;

#pragma mark - Core summary

/// POST /summaries —— 创建总结。result = @{@"task_id": NSNumber}。
- (void)createSummaryWithParams:(NSDictionary *)params callback:(OctoSummaryCallback)cb;

/// GET /summaries —— 列表。result = @{@"items": NSArray<OctoSummaryListItem*>, @"total": NSNumber}。
- (void)listSummariesWithParams:(nullable NSDictionary *)params callback:(OctoSummaryCallback)cb;

/// GET /summaries/:id —— 详情。result = OctoSummaryDetail。
- (void)getSummaryDetail:(int64_t)taskId callback:(OctoSummaryCallback)cb;

/// DELETE /summaries/:id。result = nil。
- (void)deleteSummary:(int64_t)taskId callback:(OctoSummaryCallback)cb;

/// POST /summaries/:id/regenerate —— 重新生成。topic 可空。result = @{@"task_id": NSNumber}。
- (void)regenerateSummary:(int64_t)taskId topic:(nullable NSString *)topic callback:(OctoSummaryCallback)cb;

/// PUT /summaries/:id/edit —— 编辑。
/// result = @{@"edited_at": NSString} 或 NSError(其中 code 保留 HTTP status, 409 = 冲突)。
- (void)editSummary:(int64_t)taskId
            content:(NSString *)content
       baseResultId:(int64_t)baseResultId
           callback:(OctoSummaryCallback)cb;

#pragma mark - Status

/// POST /summaries/batch-status。result = NSArray<OctoBatchStatusItem*>。
- (void)batchStatus:(NSArray<NSNumber *> *)taskIds callback:(OctoSummaryCallback)cb;

/// POST /summaries/:id/cancel。result = nil。
- (void)cancelSummary:(int64_t)taskId callback:(OctoSummaryCallback)cb;

/// POST /summaries/:id/confirm —— 参与者确认 + 提交来源。
- (void)confirmParticipation:(int64_t)taskId
                     sources:(NSArray<OctoSourceItem *> *)sources
                    callback:(OctoSummaryCallback)cb;

/// POST /summaries/:id/decline。
- (void)declineParticipation:(int64_t)taskId callback:(OctoSummaryCallback)cb;

/// POST /summaries/:id/accept。
- (void)acceptInvitation:(int64_t)taskId callback:(OctoSummaryCallback)cb;

/// POST /summaries/:id/respond。action: @"accept" / @"reject"。
- (void)respondToTask:(int64_t)taskId action:(NSString *)action callback:(OctoSummaryCallback)cb;

#pragma mark - Personal (BY_PERSON)

/// GET /summaries/:id/personal。result = OctoPersonalResult。
- (void)getPersonalResult:(int64_t)taskId callback:(OctoSummaryCallback)cb;

/// POST /summaries/:id/submit。
- (void)submitPersonalResult:(int64_t)taskId callback:(OctoSummaryCallback)cb;

/// GET /summaries/:id/members。result = NSArray<OctoMemberStatus*>。
- (void)getMembers:(int64_t)taskId callback:(OctoSummaryCallback)cb;

#pragma mark - Participants & data

/// GET /summaries/:id/participants。result = NSArray<OctoParticipant*>。
- (void)getParticipants:(int64_t)taskId callback:(OctoSummaryCallback)cb;

/// GET /summary-templates —— 主题模板。result = NSArray<OctoTopicTemplate*>。
- (void)getTopicTemplates:(OctoSummaryCallback)cb;

/// GET /summary-infer?topic= —— 主题推断。result = NSDictionary 原样返回。
- (void)inferScope:(NSString *)topic callback:(OctoSummaryCallback)cb;

#pragma mark - Candidates

/// GET /summary-chat-candidates。result = NSArray<OctoChatCandidate*>。
- (void)getChatCandidates:(nullable NSDictionary *)params callback:(OctoSummaryCallback)cb;

/// GET /summary-member-candidates。result = NSArray<OctoMemberCandidate*>。
- (void)getMemberCandidates:(nullable NSDictionary *)params callback:(OctoSummaryCallback)cb;

@end

NS_ASSUME_NONNULL_END
