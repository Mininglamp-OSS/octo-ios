//
//  OctoRelatedChatSheet.h
//  OctoContext
//
//  详情页点击 [N] citation 徽章弹出的"关联聊天记录"底部 sheet。
//
//  数据流: 直接消费 OctoCitationItem.contextBefore + 命中条 + contextAfter,
//  无需新接口。点击命中条的 "原消息→" 调 WKConversationRouter 跳到聊天页。
//
//  Sheet 视图 scope 到 *被点击的 citation indices* 范围内的所有命中条 + 上下文,
//  不再展示总结里其它 citations。当合并徽章 (如 [1-3]) 跨多个 channel 时, 顶部
//  出 channel 切换器, 让用户在该组内的不同聊天间跳。当只命中单一 channel 时
//  切换器隐藏 —— 修"切换到其他群聊跟当前 citation 无关"的困惑。
//

#import <UIKit/UIKit.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OctoRelatedChatSheet : UIViewController

/// 新入口: 展开一组(可能含多个) citation 的关联聊天。indices 是 OctoCitationItem.index 列表。
+ (void)presentInVC:(UIViewController *)host
          citations:(NSArray<OctoCitationItem *> *)citations
      activeIndices:(NSArray<NSNumber *> *)activeIndices;

/// 兼容入口: 单 citation 调用, 内部包成单元素数组转发到 activeIndices: 路径。
+ (void)presentInVC:(UIViewController *)host
          citations:(NSArray<OctoCitationItem *> *)citations
        activeIndex:(NSInteger)activeCitationIndex;

@end

NS_ASSUME_NONNULL_END
