//
//  WKMessageListView+Position.h
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import "WKMessageListView.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKMessageListView (Position)

-(void) initPosition;

-(void) calcPositionAtBottom;

-(void) viewDidLayoutSubviewsOfPosition;

-(void) showScrollToBottomBarIfNeed;

-(void) handleNewMsgCountChange;

- (void)scrollViewDidScrollOfPosition:(UIScrollView *)scrollView;

-(void) layoutConversationPositionBarView;

-(void) updatePostionReminders:(NSArray<WKReminder*>*) reminders force:(BOOL)force;

@end

NS_ASSUME_NONNULL_END
