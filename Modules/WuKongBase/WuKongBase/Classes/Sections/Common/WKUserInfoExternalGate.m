//
//  WKUserInfoExternalGate.m
//  WuKongBase
//

#import "WKUserInfoExternalGate.h"
#import "WKExternalViewerResolver.h"

@implementation WKUserInfoExternalGate

+ (BOOL)shouldHideDMWithMemberExtras:(NSDictionary *)memberExtras
                  channelInfoExtras:(NSDictionary *)channelInfoExtras
                      viewerSpaceId:(NSString *)viewerSpaceId
                             isSelf:(BOOL)isSelf {
    if (isSelf) {
        return NO;
    }

    // Priority 1: group-member subscriber extras (authoritative when we
    // got here from a group → avatar → user info flow).
    if (memberExtras != nil && memberExtras.count > 0) {
        WKExternalResolveResult *r = [WKExternalViewerResolver
                                      resolveFromExtras:memberExtras
                                          viewerSpaceId:viewerSpaceId];
        if (r.isExternal) {
            return YES;
        }
        // Conservative: if group-member extras carried home_space_id and
        // the resolver decided "same space", do NOT fall back to the
        // legacy channelInfo path. Web PR #1021 preserves this invariant
        // so a stale legacy is_external=1 on channelInfo cannot override
        // a fresh home_space_id=viewer decision.
        if ([self hasAuthoritativeHomeSpaceId:memberExtras]) {
            return NO;
        }
    }

    // Priority 2: personal-channel extras (legacy fallback — the
    // /users/{uid}?group_no=... endpoint historically wrote is_external
    // / source_space_name onto channelInfo.extra).
    if (channelInfoExtras != nil && channelInfoExtras.count > 0) {
        WKExternalResolveResult *r = [WKExternalViewerResolver
                                      resolveFromExtras:channelInfoExtras
                                          viewerSpaceId:viewerSpaceId];
        if (r.isExternal) {
            return YES;
        }
    }

    return NO;
}

+ (BOOL)shouldUseSpaceModeSendMessageWithIsExternal:(BOOL)isExternalUser
                                      viewerSpaceId:(NSString *)viewerSpaceId
                                              isBot:(BOOL)isBot
                                             follow:(NSInteger)follow {
    if (isExternalUser) {
        return NO;
    }
    if (follow != 0) {
        return NO;
    }
    if (isBot) {
        return NO;
    }
    return viewerSpaceId != nil && viewerSpaceId.length > 0;
}

+ (BOOL)hasAuthoritativeHomeSpaceId:(NSDictionary *)extras {
    id raw = extras[WKExternalExtrasKeyHomeSpaceId];
    if ([raw isKindOfClass:[NSString class]]) {
        return ((NSString *)raw).length > 0;
    }
    if ([raw isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)raw stringValue].length > 0;
    }
    return NO;
}

@end
