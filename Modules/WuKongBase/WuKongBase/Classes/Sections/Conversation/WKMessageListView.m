//
//  WKConversationView.m
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import "WKMessageListView.h"
#import "WKConversationTableView.h"
#import "WuKongBase.h"
#import <MJRefresh/MJRefresh.h>
#import "WKTimeHeaderView.h"
#import "WKMessageRevokeCell.h"
#import "WKTextMessageCell.h"
#import <WuKongBase/WuKongBase-Swift.h>
#import "WKHistorySplitTipContent.h"
#import "WKTypingManager.h"
#import "WKMessageListView+Position.h"
#import "WKConversationListVM.h"
#import <WuKongBase/WuKongBase-Swift.h>
@interface WKMessageListView ()<UITableViewDelegate,UITableViewDataSource,WKConversationTableViewDelegate,WKChannelManagerDelegate,WKChatManagerDelegate,WKReactionManagerDelegate,WKConnectionManagerDelegate,WKTypingManagerDelegate,WKReminderManagerDelegate>

@property(nonatomic,strong) UIViewPropertyAnimator *headerViewsAnimator;
@property(nonatomic,assign) BOOL didManuallyStoppedTableViewDecelerating;

// -------------------- 历史风格线相关 --------------------
@property(nonatomic,assign,readonly) BOOL insertedHistorySplit;
@property(nonatomic,copy) NSString *insertedHistoryClientMsgNo;

@property(nonatomic,assign) BOOL multipleOn;
@property(nonatomic,strong,nullable) WKMessageModel *lastMessageInner;

// pulldown 期间串行化新消息，防止并发修改导致布局错乱
@property(nonatomic,assign) BOOL isPulldownInProgress;
@property(nonatomic,strong) NSMutableArray<WKMessage*> *pendingRecvMessages;

@end

@implementation WKMessageListView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.scrollEnabled  =YES;
    }
    return self;
}

-(void) setupUI {

    self.clipsToBounds = YES;
    [self addSubview:self.tableView];
    [self initPosition];

    [self addDelegates];

}

-(void) rebuildForStyleChange {
    // 保存当前滚动位置
    [self updatePosition];
    // 先清空数据源，防止旧 tableView 布局时越界
    [self.dataProvider clearMessages];
    [self.tableView reloadData];
    // 销毁旧 tableView（连同所有 cell 的 WebKit 缓存）
    [self.tableView removeFromSuperview];
    _tableView = nil;
    // 创建全新的 tableView
    [self addSubview:self.tableView];
    // 重新加载消息数据
    [self loadMessages];
}

- (void)viewDidLoad {
    [self setupUI];
    [self loadMessages];
    
    // 同步扩展数据
    [[WKSDK shared].chatManager syncMessageExtra:self.channel complete:nil];
    
    // 同步回应数据
    [[WKSDK shared].reactionManager sync:self.channel];
}

- (void)viewWillDisappear {
    [self updatePosition];
    // 界面退出停止播放
    [[WKSDK shared].mediaManager stopAudioPlay];
    
    [self markReminderDoneIfNeed];
}

- (void)setScrollEnabled:(BOOL)scrollEnabled {
    _scrollEnabled = scrollEnabled;
    self.tableView.scrollEnabled = scrollEnabled;
}

-(void) addDelegates {
    [[WKSDK shared].channelManager addDelegate:self]; // 频道数据监听
    [[WKSDK shared].chatManager addDelegate:self]; // 消息监听
    [[WKSDK shared].reactionManager addDelegate:self]; // 回应监听
    [[WKSDK shared].connectionManager addDelegate:self]; // 连接状态监听
    [[WKTypingManager shared] addDelegate:self]; // 正在输入...
    [[WKReminderManager shared] addDelegate:self]; // 提醒项监听
    // 外部分享消息发送通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onShareExtensionMessageSent:) name:@"WKShareExtensionMessageSent" object:nil];
}

-(void) removeDelegates {
    [[WKSDK shared].channelManager removeDelegate:self];
    [[WKSDK shared].chatManager removeDelegate:self];
    [[WKSDK shared].reactionManager removeDelegate:self];
    [[WKSDK shared].connectionManager  removeDelegate:self];
    [[WKTypingManager shared] removeDelegate:self];
    [[WKReminderManager shared] removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"WKShareExtensionMessageSent" object:nil];
}

/// 外部分享的消息发送后，插入消息到当前聊天页面
-(void) onShareExtensionMessageSent:(NSNotification *)notification {
    WKChannel *channel = notification.object;
    NSLog(@"[ShareExt] onShareExtensionMessageSent 收到通知, channel=%@_%d", channel.channelId, channel.channelType);
    if (!channel) {
        NSLog(@"[ShareExt] channel 为空，跳过");
        return;
    }

    NSArray<WKMessage *> *messages = notification.userInfo[@"messages"];
    NSLog(@"[ShareExt] 消息数量: %lu", (unsigned long)messages.count);
    if (!messages || messages.count == 0) return;

    // 检查第一条消息是否属于当前会话
    WKMessage *firstMsg = messages.firstObject;
    BOOL canHandle = [self needHandle:firstMsg];
    NSLog(@"[ShareExt] needHandle=%d, 消息channel=%@_%d, contentType=%ld", canHandle, firstMsg.channel.channelId, firstMsg.channel.channelType, (long)firstMsg.contentType);
    if (!canHandle) {
        NSLog(@"[ShareExt] 消息不属于当前会话，跳过");
        return;
    }

    NSInteger insertedCount = 0;
    for (WKMessage *msg in messages) {
        NSIndexPath *existPath = [self.dataProvider indexPathAtClientMsgNo:msg.clientMsgNo];
        NSLog(@"[ShareExt] 检查消息 clientMsgNo=%@, existPath=%@", msg.clientMsgNo, existPath);
        if (existPath) {
            NSLog(@"[ShareExt] 消息已存在，跳过");
            continue;
        }

        WKMessageModel *model = [[WKMessageModel alloc] initWithMessage:msg];
        NSLog(@"[ShareExt] 插入消息到 UI, contentType=%ld, status=%ld", (long)msg.contentType, (long)msg.status);
        [self sendMessage:model];
        insertedCount++;
    }
    NSLog(@"[ShareExt] 共插入 %ld 条消息到聊天页面", (long)insertedCount);
}



-(void) sendMessage:(WKMessageModel*)message {
    [self updateLastMsgIfNeed:message];

    // 预缓存高度（触发 markdown 渲染），避免在 UITableView 布局回调中首次渲染
    // Down 库的 WebKit 渲染会启动嵌套 RunLoop，在布局回调中会导致 UITableView 重入崩溃
    [self precacheHeightForMessage:message];

    // 快照 addMessage 前后的 section/row 数量，按实际变化增量更新
    NSInteger oldSectionCount = [self.dataProvider dateCount];
    NSInteger oldLastSectionRowCount = 0;
    if (oldSectionCount > 0) {
        oldLastSectionRowCount = [self.dataProvider messagesAtSection:oldSectionCount - 1].count;
    }

    [self.dataProvider addMessage:message];

    NSInteger newSectionCount = [self.dataProvider dateCount];
    BOOL newSectionAdded = (newSectionCount > oldSectionCount);
    NSInteger newLastSectionRowCount = (newSectionCount > 0) ? [self.dataProvider messagesAtSection:newSectionCount - 1].count : 0;

    if (newSectionAdded) {
        [UIView performWithoutAnimation:^{
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:newSectionCount - 1] withRowAnimation:UITableViewRowAnimationNone];
        }];
    } else if (newLastSectionRowCount > oldLastSectionRowCount) {
        NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
        for (NSInteger row = oldLastSectionRowCount; row < newLastSectionRowCount; row++) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:row inSection:newSectionCount - 1]];
        }
        [UIView performWithoutAnimation:^{
            [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        }];
    } else {
        // typing 替换等场景：刷新最后一行
        if (newSectionCount > 0 && newLastSectionRowCount > 0) {
            NSIndexPath *lastPath = [NSIndexPath indexPathForRow:newLastSectionRowCount - 1 inSection:newSectionCount - 1];
            [self.tableView reloadRowsAtIndexPaths:@[lastPath] withRowAnimation:UITableViewRowAnimationNone];
        }
    }

    [self didAddMessageUI];
}

-(void) removeMessage:(WKMessageModel*)message {
    [self.dataProvider removeMessage:message];
    [self.tableView reloadData];
}

-(void) didAddMessageUI{
    // 不再 reloadData，调用方已通过增量 insertRows 更新
    __weak typeof(self) weakSelf = self;
    
    if([self.dataProvider hasTyping]) {
        [weakSelf scrollToBottom:NO];
    }else{
        [self animateMessageWithBlock:^{
            [weakSelf scrollToBottom:NO];
            
        }];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
}


-(void) markReminderDoneIfNeed {
    NSArray<WKReminder*> *reminders = self.reminders;
    if(reminders && reminders.count>0) {
        NSMutableArray *ids = [NSMutableArray array];
        for (WKReminder *reminder  in reminders) {
            if(reminder.isLocate && reminder.done) {
                [ids addObject:@(reminder.reminderID)];
            }
        }
        [[WKSDK shared].reminderManager done:ids];
    }
    
}


- (void)loadMessages {
    __weak typeof(self) weakSelf = self;
    [self loadMessages:false firstLoad:YES complete:^{
        [weakSelf refreshNewMsgCount];
        // 消息加载完成后检查可见区域的@提醒，标记已读
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSArray<WKReminder *> *reminders = weakSelf.reminders;
            if (reminders && reminders.count > 0) {
                [weakSelf updatePostionReminders:reminders force:YES];
            }
        });
    }];
}

-(void) loadMessages:(BOOL)animation firstLoad:(BOOL)firstLoad complete:(void(^)(void))complete{
    __weak typeof(self) weakSelf = self;
    if(self.keepPosition) {
        [self enablePullup:YES];
    }else {
        [self enablePullup:NO];
    }
    [self.dataProvider pullFirst:self.keepPosition complete:^(bool hasMore) {
        [weakSelf handleLoadMessages:animation firstLoad:firstLoad hasMore:hasMore complete:complete];
    }];
}

-(void) handleLoadMessages:(BOOL)animation firstLoad:(BOOL)firstLoad hasMore:(bool)hasMore complete:(void(^)(void))complete {
    if (!self.tableView) return; // 防止 view 已释放后继续操作
    if(!hasMore) {
        [self pullupFinished];
        if(!self.keepPosition) {
            [self pulldownFinished];
        }
    }
    if(![self pullupHasMore]) { // 如果没有下方已到底，则禁用上拉
        [self pullupFinished];
    }
    [self updateOrInsertHistoryMsgSplitIfNeed]; // 插入历史消息风格线
    
    if(firstLoad) {
        WKMessage *typingMessage =  [[WKTypingManager shared] getTypingMessage:self.channel];
         if(typingMessage) {
             [self.dataProvider addTypingMessageIfNeed:[[WKMessageModel alloc] initWithMessage:typingMessage]];
         }
    }
    [self.tableView reloadData];
    
    if(!self.keepPosition) {
        [self scrollToBottom:animation];
    }else {
        NSIndexPath *indexPath = [self.dataProvider indexPathAtOrderSeq:self.keepPosition.orderSeq];
        if(!indexPath) {
            [self scrollToBottom:animation];
        } else {
            CGRect indexRect = [self.tableView rectForRowAtIndexPath:indexPath];
            [self setContentOffsetYSafely:indexRect.origin.y+self.keepPosition.offset - self.tableView.contentInset.top];
            if(self.needPositionReminder) {
                WKMessageBaseCell *cell =  (WKMessageBaseCell*) [self.tableView cellForRowAtIndexPath:indexPath];
                if(cell && [cell isKindOfClass:[WKMessageCell class]]) {
                    [(WKMessageCell*)cell startReminderAnimation];
                }
                self.needPositionReminder = false;
            }
        }
    }
    if(complete) {
        complete();
    }
    if(firstLoad) {
        [self calcPositionAtBottom];
        [self showScrollToBottomBarIfNeed];
    }
}

// 请求到最底部
-(void) pullBottom {
    if(![self pullupHasMore]) {
        [self pullupFinished];
        [self.tableView setContentOffset:self.tableView.contentOffset animated:NO]; // 立刻停止滚动
        [self scrollToBottom:YES];
        return;
    }
    self.keepPosition = nil;
    [self loadMessages:true firstLoad:false complete:nil];
  
}

- (void)scrollToBottom:(BOOL)animation {
   
    if(self.tableView.contentSize.height<= [self visiableTableHeight]) { // 如果内容高度小于或等于table的可示区域则不滚动
        return;
    }
    CGFloat adjustOffset = 0.01f; // TODO: 这里默认需要给个0.01f不能给0 要不然滚动条距离顶部有距离，这个不清楚原因
//    if(firstLoad) {
//        CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
//        adjustOffset = statusHeight; // 调整偏移
//    }
   
    if(animation) {
        [self animateMessageWithBlock:^{
            [self.tableView setContentOffset:CGPointMake(0, self.tableView.contentSize.height-self.tableView.lim_height+adjustOffset)];
        }];
    }else{
        [self.tableView setContentOffset:CGPointMake(0, self.tableView.contentSize.height-self.tableView.lim_height+adjustOffset)];
    }
}

-(void) setContentOffsetYSafely:(CGFloat)y {
    [self.tableView setContentOffset:CGPointMake(0, MAX(0, y))];
}

-(void) animateMessageWithBlock:(void(^)(void)) block completion:(void(^)(BOOL finished))completionBlock{
    [UIView animateWithDuration:SessionInputAnimateDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        block();
    } completion:completionBlock];
}

- (void)stopScrollingAnimation
{
    UIView *superview = self.tableView.superview;
    NSUInteger index = [self.tableView.superview.subviews indexOfObject:self.tableView];
    [self.tableView removeFromSuperview];
    [superview insertSubview:self.tableView atIndex:index];
}
-(void) animateMessageWithBlock:(void(^)(void)) block{
    [self animateMessageWithBlock:block completion:nil];
}

- (BOOL)insertedHistorySplit {
    if(self.insertedHistoryClientMsgNo && ![self.insertedHistoryClientMsgNo isEqualToString:@""]) {
        return true;
    }
    return false;
}

- (void)dealloc {
    WKLogDebug(@"%s",__func__);
    [self removeDelegates];
}

// 插入历史消息风格线
-(void) updateOrInsertHistoryMsgSplitIfNeed {
    if(self.browseToOrderSeq == 0) {
        return;
    }
    
    WKMessageModel *oldHistorySplitMsgModel;
    if(self.insertedHistorySplit) {
        NSIndexPath *indexPath = [self.dataProvider indexPathAtClientMsgNo:self.insertedHistoryClientMsgNo];
        if(indexPath) {
            oldHistorySplitMsgModel = [self.dataProvider messageAtIndexPath:indexPath];
        }
    }
    
    if(oldHistorySplitMsgModel) { // 更新分割线
        [self.dataProvider removeMessage:oldHistorySplitMsgModel];
        [self insertHistoryMsgSplitUI];
    }else { // 插入分割线
        [self insertHistoryMsgSplitUI];
    }
}

-(void) insertHistoryMsgSplitUI {
    NSIndexPath *browseToIndex =  [self.dataProvider indexPathAtOrderSeq:self.browseToOrderSeq];
     if(browseToIndex) {
         WKMessageModel *browseMessageModel = [self.dataProvider messageAtIndexPath:browseToIndex];
         if(browseMessageModel) {
             if(browseMessageModel.clientSeq != [self.dataProvider lastMessage].clientSeq) {
                 [self insertHistoryMsgSplitAtIndex:browseToIndex];
             }
         }
     }
}

-(void) insertHistoryMsgSplitAtIndex:(NSIndexPath*)indexPath {
    
//    WKMessageModel *browseToMessageModel = [self.conversationVM messageAtIndex:index];
    WKMessage *historySplitMessage = [[WKSDK shared].chatManager contentToMessage:WKHistorySplitTipContent.new channel:self.channel fromUid:@""];
    self.insertedHistoryClientMsgNo = historySplitMessage.clientMsgNo;
    [self.dataProvider insertMessage:[[WKMessageModel alloc] initWithMessage:historySplitMessage] atIndex:[NSIndexPath indexPathForRow:indexPath.row+1 inSection:indexPath.section]];
    [self.tableView reloadData];
}

- (NSArray<WKMessageModel *> *)getSelectedMessages {
    return [self.dataProvider getSelectedMessages];
}

-(WKConversationTableView*) tableView {
    if(!_tableView){
        _tableView = [[WKConversationTableView alloc] initWithFrame:CGRectMake(0.0f,0.0f,self.lim_width, self.lim_height) style:UITableViewStylePlain];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        _tableView.conversationTableDelegate = self;
//        _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.backgroundColor = [UIColor clearColor];
        [_tableView setTableFooterView:[UIView new]];
        _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
        [_tableView registerClass:[WKTimeHeaderView class] forHeaderFooterViewReuseIdentifier:[WKTimeHeaderView reuseId]];
        _tableView.contentInset = UIEdgeInsetsMake(0.01f, 0, 0, 0); // TODO: 这里要整个0.01 要不然scrollIndicatorInsets会偏移顶部，黑人问号❓
        _tableView.scrollIndicatorInsets = _tableView.contentInset;
        
        __weak typeof(self) weakSelf = self;
        
       //  MJRefreshNormalHeader
       MJRefreshNormalHeader *header = [MJRefreshNormalHeader headerWithRefreshingBlock:^{
               [weakSelf pulldown];
        }];
        header.lastUpdatedTimeLabel.hidden = YES;
        header.stateLabel.hidden = YES;
        header.arrowView.alpha = 0.0f;
        header.lim_height = 30.0f;
        _tableView.mj_header =  header;

        MJRefreshAutoNormalFooter *footer = [MJRefreshAutoNormalFooter footerWithRefreshingBlock:^{
            [weakSelf pullup];
        }];
        footer.refreshingTitleHidden = YES;
        footer.stateLabel.hidden  = YES;
        _tableView.mj_footer = footer;
        _tableView.mj_footer.hidden = YES;
        
        
    }
    return _tableView;
}
-(void) adjustTableWithOffset:(CGFloat)offset {
    self.tableView.lim_top = -offset;
//    CGFloat statusHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
    
    self.tableView.contentInset = UIEdgeInsetsMake(offset, 0, 0, 0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
}

-(void) enablePullup:(BOOL) enable {
    self.tableView.mj_footer.hidden = !enable;
   // [self adjustTable:false]; // mj_footer.hidden = YES 会导致table下移，这里调用adjustTable调整table
    [self adjustTableWithOffset:self.tableView.contentInset.top];
}

-(void) enablePullDown:(BOOL)enable {
    self.tableView.mj_header.hidden = !enable;
}

// 上拉完成
-(void) pullupFinished {
    [self enablePullup:NO];
}

// 下拉完成
-(void) pulldownFinished {
    [self enablePullDown:NO];
//    [self.conversationVM insertEndToEndEncryptHitMessageIfNeed];
}

-(void) pulldown {
    __weak typeof(self) weakSelf = self;

    // 标记 pulldown 进行中，阻止新消息并发修改 tableView
    self.isPulldownInProgress = YES;

    // 记录旧状态，用于增量插入
    NSInteger oldSectionCount = [self.dataProvider dateCount];
    NSInteger oldFirstSectionRowCount = 0;
    if (oldSectionCount > 0) {
        oldFirstSectionRowCount = [self.dataProvider messagesAtSection:0].count;
    }

    [self.dataProvider pulldown:^(bool hasMore) {
        if(!hasMore) {
            [weakSelf pulldownFinished];
        }

        NSInteger newSectionCount = [weakSelf.dataProvider dateCount];
        NSInteger newSectionsAdded = newSectionCount - oldSectionCount;

        // 旧的第一个 section 现在偏移到 newSectionsAdded 位置，检查是否新增了行
        NSInteger newRowsInOldFirstSection = 0;
        if (oldSectionCount > 0 && newSectionsAdded >= 0 && newSectionsAdded < newSectionCount) {
            NSInteger currentRowCount = [weakSelf.dataProvider messagesAtSection:newSectionsAdded].count;
            newRowsInOldFirstSection = currentRowCount - oldFirstSectionRowCount;
        }

        BOOL hasInsertions = (newSectionsAdded > 0 || newRowsInOldFirstSection > 0);

        if (hasInsertions) {
            // 记录当前可见位置
            NSIndexPath *firstVisible = weakSelf.tableView.indexPathsForVisibleRows.firstObject;
            CGFloat cellOffsetInView = 0;
            if (firstVisible) {
                CGRect cellRect = [weakSelf.tableView rectForRowAtIndexPath:firstVisible];
                cellOffsetInView = cellRect.origin.y - weakSelf.tableView.contentOffset.y;
            }
            NSIndexPath *targetAfterReload = nil;
            if (firstVisible) {
                NSInteger newSection = firstVisible.section + newSectionsAdded;
                NSInteger newRow = firstVisible.row;
                if (firstVisible.section == 0) {
                    newRow += newRowsInOldFirstSection;
                }
                targetAfterReload = [NSIndexPath indexPathForRow:newRow inSection:newSection];
            }

            // 收集需要预计算的消息
            NSMutableArray<WKMessageModel*> *newMsgs = [NSMutableArray array];
            for (NSInteger s = 0; s < newSectionsAdded; s++) {
                NSArray *msgs = [weakSelf.dataProvider messagesAtSection:s];
                [newMsgs addObjectsFromArray:msgs];
            }
            if (newRowsInOldFirstSection > 0) {
                NSArray *msgs = [weakSelf.dataProvider messagesAtSection:newSectionsAdded];
                for (NSInteger r = 0; r < newRowsInOldFirstSection && r < (NSInteger)msgs.count; r++) {
                    [newMsgs addObject:msgs[r]];
                }
            }

            // 清除边界消息的高度缓存
            NSInteger boundarySection = newSectionsAdded;
            NSArray *boundaryMsgs = (boundarySection < newSectionCount) ? [weakSelf.dataProvider messagesAtSection:boundarySection] : @[];
            if (boundaryMsgs.count > (NSUInteger)newRowsInOldFirstSection) {
                WKMessageModel *boundaryMsg = boundaryMsgs[newRowsInOldFirstSection];
                if (boundaryMsg.clientMsgNo.length > 0) {
                    [[WKMessageListView cellHeightCache] removeObjectForKey:boundaryMsg.clientMsgNo];
                }
            }

            // 后台线程预计算高度，完成后回主线程刷新 UI
            NSIndexPath *targetCopy = targetAfterReload;
            CGFloat offsetCopy = cellOffsetInView;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                CFAbsoluteTime t_precache = CFAbsoluteTimeGetCurrent();
                for (WKMessageModel *msg in newMsgs) {
                    [weakSelf precacheHeightForMessage:msg];
                }
                CGFloat precacheMs = (CFAbsoluteTimeGetCurrent() - t_precache) * 1000;

                dispatch_async(dispatch_get_main_queue(), ^{
                    CFAbsoluteTime t_reload = CFAbsoluteTimeGetCurrent();
                    [UIView performWithoutAnimation:^{
                        [weakSelf.tableView reloadData];
                        [weakSelf.tableView layoutIfNeeded];
                    }];

                    if (targetCopy) {
                        [UIView performWithoutAnimation:^{
                            CGRect targetRect = [weakSelf.tableView rectForRowAtIndexPath:targetCopy];
                            weakSelf.tableView.contentOffset = CGPointMake(0, targetRect.origin.y - offsetCopy);
                        }];
                    }
                    CGFloat reloadMs = (CFAbsoluteTimeGetCurrent() - t_reload) * 1000;
                    NSLog(@"[Perf] pulldown: %lu msgs | precache=%.1fms(bg) reload=%.1fms(main)", (unsigned long)newMsgs.count, precacheMs, reloadMs);

                    [weakSelf.tableView.mj_header endRefreshing];
                    weakSelf.isPulldownInProgress = NO;
                    [weakSelf processPendingRecvMessages];
                });
            });
        } else {
            [weakSelf.tableView.mj_header endRefreshing];
            weakSelf.isPulldownInProgress = NO;
            [weakSelf processPendingRecvMessages];
        }
    }];

}

-(void) pullup {
    [self pullup:nil];
}

-(void) pullup:(void(^)(bool more))complete {
    __weak typeof(self) weakSelf = self;

    NSInteger oldSectionCount = [self.dataProvider dateCount];
    NSInteger oldLastSectionRowCount = 0;
    if (oldSectionCount > 0) {
        oldLastSectionRowCount = [self.dataProvider messagesAtSection:oldSectionCount - 1].count;
    }

    [self.dataProvider pullup:^(bool hasMore) {
        if(!hasMore) {
            [weakSelf pullupFinished];
        }else {
            [weakSelf enablePullup:YES];
        }

        NSInteger newSectionCount = [weakSelf.dataProvider dateCount];
        NSInteger newSectionsAdded = newSectionCount - oldSectionCount;

        NSMutableArray<WKMessageModel *> *newMsgs = [NSMutableArray array];
        if (newSectionsAdded > 0) {
            if (oldSectionCount > 0) {
                NSInteger oldSectionNewRowCount = [weakSelf.dataProvider messagesAtSection:oldSectionCount - 1].count;
                for (NSInteger r = oldLastSectionRowCount; r < oldSectionNewRowCount; r++) {
                    [newMsgs addObject:[weakSelf.dataProvider messagesAtSection:oldSectionCount - 1][r]];
                }
            }
            for (NSInteger s = oldSectionCount; s < newSectionCount; s++) {
                [newMsgs addObjectsFromArray:[weakSelf.dataProvider messagesAtSection:s]];
            }
        } else if (newSectionCount > 0) {
            NSInteger newLastSectionRowCount = [weakSelf.dataProvider messagesAtSection:newSectionCount - 1].count;
            for (NSInteger r = oldLastSectionRowCount; r < newLastSectionRowCount; r++) {
                [newMsgs addObject:[weakSelf.dataProvider messagesAtSection:newSectionCount - 1][r]];
            }
        }

        if (newMsgs.count > 0) {
            // 后台预计算高度，完成后回主线程插入行
            NSInteger newSectionsAddedCopy = newSectionsAdded;
            NSInteger oldSectionCountCopy = oldSectionCount;
            NSInteger oldLastSectionRowCountCopy = oldLastSectionRowCount;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                CFAbsoluteTime t_precache = CFAbsoluteTimeGetCurrent();
                for (WKMessageModel *msg in newMsgs) {
                    [weakSelf precacheHeightForMessage:msg];
                }
                CGFloat precacheMs = (CFAbsoluteTimeGetCurrent() - t_precache) * 1000;

                dispatch_async(dispatch_get_main_queue(), ^{
                    CFAbsoluteTime t_insert = CFAbsoluteTimeGetCurrent();
                    [UIView performWithoutAnimation:^{
                        @try {
                            [weakSelf.tableView beginUpdates];

                            if (newSectionsAddedCopy > 0) {
                                if (oldSectionCountCopy > 0) {
                                    NSInteger oldSectionNewRowCount = [weakSelf.dataProvider messagesAtSection:oldSectionCountCopy - 1].count;
                                    if (oldSectionNewRowCount > oldLastSectionRowCountCopy) {
                                        NSMutableArray<NSIndexPath *> *rowPaths = [NSMutableArray array];
                                        for (NSInteger r = oldLastSectionRowCountCopy; r < oldSectionNewRowCount; r++) {
                                            [rowPaths addObject:[NSIndexPath indexPathForRow:r inSection:oldSectionCountCopy - 1]];
                                        }
                                        [weakSelf.tableView insertRowsAtIndexPaths:rowPaths withRowAnimation:UITableViewRowAnimationNone];
                                    }
                                }
                                NSIndexSet *sectionSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(oldSectionCountCopy, newSectionsAddedCopy)];
                                [weakSelf.tableView insertSections:sectionSet withRowAnimation:UITableViewRowAnimationNone];
                            } else {
                                NSInteger newSC = [weakSelf.dataProvider dateCount];
                                if (newSC > 0) {
                                    NSInteger newLastSectionRowCount = [weakSelf.dataProvider messagesAtSection:newSC - 1].count;
                                    if (newLastSectionRowCount > oldLastSectionRowCountCopy) {
                                        NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
                                        for (NSInteger r = oldLastSectionRowCountCopy; r < newLastSectionRowCount; r++) {
                                            [indexPaths addObject:[NSIndexPath indexPathForRow:r inSection:newSC - 1]];
                                        }
                                        [weakSelf.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
                                    }
                                }
                            }

                            [weakSelf.tableView endUpdates];
                        } @catch (NSException *exception) {
                            [weakSelf.tableView reloadData];
                        }
                    }];
                    CGFloat insertMs = (CFAbsoluteTimeGetCurrent() - t_insert) * 1000;
                    NSLog(@"[Perf] pullup: %lu msgs | precache=%.1fms(bg) insert=%.1fms(main)", (unsigned long)newMsgs.count, precacheMs, insertMs);

                    [weakSelf.tableView.mj_footer endRefreshing];
                    if(complete) {
                        complete(hasMore);
                    }
                });
            });
        } else {
            [weakSelf.tableView.mj_footer endRefreshing];

            // 去重跳过后重试
            if(hasMore && newMsgs.count == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf pullup:complete];
                });
                return;
            }

            if(complete) {
                complete(hasMore);
            }
        }
    }];
}

// 上拉是否还有更多
-(BOOL) pullupHasMore {
    if(!self.lastMessage) {
        return false;
    }
    WKMessageModel *currentLastMsgModel = [self.dataProvider lastMessage];
    NSString *currentLastClientMsgNo = @"";
    if(currentLastMsgModel) {
        if(currentLastMsgModel.contentType == WK_TYPING) {
            if(currentLastMsgModel.preMessageModel) {
                currentLastClientMsgNo = currentLastMsgModel.preMessageModel.clientMsgNo;
            } else {
                return false;
            }
        }else {
            currentLastClientMsgNo = currentLastMsgModel.clientMsgNo;
        }
       
    } else {
        return false;
    }
    if(![self.lastMessage.clientMsgNo isEqualToString:currentLastClientMsgNo]) {
        return true;
    }
    return false;
}


// 更新已读消息的orderSeq
-(void) updateBrowseToOrderSeq {
    if(self.browseToOrderSeq == 0) {
        return;
    }
    BOOL change = false;
    NSIndexPath *lastVisibleIndexPath =  [self lastVisibleIndexPath];
    if(lastVisibleIndexPath) {
        WKMessageModel *lastVisibleMessageModel = [self.dataProvider messageAtIndexPath:lastVisibleIndexPath];
        if(lastVisibleMessageModel && lastVisibleMessageModel.orderSeq>self.browseToOrderSeq) {
            self.browseToOrderSeq = lastVisibleMessageModel.orderSeq;
            change = true;
        }
    }
    if(change) {
        [self refreshNewMsgCount];
    }
}

// 更新位置
-(void) updatePosition {
    
    if([self.dataProvider messageCount] == 0) {
        self.keepPosition = nil;
        return;
    }
    
    if(self.lastMessage && [self messageIsVisible:self.lastMessage.clientMsgNo]) { // 最后一条消息可见 说明到底了
        self.keepPosition = nil;
        return;
    }
    
    NSIndexPath *firstIndexPath = [self firstVisibleIndexPath];
    if(!firstIndexPath) {
        return;
    }
    WKMessageModel *firstMessageModel = [self.dataProvider messageAtIndexPath:firstIndexPath];
    if(firstMessageModel.messageSeq == 1) { // 等于1表示阅读到最后一条消息了 下次进来滚到到底部
        self.keepPosition = nil;
        return;
    }
    
    CGRect firstRect = [self.tableView rectForRowAtIndexPath:firstIndexPath];
    uint32_t firstVisibleOrderSeq = [self.dataProvider messageAtIndexPath:firstIndexPath].orderSeq;

    CGFloat offset =  self.tableView.contentOffset.y  - firstRect.origin.y;
    
    self.keepPosition = [WKConversationPosition orderSeq:firstVisibleOrderSeq offset:offset];
}


-(CGFloat) statusOffsetY {
    
    return [UIApplication sharedApplication].statusBarFrame.size.height;
}
// 消息是否可见
-(BOOL) messageIsVisible:(NSString*)clientMsgNo {
    NSArray<NSIndexPath*> *visibleRows = [self.tableView indexPathsForVisibleRows];
    if(visibleRows && visibleRows.count>0) {
        for (NSIndexPath *indexPath in visibleRows) {
           WKMessageModel *visibleMessage = [self.dataProvider messageAtIndexPath:indexPath];
            if([clientMsgNo isEqualToString:visibleMessage.clientMsgNo]) {
                return [self cellIsVisible: [self.tableView rectForRowAtIndexPath:indexPath]];
            }
        }
    }
    return  false;
}

-(void) refreshNewMsgCount {
    NSInteger oldMsgCount = self.newMsgCount;
    if(self.browseToOrderSeq == 0) {
        self.newMsgCount = 0;
    }else if(!self.lastMessage) { // 没有给定最新的消息 没办法算未读数量
        self.newMsgCount = 0;
    }else if(self.lastMessage.isSend) { // 如果最后一条消息是自己发的 则新消息数量为0
        self.browseToOrderSeq = self.lastMessage.orderSeq;
        self.newMsgCount = 0;
    }else if(self.lastMessage.orderSeq<=self.browseToOrderSeq) { // 如果最新消息的序号小于或等于预览到的 则最新消息为0
        self.newMsgCount = 0;
    }else {
        uint32_t lastMessageSeq = self.lastMessage.messageSeq;
        uint32_t browseToMessageSeq = [[WKSDK shared].chatManager getOrNearbyMessageSeq:self.browseToOrderSeq];
         
        if(lastMessageSeq>browseToMessageSeq) {
            self.newMsgCount = lastMessageSeq - browseToMessageSeq;
        }
    }
    [self handleNewMsgCountChange];
    if(oldMsgCount!=self.newMsgCount){
        [self refreshConversationListNewCount];
    }
   
}

// 刷新最近会话的新消息数量
-(void) refreshConversationListNewCount {
   WKConversationWrapModel *model = [[WKConversationListVM shared] modelAtChannel:self.channel];
    if(model) {
        model.unreadCount = self.newMsgCount;
        [[WKSDK shared].conversationManager callOnConversationUpdateDelegate:[model getConversation]];
    }
    // 立即同步到服务器和本地 DB，防止用户按 Home 键或杀 app 时未读状态丢失
    uint32_t messageSeq = self.lastMessage ? self.lastMessage.messageSeq : 0;
    [[WKMessageManager shared] conversationSetUnread:self.channel unread:self.newMsgCount messageSeq:messageSeq complete:nil];
    [[WKSDK shared].conversationManager setConversationUnreadCount:self.channel unread:self.newMsgCount];
}


// 第一条可见的cell indexPath
-(NSIndexPath*) firstVisibleIndexPath {
    NSArray *indexPaths  = self.tableView.indexPathsForVisibleRows;
    if(indexPaths && indexPaths.count>0) {
        for (NSIndexPath *indexPath in indexPaths) {
            CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
            if([self cellIsVisible:rect]) {
                return indexPath;
            }
        }
    }
    return nil;
}
// 最后一条可见的cell indexPath
-(NSIndexPath*) lastVisibleIndexPath {
    NSArray *indexPaths  = self.tableView.indexPathsForVisibleRows;
    if(indexPaths && indexPaths.count>0) {
        for (NSInteger i=indexPaths.count-1; i>=0; i--) {
            NSIndexPath *indexPath = indexPaths[i];
            CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
            if([self cellIsVisible:rect]) {
                return indexPath;
            }
        }
    }
    return nil;
    
}

// 获取消息cell的class
-(Class) getMessageCellClass:(WKMessageModel*) messageModel {
    if(messageModel.revoke) {
        return WKMessageRevokeCell.class;
    }
    Class  messageCellClass =  [[WKApp shared].messageRegitry getMessageCell:messageModel.contentType];
    
    return messageCellClass;
}

- (void)didReadedAndViewed {
    NSArray<NSIndexPath*> *visibleRows = [self.tableView indexPathsForVisibleRows];
    if(visibleRows && visibleRows.count>0) {
        NSMutableArray<WKMessageModel*> *messagesOfReaded = [NSMutableArray array];
        NSMutableArray<WKMessage*> *messagesOfViewed = [NSMutableArray array];
        for (NSIndexPath *indexPath in visibleRows) {
            CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
            if([self cellIsVisible:rect]) {
                WKMessageModel *messageModel = [self.dataProvider messageAtIndexPath:indexPath];
                 if(messageModel.messageId != 0 && !messageModel.isSend && !messageModel.readed && messageModel.message.setting.receiptEnabled) {
                     [messagesOfReaded addObject:messageModel];
                 }
                if(messageModel.content.flame && messageModel.content.viewedOfVisible && !messageModel.viewed) {
                    [messagesOfViewed addObject:messageModel.message];
                }
            }
        }
        if(messagesOfReaded.count>0) {
            [self.dataProvider didReaded:messagesOfReaded];
        }
        if(messagesOfViewed.count>0) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [WKSDK.shared.flameManager didViewed:messagesOfViewed];
            });
           
        }
    }
}


// cell是否在可见范围内
-(BOOL) cellIsVisible:(CGRect)cellRect {
    CGFloat offset = cellRect.origin.y - (self.tableView.contentOffset.y + self.tableView.contentInset.top);
    if(offset<[self visiableTableHeight] && offset > -cellRect.size.height) {
        return  true;
    }
    return false;
}

// table的可视区域
-(CGFloat) visiableTableHeight {
    return self.tableView.lim_height-self.tableView.contentInset.top - self.tableView.contentInset.bottom;
    
}


-(void) locateMessageCellWithOrderSeqForReminder:(uint32_t)orderSeq tablePosition:(UITableViewScrollPosition)tablePosition{
    if(orderSeq == 0) {
        return;
    }
    NSIndexPath *locatMessagePath; // 定位到的消息下表
    locatMessagePath = [self.dataProvider indexPathAtOrderSeq:orderSeq];
    WKMessageModel *locatMessageModel; // 定位到的消息对象
    if(locatMessagePath) {
        locatMessageModel = [self.dataProvider messageAtIndexPath:locatMessagePath];
    }
    [self startReminderAnimation];
    if(locatMessageModel) { // 说明本地有这条消息,滚动到这条消息即可
        [self scrollToIndex:locatMessagePath animated:YES atScrollPosition:tablePosition];
        return;
    }
    
    [[WKConversationPositionManager shared] removePositions:self.channel type:WKConversationPositionTypeUnreadFirst];
    [[WKConversationPositionManager shared] channel:self.channel position:[WKConversationPosition orderSeq:orderSeq offset:0]];
    
    self.keepPosition = [WKConversationPosition orderSeq:orderSeq offset:0];
    
    __weak typeof(self) weakSelf = self;
    [self loadMessages:true firstLoad:false complete:^{
        [weakSelf startReminderAnimation];
        NSIndexPath *browseToIndex =  [weakSelf.dataProvider indexPathAtOrderSeq:orderSeq];
        if(browseToIndex) {
            [weakSelf scrollToIndex:browseToIndex animated:YES atScrollPosition:tablePosition];
        }
    }];
}


-(void) startReminderAnimation {
    NSArray<WKReminder*> *reminders = self.reminders;
    if(reminders && reminders.count>0) {
        __weak typeof(self) weakSelf = self;
        [self.tableView performBatchUpdates:^{
            NSMutableArray *indexPaths = [NSMutableArray array];
            for (WKReminder *reminder in reminders) {
                if(reminder.isLocate && !reminder.done) {
                    uint32_t orderSeq = [[WKSDK shared].chatManager getOrderSeq:reminder.messageSeq];
                    NSIndexPath *indexPath = [weakSelf.dataProvider indexPathAtOrderSeq:orderSeq];
                    if(indexPath) {
                        [indexPaths addObject:indexPath];
                    }
                }
            }
            if(indexPaths.count>0) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    for (NSIndexPath *indexPath in indexPaths) {
                        WKMessageBaseCell *cell =  (WKMessageBaseCell*) [weakSelf.tableView cellForRowAtIndexPath:indexPath];
                        if(cell && [cell isKindOfClass:[WKMessageCell class]]) {
                            [(WKMessageCell*)cell startReminderAnimation];
                        }
                    }
                   // [weakSelf.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
                });
                
            }
        } completion:nil];
        
    }
    
}

-(void) scrollToIndex:(NSIndexPath*)indexPath {
    [self scrollToIndex:indexPath animated:NO];
}


-(void) scrollToIndex:(NSIndexPath*)indexPath animated:(BOOL)animated{
    if (index >= 0) {
        [self scrollToIndex:indexPath animated:animated atScrollPosition:UITableViewScrollPositionTop];
   }
}
-(void) scrollToIndex:(NSIndexPath*)indexPath animated:(BOOL)animated atScrollPosition:(UITableViewScrollPosition)atScrollPosition{
    if (indexPath) {
        [self.tableView beginUpdates];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:atScrollPosition animated:animated];
        [self.tableView endUpdates];
   }
}


-(void) setFloatingHeaderViewsHidden:(BOOL)hidden animated:(BOOL)animated delay:(NSTimeInterval)delay {
    if(self.headerViewsAnimator) {
        [self.headerViewsAnimator stopAnimation:YES];
        if (@available(iOS 10.0, *)) {
            [self.headerViewsAnimator finishAnimationAtPosition:UIViewAnimatingPositionCurrent];
        } else {
            // Fallback on earlier versions
        }
    }
    __weak typeof(self) weakSelf = self;
    if(animated) {
        if (@available(iOS 10.0, *)) {
            self.headerViewsAnimator = [[UIViewPropertyAnimator alloc] initWithDuration:0.3 curve:UIViewAnimationCurveLinear animations:^{
                [weakSelf setFloatingHeaderViewsHidden:hidden];
            }];
            [self.headerViewsAnimator startAnimationAfterDelay:delay];
        } else {
            // Fallback on earlier versions
        }
       
    }else{
       
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [weakSelf setFloatingHeaderViewsHidden:hidden];
        });
    }
}


-(void) setFloatingHeaderViewsHidden:(BOOL)hidden {
    NSMutableArray<NSNumber*> *visibleSections = [self indicesForVisibleSectionHeaders];
    NSInteger firstVisibleSection = -1;
    if(hidden) {
        
        UITableViewHeaderFooterView *firstVisibleHeaderView;
        for (NSNumber *visibleSection in visibleSections) {
           UITableViewHeaderFooterView *headerView= [self.tableView headerViewForSection:visibleSection.integerValue];
            if(headerView.frame.origin.y + headerView.lim_height>=self.tableView.contentOffset.y+self.tableView.contentInset.top) {
                firstVisibleSection  = visibleSection.integerValue;
                firstVisibleHeaderView = headerView;
                break;
            }
        }
        if(firstVisibleHeaderView) {
            CGRect fixedRect = [self.tableView rectForHeaderInSection:firstVisibleSection];
            CGRect actualRect = firstVisibleHeaderView.frame;
            if(ABS(fixedRect.origin.y - actualRect.origin.y)>1) {
                firstVisibleHeaderView.alpha = 0;
            }
        }
    }
    for (NSNumber *section in visibleSections) {
        if(section.integerValue == firstVisibleSection) {
            continue;
        }
        UITableViewHeaderFooterView *header = [self.tableView headerViewForSection:section.integerValue];
        header.alpha = 1.0f;
    }
}
// 获取可见的header的index
-(NSMutableArray<NSNumber*>*) indicesForVisibleSectionHeaders {
    NSArray<NSIndexPath*> *indexPaths= [self.tableView indexPathsForVisibleRows];
    NSMutableSet *sets = [[NSMutableSet alloc] init];
    if(indexPaths.count>0) {
        for (NSIndexPath *indexPath in indexPaths) {
            [sets addObject:@(indexPath.section)];
        }
    }
    NSMutableArray<NSNumber*> *items = [NSMutableArray array];
    for (NSNumber *number in sets) {
        [items addObject:number];
    }
    [items sortUsingComparator:^NSComparisonResult(NSNumber   *obj1, NSNumber  *obj2) {
        return obj1.intValue>obj2.intValue;
    }];
    return items;
    
}

// 结束滚动
-(void) endScroll:(UIScrollView*)scrollView {
    self.scrolling = false;
}

- (void)reloadData {
    [self.tableView reloadData];

}

// 设置多选模式
-(void) setMultipleOn:(BOOL)multiple selectedMessage:(WKMessageModel * _Nullable)messageModel {
    self.multipleOn = multiple;
    // 先取消所有选中的
    [self cancelAllSelected];
    
    __weak typeof(self) weakSelf = self;
    if(multiple) {
        if(messageModel && messageModel.contentType != WK_TYPING) {
            messageModel.checked = YES;
        }
    }
    
    // checkBox动画
    [self visiableCellAnimatioCheckBoxShow:multiple];
    // checBox动画后才reloadData 如果不这样动画会被盖掉
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf reloadData];
    });
}


// 取消所有被选中的
-(void) cancelAllSelected {
    [self.dataProvider cancelSelectedMessages];
    NSArray *visibleCells =  [self visibleCells];
    if(visibleCells) {
        for (WKMessageBaseCell *baseCell in visibleCells) {
            if([baseCell isKindOfClass:[WKMessageCell class]]) {
                WKMessageCell *messageCell = (WKMessageCell*)baseCell;
                [messageCell.checkBox setOn:NO];
            }
        }
    }
}
-(void) visiableCellAnimatioCheckBoxShow:(BOOL)show {
    NSArray *visibleCells =  [self visibleCells];
    if(visibleCells) {
        for (WKMessageBaseCell *baseCell in visibleCells) {
            if([baseCell isKindOfClass:[WKMessageCell class]]) {
                WKMessageCell *messageCell = (WKMessageCell*)baseCell;
                messageCell.showCheckBox = show;
                [messageCell animationCheckBox:show];
            }
        }
    }
}

-(NSArray<WKMessageModel*>*) getMessagesWithContentType:(NSInteger)contentType {
    return [self.dataProvider getMessagesWithContentType:contentType];
}

- (NSArray<NSString *> *)dates {
    return [self.dataProvider dates];
}

-(NSArray<WKMessageModel*>*) messagesAtDate:(NSString*)date {
    return [self.dataProvider messagesAtDate:date];
}

/**
 获取可见的指定下标的cell

 */
-(UITableViewCell*) cellForRowAtIndex:(NSIndexPath*)indexPath {
    return [self.tableView cellForRowAtIndexPath:indexPath];
}


-(void) refreshCell:(WKMessageModel*) messageModel {

    NSIndexPath *indexPath =  [self.dataProvider replaceMessage:messageModel atClientMsgNo:messageModel.message.clientMsgNo];
    if(indexPath) {
        WKMessageBaseCell *cell = (WKMessageBaseCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        [cell refresh:messageModel];
        // TODO: 应该不需要执行 reloadRowsAtIndexPaths 音频消息播放的时候会大量执行reloadRowsAtIndexPaths导致卡顿
//        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }else {
        [self.dataProvider addMessage:messageModel];
        [self.tableView reloadData];
        [self animateMessageWithBlock:^{
            [self scrollToBottom:NO];
        }];
    }
}

-(void) locateMessageCellWithMessageSeq:(uint32_t )messageSeq {
   

    BOOL visible = false; // 消息是否在可见
    NSIndexPath *locatMessagePath; // 定位到的消息下表
    WKMessageModel *locatMessageModel; // 定位到的消息对象
    
    locatMessagePath = [self.dataProvider indexPathAtOrderSeq:[WKSDK.shared.chatManager getOrderSeq:messageSeq]];
    if(locatMessagePath) {
        locatMessageModel = [self.dataProvider messageAtIndexPath:locatMessagePath];
    }
    if(locatMessageModel!=nil) {
        visible = [self cellIsVisible:[self.tableView rectForRowAtIndexPath:locatMessagePath]];
    }
    
    if(visible) { // 如果消息在可见范围内 则直接播提醒动画
        locatMessageModel.reminderAnimation = YES;
        [self.tableView reloadRowsAtIndexPaths:@[locatMessagePath] withRowAnimation:UITableViewRowAnimationNone];
        return;
    }
    
    if(locatMessageModel) {
        __weak typeof(self) weakSelf = self;
        [self scrollToIndex:locatMessagePath animated:YES atScrollPosition:UITableViewScrollPositionMiddle];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            locatMessageModel.reminderAnimation = YES;
            [weakSelf.tableView beginUpdates];
            [weakSelf.tableView reloadRowsAtIndexPaths:@[locatMessagePath] withRowAnimation:UITableViewRowAnimationNone];
            [weakSelf.tableView endUpdates];
        });
       
        return;
    }
    
    // 查DB确认消息是否存在且可用（未删除、未撤回），不可用则直接提示
    WKMessage *targetMsg = [[WKMessageDB shared] getMessage:self.channel messageSeq:messageSeq];
    if(!targetMsg || targetMsg.isDeleted || targetMsg.remoteExtra.revoke) {
        [self.tableView showHUDWithHide:LLang(@"原消息不存在")];
        return;
    }

    self.keepPosition = [WKConversationPosition orderSeq:[[WKSDK shared].chatManager getOrderSeq:messageSeq] offset:0];

    __weak typeof(self) weakSelf = self;
    [self loadMessages:true firstLoad:false complete:^{
        NSIndexPath *browseToIndex = [weakSelf.dataProvider indexPathAtOrderSeq:[WKSDK.shared.chatManager getOrderSeq:messageSeq]];
        if(browseToIndex) {
             WKMessageModel *messageModel = [weakSelf.dataProvider messageAtIndexPath:browseToIndex];
            [weakSelf scrollToIndex:browseToIndex animated:YES atScrollPosition:UITableViewScrollPositionMiddle];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                messageModel.reminderAnimation = YES;
                [weakSelf.tableView beginUpdates];
                [weakSelf.tableView reloadRowsAtIndexPaths:@[browseToIndex] withRowAnimation:UITableViewRowAnimationNone];
                [weakSelf.tableView endUpdates];
            });
        }
    }];
    
 //    [self.conversationVM clearMessages];
 //    __weak typeof(self) weakSelf = self;
 //    [self.conversationVM pullAtLocation:destMessage.orderSeq complete:^(bool hasMore) {
 //        if(!hasMore) {
 //            weakSelf.tableView.mj_header.hidden = YES;
 //        }
 //
 //        [weakSelf.tableView reloadData];
 //        [weakSelf.tableView.mj_header endRefreshing];
 //
 //
 //
 //        // 判断是否启用pullup
 //        WKMessageModel *lastMessageModel = [self.conversationVM lastMessageModel];
 //        if(lastMessageModel && weakSelf.conversationVM.conversation.lastMessage && lastMessageModel.clientSeq == weakSelf.conversationVM.conversation.lastMessage.clientSeq) {
 //            [self enablePullup:NO];
 //        }else{
 //            [self enablePullup:YES];
 //        }
 //    }];
}

// 定位到指定消息
-(void) locateMessageCell:(uint32_t)messageSeq{
    if(messageSeq == 0) {
        return;
    }
    [self locateMessageCellWithMessageSeq:messageSeq];
}

// 是否需要处理消息
-(BOOL) needHandle:(WKMessage*)message {
    if(![message.channel isEqual:self.channel]) {
        return false;
    }
    if(message.contentType == WK_CMD) { // 命令类消息不处理
        return false;
    }
    if(message.contentType == WK_VIDEOCALL_DATA) { // 音视频数据传输类的消息不处理
        return false;
    }
   
    return true;
}

// 判断消息是否应在当前空间显示（所有个人聊天在多空间模式下按space_id过滤）
-(BOOL) shouldShowMessageInCurrentSpace:(WKMessage*)message {
    if(self.channel.channelType != WK_PERSON) {
        return YES;
    }
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(!currentSpaceId || currentSpaceId.length == 0) {
        return YES;
    }
    NSString *msgSpaceId = message.content.contentDict[@"space_id"];
    if(!msgSpaceId || [msgSpaceId isKindOfClass:[NSNull class]] || ([msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length == 0)) {
        return YES; // 无space_id的历史消息，所有空间可见
    }
    return [msgSpaceId isEqualToString:currentSpaceId];
}

-(void) handleRecvMessage:(WKMessage*) message  {
    if(message.isDeleted) { // 已删除的消息不处理
        return;
    }

    // pulldown 进行中，暂存新消息避免并发修改 tableView 导致布局错乱
    if(self.isPulldownInProgress) {
        if(!self.pendingRecvMessages) {
            self.pendingRecvMessages = [NSMutableArray array];
        }
        [self.pendingRecvMessages addObject:message];
        return;
    }

    if(![message isSend]) {
        self.hasRecvMsg = true;
    }
    WKMessageModel *messageModel = [[WKMessageModel alloc] initWithMessage:message];
    if([self pullupHasMore]) { // 消息没有完全加载完成
        [self updateLastMsgIfNeed:messageModel];
        if( [message isSend]) {
            [self  pullBottom];
        }
    } else {
        [self updateLastMsgIfNeed:messageModel];

        // 预缓存高度（触发 markdown 渲染），避免在 UITableView 布局回调中首次渲染
        [self precacheHeightForMessage:messageModel];

        // 快照 addMessage 前后的 section/row 数量，按实际变化增量更新
        NSInteger oldSectionCount = [self.dataProvider dateCount];
        NSInteger oldLastSectionRowCount = 0;
        if (oldSectionCount > 0) {
            oldLastSectionRowCount = [self.dataProvider messagesAtSection:oldSectionCount - 1].count;
        }

        [self.dataProvider addMessage:messageModel];

        NSInteger newSectionCount = [self.dataProvider dateCount];
        BOOL newSectionAdded = (newSectionCount > oldSectionCount);
        NSInteger newLastSectionRowCount = (newSectionCount > 0) ? [self.dataProvider messagesAtSection:newSectionCount - 1].count : 0;

        if (newSectionAdded) {
            // 新日期分组：插入整个 section
            [UIView performWithoutAnimation:^{
                [self.tableView insertSections:[NSIndexSet indexSetWithIndex:newSectionCount - 1] withRowAnimation:UITableViewRowAnimationNone];
            }];
        } else if (!newSectionAdded && newLastSectionRowCount > oldLastSectionRowCount) {
            // 同日期且行数增加：在末尾插入新行
            NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
            for (NSInteger row = oldLastSectionRowCount; row < newLastSectionRowCount; row++) {
                [indexPaths addObject:[NSIndexPath indexPathForRow:row inSection:newSectionCount - 1]];
            }
            [UIView performWithoutAnimation:^{
                [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
            }];
        } else {
            // typing 替换/丢弃等场景：行数不变，刷新最后一行即可
            if (newSectionCount > 0 && newLastSectionRowCount > 0) {
                NSIndexPath *lastPath = [NSIndexPath indexPathForRow:newLastSectionRowCount - 1 inSection:newSectionCount - 1];
                [self.tableView reloadRowsAtIndexPaths:@[lastPath] withRowAnimation:UITableViewRowAnimationNone];
            }
        }

        if(self.positionAtBottom) {
            [self scrollToBottom:YES];
        }else{
            if( [message isSend]) {
                [self scrollToBottom:YES];
            }
        }
    }
}

// pulldown 完成后，统一处理暂存的新消息
-(void) processPendingRecvMessages {
    if(!self.pendingRecvMessages || self.pendingRecvMessages.count == 0) {
        return;
    }
    NSArray<WKMessage*> *pending = [self.pendingRecvMessages copy];
    [self.pendingRecvMessages removeAllObjects];
    for(WKMessage *msg in pending) {
        [self handleRecvMessage:msg];
    }
}

//通过删除然后插入的方式更新cell
-(void) refreshCellForDeleteAndInsert:(WKMessageModel*) messageModel {
    
    NSIndexPath *indexPath =  [self.dataProvider replaceMessage:messageModel atClientMsgNo:messageModel.clientMsgNo];
    if(indexPath) {
        WKMessageBaseCell *cell = (WKMessageBaseCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        [cell refresh:messageModel];
        if (@available(iOS 11.0, *)) {
            [self.tableView performBatchUpdates:^{
                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            } completion:nil];
        }
        
    }else {
        [self.dataProvider addMessage:messageModel];
        [self.tableView reloadData];
        [self animateMessageWithBlock:^{
            [self scrollToBottom:NO];
        }];
    }
}

- (void)setLastMessage:(WKMessageModel *)lastMessage {
    [self updateLastMsgIfNeed:lastMessage];
}

- (WKMessageModel *)lastMessage {
    return self.lastMessageInner;
}

-(BOOL) updateLastMsgIfNeed:(WKMessageModel*)messageModel {
    bool change = false;
    if(!self.lastMessageInner) {
        self.lastMessageInner = messageModel;
        change = true;
    }else if(self.lastMessageInner.orderSeq<messageModel.orderSeq){
        self.lastMessageInner = messageModel;
        change = true;
    }
    if(change) {
        [self refreshNewMsgCount];
        return true;
    }
    return false;
}


-(NSArray<UITableViewCell*>*) visibleCells {
    return [self.tableView visibleCells];
}

# pragma mark -- 列表委托 UITableViewDataSource && UITableViewDelegate

- (void)tableView:(UITableView *)tableView touchesTime:(NSTimeInterval)timestamp {
    // 短按点击或长按都收起键盘
    if(self.onContentViewClick) {
        self.onContentViewClick();
    }else {
        [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{

    WKMessageModel *messageModel = [self.dataProvider messageAtIndexPath:indexPath];
    Class messageCellClass =  [self getMessageCellClass:messageModel];

    NSString *identifier = NSStringFromClass(messageCellClass);
    // 含表格的文本消息：用 messageId 做唯一 reuseIdentifier，不参与复用池
    if (messageCellClass == WKTextMessageCell.class && messageModel.contentType == WK_TEXT) {
        id contentObj = [messageModel content];
        if ([contentObj isKindOfClass:[WKTextContent class]]) {
            NSString *rawText = ((WKTextContent*)contentObj).content;
            if ([rawText isKindOfClass:[NSString class]] && [WKMarkdownRenderer containsTable:rawText]) {
                identifier = [NSString stringWithFormat:@"%@_table_%llu", identifier, messageModel.messageId];
            }
        }
    }
    WKMessageBaseCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    // 复用池中的 cell 类型可能与当前消息不匹配（reloadData 期间数据源变化），重新创建
    if(!cell || ![cell isKindOfClass:messageCellClass]) {
        cell = [[messageCellClass alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    return cell;
}

// 预计算消息高度并写入 cellHeightCache，确保 reloadData 时高度正确
-(void) precacheHeightForMessage:(WKMessageModel *)msg {
    if (!msg) return;
    BOOL isStreaming = msg.streamOn && msg.streamFlag != WKStreamFlagEnd;
    if (isStreaming) return;

    NSString *heightKey = msg.clientMsgNo;
    if (!heightKey || heightKey.length == 0) return;
    if (msg.remoteExtra.contentEdit) {
        heightKey = [NSString stringWithFormat:@"%@-e%lu", heightKey, (unsigned long)msg.remoteExtra.editedAt];
    }
    // 已缓存则跳过
    if ([[WKMessageListView cellHeightCache] objectForKey:heightKey]) return;

    @try {
        CFAbsoluteTime t0 = CFAbsoluteTimeGetCurrent();
        Class cellClass = [self getMessageCellClass:msg];
        CGSize size = [cellClass sizeForMessage:msg];
        CGFloat height = MAX(size.height, 0.1f);
        [[WKMessageListView cellHeightCache] setObject:@(height) forKey:heightKey];
        CGFloat ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000;
        if (ms > 10) {
            NSString *preview = @"";
            if (msg.contentType == 1 && [msg.content isKindOfClass:NSClassFromString(@"WKTextContent")]) {
                NSString *text = [(id)msg.content content];
                if ([text isKindOfClass:[NSString class]]) {
                    preview = text.length > 60 ? [text substringToIndex:60] : text;
                    preview = [preview stringByReplacingOccurrencesOfString:@"\n" withString:@"↵"];
                }
            }
            NSLog(@"[Perf] precache SLOW: %.1fms type=%ld len=%lu key=%@ content=[%@]",
                  ms, (long)msg.contentType,
                  (unsigned long)(msg.contentType == 1 ? [(NSString*)[(id)msg.content content] length] : 0),
                  heightKey, preview);
        }
    } @catch (NSException *exception) {
        NSLog(@"[HeightCache] precache exception for %@: %@", heightKey, exception);
    }
}

// 高度缓存：避免重复触发 Down 库 markdown 渲染
// 使用 NSCache 替代 NSMutableDictionary：
//   1. countLimit=2000 防止跨会话无限积累（原方案无上限，活跃用户可达数万条）
//   2. 系统内存压力时自动淘汰，无需手动清理
//   3. NSCache 本身线程安全，无需外部加锁
static NSCache<NSString*, NSNumber*> *_cellHeightCache;
+(NSCache<NSString*, NSNumber*>*) cellHeightCache {
    if (!_cellHeightCache) {
        _cellHeightCache = [[NSCache alloc] init];
        _cellHeightCache.countLimit = 2000;
        _cellHeightCache.name = @"WKMessageListViewCellHeightCache";
    }
    return _cellHeightCache;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    WKMessageModel *messageModel = [self.dataProvider messageAtIndexPath:indexPath];
    if (!messageModel) return 0.1f;

    // 流式消息不缓存高度（内容还在变化）
    BOOL isStreaming = messageModel.streamOn && messageModel.streamFlag != WKStreamFlagEnd;
    NSString *heightKey = nil;
    if (!isStreaming && messageModel.clientMsgNo.length > 0) {
        heightKey = messageModel.clientMsgNo;
        // 编辑过的消息用不同 key
        if (messageModel.remoteExtra.contentEdit) {
            heightKey = [NSString stringWithFormat:@"%@-e%lu", heightKey, (unsigned long)messageModel.remoteExtra.editedAt];
        }
        NSNumber *cachedHeight = [[WKMessageListView cellHeightCache] objectForKey:heightKey];
        if (cachedHeight) {
            return cachedHeight.floatValue;
        }
    }

    CGFloat height = 44.0f; // 默认高度兜底
    @try {
        Class messageCellClass = [self getMessageCellClass:messageModel];
        CGSize cellSize = [messageCellClass sizeForMessage:messageModel];
        height = MAX(cellSize.height, 0.1f);
    } @catch (NSException *exception) {
        NSLog(@"[HeightCache] heightForRow exception at %@: %@", indexPath, exception);
    }

    if (heightKey) {
        [[WKMessageListView cellHeightCache] setObject:@(height) forKey:heightKey];
    }
    return height;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    WKMessageModel *messageModel = [self.dataProvider messageAtIndexPath:indexPath];
    if (!messageModel) return;
    WKMessageBaseCell *baseCell = (WKMessageBaseCell*)cell;
    baseCell.conversationContext = [self.dataProvider conversationContext];
    messageModel.checkboxOn =self.multipleOn;
    if([baseCell isKindOfClass:[WKMessageCell class]]) {
        ((WKMessageCell*)baseCell).showNavigateToMessage = self.showNavigateToMessage;
    }
    @try {
        [baseCell refresh:messageModel];
    } @catch (NSException *exception) {
        // 竞态下 cell class 与消息 content 类型不匹配时不崩溃
        NSLog(@"[MessageList] refresh exception at %@: %@", indexPath, exception);
    }
    [baseCell onWillDisplay];

    
    [self didReadedAndViewed]; // 将消息放入已读和已查看
    
    if(messageModel.orderSeq>self.browseToOrderSeq) {
        [self updateBrowseToOrderSeq];
    }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    WKMessageBaseCell *baseCell = (WKMessageBaseCell*)cell;
    [baseCell onEndDisplay];
}

//
//- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
//
//    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
//        UIAction *action = [UIAction actionWithTitle:@"复制" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
//
//        }];
//
//        return [UIMenu menuWithChildren:@[action]];
//    }];
//}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.dataProvider dateCount];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray<WKMessageModel*> *messages = [self.dataProvider messagesAtSection:section];
    if(!messages||messages.count==0) {
        return 0;
    }
    return messages.count;
}


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
   WKTimeHeaderView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:[WKTimeHeaderView reuseId]];
    static NSDateFormatter *sectionDateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sectionDateFormatter = [[NSDateFormatter alloc] init];
        [sectionDateFormatter setDateFormat:@"yyyy-MM-dd"];
    });
    NSDate *date = [sectionDateFormatter dateFromString:[self.dataProvider dateWithSection:section]];
    headerView.dateLbl.text = [WKTimeTool formatDateStyle1:date];
//    [headerView.dateLbl sizeToFit];
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [WKTimeHeaderView height];
}


#pragma mark -- scollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    self.scrolling = true;
    [self updateBrowseToOrderSeq];
    [self scrollViewDidScrollOfPosition:scrollView];

    // 滚到顶部自动触发 MJRefresh 加载历史消息（显示菊花）
    CGFloat offsetY = scrollView.contentOffset.y + scrollView.contentInset.top;
    if (offsetY <= -1 && !self.isPulldownInProgress && !self.tableView.mj_header.hidden
        && self.tableView.mj_header.state != MJRefreshStateRefreshing) {
        [self.tableView.mj_header beginRefreshing];
    }
}


- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [UIView animateWithDuration:0.3f animations:^{
        self.didManuallyStoppedTableViewDecelerating = false;
        [self setFloatingHeaderViewsHidden:false animated:false delay:0.0f];
    } completion:nil];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if(!decelerate) {
        self.didManuallyStoppedTableViewDecelerating = true;
        [self setFloatingHeaderViewsHidden:true animated:true delay:0.5f];
        [self endScroll:scrollView];
    }
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (!self.didManuallyStoppedTableViewDecelerating) {
        [self setFloatingHeaderViewsHidden:true animated:true delay:0.5f];
    }
    [self endScroll:scrollView];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
}
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setFloatingHeaderViewsHidden:true animated:true delay:1.0f];
    });
}

#pragma mark - WKChatManagerDelegate

// 收取消息 left表示剩余消息数量 TODO: 这里有优化的余地 优化到最后一条此会话的消息才刷新
- (void)onRecvMessages:(WKMessage*)message left:(NSInteger)left {
    // [DEBUG] 打印收到消息在UI层的处理
    NSLog(@"[BOT-DEBUG] UI层收到消息: contentType=%ld, contentClass=%@, streamOn=%d, streamNo=%@, streamFlag=%ld, status=%ld, isSend=%d, fromUid=%@",
          (long)message.contentType,
          NSStringFromClass([message.content class]),
          message.streamOn,
          message.streamNo ?: @"(nil)",
          (long)message.streamFlag,
          (long)message.status,
          message.isSend,
          message.fromUid);
    if(![self needHandle:message]) {
        return;
    }
    // 系统Bot（如BotFather）消息按space_id过滤，实现会话隔离
    if(![self shouldShowMessageInCurrentSpace:message]) {
        return;
    }
    NSIndexPath *indexPath = [self.dataProvider indexPathAtClientMsgNo:message.clientMsgNo];
    if(indexPath) { // 存在的消息不再添加
        return;
    }
    [self handleRecvMessage:message];
}


// 消息更新
-(void) onMessageUpdate:(WKMessage*) message left:(NSInteger)left total:(NSInteger)total{
    WKLogDebug(@"onMessageUpdate-->%u",message.messageSeq);

    if(![self needHandle:message]) {
        return;
    }
    BOOL needRelodData = false;
    if(left == 0) {
        needRelodData = true;
    }
    NSIndexPath *indexPath = [self.dataProvider indexPathAtClientMsgNo:message.clientMsgNo];
    if(indexPath) {
//        WKMessageModel *newMessageModel = [[WKMessageModel alloc]  initWithMessage:message];
        WKMessageModel *newMessageModel = [self.dataProvider messageAtIndexPath:indexPath];
        if(!newMessageModel) {
            newMessageModel =  [[WKMessageModel alloc]  initWithMessage:message];
        }
        newMessageModel.message = message;
        [self.dataProvider replaceMessage:newMessageModel atClientMsgNo:message.clientMsgNo];
       
        if(message.remoteExtra.revoke|| message.isDeleted ) {
//            if(total == 1) { // 如果只有一条消息，这里做了单独的cell刷新，则不需要再[self.tableView reloadData]了
//                needRelodData = false;
//            }
//            [self refreshCellForDeleteAndInsert:newMessageModel];
            needRelodData =true;
            if(message.remoteExtra.revoke) {
               NSArray<WKMessageModel*> *containReplyMessages = [self.dataProvider messagesAtMessageReply:message.messageId];
                if(containReplyMessages&&containReplyMessages.count>0) {
                    for (WKMessageModel *model in containReplyMessages) {
                        if(model.content.reply) {
                            model.content.reply.revoke = true;
                        }
                    }
                }
            }
            
        }else if(total == 1) {
            needRelodData = false;
            WKMessageBaseCell *cell = (WKMessageBaseCell *)[self.tableView cellForRowAtIndexPath:indexPath];
            
            [self animateMessageWithBlock:^{
                [cell refresh:newMessageModel];
                [cell layoutSubviews];
            }];
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
           
        }
        
        if(self.lastMessage) {
            if(message.isSend && message.orderSeq>self.lastMessage.orderSeq) {
                [self updateLastMsgIfNeed:newMessageModel];
            }
            if(message.isDeleted && [self.lastMessage.clientMsgNo isEqualToString:message.clientMsgNo]) {
                [self  updateLastMsgIfNeed:[self.dataProvider lastMessage]];
            }
        }
        
    }
    if(needRelodData) {
        [self.tableView reloadData];
    }
}

- (void)onMessageStream:(WKStream *)stream {
    NSIndexPath *indexPath = [self.dataProvider indexPathAtStreamNo:stream.streamNo];
    if(indexPath) {
        WKMessageBaseCell *cell = (WKMessageBaseCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        WKMessageModel *messageModel = [self.dataProvider messageAtIndexPath:indexPath];
        [messageModel.streams addObject:stream];
        
        CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
        
        CGFloat cellOffsetTop = cellRect.origin.y - (self.tableView.contentOffset.y + self.tableView.contentInset.top);// cell顶部偏移量
        
        
        [self animateMessageWithBlock:^{
            [cell refresh:messageModel];
            [cell layoutSubviews];
        } completion:^(BOOL finished) {
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            [self ajustTableViewByStreams];
            if(self.positionAtBottom) {
                if(cellOffsetTop + cellRect.size.height > [self visiableTableHeight]) { // cell底部被table挡住了，滚动到最底部
                    [self scrollToBottom:YES];
                }
            }
        }];
    }
}

-(void) ajustTableViewByStreams {
    
    NSArray<UITableViewCell*> *visibleCells =  [self visibleCells];
    CGFloat tableOffset = 0.0f;
     if(visibleCells && visibleCells.count>0) {
         for (UITableViewCell *tableCell in visibleCells) {
             if([tableCell isKindOfClass:WKMessageCell.class]) {
                 WKMessageCell *messageCell = (WKMessageCell*)tableCell;
                 WKMessageModel *messageModel = messageCell.messageModel;
                 if(messageModel.streamOn) {
                     if(messageModel.preCellHeight > 0) {
                         tableOffset += (messageModel.preCellHeight - tableCell.frame.size.height);
                     }
                     messageModel.preCellHeight = tableCell.frame.size.height;
                 }
             }
         }
     }
    if(tableOffset!=0) {
        CGFloat offsetY = self.tableView.contentOffset.y - tableOffset;// 离底部的距离
        [self.tableView setContentOffset:CGPointMake(0, offsetY)];
    }
}


// 消息已删除
-(void) onMessageDeleted:(WKMessage *)message {
    if(![self needHandle:message]) {
        return;
    }
   
    [self deleteMessageUI:message];
}


-(void) deleteMessageUI:(WKMessage*)message {
    NSIndexPath *indexPath  = [self.dataProvider indexPathAtClientMsgNo:message.clientMsgNo];
    if(indexPath) {
        WKMessageModel *deleteMessageModel = [self.dataProvider messageAtIndexPath:indexPath];
        if(deleteMessageModel) {
            NSString *preClientMsgNo;
            NSString *nextClientMsgNo;
            if(deleteMessageModel.preMessageModel && deleteMessageModel.preMessageModel.clientMsgNo && ![deleteMessageModel.preMessageModel.clientMsgNo isEqualToString:@""]) {
                preClientMsgNo = deleteMessageModel.preMessageModel.clientMsgNo;
            }
            if(deleteMessageModel.nextMessageModel && deleteMessageModel.nextMessageModel.clientMsgNo && ![deleteMessageModel.nextMessageModel.clientMsgNo isEqualToString:@""]) {
                nextClientMsgNo = deleteMessageModel.nextMessageModel.clientMsgNo;
            }
            BOOL sectionRemove = false;
            [self.dataProvider removeMessage:deleteMessageModel sectionRemove:&sectionRemove];
            
            if(self.lastMessage && [deleteMessageModel.clientMsgNo isEqualToString:self.lastMessage.clientMsgNo]) {
                self.lastMessageInner = nil;
                [self updateLastMsgIfNeed:[self.dataProvider lastMessage]];
                
            }
            
            NSMutableArray *reloadIndexPaths = [NSMutableArray array];
            if(preClientMsgNo) {
               NSIndexPath *preIndexPath =  [self.dataProvider indexPathAtClientMsgNo:preClientMsgNo];
                if(preIndexPath) {
                    [reloadIndexPaths addObject:preIndexPath];
                }
            }
            if(nextClientMsgNo) {
               NSIndexPath *nextIndexPath =  [self.dataProvider indexPathAtClientMsgNo:nextClientMsgNo];
                if(nextIndexPath) {
                    [reloadIndexPaths addObject:nextIndexPath];
                }
            }
        
           
            @try {
                if(sectionRemove) {
                    [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
                }else {
                    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                }
            } @catch (NSException *exception) {
                NSLog(@"deleteMessageUI-exception->%@",exception);
                [self.tableView reloadData];
            }
           
            if(reloadIndexPaths.count>0) {
                [self.tableView reloadRowsAtIndexPaths:reloadIndexPaths withRowAnimation:UITableViewRowAnimationFade];
            }
            
        }
       
    }
}
// 清除所有消息
- (void)onMessageCleared:(WKChannel *)channel {
    if(![channel isEqual:self.channel]) {
        return;
    }
    [self.dataProvider clearMessages];
    [self.tableView reloadData];
}

#pragma mark - WKChannelManagerDelegate
// 频道信息更新
-(void) channelInfoUpdate:(WKChannelInfo*)channelInfo {
    if([self.channel isEqual:channelInfo.channel]) { // 更新的当前会话的信息
        self.channelInfo = channelInfo;
    }else { // 更新的当前聊里页面的发送者的信息
        if(channelInfo.channel.channelType != WK_PERSON) {
            return;
        }
       NSArray<UITableViewCell*> *visibleCells =  self.tableView.visibleCells;
        if(visibleCells && visibleCells.count>0) {
            for (UITableViewCell *tableCell in visibleCells) {
                if([tableCell isKindOfClass:WKMessageCell.class]) {
                    WKMessageCell *messageCell = (WKMessageCell*)tableCell;
                    WKMessageModel *messageModel = messageCell.messageModel;
                    if(messageModel &&  [messageModel.fromUid isEqual:channelInfo.channel.channelId]) {
                        messageModel.from = nil;
                        [messageCell refresh:messageModel];
                    }
                    
                }
            }
        }
//         [self.tableView reloadData]; // TODO: 不要用reloadData 会导致长按菜单错位
    }
}

#pragma mark -- WKReactionManagerDelegate

- (void)reactionManagerChange:(WKReactionManager *)reactionManager reactions:(NSArray<WKReaction *> *)reactions channel:(WKChannel *)channel {
    if(![self.channel isEqual:channel]) {
        return;
    }
    for (WKReaction *reaction in reactions) {
        NSIndexPath *indexPath = [self.dataProvider indexPathAtMessageID:reaction.messageId];
        if(indexPath) {
            WKMessageModel *messageModel = [self.dataProvider messageAtIndexPath:indexPath];
            if(reaction.isDeleted == 1) {
                [messageModel cancelReaction:reaction];
            }else {
                [messageModel addReaction:reaction];
            }
            WKMessageCell *messageCell = [self.tableView cellForRowAtIndexPath:indexPath];
            [messageCell refresh:messageModel];
            [messageCell layoutReaction];
        }
    }
}

#pragma mark -- WKConnectionManagerDelegate


-(void) onConnectStatus:(WKConnectStatus)status reasonCode:(WKReason)reasonCode {
    if(status == WKConnected) { // 如果已连接，则重新请求消息
        __weak typeof(self) weakSelf = self;
        [self pullup:^(bool more) {
            WKMessageModel *localLastMsg = [weakSelf.dataProvider lastMessage];
            if(!localLastMsg) {
                return;
            }
            if(weakSelf.lastMessage && [weakSelf.lastMessage.clientMsgNo isEqualToString:localLastMsg.clientMsgNo]) {
                return;
            }
            WKMessage *newLastMsg = [[WKSDK shared].chatManager getLastMessage:weakSelf.channel];
            
            if(newLastMsg) {
                [weakSelf updateLastMsgIfNeed:[[WKMessageModel alloc] initWithMessage:newLastMsg]];
            }
        }];
    }
}

#pragma mark - WKTypingManagerDelegate

- (void)typingAdd:(WKTypingManager *)manager message:(WKMessage *)message {
    if(![self.channel isEqual:message.channel] || [message.fromUid isEqualToString:[WKApp shared].loginInfo.uid]) {
        return;
    }
    if([self pullupHasMore]) {
        return;
    }
    WKMessageModel *model = [[WKMessageModel alloc] initWithMessage:message];
    [self.dataProvider addMessage:model];
    [self reloadData];
    if(self.positionAtBottom) {
        [self animateMessageWithBlock:^{
            [self scrollToBottom:NO];
        }];
    }
    
}


- (void)typingRemove:(WKTypingManager *)manager message:(WKMessage *)message  newMessage:(WKMessage *)newMessage{
    if(![self.channel isEqual:message.channel] || [message.fromUid isEqualToString:[WKApp shared].loginInfo.uid]) {
        return;
    }
    WKLogDebug(@"typingRemove------%@",newMessage);
    if(!newMessage) { // 最后没有将消息发送出来
        [self deleteMessageUI:message];
    }

}


#pragma mark -- WKReminderManagerDelegate

- (void)reminderManager:(WKReminderManager *)manager didChange:(WKChannel *)channel reminders:(NSArray<WKReminder *> *)reminders {
    if(![channel isEqual:self.channel]) {
        return;
    }
    NSArray<WKReminder*> *oldReminders = self.reminders;
    if(!oldReminders||oldReminders.count ==0) {
        self.reminders = reminders;
    }else {
        NSMutableArray<WKReminder*> *newReminders = [NSMutableArray array];
        for (WKReminder *reminder in reminders) {
            if(reminder.publisher && [reminder.publisher isEqualToString:WKApp.shared.loginInfo.uid]) {
                continue;
            }
            WKReminder *newReminder = [reminder copy];
            for (WKReminder *oldReminder in oldReminders) {
                if(newReminder.reminderID == oldReminder.reminderID) {
                    if(!newReminder.done && oldReminder.done) {
                        newReminder.done = oldReminder.done;
                    }
                }
            }
            [newReminders addObject:newReminder];
        }
        self.reminders = newReminders;
    }
    [self updatePostionReminders:self.reminders force:true];
    
}


@end
