//
//  WKDocumentPreviewLoader.h
//  WuKongBase
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Accepts only a single ASCII document ID path segment (1–128 characters).
FOUNDATION_EXPORT BOOL WKDocumentShareCardIsValidDocId(NSString * _Nullable docId);
FOUNDATION_EXPORT NSNotificationName const WKDocumentPreviewSessionDidChangeNotification;

/// Builds a document-card URL while preserving any deployment prefix in apiBaseURL.
/// Known API suffixes (/v1 or /api/v1) are removed before appending the route.
FOUNDATION_EXPORT NSURL * _Nullable WKDocumentShareCardAbsoluteURL(NSString *relativePath, NSString *apiBaseURL);

/// Cancels one card's interest in a shared request without cancelling other cards.
@interface WKDocumentPreviewSubscription : NSObject
- (void)cancel;
@end

/// Loads and parses the ACL-protected first-page preview for a document card.
@interface WKDocumentPreviewLoader : NSObject

+ (instancetype)shared;

/// Results use status ready/denied/unavailable/empty/unauthenticated/error and optionally a preview dictionary.
/// An empty spaceId is allowed; the request then omits X-Space-Id.
- (nullable WKDocumentPreviewSubscription *)fetchPreviewForKind:(NSString *)kind
                      docId:(NSString *)docId
                    spaceId:(NSString *)spaceId
                      force:(BOOL)force
                   callback:(void (^)(NSDictionary *result))callback;

/// Clears preview state and cancels/invalidates the current session transport.
- (void)resetCache;

@end

NS_ASSUME_NONNULL_END
