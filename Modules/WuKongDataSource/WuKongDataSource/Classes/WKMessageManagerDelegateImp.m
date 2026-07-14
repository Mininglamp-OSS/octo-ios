//
//  WKMessageManagerDelegateImp.m
//  WuKongDataSource
//
//  Created by tt on 2020/1/29.
//

#import "WKMessageManagerDelegateImp.h"
#import "WKGIFContent.h"
#import "WKLottieStickerContent.h"
#import "WKConstant.h"

@implementation WKMessageManagerDelegateImp


/**
 删除消息
 
 @param manager <#manager description#>
 @param messages 消息对象
 */
-(void) messageManager:(WKMessageManager*)manager deleteMessages:(NSArray<WKMessageModel*>*)messages {
    if(!messages || messages.count==0) {
        return;
    }
    NSMutableArray *params = [NSMutableArray array];
    for (WKMessageModel *messageModel in messages) {
        [params addObject:@{
            @"message_id": [NSString stringWithFormat:@"%llu",messageModel.messageId],
            @"channel_id": messageModel.channel.channelId,
            @"channel_type": @(messageModel.channel.channelType),
            @"message_seq":@(messageModel.messageSeq),
        }];
    }
    [[WKAPIClient sharedClient] DELETE:@"message" parameters:params ].catch(^(NSError *error){
        WKLogError(@"删除服务器消息失败！-> %@",error);
    });
}


/**
 清除指定频道的消息
 
 @param manager <#manager description#>
 @param channel 频道
 */
-(void) messageManager:(WKMessageManager*)manager clearMessages:(WKChannel*)channel{
    // BotFather空间隔离：只删除当前空间的消息，不影响其他空间
    NSString *botfatherUID = [WKApp shared].config.botfatherUID;
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(botfatherUID && [channel.channelId isEqualToString:botfatherUID] && currentSpaceId.length > 0) {
        [self clearBotFatherMessagesForSpace:channel spaceId:currentSpaceId];
        return;
    }

    uint32_t messageSeq = [[WKMessageDB shared] getMaxMessageSeq:channel];
    [[WKAPIClient sharedClient] POST:@"message/offset" parameters:@{
        @"channel_id": channel.channelId,
        @"channel_type": @(channel.channelType),
        @"message_seq": @(messageSeq),
    }].then(^{
        [[WKSDK shared].chatManager clearMessages:channel];
    }).catch(^(NSError *error){
        WKLogError(@"删除服务器频道消息失败！-> %@",error);
    });
}

/// BotFather空间隔离版清空消息：仅删除匹配当前space_id的消息
-(void) clearBotFatherMessagesForSpace:(WKChannel*)channel spaceId:(NSString*)spaceId {
    NSMutableArray<WKMessage*> *messagesToDelete = [NSMutableArray array];
    uint32_t cursor = 0;
    BOOL hasMore = YES;

    // 分页遍历所有消息，收集属于当前空间的消息
    while (hasMore) {
        NSArray<WKMessage*> *messages = [[WKMessageDB shared] getMessages:channel startOrderSeq:cursor endOrderSeq:0 limit:200 pullMode:WKPullModeDown];
        if(!messages || messages.count == 0) {
            break;
        }
        for (WKMessage *msg in messages) {
            NSString *msgSpaceId = msg.content.contentDict[@"space_id"];
            if([msgSpaceId isKindOfClass:[NSString class]] && [msgSpaceId isEqualToString:spaceId]) {
                [messagesToDelete addObject:msg];
            }
        }
        WKMessage *oldestMsg = messages.lastObject;
        if(oldestMsg.orderSeq == 0) {
            break;
        }
        cursor = oldestMsg.orderSeq;
        hasMore = messages.count == 200;
    }

    if(messagesToDelete.count == 0) {
        return;
    }

    // 逐条本地软删除
    for (WKMessage *msg in messagesToDelete) {
        [[WKSDK shared].chatManager deleteMessage:msg];
    }

    // 批量通知服务端删除
    NSMutableArray *params = [NSMutableArray array];
    for (WKMessage *msg in messagesToDelete) {
        if(msg.messageId > 0) {
            [params addObject:@{
                @"message_id": [NSString stringWithFormat:@"%llu", msg.messageId],
                @"channel_id": channel.channelId,
                @"channel_type": @(channel.channelType),
                @"message_seq": @(msg.messageSeq),
            }];
        }
    }
    if(params.count > 0) {
        [[WKAPIClient sharedClient] DELETE:@"message" parameters:params].catch(^(NSError *error){
            WKLogError(@"BotFather空间隔离删除消息失败！-> %@", error);
        });
    }
}

/**
 撤回消息
 
 @param message <#message description#>
 */
- (void)messageManager:(WKMessageManager *)manager revokeMessage:(WKMessageModel *)message complete:(void (^__nullable)(NSError * __nullable))complete{
    NSString *messageID = @"";
    if(message.messageId != 0) {
        messageID = [NSString stringWithFormat:@"%llu",message.messageId];
    }else {
        messageID = message.clientMsgNo;
    }

    // 先请求服务端，成功后再执行本地撤回，避免超时后本地假撤回但服务端拒绝
    [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"message/revoke?channel_id=%@&channel_type=%hhu&message_id=%@&client_msg_no=%@",message.channel.channelId,message.channel.channelType,messageID,message.clientMsgNo] parameters:nil].then(^{
        message.message.remoteExtra.revoke = true;
        message.message.remoteExtra.revoker = [WKApp shared].loginInfo.uid;
        [[WKSDK shared].chatManager callMessageUpdateDelegate:message.message];
        if(complete) {
            complete(nil);
        }
    }).catch(^(NSError *error){
        WKLogError(@"撤回消息失败！-> %@",error);
        if(complete) {
            complete(error);
        }
    });
}

- (void)messageManager:(WKMessageManager *)manager conversationSetUnread:(WKChannel *)channel unread:(NSInteger)unread messageSeq:(uint32_t)messageSeq complete:(void (^)(NSError * _Nullable))complete {
    [[WKAPIClient sharedClient] PUT:@"coversation/clearUnread" parameters:@{@"channel_id":channel.channelId?:@"",@"channel_type":@(channel.channelType),@"unread":@(unread),@"message_seq":@(messageSeq)}].then(^{
        if(complete) {
            complete(nil);
        }
    }).catch(^(NSError*error){
        WKLogError(@"清除未读数失败！-> %@",error);
        if(complete) {
            complete(error);
        }
    });
}

- (void)messageManager:(WKMessageManager *)manager updateMessageVoiceReaded:(WKMessageModel *)messageModel complete:(void (^)(NSError * _Nullable))complete {
    [[WKAPIClient sharedClient] PUT:@"message/voicereaded" parameters:@{
        @"message_id": [NSString stringWithFormat:@"%llu",messageModel.messageId],
        @"channel_id": messageModel.channel.channelId,
        @"channel_type": @(messageModel.channel.channelType),
        @"message_seq":@(messageModel.messageSeq),
    }];
}


-(void) messageManager:(WKMessageManager*) manager collectExpressions:(WKMessageModel*)message {
    // 收藏他人发的表情：走 sticker/user/collect（专门 endpoint），
    // 而不是 sticker/user（那是「上传我自己的表情」的入口）。
    // 后端对 collect 会按 path 幂等挂到我账户下，保留原始表情；
    // 走 sticker/user 会被当成新建流程，可能触发缩略图/降级路径（问题现场：
    // 收藏后在「我的表情」里只看到一张缩略图，与原表情不符）。
    // 对齐 web `octo-web` `POST /api/v1/sticker/user/collect`。
    NSString *path;
    NSString *placeholder;
    NSString *category;
    NSString *format;
    NSInteger contentType = message.contentType;
    if (contentType == WK_GIF) {
        WKGIFContent *content = (WKGIFContent *)message.content;
        path = content.url;
    } else {
        WKLottieStickerContent *content = (WKLottieStickerContent *)message.content;
        path = content.url;
        placeholder = content.placeholder;
        category = content.category;
        format = content.format;
    }
    // 详细日志：定位问题（HUD 提示成功但列表里出现缩略图），先看清 wire 上传了什么
    WKLogInfo(@"[Sticker/collect] BEGIN contentType=%ld path='%@' placeholder='%@' category='%@' format='%@'",
              (long)contentType, path ?: @"(nil)", placeholder ?: @"(nil)", category ?: @"(nil)", format ?: @"(nil)");
    if (path.length == 0) {
        WKLogError(@"[Sticker/collect] ABORT path empty");
        return;
    }

    NSMutableDictionary *paraDict = @{@"path": path}.mutableCopy;
    if (placeholder.length > 0) paraDict[@"placeholder"] = placeholder;
    WKLogInfo(@"[Sticker/collect] POST sticker/user/collect params=%@", paraDict);

    [[WKAPIClient sharedClient] POST:@"sticker/user/collect" parameters:paraDict].then(^(id resp){
        WKLogInfo(@"[Sticker/collect] SUCCESS resp class=%@ resp=%@", NSStringFromClass([resp class]), resp);
        [[WKNavigationManager shared].topViewController.view showMsg:LLang(@"已添加到我的表情")];
        [WKApp.shared loadCollectStickers].then(^(NSArray *stickers){
            WKLogInfo(@"[Sticker/collect] loadCollectStickers back count=%lu", (unsigned long)stickers.count);
            for (WKSticker *s in stickers) {
                WKLogInfo(@"[Sticker/collect]   item path='%@' format='%@' category='%@' width=%@ height=%@",
                          s.path, s.format, s.category, s.width, s.height);
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_STICKERS_UPDATED object:nil];
        });
    }).catch(^(NSError *error){
        WKLogError(@"[Sticker/collect] FAIL error=%@ domain=%@ code=%ld userInfo=%@",
                   error, error.domain, (long)error.code, error.userInfo);
        [[WKNavigationManager shared].topViewController.view showMsg:LLang(@"添加失败")];
    });
}



@end
