//
//  WKIncomingWebhook.h
//  WuKongBase
//
//  群入站 Webhook（Incoming Webhook）— 对应群信息页「群消息推送」入口。
//  与 octo-web/packages/dmworkbase/src/Service/IncomingWebhook.ts 模型一一对应，
//  字段命名沿用服务端蛇形原名，方便对照后端契约。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 状态：0 = 禁用，1 = 启用，2 = 已删除（软删除，list 不会返回）
typedef NS_ENUM(NSInteger, WKIncomingWebhookStatus) {
    WKIncomingWebhookStatusDisabled = 0,
    WKIncomingWebhookStatusEnabled  = 1,
    WKIncomingWebhookStatusDeleted  = 2,
};

// `iwh_` 前缀的 fromUID 永远不是真人成员，渲染层据此识别 webhook 推送的消息。
extern NSString * const WKIncomingWebhookUidPrefix;

@interface WKIncomingWebhook : NSObject

@property(nonatomic,copy) NSString *webhookId;
@property(nonatomic,copy) NSString *groupNo;
@property(nonatomic,copy) NSString *name;
// 成员 / bot 创建恒为空字符串；仅群主/管理员可设。
@property(nonatomic,copy) NSString *avatar;
@property(nonatomic,copy) NSString *creatorUid;
@property(nonatomic,assign) WKIncomingWebhookStatus status;
// Unix 秒；从未推送过为 0。
@property(nonatomic,assign) NSTimeInterval lastUsedAt;
// 累计 native 推送次数（test 推送不计）。
@property(nonatomic,assign) NSInteger callCount;
@property(nonatomic,assign) NSTimeInterval createdAt;

// 仅 create / regenerate 响应返回，list / update 拿不到。
@property(nonatomic,copy,nullable) NSString *token;
// 相对路径或绝对 URL；调用方走 absoluteURLFor: 拼成可复制的绝对地址。
@property(nonatomic,copy,nullable) NSString *url;
@property(nonatomic,copy,nullable) NSString *urlNative;
@property(nonatomic,copy,nullable) NSString *urlGithub;
@property(nonatomic,copy,nullable) NSString *urlWecom;

+ (instancetype)fromDict:(NSDictionary *)dict;

// 当前登录者是否能管理此 webhook：群主/管理员管全部，普通成员仅能管自己创建的。
// 与 octo-web canManageIncomingWebhook 行为一致；服务端仍会兜底裁决。
- (BOOL)canManageByCurrentUser:(BOOL)isManagerOrCreator;

// 仅 enabled 可测：禁用/删除态走 test 会绕开推送面的 enabled 检查、向群内发真实消息。
- (BOOL)canTest;

@end

// 服务端返回的相对路径（含 `/v1` 前缀）拼成绝对 URL。
// iOS 端 apiBaseUrl 形如 `https://im.example.com/api/v1/`，与服务端相对路径里的
// `/v1` 段会重复，这里先剥掉再拼，避免出现 `/api/v1/v1/...`。
extern NSString * WKIncomingWebhookAbsoluteURL(NSString * _Nullable relativeUrl, NSString * _Nullable apiBaseUrl);

NS_ASSUME_NONNULL_END
