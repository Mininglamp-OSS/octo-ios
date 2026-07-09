//
//  WKChannelHistoryFilterChipBar.m
//

#import "WKChannelHistoryFilterChipBar.h"
#import "WKApp.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import <objc/runtime.h>

// 用于把 chip descriptor 绑到 ✕ 按钮上的关联对象 key。老实现 set 用 `_cmd`
// (= relayoutChips) 而 get 用 @selector(onChipTap:), 两把钥匙不匹配 →
// getAssociatedObject 恒返 nil → ✕ 清除按钮点了没反应 (PR #64 review 3 位 reviewer 独立命中)。
// 用一个 static const void * 统一 key 避免再犯。
static const void * const kWKChipDescKey = &kWKChipDescKey;

@implementation WKChannelHistoryFilterChipDescriptor
@end

@interface WKChannelHistoryFilterChipBar ()
@property (nonatomic, strong) UIScrollView *scrollView;
@end

@implementation WKChannelHistoryFilterChipBar

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [WKApp shared].config.backgroundColor;
        _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.alwaysBounceHorizontal = YES;
        [self addSubview:_scrollView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.scrollView.frame = self.bounds;
    [self relayoutChips];
}

- (void)setChips:(NSArray<WKChannelHistoryFilterChipDescriptor *> *)chips {
    _chips = [chips copy];
    [self relayoutChips];
}

- (void)relayoutChips {
    for (UIView *sub in [self.scrollView.subviews copy]) [sub removeFromSuperview];
    CGFloat x = 12.0f;
    CGFloat h = self.lim_height > 0 ? self.lim_height : 32.0f;
    UIColor *theme = [WKApp shared].config.themeColor;
    UIColor *bg = [theme colorWithAlphaComponent:0.10];
    UIFont *font = [[WKApp shared].config appFontOfSize:12.0f];
    for (WKChannelHistoryFilterChipDescriptor *d in self.chips) {
        // 容器
        UIControl *chip = [[UIControl alloc] init];
        chip.backgroundColor = bg;
        chip.layer.cornerRadius = (h - 12.0f) / 2.0f;
        chip.layer.masksToBounds = YES;
        [chip addTarget:self action:@selector(onChipTap:) forControlEvents:UIControlEventTouchUpInside];
        chip.tag = [self.chips indexOfObject:d];

        // 文本
        UILabel *lbl = [UILabel new];
        lbl.text = d.title ?: @"";
        lbl.font = font;
        lbl.textColor = theme;
        [chip addSubview:lbl];
        CGFloat textW = [lbl sizeThatFits:CGSizeMake(220.0f, h)].width;
        lbl.frame = CGRectMake(10.0f, 0, textW, h - 12.0f);

        // ✕ 按钮
        UIButton *clr = [UIButton buttonWithType:UIButtonTypeSystem];
        clr.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightMedium];
        [clr setTitle:@"✕" forState:UIControlStateNormal];
        [clr setTitleColor:theme forState:UIControlStateNormal];
        clr.frame = CGRectMake(CGRectGetMaxX(lbl.frame) + 4.0f, 0, 24.0f, h - 12.0f);
        // 用 block 持久持有 onClear
        WKChannelHistoryFilterChipDescriptor *desc = d;
        [clr addTarget:self action:@selector(onChipClearProxy:) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(clr, kWKChipDescKey, desc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [chip addSubview:clr];

        CGFloat chipW = CGRectGetMaxX(clr.frame) + 8.0f;
        chip.frame = CGRectMake(x, 6.0f, chipW, h - 12.0f);
        [self.scrollView addSubview:chip];
        x = CGRectGetMaxX(chip.frame) + 8.0f;
    }
    self.scrollView.contentSize = CGSizeMake(x + 4.0f, h);
}

- (void)onChipTap:(UIControl *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)self.chips.count) return;
    WKChannelHistoryFilterChipDescriptor *d = self.chips[idx];
    if (d.onTap) d.onTap();
}

- (void)onChipClearProxy:(UIButton *)btn {
    WKChannelHistoryFilterChipDescriptor *d = objc_getAssociatedObject(btn, kWKChipDescKey);
    if (!d) return;
    if (d.onClear) d.onClear();
}

@end
