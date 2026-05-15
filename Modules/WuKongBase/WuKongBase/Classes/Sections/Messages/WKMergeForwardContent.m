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
            if(![msgItem isKindOfClass:[NSDictionary class]]) {
                // 单条 dict 类型异常：保住条目数 + 把异常原因展示出来
                [messages addObject:[self placeholderMessageWithReason:[NSString stringWithFormat:@"item not a dict (%@)", NSStringFromClass([msgItem class])] rawDict:nil]];
                continue;
            }
            WKMessage *msg = nil;
            NSString *failReason = nil;
            @try {
                msg = [WKMessageUtil toMessage:msgItem];
            } @catch (NSException *exception) {
                failReason = [NSString stringWithFormat:@"%@: %@", exception.name ?: @"NSException", exception.reason ?: @"unknown"];
                NSLog(@"[MergeForward] decode message exception: %@", exception);
            }
            if(msg) {
                [messages addObject:msg];
            } else {
                if(!failReason) failReason = @"toMessage 返回 nil（可能 payload 缺失或被截断）";
                [messages addObject:[self placeholderMessageWithReason:failReason rawDict:msgItem]];
            }
        }
    }
    self.msgs = messages;

}

// 构造一条占位消息：保留可知的元信息（message_id / timestamp / from_uid），
// content 用 WKTextContent 装错误描述，详情页会按文本渲染出来，用户能看到具体异常原因。
- (WKMessage *)placeholderMessageWithReason:(NSString *)reason rawDict:(NSDictionary *)rawDict {
    WKMessage *msg = [[WKMessage alloc] init];
    msg.status = WK_MESSAGE_SUCCESS;
    if([rawDict isKindOfClass:[NSDictionary class]]) {
        id mid = rawDict[@"message_id"];
        if([mid isKindOfClass:[NSString class]]) {
            msg.messageId = [[[NSDecimalNumber alloc] initWithString:mid] unsignedLongLongValue];
        } else if([mid isKindOfClass:[NSNumber class]]) {
            msg.messageId = [(NSNumber *)mid unsignedLongLongValue];
        }
        msg.timestamp = rawDict[@"timestamp"] ? [rawDict[@"timestamp"] integerValue] : 0;
        msg.fromUid = rawDict[@"from_uid"] ?: @"";
    }
    NSString *display = [NSString stringWithFormat:@"[此条消息加载失败: %@]", reason ?: @"unknown"];
    WKTextContent *placeholder = [[WKTextContent alloc] initWithContent:display];
    msg.content = placeholder;
    msg.contentType = WK_TEXT;
    return msg;
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
    messageDict[@"message_seq"] = @(message.messageSeq);
    messageDict[@"timestamp"] = @(message.timestamp);
    messageDict[@"from_uid"] = message.fromUid?:@"";
    if(message.channel.channelId.length > 0) {
        messageDict[@"channel_id"] = message.channel.channelId;
        messageDict[@"channel_type"] = @(message.channel.channelType);
    }

    // payload 取自 SDK 解码时填好的 contentDict（接收消息一定有）；
    // 但本地发送中/流式消息的 contentDict 可能为 nil 或字段不全 —— 现场调用 encodeWithJSON 兜底，
    // 避免 NSMutableDictionary 设 nil value 导致 key 缺失，接收端再解为 unknown。
    NSDictionary *payload = message.content.contentDict;
    if(![payload isKindOfClass:[NSDictionary class]] || payload.count == 0) {
        @try {
            NSDictionary *encoded = [message.content encodeWithJSON];
            if([encoded isKindOfClass:[NSDictionary class]] && encoded.count > 0) {
                NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:encoded];
                if(!m[@"type"]) m[@"type"] = @(message.contentType);
                payload = m;
            }
        } @catch (NSException *exception) {
            NSLog(@"[MergeForward] encode message exception: %@", exception);
        }
    }
    if(payload) {
        messageDict[@"payload"] = payload;
    }
    return messageDict;
}

+(NSNumber*) contentType {
    return @(WK_MERGEFORWARD);
}

- (NSString *)conversationDigest {
    return LLang(@"[聊天记录]");
}

@end
