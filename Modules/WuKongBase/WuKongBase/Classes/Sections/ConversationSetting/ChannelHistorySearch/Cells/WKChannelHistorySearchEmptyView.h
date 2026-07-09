//
//  WKChannelHistorySearchEmptyView.h
//  WuKongBase
//
//  搜索页中部占位视图：等待输入 / 无结果 / 加载中 / 加载失败 / 离线。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WKChannelHistorySearchEmptyMode) {
    WKChannelHistorySearchEmptyModeWaitingInput = 0, // 未输入关键词且无筛选
    WKChannelHistorySearchEmptyModeNoResults,        // 已搜索但无结果
    WKChannelHistorySearchEmptyModeLoading,          // 首屏加载中
    WKChannelHistorySearchEmptyModeError,            // 加载失败（含重试按钮）
    WKChannelHistorySearchEmptyModeOffline,          // 离线
};

@interface WKChannelHistorySearchEmptyView : UIView

@property (nonatomic, assign) WKChannelHistorySearchEmptyMode mode;
@property (nonatomic, copy, nullable) NSString *primaryText;    // 主文案；nil 用 mode 默认值
@property (nonatomic, copy, nullable) NSString *secondaryText;  // 副文案
@property (nonatomic, copy, nullable) void(^onRetry)(void);     // 重试回调（仅 Error 模式显示按钮）

- (void)applyMode:(WKChannelHistorySearchEmptyMode)mode
       primary:(nullable NSString *)primary
     secondary:(nullable NSString *)secondary;

@end

NS_ASSUME_NONNULL_END
