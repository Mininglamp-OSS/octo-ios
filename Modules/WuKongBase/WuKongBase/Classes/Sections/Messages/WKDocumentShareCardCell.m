//
//  WKDocumentShareCardCell.m
//  WuKongBase
//

#import "WKDocumentShareCardCell.h"
#import "WKDocumentShareCardContent.h"
#import "WKDocumentPreviewLoader.h"
#import "WKWebViewVC.h"
#import "WKNavigationManager.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import <WuKongBase/WuKongBase-Swift.h>

// WKMessageListView owns row-height cache invalidation for asynchronously loaded card previews.
@interface NSObject (WKDocumentCardHeightReflow)
- (void)wk_invalidateHeightCacheForMessage:(WKMessageModel *)msg;
@end

static const CGFloat WKDocumentShareCardMaxWidth = 480.0f;
static const CGFloat WKDocumentShareCardPreviewHeight = 264.0f;
static const CGFloat WKDocumentShareCardOuterPadding = 12.0f;

static UIColor *WKDocumentShareCardTint(CGFloat alpha) {
    BOOL dark = [WKApp shared].config.style == WKSystemStyleDark;
    CGFloat adjustedAlpha = dark && alpha == 0.03f ? 0.04f : alpha;
    UIColor *brandTint = dark
        ? UIColor.whiteColor
        : [UIColor colorWithRed:28.0f / 255.0f green:28.0f / 255.0f blue:35.0f / 255.0f alpha:1.0f];
    return [brandTint colorWithAlphaComponent:adjustedAlpha];
}

/// Use an opaque card background so the conversation background does not affect its color.
static UIColor *WKDocumentShareCardBackgroundColor(void) {
    if ([WKApp shared].config.style == WKSystemStyleDark) {
        return [UIColor colorWithRed:37.0f / 255.0f green:37.0f / 255.0f blue:44.0f / 255.0f alpha:1.0f];
    }
    return [UIColor colorWithRed:238.0f / 255.0f green:239.0f / 255.0f blue:241.0f / 255.0f alpha:1.0f];
}

static UIColor *WKDocumentShareCardWarningColor(void) {
    if ([WKApp shared].config.style == WKSystemStyleDark) {
        return [UIColor colorWithRed:1.0f green:173.0f / 255.0f blue:51.0f / 255.0f alpha:1.0f];
    }
    return [UIColor colorWithRed:252.0f / 255.0f green:136.0f / 255.0f blue:0 alpha:1.0f];
}

static UIColor *WKDocumentShareCardErrorColor(void) {
    if ([WKApp shared].config.style == WKSystemStyleDark) {
        return [UIColor colorWithRed:1.0f green:92.0f / 255.0f blue:114.0f / 255.0f alpha:1.0f];
    }
    return [UIColor colorWithRed:245.0f / 255.0f green:74.0f / 255.0f blue:69.0f alpha:1.0f];
}

static UIColor *WKDocumentShareCardDefaultIconColor(void) {
    BOOL dark = [WKApp shared].config.style == WKSystemStyleDark;
    return [UIColor colorWithWhite:(dark ? 1.0f : 0.0f) alpha:(dark ? 0.80f : 0.60f)];
}

static UIColor *WKDocumentShareCardStatusBackground(UIColor *color) {
    CGFloat alpha = [WKApp shared].config.style == WKSystemStyleDark ? 0.10f : 0.08f;
    return [color colorWithAlphaComponent:alpha];
}

static UIColor *WKDocumentShareCardBorderColor(CGFloat lightAlpha, CGFloat darkAlpha) {
    BOOL dark = [WKApp shared].config.style == WKSystemStyleDark;
    return [(dark ? UIColor.whiteColor : UIColor.blackColor) colorWithAlphaComponent:(dark ? darkAlpha : lightAlpha)];
}

/// Draw the card icons at 24 points.
static UIImage *WKDocumentShareCardIcon(NSString *name) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(24.0f, 24.0f), NO, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, UIColor.blackColor.CGColor);
    CGContextSetLineWidth(context, 1.8f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    UIBezierPath *path = [UIBezierPath bezierPath];
    if ([name isEqualToString:@"doc"]) {
        [path moveToPoint:CGPointMake(6, 3)]; [path addLineToPoint:CGPointMake(14, 3)];
        [path addLineToPoint:CGPointMake(18, 7)]; [path addLineToPoint:CGPointMake(18, 21)];
        [path addLineToPoint:CGPointMake(6, 21)]; [path closePath];
        [path moveToPoint:CGPointMake(9, 8)]; [path addLineToPoint:CGPointMake(12, 8)];
        [path moveToPoint:CGPointMake(9, 12)]; [path addLineToPoint:CGPointMake(15, 12)];
        [path moveToPoint:CGPointMake(9, 16)]; [path addLineToPoint:CGPointMake(15, 16)];
    } else if ([name isEqualToString:@"board"]) {
        [path appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 4, 18, 14) cornerRadius:2]];
        [path moveToPoint:CGPointMake(7, 9)]; [path addLineToPoint:CGPointMake(11, 9)];
        [path moveToPoint:CGPointMake(7, 13)]; [path addLineToPoint:CGPointMake(14, 13)];
    } else if ([name isEqualToString:@"sheet"]) {
        [path appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 4, 16, 16) cornerRadius:2]];
        [path moveToPoint:CGPointMake(4, 10)]; [path addLineToPoint:CGPointMake(20, 10)];
        [path moveToPoint:CGPointMake(4, 15)]; [path addLineToPoint:CGPointMake(20, 15)];
        [path moveToPoint:CGPointMake(10, 4)]; [path addLineToPoint:CGPointMake(10, 20)];
    } else if ([name isEqualToString:@"html"]) {
        [path appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 4, 18, 16) cornerRadius:2]];
        [path moveToPoint:CGPointMake(9, 10)]; [path addLineToPoint:CGPointMake(6.5f, 12)]; [path addLineToPoint:CGPointMake(9, 14)];
        [path moveToPoint:CGPointMake(15, 10)]; [path addLineToPoint:CGPointMake(17.5f, 12)]; [path addLineToPoint:CGPointMake(15, 14)];
        [path moveToPoint:CGPointMake(13, 9)]; [path addLineToPoint:CGPointMake(11, 15)];
    } else if ([name isEqualToString:@"copy"]) {
        [path appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(9, 9, 11, 11) cornerRadius:2]];
        [path moveToPoint:CGPointMake(5, 15)]; [path addLineToPoint:CGPointMake(5, 5)];
        [path addCurveToPoint:CGPointMake(7, 3) controlPoint1:CGPointMake(5, 3) controlPoint2:CGPointMake(5, 3)];
        [path addLineToPoint:CGPointMake(15, 3)];
    } else if ([name isEqualToString:@"lock"]) {
        [path appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(5, 11, 14, 9) cornerRadius:2]];
        [path moveToPoint:CGPointMake(8, 11)]; [path addLineToPoint:CGPointMake(8, 8)];
        [path addCurveToPoint:CGPointMake(16, 8) controlPoint1:CGPointMake(8, 3) controlPoint2:CGPointMake(16, 3)];
        [path addLineToPoint:CGPointMake(16, 11)];
    } else if ([name isEqualToString:@"warning"]) {
        [path moveToPoint:CGPointMake(12, 3)]; [path addLineToPoint:CGPointMake(2, 20)];
        [path addLineToPoint:CGPointMake(22, 20)]; [path closePath];
        [path moveToPoint:CGPointMake(12, 10)]; [path addLineToPoint:CGPointMake(12, 14)];
        [path moveToPoint:CGPointMake(12, 17)]; [path addLineToPoint:CGPointMake(12.01f, 17)];
    } else {
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(3, 3, 18, 18)]];
        [path moveToPoint:CGPointMake(12, 11)]; [path addLineToPoint:CGPointMake(12, 16)];
        [path moveToPoint:CGPointMake(12, 8)]; [path addLineToPoint:CGPointMake(12.01f, 8)];
    }
    [path stroke];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@interface WKDocumentShareCardCell ()
@property(nonatomic,strong) UIView *cardView;
@property(nonatomic,strong) UIImageView *kindIconView;
@property(nonatomic,strong) UILabel *titleLabel;
@property(nonatomic,strong) UILabel *subtitleLabel;
@property(nonatomic,strong) UILabel *permissionLabel;
@property(nonatomic,strong) UIButton *linkCopyButton;
@property(nonatomic,strong) UIView *previewView;
@property(nonatomic,strong) UIView *previewContentView;
@property(nonatomic,strong) UIImageView *placeholderIconView;
@property(nonatomic,strong) UILabel *placeholderTitleLabel;
@property(nonatomic,strong) UILabel *placeholderDetailLabel;
@property(nonatomic,strong) NSDictionary *preview;
@property(nonatomic,copy) NSString *previewStatus;
@property(nonatomic,copy) NSString *renderedDocId;
@property(nonatomic,copy) NSString *renderedSpaceId;
@property(nonatomic,copy) NSString *renderedUID;
@property(nonatomic,copy) NSString *renderedPreviewKind;
@property(nonatomic,copy) NSString *renderedPreviewTitle;
@property(nonatomic,copy) NSString *renderedPreviewStatus;
@property(nonatomic,copy) NSDictionary *renderedPreviewData;
@property(nonatomic,copy) NSString *renderedPreviewLanguage;
@property(nonatomic,assign) WKSystemStyle renderedPreviewStyle;
@property(nonatomic,assign) NSUInteger requestGeneration;
@property(nonatomic,assign) BOOL previewNeedsRefresh;
@property(nonatomic,strong) WKDocumentPreviewSubscription *previewSubscription;
@property(nonatomic,assign) NSTimeInterval previewFetchedAt;
@property(nonatomic,assign) NSTimeInterval lastForcedRefreshAt;
@end

@implementation WKDocumentShareCardCell

+ (BOOL)hiddenBubble {
    return YES;
}

+ (CGFloat)cardWidthForModel:(WKMessageModel *)model {
    CGFloat configured = [WKApp shared].config.messageContentMaxWidth;
    if (configured <= 0) configured = WKScreenWidth * 0.72f;
    return floor(MIN(WKDocumentShareCardMaxWidth, configured));
}

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    CGFloat width = [self cardWidthForModel:model];
    WKDocumentShareCardContent *content = [model.content isKindOfClass:WKDocumentShareCardContent.class]
        ? (WKDocumentShareCardContent *)model.content : nil;
    // Reserve a taller header when the creator subtitle is present.
    CGFloat headerHeight = content.ownerName.length > 0 ? 42.0f : 32.0f;
    CGFloat cardHeight = WKDocumentShareCardOuterPadding * 2.0f + headerHeight + 12.0f + WKDocumentShareCardPreviewHeight;
    return CGSizeMake(width, cardHeight);
}

- (BOOL)respondContentSingleTap {
    return YES;
}

// WKMessageCell routes taps within messageContentView here. Only the preview
// area opens the document; the header's copy button handles its own tap.
- (void)onTapWithGestureRecognizer:(TapLongTapOrDoubleTapGestureRecognizerWrap *)gesture {
    if ([self.previewStatus isEqualToString:@"unavailable"]) return;
    CGPoint point = [self.cardView convertPoint:gesture.tapPoint fromView:self.contentView];
    if (!CGRectContainsPoint(self.previewView.frame, point)) return;
    [self openDocument];
}

- (void)initUI {
    [super initUI];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(documentPreviewSessionDidChange:)
                                                 name:WKDocumentPreviewSessionDidChangeNotification
                                               object:[WKDocumentPreviewLoader shared]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(documentPreviewAppDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    // UIImageView 默认不接收触摸，允许卡片内的复制按钮获得原生点击事件。
    self.bubbleBackgroundView.userInteractionEnabled = YES;

    self.cardView = [UIView new];
    self.cardView.layer.cornerRadius = 8.0f;
    self.cardView.layer.borderWidth = 1.0f;
    self.cardView.layer.masksToBounds = YES;
    [self.messageContentView addSubview:self.cardView];

    self.kindIconView = [UIImageView new];
    self.kindIconView.contentMode = UIViewContentModeCenter;
    self.kindIconView.layer.cornerRadius = 5.0f;
    self.kindIconView.clipsToBounds = YES;
    [self.cardView addSubview:self.kindIconView];

    self.titleLabel = [UILabel new];
    self.titleLabel.font = [[WKApp shared].config appFontOfSizeSemibold:14.0f];
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.cardView addSubview:self.titleLabel];

    self.subtitleLabel = [UILabel new];
    self.subtitleLabel.font = [UIFont systemFontOfSize:12.0f];
    self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.cardView addSubview:self.subtitleLabel];

    self.permissionLabel = [UILabel new];
    self.permissionLabel.font = [UIFont systemFontOfSize:11.0f weight:UIFontWeightMedium];
    self.permissionLabel.textAlignment = NSTextAlignmentCenter;
    self.permissionLabel.layer.cornerRadius = 10.0f;
    self.permissionLabel.layer.masksToBounds = YES;
    [self.cardView addSubview:self.permissionLabel];

    self.linkCopyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.linkCopyButton setImage:WKDocumentShareCardIcon(@"copy") forState:UIControlStateNormal];
    [self.linkCopyButton addTarget:self action:@selector(copyDocumentLink) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.linkCopyButton];

    self.previewView = [UIView new];
    self.previewView.userInteractionEnabled = YES;
    self.previewView.layer.cornerRadius = 5.0f;
    self.previewView.layer.borderWidth = 1.0f;
    self.previewView.clipsToBounds = YES;
    [self.cardView addSubview:self.previewView];

    self.previewContentView = [UIView new];
    self.previewContentView.userInteractionEnabled = NO;
    [self.previewView addSubview:self.previewContentView];

    self.placeholderIconView = [UIImageView new];
    self.placeholderIconView.contentMode = UIViewContentModeCenter;
    self.placeholderIconView.layer.cornerRadius = 20.0f;
    self.placeholderIconView.layer.masksToBounds = YES;
    [self.previewView addSubview:self.placeholderIconView];

    self.placeholderTitleLabel = [UILabel new];
    self.placeholderTitleLabel.font = [[WKApp shared].config appFontOfSizeSemibold:14.0f];
    self.placeholderTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.placeholderTitleLabel.numberOfLines = 1;
    [self.previewView addSubview:self.placeholderTitleLabel];

    self.placeholderDetailLabel = [UILabel new];
    self.placeholderDetailLabel.font = [UIFont systemFontOfSize:12.0f];
    self.placeholderDetailLabel.textAlignment = NSTextAlignmentCenter;
    self.placeholderDetailLabel.numberOfLines = 2;
    [self.previewView addSubview:self.placeholderDetailLabel];

}

- (void)dealloc {
    [self.previewSubscription cancel];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)documentPreviewAppDidBecomeActive:(NSNotification *)notification {
    [self forceRefreshPreview];
}

- (void)forceRefreshPreview {
    if (!self.window) return;
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (now - self.lastForcedRefreshAt < 1.0) return;
    self.lastForcedRefreshAt = now;
    WKDocumentShareCardContent *content = [self.messageModel.content isKindOfClass:WKDocumentShareCardContent.class]
        ? (WKDocumentShareCardContent *)self.messageModel.content : nil;
    if (!content) return;
    if (![WKApp shared].isLogined) {
        [self.previewSubscription cancel];
        self.previewSubscription = nil;
        self.requestGeneration++;
        self.preview = nil;
        self.previewStatus = @"unauthenticated";
        [self updateCardForContent:content];
        return;
    }
    self.preview = nil;
    self.previewStatus = @"loading";
    [self updateCardForContent:content];
    [self fetchPreviewForContent:content force:YES];
}

- (void)documentPreviewSessionDidChange:(NSNotification *)notification {
    [self.previewSubscription cancel];
    self.previewSubscription = nil;
    self.requestGeneration++;
    self.preview = nil;
    self.previewFetchedAt = 0;
    self.renderedUID = nil;
    WKDocumentShareCardContent *content = [self.messageModel.content isKindOfClass:WKDocumentShareCardContent.class]
        ? (WKDocumentShareCardContent *)self.messageModel.content : nil;
    if (!content) return;
    self.renderedDocId = content.docId ?: @"";
    self.renderedSpaceId = content.spaceId ?: @"";
    if (![WKApp shared].isLogined) {
        self.previewStatus = @"unauthenticated";
        if (self.window) [self updateCardForContent:content];
        return;
    }
    self.previewStatus = @"loading";
    if (self.window) {
        self.renderedUID = [WKApp shared].loginInfo.uid ?: @"";
        [self fetchPreviewForContent:content];
        [self updateCardForContent:content];
    }
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    if (![model.content isKindOfClass:WKDocumentShareCardContent.class]) return;

    WKDocumentShareCardContent *content = (WKDocumentShareCardContent *)model.content;
    NSString *spaceId = content.spaceId ?: @"";
    if (self.previewNeedsRefresh
        && [content.docId isEqualToString:self.renderedDocId]
        && [spaceId isEqualToString:self.renderedSpaceId]) {
        self.previewNeedsRefresh = NO;
    }
    NSString *uid = [WKApp shared].loginInfo.uid ?: @"";
    BOOL identityChanged = ![self.renderedDocId isEqualToString:content.docId]
        || ![self.renderedSpaceId isEqualToString:spaceId]
        || ![self.renderedUID isEqualToString:uid];
    if (identityChanged) {
        self.renderedDocId = content.docId ?: @"";
        self.renderedSpaceId = spaceId;
        self.renderedUID = uid;
        self.preview = nil;
        self.previewFetchedAt = 0;
        self.previewStatus = @"loading";
        [self fetchPreviewForContent:content];
    } else if (!self.previewStatus) {
        self.previewStatus = @"loading";
        [self fetchPreviewForContent:content];
    }

    [self updateCardForContent:content];
}

- (void)updateCardForContent:(WKDocumentShareCardContent *)content {
    NSString *title = content.title.length > 0 ? content.title : LLang(@"未命名文档");
    self.titleLabel.text = title;
    self.subtitleLabel.text = content.ownerName.length > 0
        ? [NSString stringWithFormat:LLang(@"%@ 创建"), content.ownerName]
        : @"";

    NSString *kind = content.kind ?: @"doc";
    NSString *symbol = kind;

    UIColor *accent = [WKApp shared].config.themeColor ?: [UIColor systemBlueColor];
    self.kindIconView.image = WKDocumentShareCardIcon(symbol);
    self.kindIconView.tintColor = accent;

    [self updatePermissionForStatus:self.previewStatus];

    UIColor *primary = [WKApp shared].config.messageRecvTextColor ?: UIColor.labelColor;
    UIColor *secondary = [WKApp shared].config.tipColor ?: UIColor.secondaryLabelColor;
    UIColor *surface = [WKApp shared].config.cellBackgroundColor ?: UIColor.secondarySystemBackgroundColor;
    self.cardView.backgroundColor = WKDocumentShareCardBackgroundColor();
    self.cardView.layer.borderColor = WKDocumentShareCardBorderColor(0.05f, 0.04f).CGColor;
    self.titleLabel.textColor = primary;
    self.subtitleLabel.textColor = secondary;
    self.kindIconView.backgroundColor = surface;
    self.previewView.backgroundColor = surface;
    self.previewView.layer.borderColor = WKDocumentShareCardBorderColor(0.08f, 0.07f).CGColor;
    self.placeholderTitleLabel.textColor = primary;
    self.placeholderDetailLabel.textColor = secondary;
    self.linkCopyButton.tintColor = secondary;
    [self updatePreviewContentForKind:kind title:title];
}

- (void)updatePermissionForStatus:(NSString *)status {
    if ([status isEqualToString:@"ready"] || [status isEqualToString:@"empty"]) {
        // The preview endpoint proves reader access, but does not return the current role.
        self.permissionLabel.text = LLang(@"可查看");
        self.permissionLabel.textColor = [UIColor secondaryLabelColor];
        self.permissionLabel.backgroundColor = [UIColor secondarySystemBackgroundColor];
    } else if ([status isEqualToString:@"unauthenticated"]) {
        self.permissionLabel.text = LLang(@"需登录");
        self.permissionLabel.textColor = WKDocumentShareCardWarningColor();
        self.permissionLabel.backgroundColor = WKDocumentShareCardStatusBackground(WKDocumentShareCardWarningColor());
    } else if ([status isEqualToString:@"denied"]) {
        self.permissionLabel.text = LLang(@"需申请");
        self.permissionLabel.textColor = WKDocumentShareCardWarningColor();
        self.permissionLabel.backgroundColor = WKDocumentShareCardStatusBackground(WKDocumentShareCardWarningColor());
    } else if ([status isEqualToString:@"unavailable"]) {
        self.permissionLabel.text = LLang(@"不可用");
        self.permissionLabel.textColor = WKDocumentShareCardErrorColor();
        self.permissionLabel.backgroundColor = WKDocumentShareCardStatusBackground(WKDocumentShareCardErrorColor());
    } else if ([status isEqualToString:@"error"]) {
        self.permissionLabel.text = LLang(@"预览不可用");
        self.permissionLabel.textColor = WKDocumentShareCardErrorColor();
        self.permissionLabel.backgroundColor = WKDocumentShareCardStatusBackground(WKDocumentShareCardErrorColor());
    } else {
        self.permissionLabel.text = LLang(@"检查中");
        self.permissionLabel.textColor = [UIColor secondaryLabelColor];
        self.permissionLabel.backgroundColor = WKDocumentShareCardTint(0.06f);
    }
}

- (void)fetchPreviewForContent:(WKDocumentShareCardContent *)content {
    [self fetchPreviewForContent:content force:NO];
}

- (void)fetchPreviewForContent:(WKDocumentShareCardContent *)content force:(BOOL)force {
    [self.previewSubscription cancel];
    self.previewSubscription = nil;
    NSUInteger generation = ++self.requestGeneration;
    NSString *docId = [content.docId copy] ?: @"";
    NSString *spaceId = [content.spaceId copy] ?: @"";
    NSString *uid = [WKApp shared].loginInfo.uid ?: @"";
    NSString *token = [WKApp shared].loginInfo.token ?: @"";
    NSString *apiBaseURL = [WKApp shared].config.apiBaseUrl ?: @"";
    __weak typeof(self) weakSelf = self;
    self.previewSubscription = [[WKDocumentPreviewLoader shared] fetchPreviewForKind:content.kind docId:docId spaceId:spaceId force:force callback:^(NSDictionary *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || generation != self.requestGeneration
                || ![self.renderedDocId isEqualToString:docId]
                || ![self.renderedSpaceId isEqualToString:spaceId]
                || ![([WKApp shared].loginInfo.uid ?: @"") isEqualToString:uid]
                || ![([WKApp shared].loginInfo.token ?: @"") isEqualToString:token]
                || ![([WKApp shared].config.apiBaseUrl ?: @"") isEqualToString:apiBaseURL]) return;
            self.previewSubscription = nil;
            self.previewFetchedAt = NSDate.date.timeIntervalSince1970;
            self.previewStatus = [result[@"status"] isKindOfClass:NSString.class] ? result[@"status"] : @"error";
            self.preview = [result[@"preview"] isKindOfClass:NSDictionary.class] ? result[@"preview"] : nil;
            WKDocumentShareCardContent *current = [self.messageModel.content isKindOfClass:WKDocumentShareCardContent.class] ? (WKDocumentShareCardContent *)self.messageModel.content : nil;
            if (!current || ![current.docId isEqualToString:docId] || ![(current.spaceId ?: @"") isEqualToString:spaceId]) {
                self.previewNeedsRefresh = YES;
                return;
            }
            self.previewNeedsRefresh = NO;
            [self updateCardForContent:current];
            [self setNeedsLayout];
            [self layoutIfNeeded];
            UIView *listView = self;
            while (listView && ![NSStringFromClass(listView.class) isEqualToString:@"WKMessageListView"]) listView = listView.superview;
            if ([listView respondsToSelector:@selector(wk_invalidateHeightCacheForMessage:)]) {
                [listView performSelector:@selector(wk_invalidateHeightCacheForMessage:) withObject:self.messageModel];
            }
        });
    }];
}

- (void)updatePreviewContentForKind:(NSString *)kind title:(NSString *)title {
    NSString *status = self.previewStatus ?: @"loading";
    NSString *language = [WKApp shared].config.langue ?: @"zh-Hans";
    WKSystemStyle style = [WKApp shared].config.style;
    BOOL renderChanged = ![self.renderedPreviewKind isEqualToString:kind ?: @""]
        || ![self.renderedPreviewTitle isEqualToString:title ?: @""]
        || ![self.renderedPreviewStatus isEqualToString:status]
        || ![self.renderedPreviewData isEqualToDictionary:self.preview ?: @{}]
        || ![self.renderedPreviewLanguage isEqualToString:language]
        || self.renderedPreviewStyle != style;
    if (!renderChanged) return;
    for (UIView *view in self.previewContentView.subviews) [view removeFromSuperview];
    BOOL hasPreview = self.previewStatus && [self.previewStatus isEqualToString:@"ready"] && self.preview;
    self.previewContentView.hidden = !hasPreview;
    self.placeholderIconView.hidden = hasPreview;
    self.placeholderTitleLabel.hidden = hasPreview;
    self.placeholderDetailLabel.hidden = hasPreview;
    self.previewView.userInteractionEnabled = ![self.previewStatus isEqualToString:@"unavailable"];

    self.renderedPreviewKind = [kind copy] ?: @"";
    self.renderedPreviewTitle = [title copy] ?: @"";
    self.renderedPreviewStatus = status;
    self.renderedPreviewData = [self.preview copy] ?: @{};
    self.renderedPreviewLanguage = language;
    self.renderedPreviewStyle = style;

    if (hasPreview) {
        NSString *type = self.preview[@"type"];
        if ([type isEqualToString:@"sheet"]) {
            [self buildSheetPreviewWithTitle:title];
        } else if ([type isEqualToString:@"board"]) {
            [self buildBoardPreview];
        } else {
            [self buildDocumentPreviewWithTitle:title];
        }
        return;
    }

    NSString *placeholderSymbol = @"info";
    if ([status isEqualToString:@"unauthenticated"]) {
        placeholderSymbol = @"lock";
        self.placeholderTitleLabel.text = LLang(@"需要登录");
        self.placeholderDetailLabel.text = LLang(@"登录后可以查看文档");
    } else if ([status isEqualToString:@"denied"]) {
        placeholderSymbol = @"lock";
        self.placeholderTitleLabel.text = LLang(@"需要访问权限");
        self.placeholderDetailLabel.text = LLang(@"打开文档后可以申请访问");
    } else if ([status isEqualToString:@"unavailable"]) {
        placeholderSymbol = @"warning";
        self.placeholderTitleLabel.text = LLang(@"文档不可用");
        self.placeholderDetailLabel.text = LLang(@"该文档可能已被删除或归档");
    } else if ([status isEqualToString:@"error"]) {
        placeholderSymbol = @"warning";
        self.placeholderTitleLabel.text = LLang(@"预览暂时不可用");
        self.placeholderDetailLabel.text = LLang(@"你仍可打开文档，或稍后重试");
    } else if ([status isEqualToString:@"empty"]) {
        self.placeholderTitleLabel.text = LLang(@"暂无预览");
        self.placeholderDetailLabel.text = @"";
    } else {
        self.placeholderTitleLabel.text = LLang(@"正在确认访问权限…");
        self.placeholderDetailLabel.text = @"";
    }
    self.placeholderIconView.image = WKDocumentShareCardIcon(placeholderSymbol);
    BOOL isErrorPlaceholder = [status isEqualToString:@"error"] || [status isEqualToString:@"unavailable"];
    self.placeholderIconView.tintColor = isErrorPlaceholder ? WKDocumentShareCardErrorColor() : WKDocumentShareCardDefaultIconColor();
    self.placeholderIconView.backgroundColor = isErrorPlaceholder
        ? WKDocumentShareCardStatusBackground(WKDocumentShareCardErrorColor())
        : ([WKApp shared].config.cellBackgroundColor ?: UIColor.secondarySystemBackgroundColor);
    UIColor *placeholderTint = WKDocumentShareCardTint(0.03f);
    self.previewView.backgroundColor = hasPreview
        ? ([WKApp shared].config.cellBackgroundColor ?: UIColor.secondarySystemBackgroundColor)
        : placeholderTint;

}

- (void)buildDocumentPreviewWithTitle:(NSString *)title {
    UIColor *primary = [WKApp shared].config.messageRecvTextColor ?: UIColor.labelColor;
    UIColor *secondary = [WKApp shared].config.tipColor ?: UIColor.secondaryLabelColor;
    UIColor *line = WKDocumentShareCardTint(0.06f);
    UILabel *label = [self previewLabel:title font:12.0f color:secondary weight:UIFontWeightRegular];
    label.tag = 1001;
    label.frame = CGRectMake(24, 24, self.previewView.bounds.size.width - 48, 14);
    [self.previewContentView addSubview:label];
    NSString *heading = [self.preview[@"heading"] isKindOfClass:NSString.class] ? self.preview[@"heading"] : @"";
    CGFloat y = 38.0f;
    if (heading.length > 0) {
        y += 20.0f;
        UILabel *headingLabel = [self previewLabel:heading font:14.0f color:primary weight:UIFontWeightSemibold];
        headingLabel.tag = 1002;
        headingLabel.frame = CGRectMake(24, y, self.previewView.bounds.size.width - 48, 20);
        [self.previewContentView addSubview:headingLabel];
        y += 20.0f;
    }
    NSArray *paragraphs = [self.preview[@"paragraphs"] isKindOfClass:NSArray.class] ? self.preview[@"paragraphs"] : @[];
    for (NSUInteger i = 0; i < MIN(paragraphs.count, 3); i++) {
        y += 8.0f;
        UILabel *paragraph = [self previewLabel:paragraphs[i] font:12.0f color:secondary weight:UIFontWeightRegular];
        paragraph.tag = 1100 + (NSInteger)i;
        paragraph.numberOfLines = 2;
        paragraph.frame = CGRectMake(24, y, self.previewView.bounds.size.width - 48, 36);
        [self.previewContentView addSubview:paragraph];
        y += 36.0f;
    }
    y += 16.0f;
    for (NSUInteger i = 0; i < 3; i++) {
        UIView *bar = [UIView new];
        bar.tag = 1200 + (NSInteger)i;
        bar.backgroundColor = line;
        bar.layer.cornerRadius = 2.0f;
        CGFloat width = self.previewView.bounds.size.width - 48.0f;
        if (i == 1) width *= 0.84f;
        if (i == 2) width *= 0.64f;
        bar.frame = CGRectMake(24, y + i * 12.0f, width, 4.0f);
        [self.previewContentView addSubview:bar];
    }
}

- (void)buildBoardPreview {
    NSArray *nodes = [self.preview[@"nodes"] isKindOfClass:NSArray.class] ? self.preview[@"nodes"] : @[];
    CGFloat width = self.previewView.bounds.size.width;
    CGFloat nodeWidth = MIN(112.0f, (width - 64.0f) / 2.0f);
    CGFloat left = (width - nodeWidth * 2.0f - 64.0f) / 2.0f;
    CGFloat top = (WKDocumentShareCardPreviewHeight - 136.0f) / 2.0f;
    self.previewView.backgroundColor = WKDocumentShareCardTint(0.03f);
    UIView *horizontalConnector = [UIView new];
    horizontalConnector.tag = 2001;
    horizontalConnector.backgroundColor = WKDocumentShareCardBorderColor(0.14f, 0.12f);
    horizontalConnector.frame = CGRectMake((width - 176.0f) / 2.0f, WKDocumentShareCardPreviewHeight / 2.0f - 0.5f, 176.0f, 1.0f);
    [self.previewContentView addSubview:horizontalConnector];
    UIView *verticalConnector = [UIView new];
    verticalConnector.tag = 2002;
    verticalConnector.backgroundColor = WKDocumentShareCardBorderColor(0.14f, 0.12f);
    verticalConnector.frame = CGRectMake(width / 2.0f - 0.5f, WKDocumentShareCardPreviewHeight / 2.0f - 44.0f, 1.0f, 88.0f);
    [self.previewContentView addSubview:verticalConnector];
    for (NSUInteger i = 0; i < MIN(nodes.count, 4); i++) {
        NSInteger col = (NSInteger)(i % 2);
        NSInteger row = (NSInteger)(i / 2);
        UILabel *node = [self previewLabel:nodes[i] font:12.0f color:[WKApp shared].config.messageRecvTextColor weight:UIFontWeightMedium];
        node.tag = 2100 + (NSInteger)i;
        node.textAlignment = NSTextAlignmentCenter;
        node.layer.borderWidth = 1.0f;
        node.layer.borderColor = WKDocumentShareCardBorderColor(0.08f, 0.07f).CGColor;
        node.layer.cornerRadius = 5.0f;
        node.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        node.frame = CGRectMake(left + col * (nodeWidth + 64.0f), top + row * 88.0f, nodeWidth, 48.0f);
        [self.previewContentView addSubview:node];
    }
}

- (void)buildSheetPreviewWithTitle:(NSString *)title {
    UILabel *titleLabel = [self previewLabel:title font:12.0f color:[WKApp shared].config.messageRecvTextColor weight:UIFontWeightSemibold];
    titleLabel.tag = 4000;
    titleLabel.frame = CGRectMake(16, 16, self.previewView.bounds.size.width - 32, 18);
    [self.previewContentView addSubview:titleLabel];
    NSArray *headers = [self.preview[@"headers"] isKindOfClass:NSArray.class] ? self.preview[@"headers"] : @[];
    NSArray *rows = [self.preview[@"rows"] isKindOfClass:NSArray.class] ? self.preview[@"rows"] : @[];
    NSMutableArray *allRows = [NSMutableArray array];
    if (headers.count > 0) [allRows addObject:headers];
    [allRows addObjectsFromArray:[rows subarrayWithRange:NSMakeRange(0, MIN(rows.count, 3))]];
    CGFloat tableX = 16.0f, tableY = 46.0f;
    CGFloat tableWidth = self.previewView.bounds.size.width - 32.0f;
    CGFloat unitWidth = tableWidth / 3.2f;
    CGFloat rowHeight = 30.0f;
    for (NSUInteger r = 0; r < allRows.count; r++) {
        NSArray *row = allRows[r];
        for (NSUInteger c = 0; c < 3; c++) {
            NSString *value = c < row.count && [row[c] isKindOfClass:NSString.class] ? row[c] : @"";
            UIView *cellContainer = [UIView new];
            cellContainer.tag = 3000 + (NSInteger)(r * 3 + c);
            cellContainer.layer.borderWidth = 0.5f;
            cellContainer.layer.borderColor = WKDocumentShareCardBorderColor(0.05f, 0.04f).CGColor;
            cellContainer.backgroundColor = r == 0 ? WKDocumentShareCardTint(0.06f) : [WKApp shared].config.cellBackgroundColor;
            UILabel *cell = [self previewLabel:value font:12.0f color:r == 0 ? [WKApp shared].config.messageRecvTextColor : [WKApp shared].config.tipColor weight:r == 0 ? UIFontWeightMedium : UIFontWeightRegular];
            cell.textAlignment = NSTextAlignmentLeft;
            CGFloat cellX = tableX + (c == 0 ? 0.0f : unitWidth * (1.2f + (c - 1)));
            CGFloat cellWidth = unitWidth * (c == 0 ? 1.2f : 1.0f);
            cellContainer.frame = CGRectMake(cellX, tableY + r * rowHeight, cellWidth, rowHeight);
            cell.frame = CGRectMake(8.0f, 0, MAX(0, cellWidth - 16.0f), rowHeight);
            [cellContainer addSubview:cell];
            [self.previewContentView addSubview:cellContainer];
        }
    }
}

- (UILabel *)previewLabel:(NSString *)text font:(CGFloat)size color:(UIColor *)color weight:(UIFontWeight)weight {
    UILabel *label = [UILabel new];
    label.text = [text isKindOfClass:NSString.class] ? text : @"";
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.textColor = color ?: UIColor.labelColor;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

- (void)layoutPreviewContent {
    if (![self.previewStatus isEqualToString:@"ready"] || !self.preview) return;
    CGFloat width = self.previewView.bounds.size.width;
    NSString *type = self.preview[@"type"];
    if ([type isEqualToString:@"board"]) {
        NSArray *nodes = [self.preview[@"nodes"] isKindOfClass:NSArray.class] ? self.preview[@"nodes"] : @[];
        CGFloat nodeWidth = MIN(112.0f, (width - 64.0f) / 2.0f);
        CGFloat left = (width - nodeWidth * 2.0f - 64.0f) / 2.0f;
        CGFloat top = (WKDocumentShareCardPreviewHeight - 136.0f) / 2.0f;
        [[self.previewContentView viewWithTag:2001] setFrame:CGRectMake((width - 176.0f) / 2.0f, WKDocumentShareCardPreviewHeight / 2.0f - 0.5f, 176.0f, 1.0f)];
        [[self.previewContentView viewWithTag:2002] setFrame:CGRectMake(width / 2.0f - 0.5f, WKDocumentShareCardPreviewHeight / 2.0f - 44.0f, 1.0f, 88.0f)];
        for (NSUInteger i = 0; i < MIN(nodes.count, 4); i++) {
            NSInteger col = (NSInteger)(i % 2);
            NSInteger row = (NSInteger)(i / 2);
            [[self.previewContentView viewWithTag:2100 + (NSInteger)i] setFrame:CGRectMake(left + col * (nodeWidth + 64.0f), top + row * 88.0f, nodeWidth, 48.0f)];
        }
        return;
    }
    if ([type isEqualToString:@"sheet"]) {
        NSArray *headers = [self.preview[@"headers"] isKindOfClass:NSArray.class] ? self.preview[@"headers"] : @[];
        NSArray *rows = [self.preview[@"rows"] isKindOfClass:NSArray.class] ? self.preview[@"rows"] : @[];
        NSUInteger displayedRows = MIN(rows.count, 3) + (headers.count > 0 ? 1 : 0);
        CGFloat tableWidth = width - 32.0f;
        CGFloat unitWidth = tableWidth / 3.2f;
        [[self.previewContentView viewWithTag:4000] setFrame:CGRectMake(16.0f, 16.0f, width - 32.0f, 18.0f)];
        for (NSUInteger r = 0; r < displayedRows; r++) {
            for (NSUInteger c = 0; c < 3; c++) {
                CGFloat cellX = 16.0f + (c == 0 ? 0.0f : unitWidth * (1.2f + (c - 1)));
                CGFloat cellWidth = unitWidth * (c == 0 ? 1.2f : 1.0f);
                UIView *container = [self.previewContentView viewWithTag:3000 + (NSInteger)(r * 3 + c)];
                container.frame = CGRectMake(cellX, 46.0f + r * 30.0f, cellWidth, 30.0f);
                container.subviews.firstObject.frame = CGRectMake(8.0f, 0, MAX(0, cellWidth - 16.0f), 30.0f);
            }
        }
        return;
    }

    UILabel *titleLabel = (UILabel *)[self.previewContentView viewWithTag:1001];
    titleLabel.frame = CGRectMake(24, 24, width - 48, 14);
    NSString *heading = [self.preview[@"heading"] isKindOfClass:NSString.class] ? self.preview[@"heading"] : @"";
    CGFloat y = 38.0f;
    if (heading.length > 0) {
        y += 20.0f;
        [[self.previewContentView viewWithTag:1002] setFrame:CGRectMake(24, y, width - 48, 20)];
        y += 20.0f;
    }
    NSArray *paragraphs = [self.preview[@"paragraphs"] isKindOfClass:NSArray.class] ? self.preview[@"paragraphs"] : @[];
    for (NSUInteger i = 0; i < MIN(paragraphs.count, 3); i++) {
        y += 8.0f;
        [[self.previewContentView viewWithTag:1100 + (NSInteger)i] setFrame:CGRectMake(24, y, width - 48, 36)];
        y += 36.0f;
    }
    y += 16.0f;
    for (NSUInteger i = 0; i < 3; i++) {
        CGFloat barWidth = width - 48.0f;
        if (i == 1) barWidth *= 0.84f;
        if (i == 2) barWidth *= 0.64f;
        [[self.previewContentView viewWithTag:1200 + (NSInteger)i] setFrame:CGRectMake(24, y + i * 12.0f, barWidth, 4.0f)];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.cardView.frame = self.messageContentView.bounds;
    CGFloat width = self.cardView.bounds.size.width;
    CGFloat inset = WKDocumentShareCardOuterPadding;
    CGFloat icon = 32.0f;
    WKDocumentShareCardContent *content = [self.messageModel.content isKindOfClass:WKDocumentShareCardContent.class]
        ? (WKDocumentShareCardContent *)self.messageModel.content : nil;
    BOOL hasOwner = content.ownerName.length > 0;
    CGFloat headerHeight = hasOwner ? 42.0f : 32.0f;
    CGFloat headerCenterY = inset + headerHeight / 2.0f;
    CGFloat copyWidth = 28.0f;
    CGFloat permissionWidth = [self.permissionLabel sizeThatFits:CGSizeMake(110, 20)].width + 16.0f;
    permissionWidth = MIN(90.0f, MAX(54.0f, permissionWidth));
    self.kindIconView.frame = CGRectMake(inset, headerCenterY - icon / 2.0f, icon, icon);
    self.linkCopyButton.frame = CGRectMake(width - inset - copyWidth, headerCenterY - 14.0f, copyWidth, 28.0f);
    self.permissionLabel.frame = CGRectMake(CGRectGetMinX(self.linkCopyButton.frame) - permissionWidth - 6.0f, headerCenterY - 10.0f, permissionWidth, 20.0f);
    CGFloat titleX = CGRectGetMaxX(self.kindIconView.frame) + 8.0f;
    CGFloat titleRight = CGRectGetMinX(self.permissionLabel.frame) - 8.0f;
    CGFloat titleWidth = MAX(20.0f, titleRight - titleX);
    if (hasOwner) {
        // Center the title and subtitle together alongside the kind icon.
        self.titleLabel.frame = CGRectMake(titleX, inset, titleWidth, 20.0f);
        self.subtitleLabel.frame = CGRectMake(titleX, inset + 24.0f, titleWidth, 18.0f);
    } else {
        // Center the title vertically when there is no subtitle.
        self.titleLabel.frame = CGRectMake(titleX, inset + (icon - 20.0f) / 2.0f, titleWidth, 20.0f);
        self.subtitleLabel.frame = CGRectZero;
    }
    self.previewView.frame = CGRectMake(inset, inset + headerHeight + 12.0f, width - inset * 2.0f, WKDocumentShareCardPreviewHeight);
    self.previewContentView.frame = self.previewView.bounds;
    BOOL hasPlaceholderDetail = self.placeholderDetailLabel.text.length > 0;
    CGFloat placeholderStackHeight = hasPlaceholderDetail ? 40.0f + 8.0f + 20.0f + 8.0f + 36.0f : 40.0f + 8.0f + 20.0f;
    CGFloat placeholderTop = (self.previewView.bounds.size.height - placeholderStackHeight) / 2.0f;
    self.placeholderIconView.frame = CGRectMake((self.previewView.bounds.size.width - 40.0f) / 2.0f, placeholderTop, 40.0f, 40.0f);
    self.placeholderTitleLabel.frame = CGRectMake(16.0f, placeholderTop + 48.0f, self.previewView.bounds.size.width - 32.0f, 20.0f);
    self.placeholderDetailLabel.frame = CGRectMake(16.0f, placeholderTop + 76.0f, self.previewView.bounds.size.width - 32.0f, 36.0f);
    if ([self.messageModel.content isKindOfClass:WKDocumentShareCardContent.class]) {
        [self layoutPreviewContent];
    }
}

- (void)onWillDisplay {
    [super onWillDisplay];
    if (![self.messageModel.content isKindOfClass:WKDocumentShareCardContent.class]) return;
    WKDocumentShareCardContent *content = (WKDocumentShareCardContent *)self.messageModel.content;
    if ([self.previewStatus isEqualToString:@"loading"] && self.preview == nil && !self.previewSubscription) {
        self.renderedUID = [WKApp shared].loginInfo.uid ?: @"";
        [self fetchPreviewForContent:content];
    } else if (self.previewFetchedAt > 0
               && NSDate.date.timeIntervalSince1970 - self.previewFetchedAt >= 30.0) {
        [self forceRefreshPreview];
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.previewSubscription cancel];
    self.previewSubscription = nil;
    self.requestGeneration++;
    self.preview = nil;
    self.previewStatus = nil;
    self.renderedDocId = nil;
    self.renderedSpaceId = nil;
    self.renderedUID = nil;
    self.renderedPreviewKind = nil;
    self.renderedPreviewTitle = nil;
    self.renderedPreviewStatus = nil;
    self.renderedPreviewData = nil;
    self.renderedPreviewLanguage = nil;
    self.previewNeedsRefresh = NO;
    self.previewFetchedAt = 0;
    self.lastForcedRefreshAt = 0;
}

- (void)onEndDisplay {
    [super onEndDisplay];
    [self.previewSubscription cancel];
    self.previewSubscription = nil;
    self.requestGeneration++;
}

- (void)copyDocumentLink {
    NSURL *url = [self documentURL];
    if (!url) return;
    [UIPasteboard generalPasteboard].string = url.absoluteString;
    [[WKNavigationManager shared].topViewController.view showMsg:LLang(@"已复制")];
}

- (void)openDocument {
    NSURL *url = [self documentURL];
    if (!url) return;
    WKDocumentShareCardContent *content = (WKDocumentShareCardContent *)self.messageModel.content;
    if (content.spaceId.length > 0 && !WKDocumentShareCardIsValidDocId(content.spaceId)) return;
    WKWebViewVC *webVC = [WKWebViewVC new];
    webVC.url = url;
    webVC.title = content.title;
    webVC.docsViewerSpaceId = content.spaceId;
    [[WKNavigationManager shared] pushViewController:webVC animated:YES];
}

- (NSURL *)documentURL {
    if (![self.messageModel.content isKindOfClass:WKDocumentShareCardContent.class]) return nil;
    WKDocumentShareCardContent *content = (WKDocumentShareCardContent *)self.messageModel.content;
    if (!WKDocumentShareCardIsValidDocId(content.docId)) return nil;
    NSString *path = [NSString stringWithFormat:@"/d/%@", content.docId];
    return WKDocumentShareCardAbsoluteURL(path, [WKApp shared].config.apiBaseUrl);
}

@end
