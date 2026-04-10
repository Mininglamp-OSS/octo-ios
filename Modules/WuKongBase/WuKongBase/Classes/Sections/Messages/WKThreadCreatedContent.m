//
//  WKThreadCreatedContent.m
//  WuKongBase
//

#import "WKThreadCreatedContent.h"
#import "WKConstant.h"

static NSMutableSet<NSString *> *_sourceMessageIdSet = nil;

@implementation WKThreadCreatedContent

+ (NSMutableSet<NSString *> *)sourceMessageIdSet {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sourceMessageIdSet = [NSMutableSet set];
    });
    return _sourceMessageIdSet;
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
    if (contentDic[@"source_message_id"] && [contentDic[@"source_message_id"] longLongValue] > 0) {
        self.sourceMessageId = [NSString stringWithFormat:@"%@", contentDic[@"source_message_id"]];
        [[WKThreadCreatedContent sourceMessageIdSet] addObject:self.sourceMessageId];
    }
}

- (NSDictionary *)encodeWithJSON {
    return @{
        @"thread_name": self.threadName ?: @"",
        @"short_id": self.threadShortId ?: @"",
        @"channel_id": self.threadChannelId ?: @"",
        @"channel_type": @(self.threadChannelType),
        @"from_name": self.creatorName ?: @"",
    };
}

- (NSString *)conversationDigest {
    return [NSString stringWithFormat:@"%@ 发起了子区「%@」", self.creatorName, self.threadName];
}

- (NSString *)searchableWord {
    return self.threadName;
}

@end
