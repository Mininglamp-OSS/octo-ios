//
//  WKFileContent.m
//  WuKongIMSDK
//
//  文件消息content

#import "WKFileContent.h"
#import "WKConst.h"
#import "WKFileUtil.h"
#import "WKSDK.h"
#import "WKMediaUtil.h"

@interface WKFileContent ()

@property(nonatomic,strong) NSData *fileData;

@end

@implementation WKFileContent

+ (instancetype)initWithFileURL:(NSURL *)fileURL {
    WKFileContent *content = [WKFileContent new];
    NSString *fileName = fileURL.lastPathComponent;
    content.name = fileName;
    content.fileExtension = [NSString stringWithFormat:@".%@", fileURL.pathExtension];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:fileURL.path error:nil];
    content.fileSize = [attrs fileSize];
    content.fileData = [NSData dataWithContentsOfURL:fileURL];

    return content;
}

- (NSString *)extension {
    return self.fileExtension ?: @"";
}

- (void)writeDataToLocalPath {
    [super writeDataToLocalPath];
    if (self.fileData) {
        [self.fileData writeToFile:self.localPath atomically:YES];
    }
}

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    self.name = contentDic[@"name"] ?: @"";
    self.fileExtension = contentDic[@"extension"] ?: @"";
    self.fileSize = contentDic[@"size"] ? [contentDic[@"size"] longLongValue] : 0;
    self.remoteUrl = contentDic[@"url"] ?: @"";
}

- (NSDictionary *)encodeWithJSON {
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
    [dataDict setObject:self.name ?: @"" forKey:@"name"];
    [dataDict setObject:self.fileExtension ?: @"" forKey:@"extension"];
    [dataDict setObject:@(self.fileSize) forKey:@"size"];
    [dataDict setObject:self.remoteUrl ?: @"" forKey:@"url"];
    return dataDict;
}

+ (NSNumber *)contentType {
    return @(8); // WK_FILE
}

- (NSString *)conversationDigest {
    return @"[文件]";
}

- (NSString *)searchableWord {
    return @"[文件]";
}

@end
