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
    self.users = contentDic[@"users"];
    NSArray<NSDictionary*> *msgDicts = contentDic[@"msgs"];
    NSMutableArray<WKMessage*> *messages = [NSMutableArray array];
    if(msgDicts && msgDicts.count>0) {
        for (NSDictionary *msgDict in msgDicts) {
            [messages addObject:[WKMessageUtil toMessage:msgDict]];
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
