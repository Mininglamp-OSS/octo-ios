//
//  WKExternalViewerResolver.h
//  WuKongBase
//
//  Viewer-relative external-member resolver, aligned with
//  dmwork-web `resolveExternalForViewer` (PR #997) and
//  dmwork-android `ExternalViewerResolver` (YUJ-87 PR #122).
//
//  Decision rule (priority):
//    if homeSpaceId is non-empty:
//        isExternal = homeSpaceId != viewerSpaceId
//        sourceSpaceName = isExternal ? homeSpaceName : ""
//    else:                              // legacy fallback
//        isExternal = isExternalLegacy == 1
//        sourceSpaceName = sourceSpaceNameLegacy
//
//  Created for YUJ-93 (iOS EP2).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// --- extras key contract (locked by unit test WKExternalViewerResolverTests) ---
// Changing these strings is a cross-layer contract break (see YUJ-53 silent-fail).
extern NSString *const WKExternalExtrasKeyHomeSpaceId;
extern NSString *const WKExternalExtrasKeyHomeSpaceName;
extern NSString *const WKExternalExtrasKeyIsExternal;
extern NSString *const WKExternalExtrasKeySourceSpaceId;
extern NSString *const WKExternalExtrasKeySourceSpaceName;

/**
 Viewer-relative external-member resolution result.
 isExternal — true when the member is external relative to viewerSpaceId.
 sourceSpaceName — the space name to show after "@" suffix; empty when
 non-external or when nothing is available.
 */
@interface WKExternalResolveResult : NSObject
@property(nonatomic,readonly,assign) BOOL isExternal;
@property(nonatomic,readonly,copy)   NSString *sourceSpaceName;
- (instancetype)initWithIsExternal:(BOOL)isExternal
                    sourceSpaceName:(nullable NSString*)sourceSpaceName;
@end

@interface WKExternalViewerResolver : NSObject

/**
 Full-control pure resolver. Does not read any global state. Safe for
 unit tests. Accepts id so callers can pass raw dictionary values
 (NSString / NSNumber / NSNull) without pre-coercing.
 */
+ (WKExternalResolveResult *)resolveWithHomeSpaceId:(nullable id)homeSpaceId
                                      homeSpaceName:(nullable id)homeSpaceName
                                   isExternalLegacy:(nullable id)isExternalLegacy
                              sourceSpaceNameLegacy:(nullable id)sourceSpaceNameLegacy
                                      viewerSpaceId:(nullable NSString*)viewerSpaceId;

/**
 Convenience: resolve from a WKChannelMember-style extras dictionary.
 Reads keys defined by WKExternalExtrasKey*. Pass nil extras to get a
 non-external result.
 */
+ (WKExternalResolveResult *)resolveFromExtras:(nullable NSDictionary *)extras
                                 viewerSpaceId:(nullable NSString*)viewerSpaceId;

/**
 Returns the currently active space id, read fresh every call from
 NSUserDefaults "currentSpaceId". Returning a fresh value each time is
 required so UI re-renders pick up Space switches without manual cache
 invalidation (YUJ-93 acceptance: Space switch re-render).
 */
+ (nullable NSString *)currentViewerSpaceId;

@end

NS_ASSUME_NONNULL_END
