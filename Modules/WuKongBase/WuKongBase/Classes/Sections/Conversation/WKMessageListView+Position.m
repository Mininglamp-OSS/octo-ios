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
        [weakSelf pullBottom];
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
