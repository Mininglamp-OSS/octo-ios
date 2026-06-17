//
//  WKChannelWebhookVC.h
//  WuKongBase
//
//  群消息推送（群入站 Webhook）列表页 —— 群信息「群消息推送」入口跳转目标。
//  对全员只读可见；按权限矩阵（群主/管理员管全部，普通成员管自己创建的）
//  控制长按菜单的可见项。
//

#import <UIKit/UIKit.h>
#import "WKBaseVC.h"

@class WKChannel;

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelWebhookVC : WKBaseVC

@property(nonatomic,strong) WKChannel *channel;
// 由跳转方传入：当前用户是否群主/管理员。普通成员仅能管自己创建的项。
@property(nonatomic,assign) BOOL isManagerOrCreator;

@end

NS_ASSUME_NONNULL_END
