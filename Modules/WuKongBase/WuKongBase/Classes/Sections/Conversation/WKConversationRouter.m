//
//  WKConversationRouter.m
//  WuKongBase
//

#import "WKConversationRouter.h"
#import "WKConversationVC.h"
#import "WKNavigationManager.h"
#import "WKApp.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

@implementation WKConversationRouter

+(void) openChannelId:(NSString *)channelId
          channelType:(NSInteger)channelType
           messageSeq:(uint32_t)messageSeq {
    if (channelId.length == 0) return;
    [self _navigateToChannelId:channelId
                   channelType:channelType
                    messageSeq:messageSeq
                    retryCount:0];
}

+(void) _navigateToChannelId:(NSString *)channelId
                 channelType:(NSInteger)channelType
                  messageSeq:(uint32_t)messageSeq
                  retryCount:(NSInteger)retryCount {
    BOOL isReady = [WKNavigationManager shared].topViewController != nil
                && [WKApp shared].loginInfo.uid.length > 0
                && [WKApp shared].loginInfo.token.length > 0;

    if (!isReady) {
        if (retryCount >= 20) return; // 最多重试 20 次（10 秒）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self _navigateToChannelId:channelId
                           channelType:channelType
                            messageSeq:messageSeq
                            retryCount:retryCount + 1];
        });
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        WKChannel *channel = [WKChannel channelID:channelId channelType:channelType];

        UIViewController *topVC = [WKNavigationManager shared].topViewController;
        if ([topVC isKindOfClass:[WKConversationVC class]]) {
            WKConversationVC *existingVC = (WKConversationVC *)topVC;
            if ([existingVC.channel.channelId isEqualToString:channel.channelId]
                && existingVC.channel.channelType == channel.channelType) {
                if (messageSeq > 0) {
                    [existingVC locateToMessageSeq:messageSeq];
                }
                return;
            }
        }

        WKConversationVC *vc = [WKConversationVC new];
        vc.channel = channel;
        if (messageSeq > 0) {
            uint32_t orderSeq = [[WKSDK shared].chatManager getOrderSeq:messageSeq];
            if (orderSeq == 0) {
                orderSeq = messageSeq;
            }
            vc.locationAtOrderSeq = orderSeq;
        }
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
    });
}

@end
