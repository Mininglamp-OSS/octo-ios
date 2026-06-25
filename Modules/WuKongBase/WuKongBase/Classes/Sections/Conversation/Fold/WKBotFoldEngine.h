//
//  WKBotFoldEngine.h
//  WuKongBase
//
//  bot 消息折叠引擎（纯逻辑层，无 UI、无副作用）。
//
//  对接：spec `.octospec/tasks/bot-msg-collapse/brief.md`。产品形态对齐 web
//  `packages/dmworkbase/src/Components/Conversation/vm.ts buildRenderItems()`。
//
//  规则（与 web 一致）：
//   - 仅群聊 + 频道有 robot 时启用，单聊不启用。
//   - 连续 ≥2 条 bot 消息、相邻间隔 <120s、其间无五类边界消息 → 折成一组。
//   - 五类边界（image/gif/smallVideo/file/richText）作为分组边界：先 flush 当前
//     组，再独立渲染。语音（voice=4）不视为边界，可折叠。
//   - 最后一组且距今 <120s = isActive；超时即转 history 折叠态。
//
//  iOS 独有：
//   - 当 `alreadyShownAsRegular` 集合包含某条消息的 clientMsgNo 时，那条消息
//     强制独立渲染（"用户停留页面时新到 bot 消息不折叠"的实现机制）。
//   - `disabled` 一键开关，命中后 engine 直接 pass-through 全部独立渲染。
//

#import <Foundation/Foundation.h>
#import "WKMessageModel.h"

NS_ASSUME_NONNULL_BEGIN

@class WKChannelInfo;

typedef NS_ENUM(NSInteger, WKBotFoldRenderItemType) {
    WKBotFoldRenderItemTypeMessage,      // 走原有 cell
    WKBotFoldRenderItemTypeFoldSession,  // 走 WKBotFoldSessionCell
};

#pragma mark - 数据类

/// 折叠分组结果（一张折叠卡内的内容）。
@interface WKBotFoldSession : NSObject
@property(nonatomic, copy, readonly) NSArray<WKMessageModel *> *messages;
/// 参与的 bot（去重，按首次出现顺序）。每个元素是该 bot 在该消息里的 from（WKChannelInfo）。
/// 可能为空（如果 message.from 都是 nil，UI 层应做空兜底）。
@property(nonatomic, copy, readonly) NSArray<WKChannelInfo *> *participants;
/// 这一组是否为 active：最后一组 + 最新一条距今 <activeWindow（默认 120s）。
@property(nonatomic, assign, readonly) BOOL isActive;
/// 是否处于"用户已展开"视觉态：YES 时 UI 应当渲染紧凑的"收起 X 条"提示条，
/// 同时该组的子消息会作为独立 RenderItem 紧随其后渲染。
@property(nonatomic, assign, readonly) BOOL expanded;
- (instancetype)initWithMessages:(NSArray<WKMessageModel *> *)messages
                    participants:(NSArray<WKChannelInfo *> *)participants
                        isActive:(BOOL)isActive
                        expanded:(BOOL)expanded;
@end

@interface WKBotFoldRenderItem : NSObject
@property(nonatomic, assign, readonly) WKBotFoldRenderItemType type;
/// type == Message 时非空。
@property(nonatomic, strong, readonly, nullable) WKMessageModel *message;
/// type == FoldSession 时非空。
@property(nonatomic, strong, readonly, nullable) WKBotFoldSession *foldSession;
+ (instancetype)itemWithMessage:(WKMessageModel *)message;
+ (instancetype)itemWithFoldSession:(WKBotFoldSession *)foldSession;
@end

#pragma mark - 配置

@interface WKBotFoldEngineConfig : NSObject
/// 最小成组数（包含），默认 2。
@property(nonatomic, assign) NSInteger minGroupSize;
/// 相邻 bot 消息时间差阈值（秒），超过即断组，默认 120。
@property(nonatomic, assign) NSTimeInterval gapThreshold;
/// active 窗口（秒），最后一组最新消息距 referenceTime 在此窗口内即 active，默认 120。
@property(nonatomic, assign) NSTimeInterval activeWindow;
/// 当前频道是否为群聊（含子区）。非群不折叠。
@property(nonatomic, assign) BOOL isChannelGroup;
/// 当前频道是否标记为有 robot。无 robot 则不折叠（与 web `channelInfo.orgData.robot===1` 对齐）。
@property(nonatomic, assign) BOOL isChannelRobot;
/// 一键关闭开关（NSUserDefaults key `WKBotFoldDisabled`），命中后 pass-through。
@property(nonatomic, assign) BOOL disabled;
/// 判定 isActive 时的参考时刻（秒级 unix timestamp）；UI 调用方传入"现在"。
/// 0 表示用 [NSDate date].timeIntervalSince1970（仅限调用方未传时）。
@property(nonatomic, assign) NSTimeInterval referenceTimestamp;
/// 判断一条消息是否由 bot 发送。**必须由调用方提供**——engine 不知道频道成员表。
/// 默认实现：检查 `message.memberOfFrom.robot`（群成员 bot 标记），fallback 到
/// `message.from`（WKChannelInfo）上的 robot 字段（如有）。设为 nil 即用默认。
@property(nonatomic, copy, nullable) BOOL (^botMessageJudge)(WKMessageModel *message);
/// 用户已展开的折叠会话——其内任一消息的 clientMsgNo 在此集合中，整组就视为
/// 已展开：engine 输出会插入一个 expanded=YES 的折叠卡 + 该组所有子消息作为
/// 独立 RenderItem 紧随其后。用 per-message-id 而非"first id"是为了**跨
/// pulldown/pullup 稳定**：上拉加载更早的同组消息后，组的"首条"会变，但只要
/// 集合中有任一旧消息 id 仍在该组里，展开态就保持。
@property(nonatomic, copy, nullable) NSSet<NSString *> *expandedMessageIDs;
+ (instancetype)defaultConfig;
@end

#pragma mark - 引擎

@interface WKBotFoldEngine : NSObject

/// 对一个 date-section 内的消息序列计算 render items。
///
/// @param messages              本 section 的消息，按时间升序（与 dataProvider
///                              `messagesAtSection:` 顺序一致）。
/// @param config                当前生效的配置。
/// @param alreadyShownAsRegular 已被"停留状态机"标记为不折叠的 clientMsgNo 集合；
///                              engine 见到这些消息时强制独立渲染。可为 nil。
/// @return                      渲染项数组，与 UITableView 的 row 一一对应。
- (NSArray<WKBotFoldRenderItem *> *)buildRenderItemsForMessages:(NSArray<WKMessageModel *> *)messages
                                                          config:(WKBotFoldEngineConfig *)config
                                          alreadyShownAsRegular:(nullable NSSet<NSString *> *)alreadyShownAsRegular;

#pragma mark - 暴露给单测和 UI 的判定函数（纯函数）

/// 是否为可折叠的 bot 消息（非 self、非边界、非系统消息、非 typing）。
/// 不检查"连续/间隔"，那是 build 的事。
+ (BOOL)isFoldableBotMessage:(WKMessageModel *)message;

/// 是否为五类边界（image=2 / gif=3 / smallVideo=5 / file=8 / richText=14）。
/// 注意：voice=4 不在内，可折叠。
+ (BOOL)isFoldBoundaryAttachment:(WKMessageModel *)message;

@end

NS_ASSUME_NONNULL_END
