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

@end

NS_ASSUME_NONNULL_END
