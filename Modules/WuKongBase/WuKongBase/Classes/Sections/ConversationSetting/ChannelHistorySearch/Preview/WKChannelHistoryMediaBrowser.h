//
//  WKChannelHistoryMediaBrowser.h
//  WuKongBase
//
//  把"图片视频"tab 的所有可浏览项构造为 YBImageBrowser 数据源 (图片+视频混排,
//  左右滑动可切换), 并挂上自定义 toolbar (右上角 ... 菜单: 定位 / 保存)。
//

#import <Foundation/Foundation.h>
#import "WKChannelHistorySearchModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelHistoryMediaBrowser : NSObject

/// 判定视频项是否有可播放的 URL (服务端字段 或 本地 WKMessageDB 兜底)。
/// 服务端 messages/_search_media 视频响应目前存在缺 URL 字段的情况;
/// 若两条来源都拿不到, 调用方应当直接跳会话页定位到该消息 (让 SDK 的下载
/// + 播放链路兜底), 而不是打开浏览器给用户看一张假的静态封面。
+ (BOOL)isVideoItemPlayable:(WKChannelHistorySearchItem *)item;

/// 打开大图浏览。
/// @param items       当前 tab 的所有 media 项（保持现有顺序，用作浏览器数据源）
/// @param tappedItem  用户点击的那一项；内部按"它在最终 dataSource 中的真实位置"定位初始页
/// @param onLocate   「定位到聊天位置」回调；菜单仅在 messageSeq > 0 时显示
+ (void)presentFromItems:(NSArray<WKChannelHistorySearchItem *> *)items
                tappedItem:(WKChannelHistorySearchItem *)tappedItem
                  onLocate:(nullable void(^)(WKChannelHistorySearchItem *item))onLocate;

@end

NS_ASSUME_NONNULL_END
