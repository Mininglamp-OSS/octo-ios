//
//  WKCommonPlugin.m
//  WuKongBase
//
//  Created by tt on 2020/4/3.
//

#import "WKCommonPlugin.h"
#import "WKNavigationManager.h"
@implementation WKCommonPlugin

//- (void)showConversation:(WKMsgCommand *)command {
//   NSString *channelID = command.arguments[@"channel_id"]?:@"";
//   NSInteger channelType = command.arguments[@"channel_type"]?[command.arguments[@"channel_type"] integerValue]:0;
//    NSString *forward = command.arguments[@"forward"];
//    if(!channelID || [channelID isEqualToString:@""]) {
//        return;
//    }
//    WKConversationVC *conversationVC =  [WKConversationVC new];
//    conversationVC.channel = [[WKChannel alloc] initWith:channelID channelType:channelType];
//    if(forward && [forward isEqualToString:@"replace"]) {
//        [[WKNavigationManager shared] replacePushViewController:conversationVC animated:YES];
//    }else {
//        [[WKNavigationManager shared] pushViewController:conversationVC animated:YES];
//    }
//}
//
//- (void)pop:(WKMsgCommand *)command {
//    [[WKNavigationManager shared] popViewControllerAnimated:YES];
//}

@end
