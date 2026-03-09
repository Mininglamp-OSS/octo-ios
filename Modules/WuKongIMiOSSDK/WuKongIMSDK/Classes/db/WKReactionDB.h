//
//  WKReactionDB.h
//  WuKongIMSDK
//
//  Created by tt on 2021/9/13.
//

#import <Foundation/Foundation.h>
#import <fmdb/FMDB.h>
#import "WKReaction.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKReactionDB : NSObject

+ (WKReactionDB *)shared;


/**
 获取某个消息的回应
 */
-(NSArray<WKReaction*>*) getReactions:(NSArray<NSNumber*>*) messageIDs;

/**
  获取以消息ID为key 回应集合为值的字典
 */
-(  NSDictionary<NSString*,NSArray<WKReaction*>*> *) getReactionDictionary:(NSArray<NSNumber*>*) messageIDs;


/**
 插入回应
 */
-(BOOL) insertOrUpdateReactions:(NSArray<WKReaction*>*)reactions;

-(BOOL) insertOrUpdateReactions:(NSArray<WKReaction*>*)reactions db:(FMDatabase*)db;

/**
 获取某个频道的最大版本号
 */
-(uint64_t) maxVersion:(WKChannel*) channel;

@end

NS_ASSUME_NONNULL_END
