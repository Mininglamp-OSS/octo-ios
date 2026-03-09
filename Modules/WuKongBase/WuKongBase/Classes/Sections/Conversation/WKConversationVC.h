//
//  WKConversationVC.h
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import <UIKit/UIKit.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKBaseVC.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConversationVC : WKBaseVC

@property(nonatomic,strong) WKChannel *channel;

/// 定位的orderSeq （如果有值，则会定位到此order_seq的消息）
@property(nonatomic,assign) uint32_t locationAtOrderSeq;

// 显示最近会话的顶部视图
-(void) showTopView:(BOOL)show;

@end

NS_ASSUME_NONNULL_END
