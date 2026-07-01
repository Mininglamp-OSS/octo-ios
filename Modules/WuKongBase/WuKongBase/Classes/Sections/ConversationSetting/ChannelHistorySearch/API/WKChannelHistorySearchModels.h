//
//  WKChannelHistorySearchModels.h
//  WuKongBase
//
//  频道内"查找聊天内容" — 数据模型与枚举。与 web 端
//  packages/dmworkbase/src/Components/ChannelSearch/types.ts / apiAdapter.ts 同口径。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 顶部 tab — 与 web 端 ChannelSearchTab 一一对应。
typedef NS_ENUM(NSInteger, WKChannelHistorySearchTab) {
    WKChannelHistorySearchTabAll = 0,     // 全部           messages/_search_all
    WKChannelHistorySearchTabMessage,     // 聊天记录       messages/_search
    WKChannelHistorySearchTabMedia,       // 图片视频       messages/_search_media
    WKChannelHistorySearchTabFile,        // 文件           messages/_search_files
};

typedef NS_ENUM(NSInteger, WKChannelHistorySearchItemKind) {
    WKChannelHistorySearchItemKindMessage = 0,
    WKChannelHistorySearchItemKindMedia,
    WKChannelHistorySearchItemKindFile,
};

typedef NS_ENUM(NSInteger, WKChannelHistorySearchMessageKind) {
    WKChannelHistorySearchMessageKindText = 0,
    WKChannelHistorySearchMessageKindForward,
    WKChannelHistorySearchMessageKindQuote,
    WKChannelHistorySearchMessageKindImage,
    WKChannelHistorySearchMessageKindVideo,
    WKChannelHistorySearchMessageKindRichText,
};

typedef NS_ENUM(NSInteger, WKChannelHistorySearchMediaKind) {
    WKChannelHistorySearchMediaKindImage = 0,
    WKChannelHistorySearchMediaKindVideo,
};

typedef NS_ENUM(NSInteger, WKChannelHistorySearchSort) {
    WKChannelHistorySearchSortTimeDesc = 0,  // 时间倒序（默认）
    WKChannelHistorySearchSortTimeAsc,       // 时间正序
};

#pragma mark - Filter

/// 筛选条件（草稿 / 已应用通用）。
/// 与 web ChannelSearchFilters 同口径: senderUids / startAt / endAt / sort。
@interface WKChannelHistorySearchFilter : NSObject <NSCopying>

/// 选中的发送人 uid 列表（最多 50，符合服务端约束）。
@property (nonatomic, copy, nullable) NSArray<NSString *> *senderUids;
/// 起止日期（精度到天）。为空表示不限制。
@property (nonatomic, strong, nullable) NSDate *startDate;
@property (nonatomic, strong, nullable) NSDate *endDate;
/// 排序方式，默认时间倒序。
@property (nonatomic, assign) WKChannelHistorySearchSort sort;

/// 是否有任何生效筛选条件（任一字段非空且 sort != desc 时也算）。
- (BOOL)hasAnyFilter;
/// 仅看是否有发送人/日期的"硬"筛选（用于 shouldRunSearch 判定）。
- (BOOL)hasEffectiveFilters;

/// 序列化为 API 请求体 `filters` 字段。日期会被格式化为 `yyyy-MM-dd`。
- (NSDictionary *)toApiDict;

@end

#pragma mark - Item

/// 单条命中项。覆盖三种 kind：message / media / file。
/// "全部" tab 服务端返回 combined hit，其中 result_type 决定 kind，
/// 真正字段在 message / media / file 子字典里 —— combinedItemFromDict: 已处理。
@interface WKChannelHistorySearchItem : NSObject

@property (nonatomic, assign) WKChannelHistorySearchItemKind kind;

#pragma mark 公共字段
@property (nonatomic, copy, nullable) NSString *channelId;
@property (nonatomic, assign) NSInteger channelType;
@property (nonatomic, copy, nullable) NSString *messageId;
@property (nonatomic, assign) NSInteger messageSeq;
@property (nonatomic, copy, nullable) NSString *senderId;
@property (nonatomic, copy, nullable) NSString *senderName;
@property (nonatomic, copy, nullable) NSString *senderAvatarUrl;
/// 消息时间（秒）。若服务端 sent_at 为 ISO 字符串或毫秒，解析时统一规整为秒。
@property (nonatomic, assign) NSTimeInterval timestamp;
/// "全部" tab 中服务端排序键 sorted_at，前端不解析，仅透传供调试。
@property (nonatomic, copy, nullable) NSString *sortedAtRaw;

#pragma mark 消息字段
@property (nonatomic, assign) WKChannelHistorySearchMessageKind messageKind;
/// 摘要文本，可能包含 `<mark>关键词</mark>` 高亮标记。
@property (nonatomic, copy, nullable) NSString *snippet;
/// 命中理由（用于合并转发/富文本），优先于 snippet 展示一行说明。
@property (nonatomic, copy, nullable) NSString *matchReason;
/// 合并转发外层：标题
@property (nonatomic, copy, nullable) NSString *forwardTitle;
/// 合并转发外层：子条总数
@property (nonatomic, assign) NSInteger forwardChildCount;
/// 合并转发内层预览（最多展示前 N 条）
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *innerMessages;
/// 引用消息字段
@property (nonatomic, copy, nullable) NSString *quotedSenderName;
@property (nonatomic, copy, nullable) NSString *quotedText;
/// 富文本纯文本兜底 (rich_text.plain) —— 服务端对富文本/Markdown 消息, snippet 可能为空,
/// 真正带关键词的正文在 rich_text.plain 里 (与 web hit.snippet || hit.rich_text.plain 同口径)。
@property (nonatomic, copy, nullable) NSString *richTextPlain;

#pragma mark 媒体字段
@property (nonatomic, assign) WKChannelHistorySearchMediaKind mediaKind;
@property (nonatomic, copy, nullable) NSString *thumbUrl;
@property (nonatomic, copy, nullable) NSString *originalUrl; // url / image_url / video_url / media_url 中任一可用
@property (nonatomic, copy, nullable) NSString *previewUrl;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) NSInteger durationMs;
@property (nonatomic, copy, nullable) NSString *monthBucket; // e.g. "2026-06"

#pragma mark 文件字段
@property (nonatomic, copy, nullable) NSString *fileName;
@property (nonatomic, assign) long long fileSizeBytes;
@property (nonatomic, copy, nullable) NSString *fileExt;
@property (nonatomic, copy, nullable) NSString *fileDownloadUrl;
@property (nonatomic, copy, nullable) NSString *filePreviewUrl;

#pragma mark 工厂

/// 解析 messages/_search 返回的 hit dict。
+ (instancetype)messageItemFromDict:(NSDictionary *)dict
                       fallbackChannelId:(nullable NSString *)fallbackChannelId
                     fallbackChannelType:(NSInteger)fallbackChannelType;
/// 解析 messages/_search_media 返回的 hit dict。
+ (instancetype)mediaItemFromDict:(NSDictionary *)dict
                     fallbackChannelId:(nullable NSString *)fallbackChannelId
                   fallbackChannelType:(NSInteger)fallbackChannelType;
/// 解析 messages/_search_files 返回的 hit dict。
+ (instancetype)fileItemFromDict:(NSDictionary *)dict
                    fallbackChannelId:(nullable NSString *)fallbackChannelId
                  fallbackChannelType:(NSInteger)fallbackChannelType;
/// 解析 messages/_search_all 返回的 combined hit。dict 形如
/// `{ result_type: "message" | "file" | "media", sorted_at, message?:{...}, file?:{...}, media?:{...} }`。
/// 返回 nil 表示无法识别。
+ (nullable instancetype)combinedItemFromDict:(NSDictionary *)dict
                                  fallbackChannelId:(nullable NSString *)fallbackChannelId
                                fallbackChannelType:(NSInteger)fallbackChannelType;

/// 是否可"定位到聊天"。messageSeq > 0 即可。
- (BOOL)canLocate;

@end

#pragma mark - Page

/// 一页搜索结果（envelope: `{data: [...], pagination: {has_more, next_cursor}}` 兼容裸数组）。
@interface WKChannelHistorySearchPage : NSObject
@property (nonatomic, copy) NSArray<WKChannelHistorySearchItem *> *items;
@property (nonatomic, assign) BOOL hasMore;
@property (nonatomic, copy, nullable) NSString *nextCursor;

/// 解析 API 响应体。tab 决定如何映射每个 hit。
+ (instancetype)pageFromResponse:(id)response
                              tab:(WKChannelHistorySearchTab)tab
                     channelId:(nullable NSString *)channelId
                   channelType:(NSInteger)channelType;
@end

NS_ASSUME_NONNULL_END
