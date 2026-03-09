//
//  WKMessageActionManager.m
//  WuKongBase
//
//  Created by tt on 2022/4/8.
//

#import "WKMessageActionManager.h"
#import "WKConversationListSelectVC.h"
@implementation WKMessageActionManager
static WKMessageActionManager *_instance;
+ (WKMessageActionManager *)shared {
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    return _instance;
}

-(void) forwardMessages:(NSArray<WKMessage*>*)messages{
    WKConversationListSelectVC *vc = [WKConversationListSelectVC new];
    vc.title = LLang(@"选择一个聊天");
    [vc setOnSelect:^(WKChannel * _Nonnull channel) {
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
//        [[WKNavigationManager shared] popToViewControllerClass:WKConversationVC.class animated:YES];
        for (WKMessage *message  in messages) {
            if([[WKApp shared] allowMessageForward:message.contentType]) { // 如果允许转发则直接转发
                [[WKSDK shared].chatManager forwardMessage:message.content channel:channel];
                
            }else{ // 如果不允许转发，则将变成文本消息转发
                WKTextContent *textContent = [[WKTextContent alloc] initWithContent:[message.content conversationDigest]];
                [[WKSDK shared].chatManager forwardMessage:textContent channel:channel];
            }
           
        }
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"发送成功")];
        
    }];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

-(void) forwardContent:(WKMessageContent*)messageContent complete:(void(^)(void))complete{
    WKConversationListSelectVC *vc = [WKConversationListSelectVC new];
    vc.title = LLang(@"选择一个聊天");
    [vc setOnSelect:^(WKChannel * _Nonnull channel) {
        if(complete) {
            complete();
        }else {
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }
       
        if([[WKApp shared] allowMessageForward:messageContent.realContentType]) { // 如果允许转发则直接转发
            [[WKSDK shared].chatManager forwardMessage:messageContent channel:channel];
            
        }else{ // 如果不允许转发，则将变成文本消息转发
            WKTextContent *textContent = [[WKTextContent alloc] initWithContent:[messageContent conversationDigest]];
            [[WKSDK shared].chatManager forwardMessage:textContent channel:channel];
        }
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"发送成功")];
        
    }];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

-(void) sendContentToFriend:(WKMessageContent*)messageContent complete:(void(^__nullable)(void))complete {
    WKConversationListSelectVC *vc = [WKConversationListSelectVC new];
    vc.title = LLang(@"选择一个聊天");
    [vc setOnSelect:^(WKChannel * _Nonnull channel) {
        if(complete) {
            complete();
        }else {
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }
        [[WKSDK shared].chatManager sendMessage:messageContent channel:channel];
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"发送成功")];
        
    }];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

@end
