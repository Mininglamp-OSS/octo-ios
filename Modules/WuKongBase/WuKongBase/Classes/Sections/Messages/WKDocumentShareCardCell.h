//
//  WKDocumentShareCardCell.h
//  WuKongBase
//

#import "WKMessageCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKDocumentShareCardCell : WKMessageCell
/// Rechecks access for a visible card after returning from another screen.
- (void)forceRefreshPreview;
@end

NS_ASSUME_NONNULL_END
