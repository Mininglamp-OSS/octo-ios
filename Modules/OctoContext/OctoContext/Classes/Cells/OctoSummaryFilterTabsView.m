//
//  OctoSummaryFilterTabsView.m
//  OctoContext
//

#import "OctoSummaryFilterTabsView.h"
#import <WuKongBase/WuKongBase.h>

@interface OctoSummaryFilterTabsView ()
@property(nonatomic, strong) UIScrollView *scroll;
@property(nonatomic, strong) NSMutableArray<UIView *> *tabContainers;
@property(nonatomic, strong) NSMutableArray<UILabel *> *labels;
@property(nonatomic, strong) NSMutableArray<UIView *> *indicators;
@end

@implementation OctoSummaryFilterTabsView

+ (NSInteger)taskStatusForFilter:(OctoSummaryFilterIndex)idx {
    switch (idx) {
        case OctoSummaryFilterPending:        return OctoTaskStatusPending;
        case OctoSummaryFilterWaitingConfirm: return OctoTaskStatusWaitingConfirm;
        case OctoSummaryFilterProcessing:     return OctoTaskStatusProcessing;
        case OctoSummaryFilterCompleted:      return OctoTaskStatusCompleted;
        case OctoSummaryFilterFailed:         return OctoTaskStatusFailed;
        default: return -1;
    }
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _scroll = [UIScrollView new];
        _scroll.showsHorizontalScrollIndicator = NO;
        _scroll.showsVerticalScrollIndicator = NO;
        _scroll.alwaysBounceHorizontal = YES;
        [self addSubview:_scroll];

        NSArray<NSString *> *titles = @[@"全部", @"等待中", @"等待参与者", @"生成中", @"已完成", @"失败"];
        _tabContainers = [NSMutableArray array];
        _labels = [NSMutableArray array];
        _indicators = [NSMutableArray array];

        for (NSInteger i = 0; i < titles.count; i++) {
            UIView *c = [UIView new];
            c.tag = i;
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
            [c addGestureRecognizer:tap];
            [_scroll addSubview:c];
            [_tabContainers addObject:c];

            UILabel *l = [UILabel new];
            l.text = LLang(titles[i]);
            [c addSubview:l];
            [_labels addObject:l];

            UIView *ind = [UIView new];
            ind.layer.cornerRadius = 1.5;
            ind.backgroundColor = [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0];
            ind.hidden = YES;
            [c addSubview:ind];
            [_indicators addObject:ind];
        }
        self.selectedIndex = OctoSummaryFilterAll;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.scroll.frame = self.bounds;
    CGFloat x = 16;
    CGFloat h = self.bounds.size.height;
    for (NSInteger i = 0; i < self.tabContainers.count; i++) {
        BOOL active = (i == self.selectedIndex);
        UILabel *l = self.labels[i];
        l.font = active ? [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold]
                        : [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
        l.textColor = active
            ? [UIColor labelColor]
            : [UIColor.labelColor colorWithAlphaComponent:0.6];
        [l sizeToFit];

        UIView *c = self.tabContainers[i];
        CGFloat w = MAX(l.frame.size.width, 24);
        c.frame = CGRectMake(x, 0, w, h);
        l.frame = CGRectMake(0, h - l.frame.size.height - 7, w, l.frame.size.height);

        UIView *ind = self.indicators[i];
        ind.frame = CGRectMake((w - 16) / 2.0, h - 3, 16, 3);
        ind.hidden = !active;

        x += w + 14;
    }
    self.scroll.contentSize = CGSizeMake(x + 16, h);
}

- (void)setSelectedIndex:(OctoSummaryFilterIndex)selectedIndex {
    if (selectedIndex == _selectedIndex) return;
    _selectedIndex = selectedIndex;
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)onTap:(UITapGestureRecognizer *)g {
    NSInteger idx = g.view.tag;
    if (idx == self.selectedIndex) return;
    self.selectedIndex = idx;
    if (self.onSelect) self.onSelect(idx);
}

@end
