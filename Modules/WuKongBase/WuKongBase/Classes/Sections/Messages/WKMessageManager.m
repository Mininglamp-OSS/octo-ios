//
//  WKMessageManager.m
//  WuKongBase
//
//  Created by tt on 2020/1/28.
//

#import "WKMessageManager.h"

@implementation WKMessageManager

static WKMessageManager *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKMessageManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(void) deleteMessages:(NSArray<WKMessageModel*>*)messages {
    if(!messages||messages.count == 0) {
        return;
    }
    for (WKMessageModel *messageModel in messages) {
        __weak typeof(messageModel.message) weakMessage = messageModel.message;
        [[WKSDK shared].chatManager deleteMessage:weakMessage];
    }
    if(_delegate && [_delegate respondsToSelector:@selector(messageManager:deleteMessages:)]) {
        [_delegate messageManager:self deleteMessages:messages];
    }
}

- (void)clearMessages:(WKChannel *)channel {
    if(_delegate && [_delegate respondsToSelector:@selector(messageManager:clearMessages:)]) {
        [_delegate messageManager:self clearMessages:channel];
    }
}

-(void) revokeMessage:(WKMessageModel*)message complete:(void(^)(NSError * __nullable error))complete{
    if(_delegate && [_delegate respondsToSelector:@selector(messageManager:revokeMessage:complete:)]) {
        [_delegate messageManager:self revokeMessage:message complete:complete];
    }
}

-(void) conversationSetUnread:(WKChannel*)channel unread:(NSInteger)unread messageSeq:(uint32_t)messageSeq complete:(void(^)(NSError * __nullable error))complete{
       // 清除此频道的未读数
    if(_delegate && [_delegate respondsToSelector:@selector(messageManager:conversationSetUnread:unread:messageSeq:complete:)]) {
        [_delegate messageManager:self conversationSetUnread:channel unread:unread messageSeq:messageSeq complete:complete];
    }
}

- (void)updateMessageVoiceReaded:(WKMessageModel *)message complete:(void (^)(NSError * _Nullable))complete {
    [[WKSDK shared].chatManager updateMessageVoiceReaded:message.message];
    if(_delegate && [_delegate respondsToSelector:@selector(messageManager:updateMessageVoiceReaded:complete:)]) {
        [_delegate messageManager:self updateMessageVoiceReaded:message complete:complete];
    }
}

-(void) collectExpressions:(WKMessageModel*)message {
    if(_delegate && [_delegate respondsToSelector:@selector(messageManager:collectExpressions:)]) {
        [_delegate messageManager:self collectExpressions:message];
    }
}

@end
