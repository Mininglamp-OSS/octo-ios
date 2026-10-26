//
//  WKDocumentPreviewLoader.h
//  WuKongBase
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Builds a document-card URL while preserving any deployment prefix in apiBaseURL.
/// Known API suffixes (/v1 or /api/v1) are removed before appending the route.
FOUNDATION_EXPORT NSURL * _Nullable WKDocumentShareCardAbsoluteURL(NSString *relativePath, NSString *apiBaseURL);

/// Loads and parses the ACL-protected first-page preview for a document card.
@interface WKDocumentPreviewLoader : NSObject

+ (instancetype)shared;

/// Results use status ready/denied/unavailable/empty/error and optionally a preview dictionary.
- (void)fetchPreviewForKind:(NSString *)kind
                      docId:(NSString *)docId
                    spaceId:(NSString *)spaceId
                      force:(BOOL)force
                   callback:(void (^)(NSDictionary *result))callback;

- (void)resetCache;

@end

NS_ASSUME_NONNULL_END
