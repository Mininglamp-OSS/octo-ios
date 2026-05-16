// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKAISummaryActionMenu.m
//  WuKongBase
//

#import "WKAISummaryActionMenu.h"
#import <objc/runtime.h>

#pragma mark - Color helpers

static UIColor *MenuHex(uint32_t hex, CGFloat alpha) {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8)  & 0xFF) / 255.0
                            blue:( hex        & 0xFF) / 255.0
                           alpha:alpha];
}
static UIColor *MenuCyan(void)    { return MenuHex(0x00E0FF, 1.0); }
static UIColor *MenuMagenta(void) { return MenuHex(0xFF4DA1, 1.0); }
static UIColor *MenuGlass(void)   { return MenuHex(0x10142E, 0.92); }
static UIColor *MenuGlassHi(void) { return MenuHex(0x1B214A, 0.95); }

#pragma mark - Item model

@implementation WKAISummaryActionItem
+ (instancetype)itemWithKind:(WKAISummaryActionKind)kind
                      itemId:(NSInteger)itemId
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                 highlighted:(BOOL)highlighted {
    WKAISummaryActionItem *i = [self new];
    i.kind = kind;
    i.itemId = itemId;
    i.title = title;
    i.subtitle = subtitle;
    i.highlighted = highlighted;
    return i;
}
@end

#pragma mark - Item row（每行一个 UIControl，自带高亮态 + 渐入动画）

@interface _WKAISummaryRow : UIControl
@property(nonatomic, strong) WKAISummaryActionItem *model;
@property(nonatomic, strong) UILabel *titleLbl;
@property(nonatomic, strong) UILabel *subtitleLbl;
@property(nonatomic, strong) CALayer *glowDot;        // 默认项左侧的青色点
@property(nonatomic, strong) UIView  *bgFill;
@end

@implementation _WKAISummaryRow

- (instancetype)initWithItem:(WKAISummaryActionItem *)item {
    if ((self = [super initWithFrame:CGRectZero])) {
        _model = item;
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _bgFill = [[UIView alloc] init];
        _bgFill.backgroundColor = UIColor.clearColor;
        _bgFill.layer.cornerRadius = 10;
        _bgFill.userInteractionEnabled = NO;
        _bgFill.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_bgFill];
        [NSLayoutConstraint activateConstraints:@[
            [_bgFill.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:8],
            [_bgFill.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [_bgFill.topAnchor      constraintEqualToAnchor:self.topAnchor      constant:2],
            [_bgFill.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-2],
        ]];

        _glowDot = [CAShapeLayer layer];
        _glowDot.frame = CGRectMake(16, 0, 6, 6);
        _glowDot.cornerRadius = 3;
        _glowDot.backgroundColor = MenuCyan().CGColor;
        _glowDot.shadowColor = MenuCyan().CGColor;
        _glowDot.shadowRadius = 4;
        _glowDot.shadowOpacity = 0.9;
        _glowDot.shadowOffset = CGSizeZero;
        _glowDot.opacity = item.highlighted ? 1.0 : 0.0;
        [self.layer addSublayer:_glowDot];

        if (item.kind == WKAISummaryActionKindCustomPrompt) {
            [self buildStackedLayoutForItem:item];
        } else {
            [self buildStandardLayoutForItem:item];
        }

        if (item.highlighted && item.kind != WKAISummaryActionKindCustomPrompt) {
            // 默认项底色微亮 + 标题字色染青
            _bgFill.backgroundColor = MenuGlassHi();
            _titleLbl.textColor = MenuCyan();
        }
        if (item.destructive) {
            _titleLbl.textColor = MenuMagenta();
            _glowDot.opacity = 0.0;
        }
    }
    return self;
}

- (void)buildStandardLayoutForItem:(WKAISummaryActionItem *)item {
    _titleLbl = [[UILabel alloc] init];
    _titleLbl.text = item.title;
    _titleLbl.textColor = UIColor.whiteColor;
    _titleLbl.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    _titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLbl.userInteractionEnabled = NO;
    [self addSubview:_titleLbl];

    _subtitleLbl = [[UILabel alloc] init];
    _subtitleLbl.text = item.subtitle ?: @"";
    _subtitleLbl.textColor = MenuHex(0x9AA0C8, 1.0);
    _subtitleLbl.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    _subtitleLbl.textAlignment = NSTextAlignmentRight;
    _subtitleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLbl.userInteractionEnabled = NO;
    [self addSubview:_subtitleLbl];

    [NSLayoutConstraint activateConstraints:@[
        [_titleLbl.leadingAnchor    constraintEqualToAnchor:self.leadingAnchor   constant:32],
        [_titleLbl.centerYAnchor    constraintEqualToAnchor:self.centerYAnchor],
        [_titleLbl.trailingAnchor   constraintLessThanOrEqualToAnchor:_subtitleLbl.leadingAnchor constant:-8],

        [_subtitleLbl.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-22],
        [_subtitleLbl.centerYAnchor  constraintEqualToAnchor:self.centerYAnchor],
    ]];
}

/// 自定义提示词专用：标题在上、prompt 内容在下两行展示（高度 64pt）。
- (void)buildStackedLayoutForItem:(WKAISummaryActionItem *)item {
    _titleLbl = [[UILabel alloc] init];
    _titleLbl.text = item.title;
    _titleLbl.textColor = item.highlighted ? MenuCyan() : UIColor.whiteColor;
    _titleLbl.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    _titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLbl.userInteractionEnabled = NO;
    [self addSubview:_titleLbl];

    _subtitleLbl = [[UILabel alloc] init];
    _subtitleLbl.text = item.subtitle ?: @"";
    _subtitleLbl.textColor = [UIColor colorWithWhite:1.0 alpha:0.92];
    _subtitleLbl.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
    _subtitleLbl.numberOfLines = 2;
    _subtitleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    _subtitleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLbl.userInteractionEnabled = NO;
    [self addSubview:_subtitleLbl];

    if (item.highlighted) {
        _bgFill.backgroundColor = MenuGlassHi();
    }

    [NSLayoutConstraint activateConstraints:@[
        [_titleLbl.leadingAnchor    constraintEqualToAnchor:self.leadingAnchor   constant:32],
        [_titleLbl.trailingAnchor   constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-22],
        [_titleLbl.topAnchor        constraintEqualToAnchor:self.topAnchor       constant:8],

        [_subtitleLbl.leadingAnchor constraintEqualToAnchor:self.leadingAnchor   constant:32],
        [_subtitleLbl.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-18],
        [_subtitleLbl.topAnchor      constraintEqualToAnchor:_titleLbl.bottomAnchor constant:3],
    ]];
}

+ (CGFloat)heightForItem:(WKAISummaryActionItem *)item {
    return item.kind == WKAISummaryActionKindCustomPrompt ? 64.0 : 42.0;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.glowDot.position = CGPointMake(20, self.bounds.size.height / 2.0);
}

// 高亮态：tap 时 bgFill 闪一下青光
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.10 animations:^{
        if (highlighted) {
            self.bgFill.backgroundColor = self.model.highlighted ? MenuHex(0x2A356A, 1.0) : MenuGlassHi();
        } else {
            self.bgFill.backgroundColor = self.model.highlighted ? MenuGlassHi() : UIColor.clearColor;
        }
    }];
}

@end

#pragma mark - Owner（管理整个 menu 的生命周期）

@interface _WKAISummaryMenuOwner : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic, strong) UIView *backdrop;       // 全屏 dim + 捕获外部 tap
@property(nonatomic, strong) UIView *panel;          // 暗色玻璃面板
@property(nonatomic, strong) NSArray<_WKAISummaryRow *> *rows;
@property(nonatomic, strong) _WKAISummaryRow *footerRow;  // 可空
@property(nonatomic, copy)   void (^selectHandler)(WKAISummaryActionItem *);
@property(nonatomic, weak)   UIView *anchorView;
@end

@implementation _WKAISummaryMenuOwner

- (void)presentInWindow:(UIWindow *)win
                 anchor:(UIView *)anchor
                  title:(NSString *)title
               subtitle:(NSString *)subtitle
                  items:(NSArray<WKAISummaryActionItem *> *)items
             footerItem:(WKAISummaryActionItem *)footer {
    self.anchorView = anchor;

    // ---- backdrop ----
    self.backdrop = [[UIView alloc] initWithFrame:win.bounds];
    self.backdrop.backgroundColor = MenuHex(0x000000, 0.0); // 透明起始
    self.backdrop.userInteractionEnabled = YES;
    [win addSubview:self.backdrop];
    UITapGestureRecognizer *outsideTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                  action:@selector(onOutsideTap)];
    outsideTap.cancelsTouchesInView = NO;       // 不抢子视图的 touch
    outsideTap.delegate = self;                 // delegate 里只允许 panel 外的 tap
    [self.backdrop addGestureRecognizer:outsideTap];

    // ---- panel ----
    self.panel = [[UIView alloc] init];
    self.panel.backgroundColor = MenuGlass();
    self.panel.layer.cornerRadius = 16;
    self.panel.layer.borderColor  = MenuCyan().CGColor;
    self.panel.layer.borderWidth  = 1.0;
    self.panel.layer.shadowColor  = MenuHex(0x9D5CFF, 1.0).CGColor;
    self.panel.layer.shadowRadius = 18;
    self.panel.layer.shadowOpacity = 0.55;
    self.panel.layer.shadowOffset  = CGSizeMake(0, 4);
    self.panel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.backdrop addSubview:self.panel];

    // ---- title 区 ----
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.text = title;
    titleLbl.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
    titleLbl.textColor = UIColor.whiteColor;
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel addSubview:titleLbl];

    // 给 title 加渐变 mask（cyan→magenta 同 sparkle 字体）
    [self attachGradientMaskTo:titleLbl];

    UILabel *subtitleLbl = [[UILabel alloc] init];
    subtitleLbl.text = subtitle ?: @"";
    subtitleLbl.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    subtitleLbl.textColor = MenuHex(0x9AA0C8, 1.0);
    subtitleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel addSubview:subtitleLbl];

    // 标题区下方分割线（青色细线 + 微 glow）
    UIView *divider = [[UIView alloc] init];
    divider.backgroundColor = [MenuCyan() colorWithAlphaComponent:0.45];
    divider.layer.shadowColor = MenuCyan().CGColor;
    divider.layer.shadowRadius = 3;
    divider.layer.shadowOpacity = 0.6;
    divider.layer.shadowOffset = CGSizeZero;
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel addSubview:divider];

    // ---- 主 items ----
    NSMutableArray<_WKAISummaryRow *> *rows = [NSMutableArray array];
    UIView *prev = divider;
    for (WKAISummaryActionItem *it in items) {
        _WKAISummaryRow *row = [[_WKAISummaryRow alloc] initWithItem:it];
        [row addTarget:self action:@selector(onRowTap:) forControlEvents:UIControlEventTouchUpInside];
        [self.panel addSubview:row];
        [rows addObject:row];

        [NSLayoutConstraint activateConstraints:@[
            [row.leadingAnchor  constraintEqualToAnchor:self.panel.leadingAnchor],
            [row.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor],
            [row.topAnchor      constraintEqualToAnchor:prev.bottomAnchor constant:(prev == divider ? 6 : 0)],
            [row.heightAnchor   constraintEqualToConstant:[_WKAISummaryRow heightForItem:it]],
        ]];
        prev = row;
    }
    self.rows = rows;

    // ---- footer（切换 Bot）----
    if (footer) {
        UIView *footerDivider = [[UIView alloc] init];
        footerDivider.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
        footerDivider.translatesAutoresizingMaskIntoConstraints = NO;
        [self.panel addSubview:footerDivider];

        _WKAISummaryRow *footerRow = [[_WKAISummaryRow alloc] initWithItem:footer];
        [footerRow addTarget:self action:@selector(onRowTap:) forControlEvents:UIControlEventTouchUpInside];
        [self.panel addSubview:footerRow];
        self.footerRow = footerRow;

        [NSLayoutConstraint activateConstraints:@[
            [footerDivider.leadingAnchor  constraintEqualToAnchor:self.panel.leadingAnchor  constant:14],
            [footerDivider.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-14],
            [footerDivider.topAnchor      constraintEqualToAnchor:prev.bottomAnchor constant:6],
            [footerDivider.heightAnchor   constraintEqualToConstant:1.0/UIScreen.mainScreen.scale],

            [footerRow.leadingAnchor  constraintEqualToAnchor:self.panel.leadingAnchor],
            [footerRow.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor],
            [footerRow.topAnchor      constraintEqualToAnchor:footerDivider.bottomAnchor],
            [footerRow.heightAnchor   constraintEqualToConstant:[_WKAISummaryRow heightForItem:footer]],
        ]];
        prev = footerRow;
    }

    // ---- panel constraints（标题 + divider 区）----
    [NSLayoutConstraint activateConstraints:@[
        [titleLbl.leadingAnchor  constraintEqualToAnchor:self.panel.leadingAnchor  constant:18],
        [titleLbl.trailingAnchor constraintLessThanOrEqualToAnchor:self.panel.trailingAnchor constant:-18],
        [titleLbl.topAnchor      constraintEqualToAnchor:self.panel.topAnchor      constant:14],

        [subtitleLbl.leadingAnchor  constraintEqualToAnchor:self.panel.leadingAnchor  constant:18],
        [subtitleLbl.trailingAnchor constraintLessThanOrEqualToAnchor:self.panel.trailingAnchor constant:-18],
        [subtitleLbl.topAnchor      constraintEqualToAnchor:titleLbl.bottomAnchor    constant:2],

        [divider.leadingAnchor  constraintEqualToAnchor:self.panel.leadingAnchor  constant:14],
        [divider.trailingAnchor constraintEqualToAnchor:self.panel.trailingAnchor constant:-14],
        [divider.topAnchor      constraintEqualToAnchor:subtitleLbl.bottomAnchor  constant:8],
        [divider.heightAnchor   constraintEqualToConstant:1.0],

        // panel 宽度固定 240；位置：右下角，向上贴近按钮上方
        [self.panel.widthAnchor   constraintEqualToConstant:240],
        [self.panel.bottomAnchor  constraintEqualToAnchor:prev.bottomAnchor constant:10],
    ]];

    // 锚点：把 panel 右下贴在按钮的左上偏移
    CGRect anchorInWin = [anchor convertRect:anchor.bounds toView:win];
    NSLayoutConstraint *trail = [self.panel.trailingAnchor
                                 constraintEqualToAnchor:self.backdrop.leadingAnchor
                                 constant:CGRectGetMaxX(anchorInWin)];  // panel 右边对齐按钮右边
    NSLayoutConstraint *bot   = [self.panel.bottomAnchor
                                 constraintEqualToAnchor:self.backdrop.topAnchor
                                 constant:CGRectGetMinY(anchorInWin) - 12]; // panel 底贴按钮顶上 12pt
    trail.priority = bot.priority = UILayoutPriorityRequired;
    [NSLayoutConstraint activateConstraints:@[trail, bot]];

    // 入场动画
    [self animateInWithAnchor:anchorInWin];
}

#pragma mark - 渐变 mask（标题）

- (void)attachGradientMaskTo:(UILabel *)label {
    [label setNeedsLayout];
    [label layoutIfNeeded];
    // mask 用 gradient layer：cyan → magenta
    CAGradientLayer *g = [CAGradientLayer layer];
    g.colors = @[(id)MenuCyan().CGColor, (id)MenuMagenta().CGColor];
    g.startPoint = CGPointMake(0.0, 0.5);
    g.endPoint   = CGPointMake(1.0, 0.5);
    // 在下一 runloop 量好尺寸再贴
    dispatch_async(dispatch_get_main_queue(), ^{
        CGSize sz = [label.text sizeWithAttributes:@{NSFontAttributeName: label.font}];
        if (sz.width <= 0) return;
        UILabel *maskLbl = [[UILabel alloc] init];
        maskLbl.text = label.text;
        maskLbl.font = label.font;
        maskLbl.textColor = UIColor.whiteColor;
        maskLbl.frame = CGRectMake(0, 0, sz.width + 2, sz.height);
        UIGraphicsBeginImageContextWithOptions(maskLbl.bounds.size, NO, 0);
        [maskLbl.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        CALayer *m = [CALayer layer];
        m.frame = CGRectMake(0, 0, sz.width + 2, sz.height);
        m.contents = (id)img.CGImage;
        g.frame = m.frame;
        g.mask = m;
        [label.superview.layer insertSublayer:g above:label.layer];
        // 隐藏原 label，只保留渐变效果
        label.hidden = YES;
        // 把 g 放到 label 同位置
        CGPoint origin = [label convertPoint:CGPointZero toView:label.superview];
        g.frame = CGRectMake(origin.x, origin.y, sz.width + 2, sz.height);
    });
}

#pragma mark - 入场动画

- (void)animateInWithAnchor:(CGRect)anchorInWin {
    self.backdrop.alpha = 0;
    self.panel.transform = CGAffineTransformMakeScale(0.6, 0.6);

    // 把缩放锚点设到右下（接近按钮位置），让 spring 弹起像"从按钮里冒出"
    self.panel.layer.anchorPoint = CGPointMake(1.0, 1.0);

    // 激活布局，再调 transform
    [self.backdrop layoutIfNeeded];

    [UIView animateWithDuration:0.20 animations:^{
        self.backdrop.backgroundColor = MenuHex(0x000000, 0.30);
    }];

    [UIView animateWithDuration:0.40 delay:0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.7
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.panel.transform = CGAffineTransformIdentity;
    } completion:nil];

    self.backdrop.alpha = 1;

    // 行项目 stagger 入场（每 30ms 错峰，scale + fade）
    NSMutableArray<_WKAISummaryRow *> *all = [NSMutableArray arrayWithArray:self.rows];
    if (self.footerRow) [all addObject:self.footerRow];
    NSInteger i = 0;
    for (_WKAISummaryRow *row in all) {
        row.alpha = 0;
        row.transform = CGAffineTransformMakeTranslation(0, 8);
        [UIView animateWithDuration:0.28
                              delay:0.10 + 0.030 * i
             usingSpringWithDamping:0.85
              initialSpringVelocity:0.6
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            row.alpha = 1;
            row.transform = CGAffineTransformIdentity;
        } completion:nil];
        i++;
    }
}

#pragma mark - 退场动画

- (void)dismissWithSelected:(WKAISummaryActionItem *)item {
    void (^cb)(WKAISummaryActionItem *) = self.selectHandler;
    self.selectHandler = nil;

    [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.backdrop.backgroundColor = MenuHex(0x000000, 0.0);
        self.panel.alpha = 0;
        self.panel.transform = CGAffineTransformMakeScale(0.85, 0.85);
    } completion:^(BOOL finished) {
        [self.backdrop removeFromSuperview];
        self.backdrop = nil;
        self.panel = nil;
        if (cb) cb(item);
    }];
}

#pragma mark - 交互

- (void)onRowTap:(_WKAISummaryRow *)row {
    [self dismissWithSelected:row.model];
}

- (void)onOutsideTap {
    [self dismissWithSelected:nil];
}

#pragma mark - Gesture delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldReceiveTouch:(UITouch *)touch {
    // 只在 panel 之外的 tap 才触发关闭，避免和 row 的 UIControl tap 抢占
    CGPoint p = [touch locationInView:self.panel];
    return ![self.panel pointInside:p withEvent:nil];
}

@end

#pragma mark - 公共入口

@implementation WKAISummaryActionMenu

+ (void)presentFromView:(UIView *)anchorView
                  title:(NSString *)title
               subtitle:(NSString *)subtitle
                  items:(NSArray<WKAISummaryActionItem *> *)items
             footerItem:(WKAISummaryActionItem *)footerItem
              onSelect:(void (^)(WKAISummaryActionItem *))select {
    UIWindow *win = anchorView.window;
    if (!win) return;

    _WKAISummaryMenuOwner *owner = [_WKAISummaryMenuOwner new];
    owner.selectHandler = select;
    [owner presentInWindow:win
                    anchor:anchorView
                     title:title
                  subtitle:subtitle
                     items:items
                footerItem:footerItem];

    // 通过把 owner 放到 backdrop 的 associated obj 上保活到关闭
    objc_setAssociatedObject(owner.backdrop, _cmd, owner, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
