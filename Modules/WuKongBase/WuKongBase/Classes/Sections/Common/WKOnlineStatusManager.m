//
//  WKOnlineStatusManager.m
//  WuKongBase
//
//  Created by tt on 2020/8/29.
//

#import "WKOnlineStatusManager.h"
#import "WKAPIClient.h"
#import "WKApp.h"
#import "WuKongBase.h"
@class WKOnlineStatusResp;
@interface WKOnlineStatusManager ()<WKConnectionManagerDelegate>



/**
 *  用来存储所有添加j过的delegate
 *  NSHashTable 与 NSMutableSet相似，但NSHashTable可以持有元素的弱引用，而且在对象被销毁后能正确地将其移除。
 */
@property (strong, nonatomic) NSHashTable  *delegates;
/**
 *  delegateLock 用于给delegate的操作加锁，防止多线程同时调用
 */
@property (strong, nonatomic) NSLock  *delegateLock;

@property(nonatomic,strong) WKFriendAndMyDeviceOnlineStatusResp *friendAndMyDeviceOnlineStatusResp;

@end

@implementation WKOnlineStatusManager

static WKOnlineStatusManager *_instance = nil;

+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone ];
    });
    return _instance;
}

+(instancetype) shared{
    if (_instance == nil) {
        _instance = [[super alloc]init];
        _instance.needUpdate = YES;
        [[WKSDK shared].connectionManager addDelegate:_instance];
    }
    return _instance;
}

- (BOOL)pcOnline {
    if(self.friendAndMyDeviceOnlineStatusResp && self.friendAndMyDeviceOnlineStatusResp.pc) {
        return self.friendAndMyDeviceOnlineStatusResp.pc.online;
    }
    return false;
}
- (WKDeviceFlagEnum)pcDeviceFlag {
    if(self.friendAndMyDeviceOnlineStatusResp && self.friendAndMyDeviceOnlineStatusResp.pc) {
        return self.friendAndMyDeviceOnlineStatusResp.pc.deviceFlag;
    }
    return WKDeviceFlagEnumWeb;
}

-(void) setChannelOnline:(WKChannel*)channel online:(BOOL)online deviceFlag:(WKDeviceFlagEnum)deviceFlag{
    // online 只表示当前在线/离线的设备 如果mainDeviceFlag有值 则表示当前用户在线的主设备，
    if(online) {
        [[WKSDK shared].channelManager setChannelOnline:channel deviceFlag:deviceFlag];
    }else {
        [[WKSDK shared].channelManager setChannelOffline:channel deviceFlag:deviceFlag];
    }
   

    WKOnlineStatusResp *resp = [WKOnlineStatusResp new];
    resp.deviceFlag = deviceFlag;
    resp.online = online;
    resp.uid = channel.channelId;
    [self callOnlineStatusChangeDelegate:resp];
}

//- (void)setChannelOnline:(WKOnlineStatusResp *)status  {
//    
//    [self setChannelOnline:[WKChannel personWithChannelID:status.uid] online:status.online deviceFlag:status.deviceFlag];
//}

- (void)requestUpdateChannelOnlineStatusIfNeed {
    if(!self.needUpdate) {
        return;
    }
    __weak typeof(self) weakSelf  = self;
    // 查询所有在线频道
    NSArray<WKChannelInfo*> *allOnlineChannelInfos = [[WKChannelInfoDB shared] queryChannelOnlines];
    [[WKAPIClient sharedClient] GET:@"user/online" parameters:nil model:WKFriendAndMyDeviceOnlineStatusResp.class].then(^(WKFriendAndMyDeviceOnlineStatusResp* onlineStatusResp){
        weakSelf.needUpdate = false;
        weakSelf.friendAndMyDeviceOnlineStatusResp = onlineStatusResp;
        if(onlineStatusResp.friends && onlineStatusResp.friends.count>0) {
            for (WKOnlineStatusResp *resp in onlineStatusResp.friends) {
                WKChannel *channel = [[WKChannel alloc] initWith:resp.uid channelType:WK_PERSON];
                if(resp.online) {
                    [[WKSDK shared].channelManager setChannelOnline:channel deviceFlag:resp.deviceFlag];
                }else {
                    [[WKSDK shared].channelManager setChannelOffline:channel lastOffline:resp.lastOffline deviceFlag:resp.deviceFlag];
                }
            }
           
        }
       
        if(onlineStatusResp.pc) {
            weakSelf.pcOnline = onlineStatusResp.pc.online;
            weakSelf.muteOfApp = onlineStatusResp.pc.muteOfApp;
            [weakSelf callOnlineStatusChangeMyPCOnlineStatusDelegate:onlineStatusResp.pc];
        }else {
            weakSelf.pcOnline = false;
            weakSelf.muteOfApp = false;
        }
        if(allOnlineChannelInfos && allOnlineChannelInfos.count>0) {
            bool noNeedOffline = false; // 不需要离线
            for (WKChannelInfo *onlineChannelInfo in allOnlineChannelInfos) {
                if(onlineStatusResp.friends && onlineStatusResp.friends.count>0) {
                    for (WKOnlineStatusResp *resp in onlineStatusResp.friends) {
                        if([resp.uid isEqualToString:onlineChannelInfo.channel.channelId]) {
                            noNeedOffline = true;
                            continue;
                        }
                    }
                }
                if(!noNeedOffline) {
                    [[WKChannelInfoDB shared] updateChannelOnlineStatus:onlineChannelInfo.channel status:WKOnlineStatusOffline lastOffline:0 mainDeviceFlag:WKDeviceFlagEnumUnknown];
                }
            }
        }
    });
}

-(void) onConnectStatus:(WKConnectStatus)status reasonCode:(WKReason)reasonCode{
    self.needUpdate = YES;
}


-(NSHashTable*) delegates {
    if (_delegates == nil) {
        _delegates = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    }
    return _delegates;
}

- (void)callOnlineStatusChangeDelegate:(WKOnlineStatusResp*)status {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(onlineStatusManagerChange:status:)]) {
            if (![NSThread isMainThread]) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [delegate onlineStatusManagerChange:self status:status];
                });
            }else {
                [delegate onlineStatusManagerChange:self status:status];
            }
        }
    }
}

- (void)callOnlineStatusChangeMyPCOnlineStatusDelegate:(WKPCOnlineResp*)status {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(onlineStatusManagerMyPCOnlineChange:status:)]) {
            if (![NSThread isMainThread]) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [delegate onlineStatusManagerMyPCOnlineChange:self status:status];
                });
            }else {
                [delegate onlineStatusManagerMyPCOnlineChange:self status:status];
            }
        }
    }
}

// 空表示不显示
- (NSString *)onlineStatusTip:(WKChannelInfo *)channelInfo {
    if(!channelInfo) {
        return nil;
    }
    if(channelInfo.channel.channelType != WK_PERSON) {
        return nil;
    }
    NSString *onlineDeviceName = [self deviceName:channelInfo.deviceFlag];
    if(channelInfo.online) {
        return [NSString stringWithFormat:LLang(@"%@在线"),onlineDeviceName];
    }
    if([[NSDate date] timeIntervalSince1970] - channelInfo.lastOffline<60) {
       return [NSString stringWithFormat:LLang(@"刚刚%@在线"),onlineDeviceName];
   }
    if(channelInfo.lastOffline+60*60>[[NSDate date] timeIntervalSince1970]) {
        return [NSString stringWithFormat:LLang(@"%0.0f分钟前%@在线"),([[NSDate date] timeIntervalSince1970]-channelInfo.lastOffline)/60,onlineDeviceName];
    }
    return  nil;
}

-(NSString*) deviceName:(WKDeviceFlagEnum)deviceFlag {
    if(deviceFlag == WKDeviceFlagEnumPC) {
        return @"电脑";
    }
    if(deviceFlag == WKDeviceFlagEnumWeb) {
        return @"网页";
    }
    if(deviceFlag == WKDeviceFlagEnumAPP) {
        return @"手机";
    }
    return @"";
}

-(NSString*) onlineStatusDetailTip:(WKChannelInfo*)channelInfo {
    NSString *tip = [self  onlineStatusTip:channelInfo];
    if(tip) {
        return tip;
    }
    if(channelInfo.lastOffline == 0) {
        return @"";
    }
//    NSString *onlineDeviceName = [self deviceName:channelInfo.deviceFlag];
   return [NSString stringWithFormat:@"最后在线 %@",[WKTimeTool formatDateStyle1:[NSDate dateWithTimeIntervalSince1970:channelInfo.lastOffline]]];
}


-(void) addDelegate:(id<WKOnlineStatusManagerDelegate>) delegate{
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates addObject:delegate];
    [self.delegateLock unlock];
}
- (void)removeDelegate:(id<WKOnlineStatusManagerDelegate>) delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates removeObject:delegate];
    [self.delegateLock unlock];
}

- (void)dealloc
{
    [[WKSDK shared].connectionManager removeDelegate:self];
}
@end


@implementation WKFriendAndMyDeviceOnlineStatusResp

+ (WKModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKFriendAndMyDeviceOnlineStatusResp *resp = [WKFriendAndMyDeviceOnlineStatusResp new];
    
    if(dictory[@"pc"]) {
        resp.pc = [WKPCOnlineResp fromMap:dictory[@"pc"] type:type];
    }
    
    if(dictory[@"friends"]) {
        NSMutableArray<WKOnlineStatusResp*> *friends = [NSMutableArray array];
        for (NSDictionary *friendOnlineStatusDict in dictory[@"friends"]) {
            [friends addObject:[WKOnlineStatusResp fromMap:friendOnlineStatusDict type:type]];
        }
        resp.friends = friends;
    }
    
    return resp;
}

@end

@implementation WKPCOnlineResp

+ (WKPCOnlineResp * )fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKPCOnlineResp *resp = [WKPCOnlineResp new];
    resp.online = [dictory[@"online"] boolValue];
    if(dictory[@"device_flag"]) {
        resp.deviceFlag = [dictory[@"device_flag"] integerValue];
    }
    
    resp.muteOfApp = [dictory[@"mute_of_app"] boolValue];
    return resp;
}

@end

@implementation WKOnlineStatusResp

+ (WKOnlineStatusResp * _Nonnull)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKOnlineStatusResp *resp = [[WKOnlineStatusResp alloc] init];
    resp.uid = dictory[@"uid"];
    resp.lastOffline = [dictory[@"last_offline"] integerValue];
    resp.online = [dictory[@"online"] boolValue];
    resp.deviceFlag = (WKDeviceFlagEnum)[dictory[@"device_flag"] integerValue];
    return resp;
}

@end
