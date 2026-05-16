//
//  WKAPMManager.m
//  WuKongBase
//
//  Created by tt on 2022/5/6.
//

#import "WKAPMManager.h"

#define limApmSortsKey @"lim_apmSortsKey"

@implementation WKAPMSortInfo

@end

@interface WKAPMManager ()

/**
 *  用来存储所有添加j过的delegate
 *  NSHashTable 与 NSMutableSet相似，但NSHashTable可以持有元素的弱引用，而且在对象被销毁后能正确地将其移除。
 */
@property (strong, nonatomic) NSHashTable  *delegates;
/**
 *  delegateLock 用于给delegate的操作加锁，防止多线程同时调用
 */
@property (strong, nonatomic) NSLock  *delegateLock;


@end

@implementation WKAPMManager

static WKAPMManager *_instance;


+ (WKAPMManager *)shared
{
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    return _instance;
}

- (void)saveAPMSorts {
    NSMutableArray *sorts = [NSMutableArray array];
    if(self.apmSorts && self.apmSorts.count>0) {
        for (WKAPMSortInfo *sortInfo in self.apmSorts) {
            [sorts addObject:[self apmSortDict:sortInfo]];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:sorts forKey:limApmSortsKey];
    [[NSUserDefaults standardUserDefaults]  synchronize];
    [self callSortInfoChange];
    
}

-(NSDictionary*) apmSortDict:(WKAPMSortInfo*)apmSort {
    return @{
        @"apm_id":apmSort.apmID,
        @"sort": @(apmSort.sort),
        @"disable":@(apmSort.disable),
        @"type":@(apmSort.type),
    };
}

-(WKAPMSortInfo*) toApmSort:(NSDictionary*)dict {
    WKAPMSortInfo *sortInfo = [WKAPMSortInfo new];
    sortInfo.apmID = dict[@"apm_id"];
    sortInfo.sort = [dict[@"sort"] integerValue];
    sortInfo.disable  = [dict[@"disable"] boolValue];
    sortInfo.type = [dict[@"type"] integerValue];
    return sortInfo;
}

- (NSArray<WKAPMSortInfo *> *)apmSorts {
    if(!_apmSorts) {
        NSMutableArray<WKAPMSortInfo*> *sorts = [NSMutableArray array];
       NSArray<NSDictionary*> *sortObjs =  [[NSUserDefaults standardUserDefaults] objectForKey:limApmSortsKey];
        if(sortObjs && sortObjs.count>0) {
            for (NSDictionary *sortObj in sortObjs) {
                [sorts addObject:[self toApmSort:sortObj]];
            }
        }
        _apmSorts = sorts;
    }
    return _apmSorts;
}



- (NSLock *)delegateLock {
    if (_delegateLock == nil) {
        _delegateLock = [[NSLock alloc] init];
    }
    return _delegateLock;
}

-(NSHashTable*) delegates {
    if (_delegates == nil) {
        _delegates = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    }
    return _delegates;
}

-(void) callSortInfoChange {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(apmManagerSortInfoChange:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate apmManagerSortInfoChange:self];
                });
            }else {
                [delegate apmManagerSortInfoChange:self];
            }
        }
    }
}


-(void) addDelegate:(id<WKAPMManagerDelegate>) delegate{
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates addObject:delegate];
    [self.delegateLock unlock];
}
- (void)removeDelegate:(id<WKAPMManagerDelegate>) delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates removeObject:delegate];
    [self.delegateLock unlock];
}


@end
