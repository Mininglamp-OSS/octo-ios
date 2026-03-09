//
//  WKMessageExtra.h
//  WuKongIMSDK
//
//  Created by tt on 2022/4/12.
//

#import <Foundation/Foundation.h>
#import "WKMessageContent.h"
NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    WKContentEditUploadStatusSuccess, // 成功
    WKContentEditUploadStatusWait, // 等待上传
    WKContentEditUploadStatusError, // 上传错误
} WKContentEditUploadStatus; // 编辑正文上传状态

@interface WKMessageExtra : NSObject

@property(nonatomic,assign) uint64_t messageID; // 消息id
@property(nonatomic,copy)   NSString *channelID; // 频道id
@property(nonatomic,assign) NSInteger channelType; // 频道类型
@property(nonatomic,assign) uint32_t messageSeq; // 消息id
@property(nonatomic,assign) BOOL readed;  // 是否已读
@property(nonatomic,copy) NSDate *readedAt; // 已读时间
@property(nonatomic,assign) NSInteger readedCount; // 已读人数
@property(nonatomic,assign) NSInteger unreadCount; // 未读人数
@property(nonatomic,assign) BOOL  revoke; // 是否撤回
@property(nonatomic,copy)   NSString *revoker; // 撤回人的uid
@property(nonatomic,assign) int64_t extraVersion;
@property(nonatomic,strong,nullable) NSData *contentEditData; // 消息编辑后的正文data数据
@property(nonatomic,strong,nullable) WKMessageContent *contentEdit; // 消息编辑后的正文
@property(nonatomic,assign) NSInteger editedAt; // 消息编辑时间 （0表示消息未被编辑）
@property(nonatomic,assign) BOOL isEdit; //  是否编辑
@property(nonatomic,assign) WKContentEditUploadStatus uploadStatus; // 上传状态
@property(nonatomic,assign) BOOL isMutualDeleted; // 是否双向删除

@property(nonatomic,assign) BOOL isPinned; // 是否已置顶

@property(nonatomic,copy) NSDictionary *extra; // 扩展数据

@end

NS_ASSUME_NONNULL_END
