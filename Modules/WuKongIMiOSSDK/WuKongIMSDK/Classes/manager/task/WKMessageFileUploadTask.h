//
//  WKMessageFileUploadTask.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/15.
//

#import <Foundation/Foundation.h>
#import "WKTaskProto.h"
#import "WKMessage.h"
#import "WKBaseTask.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMessageFileUploadTask : WKBaseTask

-(instancetype) initWithMessage:(WKMessage*)message;

// 消息
@property(nonatomic,strong) WKMessage *message;


/**
 上传后返回的路径
 */
@property(nullable,nonatomic,strong) NSString *remoteUrl;




@end

NS_ASSUME_NONNULL_END
