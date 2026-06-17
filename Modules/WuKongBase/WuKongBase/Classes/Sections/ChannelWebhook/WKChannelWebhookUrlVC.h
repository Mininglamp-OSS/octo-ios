//
//  WKChannelWebhookUrlVC.h
//  WuKongBase
//
//  一次性 URL 弹窗：create / regenerate 之后展示 webhook 推送地址 +
//  native / wecom / github 三种调用方式。token 与 URL 仅此一次返回，
//  关闭弹窗后无法再次查看。modalPresentationStyle=FormSheet present。
//

#import <UIKit/UIKit.h>

@class WKIncomingWebhook;

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelWebhookUrlVC : UIViewController

@property(nonatomic,strong) WKIncomingWebhook *webhook;

@end

NS_ASSUME_NONNULL_END
