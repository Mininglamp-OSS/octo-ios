// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKConversationPendingImageBar.m
//  WuKongBase
//

#import "WKConversationPendingImageBar.h"
#import "UIView+WK.h"
#import "UIView+WKCommon.h"
#import "WKApp.h"
#import "WKNavigationManager.h"
#import "WuKongBase.h"

static const NSInteger kPendingMaxImages = 9;
static const CGFloat   kPendingThumbSize  = 64.0f;
static const CGFloat   kPendingThumbGap   = 8.0f;
static const CGFloat   kPendingPadX       = 12.0f;
static const CGFloat   kPendingPadY       = 8.0f;
static const CGFloat   kPendingDeleteSize = 22.0f;
static const NSInteger kPendingThumbBaseTag = 1000;
static const NSInteger kPendingDeleteBaseTag = 2000;

@interface WKConversationPendingImageBar ()
@property(nonatomic, strong) NSMutableArray<NSData *> *mutableImageDatas;
@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UIView *addCell; // 末尾 + cell；imageCount<上限 时显示
@end

@implementation WKConversationPendingImageBar

+ (CGFloat)preferredHeight {
    return kPendingThumbSize + kPendingPadY * 2;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _mutableImageDatas = [NSMutableArray array];
        self.clipsToBounds = YES;
        [self addSubview:self.scrollView];
        [self refreshTheme];
        [self rebuildCells];
    }
    return self;
}

- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.alwaysBounceHorizontal = YES;
        _scrollView.contentInset = UIEdgeInsetsMake(0, kPendingPadX, 0, kPendingPadX);
        _scrollView.backgroundColor = [UIColor clearColor];
    }
    return _scrollView;
}

#pragma mark - Public

- (NSArray<NSData *> *)imageDatas {
    return [self.mutableImageDatas copy];
}

- (NSUInteger)imageCount {
    return self.mutableImageDatas.count;
}

- (void)setImageDatas:(NSArray<NSData *> *)datas {
    [self runOnMain:^{
        [self.mutableImageDatas removeAllObjects];
        if (datas.count > 0) {
            NSUInteger take = MIN(datas.count, (NSUInteger)kPendingMaxImages);
            [self.mutableImageDatas addObjectsFromArray:[datas subarrayWithRange:NSMakeRange(0, take)]];
            if (datas.count > take) {
                [self showOverLimitHUD];
            }
        }
        [self rebuildCells];
        [self notifyChanged];
    }];
}

- (void)appendImageDatas:(NSArray<NSData *> *)datas {
    if (datas.count == 0) return;
    [self runOnMain:^{
        NSInteger remaining = kPendingMaxImages - (NSInteger)self.mutableImageDatas.count;
        if (remaining <= 0) {
            [self showOverLimitHUD];
            return;
        }
        NSUInteger take = MIN(datas.count, (NSUInteger)remaining);
        [self.mutableImageDatas addObjectsFromArray:[datas subarrayWithRange:NSMakeRange(0, take)]];
        if (datas.count > take) {
            [self showOverLimitHUD];
        }
        [self rebuildCells];
        [self notifyChanged];
    }];
}

- (void)removeImageDataAtIndex:(NSInteger)index {
    [self runOnMain:^{
        if (index < 0 || index >= (NSInteger)self.mutableImageDatas.count) return;
        [self.mutableImageDatas removeObjectAtIndex:index];
        [self rebuildCells];
        [self notifyChanged];
    }];
}

- (void)clear {
    [self runOnMain:^{
        if (self.mutableImageDatas.count == 0) return;
        [self.mutableImageDatas removeAllObjects];
        [self rebuildCells];
        [self notifyChanged];
    }];
}

- (void)refreshTheme {
    BOOL dark = ([WKApp shared].config.style == WKSystemStyleDark);
    self.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    if (self.addCell) {
        self.addCell.backgroundColor = dark
            ? [UIColor colorWithWhite:0.18 alpha:1.0]
            : [UIColor colorWithRed:246.0f/255.0f green:246.0f/255.0f blue:246.0f/255.0f alpha:1.0];
        self.addCell.layer.borderColor = (dark
            ? [UIColor colorWithWhite:0.30 alpha:1.0]
            : [UIColor colorWithWhite:0.85 alpha:1.0]).CGColor;
        for (UIView *sub in self.addCell.subviews) {
            if ([sub isKindOfClass:[UILabel class]]) {
                ((UILabel *)sub).textColor = dark
                    ? [UIColor colorWithWhite:0.75 alpha:1.0]
                    : [UIColor colorWithWhite:0.45 alpha:1.0];
            }
        }
    }
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    self.scrollView.frame = CGRectMake(0, kPendingPadY, self.bounds.size.width, kPendingThumbSize);
    [self relayoutCells];
}

- (void)rebuildCells {
    [self.scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.addCell = nil;

    NSInteger count = self.mutableImageDatas.count;
    for (NSInteger i = 0; i < count; i++) {
        UIView *cell = [self thumbnailCellForIndex:i data:self.mutableImageDatas[i]];
        [self.scrollView addSubview:cell];
    }

    if (count < kPendingMaxImages) {
        self.addCell = [self buildAddCell];
        [self.scrollView addSubview:self.addCell];
        [self refreshTheme];
    }

    [self relayoutCells];
}

- (void)relayoutCells {
    NSArray<UIView *> *cells = self.scrollView.subviews;
    CGFloat x = 0;
    for (UIView *cell in cells) {
        cell.frame = CGRectMake(x, 0, kPendingThumbSize, kPendingThumbSize);
        x += kPendingThumbSize + kPendingThumbGap;
    }
    if (cells.count > 0) x -= kPendingThumbGap; // 末尾不要尾随 gap
    self.scrollView.contentSize = CGSizeMake(MAX(x, 0), kPendingThumbSize);
}

#pragma mark - Cells

- (UIView *)thumbnailCellForIndex:(NSInteger)index data:(NSData *)data {
    UIView *cell = [[UIView alloc] init];
    cell.tag = kPendingThumbBaseTag + index;
    cell.layer.cornerRadius = 12.0f;
    cell.layer.masksToBounds = NO;
    cell.userInteractionEnabled = YES;

    UIImageView *iv = [[UIImageView alloc] init];
    iv.frame = CGRectMake(0, 0, kPendingThumbSize, kPendingThumbSize);
    iv.layer.cornerRadius = 12.0f;
    iv.layer.masksToBounds = YES;
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.image = [UIImage imageWithData:data];
    iv.userInteractionEnabled = YES;
    [cell addSubview:iv];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(onThumbTapped:)];
    [iv addGestureRecognizer:tap];

    // × 按钮放在 cell bounds 内（top-right 紧贴 corner），避免超界 hit-test 失效。
    UIButton *del = [UIButton buttonWithType:UIButtonTypeCustom];
    del.tag = kPendingDeleteBaseTag + index;
    del.frame = CGRectMake(kPendingThumbSize - kPendingDeleteSize,
                           0,
                           kPendingDeleteSize,
                           kPendingDeleteSize);
    del.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
    del.layer.cornerRadius = kPendingDeleteSize / 2.0f;
    del.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:11
                                                                                          weight:UIImageSymbolWeightBold];
        UIImage *icon = [[UIImage systemImageNamed:@"xmark" withConfiguration:cfg]
                         imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        [del setImage:icon forState:UIControlStateNormal];
    } else {
        [del setTitle:@"×" forState:UIControlStateNormal];
        [del setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        del.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    }
    [del addTarget:self action:@selector(onDeleteTapped:) forControlEvents:UIControlEventTouchUpInside];
    [cell addSubview:del];

    return cell;
}

- (UIView *)buildAddCell {
    UIView *cell = [[UIView alloc] init];
    cell.layer.cornerRadius = 12.0f;
    cell.layer.borderWidth = 1.0f;
    cell.userInteractionEnabled = YES;
    cell.clipsToBounds = YES;

    UILabel *plus = [[UILabel alloc] init];
    plus.text = @"+";
    plus.font = [UIFont systemFontOfSize:32 weight:UIFontWeightLight];
    plus.textAlignment = NSTextAlignmentCenter;
    plus.frame = CGRectMake(0, 0, kPendingThumbSize, kPendingThumbSize);
    [cell addSubview:plus];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(onAddTapped:)];
    [cell addGestureRecognizer:tap];
    return cell;
}

#pragma mark - Actions

- (void)onThumbTapped:(UITapGestureRecognizer *)gr {
    NSInteger idx = gr.view.superview.tag - kPendingThumbBaseTag;
    if (idx < 0 || idx >= (NSInteger)self.mutableImageDatas.count) return;
    if (self.onPreviewAtIndex) self.onPreviewAtIndex(idx);
}

- (void)onDeleteTapped:(UIButton *)btn {
    NSInteger idx = btn.tag - kPendingDeleteBaseTag;
    [self removeImageDataAtIndex:idx];
}

- (void)onAddTapped:(UITapGestureRecognizer *)gr {
    if (self.onAddTapped) self.onAddTapped();
}

#pragma mark - Helpers

- (void)notifyChanged {
    if (self.onContentSizeChanged) self.onContentSizeChanged();
}

- (void)runOnMain:(void(^)(void))block {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)showOverLimitHUD {
    UIView *target = [WKNavigationManager shared].topViewController.view;
    if (target) {
        [target showHUDWithHide:[NSString stringWithFormat:LLang(@"最多 %ld 张图片"), (long)kPendingMaxImages]];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self refreshTheme];
}

@end
