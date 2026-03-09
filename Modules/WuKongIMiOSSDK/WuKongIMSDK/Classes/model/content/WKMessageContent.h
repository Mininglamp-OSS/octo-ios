//
//  WKMessageContent.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/29.
//


extern NSString *  _Nonnull const WKEntityTypeRobotCommand; // robot命令

#import <Foundation/Foundation.h>
#import "WKUserInfo.h"
#import <fmdb/FMDB.h>
@class WKMessageContent;
NS_ASSUME_NONNULL_BEGIN


/*!
 @提醒的类型
 */
typedef NS_ENUM(NSUInteger, WKMentionedType) {
    /*!
     @所有人
     */
    WK_Mentioned_All = 1,
    
    /*!
     @部分指定用户
     */
    WK_Mentioned_Users = 2,
};

@interface WKMessageEntity : NSObject
@property(nonatomic,copy) NSString *type;
@property(nonatomic,assign) NSRange range;
@property(nonatomic,strong) id value;

+(WKMessageEntity*) type:(NSString*)type range:(NSRange)range;
+(WKMessageEntity*) type:(NSString*)type range:(NSRange)range value:(id _Nullable)value;
@end

/**
  消息中的@提醒信息
 */
@interface WKMentionedInfo : NSObject


///  初始化@提醒信息
/// @param type <#type description#>
- (instancetype)initWithMentionedType:(WKMentionedType)type;
/*!
 初始化@提醒信息
 
 @param type       @提醒的类型
 @param uids @的用户ID列表
 
 @return @提醒信息的对象
 */
- (instancetype)initWithMentionedType:(WKMentionedType)type
                                 uids:(NSArray *__nullable)uids;


/*!
 @提醒的类型
 */
@property (nonatomic, assign) WKMentionedType type;

/*!
 @的用户ID列表
 
 @discussion 如果type是@所有人，则可以传nil
 */
@property (nonatomic, strong) NSArray<NSString *> *uids;

/*!
 是否@了我
 */
@property (nonatomic, readonly) BOOL isMentionedMe;


@end


/// 回复
@interface WKReply : NSObject

@property(nonatomic,copy) NSString *messageID; // 被回复的消息ID
@property(nonatomic,assign) uint32_t messageSeq; // 被回复的消息seq

@property(nonatomic,copy) NSString *fromUID; // 被回复消息的发送者
@property(nonatomic,copy) NSString *fromName; // 被回复消息的发送者名称
@property(nonatomic,copy) NSString *rootMessageID; // 根消息ID（可为空）
@property(nonatomic,assign) BOOL  revoke; // 是否被撤回

@property(nonatomic,strong) WKMessageContent *content; // 被回复的消息正文

@end

@class WKMessage;
@interface WKMessageContent : NSObject<NSCopying>

//TODO: 这里要注意不能声明为strong 如果声明为strong message和media互相引用 就释放不掉了导致内存爆炸。
@property(nonatomic,weak) WKMessage *message;

/**
  消息内容中携带的发送者的用户信息
 */
@property (nonatomic, strong) WKUserInfo *senderUserInfo;

/*!
 消息中的@提醒信息
 */
@property (nonatomic, strong) WKMentionedInfo *mentionedInfo;


/// 回复内容
@property(nonatomic,strong) WKReply *reply;

/*!
 将消息内容序列化，编码成为可传输的json数据
 
 @discussion
 消息内容通过此方法，将消息中的所有数据，编码成为json数据，返回的json数据将用于网络传输。
 */
- (NSData *)encode;

// 上层无需实现encode 实现此方法即可
-(NSDictionary*) encodeWithJSON;

// 上层无序实现decode 实现此方法即可
-(void) decodeWithJSON:(NSDictionary*)contentDic;

/*!
 将json数据的内容反序列化，解码生成可用的消息内容
 
 @param data    消息中的原始json数据
 
 @discussion
 网络传输的json数据，会通过此方法解码，获取消息内容中的所有数据，生成有效的消息内容。
 */
- (void)decode:(NSData *)data;

// TODO: 解码消息只供DB使用（为了兼容MOS的@消息，因为@消息有DB操作 如果直接调用DB会与外面的DB发生冲突）
- (void)decode:(NSData *)data db:(FMDatabase*)db;




/**
 你自定义的消息类型，在各个平台上需要保持一致
 @return 正文类型
 */
+(NSNumber*) contentType;


/// 实际获取到的contentType （这种情况只会一个content对象被指定多个contentType的时候，可以通过这个属性获取到真实的contentType）
@property(nonatomic,assign,readonly) NSInteger realContentType;

/*!
 返回可搜索的关键内容列表
 
 @return 返回可搜索的关键内容列表
 
 @discussion 这里返回的关键内容列表将用于消息搜索，自定义消息必须要实现此接口才能进行搜索。
 */
- (NSString *)searchableWord;


/**
 返回在会话列表和本地通知中显示的消息内容摘要
 
 @return <#return value description#>
 */
- (NSString *)conversationDigest;


/// 消息正文字典
@property(nonatomic,strong) NSDictionary *contentDict;

/**
 扩展字段
 */
@property(nonatomic,strong) NSMutableDictionary *extra;


///  in 如果此字段有值 表示 只有在此值内的uid才能看见此条消息
@property(nonatomic,strong) NSArray *visibles;

@property(nonatomic,copy,nullable) NSString *robotID; // 机器人编号，如果是机器人发的消息需要给到机器人的ID
/// 消息entitiy项
@property(nonatomic,strong) NSArray<WKMessageEntity*> *entities;

@property(nonatomic,assign) BOOL flame;  // 是否开启阅后即焚
@property(nonatomic,assign) NSInteger flameSecond; // 阅后即焚的秒数，如果为0 表示读后就删，如果有值表示读后多少秒后删

// 用户滑动看见消息就认为已查看 默认为true
-(BOOL) viewedOfVisible;

@end

NS_ASSUME_NONNULL_END
