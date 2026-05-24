//
//  WKSpaceConvSyncCache.m
//  WuKongBase
//

#import "WKSpaceConvSyncCache.h"

@interface WKSpaceConvSyncCache ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *channelSpaceMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *mySourceSpaceMap;
@end

@implementation WKSpaceConvSyncCache

+ (instancetype)shared {
    static WKSpaceConvSyncCache *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WKSpaceConvSyncCache alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _channelSpaceMap = [NSMutableDictionary dictionary];
        _mySourceSpaceMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSString *)keyForChannelId:(NSString *)channelId channelType:(uint8_t)channelType {
    return [NSString stringWithFormat:@"%@-%u", channelId ?: @"", (unsigned)channelType];
}

#pragma mark - space_id

- (void)setSpaceId:(NSString *)spaceId
      forChannelId:(NSString *)channelId
       channelType:(uint8_t)channelType {
    if (channelId.length == 0 || spaceId.length == 0) return;
    NSString *key = [self keyForChannelId:channelId channelType:channelType];
    @synchronized (self) {
        self.channelSpaceMap[key] = [spaceId copy];
    }
}

- (nullable NSString *)spaceIdForChannelId:(NSString *)channelId
                               channelType:(uint8_t)channelType {
    if (channelId.length == 0) return nil;
    NSString *key = [self keyForChannelId:channelId channelType:channelType];
    @synchronized (self) {
        return self.channelSpaceMap[key];
    }
}

- (void)removeSpaceIdForChannelId:(NSString *)channelId
                      channelType:(uint8_t)channelType {
    if (channelId.length == 0) return;
    NSString *key = [self keyForChannelId:channelId channelType:channelType];
    @synchronized (self) {
        [self.channelSpaceMap removeObjectForKey:key];
    }
}

#pragma mark - source_space_id

- (void)setMySourceSpaceId:(NSString *)sourceSpaceId
              forChannelId:(NSString *)channelId
               channelType:(uint8_t)channelType {
    if (channelId.length == 0 || sourceSpaceId.length == 0) return;
    NSString *key = [self keyForChannelId:channelId channelType:channelType];
    @synchronized (self) {
        self.mySourceSpaceMap[key] = [sourceSpaceId copy];
    }
}

- (nullable NSString *)mySourceSpaceIdForChannelId:(NSString *)channelId
                                       channelType:(uint8_t)channelType {
    if (channelId.length == 0) return nil;
    NSString *key = [self keyForChannelId:channelId channelType:channelType];
    @synchronized (self) {
        return self.mySourceSpaceMap[key];
    }
}

- (void)removeMySourceSpaceIdForChannelId:(NSString *)channelId
                              channelType:(uint8_t)channelType {
    if (channelId.length == 0) return;
    NSString *key = [self keyForChannelId:channelId channelType:channelType];
    @synchronized (self) {
        [self.mySourceSpaceMap removeObjectForKey:key];
    }
}

#pragma mark - lifecycle

- (void)clearAll {
    @synchronized (self) {
        [self.channelSpaceMap removeAllObjects];
        [self.mySourceSpaceMap removeAllObjects];
    }
}

@end
