//
//  WKCardContent.m
//  WuKongBase
//
//  Created by tt on 2020/5/5.
//

#import "WKCardContent.h"
#import "WuKongBase.h"

@implementation WKCardContent


+(WKCardContent*) cardContent:(NSString*)vercode uid:(NSString*)uid name:(NSString*)name avatar:(NSString*)avatar {
    WKCardContent *content = [WKCardContent new];
    content.uid = uid;
    content.name = name;
    content.avatar = avatar;
    content.vercode = vercode;
    return content;
}

- (NSDictionary *)encodeWithJSON {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"uid"] = self.uid?:@"";
    dict[@"name"] = self.name?:@"";
    dict[@"avatar"] = self.avatar?:@"";
    dict[@"vercode"] = self.vercode?:@"";
    return dict;
}

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    self.uid = contentDic[@"uid"];
    self.name = contentDic[@"name"];
    self.avatar = contentDic[@"avatar"];
    self.vercode = contentDic[@"vercode"]?:@"";
}


+(NSNumber*) contentType {
    return @(WK_CARD);
}


- (NSString *)conversationDigest {
    return LLang(@"[名片]");
}

- (NSString *)searchableWord {
    return @"[名片]";
}
@end
