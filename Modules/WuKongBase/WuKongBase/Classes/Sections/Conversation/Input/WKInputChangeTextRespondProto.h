//
//  WKInputChangeTextRespondProto.h
//  Pods
//
//  Created by tt on 2019/12/15.
//
#import "WKConversationContext.h"



@protocol WKInputChangeRespondResult<NSObject>

@property(nonatomic,assign) BOOL changeText;  // return NO to not change text

@property(nonatomic,assign) BOOL next; // 是否允许下一个响应链执行

@end

@protocol WKInputChangeTextRespondProto <NSObject>

/**
 输入框委托事件
 */
@property(nonatomic,weak) id<WKConversationContext> conversationContext;

- (id<WKInputChangeRespondResult>)shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;

@end
