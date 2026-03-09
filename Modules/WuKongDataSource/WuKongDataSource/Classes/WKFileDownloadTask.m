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
    if(self.message.contentType == WK_SMALLVIDEO) { // 小视频直接下载视频文件。
        storePath = [NSString stringWithFormat:@"%@_tmp",media.localPath];
    }
    __weak typeof(self) weakSelf = self;
    NSString *channelDir = [storePath stringByDeletingLastPathComponent];
    [WKFileUtil createDirectoryIfNotExist:channelDir];
    self.task = [[WKAPIClient sharedClient] createDownloadTask:[[self getVoiceFullUrl:media.remoteUrl] absoluteString] storePath:storePath progress:^(NSProgress *  downloadProgress) {
        weakSelf.progress = downloadProgress.fractionCompleted;
        weakSelf.status = WKTaskStatusProgressing;
        [weakSelf update];
    } completeCallback:^(NSError * _Nullable error) {
        if(error) {
            weakSelf.status = WKTaskStatusError;
            weakSelf.error = error;
            WKLogError(@"download fail -> %@",error);
        }else {
            NSError *copyError;
            [[NSFileManager defaultManager] moveItemAtPath:storePath toPath:realLocalPath error:&copyError];
        
            if(copyError) {
                WKLogError(@"复制文件失败！%@",copyError);
                weakSelf.status = WKTaskStatusError;
                weakSelf.error = error;
            }else {
                weakSelf.status = WKTaskStatusSuccess;
                weakSelf.error = nil;
            }
           
        }
        [weakSelf update];
    }];
}

-(NSURL*) getVoiceFullUrl:(NSString*)url{
    return [[WKApp shared] getFileFullUrl:url];
}

-(void) resume {
    [self.task resume];
}

-(void) cancel {
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
