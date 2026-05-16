// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKSpaceConversationCache.m
//  WuKongBase
//

#import "WKSpaceConversationCache.h"

// 仅缓存 server 下发的 space_last_message（按当前空间过滤的"最后一条消息"）。
// 历史上还缓存过 space_unread 客户端值，但 server 聚合窗口失真 + 重启 cache 丢失导致红点丢失，
// 已改为对齐 Android：unread 直接信任 SDK DB，UI 层按 lastMessage.space_id 过滤跨空间污染。
@interface WKSpaceConversationCache ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, WKMessage *> *lastMessageMap;
@end

@implementation WKSpaceConversationCache

+ (instancetype)shared {
    static WKSpaceConversationCache *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WKSpaceConversationCache alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lastMessageMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSString *)keyForChannel:(WKChannel *)channel {
    return [NSString stringWithFormat:@"%@-%ld", channel.channelId, (long)channel.channelType];
}

- (void)setSpaceLastMessage:(WKMessage *)lastMessage forChannel:(WKChannel *)channel {
    if (!lastMessage) return;
    NSString *key = [self keyForChannel:channel];
    @synchronized (self) {
        self.lastMessageMap[key] = lastMessage;
    }
}

- (WKMessage *)spaceLastMessageForChannel:(WKChannel *)channel {
    NSString *key = [self keyForChannel:channel];
    @synchronized (self) {
        return self.lastMessageMap[key];
    }
}

- (void)clearAll {
    @synchronized (self) {
        [self.lastMessageMap removeAllObjects];
    }
}

@end
