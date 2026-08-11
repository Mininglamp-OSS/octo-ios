//
//  WKConversationListVC.h
//  WuKongBase
//
//  Created by tt on 2019/12/15.
//

#import <UIKit/UIKit.h>
#import "WKBaseVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationListVC : WKBaseVC

-(instancetype) initWithTitle:(NSString*)title;

-(void) setCustomTitle:(NSString*)title;

/// 底部 tabbar「消息」item 被双击（宿主 WKMainTabController 判定并转发）。
/// 与页内双击「最近」tab 同一个交互：定位到下一个未读会话，走完最后一个回到第一个。
/// 当前不在「最近」tab / 没有任何未读时 no-op —— 判定收在实现里，调用方不用关心。
-(void) handleMessageTabDoubleTap;
@end

NS_ASSUME_NONNULL_END
