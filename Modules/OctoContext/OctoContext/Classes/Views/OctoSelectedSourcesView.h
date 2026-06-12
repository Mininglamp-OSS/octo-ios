//
//  OctoSelectedSourcesView.h
//  OctoContext
//
//  创建总结页"选择聊天"卡片下的 已选 chip 流式列表:
//   - 每项: 圆形头像 + 名字 + ✕ 删除
//   - 自动换行,行数超过 maxRows 自动开启垂直滚动
//   - 删除回调外抛
//

#import <UIKit/UIKit.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OctoSelectedSourcesView : UIView

/// 用 channel 反查头像/名字时所需 SDK 在 OctoSummaryCreateVC 里直接做,
/// 这里只接收最终展示数据。
@property(nonatomic, copy) NSArray<OctoSourceItem *> *items;

/// ≤ maxRows 时按内容撑高,超出时固定 maxRows 行高度并启用纵向滚动。默认 3。
@property(nonatomic, assign) NSInteger maxRows;

/// item.sourceId 唯一标识,被点 ✕ 删除时回调。
@property(nonatomic, copy, nullable) void (^onRemove)(OctoSourceItem *item);

/// 给定可用宽度,返回需要的高度(便于父容器算自身高度)。
- (CGFloat)heightForWidth:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
