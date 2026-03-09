//
//  WKConversationView.h
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import <UIKit/UIKit.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKMessageModel.h"
#import "WKMessageListDataProvider.h"
#import "WKConversationPositionBarView.h"
#import "WKConversationTableView.h"
NS_ASSUME_NONNULL_BEGIN


@interface WKMessageListView : UIView


// --------------------------------- 必传参数 ---------------------------------
@property(nonatomic,strong) WKChannel *channel; // 消息列表所属频道

@property(nonatomic,strong,nullable) WKChannelInfo *channelInfo; // 频道信息

@property(nonatomic,strong) id<WKMessageListDataProvider> dataProvider; // 数据源

-(void) viewWillDisappear; // viewController viewWillDisappear事件里需要调用此方法

// --------------------------------- 可选参数 ---------------------------------

@property(nonatomic,strong) NSArray<WKReminder*> *reminders; // 提醒项，用户提醒消息定位

@property(nonatomic,strong,nullable) WKConversationPosition *keepPosition; // 滚动保持位置
@property(nonatomic,assign) BOOL needPositionReminder; // 跳到keepPosition的位置后是否需要提醒这条消息的效果
@property(nonatomic,assign) uint32_t browseToOrderSeq; // 已看到的最新的消息orderSeq

@property(nonatomic,strong,nullable) WKMessageModel *lastMessage; // 当前会话最新的一条消息，也就是orderSeq最大的（这个决定了滚动到底部按钮的显示,和新消息数量）


@property(nonatomic,assign) NSUInteger newMsgCount;// 新消息数量

@property(nonatomic,assign) BOOL scrollEnabled; // 是否启用滚动

@property(nonatomic,assign) BOOL showNavigateToMessage; // 是否显示跳到消息的按钮

// --------------------------------- 共享属性 ---------------------------------

@property(nonatomic,assign) BOOL positionAtBottom; // 当前滑动位置是否在最底部

@property(nonatomic,assign) BOOL scrolling; // 消息列表是否正在滚动

@property(nonatomic,strong) WKConversationPositionBarView *conversationPositionBarView;

@property(nonatomic,strong) WKConversationTableView *tableView;

@property(nonatomic,assign) BOOL hasRecvMsg; // 在当前页面时 有收到别人发的消息（用于未读数量清除判断）

// --------------------------------- block事件 ---------------------------------
@property(nonatomic,copy) void(^onContentViewClick)(void); // 正文点击


// --------------------------------- 常用方法 ---------------------------------

-(void) animateMessageWithBlock:(void(^)(void)) block;

-(void) viewDidLoad;


-(void) reloadData;

// cell是否在可见范围内
-(BOOL) cellIsVisible:(CGRect)cellRect;

// 根据orderSeq定位消息
-(void) locateMessageCellWithOrderSeqForReminder:(uint32_t)orderSeq tablePosition:(UITableViewScrollPosition)tablePosition;

- (void)scrollToBottom:(BOOL)animation;

// 请求到最底部
-(void) pullBottom;

-(void) adjustTableWithOffset:(CGFloat)offset;

- (void)stopScrollingAnimation;
// 添加消息
-(void) sendMessage:(WKMessageModel*)message;

-(void) removeMessage:(WKMessageModel*)message;

-(NSArray<WKMessageModel*>*) getSelectedMessages; // 获取被选中的消息

-(NSArray<UITableViewCell*>*) visibleCells;

// 设置多选模式
-(void) setMultipleOn:(BOOL)multiple selectedMessage:(WKMessageModel * _Nullable)messageModel;

// 定位到指定消息
-(void) locateMessageCell:(uint32_t)messageSeq;
-(void) locateMessageCellWithMessageSeq:(uint32_t)messageSeq;

-(NSArray<WKMessageModel*>*) getMessagesWithContentType:(NSInteger)contentType; // 根据正文类型获取消息当前列表里的消息

- (NSArray<NSString *> *)dates; // 当前列表的所有日期

-(NSArray<WKMessageModel*>*) messagesAtDate:(NSString*)date; // 获取日期对应的消息

/**
 获取可见的指定下标的cell

 */
-(UITableViewCell*) cellForRowAtIndex:(NSIndexPath*)indexPath;


-(void) refreshCell:(WKMessageModel*) messageModel;

@end

NS_ASSUME_NONNULL_END
