//
//  WKChannelHistoryMediaBrowserToolbar.m
//

#import "WKChannelHistoryMediaBrowserToolbar.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import "UIView+WK.h"
#import "UIView+WKCommon.h"
#import "WKActionSheetView2.h"
#import "WKActionSheetItem2.h"
#import "WKConstant.h"
#import "WKVideoBrowserData.h"

#define kTopBarHeight 44.0f

@interface WKChannelHistoryMediaBrowserToolbar ()
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIVisualEffectView *topBarBg;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UILabel *pageLabel;
@property (nonatomic, strong) UIButton *moreButton;
@end

@implementation WKChannelHistoryMediaBrowserToolbar

@synthesize yb_containerView = _yb_containerView;
@synthesize yb_currentData = _yb_currentData;
@synthesize yb_containerSize = _yb_containerSize;
@synthesize yb_currentOrientation = _yb_currentOrientation;

#pragma mark - YBIBToolViewHandler

- (void)yb_containerViewIsReadied {
    UIView *container = self.yb_containerView;
    if (!container) return;

    CGFloat topSafe = 0;
    if (@available(iOS 11.0, *)) {
        topSafe = UIApplication.sharedApplication.keyWindow.safeAreaInsets.top;
    }
    CGFloat w = WKScreenWidth;
    CGFloat barH = topSafe + kTopBarHeight;
    self.topBar.frame = CGRectMake(0, 0, w, barH);
    [container addSubview:self.topBar];

    self.topBarBg.frame = self.topBar.bounds;
    self.closeButton.frame = CGRectMake(4, topSafe, 44, kTopBarHeight);
    self.moreButton.frame = CGRectMake(w - 48, topSafe, 44, kTopBarHeight);
    self.pageLabel.frame = CGRectMake(60, topSafe, w - 120, kTopBarHeight);

    [self refreshPageLabel:self.initialPage];
}

- (void)yb_hide:(BOOL)hide {
    self.topBar.hidden = hide;
}

#pragma mark - YBImageBrowserDelegate (page indicator)

- (void)yb_imageBrowser:(YBImageBrowser *)imageBrowser
            pageChanged:(NSInteger)page
                   data:(id<YBIBDataProtocol>)data {
    [self refreshPageLabel:page];
}

- (void)refreshPageLabel:(NSInteger)page {
    if (self.totalPages > 1) {
        self.pageLabel.text = [NSString stringWithFormat:@"%ld / %ld",
                                (long)(page + 1), (long)self.totalPages];
        self.pageLabel.hidden = NO;
    } else {
        self.pageLabel.hidden = YES;
    }
}

#pragma mark - actions

- (void)onCloseTap {
    [self.browser hide];
}

- (WKChannelHistorySearchItem *)currentItem {
    id<YBIBDataProtocol> data = self.yb_currentData ? self.yb_currentData() : nil;
    if (!data) return nil;
    id extra = nil;
    if ([data isKindOfClass:[YBIBImageData class]]) {
        extra = ((YBIBImageData *)data).extraData;
    } else if ([data isKindOfClass:[WKVideoBrowserData class]]) {
        extra = ((WKVideoBrowserData *)data).extraData;
    }
    if ([extra isKindOfClass:[NSDictionary class]]) {
        id it = ((NSDictionary *)extra)[@"channelHistoryItem"];
        if ([it isKindOfClass:[WKChannelHistorySearchItem class]]) return (WKChannelHistorySearchItem *)it;
    }
    return nil;
}

- (void)onMoreTap {
    __weak typeof(self) ws = self;
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:nil];
    WKChannelHistorySearchItem *item = [self currentItem];
    if (item.canLocate && self.onLocateItem) {
        [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"定位到聊天位置") onClick:^{
            __strong typeof(ws) ss = ws;
            if (!ss) return;
            // 先收起浏览器, 再走定位 — 避免浏览器盖在聊天页上面。
            [ss.browser hide];
            if (ss.onLocateItem) ss.onLocateItem(item);
        }]];
    }
    id<YBIBDataProtocol> data = self.yb_currentData ? self.yb_currentData() : nil;
    BOOL isVideo = [data isKindOfClass:[WKVideoBrowserData class]];
    NSString *saveTitle = isVideo ? LLang(@"保存视频到相册") : LLang(@"保存图片到相册");
    [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:saveTitle onClick:^{
        id<YBIBDataProtocol> cur = ws.yb_currentData ? ws.yb_currentData() : nil;
        if (cur && cur.yb_allowSaveToPhotoAlbum) {
            [cur yb_saveToPhotoAlbum];
        }
    }]];
    [sheet show];
}

#pragma mark - lazy

- (UIView *)topBar {
    if (!_topBar) {
        _topBar = [[UIView alloc] init];
        _topBar.backgroundColor = [UIColor clearColor];
        // dark blur 始终可读, 不管底图什么颜色。透明度按 0.3 保留更多底图可视性 —
        // 配合 dark blur 的微反差, 文案/图标依旧清晰。
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        _topBarBg = [[UIVisualEffectView alloc] initWithEffect:blur];
        _topBarBg.alpha = 0.3;
        [_topBar addSubview:_topBarBg];
        [_topBar addSubview:self.closeButton];
        [_topBar addSubview:self.pageLabel];
        [_topBar addSubview:self.moreButton];
    }
    return _topBar;
}

- (UIButton *)closeButton {
    if (!_closeButton) {
        _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_closeButton setTitle:@"✕" forState:UIControlStateNormal];
        [_closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _closeButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
        [_closeButton addTarget:self action:@selector(onCloseTap) forControlEvents:UIControlEventTouchUpInside];
    }
    return _closeButton;
}

- (UILabel *)pageLabel {
    if (!_pageLabel) {
        _pageLabel = [UILabel new];
        _pageLabel.textColor = [UIColor whiteColor];
        _pageLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        _pageLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _pageLabel;
}

- (UIButton *)moreButton {
    if (!_moreButton) {
        _moreButton = [UIButton buttonWithType:UIButtonTypeSystem];
        UIImage *img = [WKApp.shared loadImage:@"Common/Index/More" moduleID:@"WuKongBase"];
        if (img) {
            [_moreButton setImage:[img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                          forState:UIControlStateNormal];
            _moreButton.tintColor = [UIColor whiteColor];
        } else {
            [_moreButton setTitle:@"⋯" forState:UIControlStateNormal];
            [_moreButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            _moreButton.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
        }
        [_moreButton addTarget:self action:@selector(onMoreTap) forControlEvents:UIControlEventTouchUpInside];
    }
    return _moreButton;
}

@end
