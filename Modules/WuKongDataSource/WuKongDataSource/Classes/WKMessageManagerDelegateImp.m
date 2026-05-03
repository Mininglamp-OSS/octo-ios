//
//  WKMessageManagerDelegateImp.m
//  WuKongDataSource
//
//  Created by tt on 2020/1/29.
//

#import "WKMessageManagerDelegateImp.h"
#import "WKGIFContent.h"
#import "WKLottieStickerContent.h"

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
    
    // 不做乐观 UI 更新，等服务端 messageRevoke CMD 回推再通过 WKChatManager.revokeMessage 路径
    // 更新 DB 并调用 callMessageUpdateDelegate 渲染撤回态。对齐 Web / Android。
    [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"message/revoke?channel_id=%@&channel_type=%hhu&message_id=%@&client_msg_no=%@",message.channel.channelId,message.channel.channelType,messageID,message.clientMsgNo] parameters:nil].then(^{
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
    NSMutableDictionary *paraDict;
    if (message.contentType == WK_GIF) {
        WKGIFContent *content = (WKGIFContent *)message.content;
        paraDict = @{@"path":content.url, @"width":@(content.width), @"height":@(content.height)}.mutableCopy;
    }
    else {
        WKLottieStickerContent *content = (WKLottieStickerContent *)message.content;
        paraDict = @{@"path":content.url}.mutableCopy;
    
        // TODO: 理论上收藏Lottie表情不需要传高宽，因为lottie是矢量图,这里
        [paraDict setObject:@(256) forKey:@"width"];
        [paraDict setObject:@(256) forKey:@"height"];
        
        if (content.format && content.format.length > 0) {
            [paraDict setObject:content.format forKey:@"format"];
        }
        if (content.placeholder && content.placeholder.length > 0) {
            [paraDict setObject:content.placeholder forKey:@"placeholder"];
        }
        if (content.category && content.category.length > 0) {
            [paraDict setObject:content.category forKey:@"category"];
        }
    }
    [[WKAPIClient sharedClient] POST:@"sticker/user" parameters:paraDict].then(^{
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:@"添加成功!"];
        [WKApp.shared loadCollectStickers];
    }).catch(^(NSError *error){
        WKLogError(@"单个表情收藏失败:%@", error);
    });
}



@end
