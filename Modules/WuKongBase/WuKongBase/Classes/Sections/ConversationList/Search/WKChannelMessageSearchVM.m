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
#import "WKSpaceFilter.h"
#import "WKConversationListVM.h"

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
    // 按当前空间过滤(私聊跨空间隔离): 与列表层 WKGlobalSearchVM.refinePersonResult 同口径,
    // 否则列表显示"N条相关记录"(已按空间过滤)而点进详情页显示跨空间全部消息, 计数与内容不一致。
    newResults = [[self filterMessagesByCurrentSpace:newResults] mutableCopy];
    if (newResults.count == 0) {
        return nil;
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
           @"content": [self snippetFromText:[self previewTextForMessage:message] keyword:self.keyword maxLength:40],
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

/// 按当前空间过滤命中消息, 与全局搜索列表 WKGlobalSearchVM.refinePersonResult 同口径:
///   - 群聊/子区/Bot/单空间(无 currentSpaceId): 频道级已在列表层判定 → 原样放行, 不逐条拆。
///   - 普通私聊(WK_PERSON 非 Bot): 同一个人在多空间 channelId 相同, SQL 聚合无法区分, 逐条按
///     消息级 space_id 过滤:
///       · space_id == 当前空间          → 保留
///       · space_id != 当前空间          → 剔除(shouldSkipMessageForSpace=YES)
///       · 无 space_id(明略/默认空间消息) → 仅当该私聊频道在「当前空间会话列表」中才保留
///         (列表未就绪的 race 窗口 fail-open 放行, 避免误杀)。
- (NSArray<WKMessage*> *)filterMessagesByCurrentSpace:(NSArray<WKMessage*> *)messages {
    if (messages.count == 0) return messages;
    if (self.channel.channelType != WK_PERSON) return messages; // 群/子区: 频道级已判定
    NSString *currentSpaceId = [[WKSpaceFilter shared] currentSpaceId];
    if (currentSpaceId.length == 0) return messages;             // 单空间/未设置: 不过滤

    // Bot: payload 无 space_id, 由 WKSpaceBotRegistry 整体判定(列表层已 gate), 这里不逐条拆。
    WKChannelInfo *info = [[WKChannelInfoDB shared] queryChannelInfo:self.channel];
    if (info && info.robot) return messages;

    WKConversationListVM *convVM = [WKConversationListVM shared];
    BOOL convListReady = ([convVM conversationCount] > 0);
    BOOL channelInCurrentSpaceList = ([convVM anyModelAtChannel:self.channel] != nil);

    NSMutableArray<WKMessage*> *kept = [NSMutableArray array];
    for (WKMessage *m in messages) {
        if ([[WKSpaceFilter shared] shouldSkipMessageForSpace:m channelType:self.channel.channelType]) {
            continue; // space_id != current
        }
        NSString *msgSpace = nil;
        id sv = m.content.contentDict[@"space_id"];
        if ([sv isKindOfClass:[NSString class]]) msgSpace = (NSString *)sv;
        if (msgSpace.length == 0) {
            // 无 space_id(明略消息): 仅当该私聊频道在当前空间会话列表里才放行
            if (convListReady && !channelInCurrentSpaceList) continue;
        }
        [kept addObject:m];
    }
    return kept;
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

/// 以关键词为中心截取上下文片段(与全局搜索 WKGlobalSearchVM.snippetFromText 同口径)。
/// 会话内搜索详情页之前直接用整段 previewText, 命中关键词在中后部时只显示开头、
/// 看不到关键词附近内容。这里居中截取, 与外层全局搜索结果体验一致。
- (NSString *)snippetFromText:(NSString *)text keyword:(NSString *)keyword maxLength:(NSInteger)maxLength {
    if (!text || text.length == 0) return @"";
    if (!keyword || keyword.length == 0) return text.length > (NSUInteger)maxLength ? [text substringToIndex:maxLength] : text;

    NSRange range = [text rangeOfString:keyword options:NSCaseInsensitiveSearch];
    if (range.location == NSNotFound) {
        return text.length > (NSUInteger)maxLength ? [NSString stringWithFormat:@"%@...", [text substringToIndex:maxLength]] : text;
    }
    NSInteger contextRadius = (maxLength - (NSInteger)keyword.length) / 2;
    NSInteger start = MAX(0, (NSInteger)range.location - contextRadius);
    NSInteger end = MIN((NSInteger)text.length, (NSInteger)(range.location + range.length) + contextRadius);
    // 截取窗口对齐到字素边界, 避免按 UTF-16 code unit 截断把 emoji / 组合字劈成半个产生乱码
    NSRange safe = [text rangeOfComposedCharacterSequencesForRange:NSMakeRange(start, end - start)];
    NSString *snippet = [text substringWithRange:safe];
    if (safe.location > 0) snippet = [NSString stringWithFormat:@"...%@", snippet];
    if (NSMaxRange(safe) < text.length) snippet = [NSString stringWithFormat:@"%@...", snippet];
    return snippet;
}


@end
