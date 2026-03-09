//
//  WKConversationPositionBarView.h
//  WuKongBase
//
//  Created by tt on 2022/4/19.
//

#import <UIKit/UIKit.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConversationPosition.h"
NS_ASSUME_NONNULL_BEGIN

#define WKPositionBarHeight 56.0f
#define WKPositionBarWidth 56.0f

@interface WKConversationPositionBarView : UIView

@property(nonatomic,copy) void(^onScrollToBottom)(void); // 滚动到底部
@property(nonatomic,copy) void(^onScrollToPosition)(WKConversationPosition *position,UITableViewScrollPosition tableViewScrollPosition); // 滚动到指定位置

@property(nonatomic,assign) NSInteger minVisiableOrderSeq; // 当前可见最小的orderSeq
@property(nonatomic,assign) NSInteger maxVisiableOrderSeq; // 当前可见最大的orderSeq

-(void) updateReminders:(NSArray<WKReminder*>*)reminders;

-(void) showScrollBottom:(BOOL)showScrollBottom animateComplete:(void(^__nullable)(void))animateComplete; // 显示滚动到底部

-(void) updateScrollToBottomBarBadge:(NSInteger)value; // 更新滚动到底部的badge数

@end

@interface WKPositionBar : UIView

@property(nonatomic,strong) NSArray<WKConversationPosition*> *positions;

- (instancetype)initWithType:(WKConversationPositionType)type;

@property(nonatomic,copy) void(^onClick)(void);

-(void) updateBadge:(NSInteger)badge;

@end

NS_ASSUME_NONNULL_END
