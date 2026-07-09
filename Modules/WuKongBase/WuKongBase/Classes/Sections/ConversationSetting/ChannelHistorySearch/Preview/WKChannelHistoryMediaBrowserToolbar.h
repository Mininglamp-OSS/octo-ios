//
//  WKChannelHistoryMediaBrowserToolbar.h
//  WuKongBase
//
//  搜索"图片视频"大图浏览 toolbar — 顶部固定一条半透明 dark blur navbar:
//    ← Close     |     "1 / N"     |     "..." (定位 / 保存)
//  解决纯 floating 按钮在白图上失明的问题。
//

#import <Foundation/Foundation.h>
#import <YBImageBrowser/YBImageBrowser.h>
#import "WKChannelHistorySearchModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelHistoryMediaBrowserToolbar : NSObject <YBIBToolViewHandler, YBImageBrowserDelegate>

@property (nonatomic, weak, nullable) YBImageBrowser *browser;
@property (nonatomic, copy, nullable) void(^onLocateItem)(WKChannelHistorySearchItem *item);
@property (nonatomic, assign) NSInteger totalPages;
@property (nonatomic, assign) NSInteger initialPage;

@end

NS_ASSUME_NONNULL_END
