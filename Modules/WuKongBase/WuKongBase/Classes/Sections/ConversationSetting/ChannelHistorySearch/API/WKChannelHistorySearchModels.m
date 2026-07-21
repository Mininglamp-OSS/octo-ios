//
//  WKChannelHistorySearchModels.m
//  WuKongBase
//

#import "WKChannelHistorySearchModels.h"

#pragma mark - Helpers

static NSString * _Nullable WKCHS_String(id _Nullable v) {
    if ([v isKindOfClass:[NSString class]]) return (NSString *)v;
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v stringValue];
    return nil;
}

static NSInteger WKCHS_Int(id _Nullable v) {
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v integerValue];
    if ([v isKindOfClass:[NSString class]]) return [(NSString *)v integerValue];
    return 0;
}

static long long WKCHS_Int64(id _Nullable v) {
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v longLongValue];
    if ([v isKindOfClass:[NSString class]]) return [(NSString *)v longLongValue];
    return 0;
}

static NSArray<NSDictionary *> * _Nullable WKCHS_Array(id _Nullable v) {
    if ([v isKindOfClass:[NSArray class]]) return (NSArray *)v;
    return nil;
}

static NSDictionary * _Nullable WKCHS_Dict(id _Nullable v) {
    if ([v isKindOfClass:[NSDictionary class]]) return (NSDictionary *)v;
    return nil;
}

/// 把 sent_at 规整成秒级 NSTimeInterval。兼容三种格式：
///   - 整数 / 字符串数字：>= 1e12 视为毫秒，否则秒。
///   - ISO8601 字符串：用静态 formatter 解析。
static NSTimeInterval WKCHS_ParseTimestamp(id _Nullable v) {
    if (!v || v == [NSNull null]) return 0;
    if ([v isKindOfClass:[NSNumber class]]) {
        double n = [(NSNumber *)v doubleValue];
        return n >= 1e12 ? n / 1000.0 : n;
    }
    if ([v isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)v;
        if (s.length == 0) return 0;
        // 纯数字串
        BOOL allDigits = YES;
        for (NSUInteger i = 0; i < s.length; i++) {
            unichar c = [s characterAtIndex:i];
            if (!((c >= '0' && c <= '9') || c == '.')) { allDigits = NO; break; }
        }
        if (allDigits) {
            double n = [s doubleValue];
            return n >= 1e12 ? n / 1000.0 : n;
        }
        // ISO8601
        static NSISO8601DateFormatter *fmt = nil;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            fmt = [NSISO8601DateFormatter new];
            fmt.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        });
        NSDate *d = [fmt dateFromString:s];
        if (!d) {
            // 兼容不带毫秒
            NSISO8601DateFormatter *fmt2 = [NSISO8601DateFormatter new];
            fmt2.formatOptions = NSISO8601DateFormatWithInternetDateTime;
            d = [fmt2 dateFromString:s];
        }
        return d ? d.timeIntervalSince1970 : 0;
    }
    return 0;
}

/// 把 message_kind 字符串映射为枚举。
static WKChannelHistorySearchMessageKind WKCHS_ParseMessageKind(NSString * _Nullable s) {
    if ([s isEqualToString:@"forward"]) return WKChannelHistorySearchMessageKindForward;
    if ([s isEqualToString:@"quote"]) return WKChannelHistorySearchMessageKindQuote;
    if ([s isEqualToString:@"image"]) return WKChannelHistorySearchMessageKindImage;
    if ([s isEqualToString:@"video"]) return WKChannelHistorySearchMessageKindVideo;
    if ([s isEqualToString:@"rich_text"]) return WKChannelHistorySearchMessageKindRichText;
    return WKChannelHistorySearchMessageKindText;
}

static WKChannelHistorySearchMediaKind WKCHS_ParseMediaKind(NSString * _Nullable s) {
    if ([s isEqualToString:@"video"]) return WKChannelHistorySearchMediaKindVideo;
    return WKChannelHistorySearchMediaKindImage;
}

#pragma mark - Filter

@implementation WKChannelHistorySearchFilter

- (instancetype)init {
    self = [super init];
    if (self) {
        _sort = WKChannelHistorySearchSortTimeDesc;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    WKChannelHistorySearchFilter *c = [[[self class] allocWithZone:zone] init];
    c.senderUids = [self.senderUids copy];
    c.startDate = self.startDate;
    c.endDate = self.endDate;
    c.sort = self.sort;
    c.contentTypes = [self.contentTypes copy];
    c.fileExts = [self.fileExts copy];
    c.memberUids = [self.memberUids copy];
    c.channels = [self.channels copy];
    c.channelTypes = [self.channelTypes copy];
    return c;
}

- (BOOL)hasEffectiveFilters {
    if (self.senderUids.count > 0) return YES;
    if (self.startDate) return YES;
    if (self.endDate) return YES;
    if (self.contentTypes.count > 0) return YES;
    if (self.fileExts.count > 0) return YES;
    if (self.memberUids.count > 0) return YES;
    if (self.channels.count > 0) return YES;
    if (self.channelTypes.count > 0) return YES;
    return NO;
}

- (BOOL)hasAnyFilter {
    if ([self hasEffectiveFilters]) return YES;
    return self.sort != WKChannelHistorySearchSortTimeDesc;
}

- (NSDictionary *)toApiDict {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (self.senderUids.count > 0) {
        NSUInteger n = MIN(self.senderUids.count, (NSUInteger)50);
        d[@"sender_ids"] = [self.senderUids subarrayWithRange:NSMakeRange(0, n)];
    }
    static NSDateFormatter *fmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [NSDateFormatter new];
        fmt.dateFormat = @"yyyy-MM-dd";
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        fmt.timeZone = [NSTimeZone localTimeZone];
    });
    if (self.startDate) d[@"sent_at_from"] = [fmt stringFromDate:self.startDate];
    if (self.endDate) d[@"sent_at_to"] = [fmt stringFromDate:self.endDate];
    if (self.contentTypes.count > 0) d[@"content_types"] = self.contentTypes;
    if (self.fileExts.count > 0) {
        // 服务端 _search_global_files 用 file_exts（小写不含点）。
        NSMutableArray<NSString *> *exts = [NSMutableArray array];
        for (NSString *e in self.fileExts) {
            if (![e isKindOfClass:[NSString class]] || e.length == 0) continue;
            [exts addObject:[e lowercaseString]];
        }
        if (exts.count > 0) d[@"file_exts"] = exts;
    }
    // 全局：包含成员 / 所在群聊或子区 / 聊天类型
    if (self.memberUids.count > 0) {
        NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSet];
        for (NSString *uid in self.memberUids) {
            if ([uid isKindOfClass:[NSString class]] && uid.length > 0) [set addObject:uid];
        }
        NSUInteger n = MIN(set.count, (NSUInteger)50);
        if (n > 0) d[@"member_uids"] = [[set array] subarrayWithRange:NSMakeRange(0, n)];
    }
    if (self.channels.count > 0) {
        NSMutableArray *arr = [NSMutableArray array];
        for (NSDictionary *c in self.channels) {
            if (![c isKindOfClass:[NSDictionary class]]) continue;
            NSString *cid = c[@"channel_id"];
            if (![cid isKindOfClass:[NSString class]] || cid.length == 0) continue;
            [arr addObject:@{ @"channel_id": cid, @"channel_type": @([c[@"channel_type"] integerValue]) }];
        }
        if (arr.count > 0) d[@"channel_ids"] = arr;
    }
    if (self.channelTypes.count > 0) {
        NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSet];
        for (NSNumber *t in self.channelTypes) {
            if ([t isKindOfClass:[NSNumber class]]) [set addObject:t];
        }
        if (set.count > 0) d[@"channel_types"] = [set array];
    }
    return d;
}

@end

#pragma mark - Item

@implementation WKChannelHistorySearchItem

- (BOOL)canLocate {
    return self.messageSeq > 0;
}

#pragma mark 公共字段填充

- (void)applyCommonFromDict:(NSDictionary *)dict
              fallbackChannelId:(nullable NSString *)fallbackChannelId
            fallbackChannelType:(NSInteger)fallbackChannelType {
    self.messageId = WKCHS_String(dict[@"message_id"]);
    self.messageSeq = WKCHS_Int(dict[@"message_seq"]);
    self.senderId = WKCHS_String(dict[@"sender_id"]);
    self.senderName = WKCHS_String(dict[@"sender_name"]);
    self.senderAvatarUrl = WKCHS_String(dict[@"sender_avatar_url"]);
    self.timestamp = WKCHS_ParseTimestamp(dict[@"sent_at"]);
    NSString *cid = WKCHS_String(dict[@"channel_id"]);
    self.channelId = cid.length > 0 ? cid : fallbackChannelId;
    NSInteger ct = WKCHS_Int(dict[@"channel_type"]);
    self.channelType = ct > 0 ? ct : fallbackChannelType;
}

+ (instancetype)messageItemFromDict:(NSDictionary *)dict
                       fallbackChannelId:(nullable NSString *)fallbackChannelId
                     fallbackChannelType:(NSInteger)fallbackChannelType {
    WKChannelHistorySearchItem *it = [WKChannelHistorySearchItem new];
    it.kind = WKChannelHistorySearchItemKindMessage;
    [it applyCommonFromDict:dict
              fallbackChannelId:fallbackChannelId
            fallbackChannelType:fallbackChannelType];
    it.messageKind = WKCHS_ParseMessageKind(WKCHS_String(dict[@"message_kind"]));
    it.snippet = WKCHS_String(dict[@"snippet"]);
    it.matchReason = WKCHS_String(dict[@"match_reason"]);
    // 合并转发 outer_preview
    NSDictionary *outer = WKCHS_Dict(dict[@"outer_preview"]);
    if (outer) {
        it.forwardTitle = WKCHS_String(outer[@"title"]);
        it.forwardChildCount = WKCHS_Int(outer[@"child_count"]);
        NSDictionary *quoted = WKCHS_Dict(outer[@"quoted"]);
        if (quoted) {
            it.quotedSenderName = WKCHS_String(quoted[@"sender_name"]);
            NSString *qt = WKCHS_String(quoted[@"text"]);
            if (qt.length == 0) qt = WKCHS_String(quoted[@"placeholder"]);
            it.quotedText = qt;
        }
    }
    it.innerMessages = WKCHS_Array(dict[@"inner_messages"]);
    // rich_text.plain 兜底 (与 web hit.rich_text.plain 同口径)
    NSDictionary *richText = WKCHS_Dict(dict[@"rich_text"]);
    if (richText) {
        it.richTextPlain = WKCHS_String(richText[@"plain"]);
        // plain 也没有时, 拼所有 content[].text 作为二次兜底
        if (it.richTextPlain.length == 0) {
            NSArray *blocks = WKCHS_Array(richText[@"content"]);
            if (blocks.count > 0) {
                NSMutableString *joined = [NSMutableString string];
                for (NSDictionary *b in blocks) {
                    if (![b isKindOfClass:[NSDictionary class]]) continue;
                    NSString *t = WKCHS_String(b[@"text"]);
                    if (t.length > 0) [joined appendString:t];
                }
                if (joined.length > 0) it.richTextPlain = joined;
            }
        }
    }
    // 富文本/图片消息可能带 thumb_url / 尺寸
    it.thumbUrl = WKCHS_String(dict[@"thumb_url"]);
    it.width = WKCHS_Int(dict[@"width"]);
    it.height = WKCHS_Int(dict[@"height"]);
    it.durationMs = WKCHS_Int(dict[@"duration_ms"]);
    return it;
}

+ (instancetype)mediaItemFromDict:(NSDictionary *)dict
                     fallbackChannelId:(nullable NSString *)fallbackChannelId
                   fallbackChannelType:(NSInteger)fallbackChannelType {
    WKChannelHistorySearchItem *it = [WKChannelHistorySearchItem new];
    it.kind = WKChannelHistorySearchItemKindMedia;
    [it applyCommonFromDict:dict
              fallbackChannelId:fallbackChannelId
            fallbackChannelType:fallbackChannelType];
    it.mediaKind = WKCHS_ParseMediaKind(WKCHS_String(dict[@"media_kind"]));
    it.thumbUrl = WKCHS_String(dict[@"thumb_url"]);
    // 大文件原始 URL — 服务端字段名因接口/版本有差异, 尽量穷举常见命名以提高命中率。
    // 命中顺序: 严格的 url / media_url → 按 kind 区分的 image_url / video_url
    // → 流式播放专用 play_url / m3u8_url → 通用 file_url / source_url
    // → 兜底 download_url。
    NSString *url = WKCHS_String(dict[@"url"]);
    if (url.length == 0) url = WKCHS_String(dict[@"media_url"]);
    if (url.length == 0) {
        if (it.mediaKind == WKChannelHistorySearchMediaKindVideo) {
            url = WKCHS_String(dict[@"video_url"]);
            if (url.length == 0) url = WKCHS_String(dict[@"play_url"]);
            if (url.length == 0) url = WKCHS_String(dict[@"m3u8_url"]);
        } else {
            url = WKCHS_String(dict[@"image_url"]);
            if (url.length == 0) url = WKCHS_String(dict[@"img_url"]);
        }
    }
    if (url.length == 0) url = WKCHS_String(dict[@"file_url"]);
    if (url.length == 0) url = WKCHS_String(dict[@"source_url"]);
    if (url.length == 0) url = WKCHS_String(dict[@"download_url"]);
    it.originalUrl = url;
    it.previewUrl = WKCHS_String(dict[@"preview_url"]);
    it.width = WKCHS_Int(dict[@"width"]);
    it.height = WKCHS_Int(dict[@"height"]);
    it.durationMs = WKCHS_Int(dict[@"duration_ms"]);
    it.monthBucket = WKCHS_String(dict[@"month_bucket"]);
    return it;
}

+ (instancetype)fileItemFromDict:(NSDictionary *)dict
                    fallbackChannelId:(nullable NSString *)fallbackChannelId
                  fallbackChannelType:(NSInteger)fallbackChannelType {
    WKChannelHistorySearchItem *it = [WKChannelHistorySearchItem new];
    it.kind = WKChannelHistorySearchItemKindFile;
    [it applyCommonFromDict:dict
              fallbackChannelId:fallbackChannelId
            fallbackChannelType:fallbackChannelType];
    it.fileName = WKCHS_String(dict[@"file_name"]);
    it.fileSizeBytes = WKCHS_Int64(dict[@"file_size_bytes"]);
    it.fileExt = WKCHS_String(dict[@"file_ext"]);
    it.fileDownloadUrl = WKCHS_String(dict[@"download_url"]);
    it.filePreviewUrl = WKCHS_String(dict[@"preview_url"]);
    return it;
}

+ (nullable instancetype)combinedItemFromDict:(NSDictionary *)dict
                                  fallbackChannelId:(nullable NSString *)fallbackChannelId
                                fallbackChannelType:(NSInteger)fallbackChannelType {
    NSString *rt = WKCHS_String(dict[@"result_type"]);
    NSString *sortedAt = WKCHS_String(dict[@"sorted_at"]);
    WKChannelHistorySearchItem *it = nil;
    if ([rt isEqualToString:@"message"]) {
        NSDictionary *m = WKCHS_Dict(dict[@"message"]);
        if (m) it = [self messageItemFromDict:m
                              fallbackChannelId:fallbackChannelId
                            fallbackChannelType:fallbackChannelType];
    } else if ([rt isEqualToString:@"file"]) {
        NSDictionary *m = WKCHS_Dict(dict[@"file"]);
        if (m) it = [self fileItemFromDict:m
                            fallbackChannelId:fallbackChannelId
                          fallbackChannelType:fallbackChannelType];
    } else if ([rt isEqualToString:@"media"]) {
        NSDictionary *m = WKCHS_Dict(dict[@"media"]);
        if (m) it = [self mediaItemFromDict:m
                            fallbackChannelId:fallbackChannelId
                          fallbackChannelType:fallbackChannelType];
    }
    if (it) it.sortedAtRaw = sortedAt;
    return it;
}

@end

#pragma mark - Page

@implementation WKChannelHistorySearchPage

+ (instancetype)pageFromResponse:(id)response
                              tab:(WKChannelHistorySearchTab)tab
                     channelId:(nullable NSString *)channelId
                   channelType:(NSInteger)channelType {
    WKChannelHistorySearchPage *page = [WKChannelHistorySearchPage new];
    page.items = @[];
    page.hasMore = NO;
    page.nextCursor = nil;

    NSArray *rawList = nil;
    if ([response isKindOfClass:[NSArray class]]) {
        rawList = response;
    } else if ([response isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)response;
        // 兼容 data / items / list 几种命名（web 用 data，旧接口用 items / list）
        id list = dict[@"data"];
        if (![list isKindOfClass:[NSArray class]]) list = dict[@"items"];
        if (![list isKindOfClass:[NSArray class]]) list = dict[@"list"];
        if ([list isKindOfClass:[NSArray class]]) rawList = list;
        NSDictionary *pg = WKCHS_Dict(dict[@"pagination"]);
        if (pg) {
            id hm = pg[@"has_more"];
            page.hasMore = [hm respondsToSelector:@selector(boolValue)] ? [hm boolValue] : NO;
            page.nextCursor = WKCHS_String(pg[@"next_cursor"]);
        } else {
            // 兼容旧风格 has_more / next_cursor 直接挂在外层
            id hm = dict[@"has_more"];
            if ([hm respondsToSelector:@selector(boolValue)]) page.hasMore = [hm boolValue];
            NSString *nc = WKCHS_String(dict[@"next_cursor"]);
            if (nc.length > 0) page.nextCursor = nc;
        }
    }

    if (![rawList isKindOfClass:[NSArray class]]) {
        return page;
    }
    NSMutableArray<WKChannelHistorySearchItem *> *items = [NSMutableArray arrayWithCapacity:rawList.count];
    for (NSDictionary *dict in rawList) {
        if (![dict isKindOfClass:[NSDictionary class]]) continue;
        WKChannelHistorySearchItem *it = nil;
        switch (tab) {
            case WKChannelHistorySearchTabAll:
                it = [WKChannelHistorySearchItem combinedItemFromDict:dict
                                                  fallbackChannelId:channelId
                                                fallbackChannelType:channelType];
                break;
            case WKChannelHistorySearchTabMessage:
                it = [WKChannelHistorySearchItem messageItemFromDict:dict
                                                 fallbackChannelId:channelId
                                               fallbackChannelType:channelType];
                break;
            case WKChannelHistorySearchTabMedia:
                it = [WKChannelHistorySearchItem mediaItemFromDict:dict
                                               fallbackChannelId:channelId
                                             fallbackChannelType:channelType];
                break;
            case WKChannelHistorySearchTabFile:
                it = [WKChannelHistorySearchItem fileItemFromDict:dict
                                              fallbackChannelId:channelId
                                            fallbackChannelType:channelType];
                break;
        }
        if (it) [items addObject:it];
    }
    page.items = items;
    return page;
}

@end
