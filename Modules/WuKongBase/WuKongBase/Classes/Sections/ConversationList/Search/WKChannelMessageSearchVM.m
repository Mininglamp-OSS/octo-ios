//
//  WKChannelMessageSearchVM.m
//  WuKongBase
//
//  Created by tt on 2020/8/10.
//
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKSearchHeaderCell.h"
#import "WKChannelMessageSearchVM.h"
#import "WKChannelMessageCell.h"
#import "WKConversationVC.h"

@implementation WKChannelMessageSearchVM


- (NSArray<NSDictionary *> *)tableSectionMaps {
    
    NSArray *results = [[WKMessageDB shared] getMessages:self.channel keyword:self.keyword limit:2000];
    if(!results || results.count<=0) {
        return nil;
    }
    NSMutableArray *newResults = [NSMutableArray array];
    for (WKMessage *message in results) {
        if(message.fromUid && ![message.fromUid isEqualToString:@""]) {
            [newResults addObject:message];
        }
    }
    
    NSMutableArray *items = [NSMutableArray array];
     [items addObject: @{
                @"class":WKSearchHeaderModel.class,
                @"title":[NSString stringWithFormat:LLang(@"%lu条与“%@”相关记录"),(unsigned long)newResults.count,self.keyword],
                @"showBottomLine":@(NO),
                         
     }];
    
    for (NSInteger i=0; i<newResults.count; i++) {
        WKMessage *message = newResults[i];
        NSString *name = @"";
        NSString *logo = @"";
        if(!message.from) {
            // 如果from不存在则异步去获取
            [[WKChannelManager shared] fetchChannelInfo:[[WKChannel alloc] initWith:message.fromUid channelType:WK_PERSON]];
        }
        if(message.from && message.from.displayName) {
            name = message.from.displayName;
        }
        if(message.from && message.from.logo) {
            logo = [WKAvatarUtil getFullAvatarWIthPath:message.from.logo];
        }
        [items addObject:@{
           @"class":WKChannelMessageModel.class,
           @"name":name,
           @"avatar":[WKAvatarUtil getFullAvatarWIthPath:logo],
           @"keyword": self.keyword?:@"",
           @"content": [self previewTextForMessage:message],
           @"timestamp": @(message.timestamp),
           @"showBottomLine":@(NO),
           @"showTopLine":@(NO),
           @"onClick":^{
            WKConversationVC *vc = [[WKConversationVC alloc] init];
            vc.channel = self.channel;
            vc.locationAtOrderSeq = message.orderSeq;
            [[WKNavigationManager shared] pushViewController:vc animated:YES];
            }
        }];
    }
    return @[@{
         @"height":@(0.01f),
         @"items":items,
    }];
}

/// 消息预览文字（按类型而定，口径与全局搜索一致）：
/// - 文件：展示真实文件名（而非占位 [文件]）
/// - 合并转发：searchableWord 为空 → 用 conversationDigest（[聊天记录]）
/// - 文本/富文本：正文 searchableWord
/// - 其它（图片/语音…）：searchableWord 占位，空时回退 conversationDigest
- (NSString *)previewTextForMessage:(WKMessage *)message {
    WKMessageContent *content = message.content;
    if (!content) return @"";
    if ([content isKindOfClass:[WKFileContent class]]) {
        NSString *fileName = ((WKFileContent *)content).name;
        if (fileName.length > 0) return fileName;
    }
    NSString *word = [content searchableWord];
    if (word.length > 0) return word;
    NSString *digest = [content conversationDigest];
    return digest ?: @"";
}


@end
