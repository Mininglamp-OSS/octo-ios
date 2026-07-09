//
//  WKChannelHistoryMessageCell.h
//  WuKongBase
//
//  搜索结果 — 消息行（用于"全部" / "聊天记录" tab）。
//  样式：左侧 36×36 圆形头像 + 右侧两行（标题：名 + 时间；内容：高亮 snippet）。
//

#import <UIKit/UIKit.h>
#import "WKChannelHistorySearchModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelHistoryMessageCell : UITableViewCell

+ (NSString *)reuseIdentifier;
+ (CGFloat)heightForItem:(WKChannelHistorySearchItem *)item width:(CGFloat)width;

- (void)applyItem:(WKChannelHistorySearchItem *)item keyword:(nullable NSString *)keyword;

@end

NS_ASSUME_NONNULL_END
