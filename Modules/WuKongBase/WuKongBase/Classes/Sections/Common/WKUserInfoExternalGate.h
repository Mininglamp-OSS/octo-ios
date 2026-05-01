//
//  WKUserInfoExternalGate.h
//  WuKongBase
//
//  Pure gate for the UserInfo screen that decides whether to collapse
//  the "send message" / "add friend" footer into a static external-hint
//  label. Aligned with dmwork-web PR #1021 (YUJ-67) and Android
//  UserDetailActivity viewer-relative external logic.
//
//  Decision rule (priority — matches web vm.tsx isExternalToViewer):
//    1. Self → never hide.
//    2. Resolve from memberOfUser.extra (group subscriber context) —
//       if WKExternalViewerResolver returns isExternal=YES → hide.
//    3. Resolve from channelInfo.extra (legacy user-profile fallback,
//       when the /users/{uid}?group_no=... path populated the old
//       is_external / source_space_name keys) → if external → hide.
//    4. Otherwise → do not hide.
//
//  This gate is intentionally decoupled from WKExternalViewerResolver
//  (which stays a pure field-level function, hard constraint of
//  YUJ-93 test contract) so it can be unit-tested without touching any
//  UIKit / WKSDK state.
//
//  Created for YUJ-137 (iOS P1, parallel to Android YUJ-67).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKUserInfoExternalGate : NSObject

/**
 Return YES when the UserInfo footer should hide the DM / add-friend
 buttons and show an "only-in-group" hint instead.

 @param memberExtras WKChannelMember.extra of the target user inside
        the current group context, or nil when not in a group.
 @param channelInfoExtras WKChannelInfo.extra of the target user's
        personal channel, or nil. Legacy is_external /
        source_space_name keys are honoured here as a fallback.
 @param viewerSpaceId The current viewer Space id (nil when not in
        any Space).
 @param isSelf YES when the target user is the login user — never
        hide in that case.
 */
+ (BOOL)shouldHideDMWithMemberExtras:(nullable NSDictionary *)memberExtras
                  channelInfoExtras:(nullable NSDictionary *)channelInfoExtras
                      viewerSpaceId:(nullable NSString *)viewerSpaceId
                             isSelf:(BOOL)isSelf;

/**
 YUJ-206 — Space-mode send-message shortcut, aligned with web
 UserInfo/index.tsx:52-55 / 企微语义 and Android
 UserDetailExternalHelper.shouldUseSpaceModeSendMessage.

 嘉伟 2026-05-01 Android 真机实测复现：外部群里点成员显示「申请加好友」。
 根因之一是 iOS WKUserInfoVC 对 Space-mode 同 Space 非好友的分支误显
 addFriendBtn，此 gate 方法把「是否用 sendBtn 替代 addFriendBtn」的决策
 抽成纯函数，方便 XCTest 覆盖并与 Android 保持锁定的优先级：

   external hint > self > Space-mode 非bot → sendMsg > Space-mode bot >
   非Space-mode follow

 语义（全部 YES/NO 短路）：
   - isExternalUser=YES → NO（交给 shouldHideDM 路径，footer 变成 hint）
   - follow != 0         → NO（已是好友，原 sendBtn 分支已处理）
   - isBot=YES           → NO（Space 模式下 bot 仍走 addFriendBtn ->
                              bot_add_friend 审批流）
   - viewerSpaceId 空    → NO（非 Space 模式走 follow + vercode 老路径）
   - 其它                → YES（Space-mode + 非bot + 非好友 → sendBtn）

 @param isExternalUser  上游已判定的跨 Space 外部性。
 @param viewerSpaceId   当前 viewer Space id（空 / nil 视为非 Space 模式）。
 @param isBot           target 用户是否为 bot（WKChannelInfo.robot）。
 @param follow          WKChannelInfo.follow（0 = 陌生，1 = 已加好友）。
 */
+ (BOOL)shouldUseSpaceModeSendMessageWithIsExternal:(BOOL)isExternalUser
                                      viewerSpaceId:(nullable NSString *)viewerSpaceId
                                              isBot:(BOOL)isBot
                                             follow:(NSInteger)follow;

@end

NS_ASSUME_NONNULL_END
