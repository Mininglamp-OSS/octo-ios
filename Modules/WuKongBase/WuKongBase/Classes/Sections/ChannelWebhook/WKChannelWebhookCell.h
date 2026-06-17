//
//  WKChannelWebhookCell.h
//  WuKongBase
//
//  群消息推送列表 cell：头像 + 名称 + 「已禁用」chip + 启停 Switch + meta 信息行。
//  长按手势由列表 VC 统一在 tableView 上挂，cell 本身只负责渲染。
//

#import <UIKit/UIKit.h>

@class WKIncomingWebhook;

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelWebhookCell : UITableViewCell

// 渲染 webhook 信息。creatorDisplayName 由 VC 解析（订阅缓存 / 自己 / 兜底空串）。
- (void)refreshWithWebhook:(WKIncomingWebhook *)webhook
        creatorDisplayName:(NSString * _Nullable)creatorDisplayName
              canManage:(BOOL)canManage
            switchLoading:(BOOL)loading;

// 启停切换回调（manage=NO 时 Switch 隐藏，不会触发）
@property(nonatomic,copy,nullable) void(^onSwitchToggle)(BOOL nextOn);

+ (CGFloat)cellHeight;
+ (UIImage *)defaultAvatarImage;

@end

NS_ASSUME_NONNULL_END
