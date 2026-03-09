//
//  WKURLSessionDataTask.m
//  WuKongBase
//
//  Created by tt on 2022/5/13.
//

#import "WKDowloadTask.h"
#import "WuKongBase.h"
@interface WKDowloadTask ()



@property(nonatomic,strong) NSURLSessionDownloadTask *task;

@end

@implementation WKDowloadTask
-(instancetype) initWithURL:(NSString*)url storePath:(NSString*)storePath{
    WKDowloadTask *task = [WKDowloadTask new];
    task.taskId = url;
    task.url = url;
    task.storePath = storePath;
    [task initTask];
    return task;
}

-(void) initTask {
    NSString *storeDir = [self.storePath stringByDeletingLastPathComponent];
    [WKFileUtil createDirectoryIfNotExist:storeDir];
    
    if([WKFileUtil fileIsExistOfPath:self.storePath]) {
        self.status = WKTaskStatusSuccess;
        [self update];
        return;
    }
    
    NSString *tempDir= NSTemporaryDirectory();
    NSString *tmpFile = [tempDir stringByAppendingPathComponent:[self uuidString]];
    
    __weak typeof(self) weakSelf = self;
  self.task =   [[WKAPIClient sharedClient] createDownloadTask:self.url storePath:tmpFile progress:^(NSProgress * _Nullable downloadProgress) {
        weakSelf.progress = downloadProgress.fractionCompleted;
        weakSelf.status = WKTaskStatusProgressing;
        [weakSelf update];
    } completeCallback:^(NSError * _Nullable error) {
        if(error) {
            weakSelf.status = WKTaskStatusError;
            weakSelf.error = error;
        }else {
            NSError *copyError;
            [[NSFileManager defaultManager] moveItemAtPath:tmpFile toPath:weakSelf.storePath error:&copyError];
            
            
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

- (NSString *)uuidString{
    
    CFUUIDRef uuid_ref = CFUUIDCreate(NULL);
    CFStringRef uuid_string_ref= CFUUIDCreateString(NULL, uuid_ref);
    NSString *uuid = [NSString stringWithString:(__bridge NSString *)uuid_string_ref];
    CFRelease(uuid_ref);
    CFRelease(uuid_string_ref);
    
    //去除UUID ”-“
    NSString *UUID = [[uuid lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""];

    return UUID;
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

@end
