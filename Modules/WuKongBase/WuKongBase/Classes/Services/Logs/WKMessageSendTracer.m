//
//  Copyright 2026 MININGLAMP
//  SPDX-License-Identifier: Apache-2.0
//
//  调试用途，上线前可关闭。回退路径：删除 WKConversationContextImpl 中的 traceSendBegin 调用即可，
//  Tracer 不会再被引用，单例不会创建，也就不会注册 SDK delegate。
//

#import "WKMessageSendTracer.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

@interface WKMessageSendTracer () <WKChatManagerDelegate, WKConnectionManagerDelegate>
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *inFlight; // clientMsgNo -> { startMs, channelDesc, contentType }
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, assign) WKConnectStatus lastConnectStatus;
@end

@implementation WKMessageSendTracer

+ (instancetype)shared {
    static WKMessageSendTracer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WKMessageSendTracer alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _inFlight = [NSMutableDictionary dictionary];
        _queue = dispatch_queue_create("com.octo.sendtracer", DISPATCH_QUEUE_SERIAL);
        _lastConnectStatus = (WKConnectStatus)NSUIntegerMax;
        [[WKSDK shared].chatManager addDelegate:self];
        [[WKSDK shared].connectionManager addDelegate:self];
    }
    return self;
}

#pragma mark - Public

- (void)traceSendBegin:(WKMessage *)message channel:(WKChannel *)channel extra:(NSString *)extra {
    if (!message || message.clientMsgNo.length == 0) {
        return;
    }
    NSString *clientMsgNo = message.clientMsgNo;
    NSInteger startMs = (NSInteger)([[NSDate date] timeIntervalSince1970] * 1000);
    NSString *channelDesc = [self descChannel:channel];
    NSInteger contentType = message.contentType;
    NSString *tag = extra.length > 0 ? extra : @"send";
    WKConnectStatus connStatus = [WKConnectionManager sharedManager].connectStatus;

    dispatch_async(self.queue, ^{
        self.inFlight[clientMsgNo] = @{
            @"startMs": @(startMs),
            @"channel": channelDesc ?: @"-",
            @"contentType": @(contentType),
            @"tag": tag,
        };
        NSLog(@"[SendTrace] begin tag=%@ client_msg_no=%@ channel=%@ content_type=%ld status=%lu conn=%@ ts=%ld",
              tag, clientMsgNo, channelDesc, (long)contentType,
              (unsigned long)message.status, [self descConnStatus:connStatus], (long)startMs);
    });
}

#pragma mark - WKChatManagerDelegate

- (void)onMessageUpdate:(WKMessage *)message left:(NSInteger)left {
    [self logUpdate:message];
}

- (void)onMessageUpdate:(WKMessage *)message left:(NSInteger)left total:(NSInteger)total {
    [self logUpdate:message];
}

- (void)onSendack:(WKSendackPacket *)sendackPacket left:(NSInteger)left {
    if (!sendackPacket) {
        return;
    }
    uint32_t clientSeq = sendackPacket.clientSeq;
    uint64_t messageId = sendackPacket.messageId;
    uint32_t messageSeq = sendackPacket.messageSeq;
    uint8_t reasonCode = sendackPacket.reasonCode;
    NSInteger ackMs = (NSInteger)([[NSDate date] timeIntervalSince1970] * 1000);

    dispatch_async(self.queue, ^{
        NSLog(@"[SendTrace] sendack client_seq=%u msg_id=%llu msg_seq=%u reason=%u(%@) ts=%ld",
              clientSeq, messageId, messageSeq, reasonCode, [self descReason:reasonCode], (long)ackMs);
    });
}

#pragma mark - WKConnectionManagerDelegate

- (void)onConnectStatus:(WKConnectStatus)status reasonCode:(WKReason)reasonCode {
    WKConnectStatus prev = self.lastConnectStatus;
    self.lastConnectStatus = status;
    NSInteger ts = (NSInteger)([[NSDate date] timeIntervalSince1970] * 1000);
    dispatch_async(self.queue, ^{
        NSLog(@"[SendTrace] conn %@->%@ reason=%u(%@) ts=%ld inflight=%lu",
              [self descConnStatus:prev], [self descConnStatus:status],
              reasonCode, [self descReason:reasonCode], (long)ts,
              (unsigned long)self.inFlight.count);
    });
}

- (void)onKick:(uint8_t)reasonCode reason:(NSString *)reason {
    NSInteger ts = (NSInteger)([[NSDate date] timeIntervalSince1970] * 1000);
    NSString *r = reason ?: @"-";
    dispatch_async(self.queue, ^{
        NSLog(@"[SendTrace] kick reason_code=%u reason=%@ ts=%ld inflight=%lu",
              reasonCode, r, (long)ts, (unsigned long)self.inFlight.count);
    });
}

#pragma mark - Helpers

- (void)logUpdate:(WKMessage *)message {
    if (!message || message.clientMsgNo.length == 0) {
        return;
    }
    NSString *clientMsgNo = message.clientMsgNo;
    WKMessageStatus status = message.status;
    WKReason reason = message.reasonCode;
    uint64_t msgId = message.messageId;
    uint32_t msgSeq = message.messageSeq;
    NSInteger nowMs = (NSInteger)([[NSDate date] timeIntervalSince1970] * 1000);

    dispatch_async(self.queue, ^{
        NSDictionary *meta = self.inFlight[clientMsgNo];
        if (!meta) {
            // 非聊天详情 trace 过的消息（例如系统消息、其他入口），忽略以减噪
            return;
        }
        NSInteger startMs = [meta[@"startMs"] integerValue];
        NSInteger elapsed = nowMs - startMs;
        NSString *tag = meta[@"tag"] ?: @"send";
        NSString *channel = meta[@"channel"] ?: @"-";
        NSInteger contentType = [meta[@"contentType"] integerValue];

        NSLog(@"[SendTrace] update tag=%@ client_msg_no=%@ channel=%@ content_type=%ld status=%@ reason=%u(%@) msg_id=%llu msg_seq=%u elapsed_ms=%ld",
              tag, clientMsgNo, channel, (long)contentType,
              [self descStatus:status], reason, [self descReason:reason],
              msgId, msgSeq, (long)elapsed);

        if (status == WK_MESSAGE_SUCCESS || status == WK_MESSAGE_FAIL) {
            [self.inFlight removeObjectForKey:clientMsgNo];
        }
    });
}

- (NSString *)descChannel:(WKChannel *)channel {
    if (!channel) return @"-";
    return [NSString stringWithFormat:@"%@/%d", channel.channelId ?: @"-", channel.channelType];
}

- (NSString *)descStatus:(WKMessageStatus)status {
    switch (status) {
        case WK_MESSAGE_WAITSEND: return @"WAITSEND";
        case WK_MESSAGE_SUCCESS:  return @"SUCCESS";
        case WK_MESSAGE_ONLYSAVE: return @"ONLYSAVE";
        case WK_MESSAGE_UPLOADING:return @"UPLOADING";
        case WK_MESSAGE_FAIL:     return @"FAIL";
    }
    return [NSString stringWithFormat:@"UNKNOWN(%lu)", (unsigned long)status];
}

- (NSString *)descConnStatus:(WKConnectStatus)status {
    switch (status) {
        case WKNoConnect:        return @"NoConnect";
        case WKConnecting:       return @"Connecting";
        case WKPullingOffline:   return @"PullingOffline";
        case WKConnected:        return @"Connected";
        case WKDisconnected:     return @"Disconnected";
    }
    return [NSString stringWithFormat:@"UNKNOWN(%lu)", (unsigned long)status];
}

- (NSString *)descReason:(uint8_t)reason {
    switch (reason) {
        case WK_REASON_UNKNOWN:          return @"UNKNOWN";
        case WK_REASON_SUCCESS:          return @"SUCCESS";
        case WK_REASON_AUTHFAIL:         return @"AUTHFAIL";
        case WK_REASON_IN_BLACKLIST:     return @"IN_BLACKLIST";
        case WK_REASON_KICK:             return @"KICK";
        case WK_REASON_NOT_IN_WHITELIST: return @"NOT_IN_WHITELIST";
    }
    return @"OTHER";
}

@end
