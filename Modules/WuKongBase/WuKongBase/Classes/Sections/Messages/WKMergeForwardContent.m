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
#import <CommonCrypto/CommonDigest.h>

// 按字典键排序后序列化，使相同输入的摘要不受字典键顺序影响。
static NSString *WKMergeForwardFileDigest(id object) {
    if (![NSJSONSerialization isValidJSONObject:object]) return nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingSortedKeys error:nil];
    if (!data) return nil;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

@interface WKMergeForwardContent ()

@property(nonatomic,copy) NSString *titleInner;
@property(nonatomic,copy) NSString *fileCacheInstanceScope;
@property(nonatomic,copy) NSString *fileCachePayloadDigest;
@property(nonatomic,copy) NSIndexSet *generatedFileCacheIndexes;

- (NSString *)fileCacheRootScope;
- (void)applyFileCacheScope:(NSString *)scope;

@end

@implementation WKMergeForwardContent

- (NSString *)fileCacheRootScope {
    WKMessage *parent = self.message;
    NSString *clientMsgNo = [parent.clientMsgNo isKindOfClass:NSString.class] ? parent.clientMsgNo : nil;
    NSString *channelId = [parent.channel.channelId isKindOfClass:NSString.class] ? parent.channel.channelId : @"";
    NSArray *identity = nil;
    if (clientMsgNo.length > 0) {
        identity = @[@"client", @(parent.channel.channelType), channelId, clientMsgNo];
    } else if (parent.messageId != 0) {
        identity = @[@"message", @(parent.channel.channelType), channelId,
                     [NSString stringWithFormat:@"%llu", parent.messageId]];
    }
    NSString *digest = identity ? WKMergeForwardFileDigest(identity) : nil;
    if (digest) return [@"parent:" stringByAppendingString:digest];
    // 无可靠外层编号时按内容对象实例隔离；同一实例内的重复调用不改变作用域。
    if (!self.fileCacheInstanceScope) {
        self.fileCacheInstanceScope = [@"instance:" stringByAppendingString:NSUUID.UUID.UUIDString];
    }
    return self.fileCacheInstanceScope;
}

- (void)setMessage:(WKMessage *)message {
    [super setMessage:message];
    // 外层消息在正文解码完成后才绑定，此时补入真实外层作用域。
    if (message && self.generatedFileCacheIndexes) {
        [self applyFileCacheScope:[self fileCacheRootScope]];
    }
}

- (void)applyFileCacheScope:(NSString *)scope {
    if (!self.generatedFileCacheIndexes) return;
    for (NSUInteger index = 0; index < self.msgs.count; index++) {
        WKMessage *msg = self.msgs[index];
        NSString *messageId = [NSString stringWithFormat:@"%llu", msg.messageId];
        if ([self.generatedFileCacheIndexes containsIndex:index] &&
            msg.contentType == WK_FILE && [msg.content isKindOfClass:WKFileContent.class]) {
            NSString *identity = WKMergeForwardFileDigest(@[scope, self.fileCachePayloadDigest, @(index), messageId]);
            // 摘要生成失败时保留此前已生成的隔离编号，不退回空编号缓存。
            if (identity) msg.clientMsgNo = [@"mf-v2-" stringByAppendingString:identity];
        } else if ([msg.content isKindOfClass:WKMergeForwardContent.class]) {
            // 每层位置都参与作用域，避免相同内层载荷在不同外层或不同位置共用缓存。
            NSString *nestedScope = WKMergeForwardFileDigest(@[scope, @"nested", @(index), messageId]);
            if (nestedScope) [(WKMergeForwardContent *)msg.content applyFileCacheScope:nestedScope];
        }
    }
}

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
    NSMutableIndexSet *generatedFileCacheIndexes = [NSMutableIndexSet indexSet];
    NSString *fileCacheScope = nil;
    if(msgDicts && [msgDicts isKindOfClass:[NSArray class]] && msgDicts.count>0) {
        // self.currentDb: 当本条 MergeForward 由 WKMessageDB.toMessage:db: → decodeContent:data:db:
        // 链路一路带 db 进来时, 这里非 nil; 透给嵌套消息解码, 嵌套 decodeReply 查 ChannelInfo
        // 走 -queryChannelInfo:db: 复用同一连接, 避免再次 [FMDatabaseQueue inDatabase:]
        // 触发 FMDB 反重入断言 SIGABRT (Bugly: handleSyncConversation: → replaceMessages:
        // inTransaction: 内). 协议层/UI 层调用 (DataSourceModule / WKReplyView) 时 currentDb
        // 为 nil, +toMessage:db: 内部走与旧 +toMessage: 完全等价的路径.
        FMDatabase *txDb = [self currentDb];
        for (NSUInteger index = 0; index < msgDicts.count; index++) {
            id msgItem = msgDicts[index];
            if(![msgItem isKindOfClass:[NSDictionary class]]) {
                // 单条 dict 类型异常：保住条目数 + 把异常原因展示出来
                [messages addObject:[self placeholderMessageWithReason:[NSString stringWithFormat:@"item not a dict (%@)", NSStringFromClass([msgItem class])] rawDict:nil]];
                continue;
            }
            WKMessage *msg = nil;
            NSString *failReason = nil;
            @try {
                msg = [WKMessageUtil toMessage:msgItem db:txDb];
                if (msg.contentType == WK_FILE && [msg.content isKindOfClass:WKFileContent.class] &&
                    (![msg.clientMsgNo isKindOfClass:NSString.class] || msg.clientMsgNo.length == 0)) {
                    // 文件子消息缺少有效 client_msg_no 时，同账号、同会话、同扩展名的文件
                    // 会共用缓存路径（例如 <channel>/.pdf）。已有的非空字符串编号保持不变。
                    // 编号包含外层作用域、消息数组摘要、原始位置和消息 ID；外层尚未绑定时
                    // 先按实例隔离，绑定后统一更新。不写回转发载荷，只用于本地缓存。
                    if (!fileCacheScope) fileCacheScope = WKMergeForwardFileDigest(msgDicts);
                    NSString *identity = fileCacheScope
                        ? WKMergeForwardFileDigest(@[[self fileCacheRootScope], fileCacheScope, @(index),
                                                    [NSString stringWithFormat:@"%llu", msg.messageId]])
                        : nil;
                    if (identity) {
                        msg.clientMsgNo = [@"mf-v2-" stringByAppendingString:identity];
                        [generatedFileCacheIndexes addIndex:index];
                    } else {
                        // 摘要生成失败时显示错误占位，避免继续使用空编号对应的公共缓存。
                        failReason = @"无法生成文件缓存标识";
                        msg = nil;
                    }
                }
            } @catch (NSException *exception) {
                msg = nil;
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
    self.fileCachePayloadDigest = fileCacheScope;
    self.generatedFileCacheIndexes = generatedFileCacheIndexes;
    self.msgs = messages;
    [self applyFileCacheScope:[self fileCacheRootScope]];

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
