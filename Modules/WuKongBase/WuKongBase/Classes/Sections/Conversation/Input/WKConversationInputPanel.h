//
//  WKConversationInputPanel.h
//  Session
//
//  Created by tt on 2018/9/29.
//


#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConversationContext.h"
#import "WKGrowingTextView.h"
#import "WKConversationPanel.h"
#import "WKMenusBtn.h"
#define SessionInputAnimateDuration 0.2f  // 输入框动画时间


@class WKConversationInputPanel;
@protocol WKConversationInputPanelDelegate <NSObject>

@optional


/**
 发送消息

 @param content <#content description#>
 */
-(void) inputPanel:(WKConversationInputPanel *)inputPanel sendMessage:(WKMessageContent*)content;
/**
 输入面板高度发送改变
 
 @param inputPanel 输入面板
 @param height 消息栏的高度没包含面板高度
 @param duration 动画时间
 @param animationCurve 动画类型
 */
- (void)inputPanelWillChangeHeight:(WKConversationInputPanel *)inputPanel height:(CGFloat)height duration:(NSTimeInterval)duration animationCurve:(int)animationCurve;


/**
 输入面板弹起活隐藏
 
 @param inputPanel <#inputPanel description#>
 @param up <#up description#>
 */
- (void)inputPanelUpOrDown:(WKConversationInputPanel *)inputPanel up:(BOOL)up;


/**
 发送文本消息

 @param inputPanel <#inputPanel description#>
 @param text <#text description#>
 */
- (void)inputPanelSend:(WKConversationInputPanel *)inputPanel text:(NSString*)text;


/// 正在输入中
/// @param inputPanel <#inputPanel description#>
-(void) inputPanelTyping:(WKConversationInputPanel *)inputPanel;



/// 切换面板
/// @param inputPanel <#inputPanel description#>
/// @param pointID 面板唯一ID
-(void) switchPanel:(WKConversationInputPanel *)inputPanel pointID:(NSString*)pointID;


/**
 录音发送

 @param inputPanel <#inputPanel description#>
 @param voiceData 录音文件数据
 @param seconds 录音秒数
 */
- (void)inputPanelSend:(WKConversationInputPanel *)inputPanel voiceData:(NSData*)voiceData seconds: (double)seconds;

// 触发@功能开始
-(void) inputPanelMentionStart:(WKConversationInputPanel *)inputPanel;

// 触发@功能结束
-(void) inputPanelMentionEnd:(WKConversationInputPanel *)inputPanel;

// 删除提及
-(void) inputPanel:(WKConversationInputPanel *)inputPanel delMention:(NSRange)range;

// @后面的关键字
-(void) inputPanel:(WKConversationInputPanel *)inputPanel mentionSearch:(NSString*)keyword;

// 文本改变
-(void) inputPanel:(WKConversationInputPanel*)inputPanel textChange:(NSString*)text;

@end

@interface WKConversationInputPanel : UIView
@property(nonatomic,strong) WKGrowingTextView *textView;

@property(nonatomic,strong) UIView *textViewRightView; // textView的右边view

@property(nonatomic,strong) WKMenusBtn *menusBtn; // 菜单按钮
@property(nonatomic,assign) BOOL showMenusBtn;

@property(nonatomic,strong) UIView *topView; // 输入框顶部试图

-(WKConversationInputPanel*) initWithConversationContext:(id<WKConversationContext>)context;

// 键盘高度
@property (assign, nonatomic) CGFloat keyboardHeight;

@property(nonatomic) CGFloat contentViewMinHeight; // 输入面板正文最小高度
// 输入框委托
@property(nonatomic,weak) id<WKConversationInputPanelDelegate> delegate;
// 会话委托
@property(nonatomic,weak) id<WKConversationContext> conversationContext;

@property(nonatomic,assign) BOOL disableAutoTop; // 是否禁用自动top


// 消息工具栏
@property(nonatomic,readonly) CGFloat contentViewChangeHeight; //输入面板变化的高度
@property(nonatomic,assign,readonly) CGFloat currentContentHeight; // 当前输入面板正文高度
@property(nonatomic,strong) WKConversationPanel *conversationPanel; // 面板对象

//当前面板的高度
-(CGFloat) currentPanelHeight;

// 调整输入框
-(void) adjustInput:(BOOL)animation;


// 重置输入框高度（如果输入框内有文本则计算在内）
-(void) resetCurrentInputHeight;


/**
 获取焦点

 @return <#return value description#>
 */
-(BOOL) becomeFirstResponder;
/**
 结束编辑
 */
-(void) endEditing;


/**
 切换面板
 
 @param pointId 面板pointId
 */
-(void) switchPanel:(NSString*)pointId;

// 底部偏移距离
-(CGFloat) bottomOffset;



/**
 重置输入框高度
 */
-(void) resetInputHeight;

/**
 当前输入面板高度
 
 @return <#return value description#>
 */
-(CGFloat) currentInputPanelHeight;


/**
 往输入框插入文本 (根据光标的位置插入)
 */
-(void) inputInsertText:(NSString *)text;

// 设置文本
-(void) inputSetText:(NSString *)text;

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

// 替换正在输入中的@
-(BOOL) replaceInputingMention:(NSString*)value;

/**
 输入选择范围

 @return <#return value description#>
 */
-(NSRange) inputSelectedRange;



/// 设置输入框顶部view
/// @param topView <#topView description#>
/// @param animateBlock <#animateBlock description#>
- (void)setTopView:(UIView *)topView animateBlock:(void(^)(void))animateBlock;

/**
 取消所有选中的功能项
 */
-(void) unSelectedFuncItems;


/// 消息工具栏是否弹起
-(BOOL) messageToolBarIsUp;


/// 键盘是否弹起
-(BOOL) keyboardIsUp;


/// 隐藏 输入框
/// @param hidden <#hidden description#>
/// @param animation <#animation description#>
-(void) setHidden:(BOOL)hidden animation:(BOOL)animation animationBlock:(void(^)(void))animationBlock;


//添加监听键盘
-(void)addKeyboardListen;

//移除监听
-(void)removeKeyboardListen;

// 停止功能组放大（apm列表）
-(void) stopFuncGroupZoom;

// 功能组是否放大状态
-(BOOL) isFuncGroupZooming;

// 更新和布局输入框右边视图
-(void) updateAndLayoutTextViewRightView;

@end
