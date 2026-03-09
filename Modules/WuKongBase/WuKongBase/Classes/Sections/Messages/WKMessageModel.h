//
//  WKMessageVM.h
//  WuKongBase
//
//  Created by tt on 2019/12/28.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
@class RadialStatusNode;
NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    WKVoicePlayStatusUnknown,
    WKVoicePlayStatusNoPlay, // 没有播放
    WKVoicePlayStatusPlaying, // 播放中
    WKVoicePlayStatusPause, // 暂停
} WKVoicePlayStatus;

@interface WKMessageModel : NSObject

-(instancetype) initWithMessage:(WKMessage*)message;

// 上一条消息
@property(nonatomic,weak) WKMessageModel *preMessageModel;
// 下一条消息
@property(nonatomic,weak) WKMessageModel *nextMessageModel;

@property(nonatomic,strong) WKMessage *message;

@property(nonatomic,strong) WKSetting *setting;

// 客户端序列号 (客户端提供，服务端原样返回)
@property(nonatomic,assign,readonly) uint32_t clientSeq;
/// 客户端消息唯一编号(相同clientMsgNo被认为是重复消息)
@property(nonatomic,copy) NSString *clientMsgNo;
// 消息ID（全局唯一）
@property(nonatomic,assign,readonly) uint64_t messageId;
// 消息序列号（用户唯一，有序）
@property(nonatomic,assign,readonly)  uint32_t messageSeq;
// 消息排序号（消息越新序号越大）
@property(nonatomic,assign,readonly)  uint32_t orderSeq;
// 消息时间（服务器时间）
@property(nonatomic,assign,readonly) NSInteger timestamp;

@property(nonatomic,copy) NSString *dateStr; // 日期字符串 格式 yyyy-MM-dd

@property(nonatomic,copy) NSString *timeStr; // 时间字符串 例如：下午 08:11

@property(nonatomic,copy) NSString *editedAtStr; // 编辑时间 例如：下午 08:11

// 本地消息创建时间
@property(nonatomic,assign) NSInteger localTimestamp;
// 发送者uid
@property(nonatomic,copy,readonly) NSString *fromUid;
// 发送者在频道的成员信息
@property(nonatomic,strong,readonly) WKChannelMember *memberOfFrom;
// 发送者数据
@property(nonatomic,strong,nullable) WKChannelInfo *from;
// 接收者uid
@property(nonatomic,copy,readonly) NSString *toUid;
// 频道
@property(nonatomic,strong,readonly) WKChannel *channel;
@property(nullable,nonatomic,strong,readonly) WKChannelInfo *channelInfo;
// 正文类型
@property(nonatomic,assign,readonly) NSInteger contentType;
// 消息正文
@property(nonatomic,strong,readonly) WKMessageContent *content;
// 是否是发送消息
@property(nonatomic,assign,readonly) BOOL isSend;

// 消息是否已读
@property(nonatomic,assign) BOOL readed;
@property(nonatomic,strong,readonly) NSDate *readedAt; // 消息已读时间

// 是否开启checkbox
@property(nonatomic,assign) BOOL checkboxOn;
// 是否被选中
@property(nonatomic,assign) BOOL checked;

/// 是否被撤回
@property(nonatomic,assign,readonly) BOOL revoke;

@property(nonatomic,strong,readonly) WKMessageExtra *remoteExtra;



/// 是否需要提醒动画
@property(nonatomic,assign) BOOL reminderAnimation;
// 提醒动画执行次数
@property(nonatomic,assign) NSInteger reminderAnimationCount;

// 消息状态
@property(nonatomic,assign) WKMessageStatus status;
@property(nonatomic,assign,readonly) WKReason reasonCode;
@property(nonatomic,strong) NSMutableAttributedString *reason; // 原因内容

@property(nonatomic,weak,readonly) id<WKTaskProto> task;
// 本地扩展数据
@property(nonatomic,strong,readonly) NSDictionary *extra;


// ---------- 音频消息相关 ----------
// 播放状态
@property(nonatomic,assign) WKVoicePlayStatus voicePlayStatus;
// 语音播放进度 0-1.0之间
@property(nonatomic,assign) CGFloat voicePlayProgress;
// 语音是否已读
@property(nonatomic,assign) BOOL voiceReaded;
// 语音当前已读秒数
@property(nonatomic,assign) NSInteger voiceCurrentSecond;

// 是否是个人频道
@property(nonatomic,assign,readonly) BOOL isPersonChannel;

// 所有回应
@property(nonatomic,strong,readonly) NSArray<WKReaction*> *reactions;

// 回应最多的三个emoji
@property(nonatomic,strong,readonly) NSArray<WKReaction*> *reactionTop3;

@property(nonatomic,assign,readonly) BOOL hasSensitiveWord;

// 添加回应
-(void) addReaction:(WKReaction*)reaction;

// 取消回应
-(void) cancelReaction:(WKReaction*)reaction;

@property(nonatomic,assign) BOOL viewed;

@property(nonatomic,assign) NSInteger viewedAt;

// 临时数据，只存在内存内 extra是存在数据库内
@property(nonatomic,strong) NSMutableDictionary *tmpObject;


@property(nonatomic,assign) CGFloat flameIconSizeFactor; // 阅后即焚icon大小比率
@property(nonatomic,strong) RadialStatusNode *flameNode; // 阅后即焚的动画
@property(nonatomic,assign) BOOL flameFinished; // flame的动画完成
@property(nonatomic,copy) void(^OnFlameFinished)(void); // flame动画完成回调

-(BOOL) needFlame; // 是否需要显示阅后即焚

-(void) startFlameIfNeed:(void(^)(void))finished; // 阅后即焚开始焚烧


-(NSInteger) remainderFlame;  // 阅后即焚焚烧剩余时间

@property(nonatomic,assign) BOOL startingFlameFlag; // 开始flame标记 true表示正在计时

@property(nonatomic,copy,readonly) NSString *streamNo;

@property(nonatomic,assign) WKStreamFlag streamFlag;

@property(nonatomic,strong,readonly) NSMutableArray<WKStream*> *streams;

@property(nonatomic,assign,readonly) BOOL streamOn;

// 以下两个字段是为了，流式消息cell高度变高后自动调整tableView，不让产生顿挫感。
@property(nonatomic,assign) CGFloat cellOffsetY; // 消息应该滚动的Y的距离
@property(nonatomic,assign) CGFloat preCellHeight; // 上次cell的高度


@end

NS_ASSUME_NONNULL_END
