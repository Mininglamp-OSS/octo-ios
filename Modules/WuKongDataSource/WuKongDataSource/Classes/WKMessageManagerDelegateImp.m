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
    
    // 先本地执行假的撤回逻辑（为了使前端页面看着顺畅），后面收到撤回的消息才会执行真的逻辑
    if(![[WKChannelSettingManager shared] revokeRemind:message.channel]) {
        message.message.isDeleted = true; // 如果设置了不撤回不提醒则直接删除消息
    }else{
        message.message.remoteExtra.revoke = true;
        message.message.remoteExtra.revoker = [WKApp shared].loginInfo.uid;
    }
    [[WKSDK shared].chatManager callMessageUpdateDelegate:message.message];
    
    
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
