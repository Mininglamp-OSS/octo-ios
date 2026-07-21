//
//  WKChannelHistoryFilterVC.h
//  WuKongBase
//
//  搜索页"筛选"半屏（modal）：发送人 / 日期 / 排序 + 底部重置/应用。
//

#import <UIKit/UIKit.h>
#import "WKChannelHistorySearchModels.h"

@class WKChannel;
@class WKChannelHistoryFilterVC;

NS_ASSUME_NONNULL_BEGIN

@protocol WKChannelHistoryFilterVCDelegate <NSObject>
- (void)channelHistoryFilterVC:(WKChannelHistoryFilterVC *)vc didApplyFilter:(WKChannelHistorySearchFilter *)filter;
@end

@interface WKChannelHistoryFilterVC : UIViewController

@property (nonatomic, strong) WKChannel *channel;
/// 当前筛选条件草稿（外部传入，本 VC 内部会复制一份编辑）。
@property (nonatomic, strong) WKChannelHistorySearchFilter *draft;
/// 全局搜索模式：展示 发送者(好友候选)/所在群聊或子区/包含成员/聊天类型 等全局专用筛选。
/// 默认 NO（会话内搜索保持原有 发送人[花名册]/日期/排序）。
@property (nonatomic, assign) BOOL globalMode;
/// 是否展示"消息类型"多选（全局「聊天记录」用；默认 NO，会话内搜索不受影响）。
@property (nonatomic, assign) BOOL showContentTypes;
/// 是否展示"文件类型"多选（全局「文件」用；默认 NO）。
@property (nonatomic, assign) BOOL showFileTypes;
@property (nonatomic, weak, nullable) id<WKChannelHistoryFilterVCDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
