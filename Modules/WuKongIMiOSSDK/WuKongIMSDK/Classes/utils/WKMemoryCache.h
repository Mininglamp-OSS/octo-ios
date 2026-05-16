//
//  WKCache.h
//  WuKongIMBase
//
//  Created by tt on 2020/1/11.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKMemoryCache : NSObject


/**
 最大缓存数量 默认不限制
 */
@property(nonatomic,assign) NSInteger maxCacheNum;

/**
 设置缓存
 
 @param value 值
 @param key 键
 */
-(void) setCache:(id __nullable)value forKey:(NSString*)key;


/**
 获取缓存
 
 @param key 键
 @return 值
 */
-(id) getCache:(NSString*)key;

@end

NS_ASSUME_NONNULL_END
