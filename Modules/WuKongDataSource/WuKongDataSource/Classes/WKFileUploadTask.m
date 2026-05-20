//
//  WKFileUploadTask.m
//  WuKongDataSource
//
//  Created by tt on 2020/1/15.
//

#import "WKFileUploadTask.h"
@interface WKFileUploadTask ()
@property(nonatomic,strong) NSMutableArray<NSURLSessionTask*> *tasks;

@end
@implementation WKFileUploadTask


- (instancetype)initWithMessage:(WKMessage *)message {
    self = [super initWithMessage:message];
    if(self) {
        [self initTasks];
    }
    return self;
}

-(void) initTasks {

    id<WKMediaProto> media = [self getMessageMedia:self.message];
    if(!media) {
        WKLogDebug(@"不是多媒体消息！");
        return;
    }

    NSString *randomFileName = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    NSString *ext = media.extension ?: @"";
    NSString *path = [NSString stringWithFormat:@"/%d/%@/%@%@",self.message.channel.channelType,self.message.channel.channelId,randomFileName,ext];
    NSString *localPath = media.localPath;

    // ---- 如果是声音文件，则上传转码后的副本也就是amr文件 ----
    if([media isKindOfClass:[WKVoiceContent class]]) {
        ext = media.thumbExtension ?: @"";
        path = [NSString stringWithFormat:@"/%d/%@/%@%@",self.message.channel.channelType,self.message.channel.channelId,randomFileName,ext];
        localPath = media.thumbPath;
    }

    NSString *fileUrl = [NSString stringWithFormat:@"file://%@",localPath];

    if(self.message.contentType == WK_SMALLVIDEO) { // 小视频
        __weak typeof(self) weakSelf = self;
        [self uploadVideoCoverImage:^{ // 先上传封面图,再上传视频
            WKLogDebug(@"封面上传成功！");
            [weakSelf createAndAddUploadTask:path sourceFileURL:fileUrl localFilePath:localPath ext:ext];
        }];
    }else {
        [self createAndAddUploadTask:path sourceFileURL:fileUrl localFilePath:localPath ext:ext];
    }


}

// 获取预签名直传凭证（COS 等 OSS 直传模式）
// path/filename/contentType/fileSize 都参与 URL 签名，必须真实，否则 COS PUT 会
// 拿 SignatureDoesNotMatch。对齐 web `octo-web/.../task.ts` 的 getUploadCredentials。
-(AnyPromise*) getUploadCredentials:(NSString*)path
                           filename:(NSString*)filename
                        contentType:(NSString*)contentType
                           fileSize:(long long)fileSize {
    NSString *url = [NSString stringWithFormat:@"%@file/upload/credentials?path=%@&type=chat&filename=%@&contentType=%@&fileSize=%lld",
                     [WKApp shared].config.fileBaseUrl,
                     [self urlEncode:path],
                     [self urlEncode:filename],
                     [self urlEncode:contentType],
                     fileSize];
    return [[WKAPIClient sharedClient] GET:url parameters:nil];
}

-(NSString*) urlEncode:(NSString*)raw {
    if (!raw) return @"";
    return [raw stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] ?: @"";
}

// 通过扩展名推断 MIME。COS 预签名时服务端按 contentType 签 URL，
// 客户端 PUT 必须用一样的值；不匹配 → 403 SignatureDoesNotMatch。
-(NSString*) mimeTypeForExtension:(NSString*)extWithDot {
    NSString *ext = extWithDot;
    if ([ext hasPrefix:@"."]) {
        ext = [ext substringFromIndex:1];
    }
    ext = ext.lowercaseString;
    if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"]) return @"image/jpeg";
    if ([ext isEqualToString:@"png"]) return @"image/png";
    if ([ext isEqualToString:@"gif"]) return @"image/gif";
    if ([ext isEqualToString:@"webp"]) return @"image/webp";
    if ([ext isEqualToString:@"heic"]) return @"image/heic";
    if ([ext isEqualToString:@"mp4"]) return @"video/mp4";
    if ([ext isEqualToString:@"mov"]) return @"video/quicktime";
    if ([ext isEqualToString:@"amr"]) return @"audio/amr";
    if ([ext isEqualToString:@"m4a"]) return @"audio/mp4";
    if ([ext isEqualToString:@"mp3"]) return @"audio/mpeg";
    if ([ext isEqualToString:@"wav"]) return @"audio/wav";
    if ([ext isEqualToString:@"pdf"]) return @"application/pdf";
    return @"application/octet-stream";
}

-(long long) fileSizeAtPath:(NSString*)localPath {
    if (localPath.length == 0) return 0;
    NSError *err = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:localPath error:&err];
    if (err) return 0;
    return [attrs fileSize];
}


// 创建和添加下载上传任务（直传到预签名 URL）
-(void) createAndAddUploadTask:(NSString*)path sourceFileURL:(NSString*)fileURL localFilePath:(NSString*)localPath ext:(NSString*)ext {

    id<WKMediaProto> media = [self getMessageMedia:self.message];
    NSString *filename = localPath.lastPathComponent ?: [NSString stringWithFormat:@"file%@", ext ?: @""];
    NSString *contentType = [self mimeTypeForExtension:ext];
    long long fileSize = [self fileSizeAtPath:localPath];

    __weak typeof(self) weakSelf = self;
    [self getUploadCredentials:path filename:filename contentType:contentType fileSize:fileSize].then(^(NSDictionary *result){
        NSString *uploadUrl = result[@"uploadUrl"];
        NSString *downloadUrl = result[@"downloadUrl"];
        NSString *signedContentType = result[@"contentType"] ?: contentType;
        NSString *contentDisposition = result[@"contentDisposition"];
        if (uploadUrl.length == 0 || downloadUrl.length == 0) {
            weakSelf.status = WKTaskStatusError;
            weakSelf.error = [NSError errorWithDomain:@"WKFileUploadTask" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"credentials 缺 uploadUrl/downloadUrl"}];
            weakSelf.remoteUrl = @"";
            [weakSelf update];
            return;
        }
        NSURLSessionUploadTask *task = [[WKAPIClient sharedClient] createFileUploadPutTask:uploadUrl
                                                                                   fileURL:fileURL
                                                                               contentType:signedContentType
                                                                        contentDisposition:contentDisposition
                                                                                  progress:^(NSProgress * _Nullable uploadProgress) {
            weakSelf.progress = uploadProgress.fractionCompleted;
            weakSelf.status = WKTaskStatusProgressing;
            [weakSelf update];
        } completeCallback:^(NSInteger statusCode, NSError * _Nullable error) {
            if(error) {
                weakSelf.status = WKTaskStatusError;
                weakSelf.error = error;
                weakSelf.remoteUrl = @"";
            }else {
                // COS PUT 成功不回 body —— downloadUrl 直接用凭证里的，对齐 web
                weakSelf.status = WKTaskStatusSuccess;
                weakSelf.error = nil;
                media.remoteUrl = downloadUrl;
                weakSelf.remoteUrl = downloadUrl;
                WKLogDebug(@"上传完成 downloadUrl=%@",downloadUrl);
            }
            [weakSelf update];
        }];
        if (task) {
            [self.tasks addObject:task];
            [task resume];
        }
    }).catch(^(NSError *error){
        weakSelf.status = WKTaskStatusError;
        weakSelf.error = error;
        weakSelf.remoteUrl = @"";
        [weakSelf update];
    });
}

// 上传封面图（小视频专用），同样走新凭证接口
-(void) uploadVideoCoverImage:(void(^)(void))successCallback {
    id<WKMediaProto> media = [self getMessageMedia:self.message];
    NSString *coverFileURL =[media getExtra:@"video_cover_file"];
    if(!coverFileURL) {
        WKLogDebug(@"上传视频，没有设置封面图,请在extra字段内设置video_cover_file");
        return;
    }
    NSString *randomFileName = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    // 注意：封面图扩展名应该跟图片走（jpg），不应该跟 media.extension（视频）走。
    // 老代码这里用了 media.extension（.mp4），路径不对但服务端不强校验也能过，
    // 现在切到 COS 预签名以后 contentType 严格匹配，这里改成显式 .jpg。
    NSString *coverExt = @".jpg";
    NSString *coverContentType = @"image/jpeg";
    NSString *path = [NSString stringWithFormat:@"/%d/%@/%@%@",self.message.channel.channelType,self.message.channel.channelId,randomFileName,coverExt];
    NSString *coverFilename = coverFileURL.lastPathComponent ?: [@"cover" stringByAppendingString:coverExt];
    long long coverSize = [self fileSizeAtPath:coverFileURL];

    __weak typeof(self) weakSelf = self;
    [self getUploadCredentials:path filename:coverFilename contentType:coverContentType fileSize:coverSize].then(^(NSDictionary *result){
        NSString *uploadUrl = result[@"uploadUrl"];
        NSString *downloadUrl = result[@"downloadUrl"];
        NSString *signedContentType = result[@"contentType"] ?: coverContentType;
        NSString *contentDisposition = result[@"contentDisposition"];
        if (uploadUrl.length == 0 || downloadUrl.length == 0) {
            weakSelf.status = WKTaskStatusError;
            weakSelf.error = [NSError errorWithDomain:@"WKFileUploadTask" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"cover credentials 缺字段"}];
            weakSelf.remoteUrl = @"";
            [weakSelf update];
            return;
        }
        NSURLSessionUploadTask *task = [[WKAPIClient sharedClient] createFileUploadPutTask:uploadUrl
                                                                                   fileURL:[NSString stringWithFormat:@"file://%@",coverFileURL]
                                                                               contentType:signedContentType
                                                                        contentDisposition:contentDisposition
                                                                                  progress:nil
                                                                          completeCallback:^(NSInteger statusCode, NSError * _Nullable error) {
            if(error) {
                weakSelf.status = WKTaskStatusError;
                weakSelf.error = error;
                weakSelf.remoteUrl = @"";
                [weakSelf update];
                return;
            }
            [media setExtra:downloadUrl key:@"video_cover"];
            if(successCallback) {
                successCallback();
            }
        }];
        if (task) {
            [self.tasks addObject:task];
            [task resume];
        }
    }).catch(^(NSError *error){
        weakSelf.status = WKTaskStatusError;
        weakSelf.error = error;
        weakSelf.remoteUrl = @"";
        [weakSelf update];
    });
}



-(void) resume {
    for (NSURLSessionTask *task in self.tasks) {
        [task resume];
    }
}

-(void) cancel {
    for (NSURLSessionTask *task in self.tasks) {
        [task cancel];
    }
}

- (void)suspend {
    for (NSURLSessionTask *task in self.tasks) {
        [task suspend];
    }
}

-(NSMutableArray<NSURLSessionTask*>*) tasks {
    if(!_tasks) {
        _tasks = [NSMutableArray array];
    }
    return _tasks;
}

-(id<WKMediaProto>) getMessageMedia:(WKMessage*)message {
    if([message.content conformsToProtocol:@protocol(WKMediaProto)] ) {
        return (id<WKMediaProto>)message.content;
    }
    return nil;
}
@end
