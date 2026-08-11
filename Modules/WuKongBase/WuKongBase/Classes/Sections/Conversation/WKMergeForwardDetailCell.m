//
//  WKMergeForwardDetailCell.m
//  WuKongBase
//
//  Created by tt on 2020/10/12.
//

#import "WKMergeForwardDetailCell.h"
#import "WKApp.h"
#import "WKAvatarUtil.h"
#import "WKTimeTool.h"
#import <M80AttributedLabel/M80AttributedLabel.h>
#import "M80AttributedLabel+WK.h"
#import "UIImage+WK.h"
#import <YBImageBrowser/YBImageBrowser.h>
#import "WKDefaultWebImageMediator.h"
#import "WKBrowserToolbar.h"
#import "UIImageView+WK.h"
#import <WuKongIMSDK/WKFileContent.h>
#import <WuKongIMSDK/WKVoiceContent.h>
#import "WKNavigationManager.h"
#import "WKWebViewVC.h"
#import "WKMergeForwardContent.h"
#import "WKMergeForwardDetailVC.h"
#import "WKExternalViewerResolver.h"
#import <AVKit/AVKit.h>
#import <WebKit/WebKit.h>
#import <WuKongBase/WuKongBase-Swift.h>
#import "UIColor+WK.h"
#import "WKSafeFilePreviewVC.h"
#import "WKStickerImageView.h"
#import "WKLottieStickerContent.h"
#import "WKGIFContent.h"
#import "WKRichTextContent.h"
#import "WKRichTextCell.h"
#import "WKMessageModel.h"
#import "WKMessageTextView.h"
#import "WKMatchToken.h"
#import "WKRemoteImageAttachment.h"
#import "NSMutableAttributedString+WK.h"

// 下载进度遮罩（黑色半透明蒙版 + 转圈 + 百分比）
@interface WKDownloadProgressOverlay : UIView
@property(nonatomic,strong) UIActivityIndicatorView *activity;
@property(nonatomic,strong) UILabel *progressLabel;
- (void)showWithProgress:(CGFloat)progress;
- (void)dismiss;
@end

@implementation WKDownloadProgressOverlay

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
        self.hidden = YES;

        _activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _activity.hidesWhenStopped = YES;
        [self addSubview:_activity];

        _progressLabel = [[UILabel alloc] init];
        _progressLabel.font = [UIFont systemFontOfSize:14.0f];
        _progressLabel.textColor = [UIColor whiteColor];
        _progressLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_progressLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat centerY = self.bounds.size.height / 2.0f;
    self.activity.center = CGPointMake(self.bounds.size.width / 2.0f, centerY - 10.0f);
    self.progressLabel.frame = CGRectMake(0, CGRectGetMaxY(self.activity.frame) + 4.0f, self.bounds.size.width, 18.0f);
}

- (void)showWithProgress:(CGFloat)progress {
    self.hidden = NO;
    [self.activity startAnimating];
    if (progress <= 0) {
        self.progressLabel.text = @"0%";
    } else if (progress >= 1.0) {
        self.progressLabel.text = @"100%";
    } else {
        self.progressLabel.text = [NSString stringWithFormat:@"%d%%", (int)(progress * 100)];
    }
}

- (void)dismiss {
    self.hidden = YES;
    [self.activity stopAnimating];
    self.progressLabel.text = @"";
}

@end

// 全局下载状态跟踪（跨 cell 刷新保持进度）
static NSString * const kMergeForwardDownloadNotification = @"WKMergeForwardDownloadProgress";
static NSMutableDictionary<NSNumber *, NSNumber *> *_downloadingMessages;
static NSMutableSet<NSNumber *> *_cancelledDownloads;

static NSMutableDictionary<NSNumber *, NSNumber *> *downloadingMessages(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _downloadingMessages = [NSMutableDictionary dictionary];
    });
    return _downloadingMessages;
}

static NSMutableSet<NSNumber *> *cancelledDownloads(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _cancelledDownloads = [NSMutableSet set];
    });
    return _cancelledDownloads;
}

/// 发起下载并通过通知广播进度
static void startDownloadForMessage(WKMessage *message, void(^onSuccess)(void)) {
    NSNumber *msgKey = @(message.messageId);
    if (downloadingMessages()[msgKey]) return; // 已在下载中
    [cancelledDownloads() removeObject:msgKey]; // 清除取消标记
    downloadingMessages()[msgKey] = @(0);
    [[NSNotificationCenter defaultCenter] postNotificationName:kMergeForwardDownloadNotification object:msgKey userInfo:@{@"progress": @(0), @"state": @"downloading"}];

    [[WKSDK shared].mediaManager download:message callback:^(WKMediaDownloadState state, CGFloat progress, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // 已取消：忽略回调，仅在成功/失败时清理取消标记
            if ([cancelledDownloads() containsObject:msgKey]) {
                if (state == WKMediaDownloadStateSuccess || state == WKMediaDownloadStateFail) {
                    [cancelledDownloads() removeObject:msgKey];
                }
                return;
            }
            if (state == WKMediaDownloadStateSuccess) {
                [downloadingMessages() removeObjectForKey:msgKey];
                [[NSNotificationCenter defaultCenter] postNotificationName:kMergeForwardDownloadNotification object:msgKey userInfo:@{@"state": @"success"}];
                if (onSuccess) onSuccess();
            } else if (state == WKMediaDownloadStateFail) {
                [downloadingMessages() removeObjectForKey:msgKey];
                [[NSNotificationCenter defaultCenter] postNotificationName:kMergeForwardDownloadNotification object:msgKey userInfo:@{@"state": @"fail"}];
            } else {
                downloadingMessages()[msgKey] = @(progress);
                [[NSNotificationCenter defaultCenter] postNotificationName:kMergeForwardDownloadNotification object:msgKey userInfo:@{@"progress": @(progress), @"state": @"downloading"}];
            }
        });
    }];
}

/// 取消下载（UI 层面停止显示进度，后台继续下载）
static void cancelDownloadForMessage(WKMessage *message) {
    NSNumber *msgKey = @(message.messageId);
    [downloadingMessages() removeObjectForKey:msgKey];
    [cancelledDownloads() addObject:msgKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMergeForwardDownloadNotification object:msgKey userInfo:@{@"state": @"cancelled"}];
}

@interface WKMergeForwardDetailHeaderView ()


@property(nonatomic,strong) UIView *lineView1;
@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,strong) UIView *lineView2;
@end

@implementation WKMergeForwardDetailHeaderView

- (instancetype)initWithFrame:(CGRect)frame title:(NSString*)title
{
    self = [super initWithFrame:frame];
    if (self) {
//        [self setBackgroundColor:[UIColor whiteColor]];
        [self addSubview:self.lineView1];
        [self addSubview:self.lineView2];
        [self addSubview:self.titleLbl];
        self.titleLbl.text = title;
        [self.titleLbl sizeToFit];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat leftSpace = 15.0f;
    CGFloat titleLeftSpace = 10.0f;
    
    self.lineView1.lim_centerY_parent = self;
    self.lineView1.lim_left = leftSpace;
    self.lineView1.lim_width = (self.lim_width - leftSpace*2 - self.titleLbl.lim_width - titleLeftSpace*2)/2.0f;
    
    self.titleLbl.lim_centerY_parent = self;
    self.titleLbl.lim_left = self.lineView1.lim_right + titleLeftSpace;
    
    self.lineView2.lim_centerY_parent = self;
    self.lineView2.lim_left = self.titleLbl.lim_right + titleLeftSpace;
    self.lineView2.lim_width = self.lineView1.lim_width;
    
    if([WKApp shared].config.style == WKSystemStyleDark) {
        self.lineView1.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        self.lineView2.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    }else{
        self.lineView1.backgroundColor = [UIColor colorWithRed:240.0f/255.0f green:240.0f/255.0f blue:240.0f/255.0f alpha:1.0f];
        self.lineView2.backgroundColor = [UIColor colorWithRed:240.0f/255.0f green:240.0f/255.0f blue:240.0f/255.0f alpha:1.0f];
    }
    
}

- (UIView *)lineView1 {
    if(!_lineView1) {
        _lineView1 = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, 0.5f)];
    }
    return _lineView1;
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
        _titleLbl.textColor = [WKApp shared].config.tipColor;
    }
    return _titleLbl;
}

- (UIView *)lineView2 {
    if(!_lineView2) {
        _lineView2 =  [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, 1.0f)];
    }
    return _lineView2;
}

@end

@implementation WKMergeForwardDetailModel

+ (instancetype)message:(WKMessage *)message {
    WKMergeForwardDetailModel *model = WKMergeForwardDetailModel.new;
    model.message = message;
    return model;
}

- (Class)cell {
    return WKMergeForwardDetailCell.class;
}


@end

@interface WKMergeForwardDetailCell ()

@property(nonatomic,strong) UIImageView *avatarImgView; // 头像
@property(nonatomic,strong) UILabel *nameLbl; // 名字
@property(nonatomic,strong) UILabel *timeLbl; // 时间





@end

#define avatarTop 15.0f
#define namelHeight 17.0f
#define contentTop 8.0f

#define minContentHeight 80.0f - avatarTop - namelHeight - contentTop - 10.0f

#define contentMaxWidth WKScreenWidth - 15.0f*2 - [WKApp shared].config.messageAvatarSize.width

@implementation WKMergeForwardDetailCell


+ (CGSize)sizeForModel:(WKFormItemModel *)model {
    CGFloat contentHeight = [self contentHeightForModel:model maxWidth:contentMaxWidth];
    if(contentHeight<minContentHeight) {
        contentHeight = minContentHeight;
    }
    return CGSizeMake(WKScreenWidth, avatarTop + namelHeight + contentTop + 10.0f + contentHeight);
}

+(CGFloat) contentHeightForModel:(WKFormItemModel*)model maxWidth:(CGFloat)maxWidth {
    return 0.0f;
}

- (void)setupUI {
    [super setupUI];
    [self.contentView addSubview:self.avatarImgView];
    [self.contentView addSubview:self.nameLbl];
    [self.contentView addSubview:self.timeLbl];
    [self.contentView addSubview:self.messageContentView];
    
    self.bottomLineView.hidden = NO;
    
}

- (void)refresh:(WKMergeForwardDetailModel *)model {
    [super refresh:model];
    self.model = model;

    self.avatarImgView.hidden = model.hideAvatar;

    [self.avatarImgView lim_setImageWithURL:[NSURL URLWithString:[WKAvatarUtil getAvatar:model.message.fromUid]] placeholderImage:[WKApp shared].config.defaultAvatar];

    // / Web PR#981-982 / Android ChatMultiForwardDetailAdapter:682-699 对齐：
    // 合并转发详情里按 viewer-relative 判定作者是否外部，外部 → 名字后拼接
    // 灰色「 @SpaceName」后缀。judge 走统一的 WKExternalViewerResolver，保证和
    // 会话设置 / 群成员列表 / 用户资料页行为一致。
    NSString *baseName = @"";
    if(model.message.from) {
        baseName = model.message.from.displayName ?: @"";
    }else{
        [[WKSDK shared].channelManager fetchChannelInfo:[[WKChannel alloc] initWith:model.message.fromUid channelType:WK_PERSON]];
    }

    NSString *viewerSpaceId = [WKExternalViewerResolver currentViewerSpaceId];
    WKExternalResolveResult *ext = [WKExternalViewerResolver resolveFromExtras:model.userExtras
                                                                 viewerSpaceId:viewerSpaceId];
    if (ext.isExternal && ext.sourceSpaceName.length > 0 && baseName.length > 0) {
        UIColor *nameColor = self.nameLbl.textColor ?: [UIColor grayColor];
        UIFont *nameFont = self.nameLbl.font ?: [[WKApp shared].config appFontOfSize:15.0f];
        NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:baseName
                                                                                 attributes:@{NSFontAttributeName: nameFont,
                                                                                              NSForegroundColorAttributeName: nameColor}];
        UIColor *suffixColor = [UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0f];
        [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" @%@", ext.sourceSpaceName]
                                                                     attributes:@{NSFontAttributeName: nameFont,
                                                                                  NSForegroundColorAttributeName: suffixColor}]];
        self.nameLbl.attributedText = attr;
        self.nameLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    } else {
        self.nameLbl.attributedText = nil;
        self.nameLbl.text = baseName;
    }

    self.timeLbl.text = [WKTimeTool getTimeStringAutoShort2:[NSDate dateWithTimeIntervalSince1970:model.message.timestamp] mustIncludeTime:YES];
    [self.timeLbl sizeToFit];

}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat leftSpace = 15.0f;
    
    self.avatarImgView.lim_top = 15.0f;
    self.avatarImgView.lim_left = leftSpace;
    
    self.timeLbl.lim_left = self.lim_width - self.timeLbl.lim_width - leftSpace;
    self.timeLbl.lim_top = self.avatarImgView.lim_top + 2.0f;
    
    self.nameLbl.lim_top = self.avatarImgView.lim_top+2.0f;
    self.nameLbl.lim_height = 17.0f;
    self.nameLbl.lim_width = self.lim_width - self.avatarImgView.lim_right - 5.0f - self.timeLbl.lim_width - leftSpace;
    self.nameLbl.lim_left = self.avatarImgView.lim_right + 5.0f;
    
    self.messageContentView.lim_top = self.nameLbl.lim_bottom + contentTop;
    self.messageContentView.lim_left = self.nameLbl.lim_left;
    self.messageContentView.lim_width = contentMaxWidth;
    
    if([[self class] contentHeightForModel:self.model maxWidth:self.messageContentView.lim_width]<minContentHeight) {
        self.messageContentView.lim_height = minContentHeight;
    }else{
        self.messageContentView.lim_height = [[self class] contentHeightForModel:self.model maxWidth:contentMaxWidth];
    }
    
}

- (UIImageView *)avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, [WKApp shared].config.messageAvatarSize.width, [WKApp shared].config.messageAvatarSize.height)];
        _avatarImgView.layer.masksToBounds = YES;
        _avatarImgView.layer.cornerRadius = _avatarImgView.lim_height/2.0f;
    }
    return _avatarImgView;
}

- (UILabel *)nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
        _nameLbl.font = [[WKApp shared].config appFontOfSize:15.0f];
        _nameLbl.textColor = [UIColor grayColor];
    }
    return _nameLbl;
}

- (UILabel *)timeLbl {
    if(!_timeLbl) {
        _timeLbl = [[UILabel alloc] init];
        _timeLbl.font =  [[WKApp shared].config appFontOfSize:12.0f];
        _timeLbl.textColor = [WKApp shared].config.tipColor;
    }
    return _timeLbl;
}

- (UIView *)messageContentView {
    if (!_messageContentView) {
        _messageContentView = [UIView new];
        [_messageContentView setBackgroundColor:[UIColor clearColor]];
    }
    return _messageContentView;
}

@end


// ########## 文本cell ##########

@implementation WKMergeForwardDetailTextModel

- (Class)cell {
    return WKMergeForwardDetailTextCell.class;
}

@end

static const CGFloat kMFTableRowHeight = 44.0f;
static const CGFloat kMFTableExtraPadding = 10.0f;
static const CGFloat kMFTableTopSpace = 8.0f;
static const CGFloat kMFTableToolbarHeight = 36.0f;

@interface WKMergeForwardDetailTextCell () <WKNavigationDelegate, UIScrollViewDelegate, M80AttributedLabelDelegate>

@property(nonatomic,strong) M80AttributedLabel *textLbl;
@property(nonatomic,strong) M80AttributedLabel *markdownLbl;
@property(nonatomic,strong) NSMutableArray<UIView *> *segmentViews;
@property(nonatomic,strong) NSMutableArray<WKWebView *> *tableWebViews;
@property(nonatomic,strong) NSMutableArray<UIScrollView *> *tableOverlays;
@property(nonatomic,strong) NSMutableArray<NSString *> *tableRawContents;
@property(nonatomic,assign) BOOL segmentsBuilt;
// 已经为哪条消息构建过 segmentViews。WKMergeForwardDetail*Cell 跟普通 Form cell 一样
// 共享 reuseIdentifier，cell 复用给不同消息时如果只看 segmentsBuilt，分段视图会
// 沿用前一条消息的内容（高度按新消息算、布局是旧消息）→ 底部留出大块空白。所以
// 还要按 message.messageId 做一道判等。
@property(nonatomic,assign) uint64_t lastBuiltMessageId;

// 长按命中的目标 view 和它对应的 raw 文本。
// 旧实现 menu / copy 都固定在 self.textLbl 上，markdown / 表格分段消息上点复制
// 经常拿到错的内容；这里改成命中即记，customcopy: 直接用 wk_longPressCopyText。
@property(nonatomic,weak) UIView *wk_longPressTargetView;
@property(nonatomic,copy) NSString *wk_longPressCopyText;
@property(nonatomic,strong) UIColor *wk_longPressOrigBgColor;

@end

@implementation WKMergeForwardDetailTextCell

+ (CGFloat)contentHeightForModel:(WKMergeForwardDetailTextModel *)model maxWidth:(CGFloat)maxWidth{
    CGSize size = [self getTextLabelSize:model.message maxWidth:maxWidth];
    return size.height;
}

- (void)setupUI {
    [super setupUI];
    
    [self.messageContentView addSubview:self.textLbl];
    [self.messageContentView addSubview:self.markdownLbl];

    self.messageContentView.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGesture:)];
    
    [self.messageContentView addGestureRecognizer:longPressGesture];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuDidHide) name:UIMenuControllerDidHideMenuNotification object:nil];
}

-(void) menuDidHide {
    // 恢复命中段的原 backgroundColor（不再固定清 textLbl —— 长按命中的可能是
    // markdownLbl / 某个 segmentView，错的清会留下高亮残留）。
    if (self.wk_longPressTargetView) {
        self.wk_longPressTargetView.backgroundColor = self.wk_longPressOrigBgColor ?: [UIColor clearColor];
    } else {
        // 兜底：旧路径，如果完全没命中过，也把可能被旧实现染色的 textLbl 复位。
        [self.textLbl setBackgroundColor:[UIColor clearColor]];
    }
    self.wk_longPressTargetView = nil;
    self.wk_longPressCopyText = nil;
    self.wk_longPressOrigBgColor = nil;
}

- (void)clearSegmentViews {
    for (UIView *v in self.segmentViews) {
        if (v != self.textLbl && v != self.markdownLbl) {
            [v removeFromSuperview];
        }
    }
    [self.segmentViews removeAllObjects];
    for (UIScrollView *o in self.tableOverlays) { [o removeFromSuperview]; }
    [self.tableOverlays removeAllObjects];
    [self.tableWebViews removeAllObjects];
    [self.tableRawContents removeAllObjects];
    self.segmentsBuilt = NO;
    self.lastBuiltMessageId = 0;
}

- (WKWebView *)createTableWebView {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    WKWebView *wv = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    wv.scrollView.scrollEnabled = NO;
    wv.backgroundColor = [UIColor clearColor];
    wv.opaque = NO;
    wv.scrollView.backgroundColor = [UIColor clearColor];
    wv.navigationDelegate = self;
    return wv;
}

- (UIScrollView *)createTableOverlay {
    UIScrollView *sv = [[UIScrollView alloc] init];
    sv.backgroundColor = [UIColor clearColor];
    sv.showsHorizontalScrollIndicator = YES;
    sv.showsVerticalScrollIndicator = NO;
    sv.bounces = NO;
    sv.directionalLockEnabled = YES;
    sv.delegate = self;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTableLinkTap:)];
    [sv addGestureRecognizer:tap];
    return sv;
}

- (void)handleTableLinkTap:(UITapGestureRecognizer *)gr {
    NSInteger idx = [self.tableOverlays indexOfObject:gr.view];
    if (idx == NSNotFound || idx >= (NSInteger)self.tableWebViews.count) return;
    WKWebView *wv = self.tableWebViews[idx];
    CGPoint pt = [gr locationInView:gr.view];
    NSString *js = [NSString stringWithFormat:
        @"(function(){"
        @"var el=document.elementFromPoint(%f,%f);"
        @"if(!el)return;"
        @"var a=el.tagName==='A'?el:(el.closest?el.closest('a'):null);"
        @"if(a&&a.href)window.location.href=a.href;"
        @"})()", pt.x, pt.y];
    [wv evaluateJavaScript:js completionHandler:nil];
}

- (UIView *)createTableToolbar:(NSInteger)tableIndex {
    UIView *toolbar = [[UIView alloc] init];
    toolbar.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xF6/255.0 alpha:1.0];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.text = @"表格";
    titleLbl.font = [UIFont boldSystemFontOfSize:15];
    titleLbl.textColor = [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1.0];
    [titleLbl sizeToFit];
    titleLbl.frame = CGRectMake(12, (kMFTableToolbarHeight - titleLbl.frame.size.height) / 2.0, titleLbl.frame.size.width, titleLbl.frame.size.height);
    [toolbar addSubview:titleLbl];

    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.tag = tableIndex;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightRegular];
        UIImage *icon = [UIImage systemImageNamed:@"doc.on.doc" withConfiguration:iconConfig];
        [copyBtn setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    } else {
        [copyBtn setTitle:@"复制" forState:UIControlStateNormal];
        copyBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    }
    copyBtn.tintColor = [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1.0];
    [copyBtn addTarget:self action:@selector(copyTableTapped:) forControlEvents:UIControlEventTouchUpInside];
    copyBtn.frame = CGRectMake(0, 0, 36, kMFTableToolbarHeight);
    [toolbar addSubview:copyBtn];

    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = [UIColor colorWithRed:0xE0/255.0 green:0xE0/255.0 blue:0xE0/255.0 alpha:1.0];
    separator.tag = 9999;
    [toolbar addSubview:separator];

    return toolbar;
}

- (void)copyTableTapped:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx < (NSInteger)self.tableRawContents.count) {
        [UIPasteboard generalPasteboard].string = self.tableRawContents[idx];
        UIView *topView = [WKNavigationManager shared].topViewController.view;
        [topView showHUDWithHide:LLang(@"已复制")];
    }
}

- (void)refresh:(WKMergeForwardDetailTextModel *)model {
    [super refresh:model];

    if(![model.message.content isKindOfClass:[WKTextContent class]]) {
        self.textLbl.hidden = NO;
        self.markdownLbl.hidden = YES;
        [self clearSegmentViews];
        self.textLbl.text = @"[未知消息]";
        return;
    }
    WKTextContent *textContent = (WKTextContent *)[model.message content];
    NSString *content = textContent.content ?: @"";
    UIColor *textColor = [WKApp shared].config.defaultTextColor;
    NSString *colorHex = [textColor toHexRGB];
    BOOL hasTable = [WKMarkdownRenderer containsTable:content];

    if (hasTable) {
        self.textLbl.hidden = YES;
        self.markdownLbl.hidden = YES;

        // cell 复用：若上次构建的不是这条消息，必须先 clear 再重建，否则
        // segmentViews 沿用前条消息的内容、高度按当前消息算 → 底部留出大块空白。
        if (self.lastBuiltMessageId != model.message.messageId) {
            [self clearSegmentViews];
        }

        if (!self.segmentsBuilt) {
            [self clearSegmentViews];
            NSArray *segments = [WKMarkdownRenderer splitContentSegments:content];
            for (NSDictionary *seg in segments) {
                NSString *type = seg[@"type"];
                NSString *segContent = seg[@"content"];
                if ([type isEqualToString:@"text"]) {
                    // 用 M80AttributedLabel 而非 UILabel：UILabel 不响应 NSLink 点击，
                    // 而合并消息含表格时这一段也可能含 markdown 链接，要可点。
                    M80AttributedLabel *lbl = [[M80AttributedLabel alloc] init];
                    lbl.font = [UIFont systemFontOfSize:[WKApp shared].config.messageTextFontSize];
                    lbl.textColor = textColor;
                    lbl.numberOfLines = 0;
                    lbl.lineBreakMode = kCTLineBreakByWordWrapping;
                    lbl.backgroundColor = [UIColor clearColor];
                    lbl.autoDetectLinks = NO;
                    lbl.underLineForLink = NO;
                    lbl.delegate = self;
                    if (@available(iOS 13.0, *)) {
                        lbl.linkColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull tc) {
                            if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
                                return [UIColor colorWithRed:100/255.0 green:181/255.0 blue:246/255.0 alpha:1.0];
                            }
                            return [UIColor colorWithRed:89/255.0 green:121/255.0 blue:240/255.0 alpha:1.0];
                        }];
                    } else {
                        lbl.linkColor = [UIColor colorWithRed:89/255.0 green:121/255.0 blue:240/255.0 alpha:1.0];
                    }
                    if ([WKMarkdownRenderer containsMarkdown:segContent]) {
                        NSAttributedString *mdAttr = [WKMarkdownRenderer render:segContent fontSize:[WKApp shared].config.messageTextFontSize textColorHex:colorHex];
                        if (mdAttr) {
                            lbl.attributedText = mdAttr;
                            [self wk_registerNSLinksOnLabel:lbl fromAttributedText:mdAttr];
                        } else { [lbl setText:segContent]; }
                    } else {
                        [lbl setText:segContent];
                    }
                    [self.messageContentView addSubview:lbl];
                    [self.segmentViews addObject:lbl];
                } else {
                    // 表格段：工具栏 + WebView + 滚动遮罩
                    NSInteger tableIndex = (NSInteger)self.tableRawContents.count;
                    [self.tableRawContents addObject:segContent];

                    UIView *container = [[UIView alloc] init];
                    container.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xF6/255.0 alpha:1.0];
                    container.layer.cornerRadius = 8.0;
                    container.clipsToBounds = YES;

                    UIView *toolbar = [self createTableToolbar:tableIndex];
                    [container addSubview:toolbar];

                    WKWebView *wv = [self createTableWebView];
                    NSString *tableHTML = [WKMarkdownRenderer extractTableHTML:segContent fontSize:[WKApp shared].config.messageTextFontSize textColorHex:@"#333333"];
                    if (tableHTML) { [wv loadHTMLString:tableHTML baseURL:nil]; }
                    [container addSubview:wv];

                    NSInteger rowCount = [WKMarkdownRenderer tableRowCount:segContent];
                    container.tag = (NSInteger)(kMFTableToolbarHeight + rowCount * kMFTableRowHeight + kMFTableExtraPadding);

                    [self.messageContentView addSubview:container];
                    [self.segmentViews addObject:container];
                    [self.tableWebViews addObject:wv];

                    UIScrollView *overlay = [self createTableOverlay];
                    [self.contentView addSubview:overlay];
                    [self.tableOverlays addObject:overlay];
                }
            }
            self.segmentsBuilt = YES;
            self.lastBuiltMessageId = model.message.messageId;
        }
    } else if ([WKMarkdownRenderer containsMarkdown:content]) {
        self.textLbl.hidden = YES;
        self.markdownLbl.hidden = NO;
        [self clearSegmentViews];
        @try {
            NSAttributedString *mdAttr = [WKMarkdownRenderer render:content fontSize:[WKApp shared].config.messageTextFontSize textColorHex:colorHex];
            if (mdAttr && mdAttr.length > 0) {
                self.markdownLbl.attributedText = mdAttr;
                // M80.setAttributedText 会 cleanAll，customLink 必须在之后注册才不会被清掉
                [self wk_registerNSLinksOnLabel:self.markdownLbl fromAttributedText:mdAttr];
            } else {
                self.textLbl.hidden = NO;
                self.markdownLbl.hidden = YES;
                [self.textLbl lim_setText:content mentionInfo:textContent.mentionedInfo];
            }
        } @catch (NSException *exception) {
            // markdown 渲染异常兜底（cmark-gfm 解析失败或表格 WebView 加载异常），fallback 到纯文本
            self.textLbl.hidden = NO;
            self.markdownLbl.hidden = YES;
            [self.textLbl lim_setText:content mentionInfo:textContent.mentionedInfo];
        }
    } else {
        self.textLbl.hidden = NO;
        self.markdownLbl.hidden = YES;
        [self clearSegmentViews];
        [self.textLbl lim_setText:content mentionInfo:textContent.mentionedInfo];
    }

    [self.textLbl setBackgroundColor:[UIColor clearColor]];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if (self.segmentViews.count > 0) {
        CGFloat y = 0;
        CGFloat maxWidth = contentMaxWidth;
        NSInteger tableIdx = 0;
        for (NSUInteger i = 0; i < self.segmentViews.count; i++) {
            UIView *v = self.segmentViews[i];
            CGFloat spacing = (i < self.segmentViews.count - 1) ? kMFTableTopSpace : 0;
            // 文本段是 M80AttributedLabel（UIView 子类，不是 UILabel），表格段才是普通 UIView 容器。
            // 早先文本段用 UILabel，改成 M80 以支持 markdown 链接点击后，这里的类型判断没同步，
            // 导致文本段被当成表格段、赋成 tag(=0) 高度而不可见（表现为表格之后的内容“算了高度但空白”）。
            if ([v isKindOfClass:[M80AttributedLabel class]] || [v isKindOfClass:[UILabel class]]) {
                CGSize fitSize = [v sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];
                v.frame = CGRectMake(0, y, ceilf(fitSize.width), ceilf(fitSize.height));
                y += ceilf(fitSize.height) + spacing;
            } else {
                CGFloat tableH = (CGFloat)v.tag;
                v.frame = CGRectMake(0, y, maxWidth, tableH);

                // 容器内布局：toolbar 在顶部，webview 在 toolbar 下方
                for (UIView *sub in v.subviews) {
                    if ([sub isKindOfClass:[WKWebView class]]) {
                        sub.frame = CGRectMake(0, kMFTableToolbarHeight, maxWidth, tableH - kMFTableToolbarHeight);
                    } else {
                        // toolbar
                        sub.frame = CGRectMake(0, 0, maxWidth, kMFTableToolbarHeight);
                        for (UIView *toolSub in sub.subviews) {
                            if ([toolSub isKindOfClass:[UIButton class]]) {
                                toolSub.frame = CGRectMake(maxWidth - 36 - 8, 0, 36, kMFTableToolbarHeight);
                            } else if (toolSub.tag == 9999) {
                                toolSub.frame = CGRectMake(0, kMFTableToolbarHeight - 0.5, maxWidth, 0.5);
                            }
                        }
                    }
                }

                // 滚动遮罩覆盖 webview 区域
                if (tableIdx < (NSInteger)self.tableOverlays.count) {
                    CGRect containerInContent = [self.contentView convertRect:v.frame fromView:self.messageContentView];
                    CGRect overlayRect = CGRectMake(containerInContent.origin.x, containerInContent.origin.y + kMFTableToolbarHeight, containerInContent.size.width, containerInContent.size.height - kMFTableToolbarHeight);
                    self.tableOverlays[tableIdx].frame = overlayRect;
                    tableIdx++;
                }

                y += tableH + spacing;
            }
        }
    } else if (!self.markdownLbl.hidden) {
        CGSize textLabelSize = [[self class] getTextLabelSize:self.model.message maxWidth:contentMaxWidth];
        self.markdownLbl.frame = CGRectMake(0, 0, textLabelSize.width, textLabelSize.height);
    } else {
        CGSize textLabelSize = [[self class] getTextLabelSize:self.model.message maxWidth:contentMaxWidth];
        self.textLbl.lim_width = textLabelSize.width;
        self.textLbl.lim_height = textLabelSize.height;
    }
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSString *scheme = url.scheme.lowercaseString;
    // 表格 / 富文本 WebView 渲染完成后的首次加载不拦，否则空白 —— 仅拦用户点击触发的导航
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated &&
        ([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"])) {
        [self openURLInAppWebView:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSUInteger idx = [self.tableWebViews indexOfObject:webView];
    if (idx == NSNotFound || idx >= self.tableOverlays.count) return;
    UIScrollView *overlay = self.tableOverlays[idx];
    [webView evaluateJavaScript:@"Math.max(document.body.scrollWidth, document.documentElement.scrollWidth)" completionHandler:^(id result, NSError *error) {
        if (!result || error) return;
        CGFloat contentWidth = [result floatValue];
        CGFloat frameWidth = overlay.frame.size.width;
        if (contentWidth > frameWidth && frameWidth > 0) {
            overlay.contentSize = CGSizeMake(contentWidth, overlay.frame.size.height);
        }
    }];
}

#pragma mark - UIScrollViewDelegate (遮罩层滑动同步到 WebView)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSUInteger idx = [self.tableOverlays indexOfObject:scrollView];
    if (idx != NSNotFound && idx < self.tableWebViews.count) {
        self.tableWebViews[idx].scrollView.contentOffset = scrollView.contentOffset;
    }
}

#pragma mark - M80AttributedLabelDelegate

- (void)m80AttributedLabel:(M80AttributedLabel *)label clickedOnLink:(id)linkData {
    NSURL *url = nil;
    if ([linkData isKindOfClass:[NSURL class]]) {
        url = (NSURL *)linkData;
    } else if ([linkData isKindOfClass:[NSString class]]) {
        url = [NSURL URLWithString:(NSString *)linkData];
    }
    if (url && ([@[@"http", @"https"] containsObject:url.scheme.lowercaseString])) {
        [self openURLInAppWebView:url];
    }
}

- (void)openURLInAppWebView:(NSURL *)url {
    if (!url) return;
    WKWebViewVC *vc = [[WKWebViewVC alloc] init];
    vc.url = url;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}


- (M80AttributedLabel *)textLbl {
    if(!_textLbl) {
        _textLbl = [[M80AttributedLabel alloc] init];
        _textLbl.underLineForLink = false;
        _textLbl.delegate = self;
        [_textLbl setFont:[UIFont systemFontOfSize:[WKApp shared].config.messageTextFontSize]];
        [_textLbl setBackgroundColor:[UIColor clearColor]];
        [_textLbl setTextColor:[WKApp shared].config.defaultTextColor];
        // 跟 markdownLbl（WKMarkdownRenderer）保持一致的链接色：
        // 深色 #64B5F6（Material Blue 300 浅蓝）/ 浅色 #5979F0。
        // 不设的话 M80 会用默认 [UIColor blueColor]（#0000FF 深蓝），
        // 导致同一个详情页里 markdown 链接与自动识别 URL 颜色不一致。
        if (@available(iOS 13.0, *)) {
            _textLbl.linkColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull tc) {
                if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return [UIColor colorWithRed:100/255.0 green:181/255.0 blue:246/255.0 alpha:1.0]; // #64B5F6
                }
                return [UIColor colorWithRed:89/255.0 green:121/255.0 blue:240/255.0 alpha:1.0]; // #5979F0
            }];
        } else {
            _textLbl.linkColor = [UIColor colorWithRed:89/255.0 green:121/255.0 blue:240/255.0 alpha:1.0];
        }
        _textLbl.numberOfLines = 0;
        _textLbl.lineBreakMode = kCTLineBreakByWordWrapping;

    }
    return _textLbl;
}

- (NSMutableArray<UIView *> *)segmentViews {
    if (!_segmentViews) { _segmentViews = [NSMutableArray array]; }
    return _segmentViews;
}
- (NSMutableArray<WKWebView *> *)tableWebViews {
    if (!_tableWebViews) { _tableWebViews = [NSMutableArray array]; }
    return _tableWebViews;
}
- (NSMutableArray<UIScrollView *> *)tableOverlays {
    if (!_tableOverlays) { _tableOverlays = [NSMutableArray array]; }
    return _tableOverlays;
}
- (NSMutableArray<NSString *> *)tableRawContents {
    if (!_tableRawContents) { _tableRawContents = [NSMutableArray array]; }
    return _tableRawContents;
}

- (M80AttributedLabel *)markdownLbl {
    if (!_markdownLbl) {
        _markdownLbl = [[M80AttributedLabel alloc] init];
        _markdownLbl.font = [UIFont systemFontOfSize:[WKApp shared].config.messageTextFontSize];
        _markdownLbl.textColor = [WKApp shared].config.defaultTextColor;
        _markdownLbl.numberOfLines = 0;
        _markdownLbl.lineBreakMode = kCTLineBreakByWordWrapping;
        _markdownLbl.backgroundColor = [UIColor clearColor];
        _markdownLbl.hidden = YES;
        // markdown 已经把 [text](url) 解析成 NSLinkAttribute，autoDetect 会再走一次 NSDataDetector
        // 反而对纯文本里的 URL 会和 markdown link 冲突，关掉
        _markdownLbl.autoDetectLinks = NO;
        _markdownLbl.underLineForLink = NO;
        _markdownLbl.delegate = self;
        // 跟 textLbl 完全相同的 dynamic linkColor：深色 #64B5F6 浅蓝 / 浅色 #5979F0
        if (@available(iOS 13.0, *)) {
            _markdownLbl.linkColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull tc) {
                if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return [UIColor colorWithRed:100/255.0 green:181/255.0 blue:246/255.0 alpha:1.0];
                }
                return [UIColor colorWithRed:89/255.0 green:121/255.0 blue:240/255.0 alpha:1.0];
            }];
        } else {
            _markdownLbl.linkColor = [UIColor colorWithRed:89/255.0 green:121/255.0 blue:240/255.0 alpha:1.0];
        }
    }
    return _markdownLbl;
}

// 把 attributedText 内 NSLinkAttributeName 标记的 range 注册成 M80 的 customLink，
// UILabel 本身不响应 NSLink 点击；M80 的 customLink 才会进 m80AttributedLabel:clickedOnLink: 回调。
// 必须在 setAttributedText 之后调（M80.setAttributedText 会 cleanAll 已注册的 customLink）。
- (void)wk_registerNSLinksOnLabel:(M80AttributedLabel *)label fromAttributedText:(NSAttributedString *)attr {
    if (!label || !attr || attr.length == 0) return;
    [attr enumerateAttribute:NSLinkAttributeName
                     inRange:NSMakeRange(0, attr.length)
                     options:0
                  usingBlock:^(id value, NSRange range, BOOL *stop) {
        id linkData = nil;
        if ([value isKindOfClass:[NSURL class]] || [value isKindOfClass:[NSString class]]) {
            linkData = value;
        }
        if (linkData) {
            [label addCustomLink:linkData forRange:range];
        }
    }];
}

-(void) handleLongPressGesture:(UILongPressGestureRecognizer *)longPressGR {
    if (longPressGR.state != UIGestureRecognizerStateBegan) return;

    // 命中检测：触点位置 → 命中的具体 view + 它对应的 raw 文本。
    // 旧实现固定锚到 self.textLbl，markdown / 多段表格消息上经常拿到错的内容；
    // 现在按真实命中决定复制对象，并把高亮也加到命中 view 上让用户知道复制的
    // 是哪一段。
    CGPoint pt = [longPressGR locationInView:self.messageContentView];
    UIView *target = nil;
    NSString *copyText = nil;

    if (self.segmentViews.count > 0) {
        // hasTable 路径：命中具体 segmentView。文本段是 M80AttributedLabel，
        // 表格段是 UIView container。
        for (NSUInteger i = 0; i < self.segmentViews.count; i++) {
            UIView *v = self.segmentViews[i];
            if (!CGRectContainsPoint(v.frame, pt)) continue;
            target = v;
            // 推导 raw 文本：用 splitContentSegments 同样按下标取 segments[i].content。
            // 表格段的 content 是 raw markdown 表格语法（| col | col |），文本段
            // 是 raw markdown 文本（可能含 # ** | 等）。粘贴回输入框再发送，接收
            // 端的 markdown 渲染能识别。
            NSString *raw = [self wk_rawContentForSegmentAtIndex:(NSInteger)i];
            if (raw.length > 0) copyText = raw;
            break;
        }
    }
    if (!target && !self.markdownLbl.hidden && CGRectContainsPoint(self.markdownLbl.frame, pt)) {
        target = self.markdownLbl;
        // 单段 markdown：copy 整条 raw markdown。
        copyText = [self wk_rawContentOfMessage];
    }
    if (!target && !self.textLbl.hidden && CGRectContainsPoint(self.textLbl.frame, pt)) {
        target = self.textLbl;
        // 普通文本（无 markdown）：直接复制原始 content（避免 textLbl.text 因
        // attributedText 处理掉换行/链接等而失真）。
        copyText = [self wk_rawContentOfMessage];
        if (copyText.length == 0) copyText = self.textLbl.text;
    }
    if (!target) {
        // 兜底：命中失败但用户长按就要触发菜单，落到当前可见的主显示控件。
        if (!self.markdownLbl.hidden) {
            target = self.markdownLbl;
            copyText = [self wk_rawContentOfMessage];
        } else if (!self.textLbl.hidden) {
            target = self.textLbl;
            copyText = [self wk_rawContentOfMessage] ?: self.textLbl.text;
        } else if (self.segmentViews.count > 0) {
            target = self.segmentViews.firstObject;
            copyText = [self wk_rawContentForSegmentAtIndex:0];
        }
    }
    if (!target) return;

    // 记下命中状态，customcopy: / menuDidHide 用
    self.wk_longPressTargetView = target;
    self.wk_longPressCopyText = copyText ?: @"";
    self.wk_longPressOrigBgColor = target.backgroundColor;

    // 高亮命中段：浅蓝（与 WKTextMessageCell 选区高亮风格一致），不会盖住文字
    target.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.18];

    [self becomeFirstResponder];
    UIMenuItem *copyLink = [[UIMenuItem alloc] initWithTitle:@"复制" action:@selector(customcopy:)];
    [[UIMenuController sharedMenuController] setMenuItems:@[copyLink]];
    [[UIMenuController sharedMenuController] setTargetRect:target.frame inView:target.superview];
    [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
}

// 推导 segmentViews[idx] 对应的原始 markdown 文本（splitContentSegments 拆出来的
// content 串）。表格段就是 raw 表格 markdown，文本段就是 raw 文本 markdown。
-(NSString*) wk_rawContentForSegmentAtIndex:(NSInteger)idx {
    if (idx < 0) return nil;
    NSString *raw = [self wk_rawContentOfMessage];
    if (raw.length == 0) return nil;
    NSArray *segments = [WKMarkdownRenderer splitContentSegments:raw];
    if (idx >= (NSInteger)segments.count) return nil;
    NSDictionary *seg = segments[idx];
    NSString *content = seg[@"content"];
    return content;
}

// 当前消息的原始 markdown 文本（WKTextContent.content）。
-(NSString*) wk_rawContentOfMessage {
    if (![self.model.message.content isKindOfClass:[WKTextContent class]]) return @"";
    return ((WKTextContent*)self.model.message.content).content ?: @"";
}


+ (CGSize)getTextLabelSize:(WKMessage *)message maxWidth:(CGFloat)maxWidth {
    static WKMemoryCache *memoryCache;
    static NSLock *memoryLock;
    if(!memoryLock) {
        memoryLock = [[NSLock alloc] init];
    }
    if(!memoryCache) {
        memoryCache = [[WKMemoryCache alloc] init];
        memoryCache.maxCacheNum = 500;
    }
   NSString *cacheKey = [NSString stringWithFormat:@"%llu",message.messageId];
    [memoryLock lock];
   NSString *cacheSizeStr =   [memoryCache getCache:cacheKey];
    [memoryLock unlock];
    if(cacheSizeStr) {
        return CGSizeFromString(cacheSizeStr);
    }
    if(![message.content isKindOfClass:[WKTextContent class]]) {
        return CGSizeMake(maxWidth, 20.0f);
    }
    WKTextContent *textContent = (WKTextContent *)message.content;
    NSString *content = textContent.content ?: @"";
    CGSize textSize;

    BOOL hasTable = [WKMarkdownRenderer containsTable:content];
    if (hasTable) {
        // 分段计算总高度
        NSArray *segments = [WKMarkdownRenderer splitContentSegments:content];
        UIColor *textColor = [WKApp shared].config.defaultTextColor;
        NSString *colorHex = [textColor toHexRGB];
        CGFloat totalHeight = 0;
        CGFloat totalWidth = maxWidth;

        // 用 M80AttributedLabel 测高，必须和 refresh: 里真正渲染文本段用的类型一致：
        // M80 走 CoreText，UILabel 走 TextKit，两者对同一段 markdown 的行高/换行结果会有差异，
        // 若测高用 UILabel 而渲染用 M80，最后一段可能被裁掉（高度偏小）。
        static M80AttributedLabel *measureLabel;
        if (!measureLabel) {
            measureLabel = [[M80AttributedLabel alloc] init];
            measureLabel.numberOfLines = 0;
            measureLabel.lineBreakMode = kCTLineBreakByWordWrapping;
        }
        measureLabel.font = [UIFont systemFontOfSize:[WKApp shared].config.messageTextFontSize];

        for (NSUInteger i = 0; i < segments.count; i++) {
            NSDictionary *seg = segments[i];
            NSString *type = seg[@"type"];
            NSString *segContent = seg[@"content"];
            CGFloat spacing = (i < segments.count - 1) ? kMFTableTopSpace : 0;
            if ([type isEqualToString:@"text"]) {
                if ([WKMarkdownRenderer containsMarkdown:segContent]) {
                    NSAttributedString *mdAttr = [WKMarkdownRenderer render:segContent fontSize:[WKApp shared].config.messageTextFontSize textColorHex:colorHex];
                    if (mdAttr) {
                        measureLabel.attributedText = mdAttr;
                    } else {
                        [measureLabel setText:segContent];
                    }
                } else {
                    [measureLabel setText:segContent];
                }
                CGSize fitSize = [measureLabel sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];
                totalHeight += ceilf(fitSize.height) + spacing;
            } else {
                NSInteger rowCount = [WKMarkdownRenderer tableRowCount:segContent];
                totalHeight += kMFTableToolbarHeight + rowCount * kMFTableRowHeight + kMFTableExtraPadding + spacing;
            }
        }
        textSize = CGSizeMake(totalWidth, totalHeight);
    } else if ([WKMarkdownRenderer containsMarkdown:content]) {
        UIColor *textColor = [WKApp shared].config.defaultTextColor;
        NSString *colorHex = [textColor toHexRGB];
        NSAttributedString *mdAttr = [WKMarkdownRenderer render:content fontSize:[WKApp shared].config.messageTextFontSize textColorHex:colorHex];
        // 必须用 M80AttributedLabel 测高 —— 实际渲染（refresh: 里 self.markdownLbl）
        // 走的是 M80AttributedLabel/CoreText，旧实现这里用 NSAttributedString 的
        // boundingRectWithSize（NSStringDrawing/TextKit）测高，两者对同一份 attrText
        // 的行间距、段落间距、--- 横线段、有序列表段处理不同，长 markdown 上 TextKit
        // 算出来明显比 CoreText 实渲染高，cell 末尾留出大块空白。hasTable 分支上方
        // 注释也明确点过这个一致性约束（用 measureLabel sizeThatFits），这里同步。
        static M80AttributedLabel *mdMeasureLabel;
        if (!mdMeasureLabel) {
            mdMeasureLabel = [[M80AttributedLabel alloc] init];
            mdMeasureLabel.numberOfLines = 0;
            mdMeasureLabel.lineBreakMode = kCTLineBreakByWordWrapping;
        }
        mdMeasureLabel.font = [UIFont systemFontOfSize:[WKApp shared].config.messageTextFontSize];
        if (mdAttr && mdAttr.length > 0) {
            mdMeasureLabel.attributedText = mdAttr;
            CGSize fitSize = [mdMeasureLabel sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];
            textSize = CGSizeMake(ceilf(fitSize.width), ceilf(fitSize.height));
        } else {
            [mdMeasureLabel lim_setText:content];
            CGSize fitSize = [mdMeasureLabel sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];
            textSize = CGSizeMake(ceilf(fitSize.width), ceilf(fitSize.height));
        }
    } else {
        static M80AttributedLabel *plainLbl2;
        if(!plainLbl2) {
            plainLbl2 = [[M80AttributedLabel alloc] init];
            [plainLbl2 setFont:[UIFont systemFontOfSize:[WKApp shared].config.messageTextFontSize]];
        }
        [plainLbl2 lim_setText:content];
        textSize = [plainLbl2 sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];
    }
    if(message.messageId !=0 ) {
         [memoryLock lock];
        [memoryCache setCache:NSStringFromCGSize(textSize) forKey:cacheKey];
         [memoryLock unlock];
    }
    return textSize;
}



#pragma mark - UIMenuController

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
//    // 自定义响应UIMenuItem Action，例如你可以过滤掉多余的系统自带功能（剪切，选择等），只保留复制功能。
    return (action == @selector(customcopy:));
}

- (void)customcopy:(id)sender
{
    // 复用 handleLongPressGesture: 保存的命中文本，而不是固定读 self.textLbl.text。
    // 否则 markdown 单段（在 markdownLbl 显示）/ 含表格分段消息（在 segmentViews）
    // 上点复制会拿到 textLbl 的旧值或空串。
    NSString *toCopy = self.wk_longPressCopyText;
    if (toCopy.length == 0) {
        // 兜底：实在没记到（理论不会），用 message 的 raw content。
        toCopy = [self wk_rawContentOfMessage];
    }
    if (toCopy.length > 0) {
        [[UIPasteboard generalPasteboard] setString:toCopy];
    }
}

@end


//----------图片cell ----------

@implementation WKMergeForwardDetailImageModel


- (Class)cell {
    return WKMergeForwardDetailImageCell.class;
}

@end


@interface WKMergeForwardDetailImageCell ()

@property(nonatomic,strong) UIImageView *messageImgView;

@end

@implementation WKMergeForwardDetailImageCell

+ (CGFloat)contentHeightForModel:(WKMergeForwardDetailImageModel *)model maxWidth:(CGFloat)maxWidth{
    if(![model.message.content isKindOfClass:[WKImageContent class]]) return 80.0f;
    WKImageContent *imageContent = (WKImageContent*)model.message.content;
    if(imageContent.width <= 0 || imageContent.height <= 0) return 80.0f;
    return [UIImage lim_sizeWithImageOriginSize:CGSizeMake(imageContent.width, imageContent.height) maxLength:maxWidth].height;
}

- (void)setupUI {
    [super setupUI];
    [self.messageContentView addSubview:self.messageImgView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
    self.messageImgView.userInteractionEnabled = YES;
    [self.messageImgView addGestureRecognizer:tap];
    
    
}

- (void)refresh:(WKMergeForwardDetailImageModel *)model {
    [super refresh:model];
    if(![model.message.content isKindOfClass:[WKImageContent class]]) return;
    WKImageContent *imageContent = (WKImageContent*)model.message.content;
    NSURL *url = [[WKApp shared] getImageFullUrl:imageContent.remoteUrl];
    [self.messageImgView lim_setImageWithURL:url placeholderImage:[WKApp shared].config.defaultPlaceholder];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    WKImageContent *imageContent = (WKImageContent*)self.model.message.content;
    CGSize size =[UIImage lim_sizeWithImageOriginSize:CGSizeMake(imageContent.width, imageContent.height) maxLength:contentMaxWidth];
    
    self.messageImgView.lim_size = size;
}

-(void) onTap {
    
    WKImageContent *imageContent = (WKImageContent*)self.model.message.content;
    
    YBIBImageData *data = [YBIBImageData new];
    data.imageURL = [[WKApp shared] getImageFullUrl:imageContent.remoteUrl];
    data.projectiveView = self.messageImgView;
    
    YBImageBrowser *imageBrowser = [[YBImageBrowser alloc] init];
    imageBrowser.webImageMediator = [WKDefaultWebImageMediator new];
    imageBrowser.toolViewHandlers = @[WKBrowserToolbar.new];
    
    imageBrowser.dataSourceArray = @[data];
    [imageBrowser show];
   
    
    
}


- (UIImageView *)messageImgView {
    if(!_messageImgView) {
        _messageImgView = [[UIImageView alloc] init];
        _messageImgView.layer.masksToBounds = YES;
        _messageImgView.layer.cornerRadius = 4.0f;
    }
    return _messageImgView;
}


@end

//---------- 图文混排 cell（RichText=14，WKRichTextContent）----------

@implementation WKMergeForwardDetailRichTextModel

- (Class)cell {
    return WKMergeForwardDetailRichTextCell.class;
}

@end

@interface WKMergeForwardDetailRichTextCell ()

// display-only UITextView（等同 UILabel，但天然渲染 NSTextAttachment 内联图片）。
@property(nonatomic,strong) WKMessageTextView *textView;
// 已渲染的是哪条消息——图片下载回调回来时用它防 cell 复用错位刷到别人。
@property(nonatomic,assign) uint64_t lastRenderedMessageId;

@end

@implementation WKMergeForwardDetailRichTextCell

// 复用 WKRichTextCell 的 block 迭代 / 图片 attachment 构建逻辑，强制传 defaultTextColor
// （合并详情是白底左对齐列表，用 isSend 分支的白字会看不见）。非 RichText 返回 nil。
+ (NSMutableAttributedString *)attributedStringForModel:(WKMergeForwardDetailModel *)model {
    if (![model.message.content isKindOfClass:[WKRichTextContent class]]) {
        return nil;
    }
    WKMessageModel *msgModel = [[WKMessageModel alloc] initWithMessage:model.message];
    return [WKRichTextCell attributedStringForMessage:msgModel
                                            textColor:[WKApp shared].config.defaultTextColor
                                         mentionColor:[WKApp shared].config.themeColor
                                            truncated:NULL];
}

+ (CGFloat)contentHeightForModel:(WKMergeForwardDetailRichTextModel *)model maxWidth:(CGFloat)maxWidth {
    NSMutableAttributedString *attr = [self attributedStringForModel:model];
    if (attr.length == 0) return minContentHeight;
    // 与 WKMessageTextView 一致的零 inset/padding 测量（NSMutableAttributedString+WK size:）。
    return ceil([attr size:maxWidth].height) + 1.0f;
}

- (void)setupUI {
    [super setupUI];
    [self.messageContentView addSubview:self.textView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapRichText:)];
    self.textView.userInteractionEnabled = YES;
    [self.textView addGestureRecognizer:tap];
}

- (void)refresh:(WKMergeForwardDetailRichTextModel *)model {
    [super refresh:model];

    NSMutableAttributedString *attr = [[self class] attributedStringForModel:model];
    if (attr.length == 0) {
        self.textView.attributedText = [[NSAttributedString alloc] initWithString:@""];
        self.lastRenderedMessageId = 0;
        return;
    }
    self.textView.attributedText = attr;
    self.lastRenderedMessageId = model.message.messageId;
    [self triggerImageDownloads:attr forMessageId:model.message.messageId];
}

// 触发内联图片下载；就绪后仅局部 invalidate 对应 glyph 的显示（不动 layout / 不重设
// attributedText），避免多图下载时「连环闪」。思路同 WKRichTextCell.m 的 triggerImageDownloads:。
- (void)triggerImageDownloads:(NSAttributedString *)attr forMessageId:(uint64_t)messageId {
    if (attr.length == 0) return;
    __weak typeof(self) weakSelf = self;
    [attr enumerateAttribute:NSAttachmentAttributeName
                     inRange:NSMakeRange(0, attr.length)
                     options:0
                  usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (![value isKindOfClass:[WKRemoteImageAttachment class]]) return;
        WKRemoteImageAttachment *attachment = (WKRemoteImageAttachment *)value;
        if (attachment.image) return; // 内存命中，首帧就已画出
        NSRange capturedRange = range;
        [attachment startDownload:^(UIImage *img) {
            dispatch_async(dispatch_get_main_queue(), ^{
                typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                if (strongSelf.lastRenderedMessageId != messageId) return; // cell 复用错位
                NSLayoutManager *lm = strongSelf.textView.layoutManager;
                if (capturedRange.location + capturedRange.length > strongSelf.textView.attributedText.length) {
                    [strongSelf.textView setNeedsDisplay];
                    return;
                }
                NSRange glyphRange = [lm glyphRangeForCharacterRange:capturedRange actualCharacterRange:NULL];
                [lm invalidateDisplayForGlyphRange:glyphRange];
                [strongSelf.textView setNeedsDisplay];
            });
        }];
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.textView.frame = CGRectMake(0, 0, self.messageContentView.lim_width, self.messageContentView.lim_height);
}

#pragma mark - 点击内联图片弹全屏预览

- (void)onTapRichText:(UITapGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:self.textView];
    NSUInteger charIndex = [self richCharacterIndexAtPoint:point];
    if (charIndex == NSNotFound) return;
    NSAttributedString *attr = self.textView.attributedText;
    if (charIndex >= attr.length) return;
    id attach = [attr attribute:NSAttachmentAttributeName atIndex:charIndex effectiveRange:nil];
    if (![attach isKindOfClass:[WKRemoteImageAttachment class]]) return;
    [self showImageBrowserAtCharIndex:charIndex];
}

// point（textView 坐标系）→ 字符下标；落在 glyph rect 外返回 NSNotFound（防点空白误开图）。
- (NSUInteger)richCharacterIndexAtPoint:(CGPoint)point {
    NSAttributedString *attr = self.textView.attributedText;
    if (attr.length == 0) return NSNotFound;
    NSLayoutManager *lm = self.textView.layoutManager;
    NSTextContainer *tc = self.textView.textContainer;
    [lm ensureLayoutForTextContainer:tc];
    UIEdgeInsets inset = self.textView.textContainerInset;
    CGPoint ptInContainer = CGPointMake(point.x - inset.left, point.y - inset.top);
    NSUInteger glyphIndex = [lm glyphIndexForPoint:ptInContainer inTextContainer:tc];
    if (glyphIndex >= [lm numberOfGlyphs]) return NSNotFound;
    CGRect glyphRect = [lm boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1) inTextContainer:tc];
    if (!CGRectContainsPoint(glyphRect, ptInContainer)) return NSNotFound;
    return [lm characterIndexForGlyphAtIndex:glyphIndex];
}

// 收集该消息全部内联图片，YBImageBrowser 弹预览，命中页定位到点中那张（多图可左右切）。
// 与本文件 WKMergeForwardDetailImageCell 共用同一套 YBImageBrowser 方案。
- (void)showImageBrowserAtCharIndex:(NSUInteger)hitCharIndex {
    NSAttributedString *attr = self.textView.attributedText;
    NSMutableArray<YBIBImageData *> *dataSource = [NSMutableArray array];
    __block NSInteger hitIdx = -1;
    __block NSInteger runningIdx = 0;
    [attr enumerateAttribute:NSAttachmentAttributeName
                     inRange:NSMakeRange(0, attr.length)
                     options:0
                  usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (![value isKindOfClass:[WKRemoteImageAttachment class]]) return;
        WKRemoteImageAttachment *att = (WKRemoteImageAttachment *)value;
        YBIBImageData *item = [YBIBImageData new];
        if (att.url.length > 0) {
            item.imageURL = [NSURL URLWithString:att.url];
        }
        if (att.image) {
            UIImage *cached = att.image;
            item.image = ^UIImage *_Nullable{ return cached; };
        }
        [dataSource addObject:item];
        if (hitCharIndex >= range.location && hitCharIndex < NSMaxRange(range)) {
            hitIdx = runningIdx;
        }
        runningIdx++;
    }];
    if (dataSource.count == 0) return;
    if (hitIdx < 0) hitIdx = 0;

    YBImageBrowser *imageBrowser = [[YBImageBrowser alloc] init];
    imageBrowser.webImageMediator = [WKDefaultWebImageMediator new];
    imageBrowser.toolViewHandlers = @[WKBrowserToolbar.new];
    imageBrowser.dataSourceArray = dataSource;
    imageBrowser.currentPage = hitIdx;
    [imageBrowser show];
}

- (WKMessageTextView *)textView {
    if (!_textView) {
        _textView = [[WKMessageTextView alloc] init];
        _textView.backgroundColor = [UIColor clearColor];
    }
    return _textView;
}

@end

//---------- 文件cell ----------

@implementation WKMergeForwardDetailFileModel

- (Class)cell {
    return WKMergeForwardDetailFileCell.class;
}

@end

@interface WKMergeForwardDetailFileCell () <UIDocumentInteractionControllerDelegate>

@property(nonatomic,strong) UIImageView *fileIconView;
@property(nonatomic,strong) UILabel *fileNameLbl;
@property(nonatomic,strong) UILabel *fileSizeLbl;
@property(nonatomic,strong) UIDocumentInteractionController *documentController;
@property(nonatomic,strong) WKDownloadProgressOverlay *downloadProgressView;

@end

@implementation WKMergeForwardDetailFileCell

+ (CGFloat)contentHeightForModel:(WKMergeForwardDetailFileModel *)model maxWidth:(CGFloat)maxWidth {
    return 72.0f;
}

- (void)setupUI {
    [super setupUI];

    self.fileIconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    self.fileIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.messageContentView addSubview:self.fileIconView];

    self.fileNameLbl = [[UILabel alloc] init];
    self.fileNameLbl.font = [[WKApp shared].config appFontOfSize:15.0f];
    self.fileNameLbl.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.fileNameLbl.numberOfLines = 1;
    [self.messageContentView addSubview:self.fileNameLbl];

    self.fileSizeLbl = [[UILabel alloc] init];
    self.fileSizeLbl.font = [UIFont systemFontOfSize:12.0f];
    self.fileSizeLbl.textColor = [UIColor grayColor];
    [self.messageContentView addSubview:self.fileSizeLbl];

    self.messageContentView.layer.masksToBounds = YES;
    self.messageContentView.layer.cornerRadius = 4.0f;
    [self.messageContentView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];

    self.downloadProgressView = [[WKDownloadProgressOverlay alloc] init];
    self.downloadProgressView.layer.masksToBounds = YES;
    self.downloadProgressView.layer.cornerRadius = 4.0f;
    [self.messageContentView addSubview:self.downloadProgressView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onFileTap)];
    self.messageContentView.userInteractionEnabled = YES;
    [self.messageContentView addGestureRecognizer:tap];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDownloadProgress:) name:kMergeForwardDownloadNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMergeForwardDownloadNotification object:nil];
}

- (void)onDownloadProgress:(NSNotification *)notification {
    NSNumber *msgKey = notification.object;
    if (!self.model || ![msgKey isEqualToNumber:@(self.model.message.messageId)]) return;
    NSString *state = notification.userInfo[@"state"];
    if ([state isEqualToString:@"downloading"]) {
        CGFloat progress = [notification.userInfo[@"progress"] floatValue];
        [self.downloadProgressView showWithProgress:progress];
    } else if ([state isEqualToString:@"success"]) {
        [self.downloadProgressView dismiss];
        WKFileContent *fileContent = (WKFileContent *)self.model.message.content;
        NSString *downloadedPath = fileContent.localPath;
        if (downloadedPath && [[NSFileManager defaultManager] fileExistsAtPath:downloadedPath]) {
            [self previewFileAtPath:downloadedPath];
        }
    } else { // fail / cancelled
        [self.downloadProgressView dismiss];
    }
}

- (void)refresh:(WKMergeForwardDetailFileModel *)model {
    [super refresh:model];
    if(![model.message.content isKindOfClass:[WKFileContent class]]) {
        self.fileNameLbl.text = @"[未知文件]";
        self.fileSizeLbl.text = @"";
        return;
    }
    WKFileContent *fileContent = (WKFileContent *)model.message.content;
    self.fileNameLbl.text = fileContent.name ?: @"";
    self.fileSizeLbl.text = [self formatFileSize:fileContent.fileSize];
    self.fileNameLbl.textColor = [WKApp shared].config.defaultTextColor;

    // 恢复下载进度状态
    NSNumber *msgKey = @(model.message.messageId);
    NSNumber *cachedProgress = downloadingMessages()[msgKey];
    if (cachedProgress) {
        [self.downloadProgressView showWithProgress:[cachedProgress floatValue]];
    } else {
        [self.downloadProgressView dismiss];
    }

    NSString *ext = fileContent.fileExtension;
    if (!ext || ext.length == 0 || [ext isEqualToString:@"."]) {
        ext = [fileContent.name pathExtension];
    }
    self.fileIconView.image = [self iconForFileExtension:ext];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat padding = 12.0f;
    self.fileIconView.lim_left = padding;
    self.fileIconView.lim_top = (self.messageContentView.lim_height - 40) / 2.0f;

    CGFloat textLeft = self.fileIconView.lim_right + 10.0f;
    CGFloat textMaxWidth = self.messageContentView.lim_width - textLeft - padding;

    self.fileNameLbl.lim_left = textLeft;
    self.fileNameLbl.lim_top = padding;
    self.fileNameLbl.lim_width = textMaxWidth;
    self.fileNameLbl.lim_height = 20.0f;

    self.fileSizeLbl.lim_left = textLeft;
    self.fileSizeLbl.lim_top = self.fileNameLbl.lim_bottom + 4.0f;
    self.fileSizeLbl.lim_width = textMaxWidth;
    self.fileSizeLbl.lim_height = 16.0f;

    self.downloadProgressView.frame = self.messageContentView.bounds;
}

- (void)onFileTap {
    WKFileContent *fileContent = (WKFileContent *)self.model.message.content;
    NSString *localPath = fileContent.localPath;
    if (localPath && [[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        [self previewFileAtPath:localPath];
        return;
    }
    if (fileContent.remoteUrl && fileContent.remoteUrl.length > 0) {
        // 下载中再点击 → 取消
        NSNumber *msgKey = @(self.model.message.messageId);
        if (downloadingMessages()[msgKey]) {
            cancelDownloadForMessage(self.model.message);
            return;
        }
        startDownloadForMessage(self.model.message, nil);
    }
}

- (void)previewFileAtPath:(NSString *)path {
    WKFileContent *fileContent = (WKFileContent *)self.model.message.content;
    NSString *realName = fileContent.name;
    NSString *previewPath = path;
    if (realName && realName.length > 0) {
        NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WKFilePreview"];
        [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *destPath = [tmpDir stringByAppendingPathComponent:realName];
        [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
        if ([[NSFileManager defaultManager] linkItemAtPath:path toPath:destPath error:nil]) {
            previewPath = destPath;
        } else if ([[NSFileManager defaultManager] copyItemAtPath:path toPath:destPath error:nil]) {
            previewPath = destPath;
        }
    }
    NSURL *fileURL = [NSURL fileURLWithPath:previewPath];
    [WKSafeFilePreviewVC showFilePreview:fileURL title:fileURL.lastPathComponent];
}

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return [WKNavigationManager shared].topViewController;
}

- (UIImage *)iconForFileExtension:(NSString *)ext {
    NSString *lowExt = [ext lowercaseString];
    if ([lowExt hasPrefix:@"."]) {
        lowExt = [lowExt substringFromIndex:1];
    }
    NSString *imageName = nil;
    if ([@[@"doc", @"docx", @"docm", @"dot", @"dotx", @"dotm", @"rtf", @"odt", @"wps"] containsObject:lowExt]) {
        imageName = @"FileType/FileWord";
    } else if ([@[@"xls", @"xlsx", @"xlsm", @"xlsb", @"xlt", @"xltx", @"xltm", @"csv", @"ods", @"et", @"ett"] containsObject:lowExt]) {
        imageName = @"FileType/FileExcel";
    } else if ([lowExt isEqualToString:@"pdf"]) {
        imageName = @"FileType/FilePDF";
    } else if ([@[@"ppt", @"pptx", @"pptm", @"pps", @"ppsx", @"ppsm", @"pot", @"potx", @"potm", @"odp", @"dps", @"dpt"] containsObject:lowExt]) {
        imageName = @"FileType/FilePPT";
    } else if ([@[@"mp4", @"mov", @"avi", @"mkv", @"wmv", @"flv", @"webm", @"m4v", @"mpg", @"mpeg", @"3gp", @"3gpp", @"ts", @"rmvb", @"rm"] containsObject:lowExt]) {
        imageName = @"FileType/FileVideo";
    } else if ([@[@"md", @"markdown", @"mdown", @"mkd", @"mdwn"] containsObject:lowExt]) {
        imageName = @"FileType/FileMarkdown";
    }
    if (imageName) {
        UIImage *img = [[WKApp shared] loadImage:imageName moduleID:@"WuKongBase"];
        if (img) {
            self.fileIconView.tintColor = nil;
            return [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        }
    }
    self.fileIconView.tintColor = [UIColor systemBlueColor];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightRegular];
        return [UIImage systemImageNamed:@"doc.fill" withConfiguration:config];
    }
    return nil;
}

- (NSString *)formatFileSize:(long long)size {
    if (size < 1024) {
        return [NSString stringWithFormat:@"%lld B", size];
    } else if (size < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", size / 1024.0];
    } else if (size < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB", size / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.1f GB", size / (1024.0 * 1024.0 * 1024.0)];
    }
}

@end


//---------- 语音cell ----------

@implementation WKMergeForwardDetailVoiceModel

- (Class)cell {
    return WKMergeForwardDetailVoiceCell.class;
}

@end

@interface WKMergeForwardDetailVoiceCell ()

@property(nonatomic,strong) UIImageView *playIconView;
@property(nonatomic,strong) UILabel *durationLbl;
@property(nonatomic,strong) UIActivityIndicatorView *voiceLoadingView;
@property(nonatomic,assign) BOOL isPlaying;
@property(nonatomic,assign) BOOL isDownloading;

@end

@implementation WKMergeForwardDetailVoiceCell

+ (CGFloat)contentHeightForModel:(WKMergeForwardDetailVoiceModel *)model maxWidth:(CGFloat)maxWidth {
    return 50.0f;
}

- (void)setupUI {
    [super setupUI];

    self.playIconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 36, 36)];
    self.playIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.playIconView.tintColor = [WKApp shared].config.themeColor;
    [self.messageContentView addSubview:self.playIconView];

    self.durationLbl = [[UILabel alloc] init];
    self.durationLbl.font = [UIFont systemFontOfSize:14.0f];
    self.durationLbl.textColor = [WKApp shared].config.defaultTextColor;
    [self.messageContentView addSubview:self.durationLbl];

    self.voiceLoadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.voiceLoadingView.hidesWhenStopped = YES;
    [self.messageContentView addSubview:self.voiceLoadingView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onVoiceTap)];
    self.messageContentView.userInteractionEnabled = YES;
    [self.messageContentView addGestureRecognizer:tap];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDownloadProgress:) name:kMergeForwardDownloadNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMergeForwardDownloadNotification object:nil];
}

- (void)onDownloadProgress:(NSNotification *)notification {
    NSNumber *msgKey = notification.object;
    if (!self.model || ![msgKey isEqualToNumber:@(self.model.message.messageId)]) return;
    NSString *state = notification.userInfo[@"state"];
    if ([state isEqualToString:@"downloading"]) {
        self.isDownloading = YES;
        self.playIconView.hidden = YES;
        [self.voiceLoadingView startAnimating];
    } else { // success / fail / cancelled
        self.isDownloading = NO;
        self.playIconView.hidden = NO;
        [self.voiceLoadingView stopAnimating];
        if ([state isEqualToString:@"success"]) {
            // 下载完成后转码 AMR → WAV，再播放
            [[WKSDK shared].mediaManager voiceMessageThumbToSource:self.model.message];
            WKVoiceContent *voiceContent = (WKVoiceContent *)self.model.message.content;
            if (voiceContent.localPath && [[NSFileManager defaultManager] fileExistsAtPath:voiceContent.localPath]) {
                [self playAudioAtPath:voiceContent.localPath];
            }
        }
    }
}

- (void)refresh:(WKMergeForwardDetailVoiceModel *)model {
    [super refresh:model];
    WKVoiceContent *voiceContent = (WKVoiceContent *)model.message.content;
    NSInteger second = voiceContent.second;
    self.durationLbl.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)(second / 60), (long)(second % 60)];
    [self.durationLbl sizeToFit];

    // 恢复下载状态
    NSNumber *msgKey = @(model.message.messageId);
    if (downloadingMessages()[msgKey]) {
        self.isDownloading = YES;
        self.playIconView.hidden = YES;
        [self.voiceLoadingView startAnimating];
    } else {
        self.isDownloading = NO;
        self.playIconView.hidden = NO;
        [self.voiceLoadingView stopAnimating];
    }
    [self updatePlayIcon];
}

- (void)updatePlayIcon {
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightRegular];
        NSString *name = self.isPlaying ? @"stop.circle.fill" : @"play.circle.fill";
        self.playIconView.image = [UIImage systemImageNamed:name withConfiguration:config];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.playIconView.lim_left = 4.0f;
    self.playIconView.lim_centerY_parent = self.messageContentView;

    self.durationLbl.lim_left = self.playIconView.lim_right + 8.0f;
    self.durationLbl.lim_centerY_parent = self.messageContentView;

    self.voiceLoadingView.center = self.playIconView.center;
}

- (void)onVoiceTap {
    if (self.isPlaying) {
        [[WKSDK shared].mediaManager stopAudioPlay];
        self.isPlaying = NO;
        [self updatePlayIcon];
        return;
    }
    // 下载中再点击 → 取消
    if (self.isDownloading) {
        cancelDownloadForMessage(self.model.message);
        return;
    }

    WKVoiceContent *voiceContent = (WKVoiceContent *)self.model.message.content;

    // 1. localPath 存在（已转码的 WAV）→ 直接播放
    if (voiceContent.localPath && [[NSFileManager defaultManager] fileExistsAtPath:voiceContent.localPath]) {
        [self playAudioAtPath:voiceContent.localPath];
        return;
    }

    // 2. thumbPath 存在（下载的 AMR 副本）→ 转码后播放
    if (voiceContent.thumbPath && [[NSFileManager defaultManager] fileExistsAtPath:voiceContent.thumbPath]) {
        [[WKSDK shared].mediaManager voiceMessageThumbToSource:self.model.message];
        if (voiceContent.localPath && [[NSFileManager defaultManager] fileExistsAtPath:voiceContent.localPath]) {
            [self playAudioAtPath:voiceContent.localPath];
        }
        return;
    }

    // 3. 都不存在 → 下载
    if (voiceContent.remoteUrl && voiceContent.remoteUrl.length > 0) {
        startDownloadForMessage(self.model.message, nil);
    }
}

- (void)playAudioAtPath:(NSString *)path {
    self.isPlaying = YES;
    [self updatePlayIcon];
    __weak typeof(self) weakSelf = self;
    [[WKSDK shared].mediaManager playAudio:path playerDidFinish:^(AVAudioPlayer *player, BOOL successFlag) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.isPlaying = NO;
            [weakSelf updatePlayIcon];
        });
    } progress:nil];
}

@end


//---------- 视频cell ----------

@implementation WKMergeForwardDetailVideoModel

- (Class)cell {
    return WKMergeForwardDetailVideoCell.class;
}

@end

@interface WKMergeForwardDetailVideoCell ()

@property(nonatomic,strong) UIImageView *videoImgView;
@property(nonatomic,strong) UIImageView *playOverlayView;
@property(nonatomic,strong) WKDownloadProgressOverlay *videoProgressView;

@end

@implementation WKMergeForwardDetailVideoCell

+ (CGFloat)contentHeightForModel:(WKMergeForwardDetailVideoModel *)model maxWidth:(CGFloat)maxWidth {
    if(![model.message.content isKindOfClass:[WKImageContent class]]) return 150.0f;
    WKImageContent *imageContent = (WKImageContent *)model.message.content;
    if (imageContent.width > 0 && imageContent.height > 0) {
        return [UIImage lim_sizeWithImageOriginSize:CGSizeMake(imageContent.width, imageContent.height) maxLength:maxWidth].height;
    }
    return 150.0f;
}

- (void)setupUI {
    [super setupUI];

    self.videoImgView = [[UIImageView alloc] init];
    self.videoImgView.layer.masksToBounds = YES;
    self.videoImgView.layer.cornerRadius = 4.0f;
    self.videoImgView.contentMode = UIViewContentModeScaleAspectFill;
    [self.messageContentView addSubview:self.videoImgView];

    self.playOverlayView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    self.playOverlayView.contentMode = UIViewContentModeScaleAspectFit;
    self.playOverlayView.tintColor = [UIColor whiteColor];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:36 weight:UIImageSymbolWeightRegular];
        self.playOverlayView.image = [UIImage systemImageNamed:@"play.circle.fill" withConfiguration:config];
    }
    [self.messageContentView addSubview:self.playOverlayView];

    self.videoProgressView = [[WKDownloadProgressOverlay alloc] init];
    self.videoProgressView.layer.masksToBounds = YES;
    self.videoProgressView.layer.cornerRadius = 4.0f;
    [self.messageContentView addSubview:self.videoProgressView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onVideoTap)];
    self.messageContentView.userInteractionEnabled = YES;
    [self.messageContentView addGestureRecognizer:tap];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDownloadProgress:) name:kMergeForwardDownloadNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMergeForwardDownloadNotification object:nil];
}

- (void)onDownloadProgress:(NSNotification *)notification {
    NSNumber *msgKey = notification.object;
    if (!self.model || ![msgKey isEqualToNumber:@(self.model.message.messageId)]) return;
    NSString *state = notification.userInfo[@"state"];
    if ([state isEqualToString:@"downloading"]) {
        CGFloat progress = [notification.userInfo[@"progress"] floatValue];
        self.playOverlayView.hidden = YES;
        [self.videoProgressView showWithProgress:progress];
    } else { // success / fail / cancelled
        self.playOverlayView.hidden = NO;
        [self.videoProgressView dismiss];
        if ([state isEqualToString:@"success"]) {
            WKImageContent *imageContent = (WKImageContent *)self.model.message.content;
            NSString *downloadedPath = imageContent.localPath;
            if (downloadedPath && [[NSFileManager defaultManager] fileExistsAtPath:downloadedPath]) {
                [self playVideoAtPath:downloadedPath];
            }
        }
    }
}

- (void)refresh:(WKMergeForwardDetailVideoModel *)model {
    [super refresh:model];
    WKImageContent *imageContent = (WKImageContent *)model.message.content;
    NSURL *url = [[WKApp shared] getImageFullUrl:imageContent.remoteUrl];
    [self.videoImgView lim_setImageWithURL:url placeholderImage:[WKApp shared].config.defaultPlaceholder];

    // 恢复下载进度状态
    NSNumber *msgKey = @(model.message.messageId);
    NSNumber *cachedProgress = downloadingMessages()[msgKey];
    if (cachedProgress) {
        self.playOverlayView.hidden = YES;
        [self.videoProgressView showWithProgress:[cachedProgress floatValue]];
    } else {
        self.playOverlayView.hidden = NO;
        [self.videoProgressView dismiss];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    WKImageContent *imageContent = (WKImageContent *)self.model.message.content;
    if (imageContent.width > 0 && imageContent.height > 0) {
        self.videoImgView.lim_size = [UIImage lim_sizeWithImageOriginSize:CGSizeMake(imageContent.width, imageContent.height) maxLength:contentMaxWidth];
    } else {
        self.videoImgView.lim_size = CGSizeMake(contentMaxWidth, 150.0f);
    }
    self.playOverlayView.center = CGPointMake(self.videoImgView.lim_width / 2.0f, self.videoImgView.lim_height / 2.0f);
    self.videoProgressView.frame = self.videoImgView.frame;
}

- (void)onVideoTap {
    WKImageContent *imageContent = (WKImageContent *)self.model.message.content;
    NSString *localPath = imageContent.localPath;

    if (localPath && [[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        [self playVideoAtPath:localPath];
        return;
    }
    if (imageContent.remoteUrl && imageContent.remoteUrl.length > 0) {
        // 下载中再点击 → 取消
        NSNumber *msgKey = @(self.model.message.messageId);
        if (downloadingMessages()[msgKey]) {
            cancelDownloadForMessage(self.model.message);
            return;
        }
        startDownloadForMessage(self.model.message, nil);
    }
}

- (void)playVideoAtPath:(NSString *)path {
    [self playVideoWithURL:[NSURL fileURLWithPath:path]];
}

- (void)playVideoWithURL:(NSURL *)url {
    AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
    playerVC.player = [AVPlayer playerWithURL:url];
    UIViewController *topVC = [WKNavigationManager shared].topViewController;
    [topVC presentViewController:playerVC animated:YES completion:^{
        [playerVC.player play];
    }];
}

@end


//---------- 嵌套合并转发cell ----------

@implementation WKMergeForwardDetailNestedModel

- (Class)cell {
    return WKMergeForwardDetailNestedCell.class;
}

@end

@interface WKMergeForwardDetailNestedCell ()

@property(nonatomic,strong) UILabel *nestedTitleLbl;
@property(nonatomic,strong) UIView *nestedMessageBox;
@property(nonatomic,strong) UIView *nestedLineView;
@property(nonatomic,strong) UILabel *nestedDescLbl;

@end

#define nestedTitleHeight 18.0f
#define nestedTitleTop 10.0f
#define nestedMsgBoxTop 4.0f
#define nestedMsgHeight 13.0f
#define nestedLineTop 4.0f
#define nestedDescHeight 26.0f
#define nestedPadding 10.0f

@implementation WKMergeForwardDetailNestedCell

+ (CGFloat)contentHeightForModel:(WKMergeForwardDetailNestedModel *)model maxWidth:(CGFloat)maxWidth {
    if(![model.message.content isKindOfClass:[WKMergeForwardContent class]]) return 80.0f;
    WKMergeForwardContent *content = (WKMergeForwardContent *)model.message.content;
    NSInteger msgCount = content.msgs.count > 4 ? 4 : content.msgs.count;
    return nestedTitleTop + nestedTitleHeight + nestedMsgBoxTop + nestedMsgHeight * msgCount + nestedLineTop + 1.0f + nestedDescHeight;
}

- (void)setupUI {
    [super setupUI];

    self.messageContentView.layer.masksToBounds = YES;
    self.messageContentView.layer.cornerRadius = 4.0f;
    [self.messageContentView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];

    self.nestedTitleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, nestedTitleHeight)];
    self.nestedTitleLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
    self.nestedTitleLbl.textColor = [WKApp shared].config.defaultTextColor;
    [self.messageContentView addSubview:self.nestedTitleLbl];

    self.nestedMessageBox = [[UIView alloc] init];
    [self.messageContentView addSubview:self.nestedMessageBox];

    self.nestedLineView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 1.0f)];
    self.nestedLineView.backgroundColor = [WKApp shared].config.lineColor;
    [self.messageContentView addSubview:self.nestedLineView];

    self.nestedDescLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, nestedDescHeight)];
    self.nestedDescLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
    self.nestedDescLbl.textColor = [WKApp shared].config.tipColor;
    self.nestedDescLbl.text = LLang(@"聊天记录");
    [self.messageContentView addSubview:self.nestedDescLbl];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onNestedTap)];
    self.messageContentView.userInteractionEnabled = YES;
    [self.messageContentView addGestureRecognizer:tap];
}

- (void)refresh:(WKMergeForwardDetailNestedModel *)model {
    [super refresh:model];
    WKMergeForwardContent *content = (WKMergeForwardContent *)model.message.content;

    self.nestedTitleLbl.text = content.title;

    [[self.nestedMessageBox subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    if (content.msgs && content.msgs.count > 0) {
        for (NSInteger i = 0; i < content.msgs.count && i < 4; i++) {
            WKMessage *msg = content.msgs[i];
            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, nestedMsgHeight)];
            lbl.font = [[WKApp shared].config appFontOfSize:11.0f];
            lbl.textColor = [WKApp shared].config.tipColor;
            NSString *fromName = @"";
            if (msg.from) {
                fromName = msg.from.displayName;
            }
            lbl.text = [NSString stringWithFormat:@"%@: %@", fromName, [msg.content conversationDigest]];
            [self.nestedMessageBox addSubview:lbl];
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.nestedTitleLbl.lim_top = nestedTitleTop;
    self.nestedTitleLbl.lim_left = nestedPadding;
    self.nestedTitleLbl.lim_width = self.messageContentView.lim_width - nestedPadding * 2;

    self.nestedMessageBox.lim_top = self.nestedTitleLbl.lim_bottom + nestedMsgBoxTop;
    self.nestedMessageBox.lim_width = self.messageContentView.lim_width;
    self.nestedMessageBox.lim_height = nestedMsgHeight * self.nestedMessageBox.subviews.count;
    for (NSInteger i = 0; i < self.nestedMessageBox.subviews.count; i++) {
        UIView *v = self.nestedMessageBox.subviews[i];
        v.lim_left = nestedPadding;
        v.lim_top = i * nestedMsgHeight;
        v.lim_width = self.messageContentView.lim_width - nestedPadding * 2;
        v.lim_height = nestedMsgHeight;
    }

    self.nestedLineView.lim_left = nestedPadding;
    self.nestedLineView.lim_width = self.messageContentView.lim_width - nestedPadding * 2;
    self.nestedLineView.lim_top = self.nestedMessageBox.lim_bottom + nestedLineTop;

    self.nestedDescLbl.lim_left = nestedPadding;
    self.nestedDescLbl.lim_width = self.messageContentView.lim_width - nestedPadding * 2;
    self.nestedDescLbl.lim_top = self.nestedLineView.lim_bottom;
}

- (void)onNestedTap {
    WKMergeForwardContent *content = (WKMergeForwardContent *)self.model.message.content;
    WKMergeForwardDetailVC *vc = [WKMergeForwardDetailVC new];
    vc.mergeForwardContent = content;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

@end


//---------- 表情/贴图 cell（WK_LOTTIE_STICKER=12 / WK_EMOJI_STICKER=13 / WK_GIF=3）----------

@implementation WKMergeForwardDetailStickerModel

- (Class)cell {
    return WKMergeForwardDetailStickerCell.class;
}

@end

@interface WKMergeForwardDetailStickerCell ()

@property(nonatomic,strong) WKStickerImageView *stickerImageView;

@end

@implementation WKMergeForwardDetailStickerCell

// 与聊天页 WKLottieStickerCell 一致：固定 160×160 缩略呈现
+ (CGFloat)contentHeightForModel:(WKMergeForwardDetailStickerModel *)model maxWidth:(CGFloat)maxWidth {
    return 160.0f;
}

- (void)setupUI {
    [super setupUI];
    self.stickerImageView = [[WKStickerImageView alloc] initWithFrame:CGRectMake(0, 0, 160.0f, 160.0f)];
    [self.messageContentView addSubview:self.stickerImageView];
}

- (void)refresh:(WKMergeForwardDetailStickerModel *)model {
    [super refresh:model];
    NSString *url = nil;
    NSString *placeholder = nil;
    if ([model.message.content isKindOfClass:[WKLottieStickerContent class]]) {
        // WK_LOTTIE_STICKER=12 / WK_EMOJI_STICKER=13 (WKEmojiStickerContent 继承 WKLottieStickerContent)
        WKLottieStickerContent *c = (WKLottieStickerContent *)model.message.content;
        url = c.url;
        placeholder = c.placeholder;
    } else if ([model.message.content isKindOfClass:[WKGIFContent class]]) {
        WKGIFContent *c = (WKGIFContent *)model.message.content;
        url = c.url;
    }
    self.stickerImageView.placehoderSvg = placeholder; // placehoderSvg 必须在 stickerURL 前
    self.stickerImageView.stickerURL = [[WKApp shared] getFileFullUrl:url];
    self.stickerImageView.isPlay = YES;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.stickerImageView.frame = CGRectMake(0, 0, 160.0f, 160.0f);
}

@end


//----------其他cell ----------

@implementation WKMergeForwardDetailOtherModel


- (Class)cell {
    return WKMergeForwardDetailOtherCell.class;
}
@end

@interface WKMergeForwardDetailOtherCell ()

@property(nonatomic,strong) UILabel *textLbl;

@end

@implementation WKMergeForwardDetailOtherCell


+ (CGFloat)contentHeightForModel:(WKMergeForwardDetailTextModel *)model maxWidth:(CGFloat)maxWidth{
    NSString *conversationDigest = [model.message.content conversationDigest];
    if(!conversationDigest || conversationDigest.length == 0) {
        conversationDigest = @"[未知消息]";
    }
    CGSize size = [self getTextSize:conversationDigest maxWidth:maxWidth fontSize:[WKApp shared].config.messageTextFontSize];
    return size.height;
}

- (void)setupUI {
    [super setupUI];
    
    [self.messageContentView addSubview:self.textLbl];
}

- (void)refresh:(WKMergeForwardDetailTextModel *)model {
    [super refresh:model];
    
    NSString *conversationDigest = [model.message.content conversationDigest];
    if(conversationDigest && ![conversationDigest isEqualToString:@""]) {
        self.textLbl.text = conversationDigest;
    }else{
        self.textLbl.text = @"[未知消息]";
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.textLbl.lim_top = 0.0f;
    self.textLbl.lim_size = self.messageContentView.lim_size;
}


- (UILabel *)textLbl {
    if(!_textLbl) {
        _textLbl = [[UILabel alloc] init];
//        _textLbl.delegate = self;
        [_textLbl setFont:[UIFont systemFontOfSize:[WKApp shared].config.messageTextFontSize]];
        _textLbl.numberOfLines = 0;
        _textLbl.lineBreakMode = NSLineBreakByWordWrapping;
//        _textLbl.backgroundColor = [UIColor redColor];
    //    [self.textLbl setTextColor:[WKApp shared].config.defaultTextColor];
    }
    return _textLbl;
}

+ (CGSize) getTextSize:(NSString*) text maxWidth:(CGFloat)maxWidth fontSize:(CGFloat)fontSize{
    if (!text || text.length == 0) {
        return CGSizeZero;
    }
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.alignment = NSTextAlignmentCenter;
    NSAttributedString *string = [[NSAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:fontSize], NSParagraphStyleAttributeName:style}];
    CGSize size =  [string boundingRectWithSize:CGSizeMake(maxWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil].size;
    return size;
}


@end
