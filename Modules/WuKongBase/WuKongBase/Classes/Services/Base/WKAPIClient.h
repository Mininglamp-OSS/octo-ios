//
//  WKAPIClient.h
//  Common
//
//  Created by tt on 2018/9/12.
//

#import <Foundation/Foundation.h>
#import <PromiseKit/PromiseKit.h>
//#import <AFNetworking/AFNetworking.h>

NS_ASSUME_NONNULL_BEGIN

@import AFNetworking;

@interface WKAPIClientConfig : NSObject

/**
 API 基地址  例如： http://api.xxx.com/v1
 */
@property(nonatomic,copy) NSString * _Nonnull baseUrl;

/**
 公共header
 */
@property(nonatomic,copy) NSDictionary*_Nullable(^ _Nullable publicHeaderBLock)(void);


/**
 错误处理
 */
@property(nonatomic,copy) NSError*_Nullable(^ _Nullable errorHandler)(id _Nullable respObj,NSError * _Nullable error);


/**
 替换请求的path路径
 */
@property(nonatomic,copy) NSString*_Nullable(^ _Nullable requestPathReplace)(NSString * _Nullable requestPath);

@end

@interface WKAPIClient : NSObject

+ (instancetype _Nonnull )sharedClient;

/**
 配置API
**/
@property(nonatomic,strong) WKAPIClientConfig *config;


-(AnyPromise* _Nonnull) GET:(NSString* _Nonnull)path parameters:(nullable id)parameters;

-(AnyPromise*_Nonnull) GET:(NSString*_Nonnull)path parameters:(nullable id)parameters model:(Class _Nullable ) modelClass;

/**
 返回task的GET请求
 */
-(NSURLSessionDataTask * _Nonnull) taskGET:(NSString* _Nonnull)path parameters:(nullable id)parameters callback:(void(^_Nullable)(NSError * _Nullable error,id _Nullable result))callback;
-(NSURLSessionDataTask* _Nonnull) taskGET:(NSString* _Nonnull)path parameters:(nullable id)parameters model:(Class _Nonnull)modelClass callback:(void(^_Nullable)(NSError * _Nullable error,id _Nullable result))callback;

-(AnyPromise*_Nonnull) POST:(NSString*_Nonnull)path parameters:(nullable id)parameters;
-(AnyPromise*_Nonnull) POST:(NSString*_Nonnull)path parameters:(nullable id)parameters model:(Class _Nullable) modelClass;

-(AnyPromise*_Nonnull) POST:(NSString*_Nonnull)path parameters:(nullable id)parameters headers:(NSDictionary<NSString*,NSString*>*_Nullable)headers;


-(AnyPromise*_Nonnull) DELETE:(NSString*_Nonnull)path parameters:(nullable id)parameters;

-(AnyPromise*_Nonnull) PUT:(NSString*_Nonnull)path parameters:(nullable id)parameters;


-(NSURLSessionDataTask* _Nonnull) fileUpload:(NSString* _Nonnull)path fileURL:(NSString* _Nonnull)fileUrl progress:(void(^ _Nullable)(NSProgress * _Nonnull progress)) progressCallback completeCallback:(void(^ _Nullable)(id __nullable resposeObject,NSError * __nullable error)) completeCallback;


/// 文件上传
/// @param path 上传路径
/// @param data 上传数据
/// @param progressCallback 进度回调
/// @param completeCallback 完成回调
-(NSURLSessionDataTask* _Nonnull) fileUpload:(NSString* _Nonnull)path data:(NSData* _Nonnull)data progress:(void(^_Nullable)(NSProgress * _Nonnull progress)) progressCallback completeCallback:(void(^_Nullable)(id __nullable resposeObject,NSError * __nullable error)) completeCallback;

-(NSURLSessionDataTask*) fileUpload:(NSString*)path data:(NSData*)data fileName:(NSString*)fileName progress:(void(^_Nullable)(NSProgress *progress)) progressCallback completeCallback:(void(^)(id resposeObject,NSError *error)) completeCallback ;


/**
 上传聊天文件
 @param serverPath 服务器上的路径
 @param localURL 本地文件url
 */
-(void) uploadChatFile:(NSString*_Nullable)serverPath localURL:(NSURL*)localURL progress:(void(^_Nullable)(NSProgress * _Nonnull progress)) progressCallback completeCallback:(void(^_Nullable)(id __nullable resposeObject,NSError * __nullable error)) completeCallback;

/**
 创建一个上传任务

 @param path 请求路径
 @param fileUrl 文件路径
 @param uploadProgressBlock 上传进度回调
 @param completeCallback 完成回调
 @return 任务对象
 */
-(NSURLSessionDataTask*_Nullable) createFileUploadTask:(NSString* _Nonnull)path fileURL:(NSString*_Nullable)fileUrl  progress:(void (^_Nullable)(NSProgress * _Nullable uploadProgress)) uploadProgressBlock completeCallback:(void(^_Nullable)(id _Nullable responseObj,NSError * _Nullable error)) completeCallback;




/**
 创建一个下载任务

 @param path 下载地址
 @param storePath 存储在本地的路径
 @param downloadProgressBlock 下载进度回调
 @param completeCallback 完成下载回调
 @return 任务对象
 */
-(NSURLSessionDownloadTask*_Nullable) createDownloadTask:(NSString*_Nonnull)path storePath:(NSString*_Nonnull)storePath progress:(void (^_Nullable)(NSProgress *  _Nullable downloadProgress)) downloadProgressBlock completeCallback:(void(^_Nullable)(NSError * _Nullable error)) completeCallback;
@end


NS_ASSUME_NONNULL_END
