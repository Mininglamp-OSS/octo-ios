//
//  WKConversationContext.h
//  WuKongBase
//
//  Created by tt on 2020/1/15.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKMessageModel.h"
#import "WKInputMentionCache.h"
@class WKMessageCell;
@protocol WKConversationContext;
NS_ASSUME_NONNULL_BEGIN
@class WKConversationInputPanel;
@class WKMessageContextController;

@protocol WKConversationInputDelegate <NSObject>

// 输入框内容改变
-(void) conversationInputChange:(id<WKConversationContext>)context;


@end

@protocol WKConversationContext<NSObject>

@optional

//  获取当前会话的频道
@property(nonatomic,strong,readonly) WKChannel *channel;

// 输入框是否有输入文本
@property(nonatomic,assign,readonly) BOOL hasInputText;

@property(nonatomic,strong,nullable) UIView *inputTopView;


-(NSArray<WKMessageModel*>*) getMessagesWithContentType:(NSInteger)contentType;

-(NSArray<NSString*> *) dates; // 当前列表的所有日期

-(NSArray<WKMessageModel*>*) messagesAtDate:(NSString*)date; // 获取日期对应的消息

/**
 刷新消息对应的cell

 @param messageModel <#messageModel description#>
 */
-(void) refreshCell:(WKMessageModel*) messageModel;

/**
 获取可见的指定下标的cell

 */
-(UITableViewCell*) cellForRowAtIndex:(NSIndexPath*)indexPath;


// 获取当前文本的entity
-(NSArray<WKMessageEntity*>*) entities:(NSString*)text;
-(NSArray<WKMessageEntity*>*) entities:(NSString*)text mentionCache:(WKInputMentionCache*)mentionCache;


// 获取当前文本的@信息
-(WKMentionedInfo*) mentionedInfo:(NSString*)text;
-(WKMentionedInfo*) mentionedInfo:(NSString*)text mentionCache:(WKInputMentionCache*)mentionCache;
/**
 发送消息

 @param content <#content description#>
 */
-(WKMessage*) sendMessage:(WKMessageContent*)content;

// 发送文本消息
-(WKMessage*) sendTextMessage:(NSString*)text;

-(WKMessage*) sendTextMessage:(NSString*)text entities:(nullable NSArray<WKMessageEntity*>*)entities robotID:(nullable NSString*)robotID;
/**
 重发消息
 */
-(void) resendMessage:(WKMessage*)message;

/**
 转发消息
 */
-(void) forwardMessage:(WKMessageContent*)content;


/**
 将输入的文本发送出去
 */
-(void) inputTextToSend;

/**
 往输入框插入文本
 */
-(void) inputInsertText:(NSString *)text;

-(void) inputSetText:(NSString*)text;

/**
 删除范围内的文本
 
 @param range <#range description#>
 */
-(void) inputDeleteText:(NSRange)range;


/**
 获取当前输入框的文本
 
 @return <#return value description#>
 */
-(NSString*) inputText;



/**
 输入框的有效范围
 
 @return <#return value description#>
 */
-(NSRange) inputSelectedRange;



/**
 获取当前会话的频道信息
 
 @return <#return value description#>
 */
-(WKChannelInfo*) getChannelInfo;


/**
 显示当前会话的@用户列表
 */
-(void) showMentionUsers;

-(void) showMentionUsers:(NSString*)keyword;

-(void) hideMentionUsers;

/// 添加@
/// @param uid 被@人的uid
-(void) addMention:(NSString*)uid;



/// 设置多选模式
/// @param multiple <#multiple description#>
-(void) setMultipleOn:(BOOL)multiple selectedMessage:(WKMessageModel * _Nullable)messageModel;

// ---------- 回复相关 ----------

/// 回复
/// @param message <#message description#>
-(void) replyTo:(WKMessage*)message;

// 正在回复的消息
-(WKMessage*) replyingMessage;

// 回复的view
-(UIView*) replyView:(WKMessage*)message;

// 是否有回复
-(BOOL) hasReply;


// ---------- 编辑相关 ----------

/**
 编辑消息
 */
-(void) editTo:(WKMessage*)message;


// 正在编辑中的消息
-(WKMessage*) editingMessage;

// 编辑的view
-(UIView*) editView:(WKMessage*)message;

// 是否有编辑消息
-(BOOL) hasEdit;



/// 定位到指定的消息
/// @param messageSeq  通过消息messageSeq定位消息
-(void) locateMessageCell:(uint32_t)messageSeq;


-(void) inputBecomeFirstResponder;

/// 结束输入
-(void) endEditing;

// 长按消息cell
-(void) longPressMessageCell:(WKMessageCell*)messageCell gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;


///开始录音
- (void)startRecordingVoiceMessage;

// 功能组是否放大
-(BOOL) isFuncGroupZooming;

// 功能组停止放大
-(void) stopFuncGroupZoom;

-(UIViewController*) targetVC;

// 是否被禁言
-(BOOL) forbidden;

// 可见的cell
-(NSArray<UITableViewCell*>*) visibleCells;

// 是否显示最近会话顶部视图
-(void) showConversationTopView:(BOOL)show animated:(BOOL)animated;

// 刷新输入框
-(void) refreshInputView;

-(void) addInputDelegate:(id<WKConversationInputDelegate>)delegate;

-(void) removeInputDelegate:(id<WKConversationInputDelegate>)delegate;

// 导航到指定的消息
-(void) navigateToMessage:(WKMessageModel*)message;

@end

NS_ASSUME_NONNULL_END
