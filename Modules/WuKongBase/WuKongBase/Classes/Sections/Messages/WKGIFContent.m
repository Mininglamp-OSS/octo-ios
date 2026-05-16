//
//  WKGIFContent.m
//  WuKongBase
//
//  Created by tt on 2020/2/2.
//

#import "WKGIFContent.h"
#import "WuKongBase.h"
@implementation WKGIFContent

+(instancetype) initWithURL:(NSString*)url width:(NSInteger)width height:(NSInteger)height {
    WKGIFContent *content = [WKGIFContent new];
    content.url = url;
    content.width = width;
    content.height = height;
    return content;
}

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    self.url = contentDic[@"url"];
    self.width = contentDic[@"width"]?[contentDic[@"width"] integerValue]:100;
    self.height = contentDic[@"height"]?[contentDic[@"height"] integerValue]:100;
}

- (NSDictionary *)encodeWithJSON {
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
    [dataDict setObject:self.url?:@"" forKey:@"url"];
    [dataDict setObject:@(self.width) forKey:@"width"];
    [dataDict setObject:@(self.height) forKey:@"height"];
    return dataDict;
}

+(NSNumber*) contentType {
    return @(WK_GIF);
}

- (NSString *)conversationDigest {
    return LLang(@"[表情]");
}

@end
