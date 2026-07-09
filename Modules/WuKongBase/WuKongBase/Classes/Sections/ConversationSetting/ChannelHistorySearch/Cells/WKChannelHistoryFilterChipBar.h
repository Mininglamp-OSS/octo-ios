//
//  WKChannelHistoryFilterChipBar.h
//  WuKongBase
//
//  搜索页顶部"筛选 chip 行"：横向滚动 chip 列表，单个 chip 含图标+文字+✕。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 单个 chip 描述。
@interface WKChannelHistoryFilterChipDescriptor : NSObject
@property (nonatomic, copy) NSString *key;          // 'sender' / 'date' / 'sort'
@property (nonatomic, copy) NSString *title;        // 显示文本
@property (nonatomic, copy, nullable) void(^onClear)(void);
@property (nonatomic, copy, nullable) void(^onTap)(void);
@end

@interface WKChannelHistoryFilterChipBar : UIView

@property (nonatomic, copy) NSArray<WKChannelHistoryFilterChipDescriptor *> *chips;

@end

NS_ASSUME_NONNULL_END
