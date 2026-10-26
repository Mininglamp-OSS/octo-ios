//
//  WKDocumentPreviewLoader.h
//  WuKongBase
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

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
