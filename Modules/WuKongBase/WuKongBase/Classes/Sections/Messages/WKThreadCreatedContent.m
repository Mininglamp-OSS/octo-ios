//
//  WKThreadCreatedContent.m
//  WuKongBase
//

#import "WKThreadCreatedContent.h"
#import "WKConstant.h"

static NSMutableSet<NSString *> *_sourceMessageIdSet = nil;
static NSMutableDictionary<NSString *, NSNumber *> *_messageCountCache = nil;
static NSMutableDictionary<NSString *, WKThreadCreatedContent *> *_sourceMessageThreadMap = nil;

NSString * const WKThreadMessageCountUpdatedNotification = @"WKThreadMessageCountUpdated";

// R8 fix (yujiawei P1-2): _sourceMessageIdSet / _sourceMessageThreadMap 跨线程读写的
// 共用锁。decodeWithJSON 跑 socket 解码线程, markThreadClosedForSourceMessageId 跑主线程,
// 这两条 (write off-main + write main) 是写写冲突, 比 pre-existing 的读写冲突更危险。
// 新加的 markClosed 入口让冲突类型升级, 必须收。所有访问点统一过这把锁。
static NSObject *kThreadStaticsLock = nil;

@implementation WKThreadCreatedContent

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kThreadStaticsLock = [NSObject new];
    });
}

+ (NSMutableSet<NSString *> *)sourceMessageIdSet {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sourceMessageIdSet = [NSMutableSet set];
    });
    return _sourceMessageIdSet;
}

+ (NSMutableDictionary<NSString *, NSNumber *> *)messageCountCache {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _messageCountCache = [NSMutableDictionary dictionary];
    });
    return _messageCountCache;
}

+ (NSMutableDictionary<NSString *, WKThreadCreatedContent *> *)sourceMessageThreadMap {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sourceMessageThreadMap = [NSMutableDictionary dictionary];
    });
    return _sourceMessageThreadMap;
}

+ (void)markThreadClosedForSourceMessageId:(NSString *)sourceMessageId {
    if (sourceMessageId.length == 0) return;
    @synchronized (kThreadStaticsLock) {
        [[self sourceMessageIdSet] removeObject:sourceMessageId];
        [[self sourceMessageThreadMap] removeObjectForKey:sourceMessageId];
    }
}

+ (NSNumber *)contentType {
    return @(WK_THREAD_CREATED);
}

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    self.threadName       = contentDic[@"thread_name"] ?: @"";
    self.threadShortId    = contentDic[@"short_id"] ?: @"";
    self.threadChannelId  = contentDic[@"channel_id"] ?: @"";
    self.threadChannelType = [contentDic[@"channel_type"] unsignedCharValue];
    self.creatorUid       = contentDic[@"from_uid"] ?: @"";
    self.creatorName      = contentDic[@"from_name"] ?: @"";
    self.messageCount     = [contentDic[@"message_count"] integerValue];
    if (contentDic[@"source_message_id"]) {
        long long srcId = [contentDic[@"source_message_id"] longLongValue];
        if (srcId > 0) {
            self.sourceMessageId = [NSString stringWithFormat:@"%lld", srcId];
            @synchronized (kThreadStaticsLock) {
                [[WKThreadCreatedContent sourceMessageIdSet] addObject:self.sourceMessageId];
                [[WKThreadCreatedContent sourceMessageThreadMap] setObject:self forKey:self.sourceMessageId];
            }
        }
    }
}

- (NSDictionary *)encodeWithJSON {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"thread_name"] = self.threadName ?: @"";
    dict[@"short_id"] = self.threadShortId ?: @"";
    dict[@"channel_id"] = self.threadChannelId ?: @"";
    dict[@"channel_type"] = @(self.threadChannelType);
    dict[@"from_uid"] = self.creatorUid ?: @"";
    dict[@"from_name"] = self.creatorName ?: @"";
    dict[@"message_count"] = @(self.messageCount);
    if (self.sourceMessageId) {
        dict[@"source_message_id"] = @([self.sourceMessageId longLongValue]);
    }
    return dict;
}

- (NSString *)conversationDigest {
    return [NSString stringWithFormat:@"%@ 发起了子区「%@」", self.creatorName, self.threadName];
}

- (NSString *)searchableWord {
    return self.threadName;
}

@end
