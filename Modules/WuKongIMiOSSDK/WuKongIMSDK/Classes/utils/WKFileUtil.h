//
//  WKFileUtil.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKFileUtil : NSObject
+(BOOL)copyFileFromPath:(NSString *)fromPath toPath:(NSString *)toPath;

+ (BOOL)moveFileFromPath:(NSString *)fromPath toPath:(NSString *)toPath;

+ (BOOL)fileIsExistOfPath:(NSString *)filePath;


/**
 如果目录不存在，则创建目录

 @param dirPath 目录路径
 @return <#return value description#>
 */
+(BOOL)createDirectoryIfNotExist:(NSString *)dirPath;


/**
 如果文件不存在，则创建文件

 @param filePath 文件路径
 @return <#return value description#>
 */
+ (BOOL)creatFileIfNotExist:(NSString *)filePath;

+ (BOOL)removeFileOfPath:(NSString *)filePath;

+ (BOOL)removeFileOfURL:(NSURL *)fileURL;
@end

NS_ASSUME_NONNULL_END
