//
//  WKFileDownloadTask.m
//  WuKongDataSource
//
//  Created by tt on 2020/1/16.
//

#import "WKFileDownloadTask.h"
#import <WuKongIMSDK/WKFileUtil.h>
#import <GZIP/GZIP.h>
@interface WKFileDownloadTask ()
@property(nonatomic,strong) NSURLSessionDownloadTask *task;
@property(nonatomic,assign) BOOL cancelled;
@property(nonatomic,assign) BOOL finished;
@property(nonatomic,assign) BOOL isolatedCancellation;
@end

@implementation WKFileDownloadTask

- (instancetype)initWithMessage:(WKMessage *)message {
    self = [super initWithMessage:message];
    if(self) {
        [self initTask];
    }
    return self;
}

-(void) initTask {
    // 普通文件及合并转发支持取消的语音、视频使用独立临时文件和回调隔离。
    self.isolatedCancellation = self.message.contentType == WK_FILE
        || self.message.contentType == WK_VOICE || self.message.contentType == WK_SMALLVIDEO;
     id<WKMediaProto> media = [self getMessageMedia:self.message];
    if(!media) {
        WKLogDebug(@"不是多媒体消息！[WKFileDownloadTask]");
        self.status = WKTaskStatusError;
        self.error = [NSError errorWithDomain:@"不是多媒体消息！" code:101 userInfo:nil];
        [self update];
        return;
    }
    if(!media.remoteUrl) {
        WKLogWarn(@"remoteUrl为空，没啥东西下载的！😢");
        self.status = WKTaskStatusError;
        self.error = [NSError errorWithDomain:@"remoteUrl为空，没啥东西下载的！" code:102 userInfo:nil];
        [self update];
        return;
    }
    NSString *realLocalPath = media.thumbPath;
    if(self.message.contentType == WK_EMOJI_STICKER ||  self.message.contentType == WK_LOTTIE_STICKER) {
        realLocalPath = media.localPath;
    } if( self.message.contentType == WK_SMALLVIDEO || self.message.contentType == WK_FILE) {
        realLocalPath = media.localPath;
    }
    if([WKFileUtil fileIsExistOfPath:realLocalPath]) {
        self.status = WKTaskStatusSuccess;
        [self update];
        return;
    }
    
    NSString *downloadURL = media.remoteUrl;
    if(![downloadURL hasPrefix:@"http"]) {
        downloadURL = [[NSURL URLWithString:media.remoteUrl relativeToURL:[NSURL URLWithString:[WKApp shared].config.fileBaseUrl]] absoluteString];
    }
    NSString *storePath = [NSString stringWithFormat:@"%@_tmp",media.thumbPath];
    if(self.message.contentType == WK_SMALLVIDEO || self.message.contentType == WK_FILE) {
        storePath = [NSString stringWithFormat:@"%@_tmp",media.localPath];
    }
    // 每个下载使用独立临时文件，避免取消后立即重试与旧任务清理相互干扰。
    if (self.isolatedCancellation) {
        storePath = [storePath stringByAppendingFormat:@"_%@", NSUUID.UUID.UUIDString];
    }
    BOOL isolatedCancellation = self.isolatedCancellation;
    __weak typeof(self) weakSelf = self;
    NSString *channelDir = [storePath stringByDeletingLastPathComponent];
    [WKFileUtil createDirectoryIfNotExist:channelDir];
    self.task = [[WKAPIClient sharedClient] createDownloadTask:[[self getVoiceFullUrl:media.remoteUrl] absoluteString] storePath:storePath progress:^(NSProgress *  downloadProgress) {
        if (!isolatedCancellation) {
            weakSelf.progress = downloadProgress.fractionCompleted;
            weakSelf.status = WKTaskStatusProgressing;
            [weakSelf update];
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf.cancelled || weakSelf.finished) return;
            weakSelf.progress = downloadProgress.fractionCompleted;
            weakSelf.status = WKTaskStatusProgressing;
            [weakSelf update];
        });
    } completeCallback:^(NSError * _Nullable error) {
        if (!isolatedCancellation) {
            NSError *resultError = error;
            if (!resultError) {
                [[NSFileManager defaultManager] moveItemAtPath:storePath toPath:realLocalPath error:&resultError];
            }
            weakSelf.status = resultError ? WKTaskStatusError : WKTaskStatusSuccess;
            weakSelf.error = resultError;
            [weakSelf update];
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            WKFileDownloadTask *task = weakSelf;
            if (!task) {
                [[NSFileManager defaultManager] removeItemAtPath:storePath error:nil];
                return;
            }
            task.finished = YES;
            if (task.cancelled || error) {
                [[NSFileManager defaultManager] removeItemAtPath:storePath error:nil];
                task.status = WKTaskStatusError;
                task.error = task.cancelled
                    ? [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]
                    : error;
                if (!task.cancelled) WKLogError(@"download fail -> %@", error);
            } else {
                NSError *moveError = nil;
                [[NSFileManager defaultManager] moveItemAtPath:storePath toPath:realLocalPath error:&moveError];
                task.status = moveError ? WKTaskStatusError : WKTaskStatusSuccess;
                task.error = moveError;
                if (moveError) {
                    [[NSFileManager defaultManager] removeItemAtPath:storePath error:nil];
                    WKLogError(@"复制文件失败！%@", moveError);
                }
            }
            [task update];
        });
    }];
}

-(NSURL*) getVoiceFullUrl:(NSString*)url{
    return [[WKApp shared] getFileFullUrl:url];
}

-(void) resume {
    // Cache hits and validation failures finish during init, before listeners are registered.
    if (self.isolatedCancellation && !self.task) {
        [self update];
        return;
    }
    [self.task resume];
}

-(void) cancel {
    if (self.isolatedCancellation) {
        if (self.status == WKTaskStatusSuccess || self.status == WKTaskStatusError) return;
        self.cancelled = YES;
        // 立即标记取消，阻止排队的进度或完成回调再次更新状态。
        self.status = WKTaskStatusError;
        self.error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
    }
    [self.task cancel];
}

- (void)suspend {
   [self.task suspend];
}

-(id<WKMediaProto>) getMessageMedia:(WKMessage*)message {
    
    if([message.content conformsToProtocol:@protocol(WKMediaProto)] ) {
        return (id<WKMediaProto>)message.content;
    }
    return nil;
}

@end
