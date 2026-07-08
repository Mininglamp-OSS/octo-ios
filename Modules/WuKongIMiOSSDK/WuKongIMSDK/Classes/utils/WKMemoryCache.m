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

        // cacheArray 是 FIFO 淘汰序, 先 remove 再 addObject 保证同一 key 只占
        // 一个槽位。老实现直接 addObject: 允许重复, 高频 setCache 同一 key 会
        // 让 cacheArray 无界膨胀; cleanCache 里 removeObject: 又只删首个匹配,
        // 淘汰错位 → dict 里陈旧对象长期存活, 放大 Bugly #9089 race 概率。
        [self.cacheArray removeObject:key];
        [self.cacheArray addObject:key];

        [self cleanCache];
    }
}
-(id) getCache:(NSString*)key {
    if (!key) return nil;
    // 用显式 __strong 本地承接返回值, 而不是 `return dict[key]`。
    // 后者依赖 `objc_retainAutoreleasedReturnValue` fast-path 才能在 @synchronized
    // 退出前完成 +1, 极端场景 (Bugly #9089 iOS 26 上 objc_release_x0 SEGV) 下
    // 拿不到 retain 的 val 在锁外被别的线程 setCache 顶掉即被解引, ARC 尾部的
    // objc_autoreleaseReturnValue 踩释放页。显式本地强引用后, retain 落在锁内、
    // release 落在返回后, 无论 RRV fast-path 是否命中都安全。
    id __strong value = nil;
    @synchronized (self) {
        value = [self.cacheDictonary objectForKey:key];
    }
    return value;
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
