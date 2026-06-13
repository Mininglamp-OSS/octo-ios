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
    [vc presentViewController:sheet animated:YES completion:nil];
}

@end
