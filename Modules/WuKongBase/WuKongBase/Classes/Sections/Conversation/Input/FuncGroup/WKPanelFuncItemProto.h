//
//  WKPanelFuncItem.h
//  WuKongBase
//
//  Created by tt on 2020/2/23.
//

#import <Foundation/Foundation.h>
#import "WKConversationInputPanel.h"
#import "WKFuncItemButton.h"
NS_ASSUME_NONNULL_BEGIN

@protocol WKPanelFuncItemProto <NSObject>

-(NSString*) sid; // 唯一ID
/**
 item按钮

 @return <#return value description#>
 */
-(WKFuncItemButton*) itemButton:(WKConversationInputPanel*)inputPanel;

// 是否支持
-(BOOL) support:(id<WKConversationContext>)context;

-(NSString*) title;

-(UIImage*) itemIcon;

-(BOOL) allowEdit; // 是否允许编辑

-(NSInteger) sort;

-(BOOL) disable; // 是否禁用

-(WKChannelType) channelType; // 所属频道类型

@end


NS_ASSUME_NONNULL_END
