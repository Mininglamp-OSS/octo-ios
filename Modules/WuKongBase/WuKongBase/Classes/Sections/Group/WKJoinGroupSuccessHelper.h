// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKJoinGroupSuccessHelper.h
//  WuKongBase
//
//  (iOS) — 对齐 Web PR#1068 / /:
//  用户通过邀请链接/扫码/直接接受邀请进入一个属于「其它 Space」的群时：
//    1) 服务端加群 API 返回成功后，**不能**直接把 viewer 切到目标 Space；
//    2) 先把「本次加群成功 + 目标 Space」记录下来（in-memory + UserDefaults 兜底）；
//    3) 由主会话列表页 (WKConversationListVC) 在 viewDidAppear 时消费这条
//       通知，弹出一个带「切换过去」按钮的 Toast/Dialog；
//    4) 用户显式点击按钮才执行 Space 切换 + 跳转到目标群；
//    5) 未点击 / dismiss / 超时 → 保持 viewer 在原 Space（Web 契约）。
//
//  「同 Space 加群」场景走常规 HUD，本 helper 不会保存 cross-space 通知，
//  调用方依旧用 showHUD/showMsg 即可（保持行为向后兼容）。
//
//  契约（与 Web computeAndSaveJoinSuccess / consumeJoinSuccessNotice 对齐）：
//    - `computeAndSaveWithGroupNo:` 只在 target 与 viewer 不同时写入；
//    - 相同 Space 不写入，返回 NO；
//    - `consumeNotice` 取一次即清，避免重复弹窗（Web 用 sessionStorage）；
//    - 缺 target Space / group_no → 直接返回 NO，UI 层 fallback 到普通 toast。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 加群成功后待消费的跨 Space 通知。
@interface WKJoinGroupSuccessNotice : NSObject
@property(nonatomic,copy) NSString *groupNo;          ///< 目标群 ID（必填）
@property(nonatomic,copy) NSString *groupName;        ///< 目标群名（可空，UI 兜底）
@property(nonatomic,copy) NSString *targetSpaceId;    ///< 群所属 Space ID
@property(nonatomic,copy,nullable) NSString *spaceName; ///< 目标 Space 展示名
@property(nonatomic,copy,nullable) NSString *viewerSpaceId; ///< 记录时 viewer 所在 Space
@property(nonatomic,assign) NSTimeInterval savedAt;   ///< 保存时间戳（秒）
@end

@interface WKJoinGroupSuccessHelper : NSObject

/// 计算并保存加群成功通知。
/// - 如果 `targetSpaceId == viewerSpaceId` 或两者都为空：**不保存**，返回 NO。
/// - 如果 target / viewer 的 Space 不同（跨 Space 场景）：保存通知，返回 YES。
/// - `groupNo` / `targetSpaceId` 缺失 → 返回 NO。
/// 调用方应当在「加群成功 API 返回成功」的回调里调用。
+(BOOL) computeAndSaveWithGroupNo:(nullable NSString *)groupNo
                    targetSpaceId:(nullable NSString *)targetSpaceId
                        groupName:(nullable NSString *)groupName
                        spaceName:(nullable NSString *)spaceName;

/// 读取并**立即清空**待消费通知。Web 端用 sessionStorage 一次性取完即清，
/// iOS 同样只取一次以避免主会话列表重复弹窗。
+(nullable WKJoinGroupSuccessNotice *) consumeNotice;

/// 仅 peek 不清除 — 给测试用，不建议 UI 调用。
+(nullable WKJoinGroupSuccessNotice *) peekNotice;

/// 清空当前通知（若有）。用于异常路径 / 退出登录时兜底。
+(void) clear;

/// 辅助：获取 viewer 当前 space_id。抽出来方便测试里 stub。
+(nullable NSString *) currentViewerSpaceId;

@end

NS_ASSUME_NONNULL_END
