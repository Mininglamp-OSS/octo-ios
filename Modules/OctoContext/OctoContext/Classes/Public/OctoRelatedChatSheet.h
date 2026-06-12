//
//  OctoRelatedChatSheet.h
//  OctoContext
//
//  详情页点击 [N] citation 徽章弹出的"关联聊天记录"底部 sheet。
//
//  数据流: 直接消费 OctoCitationItem.contextBefore + 命中条 + contextAfter,
//  无需新接口。点击命中条的 "原消息→" 调 WKConversationRouter 跳到聊天页。
//

#import <UIKit/UIKit.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OctoRelatedChatSheet : UIViewController

+ (void)presentInVC:(UIViewController *)host
          citations:(NSArray<OctoCitationItem *> *)citations
        activeIndex:(NSInteger)activeCitationIndex;

@end

NS_ASSUME_NONNULL_END
