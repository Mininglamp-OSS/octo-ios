//
//  OctoSummaryActionSheet.m
//  OctoContext
//

#import "OctoSummaryActionSheet.h"
#import <WuKongBase/WuKongBase.h>

@implementation OctoSummaryActionSheet

+ (void)presentInVC:(UIViewController *)vc
             detail:(OctoSummaryDetail *)detail
           onAction:(void (^)(OctoSummaryActionType))onAction {

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    BOOL completed = (detail.status == OctoTaskStatusCompleted);
    BOOL processing = (detail.status == OctoTaskStatusProcessing
                       || detail.status == OctoTaskStatusPending
                       || detail.status == OctoTaskStatusWaitingConfirm);
    BOOL canEdit = detail.permissions ? detail.permissions.canEdit : completed;
    BOOL byPerson = (detail.summaryMode == OctoSummaryModeByPerson);

    if (completed && canEdit) {
        [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"编辑") style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *_) { if (onAction) onAction(OctoSummaryActionEdit); }]];
    }
    if (completed) {
        [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"转发到聊天") style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *_) { if (onAction) onAction(OctoSummaryActionForwardToChat); }]];
        [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"重新生成") style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *_) { if (onAction) onAction(OctoSummaryActionRegenerate); }]];
    }
    if (byPerson && (completed || processing)) {
        [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"提交我的") style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *_) { if (onAction) onAction(OctoSummaryActionSubmitMine); }]];
    }
    if (processing) {
        [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"取消任务") style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *_) { if (onAction) onAction(OctoSummaryActionCancel); }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"删除") style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *_) { if (onAction) onAction(OctoSummaryActionDelete); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    // iPad / Designed-for-iPad on Mac 上 actionSheet 走 popover, 必须有非 nil 的
    // sourceView + sourceRect (或 barButtonItem), 否则 present 时抛
    // NSGenericException: "UIPopoverPresentationController ... should have a
    // non-nil sourceView or barButtonItem set before the presentation occurs.
    // 手头拿不到触发按钮的引用, 兜底锚到 presenter.view 中心并去掉箭头。
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = vc.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(vc.view.bounds.size.width / 2,
                                                                    vc.view.bounds.size.height / 2, 0, 0);
        sheet.popoverPresentationController.permittedArrowDirections = 0;
    }
    [vc presentViewController:sheet animated:YES completion:nil];
}

@end
