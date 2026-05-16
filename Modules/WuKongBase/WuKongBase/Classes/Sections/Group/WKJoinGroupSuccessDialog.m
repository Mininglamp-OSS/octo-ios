//
//  WKJoinGroupSuccessDialog.m
//  WuKongBase
//
//  — see header.
//

#import "WKJoinGroupSuccessDialog.h"
#import "WuKongBase.h"

@interface WKJoinGroupSuccessDialog ()
@property(nonatomic,strong) UIView *backdrop;
@property(nonatomic,strong) UIView *cardView;
@property(nonatomic,strong) UILabel *line1Lbl;        ///< 已加入 "xxx"
@property(nonatomic,strong) UILabel *line2Lbl;        ///< 此群位于 xxx Space
@property(nonatomic,strong) UIButton *cancelBtn;
@property(nonatomic,strong) UIButton *switchBtn;
@end

@implementation WKJoinGroupSuccessDialog

#pragma mark - 公开入口

+ (instancetype)showWithNotice:(WKJoinGroupSuccessNotice *)notice
                      onSwitch:(void (^)(void))onSwitch {
    UIWindow *window = [self keyWindow];
    if (!window) {
        return nil;
    }
    WKJoinGroupSuccessDialog *dialog = [[WKJoinGroupSuccessDialog alloc] initWithNotice:notice];
    dialog.frame = window.bounds;
    dialog.onSwitchTapped = onSwitch;

    dialog.alpha = 0;
    [window addSubview:dialog];
    [UIView animateWithDuration:0.2 animations:^{
        dialog.alpha = 1.0;
    }];
    return dialog;
}

+ (UIWindow *)keyWindow {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) { return w; }
            }
            keyWindow = ws.windows.firstObject;
            if (keyWindow) break;
        }
    }
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    return keyWindow;
}

#pragma mark - init

- (instancetype)initWithNotice:(WKJoinGroupSuccessNotice *)notice {
    self = [super init];
    if (!self) return nil;

    self.backgroundColor = [UIColor clearColor];

    // 背景遮罩（点遮罩取消切换，保持 viewer 在原 Space — 对齐硬约束）
    _backdrop = [[UIView alloc] init];
    _backdrop.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBackdropTapped)];
    [_backdrop addGestureRecognizer:tap];
    [self addSubview:_backdrop];

    // 卡片容器
    _cardView = [[UIView alloc] init];
    _cardView.backgroundColor = [WKApp shared].config.cellBackgroundColor ?: [UIColor whiteColor];
    _cardView.layer.cornerRadius = 12.0f;
    _cardView.layer.masksToBounds = YES;
    [self addSubview:_cardView];

    // 第一行：已加入 "xxx"
    // : 三端统一 i18n key 命名 `group_join_cross_space_notice` — iOS 的
    // Localizable.strings 采用"中文即 key"约定，这里保持中文源串作为 key，
    // 逻辑 key 在注释中记录便于跨端检索。首行对应 `group_join_cross_space_notice.title`。
    _line1Lbl = [[UILabel alloc] init];
    _line1Lbl.numberOfLines = 2;
    _line1Lbl.font = [[WKApp shared].config appFontOfSizeSemibold:16.0f] ?: [UIFont boldSystemFontOfSize:16.0f];
    _line1Lbl.textColor = [WKApp shared].config.defaultTextColor ?: [UIColor blackColor];
    _line1Lbl.textAlignment = NSTextAlignmentCenter;
    NSString *groupName = notice.groupName.length > 0 ? notice.groupName : @"";
    // 用中文引号包裹群名更贴合 dmwork i18n；与 Web 文案一致："已加入 '群名'"
    _line1Lbl.text = [NSString stringWithFormat:LLang(@"已加入 '%@'"), groupName];
    [_cardView addSubview:_line1Lbl];

    // 第二行：此群位于 xxx Space
    // 对应 `group_join_cross_space_notice.subtitle`。
    _line2Lbl = [[UILabel alloc] init];
    _line2Lbl.numberOfLines = 2;
    _line2Lbl.font = [UIFont systemFontOfSize:14.0f];
    _line2Lbl.textColor = [UIColor colorWithRed:128/255.0f green:128/255.0f blue:128/255.0f alpha:1.0f];
    _line2Lbl.textAlignment = NSTextAlignmentCenter;
    NSString *spaceName = notice.spaceName.length > 0 ? notice.spaceName : LLang(@"其它");
    _line2Lbl.text = [NSString stringWithFormat:LLang(@"此群位于 %@ Space"), spaceName];
    [_cardView addSubview:_line2Lbl];

    // 「取消」
    _cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_cancelBtn setTitle:LLang(@"取消") forState:UIControlStateNormal];
    _cancelBtn.titleLabel.font = [UIFont systemFontOfSize:15.0f];
    [_cancelBtn setTitleColor:([WKApp shared].config.tipColor ?: [UIColor grayColor]) forState:UIControlStateNormal];
    _cancelBtn.backgroundColor = [UIColor colorWithRed:241/255.0f green:241/255.0f blue:243/255.0f alpha:1.0f];
    _cancelBtn.layer.cornerRadius = 8.0f;
    [_cancelBtn addTarget:self action:@selector(onCancelPressed) forControlEvents:UIControlEventTouchUpInside];
    [_cardView addSubview:_cancelBtn];

    // 「切换过去」— 紫色 #722ED1（对齐 EP5 三端统一）
    _switchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_switchBtn setTitle:LLang(@"切换过去") forState:UIControlStateNormal];
    _switchBtn.titleLabel.font = [UIFont systemFontOfSize:15.0f weight:UIFontWeightMedium];
    [_switchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    // #722ED1 = rgb(114, 46, 209) — 对齐 WKConversationListCell 外部群紫色 Tag
    _switchBtn.backgroundColor = [UIColor colorWithRed:114/255.0f green:46/255.0f blue:209/255.0f alpha:1.0f];
    _switchBtn.layer.cornerRadius = 8.0f;
    [_switchBtn addTarget:self action:@selector(onSwitchPressed) forControlEvents:UIControlEventTouchUpInside];
    [_cardView addSubview:_switchBtn];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    _backdrop.frame = self.bounds;

    // 卡片尺寸 —— 居中、左右各留 40pt
    CGFloat cardWidth = MIN(340.0f, self.bounds.size.width - 80.0f);
    CGFloat paddingH = 20.0f;
    CGFloat paddingV = 24.0f;
    CGFloat btnHeight = 44.0f;
    CGFloat btnSpacing = 12.0f;

    // 文本高度 —— 固定按两行估算避免频繁 sizeToFit 抖动
    CGFloat line1Height = 24.0f;
    CGFloat line2Height = 20.0f;
    CGFloat cardHeight = paddingV + line1Height + 8.0f + line2Height + paddingV + btnHeight + paddingV;

    _cardView.frame = CGRectMake((self.bounds.size.width - cardWidth)/2.0f,
                                 (self.bounds.size.height - cardHeight)/2.0f,
                                 cardWidth, cardHeight);

    CGFloat y = paddingV;
    _line1Lbl.frame = CGRectMake(paddingH, y, cardWidth - paddingH*2, line1Height);
    y += line1Height + 8.0f;
    _line2Lbl.frame = CGRectMake(paddingH, y, cardWidth - paddingH*2, line2Height);
    y += line2Height + paddingV;

    CGFloat btnWidth = (cardWidth - paddingH*2 - btnSpacing) / 2.0f;
    _cancelBtn.frame = CGRectMake(paddingH, y, btnWidth, btnHeight);
    _switchBtn.frame = CGRectMake(paddingH + btnWidth + btnSpacing, y, btnWidth, btnHeight);
}

#pragma mark - Actions

- (void)onBackdropTapped {
    [self dismissAnimated:YES];
    if (self.onCancelTapped) { self.onCancelTapped(); }
}

- (void)onCancelPressed {
    [self dismissAnimated:YES];
    if (self.onCancelTapped) { self.onCancelTapped(); }
}

- (void)onSwitchPressed {
    // 注意先 fire 回调再 dismiss；回调里可能 push 新 VC，不与动画冲突。
    if (self.onSwitchTapped) { self.onSwitchTapped(); }
    [self dismissAnimated:YES];
}

- (void)dismissAnimated:(BOOL)animated {
    if (!animated) {
        [self removeFromSuperview];
        return;
    }
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end
