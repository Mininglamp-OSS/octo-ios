//
//  WKSessionPanelProto.h
//  WuKongBase
//
//  Created by tt on 2019/12/15.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConversationContext.h"
NS_ASSUME_NONNULL_BEGIN

@protocol WKSessionPanelProto  <NSObject>


/**
 面板类型
 
 @return <#return value description#>
 */
-(NSInteger) panelType;

/**
 面板高度
 
 @return <#return value description#>
 */
-(CGFloat) panelHeight;
/**
 获取面板 根据channel
 
 @param channel channel对象
 @return <#return value description#>
 */
-(UIView*) panel:(WKChannel *)channel;

@optional


/**
 布局
 
 @param size 画布的大小
 */
-(void) layoutSize:(CGSize)size;


/**
 输入框委托事件
 */
@property(nonatomic,weak) id<WKConversationContext> conversationContext;

@end

NS_ASSUME_NONNULL_END
