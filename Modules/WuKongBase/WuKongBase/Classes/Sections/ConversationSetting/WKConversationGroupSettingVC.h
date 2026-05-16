//
//  WKConversationGroupSettingVC.h
//  AFNetworking
//
//  Created by tt on 2020/1/21.
//

#import "WKBaseVC.h"
#import "WKBaseTableVC.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConversationSettingVM.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConversationGroupSettingVC : WKBaseTableVC<WKConversationSettingVM*>

@property(nonatomic,strong) WKChannel *channel;

@property(nonatomic,weak) id<WKConversationContext> context;
@end

NS_ASSUME_NONNULL_END
