//
//  WKTabbar.h
//  WuKongBase
//
//  Created by tt on 2025/2/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKTabbarItem : NSObject

-(id) initWithTitle:(NSString*)title onClick:(void(^)(void))onClick;

@property(nonatomic,copy) NSString *title; // item标题
@property(nonatomic,assign) BOOL selected; // 是否被选中
@property(nonatomic,copy) void(^onClick)(void); // 点击

@end

@interface WKTabbarStyle : NSObject

/// 每个 item 自身左右内边距。默认 20pt（对齐 WKTabbar 旧行为）。
@property (nonatomic, assign) CGFloat itemHorizontalPadding;
/// item 之间额外追加的间距（在各自内边距之外）。默认 0（对齐 WKTabbar 旧行为：首尾相接）。
@property (nonatomic, assign) CGFloat interItemSpacing;
/// 未选中文字颜色覆盖。为 nil 时使用组件默认颜色。
@property (nonatomic, strong, nullable) UIColor *unselectedTextColor;
/// indicator 高度。默认 2pt（对齐 WKTabbar 旧行为）。
@property (nonatomic, assign) CGFloat indicatorHeight;
/// indicator 宽度在文字宽度之外额外加宽的量。默认 10pt（对齐 WKTabbar 旧行为）。设为 0 则宽度等于文字宽度。
@property (nonatomic, assign) CGFloat indicatorExtraWidth;
/// 选中态切换动画时长。默认 0.2s（对齐 WKTabbar 旧行为）。
@property (nonatomic, assign) NSTimeInterval selectionAnimationDuration;

/// 与 WKTabbar 旧硬编码数值完全一致的默认样式。
+ (instancetype)defaultStyle;

@end

@interface WKTabbar : UIView

-(id) initWithItems:(NSArray<WKTabbarItem*>*)items width:(CGFloat)width;

/// 自定义样式的初始化方法。style 传 nil 等价于 initWithItems:width:（沿用旧默认值，不影响现有调用方）。
- (id)initWithItems:(NSArray<WKTabbarItem *> *)items width:(CGFloat)width style:(nullable WKTabbarStyle *)style;

/// 程序式选中第 index 项。行为等价于用户点击该项：刷新选中高亮 + 触发 item.onClick。
/// index 越界 / 重复选中当前项时为 no-op。
- (void)selectItemAtIndex:(NSInteger)index;

@end



NS_ASSUME_NONNULL_END
