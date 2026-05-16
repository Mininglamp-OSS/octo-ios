//
//  WKConversationPasswordVC.h
//  WuKongBase
//
//  Created by tt on 2020/10/30.
//

#import "WuKongBase.h"
#import "WKConversationPasswordVM.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConversationPasswordVC : WKBaseTableVC<WKConversationPasswordVM*>

@property(nonatomic,copy) void(^onFinish)(void);

@end

NS_ASSUME_NONNULL_END
