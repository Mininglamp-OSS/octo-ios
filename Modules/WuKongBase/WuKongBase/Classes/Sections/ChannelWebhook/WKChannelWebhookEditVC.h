//
//  WKChannelWebhookEditVC.h
//  WuKongBase
//
//  新建 / 编辑 Webhook：
//   - 名称（最长 64）：成员留空时服务端自动命名 `Webhook-<id 后缀>`，且强制加 `Webhook-` 前缀。
//   - 头像 URL（最长 255）：仅群主/管理员可设；成员带 avatar 服务端 400。
//

#import <UIKit/UIKit.h>
#import "WKBaseVC.h"

@class WKChannel, WKIncomingWebhook;

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelWebhookEditVC : WKBaseVC

@property(nonatomic,strong) WKChannel *channel;
@property(nonatomic,assign) BOOL isManagerOrCreator;
// nil 表示新建；非空表示编辑
@property(nonatomic,strong,nullable) WKIncomingWebhook *editingWebhook;

// 创建成功 —— 携带服务端一次性返回的 webhook（含 token/url），由调用方拉起 URL 弹窗
@property(nonatomic,copy,nullable) void(^onCreated)(WKIncomingWebhook *created);
// 编辑成功 —— 调用方刷新列表
@property(nonatomic,copy,nullable) void(^onUpdated)(void);

@end

NS_ASSUME_NONNULL_END
