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
        NSURL *localFileURL;
        if ([fileUrl hasPrefix:@"file://"]) {
            NSString *filePath = [fileUrl substringFromIndex:[@"file://" length]];
            localFileURL = [NSURL fileURLWithPath:filePath];
        } else {
            localFileURL = [NSURL URLWithString:fileUrl];
        }
        [formData appendPartWithFileURL:localFileURL name:@"file" error:&fileError];
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

-(NSURLSessionDataTask *)fileUpload:(NSString *)path
                         formFields:(NSDictionary<NSString *, NSString *> *)formFields
                           fileData:(NSData *)fileData
                           fileName:(NSString *)fileName
                          fileField:(NSString *)fileField
                           mimeType:(NSString *)mimeType
                            timeout:(NSTimeInterval)timeout
                   completeCallback:(void(^)(id, NSError *))completeCallback {

    NSString *requestPath = path;
    if (_config.requestPathReplace) {
        requestPath = _config.requestPathReplace(path);
    }
    [self resetPublicHeader];

    NSError *serializerError = nil;
    NSMutableURLRequest *request =
        [_sessionManager.requestSerializer
         multipartFormRequestWithMethod:@"POST"
         URLString:[[NSURL URLWithString:[self pathURLEncode:requestPath]
                            relativeToURL:_sessionManager.baseURL] absoluteString]
         parameters:nil
         constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
             [formData appendPartWithFileData:fileData
                                        name:fileField
                                    fileName:fileName
                                    mimeType:mimeType];
             [formFields enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
                 [formData appendPartWithFormData:[value dataUsingEncoding:NSUTF8StringEncoding]
                                             name:key];
             }];
         }
         error:&serializerError];

    if (serializerError) {
        if (completeCallback) completeCallback(nil, serializerError);
        return nil;
    }

    if (timeout > 0) {
        request.timeoutInterval = timeout;
    }

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task =
        [_sessionManager dataTaskWithRequest:request
                              uploadProgress:nil
                            downloadProgress:nil
                           completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
            if (error) {
                NSError *er = nil;
                if (weakSelf.config.errorHandler) {
                    er = weakSelf.config.errorHandler(nil, error);
                }
                if (!er) {
                    er = error;
                }
                if (completeCallback) completeCallback(nil, er);
            } else {
                if (completeCallback) completeCallback(responseObject, nil);
            }
        }];
    [task resume];
    return task;
}

-(NSURLSessionDownloadTask*) createDownloadTask:(NSString*)path storePath:(NSString*_Nonnull)storePath progress:(void (^)(NSProgress *downloadProgress)) downloadProgressBlock completeCallback:(void(^)(NSError *error)) completeCallback{
    NSString *requestPath = path;
    if(_config.requestPathReplace) {
        requestPath = _config.requestPathReplace(path);
    }
     // 完整 URL 不再做 percent encoding，避免中文文件名被多重编码导致 404
     NSString *urlString;
     if ([requestPath hasPrefix:@"http"]) {
         urlString = requestPath;
     } else {
         urlString = [[NSURL URLWithString:[self pathURLEncode:requestPath] relativeToURL:_sessionManager.baseURL] absoluteString];
     }
     NSMutableURLRequest *request = [_sessionManager.requestSerializer requestWithMethod:@"GET" URLString:urlString parameters:nil error:nil];
   NSURLSessionDownloadTask *task = [_sessionManager downloadTaskWithRequest:request progress:downloadProgressBlock destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return [NSURL fileURLWithPath:storePath];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        if(completeCallback) {
            completeCallback(error);
        }
    }];
    return task;
}

-(NSURLSessionUploadTask*) createFileUploadPutTask:(NSString*)uploadUrl
                                            fileURL:(NSString*)fileUrl
                                        contentType:(NSString*)contentType
                                 contentDisposition:(NSString*)contentDisposition
                                           progress:(void (^)(NSProgress *uploadProgress))uploadProgressBlock
                                   completeCallback:(void(^)(NSInteger statusCode, NSError *error))completeCallback {
    NSURL *localFileURL;
    if ([fileUrl hasPrefix:@"file://"]) {
        localFileURL = [NSURL fileURLWithPath:[fileUrl substringFromIndex:[@"file://" length]]];
    } else if ([fileUrl hasPrefix:@"/"]) {
        localFileURL = [NSURL fileURLWithPath:fileUrl];
    } else {
        localFileURL = [NSURL URLWithString:fileUrl];
    }
    NSURL *putURL = [NSURL URLWithString:uploadUrl];
    if (!putURL || !localFileURL) {
        if (completeCallback) {
            completeCallback(0, [NSError errorWithDomain:@"WKAPIClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"invalid uploadUrl or fileURL"}]);
        }
        return nil;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:putURL];
    request.HTTPMethod = @"PUT";
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    if (contentDisposition.length > 0) {
        [request setValue:contentDisposition forHTTPHeaderField:@"Content-Disposition"];
    }
    // COS 预签名 URL 不要 Authorization；AFJSONRequestSerializer 也不该参与直传
    // → 这里直接走 AFURLSessionManager 层（绕开公共 header）。

    NSURLSessionUploadTask *task = [_sessionManager uploadTaskWithRequest:request
                                                                 fromFile:localFileURL
                                                                 progress:^(NSProgress * _Nonnull uploadProgress) {
        if (uploadProgressBlock) {
            uploadProgressBlock(uploadProgress);
        }
    } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        NSInteger statusCode = 0;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            statusCode = ((NSHTTPURLResponse *)response).statusCode;
        }
        if (!error && (statusCode < 200 || statusCode >= 300)) {
            error = [NSError errorWithDomain:@"WKAPIClient" code:statusCode userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"PUT 上传返回非 2xx: %ld", (long)statusCode]}];
        }
        if (completeCallback) {
            completeCallback(statusCode, error);
        }
    }];
    return task;
}

-(AnyPromise*) getUploadCredentialsForPath:(NSString*)path
                                       type:(NSString*)type
                                   filename:(NSString*)filename
                                contentType:(NSString*)contentType
                                   fileSize:(long long)fileSize {
    // 用 NSURLComponents + NSURLQueryItem 来构造 query —— 它会对 value 里的
    // & = ? + # 等特殊字符做正确的 percent-encode，避免类似
    // "Q&A=final.pdf" 这种 filename 把后续参数顶掉造成签名失败。
    NSString *base = [NSString stringWithFormat:@"%@file/upload/credentials", [WKApp shared].config.fileBaseUrl];
    NSURLComponents *components = [NSURLComponents componentsWithString:base];
    if (!components) {
        return [AnyPromise promiseWithValue:[NSError errorWithDomain:@"WKAPIClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"invalid fileBaseUrl"}]];
    }
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"path"        value:path        ?: @""],
        [NSURLQueryItem queryItemWithName:@"type"        value:type        ?: @""],
        [NSURLQueryItem queryItemWithName:@"filename"    value:filename    ?: @""],
        [NSURLQueryItem queryItemWithName:@"contentType" value:contentType ?: @""],
        [NSURLQueryItem queryItemWithName:@"fileSize"    value:[NSString stringWithFormat:@"%lld", fileSize]],
    ];
    NSString *url = components.URL.absoluteString ?: base;
    return [self GET:url parameters:nil];
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
                // 空字串代表 caller 希望清除该 header（避免 stale value 粘在 requestSerializer 上）
                NSString *valueStr = [obj isKindOfClass:[NSString class]] ? (NSString *)obj : [obj description];
                if (valueStr.length == 0) {
                    [weakSelf.sessionManager.requestSerializer setValue:nil forHTTPHeaderField:key];
                } else {
                    [weakSelf.sessionManager.requestSerializer setValue:valueStr forHTTPHeaderField:key];
                }
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
