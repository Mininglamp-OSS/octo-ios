//
//  OctoDetailSourcesView.h
//  OctoContext
//
//  详情页顶部 "来源 chip 列表" 视图。
//   - 每个 source 一个胶囊 chip(文本; 群聊/私聊/子区只用名字, 颜色按类型微变)
//   - 自动换行 (流式布局), 默认仅显示第 0 行
//   - 一行装不下时, 第 0 行右侧出 ↓ 折叠按钮, 点击展开 / 折起 (动画)
//   - 单行就能放下时折叠按钮不出现
//

#import <UIKit/UIKit.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OctoDetailSourcesView : UIView

@property(nonatomic, copy, nullable) NSArray<OctoSourceItem *> *items;

/// 当前是否展开。默认 NO (只显第 0 行)。可程序化设置。
@property(nonatomic, assign) BOOL expanded;

/// 折叠 / 展开后宽高变化通知, 父容器据此重排其他元素。
@property(nonatomic, copy, nullable) void (^onToggle)(BOOL expanded);

/// 给定可用宽度, 返回当前应当占用的高度 (按 expanded 状态算)。
- (CGFloat)heightForWidth:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
