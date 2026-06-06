//
//  WKContactFollowHelper.m
//  WuKongContacts
//

#import "WKContactFollowHelper.h"
#import <WuKongBase/WKFollowService.h>
#import <WuKongBase/WKFollowedKeysStore.h>
#import <WuKongBase/WKCategoryService.h>
#import <WuKongBase/WKFloatingMenu.h>
#import <WuKongBase/WKSidebarItemEntity.h>
#import <WuKongBase/WKCategoryEntity.h>
#import <WuKongBase/WKConversationListVM.h>
#import <WuKongBase/WKFollowCategorySheet.h>
#import <PromiseKit/PromiseKit.h>

// 所有文案都已在 WuKongBase 的 Localizable.strings 维护（中/英齐全），借用其
// bundle —— 否则要在 WuKongContacts 重复一份翻译且容易漂移。
#define WKLBase(s) [(s) LocalizedWithClass:[WKFollowedKeysStore class]]

@implementation WKContactFollowHelper

+ (WKFollowTargetType)targetTypeForChannel:(WKChannel *)channel {
    if (channel.channelType == WK_PERSON) return WKFollowTargetTypeDM;
    return WKFollowTargetTypeChannel; // 兜底当 group 处理；调用方保证只传 PERSON/GROUP
}

+ (BOOL)isFollowedForChannel:(WKChannel *)channel {
    if (!channel || channel.channelId.length == 0) return NO;
    if (channel.channelType != WK_PERSON && channel.channelType != WK_GROUP) return NO;
    WKFollowTargetType type = [self targetTypeForChannel:channel];
    return [[WKFollowedKeysStore shared] isFollowedWithType:type targetId:channel.channelId];
}

#pragma mark - Menu

+ (void)showFollowMenuForChannel:(WKChannel *)channel
                  atPointInWindow:(CGPoint)point
                    presentingVC:(UIViewController *)vc
                     onDidChange:(void (^)(void))onDidChange {
    if (!channel || channel.channelId.length == 0) return;
    if (channel.channelType != WK_PERSON && channel.channelType != WK_GROUP) return;

    BOOL isFollowed = [self isFollowedForChannel:channel];
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    if (isFollowed) {
        [items addObject:@{
            @"title": WKLBase(@"取消关注"),
            @"icon":  [WKFloatingMenu iconUnfollow],
            @"action": ^{ [self performUnfollowForChannel:channel presentingVC:vc onDidChange:onDidChange]; }
        }];
    } else {
        [items addObject:@{
            @"title": WKLBase(@"添加到关注"),
            @"icon":  [WKFloatingMenu iconFollow],
            @"action": ^{ [self pickCategoryAndFollowChannel:channel presentingVC:vc onDidChange:onDidChange]; }
        }];
    }
    [WKFloatingMenu showItems:items atPoint:point];

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];
}

#pragma mark - Unfollow

+ (void)performUnfollowForChannel:(WKChannel *)channel
                     presentingVC:(UIViewController *)vc
                      onDidChange:(void (^)(void))onDidChange {
    AnyPromise *p;
    if (channel.channelType == WK_PERSON) {
        p = [[WKFollowService shared] unfollowDM:channel.channelId];
    } else {
        p = [[WKFollowService shared] unfollowChannel:channel.channelId];
    }
    p.then(^id(id _) {
        return [[WKFollowedKeysStore shared] reload];
    }).then(^(id _) {
        [vc.view showMsg:WKLBase(@"已取消关注")];
        if (onDidChange) onDidChange();
        return (id)nil;
    }).catch(^(NSError *err) {
        [vc.view showMsg:err.domain ?: WKLBase(@"取消关注失败")];
    });
}

#pragma mark - Follow (with category picker)

+ (void)pickCategoryAndFollowChannel:(WKChannel *)channel
                        presentingVC:(UIViewController *)vc
                         onDidChange:(void (^)(void))onDidChange {
    // 关注 tab 只显示非默认分组里的内容 —— 默认分组在 follow tab 隐藏（与
    // WKConversationListVC.pickFollowCategoryWithTitle:onPick: 同款过滤规则）。
    NSArray<WKCategoryEntity *> *all = [WKConversationListVM shared].categoryList;
    NSMutableArray<WKCategoryEntity *> *cats = [NSMutableArray array];
    for (WKCategoryEntity *cat in all) {
        if (cat.is_default) continue;
        if (cat.category_id.length == 0) continue;
        [cats addObject:cat];
    }

    // 0 个可用分组：与会话列表逻辑对齐 —— 直接走"创建分组"流程，建完之后落到新分组
    if (cats.count == 0) {
        [self showCreateCategoryDialogOnVC:vc completion:^(WKCategoryEntity *cat) {
            [self performFollowChannel:channel categoryId:cat.category_id categoryName:cat.name
                          presentingVC:vc onDidChange:onDidChange];
        }];
        return;
    }

    // 有分组：弹与会话列表完全同款的底部 sheet（WKFollowCategorySheet），
    // 用户选中某行或点"+ 新建分组"都走同一条 perform 路径
    [WKFollowCategorySheet showWithTitle:WKLBase(@"添加到关注")
                              categories:cats
                      selectedCategoryId:nil
                           showCreateRow:YES
                                  onPick:^(NSString *catId, NSString *catName) {
        if (catId.length == 0) return;
        [self performFollowChannel:channel categoryId:catId categoryName:catName
                      presentingVC:vc onDidChange:onDidChange];
    }
                       onCreateRequested:^{
        [self showCreateCategoryDialogOnVC:vc completion:^(WKCategoryEntity *cat) {
            [self performFollowChannel:channel categoryId:cat.category_id categoryName:cat.name
                          presentingVC:vc onDidChange:onDidChange];
        }];
    }];
}

/// 与 WKConversationListVC.showCreateCategoryDialogWithCompletion: 等价的创建分组弹窗。
/// 这里复制一份（不抽公共类）—— 体量小（~20 行），且依赖 conversationList VM 同步追加,
/// 抽公共类反而要把 VM 注入回来。3 行重复优于早抽象（项目规范 CLAUDE.md）。
+ (void)showCreateCategoryDialogOnVC:(UIViewController *)vc
                            completion:(void (^)(WKCategoryEntity *cat))completion {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if (spaceId.length == 0) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:WKLBase(@"创建分组")
                                                                    message:nil
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = WKLBase(@"请输入分组名称");
    }];
    [alert addAction:[UIAlertAction actionWithTitle:WKLBase(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:WKLBase(@"创建") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        if (name.length == 0) return;
        [[WKCategoryService shared] createCategory:spaceId name:name].then(^(WKCategoryEntity *cat) {
            if (cat.category_id.length == 0) return;
            // 同步追加到 VM —— 与 WKConversationListVC.onFollowCategorySheetCreateTap 同理,
            // 避免下游 categoryNameById: 异步未到时 toast 缺失。
            NSMutableArray *m = [[WKConversationListVM shared].categoryList mutableCopy] ?: [NSMutableArray array];
            BOOL exists = NO;
            for (WKCategoryEntity *c in m) {
                if ([c.category_id isEqualToString:cat.category_id]) { exists = YES; break; }
            }
            if (!exists) [m addObject:cat];
            [WKConversationListVM shared].categoryList = m;
            if (completion) completion(cat);
        }).catch(^(NSError *error) {
            [vc.view showMsg:error.domain ?: WKLBase(@"添加到关注失败")];
        });
    }]];
    [vc presentViewController:alert animated:YES completion:nil];
}

+ (void)performFollowChannel:(WKChannel *)channel
                   categoryId:(NSString *)categoryId
                 categoryName:(NSString *)categoryName
                presentingVC:(UIViewController *)vc
                 onDidChange:(void (^)(void))onDidChange {
    AnyPromise *chain;
    if (channel.channelType == WK_PERSON) {
        chain = [[WKFollowService shared] followDM:channel.channelId categoryId:categoryId];
    } else {
        // 群：refollow → moveGroup 落到非默认分组（与 WKConversationListVC.performFollowGroup: 同款）
        NSString *groupNo = channel.channelId;
        chain = [[WKFollowService shared] refollowChannel:groupNo].then(^id(id _) {
            return [[WKCategoryService shared] moveGroup:groupNo toCategoryId:categoryId];
        });
    }
    chain.then(^id(id _) {
        return [[WKFollowedKeysStore shared] reload];
    }).then(^(id _) {
        NSString *fmt = WKLBase(@"已添加到「%@」");
        [vc.view showMsg:[NSString stringWithFormat:fmt, categoryName ?: @""]];
        if (onDidChange) onDidChange();
        return (id)nil;
    }).catch(^(NSError *err) {
        [vc.view showMsg:err.domain ?: WKLBase(@"添加到关注失败")];
    });
}

@end
