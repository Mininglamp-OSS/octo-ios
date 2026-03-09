//
//  WKMessageContent.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/29.
//

NSString * const WKEntityTypeRobotCommand = @"bot_command";

#import "WKMessageContent.h"
#import "WKSDK.h"
#import "WKMOSContentConvertManager.h"
#import "WKChannelInfoDB.h"

@implementation WKMessageEntity


+(WKMessageEntity*) type:(NSString*)type range:(NSRange)range{
    WKMessageEntity *entity = [WKMessageEntity new];
    entity.type = type;
    entity.range = range;
    return entity;
}

+(WKMessageEntity*) type:(NSString*)type range:(NSRange)range value:(id)value {
    WKMessageEntity *entity = [WKMessageEntity new];
    entity.type = type;
    entity.range = range;
    entity.value = value;
    return entity;
}

@end

@implementation WKMentionedInfo

- (instancetype)initWithMentionedType:(WKMentionedType)type {
    return [self initWithMentionedType:WK_Mentioned_All uids:nil];
}

- (instancetype)initWithMentionedType:(WKMentionedType)type
                           uids:(NSArray *)uids{
    self = [super init];
    if(self) {
        self.type = type;
        self.uids = uids;
    }
    return self;
}


- (BOOL)isMentionedMe {
    if([self.uids containsObject:[WKSDK shared].options.connectInfo.uid]||self.type == WK_Mentioned_All) {
        return true;
    }
    return false;
}

@end

@implementation WKReply


@end

@interface WKMessageContent ()

@property(nonatomic,strong) FMDatabase *db;

@end

@implementation WKMessageContent


- (NSData *)encode {
    @try {
        NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
        // 正文类型
        if(self.realContentType !=0) {
            [dataDict setObject:@(self.realContentType) forKey:@"type"];
        }else {
            [dataDict setObject:[[self class] contentType] forKey:@"type"];
        }
       
        
        // 编码用户信息
        [self encodeSenderUserInfo:dataDict];
        
        // 编码@数据
        [self encodeMentionInfo:dataDict];
        
        // 编码回复
        [self encodeReply:dataDict];
        // 编码消息entities
        [self encodeEntities:dataDict];
        
        // 编码阅后即焚
        if(self.flame) {
            dataDict[@"flame"] = @(1);
            dataDict[@"flame_second"] = @(self.flameSecond);
        }
        
        // 编码robotID
        if(self.robotID && ![self.robotID isEqualToString:@""]) {
            dataDict[@"robot_id"] = self.robotID;
        }
        
        // 编码正文数据
        NSDictionary *messageDict = [self encodeWithJSON];
        if(messageDict) {
            [dataDict addEntriesFromDictionary:messageDict];
        }
        NSDictionary *encodeDataDict = dataDict;
        self.contentDict = encodeDataDict;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:encodeDataDict options:kNilOptions error:nil];
        
        NSData *contentData = jsonData;
        
        
        return contentData;
    } @catch (NSException *exception) {
         NSLog(@"编码失败！->%@",exception);
    }
    return nil;
}

- (NSDictionary *)encodeWithJSON {
   
    
    return nil;
}

- (void)decode:(NSData *)data db:(FMDatabase*)db {
    self.db = db;
    [self decode:data];
}

- (void)decode:(NSData *)data {
    @try {
        __autoreleasing NSError *error = nil;
      
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if(error) {
            NSLog(@"%@ 解码失败！-> %@",[self class],error);
            return;
        }
        if(!dictionary) {
             NSLog(@"warn:负载数据为空不进行解码操作，将消息丢掉！。。");
            return;
        }
            
        if(dictionary[@"visibles"]) {
            self.visibles = dictionary[@"visibles"];
        }
        
        // 解码用户信息
        [self decodeSenderUserInfo:dictionary];
        // 解码@数据
        NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:dictionary];
        [self decodeMentionInfo:newDict];
        dictionary = newDict;
        // 解码回复
        [self decodeReply:dictionary];
        // 解码entities
        [self decodeEntities:dictionary];
        
        // 解码阅后即焚
        if(dictionary[@"flame"]) {
            self.flame = [dictionary[@"flame"] boolValue];
            if(dictionary[@"flame_second"]) {
                self.flameSecond = [dictionary[@"flame_second"] intValue];
            }
        }
        
        // 解码机器人ID
        self.robotID = dictionary[@"robot_id"]?:@"";
        
        // 解码消息数据
        [self decodeWithJSON:dictionary];
        
        self.contentDict = [NSDictionary dictionaryWithDictionary:dictionary];
    } @catch (NSException *exception) {
        NSLog(@"解码失败！->%@",exception);
    }
   
}

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    
}

- (void)decodeSenderUserInfo:(NSDictionary *)dict {
    if(dict[@"from_uid"]) {
         self.senderUserInfo = [[WKUserInfo alloc] initWithUid:dict[@"from_uid"] name:dict[@"from_name"] avatar:@""];
    }
    
}

// 编码用户信息
- (void) encodeSenderUserInfo:(NSMutableDictionary *)dict {
    if(self.senderUserInfo) {
        if(self.senderUserInfo.name && ![self.senderUserInfo.name isEqualToString:@""]) {
            [dict setObject:self.senderUserInfo.name?:@"" forKey:@"from_name"];
        }
        
       // [dict setObject:self.senderUserInfo.uid?:@"" forKey:@"from_uid"];
    }
}

// 解码@数据
-(void) decodeMentionInfo:(NSMutableDictionary*)dict {
    NSDictionary *mentionDict = dict[@"mention"];
    if(mentionDict && [mentionDict isKindOfClass:[NSDictionary class]]) {
        WKMentionedType type = WK_Mentioned_Users;
        if(mentionDict[@"all"] && [mentionDict[@"all"] integerValue]==1) {
            type = WK_Mentioned_All;
        }
        NSArray<NSString*> *uids;
        if([mentionDict[@"uids"] isKindOfClass:[NSArray class]]) {
             uids =mentionDict[@"uids"];
        }
         self.mentionedInfo = [[WKMentionedInfo alloc] initWithMentionedType:type uids:uids];
    }
}

-(NSString*) replaceSpecial:(NSString*)data{
    data = [data stringByReplacingOccurrencesOfString:@"@" withString:@""];
    data = [data stringByReplacingOccurrencesOfString:@"{" withString:@""];
    data = [data stringByReplacingOccurrencesOfString:@"}" withString:@""];
    data = [data stringByReplacingOccurrencesOfString:@" " withString:@""];
    return data;
}

- (NSArray*)matcheInString:(NSString*)string regularExpressionWithPattern:(NSString*)regularExpressionWithPattern
{
    NSError* error;
    NSRange range = NSMakeRange(0, [string length]);
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:regularExpressionWithPattern options:NSRegularExpressionCaseInsensitive error:&error];
    NSArray* matches = [regex matchesInString:string options:0 range:range];
    return matches;
}

// 解码session信息 mos协议如果是系统消息session信息会在payload里，所以这里需要在payload解析出来放入extra字段内
-(void) decodeSessionInfoIfNeed:(NSDictionary*)dict  {
    if(dict[@"session_id"] && dict[@"session_type"]) {
        self.extra[@"session_id"] = dict[@"session_id"];
        self.extra[@"session_type"] = dict[@"session_type"];
    }
}

// 编码@信息
-(void) encodeMentionInfo:(NSMutableDictionary*) dict {
    if(self.mentionedInfo) {
        NSMutableDictionary *mentionDic = [NSMutableDictionary dictionary];
        mentionDic[@"all"] = self.mentionedInfo.type == WK_Mentioned_All?@(1):@(0);
        if(self.mentionedInfo.uids && self.mentionedInfo.uids.count>0) {
            mentionDic[@"uids"] = self.mentionedInfo.uids;
        }
        dict[@"mention"] = mentionDic;
    }
}

-(void) decodeReply:(NSDictionary*)dict {
    NSDictionary *replyDict = dict[@"reply"];
    if(replyDict) {
        WKReply *reply = [WKReply new];
        reply.messageID = replyDict[@"message_id"];
        reply.messageSeq = [replyDict[@"message_seq"] unsignedIntValue];
        reply.fromUID = replyDict[@"from_uid"];
        reply.fromName = replyDict[@"from_name"];
        if(!reply.fromName||[reply.fromName isEqualToString:@""]) {
            WKChannel *fromChannel = [WKChannel personWithChannelID:reply.fromUID];
            WKChannelInfo *fromChannelInfo;
            if(self.db) {
                fromChannelInfo = [[WKSDK shared].channelManager getCache:fromChannel];
                if(!fromChannelInfo) {
                    fromChannelInfo = [[WKChannelInfoDB shared] queryChannelInfo:fromChannel db:self.db];
                }
                
            }else{
                fromChannelInfo = [[WKSDK shared].channelManager getChannelInfo:fromChannel];
            }
            if(fromChannelInfo) {
                reply.fromName = fromChannelInfo.displayName;
            }
        }
        if(replyDict[@"payload"]) {
           NSInteger contentType = [replyDict[@"payload"][@"type"] integerValue];
           reply.content =  [[WKSDK shared].chatManager getMessageContent:contentType];
            
            NSData *contentData = [NSJSONSerialization dataWithJSONObject:replyDict[@"payload"] options:kNilOptions error:nil];
            [reply.content decode:contentData db:self.db];
        }
        self.reply = reply;
        
    }
}
// 编码回复
-(void) encodeReply:(NSMutableDictionary*)dict {
    if(self.reply) {
        NSMutableDictionary *replyDic = [NSMutableDictionary dictionary];
        if(self.reply.rootMessageID) {
            replyDic[@"root_mid"] = self.reply.rootMessageID;
        }
        replyDic[@"message_id"] = self.reply.messageID?:@"";
        replyDic[@"message_seq"] = @(self.reply.messageSeq);
        replyDic[@"from_uid"] = self.reply.fromUID?:@"";
        replyDic[@"from_name"] = self.reply.fromName?:@"";
        if(self.reply.content) {
            replyDic[@"payload"] = [self.reply.content contentDict]?:@{};
        }
        dict[@"reply"] = replyDic;
    }
}

-(void) decodeEntities:(NSDictionary*)dict {
    NSArray<NSDictionary*> *entitiesDicts = dict[@"entities"];
    if(entitiesDicts && dict[@"entities"] != [NSNull null] && entitiesDicts.count>0) {
        NSMutableArray<WKMessageEntity*> *entities = [NSMutableArray array];
        for (NSDictionary *entitiesDict in entitiesDicts) {
            [entities addObject:[self toEntity:entitiesDict]];
        }
        self.entities = entities;
    }
}

-(WKMessageEntity*) toEntity:(NSDictionary*)entityDict {
    NSInteger length = entityDict[@"length"]?[entityDict[@"length"] integerValue]:0;
    NSInteger offset = entityDict[@"offset"]?[entityDict[@"offset"] integerValue]:0;
    NSString *type = entityDict[@"type"]?:@"";
    id value = entityDict[@"value"];
    
    return [WKMessageEntity type:type range:NSMakeRange(offset, length) value:value];
}

// 编码 entities
-(void) encodeEntities:(NSMutableDictionary*)dict {
    if(self.entities && self.entities.count>0) {
        NSMutableArray *entitiesDicts = [NSMutableArray array];
        for (WKMessageEntity *entity in self.entities) {
            NSMutableDictionary *entitiesDict = [NSMutableDictionary dictionaryWithDictionary:@{
                @"length": @(entity.range.length),
                @"offset": @(entity.range.location),
                @"type": entity.type?:@"",
            }];
            if(entity.value) {
                entitiesDict[@"value"] = entity.value;
            }
            [entitiesDicts addObject:entitiesDict];
        }
        dict[@"entities"] = entitiesDicts;
    }
}

- (NSInteger)realContentType {
    NSNumber *contentType = [[self class] contentType];
    if(contentType && contentType.integerValue != 0) {
        return contentType.integerValue;
    }
    if(self.contentDict && self.contentDict[@"type"] && [self.contentDict[@"type"] integerValue]!=0) {
        return [self.contentDict[@"type"] integerValue];
    }
    
    return [[self class] contentType].integerValue;
}

+(NSNumber*) contentType {
    return @(0);
}

- (NSString *)conversationDigest {
    return @"";
}

- (NSString *)searchableWord {
    return @"";
}

- (NSMutableDictionary *)extra {
    if(!_extra) {
        _extra = [[NSMutableDictionary alloc] init];
    }
    return _extra;
}

- (NSArray<WKMessageEntity *> *)entities {
    if(!_entities) {
        _entities = [NSArray array];
    }
    return _entities;
}


- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKMessageContent *messageContent = [[[self class] allocWithZone:zone] init];
    
    NSData *data = [self encode];
    
    [messageContent decode:data];
    
    return messageContent;
}


-(BOOL) viewedOfVisible {
    return true;
}

@end
