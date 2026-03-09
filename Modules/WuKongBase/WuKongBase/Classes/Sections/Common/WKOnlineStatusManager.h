//
//  WKOnlineStatusManager.h
//  WuKongBase
//
//  Created by tt on 2020/8/29.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKModel.h"
#import "WKConstant.h"
@class WKOnlineStatusResp;
@class WKPCOnlineResp;
NS_ASSUME_NONNULL_BEGIN

@class WKOnlineStatusManager;

@protocol WKOnlineStatusManagerDelegate <NSObject>

@optional

// 在线状态改变
-(void) onlineStatusManagerChange:(WKOnlineStatusManager*)manager status:(WKOnlineStatusResp*)status;

// 我的pc在线状态改变
-(void) onlineStatusManagerMyPCOnlineChange:(WKOnlineStatusManager*)manager status:(WKPCOnlineResp*)status;

@end

@interface WKOnlineStatusManager : NSObject



+ (WKOnlineStatusManager *)shared;

@property(nonatomic,assign) BOOL pcOnline; // pc是否在线
@property(nonatomic,assign) WKDeviceFlagEnum pcDeviceFlag; // pc设备
@property(nonatomic,assign) BOOL  muteOfApp; // app静音

@property(nonatomic,assign) BOOL needUpdate; // 是否需要更新在线状态

-(void) addDelegate:(id<WKOnlineStatusManagerDelegate>) delegate;

- (void)removeDelegate:(id<WKOnlineStatusManagerDelegate>) delegate;


/// 设置频道是否在线
/// @param channel 频道对象
/// @param online 是否在线
/// @param deviceFlag 当前在线或离线的设备标记
-(void) setChannelOnline:(WKChannel*)channel online:(BOOL)online deviceFlag:(WKDeviceFlagEnum)deviceFlag;


/// 如果频道在线状态需要更新则请求更新频道在线状态
-(void) requestUpdateChannelOnlineStatusIfNeed;

// 获取在线状态提示 空表示不显示
-(NSString*) onlineStatusTip:(WKChannelInfo*)channelInfo;

-(NSString*) onlineStatusDetailTip:(WKChannelInfo*)channelInfo;

// 设备标记对应的名字
-(NSString*) deviceName:(WKDeviceFlagEnum)deviceFlag;

- (void)callOnlineStatusChangeMyPCOnlineStatusDelegate:(WKPCOnlineResp*)status;

@end

@interface WKFriendAndMyDeviceOnlineStatusResp : WKModel

@property(nonatomic,strong,nullable) NSArray<WKOnlineStatusResp*> *friends;

@property(nonatomic,strong,nullable) WKPCOnlineResp *pc;

@end

@interface WKPCOnlineResp : WKModel

@property(nonatomic,assign) WKDeviceFlagEnum deviceFlag;

@property(nonatomic,assign) BOOL online; // pc是否在线

@property(nonatomic,assign) BOOL muteOfApp; //  app是否开启禁音

@end

@interface WKOnlineStatusResp : WKModel

@property(nonatomic,copy) NSString *uid; // 在线用户uid
@property(nonatomic,assign) NSInteger lastOffline; // 最后一次离线时间
@property(nonatomic,assign) BOOL online; // 是否在线
@property(nonatomic,assign) WKDeviceFlagEnum deviceFlag; // 设备flag

@end

NS_ASSUME_NONNULL_END
