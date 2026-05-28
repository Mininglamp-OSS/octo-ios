//
//  WKConnectionManager.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/23.
//

#import "WKConnectionManager.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "WKSDK.h"
#import "WKUnreadAckRunner.h"
#import "WKConnectPacket.h"
#import "WKConnackPacket.h"
#import "WKConst.h"
#import "WKData.h"
#import "WKPingPacket.h"
#import "WKSendackPacket.h"
#import "WKMessageDB.h"
#import "WKRecvPacket.h"
#import "WKBackoff.h"
#import "WKRetryManager.h"
#import "WKDB.h"
#import "WKSDK.h"
#import "WKDisconnectPacket.h"
#import "WKCMDManager.h"
#import "WKSecurityManager.h"
#import "WKReminderManager.h"
#import "WKChatManagerInner.h"
#import "WKConversationManagerInner.h"
#import "WKMessageQueueManager.h"


@interface WKConnectionManager ()<GCDAsyncSocketDelegate, NSURLSessionWebSocketDelegate>


@property(nonatomic,strong) GCDAsyncSocket *ssocket;

// === WSS (NSURLSessionWebSocketTask) ===
// 灰度期 TCP / WSS 两条传输层路径并存，由 useWSS + 入参地址协议头共同决定走哪条。
@property(nonatomic,strong) NSURLSession *wsSession;
@property(nonatomic,strong) NSURLSessionWebSocketTask *wsTask;
// 当前连接是否走的是 WS/WSS（用于在 disconnect / writeData 等地方分流）。
@property(nonatomic,assign) BOOL connectedViaWS;

/**
 *  用来存储所有添加j过的delegate
 *  NSHashTable 与 NSMutableSet相似，但NSHashTable可以持有元素的弱引用，而且在对象被销毁后能正确地将其移除。
 */
@property (strong, nonatomic) NSHashTable  *delegates;
/**
 *  delegateLock 用于给delegate的操作加锁，防止多线程同时调用
 */
@property (strong, nonatomic) NSLock  *delegateLock;

// 是否强制关闭连接
@property(nonatomic,assign) BOOL forceDisconnect;


// 解包的临时数据
@property(nonatomic,strong) NSMutableData *tempBufferData;
@property(nonatomic,strong) NSLock *tempBufferDataLock;
// 连接 condition
@property(nonatomic,strong) NSLock *connectStatusLock;
@property(nonatomic,assign) WKConnectStatus connectStatusInner;
@property(nonatomic,assign) WKReason reasonCodeInner;

// 心跳定时器
@property(nonatomic,strong) NSTimer *heartTimer;
// 最后一次收到的消息时间
@property(nonatomic) NSTimeInterval lastMsgTimeInterval;

// 重连退避算法
@property(nonatomic,strong) WKBackoff *reconnectBackoff;
@property(nonatomic,assign) int reconnectCount; // 重连次数，连接成功设置为0
@property(nonatomic,assign) bool isBackoffReconnect; // 是否在退避重连中

@property(nonatomic,assign) bool pullOfflineFinished; // 是否拉取离线完成

@property(nonatomic,strong) NSMutableArray<WKPacket*> *tempPackets; // 临时包（当没拉取离线完成前所有消息都存临时数组里，避免漏消息。）

@property(nonatomic,copy) NSString *deviceUUID;

@property(nonatomic,copy) void(^onConnectStatusChange)(WKConnectStatus status);

@end

@implementation WKConnectionManager

static WKConnectionManager *_instance;

static dispatch_queue_t _imsocketQueue;

+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKConnectionManager*)sharedManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        _imsocketQueue = dispatch_queue_create("my.connection.queue", DISPATCH_QUEUE_SERIAL);
        _instance.delegates = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
        _instance.tempBufferData = [[NSMutableData alloc] init];
        _instance.connectStatusLock =[[NSLock alloc] init];
        _instance.tempBufferDataLock =[[NSLock alloc] init];
        _instance.tempPackets = [NSMutableArray array];
        _instance.useWSS = YES; // 灰度期默认开启 WSS；地址不是 ws/wss 时仍会走 TCP
        _instance.reconnectBackoff = [WKBackoff createWithBuilder:^(WKBackoffBuilder *builder) {
            builder.base = 2; // 每次递增秒数
            builder.factor = 2; // 每次重连的系数 base*factor
            builder.jitter = 0;
            builder.cap = 60 * 1000; // 60s
        }];

    });
    return _instance;
}


// 连接IM服务器
-(void) connect {
    // 设置当前连接信息
    [self.connectStatusLock lock];
    self.forceDisconnect = false;
    [self.connectStatusLock unlock];
    
    if(![WKSDK shared].options.hasLogin) {
        if( [WKSDK shared].options.connectInfoCallback) {
            [WKSDK shared].options.connectInfo =  [WKSDK shared].options.connectInfoCallback();
        }else {
            NSLog(@"没有获取到连接信息，请调用[[WKSDK shared] connectionManager] setConnectInfoCallback设置连接回调");
            return;
        }
        
    }
    
    if(![WKSDK shared].options.hasLogin) {
        NSLog(@"没有设置连接信息！");
        return;
    }
    if([[WKDB sharedDB] needSwitchDB:[WKSDK shared].options.connectInfo.uid]) {
        // 切换数据库
        [[WKDB sharedDB] switchDB:[WKSDK shared].options.connectInfo.uid];
    }
    
    // 连接到IM服务器
    [self onlyConnect];
   
}


-(void) onlyConnect {
    @synchronized (self.ssocket) {
         if(self.connectStatusInner == WKConnected ||  self.connectStatusInner == WKConnecting) {
              if([WKSDK shared].isDebug) {
                  NSLog(@"已建立连接或在连接中，不再执行连接！");
              }
              return;
          }
          
           // 拉取离线消息
          [self changeConnectStatus:WKPullingOffline];
        
           self.pullOfflineFinished = false; // 还没有拉取离线
          // 状态变为：连接中...
          [self changeConnectStatus:WKConnecting];
          
        if(self.ssocket) {
            GCDAsyncSocket *oldSocket = self.ssocket;
            oldSocket.delegate = nil;
            self.ssocket = nil;
            // 在 socket 自己的队列上断开并释放，避免非 socketQueue 上 dealloc 导致递归锁崩溃
            dispatch_async(oldSocket.delegateQueue ?: dispatch_get_main_queue(), ^{
                [oldSocket disconnect];
            });
          }
        // 同样清理掉旧的 WSS 连接，避免重连时叠两条 socket
        [self teardownWS];
          // 循环去拿连接地址，直到拿到地址
          [self loopGetAddrToConnect];
        
    }
}

-(void) loopGetAddrToConnect {
    if(![WKSDK shared].options.hasLogin) {
        return;
    }
    if(self.forceDisconnect) {
         [self changeConnectStatus:WKDisconnected];
        return;
    }
    // 开始建立socket连接
    if(self.getConnectAddr) {
        __weak typeof(self) weakSelf = self;
        self.getConnectAddr(^(NSString * _Nonnull addr) {
            if(!addr || [addr isEqualToString:@""]) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [weakSelf loopGetAddrToConnect];
                });
                return;
            }
            [weakSelf dispatchConnectWithAddr:addr];
        });
    }else {
        [self connectSocket:[WKSDK shared].options.host port:[WKSDK shared].options.port];
    }
}

// 根据地址协议头 + useWSS 开关决定走 WS 还是 TCP。
//   - useWSS=YES 且 addr 为 ws/wss URL → WSS（NSURLSessionWebSocketTask）
//   - 其它情况（addr 是 host:port，或 useWSS=NO）→ TCP（GCDAsyncSocket）
//     · useWSS=NO 时，若 addr 仍是 ws/wss URL，会取出 host[:port] 退化成 TCP，
//       便于灰度回退而无需上层切换 addr 来源。
-(void) dispatchConnectWithAddr:(NSString *)addr {
    NSString *trimmed = [addr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL looksLikeWSURL = [trimmed hasPrefix:@"ws://"] || [trimmed hasPrefix:@"wss://"];

    if (self.useWSS && looksLikeWSURL) {
        [self connectWebSocketWithURL:trimmed];
        return;
    }

    NSString *host = nil;
    NSInteger port = 0;
    if (looksLikeWSURL) {
        // useWSS=NO 且收到的是 ws/wss URL，强行降级到 TCP：取 host + port（默认 80/443）。
        NSURL *url = [NSURL URLWithString:trimmed];
        host = url.host;
        if (url.port) {
            port = url.port.integerValue;
        } else {
            port = [trimmed hasPrefix:@"wss://"] ? 443 : 80;
        }
    } else {
        // host:port
        NSArray *addrs = [trimmed componentsSeparatedByString:@":"];
        if (addrs.count >= 2) {
            host = addrs[0];
            port = [addrs[1] integerValue];
        }
    }
    if (host.length > 0 && port > 0) {
        [self connectSocket:host port:(uint16_t)port];
    } else {
        NSLog(@"无法解析连接地址: %@", addr);
        [self changeConnectStatus:WKDisconnected];
    }
}

-(void) connectSocket:(NSString*)host port:(uint16_t)port {
    if ([WKSDK shared].isDebug) {
        NSLog(@"开始连接IM服务器(TCP) -> %@:%i",host,port);
    }
    self.connectedViaWS = NO;
    self.ssocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_imsocketQueue];
    NSError *error=nil;
    [self.ssocket connectToHost:host onPort:port error:&error];
    if(error) {
        NSLog(@"连接IM服务器失败-> %@",error);
        // 状态变为：已断开
        [self changeConnectStatus:WKDisconnected];
    }
}

#pragma mark --- WSS (NSURLSessionWebSocketTask)

// 建立 WS/WSS 长连接。WS 帧 payload 直接复用 wkproto 二进制帧，编解码层与 TCP 路径完全一致。
-(void) connectWebSocketWithURL:(NSString *)urlStr {
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url || !url.scheme || !url.host) {
        NSLog(@"WSS 地址解析失败 -> %@", urlStr);
        [self changeConnectStatus:WKDisconnected];
        return;
    }
    if ([WKSDK shared].isDebug) {
        NSLog(@"开始连接IM服务器(WSS) -> %@", urlStr);
    }

    self.connectedViaWS = YES;

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    // 让回调串行投递到 _imsocketQueue，行为与 GCDAsyncSocket 路径一致，
    // tempBufferData 等共享状态无需引入额外锁。
    NSOperationQueue *delegateQueue = [[NSOperationQueue alloc] init];
    delegateQueue.maxConcurrentOperationCount = 1;
    delegateQueue.underlyingQueue = _imsocketQueue;

    self.wsSession = [NSURLSession sessionWithConfiguration:cfg
                                                   delegate:self
                                              delegateQueue:delegateQueue];
    self.wsTask = [self.wsSession webSocketTaskWithURL:url];
    [self.wsTask resume];
    [self receiveLoop];
    // 注意：sendConnectPacket 不在这里调，要等 didOpenWithProtocol: 确认 WS Upgrade 完成后再发，
    // 避免 wkproto Connect 帧被丢进尚未完成握手的连接里。
}

// 拆掉当前 WSS 连接（包括 cancel + invalidate session）。
-(void) teardownWS {
    // 先 cancel、再 nil：cancel 触发的 didClose:/didCompleteWithError: 回调里 `task != self.wsTask`
    // 判断需要在 wsTask 还指向旧 task 的时刻成立才能进入 handleWSDisconnect；否则状态会卡在
    // WKConnected、心跳不停、下次 connect 被早返拒绝。
    NSURLSessionWebSocketTask *oldTask = self.wsTask;
    NSURLSession *oldSession = self.wsSession;
    if (oldTask) {
        @try {
            [oldTask cancelWithCloseCode:NSURLSessionWebSocketCloseCodeGoingAway reason:nil];
        } @catch (__unused NSException *ex) {}
    }
    self.wsTask = nil;
    self.wsSession = nil;
    // 不依赖 cancel 的回调来重置 flag —— teardownWS 可能在 logout / onlyConnect 的同步路径被调用，
    // 回调到达前 connectedViaWS 必须先归位，避免 writeData 仍然走 WS 分支。
    self.connectedViaWS = NO;
    if (oldSession) {
        // finishTasksAndInvalidate 会等待已发出的 sendMessage 完成回调，避免 dealloc 期间 crash
        [oldSession finishTasksAndInvalidate];
    }
}

// receiveMessage 是单次 callback；每收到一条消息就重新挂上一次。
// 这是 NSURLSession 推荐用法，回调由 session 调度，不会在调用栈上累积。
-(void) receiveLoop {
    NSURLSessionWebSocketTask *task = self.wsTask;
    if (!task) return;
    __weak typeof(self) weakSelf = self;
    [task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage * _Nullable msg,
                                                NSError * _Nullable err) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        // 防御：如果此时 task 已经被替换（重连过），不要再继续处理它的消息也不要再挂下一次
        if (task != self.wsTask) {
            return;
        }
        if (err) {
            // 这里只 log，断开/重连交给 didCloseWithCode: / didCompleteWithError: 统一处理，
            // 避免重复触发 backoffReconnect
            if ([WKSDK shared].isDebug) {
                NSLog(@"WSS receive 出错 -> %@", err);
            }
            return;
        }
        if (msg.type == NSURLSessionWebSocketMessageTypeData && msg.data.length > 0) {
            if ([WKSDK shared].isDebug) {
                NSLog(@"WSS 收到 binary -> len=%lu", (unsigned long)msg.data.length);
            }
            [self unpacket:msg.data callback:^(NSArray<NSData *> *frames) {
                NSLog(@"------------WSS 解包消息数量--------> %lu",(unsigned long)frames.count);
                [self handlePacketData:frames];
            }];
        } else if (msg.type == NSURLSessionWebSocketMessageTypeString) {
            // 移动端走 wkproto 二进制，不应收到 text 帧；忽略即可。
            NSLog(@"WSS 收到非预期 text 帧，忽略 -> %@", msg.string);
        }
        // 继续监听下一条
        [self receiveLoop];
    }];
}

#pragma mark --- NSURLSessionWebSocketDelegate

- (void)URLSession:(NSURLSession *)session
     webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask
didOpenWithProtocol:(NSString *)protocol {
    if (webSocketTask != self.wsTask) return; // 旧 task 的回调忽略
    if ([WKSDK shared].isDebug) {
        NSLog(@"WSS Upgrade 完成，发送 Connect 包");
    }
    // WS 握手完成后再发 wkproto Connect，行为对齐 TCP 路径的 didConnectToHost: 时点
    [self sendConnectPacket:[WKSDK shared].options.connectInfo.uid
                      token:[WKSDK shared].options.connectInfo.token];
}

- (void)URLSession:(NSURLSession *)session
     webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask
  didCloseWithCode:(NSURLSessionWebSocketCloseCode)closeCode
            reason:(NSData *)reason {
    if (webSocketTask != self.wsTask) return;
    NSString *reasonStr = reason ? [[NSString alloc] initWithData:reason encoding:NSUTF8StringEncoding] : nil;
    NSLog(@"WSS 收到 close frame -> code=%ld reason=%@", (long)closeCode, reasonStr);
    [self handleWSDisconnectWithError:nil];
}

// 链路异常 / TLS 失败 / 服务器 RST 等都会走这里
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    if (task != self.wsTask) return; // 旧 task 的延迟回调
    if (error) {
        NSLog(@"WSS 连接异常断开 -> %@", error);
    } else if ([WKSDK shared].isDebug) {
        NSLog(@"WSS 连接已关闭");
    }
    [self handleWSDisconnectWithError:error];
}

// 统一的 WSS 断开处理，等价于 TCP 路径的 socketDidDisconnect:withError:
- (void)handleWSDisconnectWithError:(NSError *)err {
    self.tempBufferData = [[NSMutableData alloc] init]; // 清掉缓存
    [self changeConnectStatus:WKDisconnected];
    [self stopHeartbeat];
    // wsTask/Session 在这里就置空，避免后续 receiveLoop / writeData 误用
    self.wsTask = nil;
    NSURLSession *oldSession = self.wsSession;
    self.wsSession = nil;
    // flag 必须在所有断开路径上都 reset，否则下一次 connectSocket: 之前 writeData 可能仍走 WS 分支
    self.connectedViaWS = NO;
    if (oldSession) {
        [oldSession finishTasksAndInvalidate];
    }
    if(!self.forceDisconnect) {
        [self backoffReconnect];
    } else if ([WKSDK shared].isDebug) {
        NSLog(@"WSS 已强制断开,不再重连！");
    }
}



/// 同步会话和离线消息（离线消息目前认为是cmd消息）
/// @param finish 同步完成
-(void) syncConversations:(void(^)(NSError *error)) finish {
    if(![WKSDK shared].options.hasLogin) {
        finish([NSError errorWithDomain:@"未登录" code:0 userInfo:nil]);
        return;
    }
    if(![WKSDK shared].conversationManager.syncConversationProvider) {
        NSLog(@"警告：没有设置会话同步提供者！");
        finish([NSError errorWithDomain:@"警告：没有设置会话同步提供者！" code:404 userInfo:nil]);
        return;
    }
    
    // 同步会话
    long long version = [[WKConversationDB shared] getConversationMaxVersion];
    NSString *syncKey = [[WKConversationDB shared] getConversationSyncKey];
    // [UnreadTrace] sync 入口,锁屏后回前台/网络抖动重连都会走这里;
    // 后面紧跟一批 [UnreadTrace] replaceConversations 就是这次 sync 的覆盖动作.
    NSLog(@"[UnreadTrace] syncConversations enter version=%lld syncKey=%@", version, syncKey ?: @"<nil>");
    [WKSDK shared].conversationManager.syncConversationProvider(version, syncKey, ^(WKSyncConversationWrapModel* _Nullable model, NSError * _Nullable error) {
        if(error) {
            // 如果拉取离线消息发生错误 则休息3秒再拉取
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                [self syncConversations:finish];
            });
            return;
        }
        if(model) {
           
            [[WKSDK shared].conversationManager handleSyncConversation:model];
        }
        if([WKSDK shared].isDebug) {
            NSLog(@"同步会话完成！");
        }
        [self finishedSyncConversation];
        
        finish(nil);
        
        [WKSDK shared].conversationManager.syncConversationAck(0, ^(NSError * _Nonnull error) {
            if(error) {
                NSLog(@"回执同步会话失败！->%@",error);
            }
            
        });
       
        [[WKSDK shared].reminderManager sync]; // 同步会话的提醒项(比如 有人@我 草稿 等等)
        
        [[WKSDK shared].conversationManager syncExtra]; // 同步最近会话扩展
        
         return;
    });
}


// 完成同步会话
-(void) finishedSyncConversation {
    if(self.tempPackets && self.tempPackets.count>0) {
        [self handlePackets:self.tempPackets];
    }
}
// 离线拉取完成
-(void) finishedPullOffline {
    if(self.tempPackets && self.tempPackets.count>0) {
        [self handlePackets:self.tempPackets];
    }
}

// 改变连接状态
-(void) changeConnectStatus:(WKConnectStatus) connectStatus {
    [self.connectStatusLock lock];
    self.connectStatusInner = connectStatus;
    [self.connectStatusLock unlock];
    // 调用状态改变
    [self connectStatusChange];
}

// 断开IM服务器
-(void) disconnect:(BOOL) force {
    [self.connectStatusLock lock];
    self.forceDisconnect = force;
    [self.connectStatusLock unlock];

    // 异步断开，避免主线程 dispatch_sync 到 socketQueue 导致死锁
    GCDAsyncSocket *socket = self.ssocket;
    if (socket) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [socket disconnect];
        });
    }
    NSURLSessionWebSocketTask *wsTask = self.wsTask;
    if (wsTask) {
        // 主动 close frame；didCloseWithCode: + didCompleteWithError: 会走 handleWSDisconnect
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [wsTask cancelWithCloseCode:NSURLSessionWebSocketCloseCodeNormalClosure reason:nil];
        });
    }
}

-(void) logout {
    [self.connectStatusLock lock];
    self.forceDisconnect = true;
    [WKSDK shared].options.connectInfo =nil;
    [self.connectStatusLock unlock];

    [[WKSDK shared].channelManager removeChannelAllCache];

    [self.ssocket disconnect];
    [self teardownWS];
}

// 重连
-(void) reconnect {
    if([WKSDK shared].isDebug) {
        NSLog(@"开始重连...");
    }
    // t改变连接状态为断开
    [self changeConnectStatus:WKDisconnected];
    // 这里不能调用断开，调用断开会走重连然后onlyConnect就是进行连接，会建立两个连接从而进行互相踢
//    [self.ssocket disconnect];
    [self onlyConnect];
}
// 重连（支持退避算法）
-(void) backoffReconnect {
    if(self.isBackoffReconnect) {
        return;
    }
    self.isBackoffReconnect = true;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 获取下次重连时间（单位秒）
        long backoffTime = [weakSelf.reconnectBackoff backoff:weakSelf.reconnectCount];
        if([WKSDK shared].isDebug) {
            NSLog(@"%lu秒后进行重连.",backoffTime);
        }
         weakSelf.reconnectCount++;
        [NSThread sleepForTimeInterval:backoffTime];
        weakSelf.isBackoffReconnect = false;
        // 重连
        [weakSelf reconnect];
        
       
    });
}

#pragma mark ---  GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    [sock readDataWithTimeout:-1 tag:0];
    [self sendConnectPacket:[WKSDK shared].options.connectInfo.uid token:[WKSDK shared].options.connectInfo.token];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    [sock readDataWithTimeout:-1 tag:0];
    
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                                                                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length {
    
    NSLog(@"read has timed out...");
    return 0.0;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    NSLog(@"IM连接已断开 -> %@",err);
     self.tempBufferData = [[NSMutableData alloc] init]; // 清楚缓存数据
    // 状态变为：已断开
    [self changeConnectStatus:WKDisconnected];
    // 断开后停止心跳
    [self stopHeartbeat];
    if(!self.forceDisconnect) { // 如果不是强制断开，则开启g退避算法重连
        [self backoffReconnect];
    }else {
        if ([WKSDK shared].isDebug) {
            NSLog(@"已强制断开,不再重连！");
        }
    }
   
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    NSLog(@"didReadPartialDataOfLength--->%lu",(unsigned long)partialLength);
}


//socket接受消息
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    
     if ([WKSDK shared].isDebug) {
        NSLog(@"读取到消息-> %@",data);
     }
    // 解包
    [self unpacket:data callback:^(NSArray<NSData *> *data) {
        NSLog(@"------------解包消息数量--------> %lu",(unsigned long)data.count);
        [self handlePacketData:data];
    }];
    
    [sock readDataWithTimeout:-1 tag:0];
}

// 发送连接包
-(void) sendConnectPacket:(NSString*)uid token:(NSString*)token{

    [[WKSecurityManager shared] generateDHPair];

    WKSDK.shared.options.protoVersion = WKDefaultProtoVersion;

    WKConnectPacket *connectPacket = [WKConnectPacket new];
    connectPacket.clientKey = [[WKSecurityManager shared] getDHPubKey];
    connectPacket.version = [WKSDK shared].options.protoVersion;
    connectPacket.deviceFlag = 3;  // 修复：3=iOS（与登录API的flag保持一致）
    connectPacket.deviceId = [self deviceUUID:uid];
    connectPacket.clientTimestamp = [[NSDate date] timeIntervalSince1970]*1000;
    connectPacket.uid = uid;
    connectPacket.token = token;

    [self sendPacket:connectPacket];
}

- (NSString *)deviceUUID:(NSString*) uid {
    if(!_deviceUUID) {
        if(uid && ![uid isEqualToString:@""]) {
            NSString *key = [NSString stringWithFormat:@"deviceUUIDv2:%@",uid];
            NSString *deviceUUID = [[NSUserDefaults standardUserDefaults] objectForKey:key];
            if(deviceUUID) {
                _deviceUUID = deviceUUID;
            }else {
                NSString *uuid = [NSString stringWithFormat:@"%@ios",[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]];
                [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:key];
                [[NSUserDefaults standardUserDefaults]  synchronize];
                _deviceUUID = uuid;
            }
        }
       
    }
    return _deviceUUID;
}

// 发送ping
-(void) sendPing{
     [self sendPacket:[WKPingPacket new]];
}

// 发送包
-(void) sendPacket:(WKPacket*)packet{
    NSData *data = [[WKSDK shared].coder encode:packet];
    [self writeData:data];
}

-(void) writeData:(NSData*) data {
    // 一次性 snapshot，避免在断连重连窗口内 connectedViaWS / wsTask 多次读取出现 race
    // 例：第一次读 connectedViaWS=YES，第二次读 wsTask 已被 teardownWS 置 nil →
    // 数据静默落空 socket，无 error 上报。
    BOOL viaWS = self.connectedViaWS;
    NSURLSessionWebSocketTask *task = self.wsTask;
    if (viaWS) {
        if (!task) {
            // 处于 WS 断连窗口：不再回退到 self.ssocket（TCP 已被 connectWebSocketWithURL 取代），
            // 显式 log 让上层 / 重连逻辑感知，避免静默丢数据
            NSLog(@"WSS 发送失败 -> wsTask is nil during WS disconnect window, drop %lu bytes",
                  (unsigned long)data.length);
            return;
        }
        // WSS 写入：单帧 = 单次 sendMessage，wkproto 二进制原样作为 WS binary payload
        NSURLSessionWebSocketMessage *m =
            [[NSURLSessionWebSocketMessage alloc] initWithData:data];
        [task sendMessage:m completionHandler:^(NSError * _Nullable e) {
            if (e) {
                // 不在这里直接 backoffReconnect — didCompleteWithError: 会兜底触发，避免重复
                NSLog(@"WSS 发送失败 -> %@", e);
            }
        }];
        return;
    }
    [self.ssocket writeData:data withTimeout:1 tag:0];
}

- (NSLock *)delegateLock {
    if (_delegateLock == nil) {
        _delegateLock = [[NSLock alloc] init];
    }
    return _delegateLock;
}

-(void) addDelegate:(id<WKConnectionManagerDelegate>) delegate{
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates addObject:delegate];
    [self.delegateLock unlock];
}
- (void)removeDelegate:(id<WKConnectionManagerDelegate>) delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates removeObject:delegate];
    [self.delegateLock unlock];
}

// 连接状态发生改变
-(void) connectStatusChange {
    if(self.connectStatusInner == WKConnected) {
        [[WKRetryManager shared] start];
        [WKMessageQueueManager.shared start];
    }else {
        [[WKRetryManager shared] stop];
        [[WKMessageQueueManager shared] stop];
    }
    if(self.onConnectStatusChange) {
        self.onConnectStatusChange(self.connectStatusInner);
    }
    [self callConnectStatusDelegate];
}
#pragma mark --- call delegate
- (void)callConnectStatusDelegate {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(onConnectStatus:reasonCode:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate onConnectStatus:self.connectStatusInner reasonCode:self.reasonCodeInner];
                });
            }else {
                 [delegate onConnectStatus:self.connectStatusInner reasonCode:self.reasonCodeInner];
            }
        }
    }
}
- (void)callKickDelegate:(WKDisconnectPacket*)disconnectPacket {
    [self callKickDelegate:disconnectPacket.reasonCode reason:disconnectPacket.reason];
}

- (void)callKickDelegate:(uint8_t)reasonCode reason:(NSString*)reason {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(onKick:reason:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate onKick:reasonCode reason:reason];
                });
            }else {
                [delegate onKick:reasonCode reason:reason];
            }
        }
    }
}


-(void) unpacket:(NSData*)packetData  callback:(void(^) (NSArray<NSData*> *data))callback{
    [self.tempBufferDataLock lock];
    @try {
        [self.tempBufferData appendData:packetData];
        unsigned long lenBefore,lenAfter;
        NSMutableArray<NSData*> *dataList = [[NSMutableArray alloc] init];
        
        do {
            lenBefore = self.tempBufferData.length;
            self.tempBufferData = [self unpackOne:self.tempBufferData callback:^(NSData *data) {
                [dataList addObject:data];
            }];
            lenAfter = self.tempBufferData.length;
            if(lenAfter>0) {
                NSLog(@"有剩余未被解析的包->%lu",lenAfter);
            }
        } while (lenBefore != lenAfter && lenAfter >= 1);
        if (dataList.count > 0) {
            callback(dataList);
        }
    } @catch (NSException *exception) {
        NSLog(@"-------- 解包异常 -> %@",exception);
        [self backoffReconnect];
        
    } @finally {
         [self.tempBufferDataLock unlock];
    }
   
}

-(NSMutableData*) unpackOne:(NSMutableData*)packData callback:(void(^) (NSData *data))callback {
    return [self unpackOneLM:packData callback:callback];
}

// 解包
-(NSMutableData*) unpackOneLM:(NSMutableData*)packData callback:(void(^) (NSData *data))callback {
    uint8_t packetType;
    [WKDataRead numberHNMemcpy:&packetType src:[[packData subdataWithRange:NSMakeRange(0, 1)] bytes] count:1];
    packetType = packetType>>4;
    if(packetType == WK_PONG) {
        callback([packData subdataWithRange:NSMakeRange(0, 1)]);
        return [[NSMutableData alloc] initWithData:[packData subdataWithRange:NSMakeRange(1, packData.length-1)]];
    }
    
    NSUInteger length = packData.length;
   int fixedHeaderLength = 1;
    int pos = fixedHeaderLength;
    int digit;
    int remLength = 0;
    int multiplier = 1;
    bool hasLength = false; // 是否还有长度数据没读完
    bool remLengthFull = true; // 剩余长度的字节是否完整
    do {
        if (pos > length - 1) {
            // 这种情况出现了分包，并且分包的位置是长度部分的某个位置。
            remLengthFull = false;
            break;
        }
        [packData getBytes:&digit range:NSMakeRange(pos++, 1)];
        remLength += ((digit & 127) * multiplier);
        multiplier *= 128;
        hasLength = (digit & 0x80) != 0;
    } while (hasLength);
    
    if (!remLengthFull) {
        NSLog(@"包长度没有读出来");
        return packData;
    }
    int remLengthLength = pos - fixedHeaderLength; // 剩余长度的长度
    if (fixedHeaderLength + remLengthLength + remLength > length) {
        // 固定头的长度 + 剩余长度的长度 + 剩余长度 如果大于 总长度说明分包了
        NSLog(@"分包了...剩余长度：%d  当前长度：%lu",remLength,(unsigned long)length);
        return packData;
    }else {
        if (fixedHeaderLength + remLengthLength + remLength == length) {
            // 刚好一个包
            NSLog(@"刚好一个包");
            callback(packData);
            return [[NSMutableData alloc] init];
        } else {
            // 粘包  大于1个包
            int packetLength = fixedHeaderLength + remLengthLength + remLength;
           
            NSData *fullPackData = [packData subdataWithRange:NSMakeRange(0, packetLength)];
           
            callback(fullPackData);
            NSData *remPackData = [packData subdataWithRange:NSMakeRange(packetLength, length-packetLength)];
            
            NSLog(@"粘包  大于1个包，包长度:%i-%lu-%lu-%lu",packetLength,fullPackData.length,remPackData.length,length);
            
            return [[NSMutableData alloc] initWithData:remPackData];
        }
    }
}

// 处理包数据
-(void) handlePacketData:(NSArray<NSData*>*)dataList {
    if(!dataList || dataList.count<=0) {
        return;
    }
    self.lastMsgTimeInterval = [[NSDate date] timeIntervalSince1970];
    NSMutableArray<WKPacket*> *packets = [NSMutableArray array];
    NSLog(@"包数量--->%lu",dataList.count);
    for (NSData *data in dataList) {
       WKPacket *packet =  [[WKSDK shared].coder decode:data];
        if(!packet) {
            NSLog(@"未解码到数据！->%@",data);
            continue;
        }
         NSLog(@"解码到包 -> %@",packet);
        if([packet header].packetType == WK_CONNACK) {
            WKConnackPacket *connackPacket = (WKConnackPacket*)packet;
            self.reasonCodeInner = connackPacket.reasonCode;
            if(connackPacket.reasonCode == WK_REASON_SUCCESS) {
                if([WKSDK shared].isDebug) {
                    NSLog(@"连接成功！-> %@",packet);
                }
                // 处理连接成功的逻辑
                [self handleConnected:connackPacket];
            }else {
                if([WKSDK shared].isDebug) {
                    NSLog(@"连接失败！-> %@",packet);
                }
                if(connackPacket.reasonCode == WK_REASON_AUTHFAIL) {
                    [self disconnect:YES];
                    [self callKickDelegate:connackPacket.reasonCode reason:@"认证失败！"];
                }else{
                    [self disconnect:NO];
                }
            }
            return;
        } else if([packet header].packetType == WK_DISCONNECT) { // 断开连接
            if([WKSDK shared].isDebug) {
                NSLog(@"收到断开连接的包！客户端将断开！");
            }
            WKDisconnectPacket *disconnectPacket = (WKDisconnectPacket*)packet;
            self.reasonCodeInner = disconnectPacket.reasonCode;
            [self disconnect:YES];
            [self callKickDelegate:disconnectPacket];
        } else {
            [packets addObject:packet];
        }
    }
    if(!self.pullOfflineFinished) { // 如果拉取消息未完成，则在线消息都存临时数组里
        [self.tempPackets addObjectsFromArray:packets];
        return;
    }
   
    if(self.tempPackets.count>0) {
        NSLog(@"有临时包,数量:%lu",(unsigned long)self.tempPackets.count);
        for (NSInteger i=0; i<self.tempPackets.count; i++) {
            WKPacket *tempPacket = self.tempPackets[i];
            [packets insertObject:tempPacket atIndex:i];
        }
        [self.tempPackets removeAllObjects];
    }
    [self handlePackets:packets];
   
}

-(void) handlePackets:(NSArray<WKPacket*>*)packets {
    NSDictionary<NSNumber*,NSArray<WKPacket*>*>* packetDict = [self packetGroup:packets];
    for (NSNumber *packetTypeNum in packetDict.allKeys) {
        NSArray<WKPacket*> *packetList = [packetDict objectForKey:packetTypeNum];
        switch (packetTypeNum.unsignedIntegerValue) {
            case WK_SENDACK:
                [[WKSDK shared].chatManager handleSendack:(NSArray<WKSendackPacket*> *)packetList];
                break;
            case WK_RECV:
                [[WKSDK shared].chatManager handleRecv:(NSArray<WKRecvPacket*> *)packetList];
                break;
            case  WK_PONG:
                break;
            default:
                NSLog(@"未知的数据包-->[%d]",packetTypeNum.unsignedIntValue);
                break;
        }
    }
}

-( WKConnectStatus) connectStatus {
    return self.connectStatusInner;
}

// 处理连接成功的逻辑
-(void) handleConnected:(WKConnackPacket*)connackPacket{

    BOOL aesOK = [[WKSecurityManager shared] generateAesKey:connackPacket.serverKey salt:connackPacket.salt];
    if (!aesOK) {
        // server 公钥非法 / 本地 DH key 缺失 → 不能继续, 否则后续加密路径会崩.
        // 断开走重连流程, 让握手重新协商.
        NSLog(@"[Connection] handshake aborted: invalid DH material from server");
        [self disconnect:YES];
        return;
    }

    // 重连次数归0
    self.reconnectCount = 0;
    
    // 开始心跳
    [self startHeartbeat];
    
    // 开始拉取离线消息
     [self changeConnectStatus:WKPullingOffline];
    
    __weak typeof(self) weakSelf = self;
    [self syncConversations:^(NSError *error){
        weakSelf.pullOfflineFinished = true; // 离线拉取完成
        if(!error) {
            // 改变状态为已连接
            [weakSelf changeConnectStatus:WKConnected];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [[WKSDK shared].cmdManager pullCMDMessages]; // 开始拉取cmd消息
                // mark-read 上报队列重试: 上次离线时积累的本地已读现在补传给 server.
                [[WKUnreadAckRunner shared] kick];
            });
        }else {
            if(error.code == 404) { // 没有syncConversationProvider
                // 改变状态为已连接
                [weakSelf changeConnectStatus:WKConnected];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    [[WKSDK shared].cmdManager pullCMDMessages]; // 开始拉取cmd消息
                    [[WKUnreadAckRunner shared] kick];
                });
            }else {
                NSLog(@"同步会话失败！-> %@",error);
            }

        }
    }];
    
}

// 包分组
-(NSDictionary<NSNumber*,NSArray<WKPacket*>*>*) packetGroup:(NSArray<WKPacket*>*)packets {
    if(!packets) {
        return [NSMutableDictionary dictionary];
    }
    NSMutableDictionary *packetDict = [NSMutableDictionary dictionary];
    for (WKPacket *packet in packets) {
       NSMutableArray<WKPacket*> *gpackets = packetDict[ @(packet.header.packetType)];
        if(!gpackets) {
            gpackets = [NSMutableArray array];
        }
        [gpackets addObject:packet];
        packetDict[ @(packet.header.packetType)] = gpackets;
    }
    return packetDict;
}


// 开始心跳
-(void) startHeartbeat {
    if(self.heartTimer){
        [self.heartTimer invalidate];
    }
    // 定时器必须在主线程才能执行
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.heartTimer = [NSTimer scheduledTimerWithTimeInterval:[WKSDK shared].options.heartbeatInterval
                                                           target:weakSelf
                                                         selector:@selector(checkAndSendHeartbeat)
                                                         userInfo:nil
                                                          repeats:YES];
    });
}

// 停止心跳
-(void) stopHeartbeat {
    [self.heartTimer invalidate];
    if([WKSDK shared].isDebug) {
        NSLog(@"心跳停止！");
    }
}

-(void) checkAndSendHeartbeat {
    //如果心跳停止时间大于心跳频率+1 那么认为心跳停止 心跳停止 进行重新连接
    NSTimeInterval nowTime = [[NSDate date] timeIntervalSince1970];
    if (nowTime - self.lastMsgTimeInterval > [WKSDK shared].options.heartbeatInterval+1) {
        [self backoffReconnect];
        return;
    }
     [self sendPing];
}

- (void)wakeup:(NSTimeInterval)timeout complete:(void (^)(NSError * __nullable))complete {
    if(self.connectStatus == WKConnected) { //  如果已经连接则什么都不做直接回调
        if(complete) {
            complete(nil);
        }
        return;
    }
    
   __block BOOL hasComplete = false;
    self.onConnectStatusChange = ^(WKConnectStatus status) {
        if(status == WKConnected) {
            hasComplete = true;
            if(complete) {
                complete(nil);
            }
            return;
        }
    };
    // 连接IM
    [self connect];
    
    // 指定超时的时间内如果没有执行callback，就执行超时回调
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.onConnectStatusChange = nil;
        if(!hasComplete) {
            if(complete) {
                complete([NSError errorWithDomain:@"唤醒超时" code:408 userInfo:nil]);
            }
        }
    });
}


@end
