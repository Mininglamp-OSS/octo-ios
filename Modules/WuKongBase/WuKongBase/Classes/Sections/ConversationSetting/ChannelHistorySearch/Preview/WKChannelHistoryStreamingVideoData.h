//
//  WKChannelHistoryStreamingVideoData.h
//  WuKongBase
//
//  搜索"图片视频"tab 大图浏览专用视频数据 —— 直接把 URL (远端 or 本地缓存)
//  喂给 AVPlayer 做流式播放。命中 WKChannelHistoryFileDownloader 的 tmp
//  缓存则用 file:// (瞬间起播), 否则走 https 边下边播。
//

#import <Foundation/Foundation.h>
#import <YBImageBrowser/YBImageBrowser.h>

@class WKChannelHistorySearchItem;

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelHistoryStreamingVideoData : NSObject <YBIBDataProtocol>

/// 视频源: 优先本地 file:// (缓存命中), 否则远端 https 流式播放。
@property (nonatomic, strong) NSURL *videoURL;
/// 远端 URL — 用于「保存到相册」时按此下载 (即便 videoURL 已经是本地)。
@property (nonatomic, copy, nullable) NSString *remoteURLString;
/// 建议下载后保存的文件名, 传给 WKChannelHistoryFileDownloader 做真实名映射。
@property (nonatomic, copy, nullable) NSString *fileName;
/// 封面图 (强引用, 用于 AVPlayer 首帧未到位时占位)。
@property (nonatomic, strong, nullable) UIImage *coverImage;
/// 业务上下文 (与 YBIBImageData.extraData 同语义) — 搜索项放这里, 供 toolbar 定位使用。
@property (nonatomic, strong, nullable) id extraData;

@end

NS_ASSUME_NONNULL_END
