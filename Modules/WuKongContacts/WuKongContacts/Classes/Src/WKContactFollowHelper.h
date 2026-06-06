//
//  WKContactFollowHelper.h
//  WuKongContacts
//
//  通讯录里联系人 / 群组的「添加到关注 / 取消关注」操作。
//  与会话列表 showAddToFollowDialogForModel: / 子区 showFollowMenuForThread:
//  同款 API 链 —— 复用 WKFollowService + WKFollowedKeysStore + WKCategoryService.moveGroup,
//  不绕过「DM/Group 必须落在非默认分组才能在 Follow tab 看见」这条规则。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKContactFollowHelper : NSObject

/// 同步查询：channel 是否已关注。channel 只支持 WK_PERSON / WK_GROUP，其它返回 NO。
+ (BOOL)isFollowedForChannel:(WKChannel *)channel;

/// 长按 cell 时调出菜单（已关注→"取消关注"，未关注→"添加到关注"）。
/// 「添加到关注」会再弹一个 action sheet 选非默认分组（与 WKThreadListVC 同款）。
/// onDidChange: API 成功 + WKFollowedKeysStore reload 完成后回调（成功才回调；失败仅 showMsg）。
+ (void)showFollowMenuForChannel:(WKChannel *)channel
                  atPointInWindow:(CGPoint)point
                    presentingVC:(UIViewController *)vc
                     onDidChange:(nullable void (^)(void))onDidChange;

@end

NS_ASSUME_NONNULL_END
