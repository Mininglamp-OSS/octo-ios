//
//  WKChannelHistorySearchEmptyView.m
//

#import "WKChannelHistorySearchEmptyView.h"
#import "WKApp.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"

@interface WKChannelHistorySearchEmptyView ()
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *primaryLbl;
@property (nonatomic, strong) UILabel *secondaryLbl;
@property (nonatomic, strong) UIButton *retryBtn;
@end

@implementation WKChannelHistorySearchEmptyView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;

        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _spinner.hidesWhenStopped = YES;
        _spinner.color = [WKApp shared].config.themeColor;
        [self addSubview:_spinner];

        _iconView = [UIImageView new];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = [[UIColor grayColor] colorWithAlphaComponent:0.6];
        [self addSubview:_iconView];

        _primaryLbl = [UILabel new];
        _primaryLbl.font = [[WKApp shared].config appFontOfSize:15.0f];
        _primaryLbl.textColor = [UIColor grayColor];
        _primaryLbl.textAlignment = NSTextAlignmentCenter;
        _primaryLbl.numberOfLines = 0;
        [self addSubview:_primaryLbl];

        _secondaryLbl = [UILabel new];
        _secondaryLbl.font = [[WKApp shared].config appFontOfSize:13.0f];
        _secondaryLbl.textColor = [[UIColor grayColor] colorWithAlphaComponent:0.7];
        _secondaryLbl.textAlignment = NSTextAlignmentCenter;
        _secondaryLbl.numberOfLines = 0;
        [self addSubview:_secondaryLbl];

        _retryBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        _retryBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
        [_retryBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        [_retryBtn setTitle:LLang(@"点击重试") forState:UIControlStateNormal];
        _retryBtn.layer.cornerRadius = 14.0f;
        _retryBtn.layer.borderColor = [WKApp shared].config.themeColor.CGColor;
        _retryBtn.layer.borderWidth = 1.0f;
        _retryBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 18, 6, 18);
        _retryBtn.hidden = YES;
        [_retryBtn addTarget:self action:@selector(onRetryTap) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_retryBtn];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.lim_width;
    CGFloat h = self.lim_height;
    // 整体居中，距顶部约 1/3
    CGFloat centerY = h * 0.4f;
    CGFloat textW = MIN(w - 60, 280);
    CGFloat cursorY = centerY - 60.0f;

    self.spinner.lim_centerX = w / 2.0f;
    self.spinner.lim_centerY = cursorY;
    self.iconView.frame = CGRectMake((w - 64) / 2.0f, cursorY - 32.0f, 64, 64);

    if (!self.iconView.hidden) {
        cursorY = CGRectGetMaxY(self.iconView.frame) + 14.0f;
    } else if (self.spinner.isAnimating) {
        cursorY = CGRectGetMaxY(self.spinner.frame) + 14.0f;
    } else {
        cursorY = centerY;
    }

    self.primaryLbl.frame = CGRectMake((w - textW) / 2.0f, cursorY, textW, 22.0f);
    cursorY = CGRectGetMaxY(self.primaryLbl.frame) + 6.0f;
    self.secondaryLbl.frame = CGRectMake((w - textW) / 2.0f, cursorY, textW, 18.0f);
    if (self.secondaryLbl.text.length > 0) {
        cursorY = CGRectGetMaxY(self.secondaryLbl.frame) + 14.0f;
    }
    [self.retryBtn sizeToFit];
    CGFloat bw = MAX(96.0f, self.retryBtn.lim_width);
    self.retryBtn.frame = CGRectMake((w - bw) / 2.0f, cursorY, bw, 30.0f);
}

- (void)onRetryTap {
    if (self.onRetry) self.onRetry();
}

- (void)setMode:(WKChannelHistorySearchEmptyMode)mode {
    [self applyMode:mode primary:nil secondary:nil];
}

- (void)applyMode:(WKChannelHistorySearchEmptyMode)mode
       primary:(NSString *)primary
     secondary:(NSString *)secondary {
    _mode = mode;
    self.spinner.hidden = (mode != WKChannelHistorySearchEmptyModeLoading);
    if (mode == WKChannelHistorySearchEmptyModeLoading) {
        [self.spinner startAnimating];
    } else {
        [self.spinner stopAnimating];
    }
    self.iconView.hidden = (mode == WKChannelHistorySearchEmptyModeLoading);
    self.retryBtn.hidden = (mode != WKChannelHistorySearchEmptyModeError && mode != WKChannelHistorySearchEmptyModeOffline);
    // 文案
    NSString *p = primary;
    NSString *s = secondary;
    switch (mode) {
        case WKChannelHistorySearchEmptyModeWaitingInput:
            if (p.length == 0) p = LLang(@"输入关键词查找此聊天内的记录");
            break;
        case WKChannelHistorySearchEmptyModeNoResults:
            if (p.length == 0) p = LLang(@"未找到相关内容");
            if (s.length == 0) s = LLang(@"换个关键词或调整筛选条件再试试");
            break;
        case WKChannelHistorySearchEmptyModeLoading:
            if (p.length == 0) p = LLang(@"搜索中…");
            break;
        case WKChannelHistorySearchEmptyModeError:
            if (p.length == 0) p = LLang(@"加载失败");
            if (s.length == 0) s = LLang(@"请检查网络后重试");
            break;
        case WKChannelHistorySearchEmptyModeOffline:
            if (p.length == 0) p = LLang(@"当前网络不可用");
            if (s.length == 0) s = LLang(@"请检查网络设置");
            break;
    }
    self.primaryLbl.text = p;
    self.secondaryLbl.text = s;
    [self setNeedsLayout];
}

@end
