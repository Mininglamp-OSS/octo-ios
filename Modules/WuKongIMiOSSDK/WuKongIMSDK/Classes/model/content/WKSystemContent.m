//
//  WKSystemContent.m
//  WuKongIMSDK
//
//  Created by tt on 2020/1/4.
//

#import "WKSystemContent.h"
#import "WKConnectionManager.h"
#import "WKSDK.h"
@interface WKSystemContent ()



@end
@implementation WKSystemContent

- (void)decodeWithJSON:(NSDictionary *)contentDic {
     self.content = contentDic;
    self.displayContent =[self getDisplayContent];
}


- (NSDictionary *)encodeWithJSON {
    return self.content;
}

- (NSString *)conversationDigest {
    return [self.displayContent stringByReplacingOccurrencesOfString:@"\n" withString:@" "];;
}

- (NSString *)searchableWord {
    return self.displayContent;
}

-(NSString*) getDisplayContent {
    if(!self.content) {
        return @"未知";
    }
    NSString *content = self.content[@"content"];
    id extra =self.content[@"extra"];
    if(extra && [extra isKindOfClass:[NSArray class]]) {
        NSArray *extraArray = (NSArray*)extra;
        if(extraArray.count>0) {
            for (int i=0; i<=extraArray.count-1; i++) {
                NSDictionary *extrDict = extraArray[i];
                NSString *name = extrDict[@"name"]?:@"";
                
                if([[WKSDK shared].options.connectInfo.uid isEqualToString:extrDict[@"uid"]]) {
                    name = @"你";
                }
                content = [content stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"{%d}",i] withString:name];
            }
        }
        
    }
    return content;
}
@end
