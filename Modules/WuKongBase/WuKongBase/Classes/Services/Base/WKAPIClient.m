//
//  WKAPIClient.m
//  Common
//
//  Created by tt on 2018/9/12.
//

#import "WKAPIClient.h"
#import <PromiseKit/PromiseKit.h>
#import "WKLogs.h"
#import "WKModel.h"
#import "WKApp.h"
#import <objc/objc.h>

@implementation  WKAPIClientConfig

-(void) setPublicHeaderBLock:(NSDictionary*(^)(void)) headerBLock{
    _publicHeaderBLock = headerBLock;
}

@end

//static AFHTTPSessionManager *_sessionManager;

@interface WKAPIClient()
@property(nonatomic,strong) AFHTTPSessionManager *sessionManager;
@end
@implementation WKAPIClient

+ (instancetype)sharedClient {
    static WKAPIClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[WKAPIClient alloc] init];
    });
    
    return _sharedClient;
}

-(void) setConfig:(WKAPIClientConfig*)config{
    _config = config;
    _sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:config.baseUrl]];
    if([config.baseUrl hasPrefix:@"https"]) {
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        securityPolicy.allowInvalidCertificates = YES;
        securityPolicy.validatesDomainName = NO;
        _sessionManager.securityPolicy = securityPolicy;
    }
//     if (config.httpsOn) {
//
//     }
    _sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
    _sessionManager.requestSerializer.HTTPMethodsEncodingParametersInURI =  [NSSet setWithObjects:@"GET", @"HEAD", nil];
}




-(AnyPromise*) GET:(NSString*)path parameters:(nullable id)parameters model:(Class) modelClass {
    NSString *requestPath = path;
    if(_config.requestPathReplace) {
        requestPath = _config.requestPathReplace(path);
    }
    __weak typeof(self) weakSelf = self;
    return [self GET:[self pathURLEncode:requestPath] parameters:parameters].then(^(id responseObj){
        
        return [weakSelf resultToModel:responseObj model:modelClass];
    });
}


-(NSURLSessionDataTask*) taskGET:(NSString*)path parameters:(nullable id)parameters model:(Class)modelClass callback:(void(^)(NSError *error,id result))callback{
    __weak typeof(self) weakSelf = self;
    return [self taskGET:[self pathURLEncode:path] parameters:parameters callback:^(NSError *error, id result) {
        if(error) {
            if(callback) {
                callback(error,nil);
            }
            return;
        }
        if(callback) {
            callback(nil,[weakSelf resultToModel:result model:modelClass]);
        }
    }];
}

-(NSURLSessionDataTask*) taskGET:(NSString*)path parameters:(nullable id)parameters callback:(void(^)(NSError *error,id result))callback{
    NSString *requestPath = path;
    if(_config.requestPathReplace) {
        requestPath = _config.requestPathReplace(path);
    }
    [self logRequestStart:requestPath params:parameters method:@"GET"];
    __weak typeof(self) weakSelf = self;
    [weakSelf resetPublicHeader];
   NSURLSessionDataTask *task =[weakSelf.sessionManager GET:[NSString stringWithFormat:@"%@",[self pathURLEncode:requestPath]] parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
       [weakSelf logRequestEnd:task response:responseObject];
       if(callback) {
           callback(nil,responseObject);
       }
   } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
       NSError *er;
       if(weakSelf.config.errorHandler){
          er =  weakSelf.config.errorHandler(nil,error);
       }
       if(!er) {
           er = error;
       }
       if(callback) {
           callback(error,nil);
       }
   }];
    return  task;
}

-(AnyPromise*) GET:(NSString*)path parameters:(nullable id)parameters {
    NSString *requestPath = path;
    if(_config.requestPathReplace) {
        requestPath = _config.requestPathReplace(path);
    }
    [self logRequestStart:requestPath params:parameters method:@"GET"];
    __weak typeof(self) weakSelf = self;
   return  [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        [weakSelf resetPublicHeader];
       
       NSURLSessionDataTask *task =[weakSelf.sessionManager GET:[NSString stringWithFormat:@"%@",[weakSelf pathURLEncode:requestPath]] parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
           [weakSelf logRequestEnd:task response:responseObject];
           resolve(PMKManifold(responseObject,task));
       } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
           NSError *er;
           if(weakSelf.config.errorHandler){
              er =  weakSelf.config.errorHandler(nil,error);
           }
           if(!er) {
               er = error;
           }
           resolve(er);
       }];
       [task resume];
    }];
}

-(NSString*) pathURLEncode:(NSString*)path {
    return [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

-(AnyPromise*) POST:(NSString*)path parameters:(nullable id)parameters model:(Class) modelClass{
    __weak typeof(self) weakSelf = self;
    return [weakSelf POST:path parameters:parameters].then(^(id responseObj){
        
        return [self resultToModel:responseObj model:modelClass];
    });
}

-(NSURLSessionDataTask*) fileUpload:(NSString*)path data:(NSData*)data progress:(void(^)(NSProgress *progress)) progressCallback completeCallback:(void(^)(id resposeObject,NSError *error)) completeCallback {
    return [self fileUpload:path data:data fileName:@"filename" progress:progressCallback completeCallback:completeCallback];
    
}

-(NSURLSessionDataTask*) fileUpload:(NSString*)path data:(NSData*)data fileName:(NSString*)fileName progress:(void(^)(NSProgress *progress)) progressCallback completeCallback:(void(^)(id resposeObject,NSError *error)) completeCallback {
    NSString *requestPath = path;
    if(_config.requestPathReplace) {
        requestPath = _config.requestPathReplace(path);
    }
    [self resetPublicHeader];
    return  [_sessionManager POST:[self pathURLEncode:requestPath] parameters:nil headers:nil constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
       //  [formData appendPartWithFileData:data name:@"file" fileName:@"filename" mimeType:@"*"];
      [formData appendPartWithFileData:data name:@"file" fileName:fileName mimeType:@"*"];
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        if(progressCallback) {
            progressCallback(uploadProgress);
        }
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if(completeCallback) {
            completeCallback(responseObject,nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if(completeCallback) {
            completeCallback(nil,error);
        }
    }];
}

-(NSURLSessionDataTask*) fileUpload:(NSString*)path fileURL:(NSString*)fileUrl progress:(void(^)(NSProgress *progress)) progressCallback completeCallback:(void(^)(id resposeObject,NSError *error)) completeCallback {
    NSString *requestPath = path;
    if(_config.requestPathReplace) {
        requestPath = _config.requestPathReplace(path);
    }
    [self resetPublicHeader];
    return  [_sessionManager POST:[self pathURLEncode:requestPath] parameters:nil headers:nil constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        NSError *fileError;
        [formData appendPartWithFileURL:[NSURL URLWithString:fileUrl] name:@"file" error:&fileError];
      if(fileError) {
          WKLogError(@"fileError-> %@",fileError);
      }
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        if(progressCallback) {
            progressCallback(uploadProgress);
        }
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if(completeCallback) {
            completeCallback(responseObject,nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if(completeCallback) {
            completeCallback(nil,error);
        }
    }];
    
}

-(void) uploadChatFile:(NSString*)serverPath localURL:(NSURL*)localURL progress:(void(^_Nullable)(NSProgress * _Nonnull progress)) progressCallback completeCallback:(void(^_Nullable)(id __nullable resposeObject,NSError * __nullable error)) completeCallback {
    [self getChatUploadURL:serverPath].then(^(NSDictionary*result){
        NSString *uploadUrl = result[@"url"];
        [self fileUpload:uploadUrl fileURL:localURL.absoluteString progress:progressCallback completeCallback:completeCallback];
    }).catch(^(NSError *error){
        if(completeCallback) {
            completeCallback(nil,error);
        }
    });
}

// 获取上传地址
-(AnyPromise*) getChatUploadURL:(NSString*)path{
    return  [[WKAPIClient sharedClient] GET:[NSString stringWithFormat:@"%@file/upload?path=%@&type=chat",[WKApp shared].config.fileBaseUrl,path] parameters:nil];
}

-(NSURLSessionDownloadTask*) createDownloadTask:(NSString*)path storePath:(NSString*_Nonnull)storePath progress:(void (^)(NSProgress *downloadProgress)) downloadProgressBlock completeCallback:(void(^)(NSError *error)) completeCallback{
    NSString *requestPath = path;
    if(_config.requestPathReplace) {
        requestPath = _config.requestPathReplace(path);
    }
     NSMutableURLRequest *request = [_sessionManager.requestSerializer requestWithMethod:@"GET" URLString:[[NSURL URLWithString:[self pathURLEncode:requestPath] relativeToURL:_sessionManager.baseURL] absoluteString] parameters:nil error:nil];
   NSURLSessionDownloadTask *task = [_sessionManager downloadTaskWithRequest:request progress:downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return [NSURL fileURLWithPath:storePath];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        if(completeCallback) {
            completeCallback(error);
        }
    }];
    return task;
}

-(NSURLSessionDataTask*) createFileUploadTask:(NSString*)path fileURL:(NSString*)fileUrl  progress:(void (^)(NSProgress *uploadProgress)) uploadProgressBlock completeCallback:(void(^)(id responseObj,NSError *error)) completeCallback{
    
    NSString *requestPath = path;
    if(_config.requestPathReplace) {
        requestPath = _config.requestPathReplace(path);
    }
    
    NSError *serializationError = nil;
    NSMutableURLRequest *request = [_sessionManager.requestSerializer multipartFormRequestWithMethod:@"POST" URLString:[[NSURL URLWithString:[self pathURLEncode:requestPath] relativeToURL:_sessionManager.baseURL] absoluteString] parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        NSError *fileError;
        [formData appendPartWithFileURL:[NSURL URLWithString:[fileUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]] name:@"file" error:&fileError];
        if(fileError) {
            WKLogError(@"file: %@ fileError-> %@",fileUrl,fileError);
            if (completeCallback) {
                completeCallback(nil, fileError);
            }
            
        }
    } error:&serializationError];
    if (serializationError) {
        if (completeCallback) {
            dispatch_async(_sessionManager.completionQueue ?: dispatch_get_main_queue(), ^{
                completeCallback(nil,serializationError);
            });
        }
        
        return nil;
    }
    __block NSURLSessionDataTask *task = [_sessionManager uploadTaskWithStreamedRequest:request progress:uploadProgressBlock completionHandler:^(NSURLResponse * __unused response, id responseObject, NSError *error) {
        if (error) {
            if (completeCallback) {
                completeCallback(nil, error);
            }
        } else {
            if (completeCallback) {
                completeCallback(responseObject, nil);
            }
        }
    }];
    
    return task;
}

-(AnyPromise*) POST:(NSString*)path parameters:(nullable id)parameters{
    return [self POST:path parameters:parameters headers:nil];
}

-(AnyPromise*_Nonnull) POST:(NSString*_Nonnull)path parameters:(nullable id)parameters headers:(NSDictionary*)headers {
    NSString *requestPath = path;
    if(_config.requestPathReplace) {
        requestPath = _config.requestPathReplace(path);
    }
     [self logRequestStart:requestPath params:parameters method:@"POST"];
     __weak typeof(self) weakSelf = self;
     return  [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
         [weakSelf resetPublicHeader];
         [weakSelf.sessionManager POST:[weakSelf pathURLEncode:requestPath] parameters:parameters headers:headers progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
             [weakSelf logRequestEnd:task response:responseObject];
             resolve(PMKManifold(responseObject,task));
         } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
             NSError *er;
             if(weakSelf.config.errorHandler){
                 er =  weakSelf.config.errorHandler(nil,error);
             }
             if(!er) {
                 er = error;
             }
             resolve(er);
         }];
     }];
}

-(AnyPromise*) DELETE:(NSString*)path parameters:(nullable id)parameters{
    NSString *requestPath = path;
    if(_config.requestPathReplace) {
        requestPath = _config.requestPathReplace(path);
    }
    [self logRequestStart:requestPath params:parameters method:@"DELETE"];
    __weak typeof(self) weakSelf = self;
    return  [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        [weakSelf resetPublicHeader];
        [weakSelf.sessionManager DELETE:[weakSelf pathURLEncode:requestPath] parameters:parameters headers:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) { [weakSelf logRequestEnd:task response:responseObject];
            resolve(PMKManifold(responseObject,task));
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSError *er;
            if(weakSelf.config.errorHandler){
                er =  weakSelf.config.errorHandler(nil,error);
            }
            if(!er) {
                er = error;
            }
            resolve(er);
        }];
    }];
}

-(AnyPromise*) PUT:(NSString*)path parameters:(nullable id)parameters{
    NSString *requestPath = path;
    if(_config.requestPathReplace) {
        requestPath = _config.requestPathReplace(path);
    }
    [self logRequestStart:requestPath params:parameters method:@"PUT"];
    __weak typeof(self) weakSelf = self;
    return  [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        [weakSelf resetPublicHeader];
        [weakSelf.sessionManager PUT:[weakSelf pathURLEncode:requestPath] parameters:parameters headers:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) { [weakSelf logRequestEnd:task response:responseObject];
            resolve(PMKManifold(responseObject,task));
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSError *er;
            if(weakSelf.config.errorHandler){
                er =  weakSelf.config.errorHandler(nil,error);
            }
            if(!er) {
                er = error;
            }
            resolve(er);
        }];
    }];
}


// 重置公共header
-(void) resetPublicHeader{
    if (self.config.publicHeaderBLock){
        NSDictionary *headers = self.config.publicHeaderBLock();
        __weak typeof(self) weakSelf = self;
        if(headers){
            [headers enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [weakSelf.sessionManager.requestSerializer setValue:obj forHTTPHeaderField:key];
            }];
        }
    }
}

-(id) resultToModel:(id)responseObj model:(Class)modelClass{
    __weak typeof(self) weakSelf = self;
    id resultObj = responseObj;
    if(modelClass){
        if([responseObj isKindOfClass:[NSDictionary class]]){
            resultObj = [weakSelf dictToModel:responseObj modelClass:modelClass];
        }
        if([responseObj isKindOfClass:[NSArray class]]){
            NSMutableArray *modelList = [[NSMutableArray alloc] init];
            [(NSArray*)responseObj enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [modelList addObject:[weakSelf dictToModel:obj modelClass:modelClass]];
            }];
            
            resultObj =modelList;
        }
    }
    return resultObj;
}

-(WKModel*) dictToModel:(NSDictionary*)dic modelClass:(Class)modelClass{
    SEL sel = NSSelectorFromString(@"fromMap:type:");
    IMP imp = [modelClass methodForSelector:sel];
    WKModel* (*convertMap)(id, SEL,NSDictionary*,ModelMapType) = (void *)imp;
    WKModel *model = convertMap(modelClass,sel,dic,ModelMapTypeAPI);
    return model;
}

-(void) logRequestStart:(NSString*)path params:(id)params method:(NSString*)method{
    if([path hasPrefix:@"http"]) {
         WKLogDebug(@"请求：%@ %@",method,path);
    }else {
         WKLogDebug(@"请求：%@ %@%@",method,self.config.baseUrl,path);
    }
   
    WKLogDebug(@"请求参数：%@",params);
}


-(void) logRequestEnd:(NSURLSessionDataTask*)task response:(id)response{
    WKLogDebug(@"返回：%@",response);
}

@end
