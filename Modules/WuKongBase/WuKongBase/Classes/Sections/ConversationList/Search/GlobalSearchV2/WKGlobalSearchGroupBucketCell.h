//
//  WKGlobalSearchGroupBucketCell.h
//  WuKongBase
//
//  全局搜索「聊天记录」L1 总览行：一个会话/群/子区/私聊桶。
//  样式对齐会话内搜索消息行的视觉语言（头像 + 名称 + 时间 + 高亮预览），
//  额外右侧显示「约N条」命中数 + drill-in chevron。
//

#import <UIKit/UIKit.h>
#import "WKGlobalSearchModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKGlobalSearchGroupBucketCell : UITableViewCell

+ (NSString *)reuseIdentifier;
+ (CGFloat)cellHeight;

- (void)applyBucket:(WKGlobalSearchGroupBucket *)bucket keyword:(nullable NSString *)keyword;

@end

NS_ASSUME_NONNULL_END
