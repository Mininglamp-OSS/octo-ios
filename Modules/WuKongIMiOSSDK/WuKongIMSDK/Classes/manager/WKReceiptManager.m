//
//  WKReceiptManager.m
//  WuKongIMSDK
// 消息已读回执管理
//  Created by tt on 2021/4/9.
//

#import "WKReceiptManager.h"
#import "WKSDK.h"
#import "WKMessageDB.h"
@interface WKReceiptManager ()

@property(nonatomic,strong) NSMutableDictionary<WKChannel*,NSMutableSet<WKMessage*>*> *cacheDict;
@property(nonatomic,strong) NSLock *cachedLock;

@property(nonatomic,strong) NSTimer *flushTimer;

@end
@implementation WKReceiptManager


static WKReceiptManager *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKReceiptManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        [_instance setup];
    });
    return _instance;
}

-(void) setup {
    self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:[WKSDK shared].options.receiptFlushInterval target:self selector:@selector(flushLoop) userInfo:nil repeats:YES];
}

-(void) addReceiptMessages:(WKChannel*)channel messages:(NSArray<WKMessage*>*)messages {
    [self.cachedLock lock];
    NSMutableSet *messagesSets = [self.cacheDict objectForKey:channel];
    if(!messagesSets) {
        messagesSets = [[NSMutableSet alloc] init];
    }
    if(messages && messages.count>0) {
        for (WKMessage *message in messages) {
            if(!message.remoteExtra.readed) {
                [messagesSets addObject:message];
            }
        }
    }
    [self.cacheDict setObject:messagesSets forKey:channel];
    [self.cachedLock unlock];
}

-(void) flushLoop {
    if(![WKSDK shared].options.hasLogin) {
        return;
    }
    for (WKChannel *channel in self.cacheDict.allKeys) {
        [self flush:channel complete:^(NSError * _Nonnull error) {
            if(error!=nil) {
                NSLog(@"flush已读数据失败！->%@",error.domain);
            }
        }];
    }
}

-(void) flush:(WKChannel*)channel complete:(void(^)(NSError *error))complete {
    if(!self.messageReadedProvider) {
        NSLog(@"warn:没有设置消息已读提供者[[WKSDK shared].receiptManager setMessageReadedProvider]！不能操作fush");
        if(complete) {
            complete(nil);
        }
        return;
    }
    NSMutableArray *tmpMessages = [NSMutableArray array];
    [self.cachedLock lock];
    NSMutableSet *cacheMessages =[self.cacheDict objectForKey:channel];
    NSInteger flushCachedLen=0;
    if(cacheMessages && cacheMessages.count>0) {
        for (WKMessage *message in cacheMessages) {
            [tmpMessages addObject:message];
        }
        flushCachedLen = cacheMessages.count;
    }
    [self.cachedLock unlock];
    if(flushCachedLen<=0) {
        if(complete) {
            complete(nil);
        }
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    self.messageReadedProvider(channel,tmpMessages, ^(NSError * _Nullable error) {
        [weakSelf removeCacheWithLength:(WKChannel*)channel len:flushCachedLen];
        if(tmpMessages && tmpMessages.count>0) {
            for (WKMessage *message in tmpMessages) {
                message.remoteExtra.readed = YES;
            }
        }
        if(complete) {
            complete(error);
        }
    });
}

// 移除指定长度的缓存
-(void) removeCacheWithLength:(WKChannel*)channel len:(NSInteger)len {
    [self.cachedLock lock];
    NSMutableSet *cacheMessages = [self.cacheDict objectForKey:channel];
    NSMutableArray *tmpArray = [NSMutableArray array];
    if(cacheMessages && cacheMessages.count>0) {
        for (WKMessage *message in cacheMessages) {
            [tmpArray addObject:message];
        }
    }
    NSInteger actLen = len;
    if(tmpArray.count<len) {
        actLen =tmpArray.count;
    }
    for (NSInteger i=0;i<actLen ; i++) {
        WKMessage *message = [tmpArray objectAtIndex:i];
        [cacheMessages removeObject:message];
    }
    [self.cachedLock unlock];
}


- (NSLock *)cachedLock {
    if(!_cachedLock) {
        _cachedLock = [[NSLock alloc] init];
    }
    return _cachedLock;
}

- (NSMutableDictionary<WKChannel *,NSMutableSet<WKMessage *> *> *)cacheDict {
    if(!_cacheDict) {
        _cacheDict = [NSMutableDictionary dictionary];
    }
    return _cacheDict;
}

@end
