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
    if(value) {
        self.cacheDictonary[key] = value;
    }else {
        [self.cacheDictonary removeObjectForKey:key];
    }
    
    [self.cacheArray addObject:key];
    
    [self cleanCache];
    
}
-(id) getCache:(NSString*)key {
    return self.cacheDictonary[key];
}
// 清理缓存
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
