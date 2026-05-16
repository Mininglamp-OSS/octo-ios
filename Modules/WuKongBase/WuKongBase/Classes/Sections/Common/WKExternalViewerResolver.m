// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKExternalViewerResolver.m
//  WuKongBase
//

#import "WKExternalViewerResolver.h"

NSString *const WKExternalExtrasKeyHomeSpaceId      = @"home_space_id";
NSString *const WKExternalExtrasKeyHomeSpaceName    = @"home_space_name";
NSString *const WKExternalExtrasKeyIsExternal       = @"is_external";
NSString *const WKExternalExtrasKeySourceSpaceId    = @"source_space_id";
NSString *const WKExternalExtrasKeySourceSpaceName  = @"source_space_name";

@implementation WKExternalResolveResult

- (instancetype)initWithIsExternal:(BOOL)isExternal
                    sourceSpaceName:(NSString *)sourceSpaceName {
    self = [super init];
    if (self) {
        _isExternal = isExternal;
        _sourceSpaceName = [sourceSpaceName copy] ?: @"";
    }
    return self;
}

@end

@implementation WKExternalViewerResolver

// Coerce any raw dict value into a clean NSString. Returns nil for
// NSNull / non-string / empty string. Important: empty string must be
// treated as "field missing" so the legacy fallback can kick in (web
// `resolveExternalForViewer` behaves the same way).
+ (nullable NSString *)coerceString:(nullable id)raw {
    if (!raw || raw == [NSNull null]) {
        return nil;
    }
    if ([raw isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)raw;
        return s.length > 0 ? s : nil;
    }
    if ([raw isKindOfClass:[NSNumber class]]) {
        NSString *s = [(NSNumber *)raw stringValue];
        return s.length > 0 ? s : nil;
    }
    return nil;
}

// Coerce to 0/1 int treating NSNumber bool/int and NSString "0"/"1"/"true".
+ (NSInteger)coerceIntFlag:(nullable id)raw {
    if (!raw || raw == [NSNull null]) {
        return 0;
    }
    if ([raw isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)raw integerValue] == 1 ? 1 : 0;
    }
    if ([raw isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)raw lowercaseString];
        if ([s isEqualToString:@"1"] || [s isEqualToString:@"true"] || [s isEqualToString:@"yes"]) {
            return 1;
        }
        return 0;
    }
    return 0;
}

+ (WKExternalResolveResult *)resolveWithHomeSpaceId:(id)homeSpaceIdRaw
                                      homeSpaceName:(id)homeSpaceNameRaw
                                   isExternalLegacy:(id)isExternalLegacyRaw
                              sourceSpaceNameLegacy:(id)sourceSpaceNameLegacyRaw
                                      viewerSpaceId:(NSString *)viewerSpaceIdRaw {
    NSString *homeSpaceId = [self coerceString:homeSpaceIdRaw];
    NSString *viewerSpaceId = [self coerceString:viewerSpaceIdRaw];

    if (homeSpaceId != nil) {
        // Preferred viewer-relative path (web PR #997 / #1037).
        BOOL isExternal = (viewerSpaceId == nil) ? YES : ![homeSpaceId isEqualToString:viewerSpaceId];
        NSString *sourceSpaceName = @"";
        if (isExternal) {
            NSString *homeName = [self coerceString:homeSpaceNameRaw];
            // Fallback to legacy source_space_name if home_space_name is
            // empty — keeps @SpaceName suffix usable during the rollout
            // window when only half of the fields are populated.
            if (homeName == nil) {
                homeName = [self coerceString:sourceSpaceNameLegacyRaw];
            }
            sourceSpaceName = homeName ?: @"";
        }
        return [[WKExternalResolveResult alloc] initWithIsExternal:isExternal
                                                   sourceSpaceName:sourceSpaceName];
    }

    // Legacy fallback — preserves behavior for clients on older
    // backends that don't yet return home_space_id.
    BOOL isExternal = [self coerceIntFlag:isExternalLegacyRaw] == 1;
    NSString *sourceSpaceName = @"";
    if (isExternal) {
        NSString *legacy = [self coerceString:sourceSpaceNameLegacyRaw];
        sourceSpaceName = legacy ?: @"";
    }
    return [[WKExternalResolveResult alloc] initWithIsExternal:isExternal
                                               sourceSpaceName:sourceSpaceName];
}

+ (WKExternalResolveResult *)resolveFromExtras:(NSDictionary *)extras
                                 viewerSpaceId:(NSString *)viewerSpaceId {
    if (!extras) {
        return [[WKExternalResolveResult alloc] initWithIsExternal:NO sourceSpaceName:@""];
    }
    return [self resolveWithHomeSpaceId:extras[WKExternalExtrasKeyHomeSpaceId]
                          homeSpaceName:extras[WKExternalExtrasKeyHomeSpaceName]
                       isExternalLegacy:extras[WKExternalExtrasKeyIsExternal]
                  sourceSpaceNameLegacy:extras[WKExternalExtrasKeySourceSpaceName]
                          viewerSpaceId:viewerSpaceId];
}

+ (NSString *)currentViewerSpaceId {
    // Read fresh each call — Space switches update NSUserDefaults
    // synchronously and callers rely on this for re-render ().
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (spaceId && spaceId.length > 0) {
        return spaceId;
    }
    return nil;
}

@end
