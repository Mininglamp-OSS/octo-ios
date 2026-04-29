//
//  WKReply+ExternalGroup.h
//  WuKongBase
//
//  YUJ-131 (iOS P0) — reply-level external-group fields for @SpaceName suffix
//  in quoted-message previews. Mirrors dmwork-web PR #1073 (Reply.prototype
//  .decode monkey-patch) and dmwork-android's ReplyExternalFieldsHelper.
//
//  WKReply lives in WuKongIMSDK, which we keep untouched; this category
//  stores the four fields via associated objects so the SDK surface stays
//  stable across the phase-1 rollout window.
//
//  Contract: field names and raw-dict keys are identical to the msg-level
//  fields WKMessageUtil writes onto WKMessage.extra — `from_home_space_id`,
//  `from_home_space_name`, `from_is_external`, `from_source_space_name`.
//  Changing them is a cross-layer break (see YUJ-53 silent-fail).
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Reply-level fields that the backend sends inside the reply sub-dict of a
 message payload. The getters return empty/NO when the fields are missing
 so callers can safely chain into WKExternalViewerResolver without extra
 null checks.
 */
@interface WKReply (ExternalGroup)

/// 被回复消息发送者归属空间 ID（YUJ-63 viewer-relative path）
@property (nonatomic, copy, nullable) NSString *fromHomeSpaceId;

/// 被回复消息发送者归属空间名称（YUJ-63 viewer-relative path）
@property (nonatomic, copy, nullable) NSString *fromHomeSpaceName;

/// Legacy `is_external` flag（被回复消息发送者，YUJ-28 路径）
@property (nonatomic, assign) BOOL fromIsExternal;

/// Legacy `source_space_name`（被回复消息发送者，YUJ-28 路径）
@property (nonatomic, copy, nullable) NSString *fromSourceSpaceName;

@end

NS_ASSUME_NONNULL_END
