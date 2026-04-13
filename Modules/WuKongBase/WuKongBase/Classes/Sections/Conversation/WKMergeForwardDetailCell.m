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
#import "WKMergeForwardContent.h"
#import "WKMergeForwardDetailVC.h"
#import <AVKit/AVKit.h>
#import <WebKit/WebKit.h>
#import <WuKongBase/WuKongBase-Swift.h>
#import "UIColor+WK.h"

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
    if(model.message.from) {
        self.nameLbl.text = model.message.from.displayName;
    }else{
        [[WKSDK shared].channelManager fetchChannelInfo:[[WKChannel alloc] initWith:model.message.fromUid channelType:WK_PERSON]];
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

@interface WKMergeForwardDetailTextCell () <WKNavigationDelegate, UIScrollViewDelegate>

@property(nonatomic,strong) M80AttributedLabel *textLbl;
@property(nonatomic,strong) UILabel *markdownLbl;
@property(nonatomic,strong) NSMutableArray<UIView *> *segmentViews;
@property(nonatomic,strong) NSMutableArray<WKWebView *> *tableWebViews;
@property(nonatomic,strong) NSMutableArray<UIScrollView *> *tableOverlays;
@property(nonatomic,strong) NSMutableArray<NSString *> *tableRawContents;
@property(nonatomic,assign) BOOL segmentsBuilt;

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
    [self.textLbl setBackgroundColor:[UIColor clearColor]];
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
    return sv;
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

    WKTextContent *textContent = (WKTextContent *)[model.message content];
    NSString *content = textContent.content;
    UIColor *textColor = [WKApp shared].config.defaultTextColor;
    NSString *colorHex = [textColor toHexRGB];
    BOOL hasTable = [WKMarkdownRenderer containsTable:content];

    if (hasTable) {
        self.textLbl.hidden = YES;
        self.markdownLbl.hidden = YES;

        if (!self.segmentsBuilt) {
            [self clearSegmentViews];
            NSArray *segments = [WKMarkdownRenderer splitContentSegments:content];
            for (NSDictionary *seg in segments) {
                NSString *type = seg[@"type"];
                NSString *segContent = seg[@"content"];
                if ([type isEqualToString:@"text"]) {
                    UILabel *lbl = [[UILabel alloc] init];
                    lbl.font = [UIFont systemFontOfSize:[WKApp shared].config.messageTextFontSize];
                    lbl.textColor = textColor;
                    lbl.numberOfLines = 0;
                    lbl.lineBreakMode = NSLineBreakByWordWrapping;
                    lbl.backgroundColor = [UIColor clearColor];
                    if ([WKMarkdownRenderer containsMarkdown:segContent]) {
                        NSAttributedString *mdAttr = [WKMarkdownRenderer render:segContent fontSize:[WKApp shared].config.messageTextFontSize textColorHex:colorHex];
                        if (mdAttr) { lbl.attributedText = mdAttr; }
                        else { lbl.text = segContent; }
                    } else {
                        lbl.text = segContent;
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
        }
    } else if ([WKMarkdownRenderer containsMarkdown:content]) {
        self.textLbl.hidden = YES;
        self.markdownLbl.hidden = NO;
        [self clearSegmentViews];
        @try {
            NSAttributedString *mdAttr = [WKMarkdownRenderer render:content fontSize:[WKApp shared].config.messageTextFontSize textColorHex:colorHex];
            if (mdAttr && mdAttr.length > 0) {
                self.markdownLbl.attributedText = mdAttr;
            } else {
                self.textLbl.hidden = NO;
                self.markdownLbl.hidden = YES;
                [self.textLbl lim_setText:content mentionInfo:textContent.mentionedInfo];
            }
        } @catch (NSException *exception) {
            // Down 库 WebKit 渲染在嵌套 RunLoop 中可能触发 autorelease pool 断言，fallback 到纯文本
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
            if ([v isKindOfClass:[UILabel class]]) {
                CGSize fitSize = [(UILabel *)v sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];
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

#pragma mark - WKNavigationDelegate (WebView 加载完成后同步 contentSize 到遮罩层)

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


- (M80AttributedLabel *)textLbl {
    if(!_textLbl) {
        _textLbl = [[M80AttributedLabel alloc] init];
        _textLbl.underLineForLink = false;
//        _textLbl.delegate = self;
        [_textLbl setFont:[UIFont systemFontOfSize:[WKApp shared].config.messageTextFontSize]];
        [_textLbl setBackgroundColor:[UIColor clearColor]];
        [_textLbl setTextColor:[WKApp shared].config.defaultTextColor];
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

- (UILabel *)markdownLbl {
    if (!_markdownLbl) {
        _markdownLbl = [[UILabel alloc] init];
        _markdownLbl.font = [UIFont systemFontOfSize:[WKApp shared].config.messageTextFontSize];
        _markdownLbl.textColor = [WKApp shared].config.defaultTextColor;
        _markdownLbl.numberOfLines = 0;
        _markdownLbl.lineBreakMode = NSLineBreakByWordWrapping;
        _markdownLbl.backgroundColor = [UIColor clearColor];
        _markdownLbl.hidden = YES;
    }
    return _markdownLbl;
}

-(void) handleLongPressGesture:(UILongPressGestureRecognizer *)longPressGR {
    if (longPressGR.state == UIGestureRecognizerStateBegan) {
        [self becomeFirstResponder];
        UIMenuItem *copyLink = [[UIMenuItem alloc] initWithTitle:@"复制" action:@selector(customcopy:)];
        [[UIMenuController sharedMenuController]  setMenuItems:@[copyLink]];
        [[UIMenuController sharedMenuController] setTargetRect:self.textLbl.frame inView:self.textLbl.superview];
        [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
        self.textLbl.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.2f];
    }else {
        
    }
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
    WKTextContent *textContent = (WKTextContent *)message.content;
    NSString *content = textContent.content;
    CGSize textSize;

    BOOL hasTable = [WKMarkdownRenderer containsTable:content];
    if (hasTable) {
        // 分段计算总高度
        NSArray *segments = [WKMarkdownRenderer splitContentSegments:content];
        UIColor *textColor = [WKApp shared].config.defaultTextColor;
        NSString *colorHex = [textColor toHexRGB];
        CGFloat totalHeight = 0;
        CGFloat totalWidth = maxWidth;

        static UILabel *measureLabel;
        if (!measureLabel) {
            measureLabel = [[UILabel alloc] init];
            measureLabel.numberOfLines = 0;
            measureLabel.lineBreakMode = NSLineBreakByWordWrapping;
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
                        measureLabel.text = segContent;
                    }
                } else {
                    measureLabel.text = segContent;
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
        if (mdAttr && mdAttr.length > 0) {
            CGRect rect = [mdAttr boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil];
            textSize = CGSizeMake(ceilf(rect.size.width), ceilf(rect.size.height));
        } else {
            static M80AttributedLabel *plainLbl;
            if(!plainLbl) {
                plainLbl = [[M80AttributedLabel alloc] init];
                [plainLbl setFont:[UIFont systemFontOfSize:[WKApp shared].config.messageTextFontSize]];
            }
            [plainLbl lim_setText:content];
            textSize = [plainLbl sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];
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
    [[UIPasteboard generalPasteboard] setString:self.textLbl.text];
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
    WKImageContent *imageContent = (WKImageContent*)model.message.content;
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
    self.documentController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.documentController.delegate = self;
    UIViewController *topVC = [WKNavigationManager shared].topViewController;
    if (![self.documentController presentPreviewAnimated:YES]) {
        [self.documentController presentOptionsMenuFromRect:topVC.view.bounds inView:topVC.view animated:YES];
    }
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
