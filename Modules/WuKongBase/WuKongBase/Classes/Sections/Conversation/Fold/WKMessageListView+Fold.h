//
//  WKMessageListView+Fold.h
//  WuKongBase
//
//  WKMessageListView 的 bot 折叠扩展。为了把折叠引擎接入 UITableView dataSource
//  而尽可能少地改 WKMessageListView.m 原文件（原文件 3000+ 行，20+ reloadData
//  调用点），状态走 associated objects、cache 用 lazy token 失效。
//
//  接入点（外部只需调这几个）：
//   - `wk_fold_applyPageVisible:` —— 由聊天 VC 在 viewDidAppear / viewWillDisappear
//     和 applicationState 切换时调；用于"停留就不折叠"状态机。
//   - `wk_fold_noteIncomingMessages:` —— 由 handleRecvMessage 调；用于把"停留期间
//     新到的可折叠 bot 消息"标记为不折叠。
//   - `wk_fold_renderItemAtIndexPath:` / `wk_fold_renderItemsCountInSection:`
//     —— 由 dataSource 方法调，命中返回折叠后的项，未命中返回 nil/NSNotFound。
//   - `wk_fold_dequeueCellForSession:` —— dataSource cellForRow 命中折叠卡时用。
//   - `wk_fold_heightForSession:` —— heightForRow 命中折叠卡时用。
//   - `wk_fold_isEnabled` —— 综合 NSUserDefaults toggle + 频道前置后的最终启用判断。
//

#import <UIKit/UIKit.h>
#import "WKMessageListView.h"
#import "WKBotFoldEngine.h"

NS_ASSUME_NONNULL_BEGIN

/// NSUserDefaults key：YES = 关闭「停留就不折叠」状态机（命中后退化为 web 等价
/// 行为——所有可折叠 bot 消息都按规则折叠，与 web 一致），便于排障与跨端对齐。
/// 注意：本开关**不**关闭整个折叠功能；折叠规则始终生效。
extern NSString * const WKBotFoldDisabledUserDefaultsKey;

@interface WKMessageListView (Fold)

#pragma mark - 外部入口

- (void)wk_fold_applyPageVisible:(BOOL)visible;
- (void)wk_fold_noteIncomingMessages:(nullable NSArray<WKMessageModel *> *)messages;
- (void)wk_fold_invalidate;

#pragma mark - dataSource 查询

- (BOOL)wk_fold_isEnabled;

/// 返回该 section 在折叠后总行数；NSNotFound 表示"未启用，按原逻辑"。
- (NSInteger)wk_fold_renderItemsCountInSection:(NSInteger)section;

/// 返回 indexPath 对应的渲染项；nil 表示"未启用，按原逻辑"。
- (nullable WKBotFoldRenderItem *)wk_fold_renderItemAtIndexPath:(NSIndexPath *)indexPath;

/// 折叠卡 cell dequeue + 配置。
- (UITableViewCell *)wk_fold_dequeueCellForSession:(WKBotFoldSession *)session
                                          tableView:(UITableView *)tableView
                                          indexPath:(NSIndexPath *)indexPath;

/// 切换某个折叠 session 的展开/收起状态；命中即整组所有 clientMsgNo 入/出
/// expandedMessageIDs 集合并 reloadData。`didSelectRowAtIndexPath:` 整行触发。
- (void)wk_fold_toggleExpandForSession:(WKBotFoldSession *)session;

/// 折叠卡高度（active vs history 不同）。
- (CGFloat)wk_fold_heightForSession:(WKBotFoldSession *)session;

/// 返回 tableView 指定行的"锚点消息 clientMsgNo"。
/// - 行是普通 Message → 该消息 clientMsgNo
/// - 行是折叠卡（FoldSession）→ 取该组**第一条**消息 clientMsgNo（视觉锚点）
/// - 折叠未启用或越界 → nil
/// 用途：pulldown/pullup 完成 reloadData 后，按 clientMsgNo 跨折叠拓扑变化稳定地
/// 还原 contentOffset，而不是按行号（行号在折叠模式下会错位）。
- (nullable NSString *)wk_fold_anchorClientMsgNoAtTableIndexPath:(NSIndexPath *)tableIndexPath;

/// 是否该强制显示该行的头像。
/// 仅当 (1) 折叠开启 (2) 该行是 Message 项 (3) 该项位于一个已展开的 FoldSession 内
/// (4) 该行是不同 bot 在该展开组内的第一条（含整组的第一条）时为 YES。
/// 用途：在 willDisplayCell 之后覆盖 WKMessageCell 的 bubblePosition-based 头像
/// 隐藏逻辑，让用户在展开后能区分不同 bot 发送方。
- (BOOL)wk_fold_shouldForceShowAvatarAtTableIndexPath:(NSIndexPath *)tableIndexPath;

/// 返回 tableView 该行"实际覆盖"的所有 WKMessageModel——折叠卡覆盖整组消息；
/// Message 行就一条。用于已读 / browseToOrderSeq 等"可见消息"统计场景：
/// 用户看到折叠卡就等于看到了组内所有消息。折叠未启用或越界返回空数组。
- (NSArray<WKMessageModel *> *)wk_fold_coveredMessagesForTableIndexPath:(NSIndexPath *)tableIndexPath;

#pragma mark - 跨折叠 indexPath 翻译（reply / locate 定位用）

/// 把 dataProvider 行索引翻译成 tableView 实际行索引。
/// 若目标消息位于折叠卡内且 `expand` = YES，自动把该折叠组加入展开集合并翻译到展开后的行。
/// 若 `expand` = NO，目标消息在折叠卡里时返回**折叠卡所在行**（用户可继续点击展开）。
/// 折叠未启用 / 目标消息未找到时返回 nil。
- (nullable NSIndexPath *)wk_fold_translatedIndexPathForDataProviderIndexPath:(NSIndexPath *)dpIndexPath
                                                               expandIfNeeded:(BOOL)expand;

#pragma mark - 增量更新（替代 pullup/pulldown 路径里的 reloadData，保留视觉连贯）

/// 在 dataProvider 变化**之前**调用，深拷一份当前 renderItems 快照。
/// 然后调用方 mutate dataProvider，再用 applyPullupIncremental:/applyPulldownIncremental:
/// 把变化以 insert/delete/reload 行的方式 diff 出来 + 在 performBatchUpdates 一次性提交。
/// 折叠未启用时返回 nil（调用方走原有非折叠路径）。
- (nullable NSArray<NSArray<WKBotFoldRenderItem *> *> *)wk_fold_snapshotRenderItemsBySection;

/// pullup 后调用：新数据在末尾追加（含可能的新 sections）。函数内部：
///  1) 失效 + 重建 fold cache（基于新 dataProvider 状态）
///  2) 对每个旧 section 做"longest common PREFIX"diff，beyond prefix 的差异按
///     delete/insert/reload 提交
///  3) 末尾追加的新 section 用 insertSections
///  4) 全部包在 performBatchUpdates 一次提交（无动画，无 reloadData）
///  5) **performBatchUpdates 的 completion 触发后**调用 `completion`，调用方在此
///     时调 scrollToBottom 才能拿到正确的 contentSize（batch 提交瞬间 contentSize
///     尚未稳定，直接调会滚到旧 bottom，新插入的行看不到）。
/// 折叠未启用 / oldItemsBySection 为 nil 时直接 no-op + 立即触发 completion。
- (void)wk_fold_applyPullupIncrementalWithOldItemsBySection:(nullable NSArray<NSArray<WKBotFoldRenderItem *> *> *)oldItemsBySection
                                              oldSectionCount:(NSInteger)oldSectionCount
                                            newSectionsAdded:(NSInteger)newSectionsAdded
                                                   completion:(nullable void(^)(void))completion;

/// pulldown 后调用：新数据在头部追加（含可能的新 sections 顶部插入）。函数内部：
///  1) 失效 + 重建 fold cache
///  2) 对每个旧 section（在新 section index 是 `s + newSectionsAdded`）做"longest
///     common SUFFIX"diff，前部差异按 delete/insert/reload 提交
///  3) 顶部追加的新 section 用 insertSections at [0..newSectionsAdded)
///  4) 全部包在 performBatchUpdates；完成回调里**调用方负责还原 contentOffset**
///     （拿 anchorClientMsgNo → translatedIndexPath → rectForRow → setContentOffset）。
- (void)wk_fold_applyPulldownIncrementalWithOldItemsBySection:(nullable NSArray<NSArray<WKBotFoldRenderItem *> *> *)oldItemsBySection
                                              oldSectionCount:(NSInteger)oldSectionCount
                                            newSectionsAdded:(NSInteger)newSectionsAdded
                                                   completion:(nullable void(^)(void))completion;

@end

NS_ASSUME_NONNULL_END
