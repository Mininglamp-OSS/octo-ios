//
//  WKConversationContextImpl.h
//  WuKongBase
//
//  Created by tt on 2022/5/19.
//

#import <Foundation/Foundation.h>
#import "WKConversationContext.h"
#import "WKConversationVM.h"
#import "WKConversationView.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConversationContextImpl : NSObject<WKConversationContext>

-(instancetype) initWithChannel:(WKChannel*)channel conersationView:(WKConversationView*)conversationView conversationVM:(WKConversationVM*)conversationVM;


-(void) callConversationInputChangeDelegate;

-(void) layoutMentionUserHandle;

@end

NS_ASSUME_NONNULL_END
