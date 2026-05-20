//
//  WKFileUploadTask.m
//  WuKongDataSource
//
//  Created by tt on 2020/1/15.
//

#import "WKFileUploadTask.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
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
    NSString *localPath = media.localPath;
    NSString *ext = [self resolveExtensionFromMedia:media localPath:localPath useThumb:NO];

    // ---- 如果是声音文件，则上传转码后的副本也就是amr文件 ----
    if([media isKindOfClass:[WKVoiceContent class]]) {
        localPath = media.thumbPath;
        ext = [self resolveExtensionFromMedia:media localPath:localPath useThumb:YES];
    }

    NSString *path = [NSString stringWithFormat:@"/%d/%@/%@%@",self.message.channel.channelType,self.message.channel.channelId,randomFileName,ext];
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

// 解析扩展名 — 三层兜底：
//   1) media.extension / thumbExtension（业务模型显式声明）
//   2) localPath.pathExtension（系统从文件名解析，自动去 ".tar.gz" 这种取最后一段）
//   3) "" — 无扩展文件也允许上传，contentType 会兜底成 application/octet-stream
// 返回值带前导 "."（与 media.extension 现有约定保持一致），无扩展返回 ""。
-(NSString*) resolveExtensionFromMedia:(id<WKMediaProto>)media localPath:(NSString*)localPath useThumb:(BOOL)useThumb {
    NSString *modelExt = useThumb ? media.thumbExtension : media.extension;
    if (modelExt.length > 0) {
        return [modelExt hasPrefix:@"."] ? modelExt : [@"." stringByAppendingString:modelExt];
    }
    NSString *fileExt = localPath.pathExtension; // 无点，无扩展时返回 ""
    if (fileExt.length > 0) {
        return [@"." stringByAppendingString:fileExt];
    }
    return @"";
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
//
// 三层兜底：硬编码高频表 → 系统 UTType（iOS 14+，覆盖广） →
// application/octet-stream（也覆盖了"无扩展文件"这条路径）。
-(NSString*) mimeTypeForExtension:(NSString*)extWithDot {
    NSString *ext = extWithDot;
    if ([ext hasPrefix:@"."]) {
        ext = [ext substringFromIndex:1];
    }
    ext = ext.lowercaseString;
    if (ext.length == 0) {
        // 无扩展 — 跟 web 行为对齐：直接走 octet-stream，服务端会按二进制流签
        return @"application/octet-stream";
    }
    // 图片
    if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"]) return @"image/jpeg";
    if ([ext isEqualToString:@"png"]) return @"image/png";
    if ([ext isEqualToString:@"gif"]) return @"image/gif";
    if ([ext isEqualToString:@"webp"]) return @"image/webp";
    if ([ext isEqualToString:@"heic"]) return @"image/heic";
    if ([ext isEqualToString:@"bmp"]) return @"image/bmp";
    if ([ext isEqualToString:@"svg"]) return @"image/svg+xml";
    // 视频
    if ([ext isEqualToString:@"mp4"]) return @"video/mp4";
    if ([ext isEqualToString:@"mov"]) return @"video/quicktime";
    if ([ext isEqualToString:@"m4v"]) return @"video/x-m4v";
    if ([ext isEqualToString:@"avi"]) return @"video/x-msvideo";
    if ([ext isEqualToString:@"mkv"]) return @"video/x-matroska";
    if ([ext isEqualToString:@"webm"]) return @"video/webm";
    // 音频
    if ([ext isEqualToString:@"amr"]) return @"audio/amr";
    if ([ext isEqualToString:@"m4a"]) return @"audio/mp4";
    if ([ext isEqualToString:@"mp3"]) return @"audio/mpeg";
    if ([ext isEqualToString:@"wav"]) return @"audio/wav";
    if ([ext isEqualToString:@"aac"]) return @"audio/aac";
    if ([ext isEqualToString:@"flac"]) return @"audio/flac";
    if ([ext isEqualToString:@"ogg"]) return @"audio/ogg";
    // 文档 — Office
    if ([ext isEqualToString:@"doc"]) return @"application/msword";
    if ([ext isEqualToString:@"docx"]) return @"application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    if ([ext isEqualToString:@"xls"]) return @"application/vnd.ms-excel";
    if ([ext isEqualToString:@"xlsx"]) return @"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    if ([ext isEqualToString:@"ppt"]) return @"application/vnd.ms-powerpoint";
    if ([ext isEqualToString:@"pptx"]) return @"application/vnd.openxmlformats-officedocument.presentationml.presentation";
    // 文档 — 其他
    if ([ext isEqualToString:@"pdf"]) return @"application/pdf";
    if ([ext isEqualToString:@"rtf"]) return @"application/rtf";
    if ([ext isEqualToString:@"epub"]) return @"application/epub+zip";
    // 文本
    if ([ext isEqualToString:@"txt"]) return @"text/plain";
    if ([ext isEqualToString:@"md"] || [ext isEqualToString:@"markdown"]) return @"text/markdown";
    if ([ext isEqualToString:@"csv"]) return @"text/csv";
    if ([ext isEqualToString:@"html"] || [ext isEqualToString:@"htm"]) return @"text/html";
    if ([ext isEqualToString:@"xml"]) return @"application/xml";
    if ([ext isEqualToString:@"json"]) return @"application/json";
    if ([ext isEqualToString:@"log"]) return @"text/plain";
    // 压缩包
    if ([ext isEqualToString:@"zip"]) return @"application/zip";
    if ([ext isEqualToString:@"rar"]) return @"application/vnd.rar";
    if ([ext isEqualToString:@"7z"]) return @"application/x-7z-compressed";
    if ([ext isEqualToString:@"tar"]) return @"application/x-tar";
    if ([ext isEqualToString:@"gz"] || [ext isEqualToString:@"gzip"]) return @"application/gzip";
    if ([ext isEqualToString:@"bz2"]) return @"application/x-bzip2";

    // 系统兜底：UTType 数据库覆盖远比硬编码全，apk/dmg/odt/keynote/numbers 等都能命中
    UTType *type = [UTType typeWithFilenameExtension:ext];
    NSString *systemMime = type.preferredMIMEType;
    if (systemMime.length > 0) {
        return systemMime;
    }
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
    NSString *filename = localPath.lastPathComponent;
    if (filename.length == 0) {
        // localPath 为空 / 异常 → 用 "file" + 扩展兜底，保证 credentials API 必有
        // 非空 filename 参数（服务端用 filename 拼 Content-Disposition）。
        filename = [@"file" stringByAppendingString:(ext ?: @"")];
    }
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
    NSString *coverFilename = coverFileURL.lastPathComponent;
    if (coverFilename.length == 0) {
        coverFilename = [@"cover" stringByAppendingString:coverExt];
    }
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
