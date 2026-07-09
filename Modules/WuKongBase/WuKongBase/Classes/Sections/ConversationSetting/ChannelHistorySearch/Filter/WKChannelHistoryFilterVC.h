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
@property (nonatomic, weak, nullable) id<WKChannelHistoryFilterVCDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
