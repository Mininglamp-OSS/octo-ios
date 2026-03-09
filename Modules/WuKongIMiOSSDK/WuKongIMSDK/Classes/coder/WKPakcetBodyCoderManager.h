//
//  WKPakcetBodyManager.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//

#import <Foundation/Foundation.h>
#import "WKPacketBodyCoder.h"
#import "WKConst.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKPakcetBodyCoderManager : NSObject


/**
 注册body解码者

 @param packetType 包类型
 @param bodyCoder 包编码者
 */
-(void) registerBodyCoder:(WKPacketType)packetType bodyCoder:(id<WKPacketBodyCoder>)bodyCoder;

/**
 获取body编码者

 @param packetType 包类型
 @return 返回包body编码者
 */
-(id<WKPacketBodyCoder>) getBodyCoder:(WKPacketType)packetType;
@end

NS_ASSUME_NONNULL_END
