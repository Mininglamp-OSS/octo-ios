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
#define WKSearchMaxCount 4

@interface WKGlobalSearchVM ()

@property(nonatomic,strong) NSDictionary *searchResult;

@property(nonatomic,assign) NSInteger page;
@property(nonatomic,assign) NSInteger limit;
@property(nonatomic,assign) BOOL pullup; // 是否pullup中
@property(nonatomic,assign) BOOL hasMore;// 是否有更多数据
@property(nonatomic,copy) NSString *tabType;
@property(nonatomic,strong) NSArray<WKChannelMessageSearchResult*> *localMessageSearchResults;

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

    // 聊天 tab：从本地会话列表中按名称过滤
    if ([self.tabType isEqualToString:@"all"] && !self.searchInChannel) {
        [self searchLocalConversations];
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

/// 聊天 tab：从本地会话列表按名称过滤 + 从本地 DB 按消息内容搜索
- (void)searchLocalConversations {
    NSString *keyword = self.keyword;
    if (!keyword || keyword.length == 0) {
        self.searchResult = @{@"friends":@[], @"groups":@[], @"messages":@[]};
        self.localMessageSearchResults = nil;
        return;
    }

    // 1) 按会话名称匹配
    NSArray<WKConversationWrapModel*> *allConversations = [[WKConversationListVM shared] conversationList];
    NSMutableArray *matchedFriends = [NSMutableArray array];
    NSMutableArray *matchedGroups = [NSMutableArray array];

    for (WKConversationWrapModel *conv in allConversations) {
        NSString *displayName = conv.channelInfo ? conv.channelInfo.displayName : @"";
        if (!displayName || [displayName rangeOfString:keyword options:NSCaseInsensitiveSearch].location == NSNotFound) {
            continue;
        }
        NSDictionary *item = @{
            @"channel_id": conv.channel.channelId ?: @"",
            @"channel_name": displayName,
            @"channel_remark": @"",
            @"channel_type": @(conv.channel.channelType),
        };
        if (conv.channel.channelType == WK_GROUP) {
            [matchedGroups addObject:item];
        } else {
            [matchedFriends addObject:item];
        }
    }

    // 2) 按消息内容搜索（本地 DB）
    NSArray<WKChannelMessageSearchResult*> *msgResults = [[WKChannelInfoDB shared] searchChannelMessageWithKeyword:keyword limit:50];
    self.localMessageSearchResults = msgResults;

    self.searchResult = @{
        @"friends": matchedFriends,
        @"groups": matchedGroups,
        @"messages": @[],
    };
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
            [friendItems addObject:@{
                      @"class":WKSearchContactsModel.class,
                      @"name":name,
                      @"avatar":[WKAvatarUtil getAvatar:uid],
                      @"keyword": @"",
                      @"showBottomLine":@(NO),
                      @"showTopLine":@(NO),
                      @"onClick":^{
                        [[WKApp shared] invoke:WKPOINT_USER_INFO param:@{@"uid":uid}];
                      }
                   }];
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
            [groupsItems addObject:@{
               @"class":WKSearchContactsModel.class,
               @"name":name?:@"",
               @"avatar":[WKAvatarUtil getGroupAvatar:groupNo],
               @"keyword": @"",
               @"showBottomLine":@(NO),
               @"showTopLine":@(NO),
               @"onClick":^{
                [[WKApp shared] pushConversation:[WKChannel groupWithChannelID:groupNo]];
            }
            }];
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
            NSString *searchableWord = result.searchableWord ?: @"";

            // 截取关键词周围的上下文片段用于预览
            NSString *snippet = [self snippetFromText:searchableWord keyword:kw maxLength:40];

            if (result.messageCount == 1) {
                // 单条命中 → 显示消息预览，点击直接跳到该消息
                uint32_t orderSeq = result.orderSeq;
                [msgItems addObject:@{
                    @"class": WKSearchMessageModel.class,
                    @"channel": ch,
                    @"keyword": kw,
                    @"content": snippet,
                    @"messageCount": @(1),
                    @"timestamp": @(0),
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
            
           
            
            
            [messagesItems addObject:@{
                @"class":WKSearchMessageModel.class,
                @"channel":requestChannel,
                @"keyword": @"",
                @"content": content?:@"",
                @"timestamp":timestamp,
                @"showBottomLine":@(NO),
                @"showTopLine":@(NO),
                @"bottomLeftSpace":@(0.0),
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
