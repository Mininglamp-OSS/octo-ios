//
//  WKMessageExtraDB.h
//  WuKongIMSDK
//
//  Created by tt on 2022/4/12.
//

#import <Foundation/Foundation.h>
#import "WKMessageExtra.h"
#import "WKChannel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMessageExtraDB : NSObject

+ (WKMessageExtraDB *)shared;


-(void) addOrUpdateMessageExtras:(NSArray<WKMessageExtra*>*)messageExtras;

-(void) addOrUpdateMessageExtra:(WKMessageExtra*)messageExtra db:(FMDatabase*)db;


-(long long) getMessageExtraMaxVersion:(WKChannel*)channel;

// 添加或更新正文编辑的内容
-(void) addOrUpdateContentEdit:(WKMessageExtra*)messageExtra;

// 通过消息ID获取消息扩展
-(WKMessageExtra*) getMessageExtraWithMessageID:(uint64_t)messageID;

// 获取等待上传的正文编辑内容
-(NSArray<WKMessageExtra*>*) getContentEditWaitUpload;

// 更新正文上传状态为失败
-(void) updateContentEditUploadStatusToFailStatus;

// 更新消息状态
-(void) updateUploadStatus:(WKContentEditUploadStatus)status withMessageID:(uint64_t)messageID;

@end

NS_ASSUME_NONNULL_END
