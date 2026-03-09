//
//  WKMessage.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"
#import "WKMessageContent.h"
#import "WKChannelInfo.h"
#import "WKConst.h"
#import "WKChannelMemberDB.h"
#import "WKTaskProto.h"
#import "WKSetting.h"
#import "WKMessageExtra.h"
#import "WKReaction.h"
#import "WKStream.h"
#import "WKRecvPacket.h"

NS_ASSUME_NONNULL_BEGIN
@interface WKMessageHeader : NSObject
// 是否红点
// 是否显示未读
@property(nonatomic,assign) BOOL showUnread; // RedDot

// 是否不存储
@property(nonatomic,assign) BOOL noPersist;

@property(nonatomic,assign) BOOL syncOnce; // 同步一次标记

@end

@interface WKMessage : NSObject

@property(nonatomic,strong) WKMessageHeader *header; // 消息头

@property(nonatomic,strong) WKSetting *setting; // 消息设置

@property(nonatomic,assign) uint32_t clientSeq; // 客户端序列号 (客户端提供，服务端原样返回)

@property(nonatomic,copy) NSString *clientMsgNo; /// 客户端消息唯一编号(相同clientMsgNo被认为是重复消息)

@property(nonatomic,copy) NSString *streamNo; // 流式编号

@property(nonatomic,assign) WKStreamFlag streamFlag; // 流式标记

@property(nonatomic,assign) uint64_t streamSeq; // 流式序号

@property(nonatomic,assign) uint64_t messageId; // 消息ID（全局唯一）

@property(nonatomic,assign)  uint32_t messageSeq; // 消息序列号（用户唯一，有序）

@property(nonatomic,assign) uint32_t orderSeq; // 消息排序号（消息越新序号越大）

@property(nonatomic,assign) NSInteger timestamp; // 消息时间（服务器时间,单位秒）

@property(nonatomic,assign) NSInteger localTimestamp; // 本地消息创建时间

@property(nonatomic,strong) WKChannelInfo *from; // 发送者

@property(nonatomic,copy) NSString *topic; // 消息话题

@property(nonatomic,copy) NSString *fromUid; // 发送者uid
@property(nonatomic,copy) NSString *toUid; // 接收者uid

@property(nonatomic,strong,readonly) WKChannelMember *memberOfFrom; // 发送者在频道里的成员信息

@property(nonatomic,strong) WKChannel *channel; // 频道

@property(nonatomic,strong) WKChannel *parentChannel; // 父类频道

@property(nullable,nonatomic,strong,readonly) WKChannelInfo *channelInfo; //  频道资料，可能为空，如果为空可以调用WKChannelManager fetchChannelInfo:completion 触发频道信息变更委托
@property(nonatomic,assign) NSInteger contentType; // 正文类型
@property(nonatomic,strong) WKMessageContent *content; // 消息正文
@property(nonatomic,strong) NSData *contentData; // 消息正文data数据
@property(nonatomic,assign) BOOL voiceReaded; // 语音是否已读 （对语音消息有效）
@property(nonatomic,assign) WKMessageStatus status; // 消息状态
@property(nonatomic,assign) WKReason reasonCode; // 原因代码,当status为WK_MESSAGE_FAIL时 应该有相应的原因代号
@property(nonatomic,weak,readonly) id<WKTaskProto> task; // 消息关联的任务（例如：下载图片任务，上传图片任务等等）

- (BOOL)isSend; // 是否是发送消息

@property(nonatomic,strong) NSMutableDictionary *extra; // 消息本地扩展数据
@property(nonatomic,strong,nullable) NSArray<WKReaction*> *reactions; // 消息回应集合
@property(nonatomic,assign) BOOL isDeleted; // 消息是否被删除

// ---------- 消息远程扩展 ----------
@property(nonatomic,assign) BOOL hasRemoteExtra; // 是否有远程消息扩展（sdk内部用于插入消息扩展表的判断）

@property(nonatomic,assign) BOOL viewed; //  是否已查看 0.未查看 1.已查看 （这个字段跟已读的区别在于是真正的查看了消息内容，比如图片消息 已读是列表滑动到图片消息位置就算已读，viewed是表示点开图片才算已查看，语音消息类似）

@property(nonatomic,assign) NSInteger viewedAt; // 查看时间戳

@property(nonatomic,strong) WKMessageExtra *remoteExtra; // 消息远程扩展

@property(nonatomic,assign) BOOL  syncStreamsFromDB; // 是否从db同步流数据
@property(nonatomic,strong) NSMutableArray<WKStream*> *streams; // 流式消息内容
@property(nonatomic,assign) BOOL streamOn; // 是否开启了stream

@property(nonatomic,assign) NSInteger expire; // 过期时长（单位为秒）

@property(nonatomic,strong) NSDate *expireAt; // 过期时间

@end


NS_ASSUME_NONNULL_END
