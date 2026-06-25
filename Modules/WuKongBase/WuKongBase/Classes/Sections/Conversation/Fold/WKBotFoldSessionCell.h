//
//  WKBotFoldSessionCell.h
//  WuKongBase
//
//  bot 消息折叠卡 cell。配合 WKBotFoldEngine + WKMessageListView 渲染折叠态。
//  对齐 web `packages/dmworkbase/src/Components/Conversation/FoldSessionCard/`
//  视觉概念：avatar stack + AI tag + 计数 + 展开/收起；active 显示进行中动效点；
//  history 显示 summary 行（最新一条 bot 消息预览）。
//
//  与 WKTextMessageCell 等其它消息 cell 一样作为 UITableViewCell，注册到
//  WKConversationTableView 上。
//

#import <UIKit/UIKit.h>
#import "WKBotFoldEngine.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kWKBotFoldSessionCellReuseId;

@interface WKBotFoldSessionCell : UITableViewCell

/// 用 fold session 数据配置 cell。
/// @param session  折叠分组
/// @param expanded 当前是否处于"已展开"视觉态（true 时 chevron 朝上、卡片底色稍变）
- (void)configureWithSession:(WKBotFoldSession *)session expanded:(BOOL)expanded;

/// 用户点击标题行（标题行是唯一的展开/收起触发区域）时回调。
/// fold 容器把该 block 设上，由 ListView 在回调里执行 toggleExpand。
@property(nonatomic, copy, nullable) void (^onToggleExpand)(WKBotFoldSession *session);

/// 估算 cell 总高度（含上下 verticalInset + shadow），用于 heightForRowAtIndexPath。
/// 给 width 传 tableView 当前可用宽度（contentSize.width）。expanded=YES 时
/// 返回紧凑"收起 X 条"条的高度（明显比折叠卡矮）。
+ (CGFloat)heightForSession:(WKBotFoldSession *)session
              tableViewWidth:(CGFloat)tableWidth
                    expanded:(BOOL)expanded;

@end

NS_ASSUME_NONNULL_END
