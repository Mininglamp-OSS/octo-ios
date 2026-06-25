//
//  WKMessageListView+Position.m
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import "WKMessageListView+Position.h"
#import "WKMessageListView+Fold.h"
#import "WKConversationPositionBarView.h"
#import "WuKongBase.h"

@implementation WKMessageListView (Position)


-(void) initPosition {
    self.positionAtBottom = true;
    self.conversationPositionBarView = [[WKConversationPositionBarView alloc] init];
    __weak typeof(self) weakSelf = self;
    [self.conversationPositionBarView setOnScrollToBottom:^{
        [weakSelf pullBottom];
        // 「跑到最底部」按钮 = 用户主动声明「我都看完了」，必须显式做三端同步。
        // 不能复用 refreshNewMsgCount 的 oldMsgCount != newMsgCount 路径 —— 这条
        // 路径在 browseToOrderSeq=0 起步、newMsgCount 一直是 0 的场景会被 bypass，
        // 表现就是「视觉上 badge 消了，server 上 unread 没动，杀进程重启又复现」。
        [weakSelf forceMarkAllAsRead];
    }];
    [self.conversationPositionBarView setOnScrollToPosition:^(WKConversationPosition * _Nonnull position,UITableViewScrollPosition tablePosition) {
        [weakSelf locateMessageCellWithOrderSeqForReminder:position.orderSeq tablePosition:tablePosition];
    }];
    
    
    [self addSubview:self.conversationPositionBarView];
    
    NSArray<WKReminder*> *reminders = self.reminders;
    [self updateVisiableOrderSeq];
    [self.conversationPositionBarView updateReminders:reminders];
    
    [self.conversationPositionBarView showScrollBottom:!self.positionAtBottom animateComplete:nil];
    
    [self layoutConversationPositionBarView];
}


-(void) viewDidLayoutSubviewsOfPosition {
    [self updateVisiableOrderSeq];
}

- (void)scrollViewDidScrollOfPosition:(UIScrollView *)scrollView {
    BOOL oldPositionAtBottom = self.positionAtBottom;
    [self calcPositionAtBottom];
    BOOL newPositionAtBottom = self.positionAtBottom;
    
   
    [self updatePostionReminders];
    
    if(oldPositionAtBottom!=newPositionAtBottom) {
        [self showScrollToBottomBarIfNeed];
    }

    
}

-(void) handleNewMsgCountChange {
    [self.conversationPositionBarView updateScrollToBottomBarBadge:[self newMsgCount]]; // 更新最新消息数量
}

-(void) updatePostionReminders:(NSArray<WKReminder*>*) reminders force:(BOOL)force{
    NSMutableArray<WKReminder*> *locateReminders = [NSMutableArray array];
    for (WKReminder *reminder in reminders) {
        if(!reminder.isLocate || reminder.done) {
            continue;
        }
        [locateReminders addObject:reminder];
    }
    NSArray<NSIndexPath*> *visibleRows = [self.tableView indexPathsForVisibleRows];
    BOOL hasDone = false;
    uint32_t minVisiableOrderSeq = 0;
    uint32_t maxVisiableOrderSeq = 0;
    for (NSInteger i = 0; i<visibleRows.count; i++) {
        NSIndexPath *visibleRow = visibleRows[i];
        CGRect rect =  [self.tableView rectForRowAtIndexPath:visibleRow];
         if([self cellIsVisible:rect]) {
             // bot 折叠：折叠卡覆盖整组消息——该行的"可见 orderSeq 范围"是 [min, max]
             // 取自该组所有消息；遍历这些消息触发 reminder.done 判定，并把 row 的
             // min/max 并入全局 min/max。
             NSArray<WKMessageModel *> *covered = [self wk_fold_coveredMessagesForTableIndexPath:visibleRow];
             NSArray<WKMessageModel *> *toScan = covered.count > 0 ? covered :
                 (^{ WKMessageModel *m = [self.dataProvider messageAtIndexPath:visibleRow]; return m ? @[m] : @[]; })();
             for (WKMessageModel *messageModel in toScan) {
                 if(messageModel) {
                     if(minVisiableOrderSeq == 0 || messageModel.orderSeq < minVisiableOrderSeq) {
                         minVisiableOrderSeq = messageModel.orderSeq;
                     }
                     if(messageModel.orderSeq > maxVisiableOrderSeq) {
                         maxVisiableOrderSeq = messageModel.orderSeq;
                     }
                     for (WKReminder *reminder in reminders) {
                         if(!reminder.done && messageModel.messageSeq == reminder.messageSeq) {
                             reminder.done = true;
                             hasDone = true;
                         }
                     }
                 }
             }
         }
    }
    if(hasDone || force) {
        self.conversationPositionBarView.minVisiableOrderSeq  =  minVisiableOrderSeq;
        self.conversationPositionBarView.maxVisiableOrderSeq = maxVisiableOrderSeq;
        [self.conversationPositionBarView updateReminders:reminders];
        [self animateMessageWithBlock:^{
            [self layoutConversationPositionBarView];
        }];
    }
    if(hasDone) {
        [self markReminderDoneIfNeed];
    }

    // [ReminderTrace] force pass(进入聊天后第一次扫描)结束时,如果还有 reminder 没被标 done,
    // 把它们的 messageSeq 在本地 message DB 里查一下,区分是"消息不存在/已 revoke"还是
    // "消息存在但当前不在可见区".这是定位"[有人@我]幽灵 reminder"的关键观测点.
    if (force) {
        for (WKReminder *reminder in reminders) {
            if (reminder.done) continue;
            if (reminder.type != WKReminderTypeMentionMe) continue;
            WKMessage *msg = [[WKMessageDB shared] getMessage:reminder.channel messageSeq:reminder.messageSeq];
            BOOL inVisible = (reminder.messageSeq != 0
                              && minVisiableOrderSeq != 0
                              && [[WKSDK shared].chatManager getOrderSeq:reminder.messageSeq] >= minVisiableOrderSeq
                              && [[WKSDK shared].chatManager getOrderSeq:reminder.messageSeq] <= maxVisiableOrderSeq);
            NSLog(@"[ReminderTrace] orphan-check channelId=%@ reminderID=%lld msgSeq=%u localMsgExists=%d localMsgIsDeleted=%d inVisibleRange=%d minVisOrder=%u maxVisOrder=%u",
                  reminder.channel.channelId, reminder.reminderID, reminder.messageSeq,
                  msg != nil, msg ? (int)msg.isDeleted : -1, inVisible,
                  minVisiableOrderSeq, maxVisiableOrderSeq);
        }
    }
}

-(void) updatePostionReminders {
    NSArray<WKReminder*> *reminders = self.reminders;
    if(!reminders||reminders.count == 0) {
        return;
    }
    [self updatePostionReminders:reminders force:false];
   
}

-(void) updateVisiableOrderSeq {
    NSArray<NSIndexPath*> *visibleRows = [self.tableView indexPathsForVisibleRows];
    uint32_t minVisiableOrderSeq = 0;
    uint32_t maxVisiableOrderSeq = 0;
    for (NSInteger i = 0; i<visibleRows.count; i++) {
        NSIndexPath *visibleRow = visibleRows[i];
        CGRect rect =  [self.tableView rectForRowAtIndexPath:visibleRow];
         if([self cellIsVisible:rect]) {
             // bot 折叠：同 updatePostionReminders——展开覆盖消息，min/max 都并入
             NSArray<WKMessageModel *> *covered = [self wk_fold_coveredMessagesForTableIndexPath:visibleRow];
             NSArray<WKMessageModel *> *toScan = covered.count > 0 ? covered :
                 (^{ WKMessageModel *m = [self.dataProvider messageAtIndexPath:visibleRow]; return m ? @[m] : @[]; })();
             for (WKMessageModel *messageModel in toScan) {
                 if(messageModel) {
                     if(minVisiableOrderSeq == 0 || messageModel.orderSeq < minVisiableOrderSeq) {
                         minVisiableOrderSeq = messageModel.orderSeq;
                     }
                     if(messageModel.orderSeq > maxVisiableOrderSeq) {
                         maxVisiableOrderSeq = messageModel.orderSeq;
                     }
                 }
             }
         }
    }
    self.conversationPositionBarView.minVisiableOrderSeq = minVisiableOrderSeq;
    self.conversationPositionBarView.maxVisiableOrderSeq = maxVisiableOrderSeq;
}

-(void) showScrollToBottomBarIfNeed {
    [self layoutConversationPositionBarView];
    [self.conversationPositionBarView showScrollBottom:!self.positionAtBottom animateComplete:^{
        [self animateMessageWithBlock:^{
            [self layoutConversationPositionBarView];
        }];
    }];
    
    [self animateMessageWithBlock:^{
        [self layoutConversationPositionBarView];
    }];
}



-(void) calcPositionAtBottom {
    if(!self.lastMessage) {
        return;
    }
    NSIndexPath *lastIndexPath = [self.dataProvider indexPathAtClientMsgNo:self.lastMessage.clientMsgNo];
    if(!lastIndexPath) { // 如果最新的消息在tableView里没有 则表示消息没到底部
        self.positionAtBottom = false;
        return;
    }
    // bot 折叠：dataProvider 返回的是 raw 行号；折叠开启时最后一条消息可能被吞进
    // 折叠卡里，raw 行号在 tableView 里不存在 → rectForRow 返 CGRectZero → 永远
    // 判 NO → 用户在底部时也认不出 → 收到新消息不会触发 scrollToBottom。
    // 翻译到 fold 后的 tableView 行号再查 rect。
    NSIndexPath *useIndexPath = lastIndexPath;
    NSIndexPath *foldIndexPath = [self wk_fold_translatedIndexPathForDataProviderIndexPath:lastIndexPath
                                                                            expandIfNeeded:NO];
    if (foldIndexPath) useIndexPath = foldIndexPath;
    CGRect lastMessageRect = [self.tableView rectForRowAtIndexPath:useIndexPath]; // 获取最底部消息的rect
    if([self cellIsVisible:lastMessageRect]) { // 如果最新的消息可见了 说明到底部了，反之没有
        self.positionAtBottom = true;
    }else {
        self.positionAtBottom = false;
    }
}

-(void) layoutConversationPositionBarView {
//    NSLog(@"self.conversationPositionBarView.lim_height--->-top:%0.2f",self.input.lim_top);
    self.conversationPositionBarView.lim_left = self.lim_width - self.conversationPositionBarView.lim_width  - 10.0f;
    self.conversationPositionBarView.lim_top = self.tableView.lim_bottom  - self.conversationPositionBarView.lim_height - 40.0f;//

}


@end
