//
//  WKReply+ExternalGroup.m
//  WuKongBase
//

#import "WKReply+ExternalGroup.h"
#import <objc/runtime.h>

static const void *kWKReplyFromHomeSpaceIdKey      = &kWKReplyFromHomeSpaceIdKey;
static const void *kWKReplyFromHomeSpaceNameKey    = &kWKReplyFromHomeSpaceNameKey;
static const void *kWKReplyFromIsExternalKey       = &kWKReplyFromIsExternalKey;
static const void *kWKReplyFromSourceSpaceNameKey  = &kWKReplyFromSourceSpaceNameKey;

@implementation WKReply (ExternalGroup)

- (NSString *)fromHomeSpaceId {
    return objc_getAssociatedObject(self, kWKReplyFromHomeSpaceIdKey);
}
- (void)setFromHomeSpaceId:(NSString *)fromHomeSpaceId {
    objc_setAssociatedObject(self, kWKReplyFromHomeSpaceIdKey, [fromHomeSpaceId copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)fromHomeSpaceName {
    return objc_getAssociatedObject(self, kWKReplyFromHomeSpaceNameKey);
}
- (void)setFromHomeSpaceName:(NSString *)fromHomeSpaceName {
    objc_setAssociatedObject(self, kWKReplyFromHomeSpaceNameKey, [fromHomeSpaceName copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)fromIsExternal {
    NSNumber *n = objc_getAssociatedObject(self, kWKReplyFromIsExternalKey);
    return [n boolValue];
}
- (void)setFromIsExternal:(BOOL)fromIsExternal {
    objc_setAssociatedObject(self, kWKReplyFromIsExternalKey, @(fromIsExternal), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)fromSourceSpaceName {
    return objc_getAssociatedObject(self, kWKReplyFromSourceSpaceNameKey);
}
- (void)setFromSourceSpaceName:(NSString *)fromSourceSpaceName {
    objc_setAssociatedObject(self, kWKReplyFromSourceSpaceNameKey, [fromSourceSpaceName copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
