//
//  WKMessageListDataProvider.h
//  Pods
//
//  Created by tt on 2022/5/18.
//

#ifndef WKMessageListDataProvider_h
#define WKMessageListDataProvider_h


#endif /* WKMessageListDataProvider_h */

#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKMessageModel.h"
#import "WKConversationContext.h"
#import "WKConversationPosition.h"

NS_ASSUME_NONNULL_BEGIN

/// prepare 阶段的回调：只把拉回来的 model 交出去，**不写入数据源**。
/// 调用方（WKMessageListView）负责在后台预热高度后，回到主线程用 commitXxx: 提交。
typedef void(^WKMessageListPreparedBlock)(NSArray<WKMessageModel*> *models, BOOL hasMore);

@protocol WKMessageListDataProvider <NSObject>

#pragma mark - 拉取：prepare / commit 两段式
//
// 为什么要拆成两段（这是一族现网崩溃的根治，改动前务必读完）:
//
// 老的 `pullFirst:complete:` 在 complete 之前就已经把消息写进了 messageList,
// 而 view 侧拿到 complete 后还要 `dispatch_async` 到后台队列预热 cell 高度,
// 再 `dispatch_async` 回主线程才 reloadData / insertRows。于是存在一个窗口:
//
//     [main] messageList 已改 (dates: 3 → 1)     ← truth 变了
//     [bg]   precacheHeightForMessage × N        ← 主线程回到 runloop, 窗口打开
//     [main] reloadData                          ← tableView 才被告知
//
// 窗口内任何一次 layout pass 都会让 UITableView 拿**上次缓存的 section 数**去问
// **已经变短的数据源**:
//   - 读越界族: viewForHeaderInSection: → dateWithSection: → NSRangeException
//     (现网 `index 1 beyond bounds [0 .. 0]`, 5/5 份日志的后台线程都正停在
//      precacheHeightForMessage 里, 是直接证据)
//   - 一致性断言族: 窗口内任何 begin/endUpdates / reloadRows / performBatchUpdates
//     → `_Bug_Detected_In_Client_Of_UITableView_Invalid_Number_Of_Rows_In_Section`
//
// 两段式把窗口彻底消掉:
//   1) prepare: 拉数据 → 交出 models, 数据源一动不动
//   2) view 在后台对 models 预热高度（model 是独立对象, 不需要它已在列表里）
//   3) commit: 主线程一个 turn 内 `commitXxx:` + `reloadData/insertRows`, 中间
//      不允许出现任何 dispatch / await
//
// 不变式 I1: **dp 的结构性变更与对应的 tableView 失效, 必须在同一个主线程 turn 内。**

/// 请求第一屏消息。position 为空表示定位最新的消息。
/// 只交出 models，不写数据源 —— 调用方须用 `commitReplaceAll:` 提交。
-(void) pullFirst:(WKConversationPosition * __nullable)position prepared:(WKMessageListPreparedBlock)prepared;

/// 上拉（更新的消息）。调用方须用 `commitAppend:` 提交。
-(void) pullupPrepared:(WKMessageListPreparedBlock)prepared;

/// 下拉（更老的历史消息）。调用方须用 `commitPrepend:` 提交。
-(void) pulldownPrepared:(WKMessageListPreparedBlock)prepared;

/// 整体替换数据源（清空 + 按序写入），原子。必须在主线程调用，且同一个 turn 内让 tableView 失效。
-(void) commitReplaceAll:(NSArray<WKMessageModel*>*)models;

/// 前插历史消息，原子。必须在主线程调用，且同一个 turn 内让 tableView 失效。
-(void) commitPrepend:(NSArray<WKMessageModel*>*)models;

/// 后追加消息，原子。必须在主线程调用，且同一个 turn 内让 tableView 失效。
-(void) commitAppend:(NSArray<WKMessageModel*>*)models;

/// 转发 WKMessageList.lastInsertWasPureTailAppend —— 最近一次 addMessage: /
/// commitAppend: 是否全部落在末尾。插入是按序定位的, 并发交错时会中段插入, 而调用方的
/// 增量刷新假设"末尾新增 N 行"; 该值为 NO 时调用方**必须** reloadData 而不是走增量。
/// 详见 WKMessageList.h 上的完整说明。
-(BOOL) lastInsertWasPureTailAppend;

#pragma mark - 只读访问

// 日期数量
-(NSInteger) dateCount;

// 获取某个section的日期。越界返回 nil。
-(NSString* __nullable) dateWithSection:(NSInteger)section;

- (NSArray<NSString *> *)dates; // 当前列表的所有日期（不可变快照）

-(NSArray<WKMessageModel*>*) messagesAtDate:(NSString*)date; // 获取日期对应的消息（不可变快照）

// 某个 section 的行数。numberOfRowsInSection: 的热路径，不产生数组拷贝。
-(NSInteger) rowCountAtSection:(NSInteger)section;

-(NSInteger) messageCount; // 消息数量

// 通过indexPath获取消息model
-(WKMessageModel*__nullable) messageAtIndexPath:(NSIndexPath*)indexPath;

// 通过section获取消息集合（不可变快照）
-(NSArray<WKMessageModel*>*) messagesAtSection:(NSInteger)section;

// 最近会话上下文
-(id<WKConversationContext>) conversationContext;



@optional


// 通过clientMsgNo获取消息
-(WKMessageModel* __nullable) messageAtClientMsgNo:(NSString*)clientMsgNo;

// 通过流式编号获取消息
-(WKMessageModel*__nullable) messageAtStreamNo:(NSString*)streamNo;



// 通过orderSeq获取消息的indexpath
-(NSIndexPath*) indexPathAtOrderSeq:(uint32_t)orderSeq;

-(NSIndexPath*) indexPathAtClientMsgNo:(NSString*) clientMsgNo;
-(NSIndexPath*) indexPathAtMessageID:(uint64_t)messageID;

-(NSIndexPath*) indexPathAtStreamNo:(NSString*)streamNo;

// 获取包含有回复messageID的消息的消息
-(NSArray<NSIndexPath*>*) indexPathAtMessageReply:(uint64_t)messageID;
-(NSArray<WKMessageModel*>*) messagesAtMessageReply:(uint64_t)messageID;

-(void) insertMessage:(WKMessageModel*)message atIndex:(NSIndexPath*)indexPath;

-(NSIndexPath*) removeMessage:(WKMessageModel*) message sectionRemove:(BOOL*)sectionRemove;

// 添加消息
-(void) addMessage:(WKMessageModel*)message;
-(NSIndexPath*) removeMessage:(WKMessageModel*) message;



// 消息已读
-(void) didReaded:(NSArray<WKMessageModel*>*)messages;


-(WKMessageModel*) lastMessage;

-(WKMessageModel*) firstMessage;



/**
 清除消息
 */
-(void) clearMessages;

-(NSArray<WKMessageModel*>*) getSelectedMessages; // 获取被选中的消息

-(void) cancelSelectedMessages; // 取消被选中的消息

// 多选模式下的区间批量勾选（并集语义）
-(NSInteger) selectMessagesFromOrderSeq:(uint32_t)orderSeqA toOrderSeq:(uint32_t)orderSeqB;

-(NSArray<WKMessageModel*>*) getMessagesWithContentType:(NSInteger)contentType;


-(NSIndexPath*) replaceMessage:(WKMessageModel*)newMessage atClientMsgNo:(NSString*)clientMsgNo;

// -------------------- typing --------------------

- (BOOL)hasTyping;
-(NSIndexPath*) replaceTyping:(WKMessageModel*)message;
-(void) addTypingMessageIfNeed:(WKMessageModel*)messageModel; // 根据需要添加typing消息
@end

NS_ASSUME_NONNULL_END
