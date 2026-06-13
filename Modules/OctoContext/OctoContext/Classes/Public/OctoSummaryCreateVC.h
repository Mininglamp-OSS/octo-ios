//
//  OctoSummaryCreateVC.h
//  OctoContext
//
//  创建总结页 (create-summary.html / create-summary-filled.html)。
//  Modal full-screen,从列表页右上 + 按钮唤起。
//

#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OctoSummaryCreateVC : WKBaseVC

/// 调用方传入的发起来源(默认 BY_GROUP),从聊天页唤起总结时可指定。
@property(nonatomic, copy, nullable) NSString *originChannelId;
@property(nonatomic, assign) NSInteger originChannelType;

/// "编辑取消/失败任务" 流程的预填数据。设了之后, 进入页面立刻把主题文字 +
/// 已选 sources 灌进去, 用户做二次编辑后调 createSummary 起一条新任务。
@property(nonatomic, copy, nullable) NSString *prefilledTopic;
@property(nonatomic, copy, nullable) NSArray<OctoSourceItem *> *prefilledSources;

/// 提交成功时 HUD 文案。默认 "已创建总结任务" (从智能总结列表 FAB 进入时, 用户
/// 已经在列表页, 简短确认即可)。从聊天详情星星入口进入时, 调用方可改成
/// "已开始生成总结，可到 智能总结 查看进度" 这种引导式文案。
@property(nonatomic, copy, nullable) NSString *submitSuccessHUDText;

@end

NS_ASSUME_NONNULL_END
