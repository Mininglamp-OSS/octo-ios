//
//  WKConversationPanel.h
//  Session
//
//  Created by tt on 2018/10/9.
//
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKSessionPanelProto.h"
#import "WKConversationContext.h"
#define WKPanelDefaultHeight 302.0f // 面板默认高度

@interface WKConversationPanel : UIView

/**
 输入框委托事件
 */
//@property(nonatomic,weak) id<WKInputProto> inputDelegate;
// 会话委托
@property(nonatomic,weak) id<WKConversationContext> conversationContext;

/**
 切换面板
 
 @param channel 频道对象
 @param pointId 面板类型
 @return 是否切换成功
 */
-(BOOL) switchPanel:(WKChannel*)channel pointId:(NSString*)pointId;


/**
 当前面板高度
 
 @return <#return value description#>
 */
-(CGFloat) currentPanelHeight;

// 当前面板pintId
-(NSString*) currentPanelPointId;


/**
 调整面板
 
 @param panelHeight 面板的高度
 */
-(void) adjustPanel:(CGFloat)panelHeight keyboardHeight:(CGFloat)keyboardHeight;

@end
