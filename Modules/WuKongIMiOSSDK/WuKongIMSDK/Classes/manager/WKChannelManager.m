//
//  WKChannelManager.m
//  WuKongIMSDK
//
//  Created by tt on 2019/12/23.
//

#import "WKChannelManager.h"
#import "WKSDK.h"
#import "WKChannelInfoDB.h"
#import "WKChannelMemberDB.h"
#import "WKMediaUtil.h"
#import "WKChannelRequestQueue.h"
#import "WKMemoryCache.h"


@interface WKChannelManager ()

@property(nonatomic,strong) NSMutableDictionary *cacheDict;
@property(nonatomic,strong) NSLock *cacheDictLock;

/**
 *  用来存储所有添加j过的delegate
 *  NSHashTable 与 NSMutableSet相似，但NSHashTable可以持有元素的弱引用，而且在对象被销毁后能正确地将其移除。
 */
@property (strong, nonatomic) NSHashTable  *delegates;
/**
 *  delegateLock 用于给delegate的操作加锁，防止多线程同时调用
 */
@property (strong, nonatomic) NSLock  *delegateLock;

@property(nonatomic,strong) NSMutableDictionary<NSString*,NSMutableArray<WKChannelInfoBlock>*> *channelReqeusts;
@property(nonatomic,strong) NSLock *channelReqeustLock;

@property(nonatomic,strong) WKMemoryCache *channelMemberCache; // 频道成员内存缓存

@end

@implementation WKChannelManager


static WKChannelManager *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKChannelManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        [_instance setup];
    });
    return _instance;
}

-(void) setup {
   NSArray<WKChannelInfo*> *channelInfos = [[WKChannelInfoDB shared] queryAllConversationChannelInfos];
    if(channelInfos && channelInfos.count>0) {
        for (WKChannelInfo *channelInfo in channelInfos) {
            [self setCache:channelInfo];
        }
    }
    self.channelMemberCache = [[WKMemoryCache alloc] init];
    self.channelMemberCache.maxCacheNum = 100000;
}

-(WKTaskOperator*) fetchChannelInfo:(WKChannel*) channel completion:(WKChannelInfoBlock)channelInfoBlock {
    NSString *key = [NSString stringWithFormat:@"%@-%d",channel.channelId,channel.channelType];
    [self.channelReqeustLock lock];
    NSMutableArray<WKChannelInfoBlock> *blockArray =  self.channelReqeusts[key];
    [self.channelReqeustLock unlock];
    if(blockArray && blockArray.count>0) { // 如果有值，则是重复请求，不处理
        [blockArray addObject:^(WKChannelInfo* channelInfo){
            if(channelInfoBlock) {
                channelInfoBlock(channelInfo);
            }
        }];
        return nil;
    }
    blockArray = [NSMutableArray array];
    [blockArray addObject:^(WKChannelInfo* channelInfo){
        if(channelInfoBlock) {
            channelInfoBlock(channelInfo);
        }
    }];
    
    [self.channelReqeustLock lock];
    self.channelReqeusts[key] = blockArray;
    [self.channelReqeustLock unlock];
    
    __weak typeof(self) weakSelf = self;
   return [WKSDK shared].channelInfoUpdate(channel,^(NSError *error,bool notifyBefore){
        if(notifyBefore) {
            return;
        }
         [weakSelf.channelReqeustLock lock];
        NSArray<WKChannelInfoBlock> *allBlock =  weakSelf.channelReqeusts[key];
         [weakSelf.channelReqeusts removeObjectForKey:key];
         [weakSelf.channelReqeustLock unlock];
        if(allBlock && allBlock.count>0) {
            WKChannelInfo *channelInfo = [[WKChannelInfoDB shared] queryChannelInfo:channel];
            for (WKChannelInfoBlock channelInfoBlock in allBlock) {
                 channelInfoBlock(channelInfo);
            }
        }
    });
}

-(void) fetchChannelInfo:(WKChannel*) channel {
    [self fetchChannelInfo:channel completion:nil];
}

-(void) addChannelRequest:(WKChannel*)channel complete:(void(^_Nullable)(NSError *error,bool notifyBefore))complete{
    [[WKChannelRequestQueue shared] addRequest:channel complete:complete];
}

-(void) cancelRequest:(WKChannel*)channel {
    [[WKChannelRequestQueue shared] cancelRequest:channel];
}

-(WKChannelInfo*) getChannelInfo:(WKChannel*)channel {
//    NSLog(@"getChannelInfo---->%@",channel.channelId);
    WKChannelInfo *channelInfo = [self getCache:channel];
    if(!channelInfo) {
        channelInfo = [[WKChannelInfoDB shared] queryChannelInfo:channel];
        if(channelInfo) {
            [self setCache:channelInfo];
        }
    }
    return channelInfo;
}

-(WKChannelInfo*) getChannelInfoOfUser:(NSString*)uid {
    return [self getChannelInfo:[WKChannel personWithChannelID:uid]];
}

-(void) deleteChannelInfo:(WKChannel*) channel {
    if(!channel.channelId || [channel.channelId isEqualToString:@""]) {
        return;
    }
    
    WKChannelInfo *oldChannelInfo = [self getChannelInfo:channel];
    
    [self deleteCache:channel];
    // 删除频道的基础信息
    [[WKChannelInfoDB shared] deleteChannelInfo:channel];
    // 删除频道的成员数据
    [[WKChannelMemberDB shared] deleteMembers:channel];
    // 通知删除
    [self callChannelInfoDeleteDelegate:channel oldChannelInfo:oldChannelInfo];
    
}

- (NSMutableDictionary *)channelReqeusts {
    if(!_channelReqeusts) {
        _channelReqeusts = [NSMutableDictionary dictionary];
    }
    return _channelReqeusts;
}

- (NSLock *)channelReqeustLock {
    if(!_channelReqeustLock) {
        _channelReqeustLock = [[NSLock alloc] init];
    }
    return _channelReqeustLock;
}

-(void) addChannelInfo:(WKChannelInfo*) channelInfo {
    [[WKChannelInfoDB shared] saveChannelInfo:channelInfo];
    [self setCache:channelInfo];
    [self callChannelInfoUpdateDelegate:channelInfo oldChannelInfo:nil];
}

-(void) addOrUpdateChannelInfoIfNeed:(WKChannelInfo*) channelInfo {
   WKChannelInfo *existChannelInfo =  [self getChannelInfo:channelInfo.channel];
    if(existChannelInfo && existChannelInfo.version >= channelInfo.version) { // 如果存在并且版本号大于传入频道信息的版本号则不更新
        return;
    }
    if(existChannelInfo) {
        [self updateChannelInfo:channelInfo];
    }else {
        [self addChannelInfo:channelInfo];
    }
    
}
-(void) addOrUpdateChannelInfo:(WKChannelInfo*) channelInfo {
    WKChannelInfo *existChannelInfo =  [self getChannelInfo:channelInfo.channel];
    if(existChannelInfo) {
        [self updateChannelInfo:channelInfo];
    }else {
        [self addChannelInfo:channelInfo];
    }
}

-(void) updateChannelSetting:(WKChannel*)channel setting:(NSDictionary*)setting {
     WKChannelInfo *channelInfo =  [self getChannelInfo:channel];
    if(channelInfo) {
        for (NSString *key in setting.allKeys) {
            if([key isEqualToString:@"mute"]) { // 免打扰
                channelInfo.mute = [setting[key] boolValue];
            }
            if([key isEqualToString:@"stick"]) { // 置顶
                channelInfo.stick = [setting[key] boolValue];
            }
            if([key isEqualToString:@"show_nick"]) { // 置顶
                channelInfo.showNick = [setting[key] boolValue];
            }
            if([key isEqualToString:@"save"]) { // 保存
                channelInfo.save = [setting[key] boolValue];
            }
            if([key isEqualToString:@"invite"]) { // 确认邀请
                channelInfo.invite = [setting[key] boolValue];
            }
            if([key isEqualToString:@"flame"]) { // 阅后即焚
                channelInfo.flame = [setting[key] boolValue];
            }
            if([key isEqualToString:@"flame_second"] && setting[key] ) { // 阅后即焚
                channelInfo.flameSecond = [setting[key] integerValue];
            }
             [self updateChannelInfo:channelInfo];
        }
    }
}

-(void) addOrUpdateChannelInfos:(NSArray<WKChannelInfo*>*) channelInfos {
     NSArray<WKChannelInfo*> *oldChannelInfos = [[WKChannelInfoDB shared] addOrUpdateChannelInfos:channelInfos];
    if(channelInfos && channelInfos.count>0) {
        for (WKChannelInfo *channelInfo in channelInfos) {
            [self setCache:channelInfo];
            WKChannelInfo *oldChannelInfo;
            if(oldChannelInfos && oldChannelInfos.count>0) {
                for (WKChannelInfo *oldC in oldChannelInfos) {
                    if([oldC.channel isEqual:channelInfo.channel]) {
                        oldChannelInfo = oldC;
                        break;
                    }
                }
            }
            [self callChannelInfoUpdateDelegate:channelInfo oldChannelInfo:oldChannelInfo];
        }
       
    }
}

-(void) deleteMembers:(WKChannel*)channel {
    [self deleteMembersWithChannelFromCache:channel];
    [[WKChannelMemberDB shared] deleteMembers:channel];
}

-(void) addOrUpdateMembers:(NSArray<WKChannelMember*>*)members {
    if(!members || members.count == 0) {
        return;
    }
    WKChannel *channel = [WKChannel channelID:members[0].channelId channelType:members[0].channelType];
    [self deleteMembersWithChannelFromCache:channel];
    [[WKChannelMemberDB shared] addOrUpdateMembers:members];
}

-(NSArray<WKChannelMember*>*) getMembersWithChannel:(WKChannel*)channel {
   NSArray<WKChannelMember*> *members = [self getMembersWithChannelFromCache:channel];
    if(members && members.count>0) {
        return members;
    }
    members = [[WKChannelMemberDB shared] getMembersWithChannel:channel];
    

    [self setMembersForCache:channel members:members];
    
    return members;
}

-(NSArray<WKChannelMember*>*) getMembersWithChannel:(WKChannel*)channel limit:(NSInteger)limit {
    return [[WKChannelMemberDB shared] getMembersWithChannel:channel limit:limit];
}

-(NSInteger) getMemberCount:(WKChannel*)channel {
    return [[WKChannelMemberDB shared] getMemberCount:channel];
}



-(WKChannelMember*)getMember:(WKChannel*)channel uid:(NSString*)uid {
    WKChannelMember *member =  [self getMemberFromCache:channel uid:uid];
    if(member) {
        return member;
    }
    member =  [[WKChannelMemberDB shared] get:channel memberUID:uid];
    return member;
}

-(BOOL) isManager:(WKChannel*)channel memberUID:(NSString*)uid {
    WKChannelMember *member = [self getMember:channel uid:uid];
    if(!member) {
        return false;
    }
    if(member.role == WKMemberRoleCreator || member.role == WKMemberRoleManager) {
        return true;
    }
    return false;
}

- (NSString *)getMemberLastSyncKey:(WKChannel *)channel {
    return [[WKChannelMemberDB shared] getMemberLastSyncKey:channel];
}

-(void) updateChannelInfo:(WKChannelInfo*) channelInfo {
    WKChannelInfo *oldChannelInfo = [[WKChannelInfoDB shared] queryChannelInfo:channelInfo.channel];
    [[WKChannelInfoDB shared] updateChannelInfo:channelInfo];
    [self setCache:channelInfo];
    [self callChannelInfoUpdateDelegate:channelInfo oldChannelInfo:oldChannelInfo];
}

-(void) setChannelOnline:(WKChannel*)channel deviceFlag:(WKDeviceFlagEnum)deviceFlag{
    WKChannelInfo *existChannelInfo =  [self getChannelInfo:channel];
    if(existChannelInfo) {
        WKChannelInfo *oldChannelInfo = [existChannelInfo copy];
        existChannelInfo.online = true;
        existChannelInfo.deviceFlag = deviceFlag;
        [[WKChannelInfoDB shared] updateChannelOnlineStatus:channel status:WKOnlineStatusOnline lastOffline:0 mainDeviceFlag:deviceFlag];
         [self callChannelInfoUpdateDelegate:existChannelInfo oldChannelInfo:oldChannelInfo];
    }
    
}

- (void)setChannelOnline:(WKChannel *)channel {
    [self setChannelOnline:channel deviceFlag:WKDeviceFlagEnumUnknown];
}

- (void)setChannelOffline:(WKChannel *)channel {
    [self setChannelOffline:channel lastOffline:[[NSDate date] timeIntervalSince1970]];
}

- (void)setChannelOffline:(WKChannel *)channel deviceFlag:(WKDeviceFlagEnum)deviceFlag{
    [self setChannelOffline:channel lastOffline:[[NSDate date] timeIntervalSince1970] deviceFlag:deviceFlag];
}

- (void)setChannelOffline:(WKChannel *)channel lastOffline:(NSTimeInterval)lastOffline {
    [self setChannelOffline:channel lastOffline:lastOffline deviceFlag:WKDeviceFlagEnumUnknown];
}

- (void)setChannelOffline:(WKChannel *)channel lastOffline:(NSTimeInterval)lastOffline deviceFlag:(WKDeviceFlagEnum)deviceFlag {
    WKChannelInfo *existChannelInfo =  [self getChannelInfo:channel];
    if(existChannelInfo) {
        WKChannelInfo *oldChannelInfo = [existChannelInfo copy];
        existChannelInfo.online = false;
        existChannelInfo.lastOffline =lastOffline;
        existChannelInfo.deviceFlag = deviceFlag;
       [[WKChannelInfoDB shared] updateChannelOnlineStatus:channel status:WKOnlineStatusOffline lastOffline:lastOffline mainDeviceFlag:deviceFlag];
        
        [self callChannelInfoUpdateDelegate:existChannelInfo oldChannelInfo:oldChannelInfo];
    }
}

-(void) updateChannelOnlineStatus:(WKChannel*)channel online:(BOOL)online {
    WKChannelInfo *existChannelInfo =  [self getChannelInfo:channel];
    if(existChannelInfo) {
        WKChannelInfo *oldChannelInfo = [existChannelInfo copy];
        
        existChannelInfo.online = online;
       [[WKChannelInfoDB shared] updateChannelInfo:existChannelInfo];
        
        [self callChannelInfoUpdateDelegate:existChannelInfo oldChannelInfo:oldChannelInfo];
    }
}

-(void) setCache:(WKChannelInfo*) channelInfo {
     [self.cacheDictLock lock];
     self.cacheDict[[self getCacheChannelKey:channelInfo.channel]] = channelInfo;
     [self.cacheDictLock unlock];
}

-(void) deleteCache:(WKChannel*)channel {
    [self.cacheDictLock lock];
    [self.cacheDict removeObjectForKey:[self getCacheChannelKey:channel]];
    [self.cacheDictLock unlock];
}

-(WKChannelMember*) getMemberFromCache:(WKChannel *)channel uid:(NSString *)uid {
    NSString *key = [NSString stringWithFormat:@"%@-%d",channel.channelId,channel.channelType];
    NSMutableArray<WKChannelMember*> *members =  [self.channelMemberCache getCache:key];
    if(!members||members.count<=0) {
        return nil;
    }
    for (WKChannelMember *member in members) {
        if([member.memberUid isEqualToString:uid]) {
            return member;
        }
    }
    return nil;
}

-(void) deleteMembersWithChannelFromCache:(WKChannel*)channel {
    NSString *key = [NSString stringWithFormat:@"%@-%d",channel.channelId,channel.channelType];
    [self.channelMemberCache setCache:nil forKey:key];
}

-(NSArray<WKChannelMember*>*) getMembersWithChannelFromCache:(WKChannel *)channel {
    NSString *key = [NSString stringWithFormat:@"%@-%d",channel.channelId,channel.channelType];
    return  [self.channelMemberCache getCache:key];
}

-(void) setMembersForCache:(WKChannel*)channel members:(NSArray<WKChannelMember*>*)members {
    NSString *key = [NSString stringWithFormat:@"%@-%d",channel.channelId,channel.channelType];
    [self.channelMemberCache setCache:members forKey:key];
}



-(WKChannelInfo*) getCache:(WKChannel*)channel {
    [self.cacheDictLock lock];
    WKChannelInfo *channelInfo = [self.cacheDict objectForKey:[self getCacheChannelKey:channel]];
    [self.cacheDictLock unlock];
    return channelInfo;
}

-(void) removeChannelAllCache {
    [self.cacheDictLock lock];
    [self.cacheDict removeAllObjects];
    [self.cacheDictLock unlock];
}

-(NSString*) getCacheChannelKey:(WKChannel*)channel {
    return [NSString stringWithFormat:@"%@-%hhu",channel.channelId,channel.channelType];
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

-(NSMutableDictionary*) cacheDict {
    if(!_cacheDict) {
        _cacheDict = [[NSMutableDictionary alloc] init];
    }
    return _cacheDict;
}

-(NSLock*) cacheDictLock {
    if(!_cacheDictLock) {
        _cacheDictLock = [[NSLock alloc] init];
    }
    return _cacheDictLock;
}

-(void) addDelegate:(id<WKChannelManagerDelegate>) delegate{
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates addObject:delegate];
    [self.delegateLock unlock];
}
- (void)removeDelegate:(id<WKChannelManagerDelegate>) delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates removeObject:delegate];
    [self.delegateLock unlock];
}

- (void)callChannelInfoUpdateDelegate:(WKChannelInfo*)channelInfo oldChannelInfo:(WKChannelInfo*)oldChannelInfo{
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        
        if(delegate && [delegate respondsToSelector:@selector(channelInfoUpdate:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                     [delegate channelInfoUpdate:channelInfo];
                });
            }else{
                [delegate channelInfoUpdate:channelInfo];
            }
        } else if (delegate && [delegate respondsToSelector:@selector(channelInfoUpdate:oldChannelInfo:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                     [delegate channelInfoUpdate:channelInfo oldChannelInfo:oldChannelInfo];
                });
            }else{
                [delegate channelInfoUpdate:channelInfo oldChannelInfo:oldChannelInfo];
            }
            
        }
    }
}

- (void)callChannelInfoDeleteDelegate:(WKChannel*)channel oldChannelInfo:(WKChannelInfo*)oldChannelInfo{
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if (delegate && [delegate respondsToSelector:@selector(channelInfoDelete:oldChannelInfo:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                     [delegate channelInfoDelete:channel oldChannelInfo:oldChannelInfo];
                });
            }else{
                [delegate channelInfoDelete:channel oldChannelInfo:oldChannelInfo];
            }
        }
    }
}

@end
