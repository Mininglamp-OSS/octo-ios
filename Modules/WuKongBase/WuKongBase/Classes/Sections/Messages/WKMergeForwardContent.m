//
//  WKMergeForwardContent.m
//  WuKongBase
//
//  Created by tt on 2020/10/12.
//

#import "WKMergeForwardContent.h"
#import "WKConstant.h"
#import <WuKongIMSDK/WKMOSContentConvertManager.h>
#import "WKMessageUtil.h"
#import "WuKongBase.h"

@interface WKMergeForwardContent ()

@property(nonatomic,copy) NSString *titleInner;

@end

@implementation WKMergeForwardContent

+(instancetype) msgs:(NSArray<WKMessage*>*)msgs users:(NSArray<NSDictionary*>*)users channelType:(WKChannelType)channelType {
    WKMergeForwardContent *content = [WKMergeForwardContent new];
    content.msgs = msgs;
    content.users = users;
    content.channelType = channelType;
    return content;
}


- (void)decodeWithJSON:(NSDictionary *)contentDic {

    self.channelType = [contentDic[@"channel_type"] intValue];
    // 外部群 Phase 1：users 数组对齐 web PR #981, 将 is_external / source_space_name 原样透传
    // 后端 payload 已把这两个字段塞在每个 user 字典里，这里只需确保不被字段白名单过滤掉即可。
    // WKMergeForwardDetailVM 渲染头像/名称时可以读取 user[@"is_external"] / user[@"source_space_name"]
    // 来决定是否显示外部 badge + @SpaceName 后缀（与群成员列表一致）。
    NSArray *rawUsers = contentDic[@"users"];
    if([rawUsers isKindOfClass:[NSArray class]]) {
        self.users = rawUsers;
    } else {
        self.users = nil;
    }
    NSArray<NSDictionary*> *msgDicts = contentDic[@"msgs"];
    NSMutableArray<WKMessage*> *messages = [NSMutableArray array];
    if(msgDicts && [msgDicts isKindOfClass:[NSArray class]] && msgDicts.count>0) {
        for (id msgItem in msgDicts) {
            if(![msgItem isKindOfClass:[NSDictionary class]]) continue;
            @try {
                WKMessage *msg = [WKMessageUtil toMessage:msgItem];
                if(msg) {
                    [messages addObject:msg];
                }
            } @catch (NSException *exception) {
                NSLog(@"[MergeForward] decode message exception: %@", exception);
            }
        }
    }
    self.msgs = messages;

}

- (NSDictionary *)encodeWithJSON {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"channel_type"] = @(self.channelType);
    if(self.users && self.users.count>0) {
        dict[@"users"] = self.users;
    }
    if(self.msgs && self.msgs.count>0) {
        NSMutableArray<NSDictionary*> *messageDicts = [NSMutableArray array];
        for (WKMessage *message in self.msgs) {
            [messageDicts addObject:[self messageToDict:message]];
        }
        dict[@"msgs"] = messageDicts;
    }
    return dict;

}

- (NSString *)title {
    if(!_titleInner) {
        _titleInner = [self getTitle];
    }
    return _titleInner;
}

-(NSString*) getTitle{
    if(self.channelType!=WK_PERSON) {
        return LLang(@"群的聊天记录");
    }
    if(!self.users || self.users.count<=0) {
        return @"";
    }
    NSString *title = @"";
    if(self.users.count==1) {
        title = [NSString stringWithFormat:LLang(@"%@的聊天记录"),self.users[0][@"name"]?:@""];
    }else if(self.users.count>=2) {
        title = [NSString stringWithFormat:LLang(@"%@和%@的聊天记录"),self.users[0][@"name"]?:@"",self.users[1][@"name"]?:@""];
    }
    return title;
}


-(NSDictionary*) messageToDict:(WKMessage*)message {
    NSMutableDictionary *messageDict = [NSMutableDictionary dictionary];
    messageDict[@"message_id"] = [NSString stringWithFormat:@"%llu",message.messageId];
    messageDict[@"timestamp"] = @(message.timestamp);
    messageDict[@"from_uid"] = message.fromUid?:@"";
    messageDict[@"payload"] = message.content.contentDict;
    return messageDict;
}

+(NSNumber*) contentType {
    return @(WK_MERGEFORWARD);
}

- (NSString *)conversationDigest {
    return LLang(@"[聊天记录]");
}

@end
