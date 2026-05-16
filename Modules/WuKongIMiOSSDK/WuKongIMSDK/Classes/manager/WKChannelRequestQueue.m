//
//  WKChannelRequestQueue.m
//  WuKongIMSDK
//
//  Created by tt on 2021/4/22.
//

#import "WKChannelRequestQueue.h"
#import "WKSDK.h"

typedef enum : NSUInteger {
    Wait,
    Success,
    Error,
    Cancel,
} WKRequestStatus;

@interface WKChannelRequest : NSObject

@property(nonatomic,strong) WKChannel *channel;
@property(nonatomic,strong) WKTaskOperator *operator;
@property(nonatomic,assign) WKRequestStatus status;

-(void) cancel;

@end

@implementation WKChannelRequest

-(void) cancel {
    self.operator.cancel();
    self.status = Cancel;
}

@end

@interface WKChannelRequestQueue ()

@property(nonatomic,strong) NSMutableArray<WKChannelRequest*> *requests;

@property(nonatomic,strong) NSMutableDictionary<NSString*,WKChannelRequest*> *requestDict;

@property(nonatomic,strong) NSRecursiveLock *lock; // 递归锁可被同一线程多次获取


@end

@implementation WKChannelRequestQueue


static WKChannelRequestQueue *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKChannelRequestQueue *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(NSString*) getChannelKey:(WKChannel*)channel {
    return [NSString stringWithFormat:@"%@-%d",channel.channelId,channel.channelType];
}

-(void) addRequest:(WKChannel*)channel complete:(void(^)(NSError *error,bool notifyBefore))complete{
    NSString *key = [self getChannelKey:channel];
    
    [self.lock lock];
    WKChannelRequest *request = [self.requestDict objectForKey:key];
    if(request) {
        NSInteger index = [self.requests indexOfObject:request];
        if(index != 0) {
            [self.requests removeObjectAtIndex:index];
            [self.requests insertObject:request atIndex:0];
        }
    }else {
        request = [self createRequest:channel complete:complete];
        [self.requestDict setObject:request forKey:key];
        [self.requests insertObject:request atIndex:0];
    }
    
    if(self.requests.count>[WKSDK shared].options.channelRequestMaxLimit) {
        WKChannelRequest *request = [self.requests lastObject];
        if(request) {
            NSString *key = [self getChannelKey:request.channel];
            [self.requests removeObject:request];
            [self.requestDict removeObjectForKey:[self getChannelKey:request.channel]];
            [request cancel];
            
            NSLog(@"移除频道请求！->%@",key);
            
        }
    }
    [self.lock unlock];
}

-(WKChannelRequest *) createRequest:(WKChannel*)channel complete:(void(^)(NSError *error,bool notifyBefore))complete{
    WKChannelRequest *request = [WKChannelRequest new];
    WKTaskOperator *operator = [WKSDK shared].channelInfoUpdate(channel, ^(NSError * _Nullable error,bool notifyBefore) {
        if(notifyBefore) {
            if(complete) {
                complete(nil,notifyBefore);
            }
            return;
        }
        if(error) {
            request.status = Error;
        }else {
            request.status = Success;
        }
        if(complete) {
            complete(error,notifyBefore);
        }
    });
    request.channel =channel;
    request.operator = operator;
    return request;
}

-(void) cancelRequest:(WKChannel*)channel {
    [self.lock lock];
    NSString *key = [self getChannelKey:channel];
    WKChannelRequest *request = [self.requestDict objectForKey:key];
    if(request) {
        [self.requests removeObject:request];
        [self.requestDict removeObjectForKey:[self getChannelKey:request.channel]];
        [request cancel];
    }
    [self.lock unlock];
}


- (NSMutableArray<WKChannelRequest *> *)requests {
    if(!_requests) {
        _requests = [NSMutableArray array];
    }
    return _requests;
}

- (NSMutableDictionary *)requestDict {
    if(!_requestDict) {
        _requestDict = [NSMutableDictionary dictionary];
    }
    return _requestDict;
}

- (NSRecursiveLock *)lock {
    if(!_lock) {
        _lock = [[NSRecursiveLock alloc] init];
    }
    return _lock;
}


@end
