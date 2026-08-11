//
//  WKMessageList.m
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import "WKMessageList.h"
#import "WKTimeTool.h"
#import "WuKongBase.h"
#import "WKProhibitwordsService.h"

// 锁纪律（见 WKMessageList.h 的 I1 / I2）:
//   - 所有 public 方法各自恰好加锁一次, 然后调 `_xxxNoLock` 内部方法完成工作。
//   - 带 `NoLock` 后缀的方法**必须**在持有 messagesLock 的情况下调用, 且它们之间
//     互相调用不会重复加锁 (NSLock 非递归, 重入即死锁)。
//   - 内部方法一律直接用 `self.dates` / `self.dateMessageGroups` (纯 lazy getter,
//     不加锁); public 只读访问器 (dateCount / dateAtSection: / datesSnapshot /
//     messagesAtDate: / rowCountAtSection:) 才加锁。
@interface WKMessageList ()

@property(nonatomic,strong) NSLock *messagesLock;

@property(nonatomic,strong) NSMutableArray<NSString*> *dates; // 消息日期 (私有: 外部只能走持锁访问器)

@property(nonatomic,strong) NSMutableDictionary<NSString*,NSMutableArray<WKMessageModel*>*> *dateMessageGroups; // 通过日期对消息分组

// O(1) 查找索引：存 model 引用而非 NSIndexPath，避免插入/删除后 indexPath 陈旧
// indexPath 在需要时通过 _indexPathForModelNoLock: 从 model 反向计算（O(D+K)，D=日期数，K=当天消息数）
@property(nonatomic,strong) NSMutableDictionary<NSString*, WKMessageModel*> *clientMsgNoIndex;
@property(nonatomic,strong) NSMutableDictionary<NSNumber*, WKMessageModel*> *orderSeqIndex;
@property(nonatomic,strong) NSMutableDictionary<NSNumber*, WKMessageModel*> *messageIdIndex;
@property(nonatomic,strong) NSMutableDictionary<NSString*, WKMessageModel*> *streamNoIndex;

@end

@implementation WKMessageList

// 锁必须在 init 里就建好。历史实现只有 lazy getter, 而多处代码用 `_messagesLock`
// 直接发消息 —— 首次调用时 ivar 还是 nil, `[nil lock]` 是无害的 no-op, 于是那次
// 访问**完全没有锁**。
- (instancetype)init {
    self = [super init];
    if (self) {
        _messagesLock = [[NSLock alloc] init];
    }
    return self;
}

#pragma mark - 索引维护（调用前必须持有 messagesLock）

- (void)_addToIndexNoLock:(WKMessageModel *)model {
    if (model.clientMsgNo.length > 0) self.clientMsgNoIndex[model.clientMsgNo] = model;
    if (model.orderSeq > 0) self.orderSeqIndex[@(model.orderSeq)] = model;
    if (model.messageId > 0) self.messageIdIndex[@(model.messageId)] = model;
    if (model.streamNo.length > 0) self.streamNoIndex[model.streamNo] = model;
}

- (void)_removeFromIndexNoLock:(WKMessageModel *)model {
    if (model.clientMsgNo.length > 0) [self.clientMsgNoIndex removeObjectForKey:model.clientMsgNo];
    if (model.orderSeq > 0) [self.orderSeqIndex removeObjectForKey:@(model.orderSeq)];
    if (model.messageId > 0) [self.messageIdIndex removeObjectForKey:@(model.messageId)];
    if (model.streamNo.length > 0) [self.streamNoIndex removeObjectForKey:model.streamNo];
}

// 由 model 反推 NSIndexPath：O(D+K)，D=日期分组数(<20)，K=当天消息数，远小于总消息数 N
- (NSIndexPath *)_indexPathForModelNoLock:(WKMessageModel *)model {
    if (!model) return nil;
    NSString *date = [self formatMessageDate:model];
    NSInteger section = [self.dates indexOfObject:date];
    if (section == NSNotFound) return nil;
    NSMutableArray *messages = self.dateMessageGroups[date];
    NSInteger row = [messages indexOfObjectIdenticalTo:model]; // 指针比较，不用 isEqual
    if (row == NSNotFound) return nil;
    return [NSIndexPath indexPathForRow:row inSection:section];
}

// clientMsgNo → indexPath, 全程无锁 (调用方持锁)。
// 历史实现是 public `indexPathAtClientMsgNo:` (自带 lock/unlock) 拿到 path 后**放锁**,
// 再重新加锁去用这个 path —— 两段之间别的线程改了 dates/messages, path 就是脏的,
// 后面 `self.dates[path.section]` / `messages[path.row]` 直接越界崩 (TOCTOU)。
// removeMessage: / replaceMessage:atClientMsgNo: 现在都走这个 NoLock 版本, 索引计算
// 与使用在同一个锁作用域内。
- (NSIndexPath *)_indexPathForClientMsgNoNoLock:(NSString *)clientMsgNo {
    if (clientMsgNo.length == 0) return nil;
    return [self _indexPathForModelNoLock:self.clientMsgNoIndex[clientMsgNo]];
}

// section → 当天消息数组 (可变本体)。越界 / 不存在返回 nil。
- (NSMutableArray<WKMessageModel*> *)_messagesAtSectionNoLock:(NSInteger)section {
    if (section < 0 || section >= (NSInteger)self.dates.count) return nil;
    return self.dateMessageGroups[self.dates[section]];
}

#pragma mark - 只读访问（持锁，越界安全）

- (NSInteger)dateCount {
    [_messagesLock lock];
    NSInteger count = (NSInteger)self.dates.count;
    [_messagesLock unlock];
    return count;
}

- (NSString *)dateAtSection:(NSInteger)section {
    [_messagesLock lock];
    NSString *date = (section >= 0 && section < (NSInteger)self.dates.count) ? self.dates[section] : nil;
    [_messagesLock unlock];
    return date;
}

- (NSArray<NSString *> *)datesSnapshot {
    [_messagesLock lock];
    NSArray<NSString*> *snapshot = [self.dates copy];
    [_messagesLock unlock];
    return snapshot ?: @[];
}

// 返回**不可变快照**而不是 dateMessageGroups 里的可变本体 —— 调用方（含后台线程的
// 高度预热 / 枚举）持有本体时若主线程插了一条, 就是 "mutated while being enumerated"
// 的 SIGSEGV。
-(NSArray<WKMessageModel*>*) messagesAtDate:(NSString*)date {
    if (!date) return @[];
    [_messagesLock lock];
    NSArray<WKMessageModel*> *messages = [self.dateMessageGroups[date] copy];
    [_messagesLock unlock];
    return messages ?: @[];
}

// numberOfRowsInSection: 的热路径, 不走 messagesAtDate: 以免每帧每 section 拷一次数组。
- (NSInteger)rowCountAtSection:(NSInteger)section {
    [_messagesLock lock];
    NSInteger count = (NSInteger)[self _messagesAtSectionNoLock:section].count;
    [_messagesLock unlock];
    return count;
}

#pragma mark - 原子提交（I1）

- (void)_clearAllNoLock {
    [self.dates removeAllObjects];
    [self.dateMessageGroups removeAllObjects];
    [self.clientMsgNoIndex removeAllObjects];
    [self.orderSeqIndex removeAllObjects];
    [self.messageIdIndex removeAllObjects];
    [self.streamNoIndex removeAllObjects];
}

// 清空 + 按序追加, 一次锁内完成。
// 关键: 绝不能拆成 `clearMessages` + `appendMessages:` 两次调用 —— 那样中间会出现
// `dates.count == 0` 的可观测中间态, 正是 `dateWithSection:` /
// `messagesAtSection:` 一族越界崩溃的来源。
- (void)replaceAllWithMessages:(NSArray<WKMessageModel *> *)messages {
    [self.messagesLock lock];
    [self _clearAllNoLock];
    for (WKMessageModel *message in messages) {
        [self _addMessageNoLock:message];
    }
    [self.messagesLock unlock];
}

- (void)prependMessages:(NSArray<WKMessageModel *> *)messages {
    if (messages.count == 0) return;
    [self.messagesLock lock];
    // _insertMessageAtHeadNoLock: 每次都插到最前, 所以要倒序喂 (最新的先插),
    // 结果才是升序。历史上这个 reverse 由调用方 (dp 的 handleMessages) 负责,
    // 容易漏; 收进来由本方法保证。
    for (WKMessageModel *message in [messages reverseObjectEnumerator]) {
        [self _insertMessageAtHeadNoLock:message];
    }
    [self.messagesLock unlock];
}

- (void)appendMessages:(NSArray<WKMessageModel *> *)messages {
    if (messages.count == 0) return;
    [self.messagesLock lock];
    _lastInsertWasPureTailAppend = YES;
    for (WKMessageModel *message in messages) {
        [self _addMessageNoLock:message];
    }
    [self.messagesLock unlock];
}

-(void) clearMessages {
    [_messagesLock lock];
    [self _clearAllNoLock];
    [_messagesLock unlock];
}

#pragma mark - 插入 / 追加内部实现

// 插到列表最前（历史消息方向）
-(void) _insertMessageAtHeadNoLock:(WKMessageModel*)model {
    if(!model) {
        return;
    }
    if(model.clientMsgNo.length > 0 && self.clientMsgNoIndex[model.clientMsgNo]) {
        return;
    }
    // 违禁词过滤: 走统一的 handleProhibitwords: —— 它带 isKindOfClass 守卫。
    // 历史实现在这里裸转 `(WKTextContent*)model.content` 再 `filter:content.content`,
    // 服务端异常下 content 可能是 NSDictionary/NSNumber, 进 filter: 后 `message.length`
    // 直接 unrecognized selector 崩 (现网 `-[__NSDictionaryI length]` 7 次)。
    [self handleProhibitwords:model];

    NSString *date = [self formatMessageDate:model];
    NSMutableArray *messages = self.dateMessageGroups[date];
    if(!messages) {
        messages = [NSMutableArray array];
        self.dateMessageGroups[date] = messages;
        [self.dates insertObject:date atIndex:0];
    }
    if(messages.count>0) {
        WKMessageModel *oldMessageModel = messages.firstObject;
        model.nextMessageModel = oldMessageModel;
        oldMessageModel.preMessageModel = model;
    }
    [messages insertObject:model atIndex:0];
    [self _addToIndexNoLock:model];
}

// 追加到列表最后（新消息方向），含 typing 占位的替换/让位逻辑
-(void) _addMessageNoLock:(WKMessageModel*)message {
    if(!message) {
        return;
    }
    WKMessageModel *typingMessageModel;
    WKMessageModel *lastMessage = [self _lastMessageNoLock];
    if(lastMessage && lastMessage.contentType == WK_TYPING) {
        typingMessageModel = lastMessage;
    }
    if(typingMessageModel) {
        if(message.contentType == WK_TYPING) { // 如果已经有typing消息，则要添加的消息也是typing消息则直接丢弃
            return;
        }
        if([typingMessageModel.fromUid isEqual:message.fromUid]) {
            [self _replaceMessageLastNoLock:message];
        }else {
            NSMutableArray *messages = [self _messagesAtSectionNoLock:(NSInteger)self.dates.count - 1];
            if(messages.count > 0) {
                // 插到 typing 之前, 让 typing 保持在最后。
                // 这是一次**中段插入**(row = count-1, typing 还在它后面), 而调用方的增量
                // 刷新假设"末尾新增" —— 必须打掉纯尾插标记让它退化成 reloadData。
                // 这个错位在加标记之前就存在(见 handleRecvMessage 上方注释), 顺带修掉。
                _lastInsertWasPureTailAppend = NO;
                [self _insertMessageNoLock:message atIndex:[NSIndexPath indexPathForRow:messages.count-1 inSection:self.dates.count-1]];
            }else {
                [self _addMessageOnlyNoLock:message];
            }
        }
    }else {
        // pre/next 的连接已经收进 _addMessageOnlyNoLock: —— 它按插入位置去左右邻居
        // (含跨 section) 重接。这里**不能**再手工把 preMessageModel 指向"当前末条":
        // 按序插入之后新消息不一定落在末尾, 那样连出来的链是错的。
        [self _addMessageOnlyNoLock:message];
    }
}

-(void) _addMessageOnlyNoLock:(WKMessageModel *)message {
    if(message.clientMsgNo.length > 0 && self.clientMsgNoIndex[message.clientMsgNo]) {
        return;
    }

    [self handleProhibitwords:message]; // 处理违禁词

    NSString *date = [self formatMessageDate:message];
    NSMutableArray *messages = self.dateMessageGroups[date];
    NSInteger section;
    if(!messages) {
        messages = [NSMutableArray array];
        self.dateMessageGroups[date] = messages;
        // dates 也必须保持有序 —— 否则 section 顺序会依赖"消息按日期递增到达"这个
        // 无法保证的前提。日期串是 yyyy-MM-dd, 字典序 == 时间序。
        section = (NSInteger)self.dates.count;
        while(section > 0 && [self.dates[section-1] compare:date] == NSOrderedDescending) {
            section--;
        }
        [self.dates insertObject:date atIndex:section];
    } else {
        section = (NSInteger)[self.dates indexOfObject:date];
    }

    // 组内按序定位: 从尾部往前走。正常情况(新消息就是最新的)第一次比较就停 → O(1),
    // 与原来的 addObject: 开销等价; 只有乱序到达时才多走几步。
    NSInteger idx = (NSInteger)messages.count;
    while(idx > 0 && [self _shouldOrderAfterNoLock:messages[idx-1] than:message]) {
        idx--;
    }

    // 纯尾插判定: 落在最后一个 section 的最末。调用方据此决定走增量 insertRows 还是
    // reloadData —— 中段插入时按"末尾新增 N 行"算出来的 indexPath 是错的。
    if(!(section == (NSInteger)self.dates.count - 1 && idx == (NSInteger)messages.count)) {
        _lastInsertWasPureTailAppend = NO;
    }

    [messages insertObject:message atIndex:idx];

    // 重接 pre/next。链是**跨 section 全局**的, 所以组内首/末位要去相邻 section 取邻居。
    WKMessageModel *prev = (idx > 0) ? messages[idx-1] : [self _lastMessageOfSectionNoLock:section-1];
    WKMessageModel *next = (idx + 1 < (NSInteger)messages.count) ? messages[idx+1] : [self _firstMessageOfSectionNoLock:section+1];
    message.preMessageModel = prev;
    message.nextMessageModel = next;
    if(prev) prev.nextMessageModel = message;
    if(next) next.preMessageModel = message;

    [self _addToIndexNoLock:message];
}

/// 排序键的核心判定: 未 ack 的本地消息(以及 typing)固定置底。
///
/// 为什么不能纯按 orderSeq: 本地发送落库时 orderSeq = **本地库** max(order_seq)+1
/// (WKMessageDB.m:256-260)。如果更新的那一页还没下载到本地(例如用户正上滑读历史),
/// 这个临时值会**小于**那一页 —— 纯按 orderSeq 排会把"用户刚发出的消息"插到几十条
/// 更旧消息中间。messageSeq == 0 正好就是"服务端还没给它排序"这个条件。
/// 置底同时也符合用户直觉(自己发的就在最下面), 并且 ack 之后它的真实 orderSeq
/// (messageSeq × WKOrderSeqFactor) 通常已大于全部已加载消息, 位置自然正确 ——
/// 所以不需要额外做"ack 后重定位"。
-(BOOL) _isTailPinnedNoLock:(WKMessageModel*)model {
    if(!model) return NO;
    if(model.contentType == WK_TYPING) return YES;   // typing 永远在最后
    return model.messageSeq == 0;                    // 未 ack: orderSeq 只是本地临时值
}

/// a 是否应该排在 b 之后。与 WKChatManager.sortMessages: 同口径(orderSeq, 相同比 timestamp),
/// 额外叠加"置底"规则。
-(BOOL) _shouldOrderAfterNoLock:(WKMessageModel*)a than:(WKMessageModel*)b {
    BOOL aPinned = [self _isTailPinnedNoLock:a];
    BOOL bPinned = [self _isTailPinnedNoLock:b];
    if(aPinned != bPinned) {
        return aPinned;
    }
    if(a.orderSeq != b.orderSeq) {
        return a.orderSeq > b.orderSeq;
    }
    return a.timestamp > b.timestamp;
}

-(WKMessageModel*) _lastMessageOfSectionNoLock:(NSInteger)section {
    if(section < 0 || section >= (NSInteger)self.dates.count) return nil;
    NSMutableArray *arr = [self _messagesAtSectionNoLock:section];
    return arr.lastObject;
}

-(WKMessageModel*) _firstMessageOfSectionNoLock:(NSInteger)section {
    if(section < 0 || section >= (NSInteger)self.dates.count) return nil;
    NSMutableArray *arr = [self _messagesAtSectionNoLock:section];
    return arr.firstObject;
}

-(void) _insertMessageNoLock:(WKMessageModel*)message atIndex:(NSIndexPath*)indexPath {
    if(!message || !indexPath) {
        return;
    }
    NSMutableArray<WKMessageModel*> *messages = [self _messagesAtSectionNoLock:indexPath.section];
    if(!messages || indexPath.row < 0 || indexPath.row > (NSInteger)messages.count) {
        return;
    }

    if(messages.count>0) {
        if (indexPath.row == 0) { // 插入到最前面
            WKMessageModel *oldFirstMessage = messages[0];
            oldFirstMessage.preMessageModel = message;
            message.nextMessageModel = oldFirstMessage;
        } else if((NSInteger)messages.count>indexPath.row) { // 插入到非首尾
            WKMessageModel *currentMessage = messages[indexPath.row];

            message.preMessageModel = currentMessage.preMessageModel;
            message.nextMessageModel = currentMessage;

            currentMessage.preMessageModel = message;
            if(message.preMessageModel) {
                message.preMessageModel.nextMessageModel = message;
            }

        }else if((NSInteger)messages.count==indexPath.row) { // 插入到最后
            WKMessageModel *oldLastMessage = messages[messages.count-1];
            oldLastMessage.nextMessageModel = message;
            message.preMessageModel = oldLastMessage;
        }
    }

    [messages insertObject:message atIndex:indexPath.row];
    [self _addToIndexNoLock:message];
}

// 替换最新的消息
-(void) _replaceMessageLastNoLock:(WKMessageModel*)model {
    [self handleProhibitwords:model]; // 处理违禁词
    NSMutableArray *messages = [self _messagesAtSectionNoLock:(NSInteger)self.dates.count - 1];
    if(messages.count>0) {
        WKMessageModel *oldMessageModel = messages.lastObject;
        [self _removeFromIndexNoLock:oldMessageModel];
        model.preMessageModel = oldMessageModel.preMessageModel;
        if(oldMessageModel.preMessageModel) {
            oldMessageModel.preMessageModel.nextMessageModel = model;
        }
        [messages replaceObjectAtIndex:messages.count-1 withObject:model];
        [self _addToIndexNoLock:model];
    }
}

-(void) _replaceMessageNoLock:(WKMessageModel*)newMessage atIndexPath:(NSIndexPath*)path {
    NSMutableArray *messages = [self _messagesAtSectionNoLock:path.section];
    if(!messages || path.row < 0 || path.row >= (NSInteger)messages.count) {
        return;
    }
    WKMessageModel *oldMessage = messages[path.row];
    [self _removeFromIndexNoLock:oldMessage];
    newMessage.preMessageModel = oldMessage.preMessageModel;
    newMessage.nextMessageModel = oldMessage.nextMessageModel;
    messages[path.row] = newMessage;
    [self _addToIndexNoLock:newMessage];
    if(oldMessage.preMessageModel) {
        oldMessage.preMessageModel.nextMessageModel = newMessage;
    }
    if(oldMessage.nextMessageModel) {
        oldMessage.nextMessageModel.preMessageModel = newMessage;
    }
}

#pragma mark - 单条变更

-(void) addMessage:(WKMessageModel*)message {
    [self.messagesLock lock];
    _lastInsertWasPureTailAppend = YES;
    [self _addMessageNoLock:message];
    [self.messagesLock unlock];
}

-(void) insertMessage:(WKMessageModel*)message atIndex:(NSIndexPath*)indexPath {
    [self.messagesLock lock];
    [self _insertMessageNoLock:message atIndex:indexPath];
    [self.messagesLock unlock];
}

// 历史实现完全没加锁, 却调了 `_removeFromIndexNoLock:` / `_addToIndexNoLock:`。
-(void) setMessages:(NSArray<WKMessageModel*>*)messages forDate:(NSString*)date {
    if (!date) return;
    [self.messagesLock lock];
    NSMutableArray *oldMessages = self.dateMessageGroups[date];
    for (WKMessageModel *m in oldMessages) [self _removeFromIndexNoLock:m];
    NSMutableArray *newMessages = [NSMutableArray arrayWithArray:messages];
    self.dateMessageGroups[date] = newMessages;
    if (![self.dates containsObject:date]) {
        // 历史实现只写 dateMessageGroups 不写 dates —— 该 date 永远不会成为一个
        // section, 消息静默消失 (端到端加密提示语走的就是这条路)。
        [self.dates addObject:date];
        [self.dates sortUsingSelector:@selector(compare:)]; // dates 按日期升序
    }
    for (WKMessageModel *m in newMessages) [self _addToIndexNoLock:m];
    [self.messagesLock unlock];
}

-(NSIndexPath*) removeMessage:(WKMessageModel*) message {
    BOOL sectionRemoved = NO;
    return [self removeMessage:message sectionRemove:&sectionRemoved];
}

-(NSIndexPath*) removeMessage:(WKMessageModel*) message sectionRemove:(BOOL*)sectionRemove{
    [_messagesLock lock];
    NSIndexPath *path = [self _indexPathForClientMsgNoNoLock:message.clientMsgNo];
    if(path) {
        NSMutableArray *messages = [self _messagesAtSectionNoLock:path.section];
        if(messages && path.row >= 0 && path.row < (NSInteger)messages.count) {
            WKMessageModel *deleteMessageModel = messages[path.row];
            [self _removeFromIndexNoLock:deleteMessageModel];
            if(deleteMessageModel.preMessageModel) {
                deleteMessageModel.preMessageModel.nextMessageModel = deleteMessageModel.nextMessageModel;
            }
            if(deleteMessageModel.nextMessageModel) {
                deleteMessageModel.nextMessageModel.preMessageModel = deleteMessageModel.preMessageModel;
            }

            [messages removeObjectAtIndex:path.row];
            if(messages.count == 0) {
                if(sectionRemove) {
                    *sectionRemove = true;
                }
                [self.dateMessageGroups removeObjectForKey:self.dates[path.section]];
                [self.dates removeObjectAtIndex:path.section];
            }
        }else {
            path = nil; // 索引已失效, 不要把脏 path 交给 tableView 去 deleteRows
        }
    }
    [_messagesLock unlock];
    return path;
}

-(NSIndexPath*) replaceMessage:(WKMessageModel*)newMessage atClientMsgNo:(NSString*)clientMsgNo {
    [self handleProhibitwords:newMessage]; // 处理违禁词 (纯 model 操作, 不需要持锁)
    [_messagesLock lock];
    NSIndexPath *path = [self _indexPathForClientMsgNoNoLock:clientMsgNo];
    if(path) {
        [self _replaceMessageNoLock:newMessage atIndexPath:path];
    }
    [_messagesLock unlock];
    return path;
}

// 违禁词过滤的唯一实现。类方法, 供 prepare 阶段在测量高度前先跑一遍
// (见 WKMessageList.h 的 applyProhibitwords: 说明)。
+ (void)applyProhibitwords:(WKMessageModel *)messageModel {
    if(messageModel.contentType != WK_TEXT) {
        return;
    }
    if(messageModel.remoteExtra.isEdit && [messageModel.remoteExtra.contentEdit isKindOfClass:[WKTextContent class]]) {
        WKTextContent *content = (WKTextContent*)messageModel.remoteExtra.contentEdit;
        if ([content.content isKindOfClass:[NSString class]]) {
            content.content = [WKProhibitwordsService.shared filter:content.content];
        }
        return;
    }
    if (![messageModel.content isKindOfClass:[WKTextContent class]]) return;
    WKTextContent *content = (WKTextContent*)messageModel.content;
    if ([content.content isKindOfClass:[NSString class]]) {
        content.content = [WKProhibitwordsService.shared filter:content.content];
    }
}

-(void) handleProhibitwords:(WKMessageModel*)messageModel {
    [WKMessageList applyProhibitwords:messageModel];
}

#pragma mark - 查询

-(WKMessageModel*) _lastMessageNoLock {
    NSMutableArray *messageModels = [self _messagesAtSectionNoLock:(NSInteger)self.dates.count - 1];
    return messageModels.lastObject;
}

-(WKMessageModel*) lastMessage {
    [_messagesLock lock];
    WKMessageModel *model = [self _lastMessageNoLock];
    [_messagesLock unlock];
    return model;
}

-(WKMessageModel*) firstMessage {
    [_messagesLock lock];
    WKMessageModel *model = [self _messagesAtSectionNoLock:0].firstObject;
    [_messagesLock unlock];
    return model;
}

-(NSIndexPath*) indexPathAtOrderSeq:(uint32_t)orderSeq {
    if(orderSeq == 0) return nil;
    [_messagesLock lock];
    NSIndexPath *path = [self _indexPathForModelNoLock:self.orderSeqIndex[@(orderSeq)]];
    [_messagesLock unlock];
    return path;
}

-(NSIndexPath*) indexPathAtMessageID:(uint64_t)messageID {
    if(messageID == 0) return nil;
    [_messagesLock lock];
    NSIndexPath *path = [self _indexPathForModelNoLock:self.messageIdIndex[@(messageID)]];
    [_messagesLock unlock];
    return path;
}

-(NSArray<NSIndexPath*>*) indexPathAtMessageReply:(uint64_t)messageID {
    if(messageID == 0 ){
        return nil;
    }
    [_messagesLock lock];
    NSMutableArray<NSIndexPath*> *indexPaths = [NSMutableArray array];
    for (NSInteger i=(NSInteger)self.dates.count-1; i>=0; i--) {
        NSMutableArray *messages = self.dateMessageGroups[self.dates[i]];
        for (NSInteger j=(NSInteger)messages.count-1;j>=0; j--) {
            WKMessageModel *messageModel = messages[j];
            if(messageModel.content.reply && [messageModel.content.reply.messageID longLongValue] == messageID) {
                [indexPaths addObject:[NSIndexPath indexPathForRow:j inSection:i]];
            }
        }
    }
    [_messagesLock unlock];
    return indexPaths;
}

-(NSArray<WKMessageModel*>*) messagesAtMessageReply:(uint64_t)messageID {
    if(messageID == 0 ){
        return nil;
    }
    [_messagesLock lock];
    NSMutableArray<WKMessageModel*> *resultMessages = [NSMutableArray array];
    for (NSInteger i=(NSInteger)self.dates.count-1; i>=0; i--) {
        NSMutableArray *messages = self.dateMessageGroups[self.dates[i]];
        for (NSInteger j=(NSInteger)messages.count-1;j>=0; j--) {
            WKMessageModel *messageModel = messages[j];
            if(messageModel.content.reply && [messageModel.content.reply.messageID longLongValue] == messageID) {
                [resultMessages addObject:messageModel];
            }
        }
    }
    [_messagesLock unlock];
    return resultMessages;
}

-(NSIndexPath*) indexPathAtClientMsgNo:(NSString*) clientMsgNo {
    if(!clientMsgNo) return nil;
    [_messagesLock lock];
    NSIndexPath *path = [self _indexPathForClientMsgNoNoLock:clientMsgNo];
    [_messagesLock unlock];
    return path;
}

-(NSIndexPath*) indexPathAtStreamNo:(NSString*)streamNo {
    if(!streamNo) return nil;
    [_messagesLock lock];
    NSIndexPath *path = [self _indexPathForModelNoLock:self.streamNoIndex[streamNo]];
    [_messagesLock unlock];
    return path;
}

-(NSInteger) messageCount {
    [self.messagesLock lock];
   __block NSInteger count = 0;
    [self.dateMessageGroups enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<WKMessageModel *> * _Nonnull obj, BOOL * _Nonnull stop) {
        if(obj) {
            count+=obj.count;
        }
    }];
    [self.messagesLock unlock];
    return count;
}

-(NSArray<WKMessageModel*>*) getMessagesWithContentType:(NSInteger)contentType {
    __block NSMutableArray<WKMessageModel*> *filterModels = [NSMutableArray array];
     [self.messagesLock lock];
    [self.dateMessageGroups enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<WKMessageModel *> * _Nonnull messages, BOOL * _Nonnull stop) {
        for (WKMessageModel *messageModel in  messages) {
            if(messageModel.contentType == contentType) {
                [filterModels insertObject:messageModel atIndex:0];
            }
        }
    }];
     [self.messagesLock unlock];
    return filterModels;
}

// 获取被选中的消息
-(NSArray<WKMessageModel*>*) getSelectedMessages {
    [self.messagesLock lock];
    NSMutableArray *selectedMessages = [NSMutableArray array];
    [self.dateMessageGroups enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<WKMessageModel *> * _Nonnull messages, BOOL * _Nonnull stop) {
        for (WKMessageModel *messageModel in messages) {
            if(messageModel.checked) {
                [selectedMessages addObject:messageModel];
            }
        }
    }];
    [self.messagesLock unlock];
    return selectedMessages;
}

-(void) cancelSelectedMessages {
    [self.messagesLock lock];
    [self.dateMessageGroups enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<WKMessageModel *> * _Nonnull messages, BOOL * _Nonnull stop) {
        for (WKMessageModel *messageModel in messages) {
            if(messageModel.checked) {
                messageModel.checked = false;
            }
        }
    }];
    [self.messagesLock unlock];
    return;
}

// 把 orderSeq 闭区间 [min, max] 内所有可选消息的 checked 置为 YES，并集语义。
// 跨日期 section 安全：基于 orderSeq 而不是 indexPath。
-(NSInteger) selectMessagesFromOrderSeq:(uint32_t)orderSeqA toOrderSeq:(uint32_t)orderSeqB {
    if(orderSeqA == 0 || orderSeqB == 0) {
        return 0;
    }
    uint32_t minSeq = MIN(orderSeqA, orderSeqB);
    uint32_t maxSeq = MAX(orderSeqA, orderSeqB);
    __block NSInteger added = 0;
    [self.messagesLock lock];
    [self.dateMessageGroups enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<WKMessageModel *> * _Nonnull messages, BOOL * _Nonnull stop) {
        for (WKMessageModel *messageModel in messages) {
            if(messageModel.contentType == WK_TYPING) continue;
            if(messageModel.orderSeq == 0) continue;
            if(messageModel.orderSeq < minSeq || messageModel.orderSeq > maxSeq) continue;
            if(!messageModel.checked) {
                messageModel.checked = YES;
                added++;
            }
        }
    }];
    [self.messagesLock unlock];
    return added;
}

#pragma mark - typing

- (NSIndexPath*)_typingIndexPathNoLock {
    NSMutableArray *messages = [self _messagesAtSectionNoLock:(NSInteger)self.dates.count - 1];
    if(messages.count>0) {
        WKMessageModel *message = messages.lastObject;
        if(message.contentType == WK_TYPING) {
            return [NSIndexPath indexPathForRow:messages.count-1 inSection:self.dates.count-1];
        }
    }
    return nil;
}

- (BOOL)hasTyping {
    [self.messagesLock lock];
    BOOL has = [self _typingIndexPathNoLock] != nil;
    [self.messagesLock unlock];
    return has;
}

-(NSIndexPath*) replaceTyping:(WKMessageModel*)messageModel {
    [self.messagesLock lock];
    NSIndexPath *indexPath = [self _typingIndexPathNoLock];
    if(indexPath) {
        NSMutableArray *messages = [self _messagesAtSectionNoLock:indexPath.section];
        WKMessageModel *typingMessageModel = messages[indexPath.row];
        [self _removeFromIndexNoLock:typingMessageModel];
        if(typingMessageModel.preMessageModel) {
            typingMessageModel.preMessageModel.nextMessageModel = messageModel;
        }
        if(typingMessageModel.nextMessageModel) {
            typingMessageModel.nextMessageModel.preMessageModel = messageModel;
        }
        messageModel.preMessageModel = typingMessageModel.preMessageModel;
        messageModel.nextMessageModel = typingMessageModel.nextMessageModel;

        messages[indexPath.row] = messageModel;
        [self _addToIndexNoLock:messageModel];
    }
    [self.messagesLock unlock];

    return indexPath;
}

-(void) addTypingMessageIfNeed:(WKMessageModel*)messageModel {
    // hasTyping 与 addMessage: 各自加锁, 中间的窗口无害: typing 只是个占位气泡,
    // 最坏情况多插一条, _addMessageNoLock 里的 "已有 typing 则丢弃" 会兜住。
    if([self hasTyping]) {
        return;
    }
    [self addMessage:messageModel];
}

#pragma mark - 日期格式化

-(NSString*) formatMessageDate:(WKMessageModel*)model {
    return [self formatDate:[NSDate dateWithTimeIntervalSince1970:model.timestamp] ];
}

-(NSString*) formatDate:(NSDate*)date {
    return [WKTimeTool getTimeString:date format:@"yyyy-MM-dd" ];
}

#pragma mark - lazy

- (NSMutableArray<NSString*> *)dates {
    if(!_dates) {
        _dates = [NSMutableArray array];
    }
    return _dates;
}

- (NSMutableDictionary<NSString *,NSMutableArray<WKMessageModel *> *> *)dateMessageGroups {
    if(!_dateMessageGroups) {
        _dateMessageGroups = [[NSMutableDictionary alloc] init];
    }
    return _dateMessageGroups;
}

-(NSLock*) messagesLock {
    if(!_messagesLock) {
        _messagesLock = [[NSLock alloc] init];
    }
    return _messagesLock;
}

- (NSMutableDictionary *)clientMsgNoIndex {
    if (!_clientMsgNoIndex) _clientMsgNoIndex = [NSMutableDictionary dictionary];
    return _clientMsgNoIndex;
}
- (NSMutableDictionary *)orderSeqIndex {
    if (!_orderSeqIndex) _orderSeqIndex = [NSMutableDictionary dictionary];
    return _orderSeqIndex;
}
- (NSMutableDictionary *)messageIdIndex {
    if (!_messageIdIndex) _messageIdIndex = [NSMutableDictionary dictionary];
    return _messageIdIndex;
}
- (NSMutableDictionary *)streamNoIndex {
    if (!_streamNoIndex) _streamNoIndex = [NSMutableDictionary dictionary];
    return _streamNoIndex;
}

- (void)dealloc {
    NSLog(@"[WKMessageList dealloc]");
}

@end
