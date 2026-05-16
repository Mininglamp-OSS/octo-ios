//
//  WKMessageFileDownloadTask.h
//  WuKongIMBase
//
//  Created by tt on 2020/1/16.
//

#import <Foundation/Foundation.h>
#import "WKBaseTask.h"
#import "WKMessage.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMessageFileDownloadTask : WKBaseTask
-(instancetype) initWithMessage:(WKMessage*)message;


// 消息
@property(nonatomic,strong) WKMessage *message;




@end

NS_ASSUME_NONNULL_END
