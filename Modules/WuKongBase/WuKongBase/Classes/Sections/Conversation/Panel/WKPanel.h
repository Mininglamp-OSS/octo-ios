//
//  WKPanel.h
//  WuKongBase
//
//  Created by tt on 2020/1/11.
//

#import <Foundation/Foundation.h>
#import "WKConversationContext.h"
#import "WKInputChangeTextRespondProto.h"
NS_ASSUME_NONNULL_BEGIN


@interface WKPanel : UIView

-(instancetype) initWithContext:(id<WKConversationContext>) context;

@property(nonatomic,weak) id<WKConversationContext> context;

@property(nonatomic,strong) UIView *contentView;

/**
 往输入框插入文本
 */
-(void) inputInsertText:(NSString *)text;

-(void) layoutPanel:(CGFloat)height;


@end

NS_ASSUME_NONNULL_END
