// SPDX-License-Identifier: Apache-2.0
// Copyright (c) MININGLAMP. All rights reserved.
//
//  WKFollowCategorySheet.m
//  WuKongBase
//

#import "WKFollowCategorySheet.h"
#import "WKApp.h"
#import "WKCategoryEntity.h"
#import "UIView+WK.h"
#import "UIView+WKCommon.h"
#import "NSString+WKLocalized.h"
#import <objc/runtime.h>

static const NSInteger kWKFollowCategorySheetOverlayTag = 77800;
static const NSInteger kWKFollowCategorySheetRowTagBase = 78000;
static const NSInteger kWKFollowCategorySheetCreateTag  = 77811;
static const void *kSheetInstanceAssocKey = &kSheetInstanceAssocKey;

@interface WKFollowCategorySheet ()
@property (nonatomic, copy) void (^onPick)(NSString *categoryId, NSString *categoryName);
@property (nonatomic, copy) void (^onCreateRequested)(void);
@property (nonatomic, strong) NSArray<WKCategoryEntity *> *categories;
@end

@implementation WKFollowCategorySheet

+ (void)showWithTitle:(NSString *)title
            categories:(NSArray<WKCategoryEntity *> *)categories
    selectedCategoryId:(NSString *)selectedCategoryId
         showCreateRow:(BOOL)showCreateRow
                onPick:(void (^)(NSString *, NSString *))onPick
     onCreateRequested:(void (^)(void))onCreateRequested {
    WKFollowCategorySheet *sheet = [WKFollowCategorySheet new];
    sheet.categories = categories ?: @[];
    sheet.onPick = onPick;
    sheet.onCreateRequested = onCreateRequested;
    [sheet presentWithTitle:title
         selectedCategoryId:selectedCategoryId
              showCreateRow:showCreateRow];
}

+ (void)dismiss {
    UIWindow *window = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    UIView *overlay = [window viewWithTag:kWKFollowCategorySheetOverlayTag];
    if (!overlay) return;
    WKFollowCategorySheet *inst = objc_getAssociatedObject(overlay, kSheetInstanceAssocKey);
    [inst animateDismissForOverlay:overlay];
}

#pragma mark - Present

- (void)presentWithTitle:(NSString *)title
       selectedCategoryId:(NSString *)selectedCategoryId
             showCreateRow:(BOOL)showCreateRow {
    UIWindow *window = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    if (!window) return;

    UIView *existing = [window viewWithTag:kWKFollowCategorySheetOverlayTag];
    if (existing) [existing removeFromSuperview];

    UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    overlay.alpha = 0;
    overlay.tag = kWKFollowCategorySheetOverlayTag;
    [window addSubview:overlay];

    // self 必须比 overlay 活久 —— 关联到 overlay 上，overlay 释放时 self 跟着释放。
    objc_setAssociatedObject(overlay, kSheetInstanceAssocKey, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    CGFloat headerH = 48;
    CGFloat rowH = 52;
    CGFloat createBtnH = 52;
    CGFloat maxVisibleRows = 6;
    CGFloat tableMaxH = rowH * maxVisibleRows;
    CGFloat tableH = MIN(rowH * self.categories.count, tableMaxH);
    CGFloat bottomSafe = 0;
    if (@available(iOS 11.0, *)) {
        bottomSafe = window.safeAreaInsets.bottom;
    }
    CGFloat sheetH = headerH + tableH + 0.5 + (showCreateRow ? createBtnH : 0) + bottomSafe;
    CGFloat sheetW = window.lim_width;

    UIView *sheet = [[UIView alloc] initWithFrame:CGRectMake(0, window.lim_height, sheetW, sheetH)];
    sheet.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    sheet.layer.cornerRadius = 14;
    if ([sheet respondsToSelector:@selector(setMaskedCorners:)]) {
        sheet.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    }
    sheet.layer.masksToBounds = YES;
    [overlay addSubview:sheet];

    // Header
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, sheetW, headerH)];
    [sheet addSubview:header];

    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(50, 0, sheetW - 100, headerH)];
    titleLbl.text = title;
    titleLbl.textAlignment = NSTextAlignmentCenter;
    titleLbl.font = [[WKApp shared].config appFontOfSizeSemibold:16];
    titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    [header addSubview:titleLbl];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(sheetW - 44, 0, 44, headerH);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:18];
    UIColor *closeColor = [[WKApp shared].config.defaultTextColor colorWithAlphaComponent:0.6];
    closeBtn.tintColor = closeColor;
    [closeBtn setTitleColor:closeColor forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(onCloseTapped) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    UIView *headerSep = [[UIView alloc] initWithFrame:CGRectMake(0, headerH - 0.5, sheetW, 0.5)];
    headerSep.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.15];
    [sheet addSubview:headerSep];

    // 中间分组列表（用 scroll + buttons，避免与外层 tableView dataSource 冲突）
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, headerH, sheetW, tableH)];
    scroll.showsVerticalScrollIndicator = YES;
    scroll.alwaysBounceVertical = (self.categories.count > maxVisibleRows);
    scroll.contentSize = CGSizeMake(sheetW, rowH * self.categories.count);
    [sheet addSubview:scroll];

    UIColor *cellTextColor = [WKApp shared].config.defaultTextColor;
    UIColor *sepColor = [[UIColor grayColor] colorWithAlphaComponent:0.15];
    for (NSInteger i = 0; i < (NSInteger)self.categories.count; i++) {
        WKCategoryEntity *cat = self.categories[i];
        UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
        row.frame = CGRectMake(0, i * rowH, sheetW, rowH);
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        row.contentEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 20);
        BOOL isSelected = selectedCategoryId.length > 0 && [cat.category_id isEqualToString:selectedCategoryId];
        NSString *displayTitle = isSelected ? [NSString stringWithFormat:@"✓ %@", cat.name ?: @""] : (cat.name ?: @"");
        [row setTitle:displayTitle forState:UIControlStateNormal];
        [row setTitleColor:cellTextColor forState:UIControlStateNormal];
        [row setTitleColor:[cellTextColor colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
        row.titleLabel.font = [[WKApp shared].config appFontOfSize:16];
        row.tag = kWKFollowCategorySheetRowTagBase + i;
        [row addTarget:self action:@selector(onRowTapped:) forControlEvents:UIControlEventTouchUpInside];
        [scroll addSubview:row];

        if (i < (NSInteger)self.categories.count - 1) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(20, (i + 1) * rowH - 0.5, sheetW - 20, 0.5)];
            sep.backgroundColor = sepColor;
            [scroll addSubview:sep];
        }
    }

    if (showCreateRow) {
        UIView *bottomSep = [[UIView alloc] initWithFrame:CGRectMake(0, headerH + tableH, sheetW, 0.5)];
        bottomSep.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.15];
        [sheet addSubview:bottomSep];

        UIButton *createBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        createBtn.frame = CGRectMake(0, headerH + tableH + 0.5, sheetW, createBtnH);
        [createBtn setTitle:[@"+ 新建分组" LocalizedWithClass:[WKFollowCategorySheet class]] forState:UIControlStateNormal];
        createBtn.titleLabel.font = [[WKApp shared].config appFontOfSizeMedium:16];
        UIColor *accent = [WKApp shared].config.themeColor ?: [UIColor colorWithRed:138.0 / 255 green:91.0 / 255 blue:255.0 / 255 alpha:1];
        createBtn.tintColor = accent;
        [createBtn setTitleColor:accent forState:UIControlStateNormal];
        createBtn.tag = kWKFollowCategorySheetCreateTag;
        [createBtn addTarget:self action:@selector(onCreateTapped) forControlEvents:UIControlEventTouchUpInside];
        [sheet addSubview:createBtn];
    }

    // 点 overlay 关闭；点 sheet 内部不冒泡
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onCloseTapped)];
    [overlay addGestureRecognizer:tap];
    UITapGestureRecognizer *eat = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(noop)];
    [sheet addGestureRecognizer:eat];

    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        overlay.alpha = 1;
        sheet.frame = CGRectMake(0, window.lim_height - sheetH, sheetW, sheetH);
    } completion:nil];
}

#pragma mark - Actions

- (void)noop {}

- (void)onCloseTapped {
    UIWindow *window = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    UIView *overlay = [window viewWithTag:kWKFollowCategorySheetOverlayTag];
    [self animateDismissForOverlay:overlay];
}

- (void)onRowTapped:(UIButton *)btn {
    NSInteger idx = btn.tag - kWKFollowCategorySheetRowTagBase;
    void (^cb)(NSString *, NSString *) = self.onPick;
    UIWindow *window = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    UIView *overlay = [window viewWithTag:kWKFollowCategorySheetOverlayTag];
    [self animateDismissForOverlay:overlay];
    if (idx < 0 || idx >= (NSInteger)self.categories.count) return;
    WKCategoryEntity *cat = self.categories[idx];
    if (cb) cb(cat.category_id, cat.name);
}

- (void)onCreateTapped {
    void (^cb)(void) = self.onCreateRequested;
    UIWindow *window = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    UIView *overlay = [window viewWithTag:kWKFollowCategorySheetOverlayTag];
    [self animateDismissForOverlay:overlay];
    if (cb) cb();
}

- (void)animateDismissForOverlay:(UIView *)overlay {
    if (!overlay) return;
    UIWindow *window = (UIWindow *)overlay.superview;
    UIView *sheet = nil;
    for (UIView *sub in overlay.subviews) {
        // overlay 里只有一个 sheet 视图（其它都是手势 attach），第一个就是
        if ([sub isKindOfClass:[UIView class]]) { sheet = sub; break; }
    }
    CGRect end = sheet.frame; end.origin.y = window.lim_height;
    [UIView animateWithDuration:0.2 animations:^{
        overlay.alpha = 0;
        if (sheet) sheet.frame = end;
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
}

@end
