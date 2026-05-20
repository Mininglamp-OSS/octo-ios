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

/// 自定义 multipart POST（支持多个表单字段 + 自定义文件参数）
-(NSURLSessionDataTask *_Nullable)fileUpload:(NSString *_Nonnull)path
                         formFields:(nullable NSDictionary<NSString *, NSString *> *)formFields
                           fileData:(NSData *_Nonnull)fileData
                           fileName:(NSString *_Nonnull)fileName
                          fileField:(NSString *_Nonnull)fileField
                           mimeType:(NSString *_Nonnull)mimeType
                            timeout:(NSTimeInterval)timeout
                   completeCallback:(void(^_Nullable)(id _Nullable responseObject,
                                             NSError * _Nullable error))completeCallback;

/**
 直传到预签名 URL（COS 等 OSS 直传模式）。
 用 PUT + 原始 body，Content-Type 必须与后端签 URL 时的一致，否则签名校验失败。

 @param uploadUrl     完整预签名 PUT URL（不是 API path，是 OSS host）
 @param fileUrl       本地文件路径，支持 "file://" 前缀
 @param contentType   必须严格匹配预签名时声明的值
 @param contentDisposition  可选，凭证里带就传，没有就别传
 */
-(NSURLSessionUploadTask*_Nullable) createFileUploadPutTask:(NSString*_Nonnull)uploadUrl
                                                     fileURL:(NSString*_Nonnull)fileUrl
                                                 contentType:(NSString*_Nonnull)contentType
                                          contentDisposition:(NSString*_Nullable)contentDisposition
                                                    progress:(void (^_Nullable)(NSProgress * _Nullable uploadProgress))uploadProgressBlock
                                            completeCallback:(void(^_Nullable)(NSInteger statusCode, NSError * _Nullable error))completeCallback;

/**
 取得 COS 预签名直传凭证。query 参数走 NSURLQueryItem 编码，安全处理
 filename 里的 & = ? + # 等特殊字符（否则会污染签名 → 403）。

 @param path        服务端用于签 URL 的对象 key，调用方负责构造
                    （如 "/<channelType>/<channelId>/<uuid>.jpg" 或 "/sticker/<uuid>.jpg"）
 @param type        资源类型，常用 "chat" / "sticker"
 @param filename    原始文件名，可含中文 / 空格 / & = 等
 @param contentType MIME，PUT 时必须用一样的值
 @param fileSize    文件字节数

 returns Promise<NSDictionary> { uploadUrl, downloadUrl, contentType,
                                  contentDisposition?, key?, expiredTime? }
 */
-(AnyPromise*_Nonnull) getUploadCredentialsForPath:(NSString*_Nonnull)path
                                              type:(NSString*_Nonnull)type
                                          filename:(NSString*_Nonnull)filename
                                       contentType:(NSString*_Nonnull)contentType
                                          fileSize:(long long)fileSize;




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
