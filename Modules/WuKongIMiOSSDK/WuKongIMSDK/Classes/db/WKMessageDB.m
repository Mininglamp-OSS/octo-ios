//
//  WKMessageDB.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/29.
//

#import "WKMessageDB.h"
#import "WKDB.h"
#import "WKSDK.h"
#import "WKMOSContentConvertManager.h"
#import "WKMessageExtraDB.h"
#import "WKReactionDB.h"
#import "WKUnknownContent.h"
// 保存消息
#define SQL_MESSAGE_SAVE [NSString stringWithFormat:@"insert into %@(message_id,message_seq,order_seq,client_msg_no,stream_no,timestamp,from_uid,to_uid,channel_id,channel_type,content_type,content,searchable_word,voice_readed,status,reason_code,extra,setting,flame,flame_second,viewed,viewed_at,expire,expire_at,is_deleted) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",TB_MESSAGE]

// 保存或更新消息
//#define SQL_MESSAGE_REPLACE [NSString stringWithFormat:@"insert into %@(message_id,message_seq,order_seq,client_msg_no,timestamp,from_uid,to_uid,channel_id,channel_type,content_type,content,searchable_word,voice_readed,status,extra,revoke,is_deleted) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(client_msg_no) DO UPDATE SET voice_readed=excluded.voice_readed,status=excluded.status",TB_MESSAGE]

// 更新撤回状态
#define SQL_MESSAGE_UPDATE_REVOKE_CLIENTMSGNO [NSString stringWithFormat:@"update %@ set revoke=? where client_msg_no=?",TB_MESSAGE]

// 更新消息的回执数据
#define SQL_MESSAGE_UPDATE_WITHACK [NSString stringWithFormat:@"update %@ set message_id=?,message_seq=?,order_seq=?,status=?,reason_code=? where id=?",TB_MESSAGE]
#define SQL_MESSAGE_UPDATE_WITHACK2 [NSString stringWithFormat:@"update %@ set message_id=?,message_seq=?,status=? where id=?",TB_MESSAGE]
// 通过客户端消息编号更新状态
#define SQL_MESSAGE_UPDATE_WITHACK_CLIENTMSGNO [NSString stringWithFormat:@"update %@ set message_id=?,message_seq=?,status=?,reason_code=? where client_msg_no=?",TB_MESSAGE]
// 消息是否存在
#define SQL_MESSAGE_EXIST [NSString stringWithFormat:@"select count(*) cn from %@ where message_id=?",TB_MESSAGE]
// 查询消息
//#define SQL_MESSAGE_QUERY_OLDESTID [NSString stringWithFormat:@"select *  from %@  where  channel_id=? and channel_type=? and is_deleted=0 and content_type<>0 and content_type<>99 and order_seq < ?   order by order_seq desc limit 0,?",TB_MESSAGE]

// 扩展表的字段
#define SQL_EXTRA_COLS [NSString stringWithFormat:@"%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@",@"IFNULL(message_extra.readed,0) readed",@"IFNULL(message_extra.readed_at,0) readed_at",@"IFNULL(message_extra.readed_count,0) readed_count",@"IFNULL(message_extra.unread_count,0) unread_count",@"IFNULL(message_extra.revoke,'') revoke",@"IFNULL(message_extra.revoker,0) revoker",@"IFNULL(message_extra.is_pinned,0) is_pinned",@"IFNULL(message_extra.content_edit,'') content_edit",@"IFNULL(message_extra.edited_at,0) edited_at",@"IFNULL(message_extra.upload_status,0) upload_status",@"IFNULL(message_extra.extra_version,0) extra_version"]

#define SQL_MESSAGE_QUERY_OLDESTID_DESC(symbol,symbol2) [NSString stringWithFormat:@"select message.*,%@  from %@ left join message_extra on message.message_id=message_extra.message_id  where  message.channel_id=? and message.channel_type=? and message.is_deleted=0  and message.content_type<>99 and message.order_seq %@ ? %@  order by message.order_seq desc,message.timestamp desc limit 0,?",SQL_EXTRA_COLS,TB_MESSAGE,symbol,symbol2?[NSString stringWithFormat:@" and message.order_seq %@ ?",symbol2]:@""]

#define SQL_MESSAGE_QUERY_OLDESTID_ASC(symbol,symbol2) [NSString stringWithFormat:@"select message.*,%@  from %@ left join message_extra on message.message_id=message_extra.message_id  where  message.channel_id=? and message.channel_type=? and message.is_deleted=0  and message.content_type<>99 and message.order_seq %@ ? %@  order by message.order_seq asc,message.timestamp asc limit 0,?",SQL_EXTRA_COLS,TB_MESSAGE,symbol,symbol2?[NSString stringWithFormat:@" and order_seq %@ ?",symbol2]:@""]
//#define SQL_MESSAGE_QUERY_OLDESTID_ASC_AND_CONTAIN [NSString stringWithFormat:@"select *  from %@  where  channel_id=? and channel_type=? and is_deleted=0 and content_type<>0 and content_type<>99 and order_seq >= ?  order by order_seq asc  limit 0,?",TB_MESSAGE]

#define SQL_MESSAGE_QUERY(symbol) [NSString stringWithFormat:@"select message.*,%@  from %@ left join message_extra on message.message_id=message_extra.message_id  where message.channel_id=? and message.channel_type=? and message.is_deleted=0  and message.content_type<>99 order by message.order_seq %@,message.timestamp %@ limit 0,?",SQL_EXTRA_COLS,TB_MESSAGE,symbol,symbol]

// 通过关键字搜索频道内的消息
#define SQL_MESSAGE_WITH_CHANNEL_AND_KEYWORD [NSString stringWithFormat:@"select message.*  from %@ where message.channel_id=? and message.channel_type=? and message.is_deleted=0  and message.content_type<>99 and message.searchable_word like ? order by message.order_seq desc,message.timestamp desc limit ?",TB_MESSAGE]

// 将等待发送中的消息修改为错误状态
#define SQL_MESSAGE_UPDATE_SENDING_TO_ERROR [NSString stringWithFormat:@"update %@ set status=? where status=? or status=?",TB_MESSAGE]
// 通过状态更新状态
#define SQL_MESSAGE_UPDATE_STATUS_WITH_STATUS [NSString stringWithFormat:@"update %@ set status=? where status=?",TB_MESSAGE]
// 更新消
#define SQL_MESSAGE_UPDATE_MESSAGE [NSString stringWithFormat:@"update %@ set content=?,status=?,extra=? where id=?",TB_MESSAGE]

// 更新消息状态
#define SQL_MESSAGE_UPDATE_STATUS [NSString stringWithFormat:@"update %@ set status=? where id=?",TB_MESSAGE]

// 更新最大的seq
#define SQL_MESSAGE_UPDATE_MAX_SEQ_WITH_MESSAGEID_OR_CLIENTMSGNO [NSString stringWithFormat:@"update %@ set message_seq=?,order_seq=? where (message_id<>0 and message_id=?) or (client_msg_no<>'' and client_msg_no=?)",TB_MESSAGE]

#define SQL_MESSAGE_MAX_MESSAGESEQ_WITH_CHANNEL [NSString stringWithFormat:@"select max(message_seq) message_seq from %@ where channel_id=? and channel_type=?  and content_type<>99  and is_deleted=0 ",TB_MESSAGE]
// 消息查询
#define SQL_MESSAGE_WITH_ID [NSString stringWithFormat:@"select * from %@ where id=?",TB_MESSAGE]
#define SQL_MESSAGE_WITH_IDS [NSString stringWithFormat:@"select * from %@ where id in ",TB_MESSAGE]

// 通过消息序列号查询消息
#define SQL_MESSAGE_WITH_MESSAGE_SEQ [NSString stringWithFormat:@"select * from %@ where channel_id=? and channel_type=? and  message_seq=?",TB_MESSAGE]

// 消息查询通过客户端消息编号
#define SQL_MESSAGE_WITH_CLIENTMSGNO [NSString stringWithFormat:@"select message.*,%@ from %@ left join message_extra on message.message_id=message_extra.message_id where client_msg_no=?",SQL_EXTRA_COLS,TB_MESSAGE]
#define SQL_MESSAGE_WITH_CLIENTMSGNOS [NSString stringWithFormat:@"select message.*,%@ from %@ left join message_extra on message.message_id=message_extra.message_id where client_msg_no in ",SQL_EXTRA_COLS,TB_MESSAGE]

// 通过消息ID获取消息
#define SQL_MESSAGE_WITH_MESSAGEIDS [NSString stringWithFormat:@"select message.*,%@ from %@ left join message_extra on message.message_id=message_extra.message_id where message.message_id in ",SQL_EXTRA_COLS,TB_MESSAGE]
// 修改语音已读状态
#define SQL_MESSAGE_UPDATE_VOICE_READED  [NSString stringWithFormat:@"update %@ set voice_readed=? where id=?",TB_MESSAGE]
// 修改消息已读状态
#define SQL_MESSAGE_UPDATE_READED  [NSString stringWithFormat:@"update %@ set readed=? where id=?",TB_MESSAGE]

#define SQL_MESSAGE_UPDATE_READED_WITH_IDS  [NSString stringWithFormat:@"update %@ set readed=? where id in ",TB_MESSAGE]
// 修改消息扩展字段
#define SQL_MESSAGE_UPDATE_EXTRA  [NSString stringWithFormat:@"update %@ set extra=? where id=?",TB_MESSAGE]
// 删除指定id的消息
#define SQL_MESSAGE_DELETE_MESSAGE_ID [NSString stringWithFormat:@"update %@ set is_deleted=1 where message_id=?",TB_MESSAGE]

#define SQL_MESSAGE_DELETE_MESSAGE_IDS [NSString stringWithFormat:@"update %@ set is_deleted=1 where message_id in ",TB_MESSAGE]

// 删除指定id的消息
#define SQL_MESSAGE_DELETE_CLIENT_SEQ [NSString stringWithFormat:@"update %@ set is_deleted=1 where id=?",TB_MESSAGE]

#define SQL_MESSAGE_DELETE_CLIENT_SEQS [NSString stringWithFormat:@"update %@ set is_deleted=1 where id in ",TB_MESSAGE]

// 彻底删除消息
#define SQL_MESSAGE_DESTORY_ID [NSString stringWithFormat:@"delete from %@ where id=?",TB_MESSAGE]

// 删除指定频道内的所有消息
#define SQL_MESSAGE_DELETE_CHANNEL [NSString stringWithFormat:@"update %@ set is_deleted=1 where channel_id=? and channel_type=?",TB_MESSAGE]
// 删除所有消息
#define SQL_MESSAGE_DELETE_ALL [NSString stringWithFormat:@"delete from  %@",TB_MESSAGE]
#define SQL_MESSAGE_DELETE_MAXMESSAGESEQ [NSString stringWithFormat:@"update  %@ set is_deleted=1 where channel_id=? and channel_type=? and message_seq<?",TB_MESSAGE]

#define SQL_MESSAGE_DELETE_MAXMESSAGESEQ_CONTAIN [NSString stringWithFormat:@"update  %@ set is_deleted=1 where channel_id=? and channel_type=? and message_seq<=?",TB_MESSAGE]
// 获取频道的最后一条消息
#define SQL_MESSAGE_LASTMESSAGE_WITH_CHANNEL [NSString stringWithFormat:@"select message.*,%@ from  %@ left join message_extra on message.message_id=message_extra.message_id where message.channel_id=? and message.channel_type=? and message.is_deleted=0 and message.content_type<>99 order by  message.order_seq  desc limit 1",SQL_EXTRA_COLS,TB_MESSAGE]
// 根据消息ID获取消息
#define SQL_MESSAGE_WITH_MESSAGEID [NSString stringWithFormat:@"select message.*,%@ from %@ left join message_extra on message.message_id=message_extra.message_id where message.message_id=?",SQL_EXTRA_COLS,TB_MESSAGE]

// 根据消息ID获取消息
#define SQL_MESSAGE_WITH_MESSAGEIDOrClientMsgNo [NSString stringWithFormat:@"select message.*,%@ from %@ left join message_extra on message.message_id=message_extra.message_id where (message.message_id<>0 and message.message_id=?) or (message.client_msg_no<>'' and message.client_msg_no=?)",SQL_EXTRA_COLS,TB_MESSAGE]
// 查询指定消息的状态
#define SQL_MESSAGES_WITH_STATUS [NSString stringWithFormat:@"select message.*,%@ from %@  left join message_extra on message.message_id=message_extra.message_id  where message.status=? and message.is_deleted=0 order by order_seq asc",SQL_EXTRA_COLS,TB_MESSAGE]

// 获取频道最大排序号
#define SQL_MESSAGE_MAX_ORDERSEQ [NSString stringWithFormat:@"select max(order_seq) order_seq from %@ where channel_id=? and channel_type=? and content_type<>99",TB_MESSAGE]

// 通过消息序列号查询消息
#define SQL_MESSAGE_WITH_ORDER_SEQ [NSString stringWithFormat:@"select message.*,%@ from %@ left join message_extra on message.message_id=message_extra.message_id where message.channel_id=? and message.channel_type=? and  message.order_seq=?",SQL_EXTRA_COLS,TB_MESSAGE]

// 查询某个频道内的某个发送者的消息
#define SQL_MESSAGE_WITH_FROM_AND_CHANNEL [NSString stringWithFormat:@"select message.*,%@ from %@ left join message_extra on message.message_id=message_extra.message_id where message.channel_id=? and message.channel_type=? and  message.from_uid=? and message.is_deleted=0",SQL_EXTRA_COLS,TB_MESSAGE]

// 获取指定偏移量的第一条消息
#define SQL_MESSAGE_WITH_OFFSET [NSString stringWithFormat:@"select message.*,%@ from %@ left join message_extra on message.message_id=message_extra.message_id where message.channel_id=? and message.channel_type=? and message.is_deleted=0 order by message.order_seq desc limit ?,1",SQL_EXTRA_COLS,TB_MESSAGE]

// 获取小于指定orderSeq 有messageSeq的第一条消息
#define SQL_MESSAGE_WITH_LESS_THAN_ORDER_SEQ [NSString stringWithFormat:@"select message.*,%@ from %@ left join message_extra on message.message_id=message_extra.message_id where message.channel_id=? and message.channel_type=? and message.order_seq<? and message.message_seq<>0 order by message.message_seq asc limit 1",SQL_EXTRA_COLS,TB_MESSAGE]

// 获取大于指定orderSeq 有messageSeq的第一条消息
#define SQL_MESSAGE_WITH_MORE_THAN_ORDER_SEQ [NSString stringWithFormat:@"select message.*,%@ from %@ left join message_extra on message.message_id=message_extra.message_id where message.channel_id=? and message.channel_type=? and  message.order_seq>? and message.message_seq<>0 order by message.message_seq desc limit 1",SQL_EXTRA_COLS,TB_MESSAGE]

// 查询message_seq区间内被删除的消息
#define SQL_DELETED_MESSAGE_WITH_MESSAGE_SEQ [NSString stringWithFormat:@"select * from %@ where channel_id=? and channel_type=? and is_deleted = 1 and message_seq<>0 and  message_seq>? and message_seq<? order by message_seq asc",TB_MESSAGE]

#define SQL_DELETED_MESSAGE_SEQ_WITH_MESSAGE_SEQ [NSString stringWithFormat:@"select message_seq from %@ where channel_id=? and channel_type=? and is_deleted = 1 and message_seq<>0 and  message_seq>? and message_seq<? order by message_seq asc",TB_MESSAGE]

#define SQL_DELETED_MESSAGE_SEQ_WITH_MESSAGE_SEQ_LESS [NSString stringWithFormat:@"select message_seq from %@ where channel_id=? and channel_type=? and is_deleted = 1 and message_seq<>0 and  message_seq<?  order by message_seq desc limit 0,?",TB_MESSAGE]

#define SQL_DELETED_MESSAGE_SEQ_WITH_MESSAGE_SEQ_MORE [NSString stringWithFormat:@"select message_seq from %@ where channel_id=? and channel_type=? and is_deleted = 1 and message_seq<>0 and  message_seq>?  order by message_seq asc limit 0,?",TB_MESSAGE]

//查询排序在指定message之前的消息数量
#define SQL_MESSAGE_ORDER_COUNT_WITH_MORE_THAN_ORDER_SEQ [NSString stringWithFormat:@"select count(*) cn from %@ where channel_id=? and channel_type=? and  content_type<>99 and order_seq>? and is_deleted=0 order by order_seq desc",TB_MESSAGE]

// 获取指定频道的最大扩展版本号
#define SQL_MESSAGE_EXTRA_MAX_VERSION [NSString stringWithFormat:@"select max(extra_version) max_version from %@ where channel_id=? and channel_type=?",TB_MESSAGE]

// 更新消息扩展部分的数据
#define SQL_MESSAGE_EXTRA_UPDATE [NSString stringWithFormat:@"update %@ set extra_version=?,revoke=?,revoker=?,readed_count=?,unread_count=?,readed=?,voice_readed=?,is_deleted=? where message_id=?",TB_MESSAGE]
// 更新消息扩展部分的数据（不更新is_deleted）
#define SQL_MESSAGE_EXTRA_UPDATE_NO_DELETED [NSString stringWithFormat:@"update %@ set extra_version=?,revoke=?,revoker=?,readed_count=?,unread_count=?,readed=?,voice_readed=? where message_id=?",TB_MESSAGE]

// 获取消息表最大序号
#define SQL_MESSAGE_MAX_ID [NSString stringWithFormat:@"select seq from %@ where name='%@'",@"sqlite_sequence",TB_MESSAGE]

// 获取指定消息的周围第一条消息SEQ
#define SQL_AROUND_MESSAGE_SEQ [NSString stringWithFormat:@"select * from (select message_seq from %@ where channel_id=? and channel_type=? and is_deleted=0 and message_seq<? order by message_seq desc limit 5) tb order by message_seq asc limit 1  ",TB_MESSAGE]

// 消息修改为已查看
#define SQL_MESSAGE_VIEWED_UPDATE [NSString stringWithFormat:@"update %@ set viewed=1,viewed_at=? where message_id in ",TB_MESSAGE]

// 查询需要delete的消息
#define SQL_MESSAGE_VIEWED_NEED_DELETE [NSString stringWithFormat:@"select client_msg_no from %@ where viewed=1 and is_deleted=0 and flame=1 and flame_second<=?-viewed_at",TB_MESSAGE]

// 查询所有消息
#define SQL_ALL_MESSAGE [NSString stringWithFormat:@"select * from %@ where  content_type<>99 and message_seq>? and is_deleted=0 order by message_seq desc",TB_MESSAGE]

// 保存流
#define SQL_STREAM_SAVE_OR_UPDATE [NSString stringWithFormat:@"insert into %@(channel_id,channel_type,client_msg_no,stream_no,stream_seq,content) values(?,?,?,?,?,?) ON CONFLICT(channel_id,channel_type,stream_no,stream_seq) DO UPDATE SET content=excluded.content",TB_STREAM]
// 查询流
#define SQL_STREAM_WITH_STREAM_NO [NSString stringWithFormat:@"select * from %@ where stream_no=? order by stream_seq asc",TB_STREAM]

// 查询过期消息
#define SQL_EXPIRE_MESSAGES [NSString stringWithFormat:@"select message.*,%@ from %@ left join message_extra on message.message_id=message_extra.message_id where message.is_deleted=0 and message.expire_at<>0 and message.expire_at <= ? order by order_seq asc limit 0,?",SQL_EXTRA_COLS,TB_MESSAGE]



@implementation WKMessageDB

static WKMessageDB *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKMessageDB *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(NSArray<WKMessage*>*) saveMessages:(NSArray<WKMessage*>*)messages {
    __block NSMutableArray<WKMessage*> *newMessages = [NSMutableArray array];
    @synchronized(self) {
        [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
            for(WKMessage *message in messages) {
                WKMessage *existMessage = [self getMessageWithMessageIdOrClientMsgNo:message.messageId clientMsgNo:message.clientMsgNo db:db];
                if(existMessage) {
                    if(existMessage.messageSeq==message.messageSeq) {
                        if([WKSDK shared].isDebug) {
                            NSLog(@"消息已存在 -> %llu messageSeq: %u",message.messageId,message.messageSeq);
                        }
                    }else {
                        [self insertMessage:message db:db clientMsgNo:[NSString stringWithFormat:@"%@-%u",message.clientMsgNo,message.messageSeq] isDeleted:1];
                        message.isDeleted = 1;
                    }
                    continue;
                }
                
                [newMessages addObject:message];
                NSString *searchableWord = @"";
                if(message.content && message.content.searchableWord) {
                    searchableWord =message.content.searchableWord;
                }
                if(message.remoteExtra.contentEdit && message.remoteExtra.contentEdit.searchableWord) { // 如果有编辑的内容 则以编辑的内容搜索关键字为准
                    searchableWord =message.remoteExtra.contentEdit.searchableWord;
                }
                uint32_t orderSeq = 0;
                if(message.messageSeq!=0) {
                    orderSeq = message.messageSeq*WKOrderSeqFactor;
                }else{
                    orderSeq = [self getMaxOrderSeqWithChannel:db channel:message.channel]+1;
                }
                NSInteger expireAt = 0;
                if(message.expireAt) {
                    expireAt = [message.expireAt timeIntervalSince1970];
                }
                bool success =  [db executeUpdate:SQL_MESSAGE_SAVE,@(message.messageId),@(message.messageSeq),@(orderSeq),message.clientMsgNo?:@"",message.streamNo?:@"",@(message.timestamp),message.fromUid?:@"",message.toUid?:@"",message.channel.channelId?:@"",@(message.channel.channelType),@(message.contentType),message.contentData?:@"",searchableWord?:@"",@(message.voiceReaded),@(message.status),@(message.reasonCode),[self extraToStr:message.extra],@([message.setting toUint8]),@(message.content.flame),@(message.content.flameSecond),@(message.viewed),@(message.viewedAt),@(message.expire),@(expireAt),@(message.isDeleted)];
                
                if(success) {
                    message.clientSeq = (uint32_t)db.lastInsertRowId;
                    message.orderSeq = orderSeq;
                }
                if(message.hasRemoteExtra) { // 添加扩展消息
                    [[WKMessageExtraDB shared] addOrUpdateMessageExtra:message.remoteExtra db:db];
                }
                if(message.reactions && message.reactions.count>0) {
                    [[WKReactionDB shared] insertOrUpdateReactions:message.reactions db:db];
                }
                if(message.streams && message.streams.count>0) {
                    [self saveOrUpdateStreams:message.streams db:db];
                }
                
            }
        }];
    }
    
    return newMessages;
}

-(NSArray<WKMessage*>*) replaceMessages:(NSArray<WKMessage*>*)messages {
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (WKMessage *message in messages) {
            NSString *searchableWord = @"";
            if(message.content && message.content.searchableWord) {
                searchableWord =message.content.searchableWord;
            }
            uint32_t orderSeq = 0;
            if(message.messageSeq!=0) {
                orderSeq = message.messageSeq*WKOrderSeqFactor;
            }
            bool success = [self insertMessage:message db:db clientMsgNo:message.clientMsgNo isDeleted:message.isDeleted];
            if(success) {
                message.clientSeq = (uint32_t)db.lastInsertRowId;
            }else{
                WKMessage *dupMessage = [self getMessageWithClientMsgNo:message.clientMsgNo db:db]; // 查询重复的clientMsgNo消息
                if(dupMessage && dupMessage.messageSeq!=message.messageSeq) {
                    NSLog(@"messageSeq:%u clientMsgNo: %@",message.messageSeq,message.clientMsgNo);
                    // 这里说明插入失败就认为是clientMsgNo冲突,修改clientMsgNo然后将消息设置为已删除状态，这样主要是为了不让messageSeq出现间断
                    [self insertMessage:message db:db clientMsgNo:[NSString stringWithFormat:@"%@-%u",message.clientMsgNo,message.messageSeq] isDeleted:1];
                    message.isDeleted = 1;
                }
                
            }
            if(message.hasRemoteExtra) { // 添加扩展消息
                [[WKMessageExtraDB shared] addOrUpdateMessageExtra:message.remoteExtra db:db];
            }
            if(message.reactions && message.reactions.count>0) {
                [[WKReactionDB shared] insertOrUpdateReactions:message.reactions db:db];
            }
            if(message.streams && message.streams.count>0) {
                [self saveOrUpdateStreams:message.streams db:db];
            }
        }
    }];
    return messages;
}



-(BOOL) insertMessage:(WKMessage*)message db:(FMDatabase*)db clientMsgNo:(NSString*)clientMsgNo isDeleted:(NSInteger)isDeleted{
    NSString *searchableWord = @"";
    if(message.content && message.content.searchableWord) {
        searchableWord =message.content.searchableWord;
    }
    if(message.remoteExtra.contentEdit && message.remoteExtra.contentEdit.searchableWord) { // 如果有编辑的内容 则以编辑的内容搜索关键字为准
        searchableWord =message.remoteExtra.contentEdit.searchableWord;
    }
    uint32_t orderSeq = 0;
    if(message.messageSeq!=0) {
        orderSeq = message.messageSeq*WKOrderSeqFactor;
    }
    NSInteger expireAt = 0;
    if(message.expireAt) {
        expireAt = [message.expireAt timeIntervalSince1970];
    }
    return  [db executeUpdate:SQL_MESSAGE_SAVE,@(message.messageId),@(message.messageSeq),@(orderSeq),clientMsgNo,message.streamNo?:@"",@(message.timestamp),message.fromUid?:@"",message.toUid?:@"",message.channel.channelId?:@"",@(message.channel.channelType),@(message.contentType),message.contentData?:@"",searchableWord?:@"",@(message.voiceReaded),@(message.status),@(message.reasonCode),[self extraToStr:message.extra],@([message.setting toUint8]),@(message.content.flame),@(message.content.flameSecond),@(message.viewed),@(message.viewedAt),@(message.expire),@(expireAt),@(isDeleted)];
}

-(BOOL) existMessage:(uint64_t)messageId db:(FMDatabase*)db{
    FMResultSet *result = [db executeQuery:SQL_MESSAGE_EXIST,@(messageId)];
    __block BOOL isExit=false;
    if(result.next){
        NSDictionary *resultDic = result.resultDictionary;
        isExit = [resultDic[@"cn"] integerValue]>0?YES:NO;
    }
    [result close];
    return isExit;
}
-(NSArray<WKMessage*>*) getMessages:(WKChannel*)channel startOrderSeq:(uint32_t)startOrderSeq endOrderSeq:(uint32_t)endOrderSeq  limit:(int) limit pullMode:(WKPullMode)pullMode {
    __block NSMutableArray *messages = [NSMutableArray new];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result;
        if(startOrderSeq==0 && endOrderSeq == 0) {
            result = [db executeQuery:SQL_MESSAGE_QUERY(@"desc"),channel.channelId?:@"",@(channel.channelType),@(limit)];
        }else {
            NSString *symbol1;
            NSString *symbol2;
            if(pullMode == WKPullModeDown) {
                if(startOrderSeq>0 && endOrderSeq == 0) {
                    symbol1 = @"<";
                }else {
                    symbol1 = @"<";
                    symbol2 = @">";
                }
                
                if(!symbol2) {
                    result = [db executeQuery:SQL_MESSAGE_QUERY_OLDESTID_DESC(symbol1,nil),channel.channelId?:@"",@(channel.channelType),@(startOrderSeq),@(limit)];
                }else{
                    result = [db executeQuery:SQL_MESSAGE_QUERY_OLDESTID_DESC(symbol1,symbol2),channel.channelId?:@"",@(channel.channelType),@(startOrderSeq),@(endOrderSeq),@(limit)];
                }
                
            }else {
                if(startOrderSeq>0 && endOrderSeq == 0) {
                    symbol1 = @">";
                }else {
                    symbol1 = @">";
                    symbol2 = @"<";
                }
                
                if(!symbol2) {
                    result = [db executeQuery:SQL_MESSAGE_QUERY_OLDESTID_ASC(symbol1,nil),channel.channelId?:@"",@(channel.channelType),@(startOrderSeq),@(limit)];
                }else {
                    result = [db executeQuery:SQL_MESSAGE_QUERY_OLDESTID_ASC(symbol1,symbol2),channel.channelId?:@"",@(channel.channelType),@(startOrderSeq),@(endOrderSeq),@(limit)];
                }
                
                
            }
        }
        while (result.next) {
            NSDictionary *resultDic = result.resultDictionary;
            [messages addObject:[self toMessage:resultDic db:db]];
        }
        [result close];
    }];
    return messages;
}

//-(NSArray<WKMessage*>*) getMessages:(WKChannel*)channel oldestOrderSeq:(uint32_t)oldestOrderSeq   limit:(int) limit{
//    return [self getMessages:channel oldestOrderSeq:oldestOrderSeq contain:false limit:limit reverse:false];
//}

-(NSArray<WKMessage*>*) getMessages:(WKChannel*)channel keyword:(NSString*)keyword limit:(int) limit {
    __block NSMutableArray *messages = [NSMutableArray new];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result = [db executeQuery:SQL_MESSAGE_WITH_CHANNEL_AND_KEYWORD,channel.channelId,@(channel.channelType),[NSString stringWithFormat:@"%%%@%%",keyword?:@""],@(limit)];
        while (result.next) {
            NSDictionary *resultDic = result.resultDictionary;
            [messages addObject:[self toMessage:resultDic db:db]];
        }
        [result close];
    }];
    return messages;
}

-(NSArray<WKMessage*>*) getMessages:(uint32_t)messageSeq limit:(int)limit {
    __block NSMutableArray *messages = [NSMutableArray new];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result = [db executeQuery:SQL_ALL_MESSAGE,@(messageSeq),@(limit)];
        while (result.next) {
            NSDictionary *resultDic = result.resultDictionary;
            [messages addObject:[self toMessage:resultDic db:db]];
        }
        [result close];
    }];
    return messages;
}

-(NSArray<WKMessage*>*) getDeletedMessagesWithChannel:(WKChannel*)channel minMessageSeq:(uint32_t)minMessageSeq maxMessageSeq:(uint32_t)maxMessageSeq {
    __block NSMutableArray *messages = [NSMutableArray new];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result =[db executeQuery:SQL_DELETED_MESSAGE_WITH_MESSAGE_SEQ,channel.channelId?:@"",@(channel.channelType),@(minMessageSeq),@(maxMessageSeq)];
        while (result.next) {
            NSDictionary *resultDic = result.resultDictionary;
            [messages addObject:[self toMessage:resultDic db:db]];
        }
        [result close];
    }];
    return messages;
}

-(NSArray<NSNumber*>*) getDeletedMessageSeqWithChannel:(WKChannel*)channel  minMessageSeq:(uint32_t)minMessageSeq maxMessageSeq:(uint32_t)maxMessageSeq{
    
    __block NSMutableArray<NSNumber*> *messageSeqs = [NSMutableArray new];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result =[db executeQuery:SQL_DELETED_MESSAGE_SEQ_WITH_MESSAGE_SEQ,channel.channelId?:@"",@(channel.channelType),@(minMessageSeq),@(maxMessageSeq)];
        while (result.next) {
            [messageSeqs addObject:@([result unsignedLongLongIntForColumn:@"message_seq"])];
        }
        [result close];
    }];
    return messageSeqs;
}

-(NSArray<NSNumber*>*) getDeletedLessThanMessageSeqWithChannel:(WKChannel*)channel  messageSeq:(uint32_t)messageSeq limit:(int)limit {
    __block NSMutableArray<NSNumber*> *messageSeqs = [NSMutableArray new];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result =[db executeQuery:SQL_DELETED_MESSAGE_SEQ_WITH_MESSAGE_SEQ_LESS,channel.channelId?:@"",@(channel.channelType),@(messageSeq),@(limit)];
        while (result.next) {
            [messageSeqs addObject:@([result unsignedLongLongIntForColumn:@"message_seq"])];
        }
        [result close];
    }];
    return messageSeqs;
}

- (NSArray<NSNumber *> *)getDeletedMoreThanMessageSeqWithChannel:(WKChannel *)channel messageSeq:(uint32_t)messageSeq limit:(int)limit {
    __block NSMutableArray<NSNumber*> *messageSeqs = [NSMutableArray new];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result =[db executeQuery:SQL_DELETED_MESSAGE_SEQ_WITH_MESSAGE_SEQ_MORE,channel.channelId?:@"",@(channel.channelType),@(messageSeq),@(limit)];
        while (result.next) {
            [messageSeqs addObject:@([result unsignedLongLongIntForColumn:@"message_seq"])];
        }
        [result close];
    }];
    return messageSeqs;
}

-(NSArray<WKMessage*>*) getMessagesWithClientSeqs:(NSArray<NSNumber*>*)clientSeqs {
    if(!clientSeqs || clientSeqs.count<=0) {
        return nil;
    }
    __block NSMutableArray *messages = [NSMutableArray new];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result;
        if(clientSeqs.count==1) {
            result = [db executeQuery:SQL_MESSAGE_WITH_ID,clientSeqs[0]];
        }else {
            NSString *ids = [clientSeqs componentsJoinedByString:@","];
            result=  [db executeQuery:[NSString stringWithFormat:@"%@ (%@)",SQL_MESSAGE_WITH_IDS,ids]];
        }
        while (result.next) {
            NSDictionary *resultDic = result.resultDictionary;
            [messages addObject:[self toMessage:resultDic db:db]];
        }
        [result close];
    }];
    return messages;
}
-(NSArray<WKMessage*>*) getMessagesWithClientMsgNos:(NSArray*)clientMsgNos {
    if(!clientMsgNos || clientMsgNos.count<=0) {
        return nil;
    }
    __block NSArray<WKMessage*> *messages = [NSArray new];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        messages = [self getMessagesWithClientMsgNos:clientMsgNos db:db];
    }];
    return messages;
}

-(NSArray<WKMessage*>*) getMessagesWithClientMsgNos:(NSArray*)clientMsgNos db:(FMDatabase*)db{
    if(!clientMsgNos || clientMsgNos.count<=0) {
        return nil;
    }
    __block NSMutableArray *messages = [NSMutableArray new];
    FMResultSet *result;
    if(clientMsgNos.count==1) {
        result = [db executeQuery:SQL_MESSAGE_WITH_CLIENTMSGNO,clientMsgNos[0]];
    }else {
        NSMutableArray *newClientMsgNos = [NSMutableArray array];
        for (NSString *clientMsgNo in clientMsgNos) {
            [newClientMsgNos addObject:[NSString stringWithFormat:@"\"%@\"",clientMsgNo]];
        }
        NSString *ids = [newClientMsgNos componentsJoinedByString:@","];
        result=  [db executeQuery:[NSString stringWithFormat:@"%@ (%@)",SQL_MESSAGE_WITH_CLIENTMSGNOS,ids]];
    }
    while (result.next) {
        NSDictionary *resultDic = result.resultDictionary;
        [messages addObject:[self toMessage:resultDic db:db]];
    }
    [result close];
    return messages;
}

-(NSArray<WKMessage*>*) getMessagesWithMessageIDs:(NSArray<NSNumber*>*)messageIDs {
    
    __block NSMutableArray *messages = [NSMutableArray new];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result;
        NSString *ids = [messageIDs componentsJoinedByString:@","];
        result=  [db executeQuery:[NSString stringWithFormat:@"%@ (%@)",SQL_MESSAGE_WITH_MESSAGEIDS,ids]];
        while (result.next) {
            NSDictionary *resultDic = result.resultDictionary;
            [messages addObject:[self toMessage:resultDic db:db]];
        }
        [result close];
    }];
    return messages;
}

-(WKMessage*) getMessageWithClientMsgNo:(NSString*)clientMsgNo {
    __block WKMessage *message;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result = [db executeQuery:SQL_MESSAGE_WITH_CLIENTMSGNO,clientMsgNo];
        if(result.next) {
            message = [self toMessage:result.resultDictionary db:db];
        }
        [result close];
    }];
    return message;
}

-(long long) getMessageMaxID {
    __block long long maxID = 0;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result = [db executeQuery:SQL_MESSAGE_MAX_ID];
        if(result.next) {
            maxID = [result longLongIntForColumnIndex:0];
        }
        [result close];
    }];
    return maxID;
}

-(WKMessage*) getMessageWithClientMsgNo:(NSString*)clientMsgNo db:(FMDatabase*)db{
    __block WKMessage *message;
    FMResultSet *result = [db executeQuery:SQL_MESSAGE_WITH_CLIENTMSGNO,clientMsgNo];
    if(result.next) {
        message = [self toMessage:result.resultDictionary db:db];
    }
    [result close];
    return message;
}

-(uint32_t) getChannelAroundFirstMessageSeq:(WKChannel*)channel messageSeq:(uint32_t)messageSeq {
    __block unsigned long long aroundSeq=0;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_AROUND_MESSAGE_SEQ,channel.channelId?:@"",@(channel.channelType),@(messageSeq)];
        if(resultSet.next) {
            aroundSeq = [resultSet unsignedLongLongIntForColumnIndex:0];
        }
        [resultSet close];
    }];
    return (uint32_t)aroundSeq;
}

-(WKMessage*) getMessage:(WKChannel*)channel messageSeq:(uint32_t)messageSeq {
    __block WKMessage *message;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_WITH_MESSAGE_SEQ,channel.channelId?:@"",@(channel.channelType),@(messageSeq)];
        if(resultSet.next) {
            message = [self toMessage:resultSet.resultDictionary db:db];
        }
        [resultSet close];
    }];
    return message;
}

-(WKMessage*) getMessage:(WKChannel*)channel orderSeq:(uint32_t)orderSeq {
    __block WKMessage *message;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_WITH_ORDER_SEQ,channel.channelId?:@"",@(channel.channelType),@(orderSeq)];
        if(resultSet.next) {
            message = [self toMessage:resultSet.resultDictionary db:db];
        }
        [resultSet close];
    }];
    return message;
}




-(WKMessage*) getMessage:(WKChannel*)channel lessThanAndFirstMessageSeq:(uint32_t)orderSeq {
    __block WKMessage *message;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_WITH_LESS_THAN_ORDER_SEQ,channel.channelId?:@"",@(channel.channelType),@(orderSeq)];
        if(resultSet.next) {
            message = [self toMessage:resultSet.resultDictionary db:db];
        }
        [resultSet close];
    }];
    return message;
}

-(WKMessage*) getMessage:(WKChannel*)channel moreThanAndFirstMessageSeq:(uint32_t)orderSeq {
    __block WKMessage *message;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_WITH_MORE_THAN_ORDER_SEQ,channel.channelId?:@"",@(channel.channelType),@(orderSeq)];
        if(resultSet.next) {
            message = [self toMessage:resultSet.resultDictionary db:db];
        }
        [resultSet close];
    }];
    return message;
}


-(WKMessage*) getMessage:(uint32_t)clientSeq {
    __block WKMessage *message;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_WITH_ID,@(clientSeq)];
        if(resultSet.next) {
            message = [self toMessage:resultSet.resultDictionary db:db];
        }
        [resultSet close];
    }];
    return message;
}
-(WKMessage*) getMessage:(uint32_t)clientSeq db:(FMDatabase*)db{
    __block WKMessage *message;
    FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_WITH_ID,@(clientSeq)];
    if(resultSet.next) {
        message = [self toMessage:resultSet.resultDictionary db:db];
    }
    [resultSet close];
    return message;
}

-(WKMessage*) getMessageWithMessageId:(uint64_t)messageId {
    __block WKMessage *message;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_WITH_MESSAGEID,@(messageId)];
        if(resultSet.next) {
            message = [self toMessage:resultSet.resultDictionary db:db];
        }
        [resultSet close];
    }];
    return message;
}

-(WKMessage*) getMessageWithMessageId:(uint64_t)messageId db:(FMDatabase*)db {
    WKMessage *message;
    FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_WITH_MESSAGEID,@(messageId)];
    if(resultSet.next) {
        message = [self toMessage:resultSet.resultDictionary db:db];
    }
    [resultSet close];
    return message;
}

-(WKMessage*) getMessageWithMessageIdOrClientMsgNo:(uint64_t)messageId clientMsgNo:(NSString*)clientMsgNo db:(FMDatabase*)db {
    
    WKMessage *message;
    FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_WITH_MESSAGEIDOrClientMsgNo,@(messageId),clientMsgNo?:@""];
    if(resultSet.next) {
        message = [self toMessage:resultSet.resultDictionary db:db];
    }
    [resultSet close];
    return message;
}

-(void) updateMessageContent:(NSData*)content status:(WKMessageStatus)status extra:(NSDictionary*)extra clientSeq:(uint32_t)clientSeq {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_MESSAGE_UPDATE_MESSAGE,content?:@"",@(status),[self extraToStr:extra],@(clientSeq)];
    }];
}

-(void) updateMessageMaxSeqWithMessageIDOrClientMsgNo:(uint32_t)messageSeq messageID:(uint64_t)messageID clientMsgNo:(NSString*)clientMsgNo db:(FMDatabase*)db{
    [db executeUpdate:SQL_MESSAGE_UPDATE_MAX_SEQ_WITH_MESSAGEID_OR_CLIENTMSGNO,@(messageSeq),@(messageSeq*WKOrderSeqFactor),@(messageID),clientMsgNo?:@""];
}

-(void) updateMessageWithSendackPackets:(NSArray<WKSendackPacket*> *)sendackPackets {
    if(!sendackPackets || sendackPackets.count<=0) {
        return;
    }
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        for (WKSendackPacket *sendackPacket in sendackPackets) {
            if(sendackPacket.header.noPersist) { // 不存储的忽略掉
                continue;
            }
            int status = WK_MESSAGE_SUCCESS;
            if(sendackPacket.reasonCode !=WK_MESSAGE_SUCCESS) {
                status = WK_MESSAGE_FAIL;
            }
            uint32_t orderSeq = 0;
            if(sendackPacket.messageSeq!=0) {
                orderSeq = sendackPacket.messageSeq*WKOrderSeqFactor;
            }else {
                WKMessage *message=  [self getMessage:sendackPacket.clientSeq db:db];
                if(message) {
                    orderSeq = [self getMaxOrderSeqWithChannel:db channel:message.channel]+1;
                }
                
            }
            [db executeUpdate:SQL_MESSAGE_UPDATE_WITHACK,@(sendackPacket.messageId),@(sendackPacket.messageSeq),@(orderSeq),@(status),@(sendackPacket.reasonCode),@(sendackPacket.clientSeq)];
            
        }
        
    }];
}

-(void) updateMessageVoiceReaded:(BOOL)voiceReaded clientSeq:(uint32_t)clientSeq {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_MESSAGE_UPDATE_VOICE_READED,@(voiceReaded?1:0),@(clientSeq)];
    }];
}


-(void) updateMessageExtra:(NSDictionary*) extra clientSeq:(uint32_t)clientSeq {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_MESSAGE_UPDATE_EXTRA,[self extraToStr:extra],@(clientSeq)];
    }];
}



-(uint32_t) getMaxMessageSeq:(WKChannel*)channel {
    __block uint32_t maxMessageSeq;
    __weak typeof(self) weakSelf = self;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        maxMessageSeq = [weakSelf getMaxMessageSeqWithChannel:db channel:channel];
    }];
    return maxMessageSeq;
}


-(uint32_t) getMaxMessageSeqWithChannel:(FMDatabase*)db channel:(WKChannel*)channel {
    uint32_t maxMessageSeq = 0;
    FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_MAX_MESSAGESEQ_WITH_CHANNEL,channel.channelId?:@"",@(channel.channelType)];
    if(resultSet.next) {
        maxMessageSeq =  (uint32_t)[resultSet unsignedLongLongIntForColumn:@"message_seq"];
    }
    [resultSet close];
    return maxMessageSeq;
}

-(uint32_t) getMaxOrderSeqWithChannel:(FMDatabase*) db channel:(WKChannel*)channel {
    uint32_t maxOrderSeq = 0;
    FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_MAX_ORDERSEQ,channel.channelId?:@"",@(channel.channelType)];
    if(resultSet.next) {
        maxOrderSeq =  (uint32_t)[resultSet unsignedLongLongIntForColumn:@"order_seq"];
    }
    [resultSet close];
    return maxOrderSeq;
}

- (void)deleteMessage:(WKMessage *)message {
    
    uint32_t clientSeq = message.clientSeq;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_MESSAGE_DELETE_CLIENT_SEQ,@(clientSeq)];
    }];
}

-(void) deleteMessagesWithClientSeqs:(NSArray<NSNumber*>*)ids {
    [WKDB.sharedDB.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSString *idStrs = [ids componentsJoinedByString:@","];
        [db executeUpdate:[NSString stringWithFormat:@"%@ (%@)",SQL_MESSAGE_DELETE_CLIENT_SEQS,idStrs]];
    }];
}

-(void) deleteMessagesWithMessageIDs:(NSArray<NSNumber*>*)messageIDs {
    __weak typeof(self) weakSelf = self;
    [WKDB.sharedDB.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [weakSelf deleteMessagesWithMessageIDs:messageIDs db:db];
    }];
}

-(void) deleteMessagesWithMessageIDs:(NSArray<NSNumber*>*)messageIDs db:(FMDatabase*)db {
    if(messageIDs && messageIDs.count==0) {
        return;
    }
    if(messageIDs.count == 1) {
        NSNumber *messageID = messageIDs[0];
        [db executeUpdate:SQL_MESSAGE_DELETE_MESSAGE_ID,messageID];
    }else {
        NSString *idStrs = [messageIDs componentsJoinedByString:@","];
        [db executeUpdate:[NSString stringWithFormat:@"%@ (%@)",SQL_MESSAGE_DELETE_MESSAGE_IDS,idStrs]];
    }
    
}

- (void)destoryMessage:(WKMessage *)message {
    
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_MESSAGE_DESTORY_ID,@(message.clientSeq)];
    }];
}

-(NSArray<WKMessage*>*) getMessages:(NSString*)fromUID channel:(WKChannel*)channel {
    __block NSMutableArray *messages = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_WITH_FROM_AND_CHANNEL,channel.channelId,@(channel.channelType),fromUID];
        while (resultSet.next) {
            [messages addObject:[self toMessage:resultSet.resultDictionary db:db]];
        }
        [resultSet close];
    }];
    return messages;
}

- (void)deleteMessage:(WKMessage *)message db:(FMDatabase*)db{
    if(!message || message.messageId <=0) {
        return;
    }
    [db executeUpdate:SQL_MESSAGE_DELETE_MESSAGE_ID,@(message.messageId)];
}

-(void) clearMessages:(WKChannel *)channel {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_MESSAGE_DELETE_CHANNEL,channel.channelId?:@"",@(channel.channelType)];
    }];
}

-(void) clearAllMessages {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_MESSAGE_DELETE_ALL];
    }];
}

- (void) clearFromMsgSeq:(WKChannel*)channel maxMsgSeq:(uint32_t)maxMsgSeq isContain:(BOOL)isContain {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSString *sql = isContain?SQL_MESSAGE_DELETE_MAXMESSAGESEQ_CONTAIN:SQL_MESSAGE_DELETE_MAXMESSAGESEQ;
        
        [db executeUpdate:sql,channel.channelId?:@"",@(channel.channelType),@(maxMsgSeq)];
    }];
}

-(WKMessage*) getLastMessage:(WKChannel*)channel {
    __block WKMessage *message;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_LASTMESSAGE_WITH_CHANNEL,channel.channelId?:@"",@(channel.channelType)];
        if(resultSet.next) {
            NSDictionary *resultDic = resultSet.resultDictionary;
            message = [self toMessage:resultDic db:db];
        }
        [resultSet close];
    }];
    return message;
}
-(WKMessage*) getLastMessage:(WKChannel*)channel offset:(NSInteger)offset {
    __block WKMessage *message;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_WITH_OFFSET,channel.channelId?:@"",@(channel.channelType),@(offset)];
        if(resultSet.next) {
            message = [self toMessage:resultSet.resultDictionary db:db];
        }
        [resultSet close];
    }];
    return message;
    
}

-(void) updateMessageUploadingToFailStatus{
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_MESSAGE_UPDATE_STATUS_WITH_STATUS,@(WK_MESSAGE_FAIL),@(WK_MESSAGE_UPLOADING)];
    }];
}

-(NSArray<WKMessage*>*) getMessagesWaitSend; {
    __block NSMutableArray *messages = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MESSAGES_WITH_STATUS,@(WK_MESSAGE_WAITSEND)];
        while(resultSet.next) {
            NSDictionary *resultDic = resultSet.resultDictionary;
            [messages addObject:[self toMessage:resultDic db:db]];
        }
        [resultSet close];
    }];
    return messages;
}

-(NSArray<WKMessage*>*) getExpireMessages:(NSInteger)limit {
    __block NSMutableArray *messages = [NSMutableArray array];
    [WKDB.sharedDB.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSTimeInterval nowInterval = [[NSDate date] timeIntervalSince1970];
        FMResultSet *resultSet = [db executeQuery:SQL_EXPIRE_MESSAGES,@(nowInterval),@(limit)];
        while(resultSet.next) {
            NSDictionary *resultDic = resultSet.resultDictionary;
            [messages addObject:[self toMessage:resultDic db:db]];
        }
        [resultSet close];
    }];
    return messages;
}


-(void) updateMessageStatus:(WKMessageStatus)status withClientSeq:(uint32_t)clientSeq {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_MESSAGE_UPDATE_STATUS,@(status),@(clientSeq)];
    }];
}


-(void) updateMessageRevoke:(BOOL)revoke clientMsgNo:(NSString*)clientMsgNo {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_MESSAGE_UPDATE_REVOKE_CLIENTMSGNO,@(revoke?1:0),clientMsgNo?:@""];
    }];
}

-(NSArray<WKMessage*>*) updateViewed:(NSArray<WKMessage*>*)messages {
    if(!messages||messages.count == 0) {
        return messages;
    }
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSMutableArray<NSNumber*> *messageIDs = [NSMutableArray array];
        NSInteger time = [[NSDate date] timeIntervalSince1970];
        for (WKMessage *message in messages) {
            [messageIDs addObject:@(message.messageId)];
            message.viewed = 1;
            message.viewedAt = time;
        }
        NSString *ids = [messageIDs componentsJoinedByString:@","];
        [db executeUpdate:[NSString stringWithFormat:@"%@ (%@)",SQL_MESSAGE_VIEWED_UPDATE,ids],@(time)];
    }];
    return messages;
}

// 获取需要焚烧的消息
-(NSArray<WKMessage*>*) getMessagesOfNeedFlame {
    __block NSArray<WKMessage*> *messages = [NSArray new];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSMutableArray<NSString*> *clientMsgNos = [NSMutableArray array];
        FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_VIEWED_NEED_DELETE,@([[NSDate date] timeIntervalSince1970])];
        while (resultSet.next) {
            [clientMsgNos addObject: [resultSet stringForColumn:@"client_msg_no"]];
        }
        [resultSet close];
        if(clientMsgNos && clientMsgNos.count>0) {
            messages = [self getMessagesWithClientMsgNos:clientMsgNos db:db];
        }
    }];
    return messages;
    
}

-(NSInteger) getOrderCountMoreThanMessage:(WKMessage*)message {
    __block NSInteger count;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_ORDER_COUNT_WITH_MORE_THAN_ORDER_SEQ,message.channel.channelId?:@"",@(message.channel.channelType),@(message.orderSeq)];
        if(resultSet.next) {
            count = [resultSet intForColumn:@"cn"];
        }
        [resultSet close];
    }];
    return count;
}

-(NSString*) extraToStr:(NSDictionary*)extra {
    NSString *extraStr = @"";
    if(extra) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:extra options:kNilOptions error:nil];
        extraStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return extraStr;
}

-(long long) getMessageExtraMaxVersion:(WKChannel*)channel {
    __block long long maxVersion;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_EXTRA_MAX_VERSION,channel.channelId?:@"",@(channel.channelType)];
        if(resultSet.next) {
            maxVersion = [resultSet intForColumn:@"max_version"];
        }
        [resultSet close];
    }];
    return maxVersion;
}


-(void) saveOrUpdateStreams:(NSArray<WKStream*>*)streams {
    if(!streams || streams.count == 0) {
        return;
    }
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        
        [self saveOrUpdateStreams:streams db:db];
    }];
}

-(void) saveOrUpdateStreams:(NSArray<WKStream*>*)streams db:(FMDatabase*)db{
    for (NSInteger i=0; i<streams.count; i++) {
        WKStream *stream = streams[i];
        [db executeUpdate:SQL_STREAM_SAVE_OR_UPDATE,stream.channel.channelId?:@"",@(stream.channel.channelType),stream.clientMsgNo?:@"",stream.streamNo?:@"",@(stream.streamSeq),stream.contentData?:@""];
    }
}

-(NSArray<WKStream*>*) getStreams:(NSString*)streamNo {
    if(!streamNo || [streamNo isEqualToString:@""]) {
        return nil;
    }
    NSMutableArray<WKStream*> *streams = [NSMutableArray array];
    [WKDB.sharedDB.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_STREAM_WITH_STREAM_NO,streamNo];
        while (resultSet.next) {
            [streams addObject:[self toStream:resultSet db:db]];
        }
        [resultSet close];
    }];
    return  streams;
}

-(WKStream*) toStream:(FMResultSet*)resultSet db:(FMDatabase*)db {
    WKStream *stream = [WKStream new];
    NSString *channelID = [resultSet stringForColumn:@"channel_id"];
    int channelType = [resultSet intForColumn:@"channel_type"];
    stream.channel = [WKChannel channelID:channelID channelType:channelType];
    NSData *data =  [resultSet dataForColumn:@"content"];
    stream.contentData = data;
    if(data) {
        __autoreleasing NSError *error = nil;
        NSDictionary *contentDictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        NSInteger contentType = 0;
        if(contentDictionary && contentDictionary[@"type"]) {
             contentType = [contentDictionary[@"type"] integerValue];
        }
        stream.content = [self decodeContent:contentType data:data db:db];
    }
    return stream;
}


-(WKMessage*) toMessage:(NSDictionary*)dict db:(FMDatabase*)db{
    WKMessage *message = [WKMessage new];
    message.clientSeq = [dict[@"id"] unsignedIntValue];
    message.clientMsgNo = dict[@"client_msg_no"];
    message.streamNo = dict[@"stream_no"];
    message.messageId = [dict[@"message_id"] unsignedLongLongValue];
    message.messageSeq = [dict[@"message_seq"] unsignedIntValue];
    message.orderSeq = [dict[@"order_seq"] unsignedIntValue];
    message.timestamp = [dict[@"timestamp"] integerValue];
    message.localTimestamp = [[self dateFromString:dict[@"created_at"]] timeIntervalSince1970];
    message.fromUid = dict[@"from_uid"];
    message.toUid = dict[@"to_uid"];
    if(dict[@"expire"]) {
        message.expire = [dict[@"expire"] integerValue];
    }
    if(dict[@"expire_at"]) {
       NSInteger expireAt = [dict[@"expire_at"] integerValue];
       message.expireAt = [NSDate dateWithTimeIntervalSince1970:expireAt];
    }
    message.channel = [[WKChannel alloc] initWith:dict[@"channel_id"] channelType:[dict[@"channel_type"] integerValue]];
    if(dict[@"parent_channel_id"] && ![dict[@"parent_channel_id"] isEqualToString:@""]) {
        message.parentChannel = [[WKChannel alloc] initWith:dict[@"parent_channel_id"] channelType:[dict[@"parent_channel_type"] integerValue]];
    }
    
    NSInteger contentType = [dict[@"content_type"] integerValue];
    message.contentType = contentType;
    if(dict[@"content"] && [dict[@"content"] isKindOfClass:[NSData class]]) {
        message.content = [self decodeContent:contentType data:dict[@"content"] db:db];
        message.contentData = dict[@"content"];
    }else {
        message.content = [[WKUnknownContent alloc] init];
        message.contentData = [[NSData alloc] init];
    }
    
    if(dict[@"flame"]) {
        message.content.flame = [dict[@"flame"] boolValue];
    }
    if(dict[@"flame_second"]) {
        message.content.flameSecond = [dict[@"flame_second"] integerValue];
    }
    if(dict[@"viewed"]) {
        message.viewed = [dict[@"viewed"] boolValue];
    }
    if(dict[@"viewed_at"]) {
        message.viewedAt = [dict[@"viewed_at"] integerValue];
    }
    
    message.isDeleted = [dict[@"is_deleted"] boolValue];
    
    
    message.hasRemoteExtra = true; // 这个目前好像没啥用，一直是true就可以
    message.remoteExtra.messageID = message.messageId;
    message.remoteExtra.messageSeq = message.messageSeq;
    message.remoteExtra.channelID = message.channel.channelId;
    message.remoteExtra.channelType = message.channel.channelType;
    if(dict[@"readed"]) {
        message.remoteExtra.readed = [dict[@"readed"] integerValue]>0;
    }
    NSInteger readedAt =  [dict[@"readed_at"] integerValue];
    if(readedAt>0) {
        message.remoteExtra.readedAt = [NSDate dateWithTimeIntervalSince1970:readedAt];
    }
    if(dict[@"revoke"]) {
        message.remoteExtra.revoke = [dict[@"revoke"] boolValue];
    }
    if(dict[@"revoker"]) {
        message.remoteExtra.revoker = dict[@"revoker"];
    }
    
    if(dict[@"is_pinned"]) {
        message.remoteExtra.isPinned = [dict[@"is_pinned"] boolValue];
    }
    
    if(dict[@"readed_count"]) {
        message.remoteExtra.readedCount = [dict[@"readed_count"] integerValue];
    }
    if(dict[@"unread_count"]) {
        message.remoteExtra.unreadCount = [dict[@"unread_count"] integerValue];
    }
    if(dict[@"extra_version"]) {
        message.remoteExtra.extraVersion = [dict[@"extra_version"] integerValue];
    }
    
    if(dict[@"voice_readed"]) {
        message.voiceReaded = [dict[@"voice_readed"] integerValue]>0;
    }
 
    if(dict[@"setting"]) {
        message.setting = [WKSetting fromUint8:[dict[@"setting"] integerValue]];
    }
    
    if(dict[@"edited_at"]) {
        message.remoteExtra.editedAt = [dict[@"edited_at"] integerValue];
    }
    
    if(dict[@"content_edit"] && [dict[@"content_edit"] length]>0) {
        message.remoteExtra.contentEditData = dict[@"content_edit"];
        message.remoteExtra.contentEdit = [self decodeContent:contentType data:dict[@"content_edit"] db:db];
    }
    if(dict[@"upload_status"]) {
        message.remoteExtra.uploadStatus = [dict[@"upload_status"] integerValue];
    }
    
    message.status = [dict[@"status"] integerValue];
    message.reasonCode = [dict[@"reason_code"] integerValue];
    NSString *extraStr = dict[@"extra"];
    __autoreleasing NSError *error = nil;
    NSDictionary *extraDictionary = [NSJSONSerialization JSONObjectWithData:[extraStr dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
    if(!error) {
        message.extra = [NSMutableDictionary dictionaryWithDictionary:extraDictionary];
    }
    return message;
}
- (NSDate *)dateFromString:(NSString *)str {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"Asia/Shanghai"]];
    NSDate *date = [formatter dateFromString:str];
    return date;
}



-(WKMessageContent*) decodeContent:(NSInteger)contentType data:(NSData *)contentData db:(FMDatabase*)db{
//    if([WKSDK shared].options.mosConvertOn) {
//        contentType = [[WKMOSContentConvertManager shared] convertTypeToLM:contentType];
//    }
     Class contentCls = [[WKSDK shared] getMessageContent:contentType];
    WKMessageContent *messageContent = [contentCls new];
    [messageContent decode:contentData db:db];
    return messageContent;
}

@end
