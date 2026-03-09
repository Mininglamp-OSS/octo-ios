//
//  WKFileUploadTask.m
//  WuKongDataSource
//
//  Created by tt on 2020/1/15.
//

#import "WKFileUploadTask.h"
@interface WKFileUploadTask ()
@property(nonatomic,strong) NSMutableArray<NSURLSessionDataTask*> *tasks;

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
    NSString *path = [NSString stringWithFormat:@"/%d/%@/%@%@",self.message.channel.channelType,self.message.channel.channelId,randomFileName,media.extension?:@""];
      NSString *fileUrl = [NSString stringWithFormat:@"file://%@",media.localPath];
    
    // ---- 如果是声音文件，则上传转码后的副本也就是amr文件 ----
     if([media isKindOfClass:[WKVoiceContent class]]) {
         path = [NSString stringWithFormat:@"/%d/%@/%@%@",self.message.channel.channelType,self.message.channel.channelId,randomFileName,media.thumbExtension?:@""];
         fileUrl = [NSString stringWithFormat:@"file://%@",media.thumbPath];
     }
    
    
    if(self.message.contentType == WK_SMALLVIDEO) { // 小视频
        __weak typeof(self) weakSelf = self;
        [self uploadVideoCoverImage:^{ // 先上传封面图,再上传视频
            WKLogDebug(@"封面上传成功！");
            [weakSelf createAndAddUploadTask:path sourceFileURL:fileUrl];
        }];
    }else {
        [self createAndAddUploadTask:path sourceFileURL:fileUrl];
    }
    
    
}
// 获取上传地址
-(AnyPromise*) getUploadURL:(NSString*)path{
    return  [[WKAPIClient sharedClient] GET:[NSString stringWithFormat:@"%@file/upload?path=%@&type=chat",[WKApp shared].config.fileBaseUrl,path] parameters:nil];
}



// 创建和添加下载上传任务
-(void) createAndAddUploadTask:(NSString*)path sourceFileURL:(NSString*)fileURL {
    
    id<WKMediaProto> media = [self getMessageMedia:self.message];
    __weak typeof(self) weakSelf = self;
    [self getUploadURL:path].then(^(NSDictionary *result){
        NSString *uploadUrl = result[@"url"];
        NSURLSessionDataTask *task = [[WKAPIClient sharedClient] createFileUploadTask:uploadUrl fileURL:fileURL progress:^(NSProgress * _Nullable uploadProgress) {
            weakSelf.progress = uploadProgress.fractionCompleted;
            weakSelf.status = WKTaskStatusProgressing;
            [weakSelf update];
        } completeCallback:^(id  _Nullable responseObj, NSError * _Nullable error) {
            if(error) {
                weakSelf.status = WKTaskStatusError;
                weakSelf.error = error;
                weakSelf.remoteUrl = @"";
            }else {
                 weakSelf.status = WKTaskStatusSuccess;
                weakSelf.error = nil;
                media.remoteUrl = responseObj[@"path"];
                weakSelf.remoteUrl = media.remoteUrl;
                
                WKLogDebug(@"上传结果：%@",responseObj);
            }
             [weakSelf update];
        }];
        [self.tasks addObject:task];
        [task resume]; // 这里直接执行了。如果WKTaskManager的执行task的resume 慢于这里可能会有问题（一般这里要慢，因为网络请求要比代码执行慢）
    }).catch(^(NSError *error){
        weakSelf.status = WKTaskStatusError;
        weakSelf.error = error;
        weakSelf.remoteUrl = @"";
        [weakSelf update];
    });
}

// 上传封面图
-(void) uploadVideoCoverImage:(void(^)(void))successCallback {
    id<WKMediaProto> media = [self getMessageMedia:self.message];
    NSString *coverFileURL =[media getExtra:@"video_cover_file"];
    if(!coverFileURL) {
        WKLogDebug(@"上传视频，没有设置封面图,请在extra字段内设置video_cover_file");
        return;
    }
     NSString *randomFileName = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    __weak typeof(self) weakSelf = self;
    NSString *path = [NSString stringWithFormat:@"/%d/%@/%@%@",self.message.channel.channelType,self.message.channel.channelId,randomFileName,media.extension?:@""];
    
    [self getUploadURL:path].then(^(NSDictionary*result){
        NSString *uploadUrl = result[@"url"];
        NSURLSessionDataTask *task = [[WKAPIClient sharedClient] createFileUploadTask:uploadUrl fileURL:[NSString stringWithFormat:@"file://%@",coverFileURL] progress:^(NSProgress * _Nullable uploadProgress) {
        } completeCallback:^(id  _Nullable responseObj, NSError * _Nullable error) {
            if(error) {
                weakSelf.status = WKTaskStatusError;
                weakSelf.error = error;
                weakSelf.remoteUrl = @"";
                 [weakSelf update];
                return;
            }
            [media setExtra:responseObj[@"path"] key:@"video_cover"];
            if(successCallback) {
                successCallback();
            }
        }];
        [task resume];
    }).catch(^(NSError *error){
        weakSelf.status = WKTaskStatusError;
        weakSelf.error = error;
        weakSelf.remoteUrl = @"";
        [weakSelf update];
    });
    
    
}



-(void) resume {
    for (NSURLSessionDataTask *task in self.tasks) {
        [task resume];
    }
}

-(void) cancel {
    for (NSURLSessionDataTask *task in self.tasks) {
        [task cancel];
    }
}

- (void)suspend {
    for (NSURLSessionDataTask *task in self.tasks) {
        [task suspend];
    }
}

-(NSMutableArray<NSURLSessionDataTask*>*) tasks {
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
