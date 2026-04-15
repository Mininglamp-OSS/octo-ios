//
//  WKForwardSelectVC.h
//  WuKongBase
//
//  转发选择会话页面（群聊/私聊 tab + 分组 + 子区）
//

#import "WKBaseVC.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKForwardSelectVC : WKBaseVC

@property (nonatomic, copy, nullable) void(^onSelect)(WKChannel *channel);

@end

NS_ASSUME_NONNULL_END
