//
//  WKMessageListDataProviderImp.m
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import "WKMessageListDataProviderImp.h"
#import "WuKongbase.h"
#import "WKMessageList.h"
#import "WKEndToEndEncryptHitContent.h"
#import "WKConversationListVM.h"
@interface WKMessageListDataProviderImp ()

@property(nonatomic,strong) WKChannel *channel;

@property(nonatomic,strong) WKMessageList *messageList;


@property(nonatomic,assign) NSInteger newMsgCount; // 新消息数量

@property(nonatomic,strong) id<WKConversationContext> conversationContextInner;

/// 串行 I/O 队列：所有进入 SDK 的 pull* 调用都派发到这里，避免主线程被
/// SDK 内部对 FMDB queue 的 `dispatch_sync` 阻塞（ANR 11:40:06 367ms 路径）。
/// 必须串行——并发会让 SDK 的"递归补窗"两路同时写 messageList，破坏历史消息顺序。
@property(nonatomic,strong) dispatch_queue_t ioQueue;

@end

@implementation WKMessageListDataProviderImp

-(instancetype) initWithChannel:(WKChannel*)channel conversationContext:(id<WKConversationContext>)conversationContext{
    self = [super init];
    if (self) {
        self.channel = channel;
        self.conversationContextInner = conversationContext;
    }
    return self;
}

- (id<WKConversationContext>)conversationContext {
    return self.conversationContextInner;
}


// 请求第一屏消息
// prepare 阶段: 只把 models 交出去, **绝不碰 messageList**。写入由调用方在主线程
// 一个 turn 内用 commitReplaceAll: + reloadData 完成 (见 WKMessageListDataProvider.h
// 的两段式说明)。历史实现在这里就 clearMessages + handleMessages, 是现网
// `dateWithSection: index N beyond bounds` 的根因。
-(void) pullFirst:(WKConversationPosition*)position prepared:(WKMessageListPreparedBlock)prepared  {

    WKConversationWrapModel *model = [[WKConversationListVM shared] modelAtChannel:self.channel];
    uint32_t maxMessageSeq = 0;
    if(model && model.lastMessage && model.lastMessage.messageSeq>0) {
        maxMessageSeq = model.lastMessage.messageSeq;
    }

    if(position) {
        // 有 position 时始终走 pullAround:position.orderSeq, 即便当前频道需要空间过滤.
        // 原实现在 needsSpaceFiltering=YES 时直接走 pullLastWithSpaceFilter "从最新递归向前",
        // 把 position 丢掉, 表现就是「右下角 @ 我快速定位按钮在个人聊天 + Space 模式下,
        // 老 @ 消息所在窗口加载不到, 视图静默重载到最新页」(这条注释配套见 WKMessageListView.m
        // locateMessageCellWithOrderSeqForReminder:). 定位/跳转场景下的 position 指向的就是
        // 当前会话的某条具体消息, 不会"指到其他空间", 直接以它为锚拉一窗口即可;
        // 拉回的数据仍由 messagesToMessageModels: 里的 filterMessagesBySpace: 兜底过滤,
        // 不会出现"看到别的空间消息"的副作用.
        __weak typeof(self) weakSelf = self;
        // 串到 ioQueue：SDK 内部 pullMessages → getLocalMessages 是同步 FMDB 读，
        // 主线程发起会被 FMDB 串行队列堵 (ANR 11:40:06 367ms)；统一在 ioQueue 上发起。
        dispatch_async(self.ioQueue, ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if(!strongSelf) {
                [WKMessageListDataProviderImp callPrepared:prepared models:@[] hasMore:NO];
                return;
            }
            [[WKSDK shared].chatManager pullAround:strongSelf.channel orderSeq:position.orderSeq maxMessageSeq:maxMessageSeq limit:[WKApp shared].config.eachPageMsgLimit complete:^(NSArray<WKMessage *> * _Nonnull messages, NSError * _Nonnull error) {
                // complete 回调线程不确定：全本地命中走 ioQueue，calSync 走 SDK 内部 main hop。
                // 统一 hop 回 main，prepared 之后的 commit 必须在主线程。
                if(error || !messages || messages.count == 0) {
                    [WKMessageListDataProviderImp callPrepared:prepared models:@[] hasMore:NO];
                    return;
                }
                NSArray<WKMessageModel*> *models = [weakSelf messagesToMessageModels:messages];
                [WKMessageListDataProviderImp callPrepared:prepared
                                                   models:models
                                                  hasMore:[weakSelf hasMoreForCount:models.count]];
            }];
        });
    } else {
        // 没有 position: 从最新消息开始递归向前搜索 (内部 filterMessagesBySpace 在
        // 不需要过滤时退化为 no-op, 安全复用同一路径).
        [self pullLastWithSpaceFilter:0 maxMessageSeq:maxMessageSeq accumulated:[NSMutableArray array] existingIds:[NSMutableSet set] prepared:prepared];
    }
}

/// prepared 回调统一 hop 回主线程 —— commit 必须在主线程, 且要和 tableView 失效同 turn。
/// 顺带在这里把违禁词过滤跑完: 调用方紧接着就要在后台**测量这些 model 的高度**, 过滤会
/// 改变渲染宽度, 必须先过滤再测量 (见 WKMessageList.applyProhibitwords: 说明)。
/// 放在主线程做是因为 WKProhibitwordsService 的 keywordChains 会被 sync/refresh 改写,
/// 不保证并发读安全。
+(void) callPrepared:(WKMessageListPreparedBlock)prepared models:(NSArray<WKMessageModel*>*)models hasMore:(BOOL)hasMore {
    if(!prepared) {
        return;
    }
    void (^deliver)(void) = ^{
        for (WKMessageModel *model in models) {
            [WKMessageList applyProhibitwords:model];
        }
        prepared(models ?: @[], hasMore);
    };
    if([NSThread isMainThread]) {
        deliver();
        return;
    }
    dispatch_async(dispatch_get_main_queue(), deliver);
}

-(BOOL) hasMoreForCount:(NSInteger)count {
    return count >= [WKApp shared].config.eachPageMsgLimit;
}

#pragma mark - commit（必须主线程，且与 tableView 失效同一个 turn）

-(void) commitReplaceAll:(NSArray<WKMessageModel*>*)models {
    [self.messageList replaceAllWithMessages:models];
}

-(void) commitPrepend:(NSArray<WKMessageModel*>*)models {
    [self.messageList prependMessages:models];
}

-(void) commitAppend:(NSArray<WKMessageModel*>*)models {
    [self.messageList appendMessages:models];
}


-(NSArray<WKMessageModel*>*) messagesToMessageModels:(NSArray<WKMessage*>*) messages {
    // 按当前空间过滤消息
    NSArray<WKMessage*> *filteredMessages = [self filterMessagesBySpace:messages];
    NSMutableArray<WKMessageModel*> *messageModels = [NSMutableArray array];
    for (WKMessage *message in filteredMessages) {
        WKMessageModel *messageModel = [[WKMessageModel alloc] initWithMessage:message];
        [messageModels addObject:messageModel];
    }
    return messageModels;
}

/// 判断当前频道是否需要按空间过滤消息（所有个人聊天在多空间模式下都需要过滤）
-(BOOL) needsSpaceFiltering {
    if(self.channel.channelType != WK_PERSON) {
        return NO;
    }
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    return currentSpaceId && currentSpaceId.length > 0;
}

/// 过滤消息：仅显示当前空间的消息
/// 空间过滤模式下加载首屏：从最新消息递归向前搜索，直到凑够一页当前空间的消息
-(void) pullLastWithSpaceFilter:(uint32_t)endOrderSeq maxMessageSeq:(uint32_t)maxMessageSeq accumulated:(NSMutableArray<WKMessageModel*>*)accumulated existingIds:(NSMutableSet*)existingIds prepared:(WKMessageListPreparedBlock)prepared {
    NSInteger pageLimit = [WKApp shared].config.eachPageMsgLimit;
    __weak typeof(self) weakSelf = self;

    // 串到 ioQueue：SDK 内部本地 DB 读不再阻塞 main。递归调用本身也走 ioQueue，
    // 串行队列保证补窗顺序与原实现一致（不会两路并发改 accumulated）。
    dispatch_async(self.ioQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if(!strongSelf) {
            [WKMessageListDataProviderImp callPrepared:prepared models:@[] hasMore:NO];
            return;
        }
        [[WKSDK shared].chatManager pullLastMessages:strongSelf.channel endOrderSeq:endOrderSeq maxMessageSeq:maxMessageSeq limit:(int)pageLimit complete:^(NSArray<WKMessage *> * _Nonnull messages, NSError * _Nonnull error) {
            if (error || !messages || messages.count == 0) {
                // 递归到底: 把已累积的交出去 (可能为空)
                [accumulated sortUsingComparator:^NSComparisonResult(WKMessageModel *a, WKMessageModel *b) {
                    if (a.orderSeq < b.orderSeq) return NSOrderedAscending;
                    if (a.orderSeq > b.orderSeq) return NSOrderedDescending;
                    return NSOrderedSame;
                }];
                [WKMessageListDataProviderImp callPrepared:prepared
                                                   models:[accumulated copy]
                                                  hasMore:[weakSelf hasMoreForCount:accumulated.count]];
                return;
            }

            NSArray<WKMessageModel*> *models = [weakSelf messagesToMessageModels:messages];
            for (WKMessageModel *model in models) {
                if (![existingIds containsObject:model.clientMsgNo]) {
                    [existingIds addObject:model.clientMsgNo];
                    [accumulated addObject:model];
                }
            }

            BOOL rawHasMore = messages.count >= pageLimit;

            if (accumulated.count < (NSUInteger)pageLimit && rawHasMore) {
                WKMessage *oldestMsg = messages.lastObject;
                if (oldestMsg.orderSeq > 0) {
                    // 递归：再次进入会自己 dispatch 到 ioQueue
                    [weakSelf pullLastWithSpaceFilter:oldestMsg.orderSeq maxMessageSeq:maxMessageSeq accumulated:accumulated existingIds:existingIds prepared:prepared];
                    return;
                }
            }

            // 按 orderSeq 升序排列（旧消息在前，新消息在后）
            [accumulated sortUsingComparator:^NSComparisonResult(WKMessageModel *a, WKMessageModel *b) {
                if (a.orderSeq < b.orderSeq) return NSOrderedAscending;
                if (a.orderSeq > b.orderSeq) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            [WKMessageListDataProviderImp callPrepared:prepared
                                               models:[accumulated copy]
                                              hasMore:[weakSelf hasMoreForCount:accumulated.count]];
        }];
    });
}

-(NSArray<WKMessage*>*) filterMessagesBySpace:(NSArray<WKMessage*>*)messages {
    if(![self needsSpaceFiltering]) {
        return messages;
    }
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    BOOL isSystemBot = [self isSystemBotChannel];
    NSMutableArray<WKMessage*> *filtered = [NSMutableArray array];
    for (WKMessage *message in messages) {
        NSString *msgSpaceId = message.content.contentDict[@"space_id"];
        BOOL hasSpaceId = msgSpaceId && ![msgSpaceId isKindOfClass:[NSNull class]] && ([msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length > 0);
        if(!hasSpaceId) {
            // 无space_id的消息：系统bot(botfather/u_10000/fileHelper)在空间模式下隐藏，普通聊天向前兼容显示
            if(!isSystemBot) {
                [filtered addObject:message];
            }
        } else if([msgSpaceId isEqualToString:currentSpaceId]) {
            [filtered addObject:message]; // space_id匹配当前空间
        }
    }
    return filtered;
}

/// : 判断当前频道是否为系统bot频道。
/// 从 appconfig.system_bot_uids 读取（fallback `@[@"botfather", @"u_10000", @"fileHelper"]`），
/// 让 u_10000、fileHelper 跨 Space 历史消息也按空间过滤。
-(BOOL) isSystemBotChannel {
    if(!self.channel.channelId || self.channel.channelId.length == 0) {
        return NO;
    }
    NSArray<NSString*> *systemBotUIDs = [WKApp shared].config.systemBotUIDs;
    if(systemBotUIDs.count == 0) {
        return NO;
    }
    return [systemBotUIDs containsObject:self.channel.channelId];
}

/// 判断单条消息是否应在当前空间显示（用于实时消息过滤）
-(BOOL) shouldShowMessageInCurrentSpace:(WKMessage*)message {
    if(![self needsSpaceFiltering]) {
        return YES;
    }
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    NSString *msgSpaceId = message.content.contentDict[@"space_id"];
    BOOL hasSpaceId = msgSpaceId && ![msgSpaceId isKindOfClass:[NSNull class]] && ([msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length > 0);
    if(!hasSpaceId) {
        // 系统bot无space_id的消息在空间模式下不显示
        return ![self isSystemBotChannel];
    }
    return [msgSpaceId isEqualToString:currentSpaceId];
}

// handleMessages:insertFirst:complete: 已删除。
// 它的职责（写 messageList + 回调 complete）正是被根治的那个反模式：写入和
// "通知 tableView" 被拆到了不同的 runloop turn。现在写入统一走 commitXxx:，
// 由 view 侧在主线程与 reloadData/insertRows 同 turn 调用。

-(BOOL) hasEndToEndEncryptHitMessage {
    NSString *date = [self.messageList dateAtSection:0];
    if(!date) {
        return false;
    }
   NSArray<WKMessageModel*> *messages =  [self.messageList messagesAtDate:date];
    if(messages && messages.count>0) {
        if([ messages[0].content isKindOfClass:[WKEndToEndEncryptHitContent class]]) {
            return true;
        }
    }
    return false;
}

-(void) insertEndToEndEncryptHitMessageIfNeed {
    if(self.channel.channelType != WK_PERSON) {
        return;
    }
    if([self hasEndToEndEncryptHitMessage]) {
        return;
    }
//    if(self.state && !self.state.signalOn) {
//        return;
//    }
    NSString *firstDate = [self.messageList dateAtSection:0];
    if(firstDate) {
        NSMutableArray *messages = [NSMutableArray arrayWithArray:[self.messageList messagesAtDate:firstDate]];
        [messages insertObject:[self newEndToEndEncryptHitMessage] atIndex:0];
        [self.messageList setMessages:messages forDate:firstDate];
    }else {
        NSMutableArray *messages = [NSMutableArray arrayWithArray:@[[self newEndToEndEncryptHitMessage]]];
        [self.messageList setMessages:messages forDate:[self formatDate:[NSDate date]]];
    }
}

-(NSString*) formatDate:(NSDate*)date {
    return [WKTimeTool getTimeString:date format:@"yyyy-MM-dd" ];
}
-(WKMessageModel*) newEndToEndEncryptHitMessage {
    WKMessage *message = [WKMessage new];
    message.messageSeq = 1;
    message.content = [WKEndToEndEncryptHitContent new];
    NSNumber *contentType = [[message.content class] contentType];
    message.contentType = contentType.integerValue;
    return [[WKMessageModel alloc] initWithMessage:message];
}
- (WKMessageList *)messageList {
    if(!_messageList) {
        _messageList = [[WKMessageList alloc] init];
    }
    return _messageList;
}

- (dispatch_queue_t)ioQueue {
    if(!_ioQueue) {
        _ioQueue = dispatch_queue_create("com.octo.msglist.io", DISPATCH_QUEUE_SERIAL);
    }
    return _ioQueue;
}



#pragma mark -- WKMessageListDataProvider

- (void)clearMessages {
    [self.messageList clearMessages];
}

-(NSIndexPath*) replaceMessage:(WKMessageModel*)newMessage atClientMsgNo:(NSString*)clientMsgNo {
    
    return [self.messageList replaceMessage:newMessage atClientMsgNo:clientMsgNo];
}
- (NSArray<NSString *> *)dates {
    return [self.messageList datesSnapshot];
}

- (NSArray<WKMessageModel *> *)messagesAtDate:(NSString *)date {
    return [self.messageList messagesAtDate:date];
}

-(NSArray<WKMessageModel*>*) getMessagesWithContentType:(NSInteger)contentType {
    return [self.messageList getMessagesWithContentType:contentType];
}

- (NSArray<WKMessageModel *> *)getSelectedMessages {
    return [self.messageList getSelectedMessages];
}

- (void)cancelSelectedMessages {
    [self.messageList cancelSelectedMessages];
}

-(NSInteger) selectMessagesFromOrderSeq:(uint32_t)orderSeqA toOrderSeq:(uint32_t)orderSeqB {
    return [self.messageList selectMessagesFromOrderSeq:orderSeqA toOrderSeq:orderSeqB];
}

-(void) addMessage:(WKMessageModel*)message {
    [self.messageList addMessage:message];
}
// 上拉加载 (prepare 阶段: 不写 messageList, 见 WKMessageListDataProvider.h)
-(void) pullupPrepared:(WKMessageListPreparedBlock)prepared  {
    WKMessageModel *lastMessageModel = [self lastMessage];
    uint32_t baseOrderSeq = 0;
    if(lastMessageModel) {
        if(lastMessageModel.contentType == WK_TYPING) {
            if(lastMessageModel.preMessageModel) {
                baseOrderSeq = lastMessageModel.preMessageModel.orderSeq;
            }
        }else{
            baseOrderSeq = lastMessageModel.orderSeq;
        }

    }
    __weak typeof(self) weakSelf = self;
    // 串到 ioQueue：SDK 的 pullMessages 内部本地 DB 读不再在 main 上同步等 FMDB queue
    dispatch_async(self.ioQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if(!strongSelf) {
            [WKMessageListDataProviderImp callPrepared:prepared models:@[] hasMore:NO];
            return;
        }
        [[WKSDK shared].chatManager pullUp:strongSelf.channel startOrderSeq:baseOrderSeq limit:[WKApp shared].config.eachPageMsgLimit complete:^(NSArray<WKMessage *> * _Nonnull messages, NSError * _Nonnull error) {
            NSArray<WKMessageModel*> *models = [weakSelf messagesToMessageModels:messages];
            [WKMessageListDataProviderImp callPrepared:prepared
                                               models:models
                                              hasMore:[weakSelf hasMoreForCount:models.count]];
        }];
    });
}

// 下拉加载 (prepare 阶段: 不写 messageList)
-(void) pulldownPrepared:(WKMessageListPreparedBlock)prepared {
    WKMessageModel *firstMessageModel = [self firstMessage];
    uint32_t baseOrderSeq = 0;
    if(firstMessageModel) {
        baseOrderSeq = firstMessageModel.orderSeq;
    }
    [self pullDownRecursive:baseOrderSeq accumulated:[NSMutableArray array] existingIds:[NSMutableSet set] prepared:prepared];
}

/// 递归加载历史消息：空间过滤后不足一页时自动继续往前拉取，确保历史完整
-(void) pullDownRecursive:(uint32_t)startOrderSeq accumulated:(NSMutableArray<WKMessageModel*>*)accumulated existingIds:(NSMutableSet*)existingIds prepared:(WKMessageListPreparedBlock)prepared {
    NSInteger pageLimit = [WKApp shared].config.eachPageMsgLimit;
    __weak typeof(self) weakSelf = self;

    // 关键: pulldown 必须传 endOrderSeq 把查询严格收紧在「dpHead 往下一个连续窗口」内。
    //
    // 历史上用的 pullDown:startOrderSeq:limit: (= pullMessages 但 endOrderSeq=0 无下界)
    // 会让 SDK 在 local DB 里查「WHERE orderSeq < startOrderSeq ORDER BY DESC LIMIT N」,
    // 命中之前浏览历史时缓存的远古条目, 跟 dpHead 之间可能隔几千 / 上万 messageSeq 没人补。
    // 经典复现路径:
    //   1) 用户跳到某条 reminder 读历史 (dp 围绕 orderSeq~17K, local 缓存了 13K..72K 段)
    //   2) 锁屏期间群里新增大量消息 (server 端 lastMsg=2333K, local DB 大概率也同步进来一些
    //      碎片段 [191K..220K] 等, 但没有 [221K..2303K] 这块桥接)
    //   3) 解锁点跳转最新 → pullFirst:nil → dp reset 到 [2304K..2333K]
    //   4) 用户上滑 → pulldown(startOrderSeq=2304K, endOrderSeq=0) → SDK 命中 local DB
    //      [191K..220K] 段直接 prepend → dp 变成 [191K..220K, 2304K..2333K] **非连续**
    //      → UIKit cell 复用 / 日期 section / scroll offset 全错位 → 气泡损坏
    //
    // 修复后: 传入窗口下界 endOrderSeq = startOrderSeq - pageLimit × WKOrderSeqFactor × 10。
    //   - 30 条消息正常 span = 30 × 1000 = 30K orderSeq, 10× slack 给删除 / 空隙 = 300K 上限,
    //     任何活跃度的群够用 (实际死群更稀疏, 活跃群 messageSeq 是密集的)
    //   - local DB 在窗口内若有数据: 直接返回 → 跟当前 dpHead 连续的相邻 30 条 (正常 case)
    //   - local DB 在窗口内若空: SDK 内部 calSync 自动到 server 拉这段 → sync 进 local DB
    //     → 递归 pullMessages 再查一次 → 拿到桥接消息 (经典 reset-load 后第一次 pulldown)
    //   - 用户继续上滑: dpHead 移到刚回来的最老一条, 下次 pulldown 窗口下移, 继续按页 sync
    //
    // 不丢任何历史: 远古消息只是按需 + 连续地拉, 不再可能一次 prepend 跳进非连续区间。
    // 跟微信下滑读历史的语义对齐 — 上滑一页 = 当前位置往下相邻一页, 不会突然跳到三个月前。
    uint32_t endOrderSeq = 0;
    if (startOrderSeq > 0) {
        uint64_t bound = (uint64_t)pageLimit * (uint64_t)WKOrderSeqFactor * 10ull;
        endOrderSeq = (startOrderSeq > (uint32_t)bound) ? (startOrderSeq - (uint32_t)bound) : 1;
    }

    // 串到 ioQueue：SDK 本地 DB 读不再卡 main；递归调用也走 ioQueue，串行队列保证补窗顺序。
    dispatch_async(self.ioQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if(!strongSelf) {
            [WKMessageListDataProviderImp callPrepared:prepared models:@[] hasMore:NO];
            return;
        }
        [[WKSDK shared].chatManager pullMessages:strongSelf.channel
                                   startOrderSeq:startOrderSeq
                                     endOrderSeq:endOrderSeq
                                           limit:(int)pageLimit
                                        pullMode:WKPullModeDown
                                        complete:^(NSArray<WKMessage *> * _Nonnull messages, NSError * _Nonnull error) {
            #if DEBUG
            NSLog(@"[BubbleBugRepro] dp.pullDown SDK RETURN start=%u end=%u msgs=%lu err=%@",
                  startOrderSeq, endOrderSeq, (unsigned long)messages.count, error.localizedDescription ?: @"nil");
            #endif
            if (error || !messages || messages.count == 0) {
                // SDK 这一页空/出错: hasMore 保持与旧实现同源 —— 由已累积的条数决定,
                // 不要在这里硬置 NO (会提前禁用 pulldown 的下拉加载)。
                [WKMessageListDataProviderImp callPrepared:prepared
                                                   models:[accumulated copy]
                                                  hasMore:[weakSelf hasMoreForCount:accumulated.count]];
                return;
            }

            NSArray<WKMessageModel*> *models = [weakSelf messagesToMessageModels:messages];
            for (WKMessageModel *model in models) {
                if (![existingIds containsObject:model.clientMsgNo]) {
                    [existingIds addObject:model.clientMsgNo];
                    [accumulated addObject:model];
                }
            }

            BOOL rawHasMore = messages.count >= pageLimit;

            if ([weakSelf needsSpaceFiltering] && accumulated.count < (NSUInteger)pageLimit && rawHasMore) {
                WKMessage *oldestMsg = messages.lastObject;
                uint32_t nextSeq = oldestMsg.orderSeq;
                if (nextSeq > 0) {
                    // 递归：再次进入会自己 dispatch 到 ioQueue
                    [weakSelf pullDownRecursive:nextSeq accumulated:accumulated existingIds:existingIds prepared:prepared];
                    return;
                }
            }

            // accumulated 已按 SDK 返回顺序 (orderSeq 降序) 累积, commitPrepend: 要求升序传入,
            // 这里统一排好再交出去 —— prepend 的倒序插入由 WKMessageList 内部负责。
            [accumulated sortUsingComparator:^NSComparisonResult(WKMessageModel *a, WKMessageModel *b) {
                if (a.orderSeq < b.orderSeq) return NSOrderedAscending;
                if (a.orderSeq > b.orderSeq) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            [WKMessageListDataProviderImp callPrepared:prepared
                                               models:[accumulated copy]
                                              hasMore:[weakSelf hasMoreForCount:accumulated.count]];
        }];
    });
}


-(NSInteger) messageCount {
    
    return [self.messageList messageCount];
}

- (BOOL)hasTyping {
    return [self.messageList hasTyping];
}

- (NSIndexPath *)replaceTyping:(WKMessageModel *)message {
    return [self.messageList replaceTyping:message];
}


-(void) addTypingMessageIfNeed:(WKMessageModel*)messageModel {
    [self.messageList addTypingMessageIfNeed:messageModel];
}
-(NSIndexPath*) removeMessage:(WKMessageModel*) message {
    
    return [self.messageList removeMessage:message];
}

- (NSIndexPath *)removeMessage:(WKMessageModel *)message sectionRemove:(BOOL *)sectionRemove {
    return [self.messageList removeMessage:message sectionRemove:sectionRemove];
}

-(NSIndexPath*) indexPathAtMessageID:(uint64_t)messageID {
    return [self.messageList indexPathAtMessageID:messageID];
}

-(NSIndexPath*) indexPathAtStreamNo:(NSString*)streamNo {
    return [self.messageList indexPathAtStreamNo:streamNo];
}

-(NSArray<NSIndexPath*>*) indexPathAtMessageReply:(uint64_t)messageID {
    return [self.messageList indexPathAtMessageReply:messageID];
}

-(NSArray<WKMessageModel*>*) messagesAtMessageReply:(uint64_t)messageID {
    return [self.messageList messagesAtMessageReply:messageID];
}

-(NSIndexPath*) indexPathAtClientMsgNo:(NSString*) clientMsgNo {
    return [self.messageList indexPathAtClientMsgNo:clientMsgNo];
}

-(void) insertMessage:(WKMessageModel*)message atIndex:(NSIndexPath*)indexPath {
    [self.messageList insertMessage:message atIndex:indexPath];
}
- (WKMessageModel *)lastMessage {
    return [self.messageList lastMessage];
}

- (WKMessageModel *)firstMessage {
    return [self.messageList firstMessage];
}

-(NSIndexPath*) indexPathAtOrderSeq:(uint32_t)orderSeq {
    return [self.messageList indexPathAtOrderSeq:orderSeq];
}

- (NSInteger)dateCount {
    return [self.messageList dateCount];
}

// 越界返回 nil。窗口已被两段式消灭, 但 UITableView 的内部缓存本质上是异步的
// (reloadData 是惰性的, 下一次 layout 才重新 query), 保留越界兜底作为第二道防线。
- (NSString *)dateWithSection:(NSInteger)section {
    return [self.messageList dateAtSection:section];
}

- (NSInteger)rowCountAtSection:(NSInteger)section {
    return [self.messageList rowCountAtSection:section];
}

- (void)didReaded:(NSArray<WKMessageModel *> *)messageModels {
    if(![WKSDK shared].receiptManager.messageReadedProvider) {
        return;
    }
    NSMutableArray<WKMessage*> *messages = [NSMutableArray array];
    for (WKMessageModel *messageModel in messageModels) {
        [messages addObject:messageModel.message];
    }
    [[WKSDK shared].receiptManager addReceiptMessages:self.channel messages:messages];
}

- (WKMessageModel *)messageAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath || indexPath.section < 0 || indexPath.row < 0) return nil;
    NSString *date = [self.messageList dateAtSection:indexPath.section];
    if (!date) return nil;
    NSArray *messages = [self.messageList messagesAtDate:date];
    if (indexPath.row >= (NSInteger)messages.count) return nil;
    return messages[indexPath.row];
}

-(WKMessageModel* __nullable) messageAtClientMsgNo:(NSString*)clientMsgNo {
   NSIndexPath *indexPath = [self indexPathAtClientMsgNo:clientMsgNo];
    if(!indexPath) {
        return nil;
    }
    return [self messageAtIndexPath:indexPath];
}

-(WKMessageModel*__nullable) messageAtStreamNo:(NSString*)streamNo {
    NSIndexPath *indexPath = [self indexPathAtStreamNo:streamNo];
     if(!indexPath) {
         return nil;
     }
    return [self messageAtIndexPath:indexPath];
}

- (NSArray<WKMessageModel *> *)messagesAtSection:(NSInteger)section {
    NSString *date = [self.messageList dateAtSection:section];
    if (!date) {
        return @[];
    }
    return [self.messageList messagesAtDate:date];
}


@end
