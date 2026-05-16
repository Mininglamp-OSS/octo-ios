//
//  WKFileLocationHelper.h
//  Pods
//
//  Created by tt on 2018/10/17.
//

#import <Foundation/Foundation.h>

@interface WKFileLocationHelper : NSObject

+ (NSString *)getAppDocumentPath;

+ (NSString *)getAppTempPath;

+ (NSString *)userDirectory;

+ (NSString *)genFilenameWithExt:(NSString *)ext;

+ (NSString *)filepathForVideo:(NSString *)filename;

+ (NSString *)filepathForImage:(NSString *)filename;

+ (NSString *)filepathForTempDir:(NSString *)dirname
                        filename:(NSString *)filename;

@end
