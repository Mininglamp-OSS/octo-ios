//
//  WKCache.m
//  WuKongIMBase
//
//  Created by tt on 2020/1/11.
//

#import "WKMemoryCache.h"

@interface WKMemoryCache ()
@property(nonatomic,strong) NSMutableDictionary<NSString*,id> *cacheDictonary;
@property(nonatomic,strong) NSMutableArray<NSString*> *cacheArray;

@end

@implementation WKMemoryCache

-(void) setCache:(id)value forKey:(NSString*)key {
    if (!key) return;
    // WKMemoryCache 实例会被 WKTextMessageCell 的高度预计算后台线程 (pullup
    // 走 QOS_CLASS_USER_INITIATED 全局队列) 与主线程 cellForRow 同时命中。
    // 内部 NSMutableDictionary / NSMutableArray 本身不是线程安全, A 线程
    // setObject 触发 bucket 扩容时 B 线程 objectForKey 会拿到悬空指针,
    // 后续 objc_retain 直接 SEGV_ACCERR (Bugly 现网命中). 统一加锁后,
    // 三处使用方 (WKTextMessageCell.textAttrCache/segHeightCache/sizeCache /
    // WKMergeForwardDetailCell / WKChannelManager) 都顺带拿到线程安全。
    @synchronized (self) {
        if(value) {
            self.cacheDictonary[key] = value;
        }else {
            [self.cacheDictonary removeObjectForKey:key];
        }

        [self.cacheArray addObject:key];

        [self cleanCache];
    }
}
-(id) getCache:(NSString*)key {
    if (!key) return nil;
    @synchronized (self) {
        return self.cacheDictonary[key];
    }
}
// 清理缓存 (调用方已在 @synchronized(self) 内,本方法不再重入加锁)
-(void) cleanCache {
    if(self.maxCacheNum>0) {
        if(self.cacheArray.count>self.maxCacheNum) {
            NSInteger cleanCount = self.maxCacheNum/2;
            for (int i=0;i<cleanCount;i++) {
                if(i<self.cacheArray.count) {
                    NSString *key = self.cacheArray[i];
                    [self.cacheDictonary removeObjectForKey:key];
                    [self.cacheArray removeObject:key];
                }
            }
        }
    }
}

-(NSMutableArray*) cacheArray {
    if(!_cacheArray) {
        _cacheArray = [NSMutableArray array];
    }
    return _cacheArray;
}

-(NSMutableDictionary*) cacheDictonary {
    if(!_cacheDictonary) {
        _cacheDictonary = [[NSMutableDictionary alloc] init];
    }
    return _cacheDictonary;
}

@end
