//
//  WKIncomingWebhookManager.h
//  WuKongBase
//
//  群入站 Webhook 数据源 + 测试推送串行/冷却状态机。
//
//  - 6 个接口与 octo-server `/v1/groups/{group_no}/incoming-webhooks*` 一一对应。
//  - 测试推送会向群内发真实消息，连点会刷屏 —— 状态机保证：
//    1) 全局同一时刻仅一条测试在飞（任一在飞，所有 webhook 的"测试"按钮都置灰）；
//    2) 单条 webhook 测试后进入 3s 冷却。
//

#import <Foundation/Foundation.h>
#import "WKIncomingWebhook.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKIncomingWebhookManager : NSObject

+ (instancetype)shared;

// list 列表
- (void)listWebhooksOfGroup:(NSString *)groupNo
                   complete:(void(^)(NSArray<WKIncomingWebhook *> *items, NSError * _Nullable error))complete;

// 新建 — token / url / urls 仅此一次随响应返回。
- (void)createWebhookForGroup:(NSString *)groupNo
                         name:(NSString *)name
                       avatar:(NSString * _Nullable)avatar
                     complete:(void(^)(WKIncomingWebhook * _Nullable webhook, NSError * _Nullable error))complete;

// 编辑（只发变化字段）
- (void)updateWebhook:(NSString *)webhookId
              ofGroup:(NSString *)groupNo
                 name:(NSString * _Nullable)name
               avatar:(NSString * _Nullable)avatar
               status:(NSNumber * _Nullable)status
             complete:(void(^)(NSError * _Nullable error))complete;

// 删除（软删）
- (void)deleteWebhook:(NSString *)webhookId
              ofGroup:(NSString *)groupNo
             complete:(void(^)(NSError * _Nullable error))complete;

// 重置 token（同 create 一次性返回）
- (void)regenerateWebhook:(NSString *)webhookId
                  ofGroup:(NSString *)groupNo
                 complete:(void(^)(WKIncomingWebhook * _Nullable webhook, NSError * _Nullable error))complete;

// 测试发送 — 走串行 + 冷却守卫；命中守卫直接 complete(NO,nil) 不打接口。
- (void)testWebhook:(NSString *)webhookId
            ofGroup:(NSString *)groupNo
           complete:(void(^)(BOOL sent, NSError * _Nullable error))complete;

#pragma mark - 测试推送状态机查询（给 UI 置灰用）

// 任一 webhook 的测试请求是否在飞。
@property(nonatomic,readonly) BOOL hasTestInFlight;

// 该 webhook 是否正处于 3s 冷却。
- (BOOL)isWebhookOnTestCooldown:(NSString *)webhookId;

@end

NS_ASSUME_NONNULL_END
