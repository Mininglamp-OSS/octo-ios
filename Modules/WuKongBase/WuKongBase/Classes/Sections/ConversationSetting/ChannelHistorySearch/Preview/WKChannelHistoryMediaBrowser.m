//
//  WKChannelHistoryMediaBrowser.m
//

#import "WKChannelHistoryMediaBrowser.h"
#import "WKChannelHistoryMediaBrowserToolbar.h"
#import "WKChannelHistoryFileDownloader.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import "WKImageBrowser.h"
#import "WKDefaultWebImageMediator.h"
#import "WKVideoBrowserData.h"
#import "WKImageContent.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <YBImageBrowser/YBImageBrowser.h>
#import <SDWebImage/SDWebImage.h>

@implementation WKChannelHistoryMediaBrowser

+ (BOOL)isVideoItemPlayable:(WKChannelHistorySearchItem *)it {
    if (it.mediaKind != WKChannelHistorySearchMediaKindVideo) return NO;
    NSString *raw = it.originalUrl.length > 0 ? it.originalUrl : it.previewUrl;
    if ([self resolveRemoteURL:raw]) return YES;
    if ([self fallbackVideoURLFromLocalMessage:it]) return YES;
    return NO;
}

/// 把服务端返回的 URL 字符串 (可能是完整 URL 也可能是相对路径) 规范化成可播放的 NSURL。
/// 与 web apiAdapter.normalizeFileUrl 同口径: 已经是 http(s) 就直接用, 否则拼上 apiBaseUrl
/// (WKApp.getImageFullUrl: 内部就是这个逻辑, 还会走 CDN 重写)。
+ (nullable NSURL *)resolveRemoteURL:(nullable NSString *)raw {
    NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) return nil;
    NSString *lower = [s lowercaseString];
    if ([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"]
        || [lower hasPrefix:@"data:"] || [lower hasPrefix:@"blob:"]
        || [lower hasPrefix:@"file:"]) {
        return [NSURL URLWithString:s];
    }
    // 相对路径 → 走 WKApp 的 CDN/apiBaseUrl 拼接 (与聊天气泡里点视频一致)
    return [[WKApp shared] getImageFullUrl:s];
}

/// 服务端 messages/_search_media 视频响应目前存在缺 URL 字段的情况 (只回
/// sender/sent_at/media_kind/message_seq/month_bucket)。用 messageSeq + channelId 反查
/// 本地 WKMessageDB, 从消息 content (小视频消息实际用 WKImageContent 承载)
/// 拿 remoteUrl, 让浏览器和聊天气泡里点视频走同一份数据源。
+ (nullable NSURL *)fallbackVideoURLFromLocalMessage:(WKChannelHistorySearchItem *)it {
    if (it.messageSeq <= 0 || it.channelId.length == 0) return nil;
    WKChannel *ch = [[WKChannel alloc] initWith:it.channelId channelType:it.channelType];
    WKMessage *msg = [[WKMessageDB shared] getMessage:ch messageSeq:(uint32_t)it.messageSeq];
    if (![msg.content isKindOfClass:[WKImageContent class]]) return nil;
    WKImageContent *imgc = (WKImageContent *)msg.content;
    if (imgc.remoteUrl.length == 0) return nil;
    return [[WKApp shared] getImageFullUrl:imgc.remoteUrl];
}

/// 视频项 → WKVideoBrowserData。download 块由 WKChannelHistoryFileDownloader 实现 (命中
/// tmp 缓存则秒回, 否则边下边播)。封面图先用 SDWebImage 预拉一次, 命中后赋值。
/// 返回 nil 表示连本地缓存都没有可播 URL —— 调用方会自动回退到 imageData 展示缩略图。
+ (nullable WKVideoBrowserData *)videoDataForItem:(WKChannelHistorySearchItem *)it {
    NSString *rawSrc = it.originalUrl.length > 0 ? it.originalUrl : it.previewUrl;
    NSURL *videoURL = [self resolveRemoteURL:rawSrc];
    // 服务端字段缺失时降级到 WKMessageDB
    if (!videoURL) videoURL = [self fallbackVideoURLFromLocalMessage:it];
    if (!videoURL) return nil;

    WKVideoBrowserData *vd = [WKVideoBrowserData new];
    vd.extraData = @{ @"channelHistoryItem": it };

    NSString *remoteUrl = videoURL.absoluteString;
    NSString *fileName = it.fileName.length > 0 ? it.fileName : nil;
    // download 块只会在 cell 真正展示时被调用一次。下载器内部对同 URL 做了 tmp 缓存,
    // 反复滑动同一条不会重复请求网络。
    vd.download = ^(void(^downCompleteBlock)(NSString *videoPath, NSError *error)) {
        [WKChannelHistoryFileDownloader downloadRemoteUrl:remoteUrl
                                                  fileName:fileName
                                                   onProgress:nil
                                                onComplete:^(NSURL *localURL, NSError *error) {
            if (downCompleteBlock) {
                downCompleteBlock(localURL.path ?: @"", error);
            }
        }];
    };

    // 预拉封面 (异步) — 拉到了就显示, 拉不到也不阻塞下载。
    NSURL *thumbURL = [self resolveRemoteURL:(it.thumbUrl.length > 0 ? it.thumbUrl : it.previewUrl)];
    if (thumbURL) {
        __weak WKVideoBrowserData *weakVd = vd;
        [[SDWebImageManager sharedManager]
         loadImageWithURL:thumbURL
         options:0
         progress:nil
         completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            if (image) weakVd.coverImage = image;
        }];
    }
    return vd;
}

/// 图片项 → YBIBImageData。可被视频项当回退路径调用 (优先吃 thumb_url, 因为视频缺
/// originalUrl 时 thumb_url 通常还在)。
+ (nullable YBIBImageData *)imageDataForItem:(WKChannelHistorySearchItem *)it {
    NSString *rawSrc = it.originalUrl.length > 0 ? it.originalUrl : it.previewUrl;
    if (rawSrc.length == 0) rawSrc = it.thumbUrl;
    NSURL *url = [self resolveRemoteURL:rawSrc];
    // 服务端 media hit 完全没 URL: 试试从本地消息 content 拿 remoteUrl
    if (!url) url = [self fallbackVideoURLFromLocalMessage:it]; // 同样能兜住图片消息
    if (!url) return nil;
    YBIBImageData *id_ = [YBIBImageData new];
    id_.imageURL = url;
    id_.extraData = @{ @"channelHistoryItem": it };
    id_.allowSaveToPhotoAlbum = YES;
    return id_;
}

/// 统一构造数据项。视频构造失败 (缺播放 URL) 自动回退为图片 (展示缩略图), 这样
/// dataSource 与 items 的位置 1:1 对齐, 永远不会出现「点视频却开到第一张图」的错位。
+ (nullable id<YBIBDataProtocol>)dataForItem:(WKChannelHistorySearchItem *)it {
    if (it.mediaKind == WKChannelHistorySearchMediaKindVideo) {
        WKVideoBrowserData *vd = [self videoDataForItem:it];
        if (vd) return vd;
    }
    return [self imageDataForItem:it];
}

+ (void)presentFromItems:(NSArray<WKChannelHistorySearchItem *> *)items
                tappedItem:(WKChannelHistorySearchItem *)tappedItem
                  onLocate:(void(^)(WKChannelHistorySearchItem *))onLocate {
    if (items.count == 0) return;

    NSMutableArray<id<YBIBDataProtocol>> *dataSource = [NSMutableArray arrayWithCapacity:items.count];
    NSInteger initial = -1;

    // 关键修复: initial 必须按 dataSource 的实际写入位置算, 不能用 items 下标。
    // dataForItem: 已经做了 video → image 的回退, 极少真正返回 nil (除非连 thumb 都没),
    // 因此 tappedItem 几乎一定能落进 dataSource。
    for (WKChannelHistorySearchItem *it in items) {
        if (it.kind != WKChannelHistorySearchItemKindMedia) continue;
        id<YBIBDataProtocol> data = [self dataForItem:it];
        if (!data) continue;
        if (tappedItem != nil && it == tappedItem) initial = dataSource.count;
        [dataSource addObject:data];
    }
    if (dataSource.count == 0) return;
    if (initial < 0) initial = 0; // tappedItem 自身被丢弃 / 未传, 兜底从首项开始

    // 使用 WKImageBrowser (项目封装的 YBImageBrowser 子类) — 必须配 webImageMediator 走
    // SDWebImage, 否则 YB 默认 mediator 找不到合适的 image loader 会闪退。
    // 关键差异 vs WKImageMessageCell: 这里不设 conversationContext (搜索场景没有会话上下文)。
    WKImageBrowser *browser = [[WKImageBrowser alloc] init];
    browser.webImageMediator = [WKDefaultWebImageMediator new];
    WKChannelHistoryMediaBrowserToolbar *toolbar = [WKChannelHistoryMediaBrowserToolbar new];
    toolbar.browser = browser;
    toolbar.onLocateItem = onLocate;
    toolbar.totalPages = dataSource.count;
    toolbar.initialPage = initial;
    // 用我们自己的 toolbar 替换默认。default toolbar 含分页指示/分享/等, 在搜索场景不需要。
    browser.toolViewHandlers = @[toolbar];
    // 把 toolbar 设为 browser delegate 以接收 pageChanged: — WKImageBrowser 自身的
    // delegate 是用于 flame 消息的 currentDataDelegate, 搜索场景不涉及, 可被覆盖。
    browser.delegate = toolbar;
    browser.dataSourceArray = dataSource;
    // currentPage 必须在 dataSourceArray 之后赋值（YBImageBrowser 文档约定，
    // 否则会先按 0 渲染再跳转，出现"首屏闪一下"）。
    browser.currentPage = initial;
    [browser showToView:[WKApp.shared findWindow]];
}

@end
