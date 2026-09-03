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


///  获取连接地址
///  传输层固定走 WebSocket（NSURLSessionWebSocketTask），不再支持 TCP。
///  支持的格式：
///    - "wss://host[:port]/path" → WebSocket Secure（生产环境）
///    - "ws://host:port/path"    → WebSocket 明文（仅开发/调试）
///  也接受裸 "host:port"，会被自动包装成 "wss://host:port" 再连接。
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

/**
 主动探测连接活性（用于前台恢复等场景，能识别本地状态机停在 WKConnected 但服务端已踢的
 "假在线"）。
 - WKConnected：发送 ping，在 timeout 内若 lastMsgTimeInterval 未推进，且被 probe 的
   wsTask 与 connectStatus 未被并发路径改动，则显式 cancel 该 wsTask 并走
   handleWSDisconnectWithError: 强制断开 + 自动重连（触发 SDK 内部 syncConversations）。
   若 timeout 时发现 socket 已被并发 reconnect 替换 / 状态已变，则让那条生命周期继续，
   不做二次 backoff。
 - WKConnecting / WKPullingOffline：握手或离线拉取 in flight，不打扰，直接回调 alive=NO。
 - WKDisconnected / WKNoConnect：直接 connect。
 与 wakeup: 的区别：wakeup: 在 WKConnected 时直接 early return，无法识别假在线；
 probeLiveness: 主动发 ping 验证响应。
 契约：complete 回调统一 hop 到 main queue（无论 case A/B/C），调用方可以放心访问 UI 状态。
 @param timeout ping 等待响应的超时（秒），建议 2 秒
 @param complete 完成回调（main queue），alive=YES 表示连接活着（收到了 pong 或其他入站消息），
                 alive=NO 表示状态机在 in-flight 状态、被并发路径覆盖，或探测超时已触发重连
 */
-(void) probeLiveness:(NSTimeInterval)timeout complete:(void(^__nullable)(BOOL alive, NSError * __nullable error))complete;



@end

NS_ASSUME_NONNULL_END
