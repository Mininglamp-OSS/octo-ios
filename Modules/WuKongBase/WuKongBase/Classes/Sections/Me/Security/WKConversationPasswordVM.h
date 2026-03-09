//
//  WKConversationPasswordVM.h
//  WuKongBase
//
//  Created by tt on 2020/10/30.
//

#import "WuKongBase.h"

NS_ASSUME_NONNULL_BEGIN

@class WKConversationPasswordVM;

@protocol WKConversationPasswordVMDelegate <NSObject>


@optional

-(void) conversationPasswordVMFinished:(WKConversationPasswordVM*)vm;

@end

@interface WKConversationPasswordVM : WKBaseTableVM

@property(nonatomic,weak) id<WKConversationPasswordVMDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
