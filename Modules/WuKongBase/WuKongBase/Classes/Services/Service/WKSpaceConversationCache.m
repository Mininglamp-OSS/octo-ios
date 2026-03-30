//
//  WKSpaceConversationCache.m
//  WuKongBase
//

#import "WKSpaceConversationCache.h"

@interface WKSpaceConversationCache ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *unreadMap;
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
        _unreadMap = [NSMutableDictionary dictionary];
        _lastMessageMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSString *)keyForChannel:(WKChannel *)channel {
    return [NSString stringWithFormat:@"%@-%ld", channel.channelId, (long)channel.channelType];
}

- (void)setSpaceUnread:(NSNumber *)unread spaceLastMessage:(WKMessage *)lastMessage forChannel:(WKChannel *)channel {
    NSString *key = [self keyForChannel:channel];
    @synchronized (self) {
        if (unread) {
            self.unreadMap[key] = unread;
        }
        if (lastMessage) {
            self.lastMessageMap[key] = lastMessage;
        }
    }
}

- (NSNumber *)spaceUnreadForChannel:(WKChannel *)channel {
    NSString *key = [self keyForChannel:channel];
    @synchronized (self) {
        return self.unreadMap[key];
    }
}

- (WKMessage *)spaceLastMessageForChannel:(WKChannel *)channel {
    NSString *key = [self keyForChannel:channel];
    @synchronized (self) {
        return self.lastMessageMap[key];
    }
}

- (void)incrementSpaceUnread:(NSInteger)delta forChannel:(WKChannel *)channel {
    if (delta <= 0) return;
    NSString *key = [self keyForChannel:channel];
    @synchronized (self) {
        NSNumber *current = self.unreadMap[key];
        if (current != nil) {
            self.unreadMap[key] = @([current integerValue] + delta);
        }
    }
}

- (void)clearAll {
    @synchronized (self) {
        [self.unreadMap removeAllObjects];
        [self.lastMessageMap removeAllObjects];
    }
}

@end
