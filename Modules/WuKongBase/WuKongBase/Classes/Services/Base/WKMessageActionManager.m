//
//  WKMessageActionManager.m
//  WuKongBase
//
//  Created by tt on 2022/4/8.
//

#import "WKMessageActionManager.h"
#import "WuKongBase.h"
#import "WKForwardSelectVC.h"
@implementation WKMessageActionManager
static WKMessageActionManager *_instance;
+ (WKMessageActionManager *)shared {
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    return _instance;
}

-(void) forwardMessages:(NSArray<WKMessage*>*)messages{
    WKForwardSelectVC *vc = [WKForwardSelectVC new];
    vc.title = LLang(@"选择聊天");
    vc.singleSelectMode = YES;
    // 构建文件预览信息
    vc.shareFileInfos = [self buildFileInfosFromMessages:messages];
    __weak typeof(self) weakSelf = self;
    [vc setOnSingleConfirm:^(WKChannel *channel, NSString *extraText) {
        [weakSelf doForwardMessages:messages toChannel:channel extraText:extraText];
    }];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

-(void) forwardContent:(WKMessageContent*)messageContent complete:(void(^)(void))complete{
    WKForwardSelectVC *vc = [WKForwardSelectVC new];
    vc.title = LLang(@"选择聊天");
    vc.singleSelectMode = YES;
    [vc setOnSingleConfirm:^(WKChannel *channel, NSString *extraText) {
        // ForwardSelectVC 确认后会自动 pop，这里不再重复 pop
        if(complete) {
            complete();
        }
        if([[WKApp shared] allowMessageForward:messageContent.realContentType]) {
            [[WKSDK shared].chatManager forwardMessage:messageContent channel:channel];
        } else {
            WKTextContent *textContent = [[WKTextContent alloc] initWithContent:[messageContent conversationDigest]];
            [[WKSDK shared].chatManager forwardMessage:textContent channel:channel];
        }
        if (extraText.length > 0) {
            WKTextContent *tc = [[WKTextContent alloc] initWithContent:extraText];
            [[WKSDK shared].chatManager forwardMessage:tc channel:channel];
        }
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"发送成功")];
    }];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

-(void) sendContentToFriend:(WKMessageContent*)messageContent complete:(void(^__nullable)(void))complete {
    WKForwardSelectVC *vc = [WKForwardSelectVC new];
    vc.title = LLang(@"选择聊天");
    vc.singleSelectMode = YES;
    [vc setOnSingleConfirm:^(WKChannel *channel, NSString *extraText) {
        // ForwardSelectVC 确认后会自动 pop，这里不再重复 pop
        if(complete) {
            complete();
        }
        [[WKSDK shared].chatManager sendMessage:messageContent channel:channel];
        if (extraText.length > 0) {
            WKTextContent *tc = [[WKTextContent alloc] initWithContent:extraText];
            [[WKSDK shared].chatManager forwardMessage:tc channel:channel];
        }
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"发送成功")];
    }];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

#pragma mark - Helper

-(void) doForwardMessages:(NSArray<WKMessage*>*)messages toChannel:(WKChannel *)channel extraText:(NSString *)extraText {
    // ForwardSelectVC 确认后已经 pop 了自己，这里不再重复 pop
    for (WKMessage *message in messages) {
        if([[WKApp shared] allowMessageForward:message.contentType]) {
            [[WKSDK shared].chatManager forwardMessage:message.content channel:channel];
        } else {
            WKTextContent *textContent = [[WKTextContent alloc] initWithContent:[message.content conversationDigest]];
            [[WKSDK shared].chatManager forwardMessage:textContent channel:channel];
        }
    }
    if (extraText.length > 0) {
        WKTextContent *tc = [[WKTextContent alloc] initWithContent:extraText];
        [[WKSDK shared].chatManager forwardMessage:tc channel:channel];
    }
    [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"发送成功")];
}

/// 从消息数组构建文件预览信息（用于确认弹窗展示）
-(NSArray<NSDictionary *> *) buildFileInfosFromMessages:(NSArray<WKMessage *> *)messages {
    NSMutableArray *infos = [NSMutableArray array];
    for (WKMessage *msg in messages) {
        NSString *digest = [msg.content conversationDigest];
        [infos addObject:@{@"type": @"text", @"content": digest ?: @""}];
    }
    return infos;
}

@end
