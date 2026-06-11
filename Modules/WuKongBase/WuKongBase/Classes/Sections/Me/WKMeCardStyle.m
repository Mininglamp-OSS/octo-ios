//
//  WKMeCardStyle.m
//  WuKongBase
//

#import "WKMeCardStyle.h"
#import "WKApp.h"
#import "WKFormItemCell.h"
#import "WKButtonItemCell.h"

static UIColor *WKMeCardDividerColor(void) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull tc) {
            if(tc.userInterfaceStyle == UIUserInterfaceStyleDark || [WKApp shared].config.style == WKSystemStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.06];
            }
            return [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xFA/255.0 alpha:1.0];
        }];
    }
    return [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xFA/255.0 alpha:1.0];
}

static UIColor *WKMeCardSwitchTint(void) {
    // UISwitch.onTintColor 不能直接交给 colorWithDynamicProvider —— UIKit 内部
    // 把 onTintColor 转成 CGColor 缓存在 layer,trait change 时不会重新解析。
    // 但 wk_applyMeCardStyleAtIndexPath: 是在 willDisplay 调用,每次 cell 上屏都
    // 重设一次,所以这里直接根据当前 trait 返回静态色就够了。
    // 浅色: 设计稿 #1C1C23 (近黑); 深色: 浅色 backdrop 上需要可见的对比色,
    // 沿用 defaultTextColor 系列 (#D0D1D2) —— 与 ON 状态白拨片对比明显,
    // 视觉上和系统 dark mode 默认 onTint 一致。
    if (@available(iOS 13.0, *)) {
        BOOL isDark = ([UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark)
                      || ([WKApp shared].config.style == WKSystemStyleDark);
        if (isDark) {
            return [UIColor colorWithRed:0xD0/255.0 green:0xD1/255.0 blue:0xD2/255.0 alpha:1.0];
        }
    }
    return [UIColor colorWithRed:0x1C/255.0 green:0x1C/255.0 blue:0x23/255.0 alpha:1.0];
}

@implementation UITableViewCell (WKMeCardStyle)

- (void)wk_applyMeCardStyleAtIndexPath:(NSIndexPath *)indexPath inTableView:(UITableView *)tableView {
    // WKButtonItemCell（如「退出登录」）走红色描边按钮样式，不画卡片背景
    if([self isKindOfClass:[WKButtonItemCell class]]) {
        UIColor *brandRed = [UIColor colorWithRed:0xF6/255.0 green:0x5E/255.0 blue:0x58/255.0 alpha:1.0];
        UIView *bg = [[UIView alloc] init];
        bg.backgroundColor = [UIColor clearColor];
        bg.layer.cornerRadius = 24.0f;
        bg.layer.borderWidth = 1.5f;
        bg.layer.borderColor = brandRed.CGColor;
        bg.layer.masksToBounds = YES;
        self.backgroundView = bg;
        self.backgroundColor = [UIColor clearColor];
        return;
    }

    NSInteger rowCount = [tableView numberOfRowsInSection:indexPath.section];
    BOOL isFirst = indexPath.row == 0;
    BOOL isLast  = indexPath.row == rowCount - 1;

    UIView *bg = [[UIView alloc] init];
    bg.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    bg.layer.cornerRadius = 16.0f;
    bg.layer.masksToBounds = YES;
    CACornerMask mask = 0;
    if(isFirst) mask |= kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    if(isLast)  mask |= kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    bg.layer.maskedCorners = mask;
    self.backgroundView = bg;
    self.backgroundColor = [UIColor clearColor];

    UIColor *tint = WKMeCardSwitchTint();
    for(UIView *v in self.contentView.subviews) {
        if([v isKindOfClass:[UISwitch class]]) {
            [(UISwitch *)v setOnTintColor:tint];
        }
    }

    if([self isKindOfClass:[WKFormItemCell class]]) {
        WKFormItemCell *fc = (WKFormItemCell *)self;
        fc.bottomLineView.backgroundColor = WKMeCardDividerColor();
    }
}

@end
