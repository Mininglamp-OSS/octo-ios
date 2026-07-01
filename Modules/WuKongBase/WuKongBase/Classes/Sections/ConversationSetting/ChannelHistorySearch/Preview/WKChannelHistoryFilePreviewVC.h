//
//  WKChannelHistoryFilePreviewVC.h
//  WuKongBase
//
//  搜索"文件"tab 的文件预览页 —— 子类化 WKSafeFilePreviewVC, 把右上角"分享"按钮
//  替换为 "..." 菜单 (定位到聊天位置 / 保存文件)。
//

#import "WKSafeFilePreviewVC.h"
#import "WKChannelHistorySearchModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelHistoryFilePreviewVC : WKSafeFilePreviewVC

/// 搜索命中项, 用于「定位到聊天位置」回调上下文。
@property (nonatomic, strong, nullable) WKChannelHistorySearchItem *historyItem;
/// 「定位到聊天位置」回调 (item.canLocate == NO 时菜单项隐藏)。
@property (nonatomic, copy, nullable) void(^onLocate)(WKChannelHistorySearchItem *item);

@end

NS_ASSUME_NONNULL_END
