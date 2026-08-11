//
//  WKMessageList.h
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import <Foundation/Foundation.h>
#import "WKMessageModel.h"
NS_ASSUME_NONNULL_BEGIN

/// 消息列表的唯一 truth（UITableView 的数据源本体）。
///
/// 两条不变式（改动本类前务必先读）:
///
/// I1 —— **原子提交**: 任何会改变 section 数 / row 数的结构性变更, 必须在**一次**
///       messagesLock 作用域内完成, 观察者不允许看到中间态。历史上
///       `clearMessages` + `addMessages` 是两次独立加锁的调用, 中间那一瞬
///       `dates.count == 0`; 只要主线程在这个瞬间回到 runloop, UITableView 就会
///       拿上次缓存的 section 数来问已经变空的数据源 → NSRangeException。
///       改用 `replaceAllWithMessages:` / `prependMessages:` / `appendMessages:`。
///
/// I2 —— **读路径也要持锁**: `dates` 曾是 public 的 NSMutableArray, 外部既能裸读
///       (无锁) 也能直接改。现已收口为 `dateCount` / `dateAtSection:` /
///       `datesSnapshot` / `messagesAtDate:` / `rowCountAtSection:` 五个持锁访问器,
///       全部越界返 nil/空, 且返回的是不可变快照 —— 调用方拿去枚举时不会撞
///       "mutated while being enumerated"。
@interface WKMessageList : NSObject

#pragma mark - 只读访问（持锁，越界安全）

/// 日期分组数 = UITableView 的 section 数
-(NSInteger) dateCount;

/// section → 日期字符串。越界返回 nil（不 raise）。
-(NSString* __nullable) dateAtSection:(NSInteger)section;

/// 所有日期的不可变快照，可安全跨线程枚举。
-(NSArray<NSString*>*) datesSnapshot;

/// 某日期下的消息，返回不可变快照。date 不存在时返回 @[]。
-(NSArray<WKMessageModel*>*) messagesAtDate:(NSString*)date;

/// 某 section 的行数。语义等价于 `[self messagesAtDate:[self dateAtSection:section]].count`,
/// 但不产生数组拷贝 —— 这是 numberOfRowsInSection: 的热路径。
-(NSInteger) rowCountAtSection:(NSInteger)section;

#pragma mark - 原子提交（I1）

/// 违禁词过滤（就地改写 model.content）。
///
/// 必须在**测量高度之前**跑：`filter:` 是 1:1 字符替换（每个命中字符换成一个 `*`），
/// 中文敏感词换成等长的 `*` 之后**渲染宽度会变**，进而可能改变换行与 cell 高度。
/// 两段式下高度预热发生在写入数据源之前，所以过滤必须提前到 prepare 阶段，否则
/// 预热缓存的是"过滤前"文本的高度，气泡会偏高/偏低。
/// 幂等：`*` 不是违禁词，重复过滤是 no-op，所以写入时的那次调用仍作为兜底保留。
+ (void)applyProhibitwords:(WKMessageModel *)model;

/// 整体替换：清空 + 按序追加，一次锁内完成。pullFirst / reset-load 用。
-(void) replaceAllWithMessages:(NSArray<WKMessageModel*>*)messages;

/// 前插一批历史消息（messages 按 orderSeq 升序传入），一次锁内完成。pulldown 用。
-(void) prependMessages:(NSArray<WKMessageModel*>*)messages;

/// 后追加一批消息（messages 按 orderSeq 升序传入），一次锁内完成。pullup 用。
-(void) appendMessages:(NSArray<WKMessageModel*>*)messages;

/// 清空。单独使用时调用方必须在同一个主线程 turn 内让 tableView 失效。
-(void) clearMessages;

#pragma mark - 单条变更

-(void) addMessage:(WKMessageModel*)message;

/// 最近一次 `addMessage:` / `appendMessages:` 是否**全部**落在列表最末（纯尾插）。
///
/// 插入是按序定位的（orderSeq，相同比 timestamp；未 ack 的本地消息与 typing 固定置底），
/// 所以新消息不保证落在末尾 —— 并发交错时（例如 pullup 预热窗口内本地发送）会发生
/// **中段插入**。而调用方的增量刷新普遍假设"末尾新增 N 行"并据此算 indexPath，
/// 那个假设一旦不成立，算出来的 indexPath 就是错的（行数仍对得上，所以不抛异常，
/// 但渲染内容会错位，比乱序更糟）。
///
/// 所以约定：调用方在 add/append 之后读这个值 ——
///   YES → 走原有增量 insertRows/insertSections（正常路径，行为不变）
///   NO  → 必须 reloadData
/// 主线程同 turn 内读取有效，不跨调用保留语义。
@property (nonatomic, assign, readonly) BOOL lastInsertWasPureTailAppend;

// 设置消息
-(void) setMessages:(NSArray<WKMessageModel*>*)messages forDate:(NSString*)date;

-(void) insertMessage:(WKMessageModel*)message atIndex:(NSIndexPath*)indexPath;

-(NSIndexPath* __nullable) removeMessage:(WKMessageModel*) message;

// sectionRemove 表示 section是否整个都移除了
-(NSIndexPath* __nullable) removeMessage:(WKMessageModel*) message sectionRemove:(BOOL*)sectionRemove;

-(NSIndexPath* __nullable) replaceMessage:(WKMessageModel*)newMessage atClientMsgNo:(NSString*)clientMsgNo;

#pragma mark - 查询

-(WKMessageModel* __nullable) lastMessage;

-(WKMessageModel* __nullable) firstMessage;

-(NSIndexPath* __nullable) indexPathAtOrderSeq:(uint32_t)orderSeq;

-(NSIndexPath* __nullable) indexPathAtClientMsgNo:(NSString*) clientMsgNo;

-(NSIndexPath* __nullable) indexPathAtStreamNo:(NSString*)streamNo;

-(NSIndexPath* __nullable) indexPathAtMessageID:(uint64_t)messageID;

// 获取包含有回复messageID的消息的消息
-(NSArray<NSIndexPath*>*) indexPathAtMessageReply:(uint64_t)messageID;
-(NSArray<WKMessageModel*>*) messagesAtMessageReply:(uint64_t)messageID;

-(NSInteger) messageCount;

-(NSArray<WKMessageModel*>*) getSelectedMessages; // 获取被选中的消息

-(void) cancelSelectedMessages; // 取消被选中的消息

// 把 orderSeq 闭区间内所有可选消息的 checked 置为 YES（并集，已选保留），返回新选中的消息条数
-(NSInteger) selectMessagesFromOrderSeq:(uint32_t)orderSeqA toOrderSeq:(uint32_t)orderSeqB;

-(NSArray<WKMessageModel*>*) getMessagesWithContentType:(NSInteger)contentType;

// -------------------- typing --------------------

- (BOOL)hasTyping;
-(NSIndexPath* __nullable) replaceTyping:(WKMessageModel*)message;
-(void) addTypingMessageIfNeed:(WKMessageModel*)messageModel; // 根据需要添加typing消息

@end

NS_ASSUME_NONNULL_END
