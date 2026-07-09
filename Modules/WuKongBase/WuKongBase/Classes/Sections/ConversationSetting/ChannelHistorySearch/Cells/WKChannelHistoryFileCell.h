//
//  WKChannelHistoryFileCell.h
//  WuKongBase
//
//  搜索结果 — 文件行。用于"全部" tab（内嵌）和"文件" tab。
//  样式：左侧文件类型小图标（圆角方形）+ 右侧两行（文件名 [高亮] / 发送人 · 大小 · 时间）。
//

#import <UIKit/UIKit.h>
#import "WKChannelHistorySearchModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelHistoryFileCell : UITableViewCell

+ (NSString *)reuseIdentifier;
+ (CGFloat)cellHeight;

- (void)applyItem:(WKChannelHistorySearchItem *)item keyword:(nullable NSString *)keyword;

@end

NS_ASSUME_NONNULL_END
