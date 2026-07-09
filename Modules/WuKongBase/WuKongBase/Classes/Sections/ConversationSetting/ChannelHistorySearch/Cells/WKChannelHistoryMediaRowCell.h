//
//  WKChannelHistoryMediaRowCell.h
//  WuKongBase
//
//  "全部" tab 中混排媒体命中：左侧 56×56 缩略图 + 右侧两行（发送人 / 时间 + 命中理由）。
//

#import <UIKit/UIKit.h>
#import "WKChannelHistorySearchModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelHistoryMediaRowCell : UITableViewCell

+ (NSString *)reuseIdentifier;
+ (CGFloat)cellHeight;

- (void)applyItem:(WKChannelHistorySearchItem *)item keyword:(nullable NSString *)keyword;

@end

NS_ASSUME_NONNULL_END
