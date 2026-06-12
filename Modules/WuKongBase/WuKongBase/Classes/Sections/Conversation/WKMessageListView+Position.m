//
//  WKMessageListView+Position.m
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import "WKMessageListView+Position.h"

#import "WKConversationPositionBarView.h"
#import "WuKongBase.h"

@implementation WKMessageListView (Position)


-(void) initPosition {
    self.positionAtBottom = true;
    self.conversationPositionBarView = [[WKConversationPositionBarView alloc] init];
    __weak typeof(self) weakSelf = self;
    [self.conversationPositionBarView setOnScrollToBottom:^{
        __strong typeof(weakSelf) ws = weakSelf;
        if (!ws) return;
        // 微信式两步定位:
        //   第 1 次 (有未读 + 视口未看到首条未读 = 用户上翻了历史): 锚到 readBoundary,
        //     让用户开始按时间往下读, 不 mark read (用户还没看完);
        //   第 2 次 (首条未读已在视口 / 没未读 / 自然开会就已 anchor 到 readBoundary):
        //     走原行为 pullBottom + 三端同步 mark read。
        // 用「位置语义」(maxVisible vs firstUnread) 自然区分一二次, 无状态 flag。
        //
        // discriminator 用 firstUnread (lastReadSeq+1) 数值比较, 不依赖消息存在;
        // anchor 用 readBoundary (lastReadSeq), 已读消息肯定 loaded — 即便首条
        // 未读被撤回 indexPath 拿不到, readBoundary 仍能命中, 不会静默 no-op
        // (R6 P2 / P1-2 选 C: 与 calcKeepPosition 同款 anchor)。
        // tablePosition=Top 让 readBoundary 在视口顶, 首条未读出现在第二行,
        // 视觉上等价于 calcKeepPosition 的 readBoundary + offset=-120。
        uint32_t firstUnreadOS = [ws ks_firstUnreadOrderSeqForScrollToBottom];
        if (firstUnreadOS > 0 &&
            ws.conversationPositionBarView.maxVisiableOrderSeq < firstUnreadOS) {
            uint32_t readBoundaryOS = [ws ks_readBoundaryOrderSeqForScrollToBottom];
            if (readBoundaryOS > 0) {
                [ws locateMessageCellWithOrderSeqForReminder:readBoundaryOS
                                               tablePosition:UITableViewScrollPositionTop];
                return;
            }
        }
        [ws pullBottom];
        // 「跑到最底部」按钮 = 用户主动声明「我都看完了」，必须显式做三端同步。
        // 不能复用 refreshNewMsgCount 的 oldMsgCount != newMsgCount 路径 —— 这条
        // 路径在 browseToOrderSeq=0 起步、newMsgCount 一直是 0 的场景会被 bypass，
        // 表现就是「视觉上 badge 消了，server 上 unread 没动，杀进程重启又复现」。
        [ws forceMarkAllAsRead];
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

// 计算"首条未读"的 orderSeq, 用于向下按钮两步定位的 discriminator (判断
// 视口是否已包含首条未读)。是纯算术 getOrderSeq, 不需要消息真实存在。
// 算法与 WKConversationView.calcKeepPositionAndBrowseToOrderSeq 同款:
//   - 优先 lastReadSeq + 1 (精确, 不受撤回/删除/推送 race 影响)
//   - 兜底 lastMsgSeq - newMsgCount + 1 (新会话 / 旧版数据 lastReadSeq=0 时用)
- (uint32_t)ks_firstUnreadOrderSeqForScrollToBottom {
    if (self.newMsgCount <= 0) return 0;
    WKChannel *ch = self.channel;
    if (!ch) return 0;
    uint32_t firstUnreadSeq = 0;
    uint32_t lastReadSeq = [[WKUnreadStore shared] lastReadSeqForChannel:ch];
    if (lastReadSeq > 0) {
        firstUnreadSeq = lastReadSeq + 1;
    } else if (self.lastMessage) {
        uint32_t lastMsgSeq = self.lastMessage.messageSeq;
        if (lastMsgSeq > (uint32_t)self.newMsgCount) {
            firstUnreadSeq = lastMsgSeq - (uint32_t)self.newMsgCount + 1;
        }
    }
    if (firstUnreadSeq == 0) return 0;
    return [[WKSDK shared].chatManager getOrderSeq:firstUnreadSeq];
}

// 计算"已读边界"的 orderSeq (= 首条未读 - 1), 用于向下按钮两步定位的实际
// anchor 目标。比首条未读更鲁棒——已读消息肯定 loaded, 不会因为首条未读被
// 撤回导致 indexPath 拿不到而 locateMessageCell 静默 no-op (R6 P2 / P1-2 选 C)。
// 与 calcKeepPositionAndBrowseToOrderSeq 的 anchorSeq 同款逻辑。
- (uint32_t)ks_readBoundaryOrderSeqForScrollToBottom {
    if (self.newMsgCount <= 0) return 0;
    WKChannel *ch = self.channel;
    if (!ch) return 0;
    uint32_t readBoundarySeq = 0;
    uint32_t lastReadSeq = [[WKUnreadStore shared] lastReadSeqForChannel:ch];
    if (lastReadSeq > 0) {
        readBoundarySeq = lastReadSeq;
    } else if (self.lastMessage) {
        uint32_t lastMsgSeq = self.lastMessage.messageSeq;
        if (lastMsgSeq > (uint32_t)self.newMsgCount) {
            readBoundarySeq = (uint32_t)(lastMsgSeq - (uint32_t)self.newMsgCount);
        }
    }
    if (readBoundarySeq == 0) return 0;
    return [[WKSDK shared].chatManager getOrderSeq:readBoundarySeq];
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
            WKMessageModel *messageModel = [self.dataProvider messageAtIndexPath:visibleRow];
             if(messageModel) {
                 if(minVisiableOrderSeq == 0 ) {
                     minVisiableOrderSeq = messageModel.orderSeq;
                 }
                 maxVisiableOrderSeq = messageModel.orderSeq;
                 for (WKReminder *reminder in reminders) {
                     if(!reminder.done && messageModel.messageSeq == reminder.messageSeq) {
                         reminder.done = true;
                         hasDone = true;
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
            WKMessageModel *messageModel = [self.dataProvider messageAtIndexPath:visibleRow];
             if(messageModel) {
                 if(minVisiableOrderSeq == 0 ) {
                     minVisiableOrderSeq = messageModel.orderSeq;
                 }
                 maxVisiableOrderSeq = messageModel.orderSeq;
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
    }else{
        CGRect lastMessageRect = [self.tableView rectForRowAtIndexPath:lastIndexPath]; // 获取最底部消息的rect
        if([self cellIsVisible:lastMessageRect]) { // 如果最新的消息可见了 说明到底部了，反之没有
            self.positionAtBottom = true;
        }else {
            self.positionAtBottom = false;
        }
    }
}

-(void) layoutConversationPositionBarView {
//    NSLog(@"self.conversationPositionBarView.lim_height--->-top:%0.2f",self.input.lim_top);
    self.conversationPositionBarView.lim_left = self.lim_width - self.conversationPositionBarView.lim_width  - 10.0f;
    self.conversationPositionBarView.lim_top = self.tableView.lim_bottom  - self.conversationPositionBarView.lim_height - 40.0f;//

}


@end
