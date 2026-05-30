//
//  WKGlobalSearchVM.m
//  WuKongBase
//
//  Created by tt on 2020/4/24.
//

#import "WKGlobalSearchVM.h"
#import "WKTableSectionUtil.h"
#import "WKLabelItemCell.h"
#import "WKSearchHeaderCell.h"
#import "WKSearchContactsCell.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKAvatarUtil.h"
#import "WKSearchMessageCell.h"
#import "WKSearchMoreCell.h"
#import "WKChannelMessageSearchResultVC.h"
#import "WKGlobalSearchResultController.h"
#import "WKConversationVC.h"
#import "WKSearchMediaCell.h"
#import "WKConversationListVM.h"
#import "WKSpaceFilter.h"
#define WKSearchMaxCount 4

@interface WKGlobalSearchVM ()

@property(nonatomic,strong) NSDictionary *searchResult;

@property(nonatomic,assign) NSInteger page;
@property(nonatomic,assign) NSInteger limit;
@property(nonatomic,assign) BOOL pullup; // 是否pullup中
@property(nonatomic,assign) BOOL hasMore;// 是否有更多数据
@property(nonatomic,copy) NSString *tabType;
@property(nonatomic,strong) NSArray<WKChannelMessageSearchResult*> *localMessageSearchResults;
@property(nonatomic,strong) NSArray<WKMessage*> *localFileSearchResults;

@end

@implementation WKGlobalSearchVM

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.page = 1;
        self.tabType = @"all";
    }
    return self;
}

- (NSArray<WKFormSection *> *)tableSections {
    if(!self.searchResult) {
        return nil;
    }

    NSArray *items = [self handleSearchResult:self.searchResult];

    return  [WKTableSectionUtil toSections:items];
}

-(void) initQuery {
    self.page = 1;
    self.pullup = false;
    self.hasMore = false;

}

- (BOOL)searchInChannel {
    if(!self.channel) {
        return false;
    }
    return  true;
}

-(void) changeKeyword:(NSString*)keyword {
    self.keyword = keyword;
    [self initQuery];
    [self resetPullupState];
    [self reloadRemoteData];
}

- (void)changeTabType:(NSString *)type {
    [self initQuery];
    [self resetPullupState];
    self.tabType = type;

    [self reloadRemoteData];
}

- (void)requestData:(void (^)(NSError * _Nullable))complete {
    [self search:^(NSError *error){
        complete(error);
    }];
}

- (void)pullup:(void (^)(BOOL))complete {
    self.page++;
    self.pullup = true;
    
    if(![self.tabType isEqualToString:@"all"] && ![self.tabType isEqualToString:@"file"]&&![self.tabType isEqualToString:@"media"]) {
        complete(false);
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [self search:^(NSError *error){
        if(error) {
            complete(true);
            return;
        }
        complete(weakSelf.hasMore);
    }];
}

-(void) search:(void(^)(NSError * _Nullable))complete {
    __weak typeof(self) weakSelf = self;

    // 全局搜索（非频道内）：聊天 / 联系人 / 群组 / 文件 全部走本地 DB，不再请求网络。
    // 各 tab 的展示过滤在 handleSearchResult: 里按 tabType 处理。
    if (!self.searchInChannel &&
        ([self.tabType isEqualToString:@"all"] ||
         [self.tabType isEqualToString:@"contacts"] ||
         [self.tabType isEqualToString:@"group"])) {
        [self searchLocalConversations];
        if (complete) complete(nil);
        [weakSelf reloadData];
        return;
    }

    // 文件 tab（全局搜索）：本地 DB 按文件名搜索 + 当前空间过滤
    if ([self.tabType isEqualToString:@"file"] && !self.searchInChannel) {
        [self searchLocalFiles];
        if (complete) complete(nil);
        [weakSelf reloadData];
        return;
    }

    NSMutableArray<NSNumber*>  *contentTypes = [NSMutableArray array];
    BOOL onlyMessage = false;
    self.limit = 20;
    if([self.tabType isEqualToString:@"file"]) {
        onlyMessage = true;
        [contentTypes addObject:@(WK_FILE)];
    } else if ([self.tabType isEqualToString:@"media"]) { // 图片/视频
        onlyMessage = true;
        
        if([WKApp.shared hasMethod:WKPOINT_SEARCH_ITEM_VIDEO]) {
            [contentTypes addObjectsFromArray:@[@(WK_IMAGE),@(WK_SMALLVIDEO)]];
        }else {
            [contentTypes addObjectsFromArray:@[@(WK_IMAGE)]];
        }
        self.limit = 40;
    }
    if(self.searchInChannel) {
        onlyMessage = true;
    }
    
    NSString *keyword = self.keyword;
    if([self.tabType isEqualToString:@"media"]) { // 图片和视频不能通过关键字搜索，所以这里抹掉关键字
        keyword = @"";
    }
    
    NSMutableDictionary *param = [NSMutableDictionary dictionaryWithDictionary:@{
        @"keyword": keyword?:@"",
        @"page": @(self.page),
        @"limit": @(self.limit),
        @"only_message": onlyMessage?@(1):@(0),
        @"content_type": contentTypes,
    }];
    if(self.channel) {
        param[@"channel_id"] = self.channel.channelId?:@"";
        param[@"channel_type"] = @(self.channel.channelType);
    }
    [self requestSearch:param callback:^(NSError *err,NSDictionary * result) {
        if(err) {
            if(complete) {
                complete(err);
            }
            return;
        }
        
        if(weakSelf.pullup) {
            if(!weakSelf.searchResult) {
                weakSelf.searchResult = result;
            }else {
                
                NSMutableDictionary *resultDict = [NSMutableDictionary dictionaryWithDictionary:weakSelf.searchResult];
                
                NSMutableArray<NSDictionary*> *messages = [NSMutableArray arrayWithArray:weakSelf.searchResult[@"messages"]];
                NSArray *resultMessages = result[@"messages"];
                if(resultMessages && resultMessages.count>=weakSelf.limit) {
                    weakSelf.hasMore = true;
                }else {
                    weakSelf.hasMore = false;
                }
                if(messages) {
                    [messages addObjectsFromArray:resultMessages];
                }
                resultDict[@"messages"] = messages;
                weakSelf.searchResult = resultDict;
            }
        }else {
            weakSelf.searchResult = result;
        }
        if(complete) {
            complete(nil);
        }
        [weakSelf reloadData];
    }];
}

/// 聊天 tab：本地 DB 联系人/群组名称匹配 + 本地 DB 消息内容搜索（全程不走网络）
- (void)searchLocalConversations {
    NSString *keyword = self.keyword;
    if (!keyword || keyword.length == 0) {
        self.searchResult = @{@"friends":@[], @"groups":@[], @"messages":@[]};
        self.localMessageSearchResults = nil;
        return;
    }

    // 1) 联系人 + 群组：本地 DB 名称/备注匹配（覆盖全部好友/群，不局限于有会话的频道）
    self.searchResult = @{
        @"friends": [self localFriendItemsWithKeyword:keyword],
        @"groups": [self localGroupItemsWithKeyword:keyword],
        @"messages": @[],
    };

    // 2) 按消息内容搜索（本地 DB）
    //    message 表不含 space_id 列且切换空间时不会清空，需按当前空间做频道级过滤，
    //    口径与会话列表 / 消息列表一致（WKSpaceFilter）。否则其它空间的历史消息会
    //    泄漏进当前空间的搜索结果。
    NSArray<WKChannelMessageSearchResult*> *msgResults = [[WKChannelInfoDB shared] searchChannelMessageWithKeyword:keyword limit:50];
    self.localMessageSearchResults = [self filterSearchResultsByCurrentSpace:msgResults];
}

/// 本地好友（个人频道 follow=friend）名称/备注匹配，按当前空间过滤
- (NSArray<NSDictionary*>*)localFriendItemsWithKeyword:(NSString*)keyword {
    NSArray<WKChannelInfo*> *friends = [[WKChannelInfoDB shared] queryChannelInfoWithFriend:keyword limit:50];
    NSMutableArray<NSDictionary*> *items = [NSMutableArray array];
    for (WKChannelInfo *info in friends) {
        if (!info.channel || info.channel.channelId.length == 0) continue;
        if (![self isChannelInCurrentSpace:info.channel]) continue;
        [items addObject:@{
            @"channel_id": info.channel.channelId ?: @"",
            @"channel_name": info.name ?: @"",
            @"channel_remark": info.remark ?: @"",
            @"channel_type": @(info.channel.channelType),
        }];
    }
    return items;
}

/// 本地群组（群频道）名称/备注匹配，按当前空间过滤
- (NSArray<NSDictionary*>*)localGroupItemsWithKeyword:(NSString*)keyword {
    NSArray<WKChannelInfo*> *groups = [[WKChannelInfoDB shared] queryChannelInfoWithType:keyword channelType:WK_GROUP limit:50];
    NSMutableArray<NSDictionary*> *items = [NSMutableArray array];
    for (WKChannelInfo *info in groups) {
        if (!info.channel || info.channel.channelId.length == 0) continue;
        if (![self isChannelInCurrentSpace:info.channel]) continue;
        [items addObject:@{
            @"channel_id": info.channel.channelId ?: @"",
            @"channel_name": info.name ?: @"",
            @"channel_remark": info.remark ?: @"",
            @"channel_type": @(info.channel.channelType),
        }];
    }
    return items;
}

/// 按当前空间过滤本地聊天记录搜索结果（频道级判定，与会话/消息列表口径一致）
- (NSArray<WKChannelMessageSearchResult*> *)filterSearchResultsByCurrentSpace:(NSArray<WKChannelMessageSearchResult*> *)results {
    if (!results || results.count == 0) {
        return results;
    }
    NSMutableArray<WKChannelMessageSearchResult*> *filtered = [NSMutableArray array];
    for (WKChannelMessageSearchResult *result in results) {
        if ([self isChannelInCurrentSpace:result.channel]) {
            [filtered addObject:result];
        }
    }
    return filtered;
}

/// 判断频道是否属于当前空间，口径对齐 WKConversationListVC.isConversationInCurrentSpace：
/// - 群聊(WK_GROUP)：WKSpaceFilter 判定，FailOpen 时降级到会话列表白名单（fail-closed）；
/// - 子区(WK_COMMUNITY_TOPIC)：取父群 channelId（`{groupId}____{topicId}`）走群聊判定；
/// - 私聊/Bot(WK_PERSON)：WKSpaceFilter 判定，Skip 才排除（缺 space_id 向前兼容放行）；
/// - 无 currentSpaceId（单空间/未设置）：不过滤。
- (BOOL)isChannelInCurrentSpace:(WKChannel *)channel {
    if (!channel || channel.channelId.length == 0) {
        return NO;
    }
    NSString *currentSpaceId = [[WKSpaceFilter shared] currentSpaceId];
    if (currentSpaceId.length == 0) {
        return YES; // 单空间 / 未设置空间：不做过滤
    }

    uint8_t type = channel.channelType;

    // 子区：归属由父群决定（channelId 形如 `{groupId}____{topicId}`）
    if (type == WK_COMMUNITY_TOPIC) {
        NSString *channelId = channel.channelId;
        NSRange sep = [channelId rangeOfString:@"____"];
        NSString *groupId = (sep.location != NSNotFound) ? [channelId substringToIndex:sep.location] : channelId;
        return [self isGroupInCurrentSpace:groupId];
    }

    if (type == WK_GROUP) {
        return [self isGroupInCurrentSpace:channel.channelId];
    }

    // 私聊 / Bot：Skip 才排除，Keep / FailOpen 放行（缺 space_id 的历史私聊向前兼容）
    WKSpaceFilterDecision decision = [[WKSpaceFilter shared] decideChannel:channel.channelId channelType:type];
    return decision != WKSpaceFilterDecisionSkip;
}

/// 群聊空间归属判定：Keep→YES，Skip→NO，FailOpen→会话列表白名单兜底（白名单未初始化时 fail-closed）
- (BOOL)isGroupInCurrentSpace:(NSString *)groupId {
    if (groupId.length == 0) {
        return NO;
    }
    WKSpaceFilterDecision decision = [[WKSpaceFilter shared] decideChannel:groupId channelType:WK_GROUP];
    if (decision == WKSpaceFilterDecisionKeep) {
        return YES;
    }
    if (decision == WKSpaceFilterDecisionSkip) {
        return NO;
    }
    // FailOpen：channelInfo / member 未缓存 → 降级到会话列表白名单（与 isConversationInCurrentSpace 一致）
    WKConversationListVM *vm = [WKConversationListVM shared];
    if (![vm isGroupWhitelistInitialized]) {
        return NO; // 白名单未初始化期严格过滤，避免其它空间群聊漏入
    }
    return [vm isGroupInWhitelist:groupId];
}

/// 取一条聊天记录命中的预览文字：
/// 优先 searchable_word；当其为空或为占位（如 [图片]/[文件]，而关键字其实命中了 content
/// 里的正文/文件名）时，解码 content JSON 还原真实预览，避免「命中了却看不到关键词」或空白。
- (NSString *)previewTextForSearchResult:(WKChannelMessageSearchResult *)result {
    NSString *kw = self.keyword ?: @"";
    NSString *word = result.searchableWord ?: @"";
    // searchable_word 已包含关键字（普通文本场景）→ 直接用
    if (word.length > 0 && kw.length > 0 &&
        [word rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return word;
    }
    // 否则解码 content，得到「按类型而定」的预览：文件→文件名，合并消息→[聊天记录]，
    // 文本/富文本→正文，图片/语音等→占位。覆盖 searchable_word 为空/占位的情况。
    NSString *decoded = [self decodedContentTextForResult:result];
    if (decoded.length > 0) {
        return decoded;
    }
    // 理论兜底
    if (word.length > 0) return word;
    return @"";
}

/// 解码该命中行的 content（NSData），返回「按类型而定」的预览文字：
/// - 文件：文件名（而非占位 [文件]）
/// - 合并转发：[聊天记录] 等 conversationDigest
/// - 文本/富文本：正文（searchableWord）
/// - 其它（图片/语音…）：searchableWord 占位，空时回退 conversationDigest
- (NSString *)decodedContentTextForResult:(WKChannelMessageSearchResult *)result {
    NSData *contentData = result.content;
    if (![contentData isKindOfClass:[NSData class]] || contentData.length == 0) return @"";
    WKMessageContent *messageContent = [WKSDK.shared.chatManager getMessageContent:result.contentType];
    if (!messageContent) return @"";
    [messageContent decode:contentData];

    // 文件：展示真实文件名
    if ([messageContent isKindOfClass:[WKFileContent class]]) {
        NSString *name = ((WKFileContent *)messageContent).name;
        if (name.length > 0) return name;
    }

    NSString *word = messageContent.searchableWord;
    if (word.length > 0) return word;
    // searchableWord 为空（如合并转发）→ 用 conversationDigest（[聊天记录] 等）
    NSString *digest = [messageContent conversationDigest];
    return digest ?: @"";
}

/// 文件 tab：本地 DB 按文件名搜索文件消息 + 当前空间频道级过滤
- (void)searchLocalFiles {
    // 文件 tab 不复用「聊天」tab 的本地聊天记录结果，避免跨 tab 串扰
    self.localMessageSearchResults = nil;
    NSString *keyword = self.keyword;
    if (!keyword || keyword.length == 0) {
        self.localFileSearchResults = nil;
        // searchResult 置为非 nil 空结果，确保 tableSections 不被 short-circuit
        self.searchResult = @{@"friends":@[], @"groups":@[], @"messages":@[]};
        return;
    }
    NSArray<WKMessage*> *fileMessages = [[WKMessageDB shared] searchFileMessagesWithKeyword:keyword limit:50];
    NSMutableArray<WKMessage*> *filtered = [NSMutableArray array];
    for (WKMessage *message in fileMessages) {
        if ([self isChannelInCurrentSpace:message.channel]) {
            [filtered addObject:message];
        }
    }
    self.localFileSearchResults = filtered;
    // 文件 section 独立从 localFileSearchResults 渲染；searchResult 仅需非 nil
    self.searchResult = @{@"friends":@[], @"groups":@[], @"messages":@[]};
}

/// 截取关键词周围的上下文片段（关键词前后各保留一段文字，超出用 ... 省略）
- (NSString *)snippetFromText:(NSString *)text keyword:(NSString *)keyword maxLength:(NSInteger)maxLength {
    if (!text || text.length == 0) return @"";
    if (!keyword || keyword.length == 0) return [text substringToIndex:MIN(text.length, (NSUInteger)maxLength)];

    NSRange range = [text rangeOfString:keyword options:NSCaseInsensitiveSearch];
    if (range.location == NSNotFound) {
        return text.length > (NSUInteger)maxLength ? [NSString stringWithFormat:@"%@...", [text substringToIndex:maxLength]] : text;
    }

    NSInteger contextRadius = (maxLength - (NSInteger)keyword.length) / 2;
    NSInteger start = MAX(0, (NSInteger)range.location - contextRadius);
    NSInteger end = MIN((NSInteger)text.length, (NSInteger)(range.location + range.length) + contextRadius);

    NSString *snippet = [text substringWithRange:NSMakeRange(start, end - start)];
    if (start > 0) snippet = [NSString stringWithFormat:@"...%@", snippet];
    if (end < (NSInteger)text.length) snippet = [NSString stringWithFormat:@"%@...", snippet];
    return snippet;
}

/// 剥离 HTML 标签（如 <mark>...</mark>），返回纯文本
- (NSString *)stripHTMLTags:(NSString *)html {
    if (!html || html.length == 0) return html;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:nil];
    return [regex stringByReplacingMatchesInString:html options:0 range:NSMakeRange(0, html.length) withTemplate:@""];
}

-(NSMutableArray<NSDictionary*>*) handleSearchResult:(NSDictionary * )result {
    NSArray<NSDictionary*> *friends = result[@"friends"];
    NSArray<NSDictionary*> *groups = result[@"groups"];
    NSArray<NSDictionary*> *messages = result[@"messages"];
    if(self.tabType && ![self.tabType isEqualToString:@""]) {
        if([self.tabType isEqualToString:@"contacts"]) {
            messages = [NSArray array];
            groups = [NSArray array];
        }else if([self.tabType isEqualToString:@"group"]) {
            friends = [NSArray array];
            messages = [NSArray array];
        } else if([self.tabType isEqualToString:@"file"]) {
            friends = [NSArray array];
            groups = [NSArray array];
        }
    }
    
    NSMutableArray<NSDictionary*> *items = [NSMutableArray array];
    if(friends&&friends.count>0) {
        [items addObject: @{
                   @"class":WKSearchHeaderModel.class,
                   @"title":LLang(@"联系人"),
                   @"showBottomLine":@(NO)
                            
        }];
        
        // friends
        NSMutableArray<NSDictionary*> *friendItems = [NSMutableArray array];
        for (NSInteger i=0; i<friends.count; i++) {
            NSDictionary *friend = friends[i];

            NSString *remark = friend[@"channel_remark"]?:@"";
            NSString *rawName = friend[@"channel_name"]?:@"";
            NSString *name = (remark.length > 0) ? [self stripHTMLTags:remark] : [self stripHTMLTags:rawName];
            NSString *uid = friend[@"channel_id"]?:@"";
            // 外部成员 @SpaceName 字段透传：后端若返回 home_space_* / is_external
            // / source_space_name 则原样挂到 cell model，cell 侧走 WKExternalViewerResolver
            // 判定。字段缺失保持 nil → 非外部行为，向后兼容。
            NSMutableDictionary *friendItem = [@{
                      @"class":WKSearchContactsModel.class,
                      @"name":name,
                      @"avatar":[WKAvatarUtil getAvatar:uid],
                      @"keyword": @"",
                      @"showBottomLine":@(NO),
                      @"showTopLine":@(NO),
                      @"onClick":^{
                        [[WKApp shared] invoke:WKPOINT_USER_INFO param:@{@"uid":uid}];
                      }
                   } mutableCopy];
            [self applyExternalFieldsTo:friendItem from:friend];
            [friendItems addObject:friendItem];
        }
        [items addObject:@{
            @"height":WKSectionHeight,
             @"items":friendItems,
        }];
    }
    
    // groups
    if(groups && groups.count>0) {
        [items addObject: @{
                   @"class":WKSearchHeaderModel.class,
                   @"title":LLang(@"群聊"),
                   @"showBottomLine":@(NO),
                            
        }];
        
        NSMutableArray<NSDictionary*> *groupsItems = [NSMutableArray array];
        for (NSInteger i=0; i<groups.count; i++) {
            NSDictionary *group = groups[i];

            NSString *gRemark = group[@"channel_remark"]?:@"";
            NSString *gRawName = group[@"channel_name"]?:@"";
            NSString *name = (gRemark.length > 0) ? [self stripHTMLTags:gRemark] : [self stripHTMLTags:gRawName];
            NSString *groupNo = group[@"channel_id"]?:@"";
            // 外部群 @SpaceName：与 friends 一致，字段透传不改搜索逻辑。
            NSMutableDictionary *groupItem = [@{
               @"class":WKSearchContactsModel.class,
               @"name":name?:@"",
               @"avatar":[WKAvatarUtil getGroupAvatar:groupNo],
               @"keyword": @"",
               @"showBottomLine":@(NO),
               @"showTopLine":@(NO),
               @"onClick":^{
                [[WKApp shared] pushConversation:[WKChannel groupWithChannelID:groupNo]];
            }
            } mutableCopy];
            [self applyExternalFieldsTo:groupItem from:group];
            [groupsItems addObject:groupItem];
        }
        
        
        [items addObject:@{
            @"height":WKSectionHeight,
             @"items":groupsItems,
        }];
    }
    
    // 本地聊天记录搜索结果（按会话分组，类微信体验）
    if (self.localMessageSearchResults && self.localMessageSearchResults.count > 0 && [self.tabType isEqualToString:@"all"]) {
        [items addObject:@{
            @"class": WKSearchHeaderModel.class,
            @"title": LLang(@"聊天记录"),
            @"showBottomLine": @(NO),
        }];

        NSString *kw = self.keyword ?: @"";
        NSMutableArray<NSDictionary*> *msgItems = [NSMutableArray array];

        for (WKChannelMessageSearchResult *result in self.localMessageSearchResults) {
            WKChannel *ch = result.channel;
            // 预览文字：优先 searchable_word；为空（富文本/未注册类型/旧消息）时解码 content 兜底
            NSString *previewText = [self previewTextForSearchResult:result];

            // 截取关键词周围的上下文片段用于预览
            NSString *snippet = [self snippetFromText:previewText keyword:kw maxLength:40];

            if (result.messageCount == 1) {
                // 单条命中 → 显示消息预览，点击直接跳到该消息
                uint32_t orderSeq = result.orderSeq;
                [msgItems addObject:@{
                    @"class": WKSearchMessageModel.class,
                    @"channel": ch,
                    @"keyword": kw,
                    @"content": snippet,
                    @"messageCount": @(1),
                    @"timestamp": @(result.timestamp),
                    @"showBottomLine": @(NO),
                    @"showTopLine": @(NO),
                    @"onClick": ^{
                        WKConversationVC *vc = [[WKConversationVC alloc] init];
                        vc.channel = ch;
                        vc.locationAtOrderSeq = orderSeq;
                        [[WKNavigationManager shared] pushViewController:vc animated:YES];
                    }
                }];
            } else {
                // 多条命中 → 显示 "N条相关聊天记录"，点击进入该会话的搜索详情页
                NSInteger count = result.messageCount;
                [msgItems addObject:@{
                    @"class": WKSearchMessageModel.class,
                    @"channel": ch,
                    @"keyword": kw,
                    @"content": @"",
                    @"messageCount": @(count),
                    @"timestamp": @(0),
                    @"showBottomLine": @(NO),
                    @"showTopLine": @(NO),
                    @"onClick": ^{
                        WKChannelMessageSearchResultVC *vc = [[WKChannelMessageSearchResultVC alloc] init];
                        vc.channel = ch;
                        vc.keyword = kw;
                        [[WKNavigationManager shared] pushViewController:vc animated:YES];
                    }
                }];
            }
        }

        [items addObject:@{
            @"height": WKSectionHeight,
            @"items": msgItems,
        }];
    }

    // 本地文件名搜索结果（「文件」tab，按文件名匹配，点击定位到文件所在聊天位置）
    // 展示样式复用聊天记录结果（WKSearchMessageModel）：会话头像 + 会话名 + 文件名行 + 时间。
    if (self.localFileSearchResults && self.localFileSearchResults.count > 0 && [self.tabType isEqualToString:@"file"]) {
        NSString *kw = self.keyword ?: @"";
        NSMutableArray<NSDictionary*> *fileItems = [NSMutableArray array];

        for (WKMessage *message in self.localFileSearchResults) {
            if (![message.content isKindOfClass:[WKFileContent class]]) {
                continue;
            }
            WKFileContent *fileContent = (WKFileContent *)message.content;
            WKChannel *channel = message.channel;
            uint32_t orderSeq = message.orderSeq;

            [fileItems addObject:@{
                @"class": WKSearchMessageModel.class,
                @"channel": channel,
                @"keyword": kw,
                @"content": fileContent.name ?: @"",
                @"messageCount": @(1),
                @"timestamp": @(message.timestamp),
                @"showBottomLine": @(NO),
                @"showTopLine": @(NO),
                @"onClick": ^{
                    WKConversationVC *vc = [[WKConversationVC alloc] init];
                    vc.channel = channel;
                    vc.locationAtOrderSeq = orderSeq;
                    [[WKNavigationManager shared] pushViewController:vc animated:YES];
                }
            }];
        }

        [items addObject:@{
            @"height": WKSectionHeight,
            @"items": fileItems,
        }];
    }

    // messages (API results)
    if(messages && messages.count>0 && ![self.tabType isEqualToString:@"media"]) {
        if(![self.tabType isEqualToString:@"file"] && ![self searchInChannel]) {
            [items addObject: @{
                @"class":WKSearchHeaderModel.class,
                @"title":LLang(@"聊天记录"),
                @"showBottomLine":@(NO),

            }];
        }

        NSMutableArray<NSDictionary*> *messagesItems = [NSMutableArray array];
        for (NSInteger i=0; i<messages.count; i++) {
            NSDictionary *message = messages[i];
            
          
            NSString *content = @"";
            NSString *channelId = @"";
            NSString *fromUid = @"";
            NSNumber *channelType = @(0);
            NSNumber *timestamp = message[@"timestamp"]?:@(0);
            if(message[@"channel"] && message[@"channel"] != [NSNull null]) {
                channelId = message[@"channel"][@"channel_id"];
                channelType = message[@"channel"][@"channel_type"];
            }
            
            NSNumber *messageSeq = message[@"message_seq"]?:@(0);
            NSDictionary *payload = message[@"payload"];
            fromUid = message[@"from_uid"];
            NSNumber *contentType = @(0);
            if(payload) {
                contentType = payload[@"type"];
            }
           
            
            WKMessageContent *messageContent = [WKSDK.shared.chatManager getMessageContent:contentType.intValue];
            if(payload) {
                NSString *payloadStr = [WKJsonUtil toJson:payload];
                [messageContent decode:[payloadStr dataUsingEncoding:NSUTF8StringEncoding]];
            }
            
            content = [messageContent conversationDigest];
            
            
            // 文件由文件服务提供item视图
            if([self.tabType isEqualToString:@"file"]) {
                NSMutableDictionary *param = [NSMutableDictionary dictionary];
                param[@"message"] = message;
                param[@"content"] = messageContent;
                NSDictionary *itemDict = [WKApp.shared invoke:WKPOINT_SEARCH_ITEM_FILE param:param];
                if(itemDict) {
                    [messagesItems addObject:itemDict];
                }
                continue;
            }
            
            WKChannel *channel = [WKChannel channelID:channelId channelType:channelType.integerValue];
            
            WKChannel *requestChannel = channel;
            if([self searchInChannel]) {
                requestChannel = [WKChannel personWithChannelID:fromUid];
            }
            
            if([WKSDK.shared isSystemMessage:contentType.integerValue]) {
                content = LLang(@"[系统消息]");
                requestChannel = channel;
            }
            
           
            
            
            NSString *msgHomeSpaceId   = [self firstNonEmptyString:@[message[@"from_home_space_id"]?:@"",
                                                                      (message[@"channel"]&&message[@"channel"]!=[NSNull null])?(message[@"channel"][@"home_space_id"]?:@""):@""]];
            NSString *msgHomeSpaceName = [self firstNonEmptyString:@[message[@"from_home_space_name"]?:@"",
                                                                      (message[@"channel"]&&message[@"channel"]!=[NSNull null])?(message[@"channel"][@"home_space_name"]?:@""):@""]];
            NSString *msgSrcSpaceName  = [self firstNonEmptyString:@[message[@"from_source_space_name"]?:@"",
                                                                      message[@"source_space_name"]?:@""]];
            NSNumber *msgIsExternal    = message[@"from_is_external"]?:(message[@"is_external"]?:@(0));

            [messagesItems addObject:@{
                @"class":WKSearchMessageModel.class,
                @"channel":requestChannel,
                @"keyword": @"",
                @"content": content?:@"",
                @"timestamp":timestamp,
                @"showBottomLine":@(NO),
                @"showTopLine":@(NO),
                @"bottomLeftSpace":@(0.0),
                // 外部群/发送者 @SpaceName：消息级 from_home_space_* 优先
                // （sender 维度），回退 channel 级 home_space_* （会话维度），最后
                // legacy is_external / source_space_name。三端字段契约一致。
                @"home_space_id": msgHomeSpaceId?:@"",
                @"home_space_name": msgHomeSpaceName?:@"",
                @"is_external": msgIsExternal,
                @"source_space_name": msgSrcSpaceName?:@"",
                @"onClick":^{
                WKConversationVC *vc = [[WKConversationVC alloc] init];
                vc.channel = channel;
                vc.locationAtOrderSeq = [WKSDK.shared.chatManager getOrderSeq:messageSeq.unsignedLongLongValue];
                [[WKNavigationManager shared] pushViewController:vc animated:YES];
            }
            }];
        }
        
        
        [items addObject:@{
            @"height":WKSectionHeight,
            @"items":messagesItems,
        }];
    }
    
    // meida
    if(messages && messages.count>0 && [self.tabType isEqualToString:@"media"]) {
        NSMutableArray<NSMutableArray<NSDictionary*>*> *messageGroups = [NSMutableArray array]; // 消息分组
        NSInteger numOfRow = 3; // 每行数量
        
        NSInteger i =1;
        NSMutableArray<NSDictionary*> *rows = [NSMutableArray array];

        for (NSDictionary *message in messages) {
            [rows addObject:message];
            if(i%numOfRow == 0) {
                [messageGroups addObject:rows];
                rows = [NSMutableArray array];
            }
            i++;
        }
        if(messages.count%numOfRow!=0) {
            [messageGroups addObject:rows];
        }
        
        NSMutableArray *mediaItems = [NSMutableArray array];
        for (NSMutableArray<NSDictionary*> *rows in messageGroups) {
            
            NSMutableArray<WKSearchMediaItem*> *items = [NSMutableArray array];
            for (NSDictionary *message in rows) {
                NSDictionary *payload = message[@"payload"];
                if(!payload) {
                    continue;
                }
                NSNumber *contentType = @(0);
                if(payload) {
                    contentType = payload[@"type"];
                }
                NSURL *url = [[WKApp shared] getImageFullUrl:payload[@"url"]];
                
                WKSearchMediaItem *item = [[WKSearchMediaItem alloc] init];
                item.url = url.absoluteString;
                if(contentType.intValue == WK_SMALLVIDEO) {
                    item.type = @"video";
                }
                NSMutableDictionary *extra = [NSMutableDictionary dictionary];
                extra[@"message"] = message;
                item.extra = extra;
                [items addObject:item];
            }
            
            [mediaItems addObject:@{
                @"class":WKSearchMediaModel.class,
                @"items": items,
                @"numOfRow": @(numOfRow),
            }];
        }
        
        [items addObject:@{
            @"height":WKSectionHeight,
            @"items":mediaItems,
        }];
        
    }
        
    return items;
}

// 帮助方法：将后端返回的 home_space_id / home_space_name / is_external /
// source_space_name 字段透传到 cell model dict。字段全部可选，缺失保留 nil → cell
// 侧 resolver 判定为非外部，向后兼容。"不改搜索逻辑本身" 硬约束：此方法只负责
// 字段拷贝，不做任何业务判断。
- (void)applyExternalFieldsTo:(NSMutableDictionary *)item from:(NSDictionary *)raw {
    if (!item || !raw) return;
    id homeId   = raw[@"home_space_id"];
    id homeName = raw[@"home_space_name"];
    id isExt    = raw[@"is_external"];
    id srcName  = raw[@"source_space_name"];
    if (homeId   && homeId   != [NSNull null]) item[@"home_space_id"]   = homeId;
    if (homeName && homeName != [NSNull null]) item[@"home_space_name"] = homeName;
    if (isExt    && isExt    != [NSNull null]) item[@"is_external"]     = isExt;
    if (srcName  && srcName  != [NSNull null]) item[@"source_space_name"] = srcName;
}

// 返回候选字符串数组中第一个非空字符串；全空返回 nil。messages 场景用于
// "sender-level 优先，channel-level 回退" 的字段优先级解析。
- (nullable NSString *)firstNonEmptyString:(NSArray *)candidates {
    for (id s in candidates) {
        if ([s isKindOfClass:[NSString class]] && ((NSString *)s).length > 0) {
            return (NSString *)s;
        }
    }
    return nil;
}


-(void) requestSearch:(NSDictionary*)param callback:(void (^)(NSError * _Nullable error,NSDictionary * _Nullable))callback{
    
    NSMutableDictionary *request = [NSMutableDictionary dictionaryWithDictionary:param];
    if(!request[@"limit"]) {
        request[@"limit"] = @(20);
    }
    
    // Space 模式下 space_id 作为 URL query 参数传递（与 Web 端一致）
    NSString *searchPath = @"search/global";
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (spaceId && spaceId.length > 0) {
        NSString *encoded = [spaceId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        searchPath = [NSString stringWithFormat:@"search/global?space_id=%@", encoded];
    }

    [WKAPIClient.sharedClient POST:searchPath parameters:request].then(^(NSDictionary*result){
        if(callback) {
            callback(nil,result);
        }
    }).catch(^(NSError *error){
        if(callback) {
            callback(error,nil);
        }
    });
}
@end
