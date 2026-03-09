//
//  WKCoder.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//

#import <Foundation/Foundation.h>
#import "WKPacket.h"
NS_ASSUME_NONNULL_BEGIN


@interface WKCoder : NSObject


/**
 编码包

 @param packet 包对象
 @return 返回包的二进制数据
 */
-(NSData*) encode:(WKPacket*)packet;


/**
 解码包

 @param data <#data description#>
 @return <#return value description#>
 */
-(WKPacket*) decode:(NSData*)data;

@end

NS_ASSUME_NONNULL_END
