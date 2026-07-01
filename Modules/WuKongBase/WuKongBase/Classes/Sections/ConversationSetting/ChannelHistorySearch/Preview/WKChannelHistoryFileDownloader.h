//
//  WKChannelHistoryFileDownloader.h
//  WuKongBase
//
//  把搜索结果的远端文件下载到 temp 目录, 命名按真实文件名 (避免 QLPreview 标题显示
//  16 进制), 拿到本地路径后回调。同一 URL 命中已下载缓存则直接复用, 不重复拉。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 进度 0..1。完成时 error == nil 且 localURL 有值; 失败时 error 非空。
typedef void(^WKChannelHistoryFileDownloadHandler)(NSURL * _Nullable localURL, NSError * _Nullable error);
typedef void(^WKChannelHistoryFileProgressHandler)(double progress);

@interface WKChannelHistoryFileDownloader : NSObject

/// 下载 remoteUrl 到 temp/WKChannelHistoryFile/<realName>。
/// 同一 (remoteUrl, fileName) 命中缓存时直接 completion(localURL, nil)。
/// 返回的 task 可用于取消。
+ (NSURLSessionDownloadTask * _Nullable)downloadRemoteUrl:(NSString *)remoteUrl
                                                  fileName:(nullable NSString *)fileName
                                                   onProgress:(nullable WKChannelHistoryFileProgressHandler)onProgress
                                                onComplete:(WKChannelHistoryFileDownloadHandler)onComplete;

@end

NS_ASSUME_NONNULL_END
