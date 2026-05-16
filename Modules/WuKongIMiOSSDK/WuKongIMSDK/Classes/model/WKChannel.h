//
//  WKChannel.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKChannel : NSObject<NSCopying>
// 频道ID
@property(nonatomic,copy) NSString *channelId;
// 频道类型
@property(nonatomic,assign) uint8_t channelType;

-(instancetype) initWith:(NSString*)channelId channelType:(uint8_t)channelType;

+(instancetype) channelID:(NSString*)channelId channelType:(uint8_t)channelType;
// 群频道
+(instancetype) groupWithChannelID:(NSString*)channelID;
// 个人频道
+(instancetype) personWithChannelID:(NSString*)channelID;

// 转换为map
-(NSDictionary*) toMap;
// 从map初始化
+(WKChannel*) fromMap:(NSDictionary*)dict;

@end

NS_ASSUME_NONNULL_END
