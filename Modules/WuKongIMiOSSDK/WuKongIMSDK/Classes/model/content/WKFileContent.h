//
//  WKFileContent.h
//  WuKongIMSDK
//
//  文件消息content

#import <Foundation/Foundation.h>
#import "WKMediaMessageContent.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKFileContent : WKMediaMessageContent

@property(nonatomic,copy) NSString *name; // 文件名
@property(nonatomic,copy) NSString *fileExtension; // 文件扩展名
@property(nonatomic,assign) long long fileSize; // 文件大小（字节）

/// 通过本地文件URL创建文件消息
/// @param fileURL 本地文件路径
+ (instancetype)initWithFileURL:(NSURL *)fileURL;

@end

NS_ASSUME_NONNULL_END
