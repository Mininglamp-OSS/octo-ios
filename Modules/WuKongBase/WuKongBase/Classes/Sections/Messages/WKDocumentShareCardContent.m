//
//  WKDocumentShareCardContent.m
//  WuKongBase
//

#import "WKDocumentShareCardContent.h"
#import "WuKongBase.h"

static NSString *WKDocumentCardString(id value) {
    return [value isKindOfClass:NSString.class] ? value : @"";
}

@implementation WKDocumentShareCardContent

- (instancetype)init {
    self = [super init];
    if (self) {
        _docId = @"";
        _kind = @"doc";
        _title = @"";
        _ownerName = @"";
        _updatedAt = @"";
        _documentURL = @"";
        _permission = @"reader";
    }
    return self;
}

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    if (![contentDic isKindOfClass:NSDictionary.class]) return;
    self.docId = WKDocumentCardString(contentDic[@"doc_id"]);
    self.spaceId = WKDocumentCardString(contentDic[@"space_id"]);
    NSString *kind = WKDocumentCardString(contentDic[@"kind"]);
    NSSet *allowedKinds = [NSSet setWithArray:@[@"doc", @"board", @"sheet", @"html"]];
    self.kind = [allowedKinds containsObject:kind] ? kind : @"doc";
    self.title = WKDocumentCardString(contentDic[@"title"]);
    self.ownerName = WKDocumentCardString(contentDic[@"owner_name"]);
    self.updatedAt = WKDocumentCardString(contentDic[@"updated_at"]);
    self.documentURL = WKDocumentCardString(contentDic[@"url"]);
    NSString *permission = WKDocumentCardString(contentDic[@"permission"]);
    NSSet *allowedPermissions = [NSSet setWithArray:@[@"reader", @"commenter", @"writer"]];
    self.permission = [allowedPermissions containsObject:permission] ? permission : @"reader";
}

- (NSDictionary *)encodeWithJSON {
    return @{
        @"doc_id": self.docId ?: @"",
        @"space_id": self.spaceId ?: @"",
        @"kind": self.kind ?: @"doc",
        @"title": self.title ?: @"",
        @"owner_name": self.ownerName ?: @"",
        @"updated_at": self.updatedAt ?: @"",
        @"url": self.documentURL ?: @"",
        @"permission": self.permission ?: @"reader",
    };
}

+ (NSNumber *)contentType {
    return @(WK_DOCUMENT_SHARE_CARD);
}

- (NSString *)conversationDigest {
    return self.title.length > 0
        ? [NSString stringWithFormat:LLang(@"[文档] %@"), self.title]
        : LLang(@"[文档]");
}

- (NSString *)searchableWord {
    return self.title.length > 0 ? self.title : LLang(@"[文档]");
}

@end
