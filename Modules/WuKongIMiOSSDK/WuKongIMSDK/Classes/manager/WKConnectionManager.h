//
//  WKConnectionManager.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/23.
//

#import <Foundation/Foundation.h>
#import "WKPacket.h"
#import "WKConnectInfo.h"
#import "WKConst.h"
NS_ASSUME_NONNULL_BEGIN


typedef enum : NSUInteger {
    WKNoConnect,    // 未连接
    WKConnecting,  // 连接中
    WKPullingOffline, // 拉取离线中
    WKConnected, // 已建立连接
    WKDisconnected, // 断开连接
} WKConnectStatus;






@protocol WKConnectionManagerDelegate <NSObject>

@optional
/**
 连接状态监听
 */
-(void) onConnectStatus:(WKConnectStatus)status reasonCode:(WKReason)reasonCode;


/**
  连接被踢出

 @param reasonCode 踢出原因代号
 @param reason 踢出原因字符串
 */
-(void) onKick:(uint8_t)reasonCode reason:(NSString*)reason;
@end

@interface WKConnectionManager : NSObject

+ (WKConnectionManager*)sharedManager;

@property(nonatomic,assign,readonly) WKConnectStatus connectStatus;


/**
 * 是否启用 WSS（NSURLSessionWebSocketTask）传输层。
 * 默认 YES。
 *
 * - YES：当 getConnectAddr 回调返回的地址以 ws:// 或 wss:// 开头时，
 *        使用 NSURLSessionWebSocketTask 建立长连接；否则 fallback 到 TCP。
 * - NO：始终强制使用 GCDAsyncSocket TCP 路径，即使地址是 ws/wss URL，
 *        也只取出 host:port 部分按 TCP 连接（用于灰度回退）。
 *
 * 灰度期 GCDAsyncSocket 与 NSURLSessionWebSocketTask 两条路径并存，
 * 通过本开关切换；setter 在下一次 connect/重连时生效。
 */
@property(nonatomic,assign) BOOL useWSS;

///  获取连接地址
///  支持的格式：
///    - "host:port"            → 走 TCP（GCDAsyncSocket）
///    - "ws://host:port/path"  → 走 WebSocket（明文，仅调试）
///    - "wss://host[:port]/path" → 走 WebSocket Secure（生产）
@property(nonatomic,copy) void(^getConnectAddr)(void(^complete)(NSString * __nullable addr));
/**
 *  连接悟空IM服务器
 */
-(void) connect;

/**
 断开连接
 @param force 是否强制断开 如果force设置为true 将不再自动重连
 */
-(void) disconnect:(BOOL) force;


/// 登出，将强制断开，并清除登录信息
-(void) logout;


/**
 添加连接委托

 @param delegate <#delegate description#>
 */
-(void) addDelegate:(id<WKConnectionManagerDelegate>) delegate;


/**
 移除连接委托

 @param delegate <#delegate description#>
 */
-(void)removeDelegate:(id<WKConnectionManagerDelegate>) delegate;


/**
 发送包

 @param packet <#packet description#>
 */
-(void) sendPacket:(WKPacket*)packet;

-(void) writeData:(NSData*) data;

/**
 发送ping包
 */
-(void) sendPing;

/**
  唤醒IM
 @param timeout 超时时间（超时后不管有没有成功都会执行complete）
 */
-(void) wakeup:(NSTimeInterval)timeout complete:(void(^__nullable)(NSError * __nullable error))complete;



@end

NS_ASSUME_NONNULL_END
