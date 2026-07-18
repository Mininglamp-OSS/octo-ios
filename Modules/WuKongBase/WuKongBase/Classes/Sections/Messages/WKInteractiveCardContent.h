//
//  WKInteractiveCardContent.h
//  WuKongBase
//
//  互动卡片（Adaptive Cards，octo/v1 展示档 + octo/v2 交互档）消息正文模型。
//  ContentType = 17（WK_INTERACTIVE_CARD）。与 type7 名片（WKCardContent）无任何关系。
//
//  服务端权威 envelope（见 octo-server pkg/cardmsg、octo-web InteractiveCard）：
//    { "type":17,
//      "card":{ 标准 Adaptive Cards 1.5 JSON，octo 白名单子集 },
//      "plain":"服务端权威纯文本",
//      "card_version":"1.5",
//      "profile":"octo/v1" | "octo/v2",
//      "card_seq":<int64 可选，编辑帧排序>,
//      "transient":<bool 可选，进度帧不入历史> }
//
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConstant.h"

NS_ASSUME_NONNULL_BEGIN

/// octo 卡片 profile 常量
extern NSString *const WKCardProfileV1; // "octo/v1" 展示档
extern NSString *const WKCardProfileV2; // "octo/v2" 交互档
/// 支持的最高 card_version
extern NSString *const WKCardMaxVersion; // "1.5"

@interface WKInteractiveCardContent : WKMessageContent

/// 原始 Adaptive Card JSON 树（根为 {type:"AdaptiveCard"}）。渲染器直接消费。
@property(nonatomic,strong,nullable) NSDictionary *card;
/// 服务端权威纯文本（fallback / 会话摘要用）。
@property(nonatomic,copy,nullable) NSString *plain;
/// profile：octo/v1 | octo/v2。
@property(nonatomic,copy,nullable) NSString *profile;
/// card 支持版本，如 "1.5"。
@property(nonatomic,copy,nullable) NSString *cardVersion;
/// 编辑帧序号；缺省为 -1（无序号，走 last-write-wins）。
@property(nonatomic,assign) NSInteger cardSeq;
/// 瞬时进度帧（不入历史）。
@property(nonatomic,assign) BOOL transient;

/// 是否交互档（octo/v2，允许 Input.* 与 Action.Submit）。
- (BOOL)isInteractiveProfile;

/// profile/version 是否被本客户端支持（用于协商；不支持→降级 plain）。
- (BOOL)isProfileSupported;

/// 内容指纹：profile + card JSON 的稳定序列化。用于 syncSdkCard 式去重，
/// 相同则不重渲（保留 v2 输入态），不同则重渲并失效高度缓存。
- (NSString *)renderFingerprint;

/// 是否可转发：交互档（octo/v2，可能含 Input.*/Action.Submit）**不可转发**（复刻 web）。
/// 纯展示档（octo/v1）可转发。
- (BOOL)isForwardable;

@end

NS_ASSUME_NONNULL_END
