//
//  WKChannelHistoryFileDownloader.m
//

#import "WKChannelHistoryFileDownloader.h"

@interface WKChannelHistoryFileDownloader () <NSURLSessionDownloadDelegate>
@property (nonatomic, copy) WKChannelHistoryFileDownloadHandler onComplete;
@property (nonatomic, copy, nullable) WKChannelHistoryFileProgressHandler onProgress;
@property (nonatomic, copy, nullable) NSString *destPath;
@end

@implementation WKChannelHistoryFileDownloader

+ (NSString *)cacheDir {
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WKChannelHistoryFile"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return dir;
}

+ (NSString *)safeFileNameFromUrl:(NSString *)remoteUrl fileName:(NSString *)fileName {
    NSString *name = [fileName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (name.length == 0) {
        NSURL *u = [NSURL URLWithString:remoteUrl];
        name = u.lastPathComponent;
    }
    if (name.length == 0) name = @"download";
    // 过滤路径分隔符
    name = [name stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    name = [name stringByReplacingOccurrencesOfString:@"\\" withString:@"_"];
    return name;
}

+ (NSURLSessionDownloadTask *)downloadRemoteUrl:(NSString *)remoteUrl
                                        fileName:(NSString *)fileName
                                         onProgress:(WKChannelHistoryFileProgressHandler)onProgress
                                      onComplete:(WKChannelHistoryFileDownloadHandler)onComplete {
    if (remoteUrl.length == 0 || !onComplete) {
        if (onComplete) {
            onComplete(nil, [NSError errorWithDomain:@"WKChannelHistoryFileDownloader"
                                                code:-1
                                            userInfo:@{ NSLocalizedDescriptionKey: @"empty url" }]);
        }
        return nil;
    }
    NSURL *url = [NSURL URLWithString:remoteUrl];
    if (!url) {
        onComplete(nil, [NSError errorWithDomain:@"WKChannelHistoryFileDownloader"
                                            code:-2
                                        userInfo:@{ NSLocalizedDescriptionKey: @"invalid url" }]);
        return nil;
    }

    NSString *safeName = [self safeFileNameFromUrl:remoteUrl fileName:fileName];
    NSString *destPath = [[self cacheDir] stringByAppendingPathComponent:safeName];

    // 缓存命中: 文件存在且非空 → 直接回调本地路径, 不重复下载。
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:destPath error:nil];
    if (attrs && [attrs[NSFileSize] unsignedLongLongValue] > 0) {
        onComplete([NSURL fileURLWithPath:destPath], nil);
        return nil;
    }

    WKChannelHistoryFileDownloader *holder = [WKChannelHistoryFileDownloader new];
    holder.onComplete = onComplete;
    holder.onProgress = onProgress;
    holder.destPath = destPath;

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    cfg.timeoutIntervalForRequest = 30;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg
                                                          delegate:holder
                                                     delegateQueue:[NSOperationQueue mainQueue]];
    NSURLSessionDownloadTask *task = [session downloadTaskWithURL:url];
    // 借助 task.priorityRetained 保活 holder — task 持有 session, session 持有 delegate(holder)。
    [task resume];
    return task;
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    if (self.onProgress && totalBytesExpectedToWrite > 0) {
        double p = (double)totalBytesWritten / (double)totalBytesExpectedToWrite;
        self.onProgress(p);
    }
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    NSError *moveErr = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    // 移动到目标路径前先确保父目录存在 & 旧文件被替换。
    NSString *dir = [self.destPath stringByDeletingLastPathComponent];
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm removeItemAtPath:self.destPath error:nil];
    BOOL ok = [fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:self.destPath] error:&moveErr];
    if (!ok) {
        if (self.onComplete) self.onComplete(nil, moveErr ?: [NSError errorWithDomain:@"WKChannelHistoryFileDownloader" code:-3 userInfo:nil]);
        return;
    }
    if (self.onComplete) self.onComplete([NSURL fileURLWithPath:self.destPath], nil);
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    if (error && self.onComplete) {
        // didFinishDownloadingToURL 没回包就先到 didCompleteWithError, 此时算失败。
        // 成功路径里 didFinishDownloadingToURL 已经清掉了 onComplete? — 没有, 我们没清。
        // 这里用一次性 guard: destPath 有文件视为成功路径已先回调。
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:self.destPath]) {
            self.onComplete(nil, error);
            self.onComplete = nil;
        }
    }
    [session finishTasksAndInvalidate];
}

@end
