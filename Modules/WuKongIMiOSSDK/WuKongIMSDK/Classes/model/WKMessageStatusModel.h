//
//  WKMessageStatusModel.h
//  WuKongIMBase
//
//  Created by tt on 2019/12/29.
//

#import <Foundation/Foundation.h>
#import "WKConst.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMessageStatusModel : NSObject
// 消息唯一ID
@property(nonatomic,assign) uint32_t clientSeq;
// 消息状态
@property(nonatomic) WKMessageStatus status;

-(instancetype) initWithClientSeq:(uint32_t)clientSeq status:(WKMessageStatus)status;
@end

NS_ASSUME_NONNULL_END
