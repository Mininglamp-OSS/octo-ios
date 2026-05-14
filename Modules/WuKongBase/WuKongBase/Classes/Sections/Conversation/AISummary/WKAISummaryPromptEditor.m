//
//  WKAISummaryPromptEditor.m
//  WuKongBase
//

#import "WKAISummaryPromptEditor.h"
#import <objc/runtime.h>

#pragma mark - Color helpers

static UIColor *EdHex(uint32_t hex, CGFloat alpha) {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8)  & 0xFF) / 255.0
                            blue:( hex        & 0xFF) / 255.0
                           alpha:alpha];
}
static UIColor *EdCyan(void)    { return EdHex(0x00E0FF, 1.0); }
static UIColor *EdMagenta(void) { return EdHex(0xFF4DA1, 1.0); }
static UIColor *EdGlass(void)   { return EdHex(0x10142E, 0.94); }
static UIColor *EdInputBg(void) { return EdHex(0x1B214A, 0.85); }

#pragma mark - Owner

@interface _WKAISummaryEditorOwner : NSObject <UITextViewDelegate, UIGestureRecognizerDelegate>
@property(nonatomic, strong) UIView *backdrop;
@property(nonatomic, strong) UIView *panel;
@property(nonatomic, strong) UITextView *textView;
@property(nonatomic, strong) UILabel *placeholderLbl;
@property(nonatomic, strong) NSLayoutConstraint *panelCenterY; // 键盘避让
@property(nonatomic, weak) UIView *anchorView;
@property(nonatomic, copy) void (^onSave)(NSString *);
@end

@implementation _WKAISummaryEditorOwner

- (void)presentInWindow:(UIWindow *)win
                 anchor:(UIView *)anchor
              prefixHint:(NSString *)prefixHint
             initialText:(NSString *)initialText {
    self.anchorView = anchor;

    // ---- backdrop（捕获外部 tap 收键盘）----
    self.backdrop = [[UIView alloc] initWithFrame:win.bounds];
    self.backdrop.backgroundColor = EdHex(0x000000, 0.0);
    self.backdrop.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(onBackdropTap)];
    tap.cancelsTouchesInView = NO;       // 不抢子视图（textView / 按钮）的 touch
    tap.delegate = self;                 // delegate 里只允许 panel 外的 tap
    [self.backdrop addGestureRecognizer:tap];
    [win addSubview:self.backdrop];

    // ---- panel ----
    self.panel = [[UIView alloc] init];
    self.panel.backgroundColor = EdGlass();
    self.panel.layer.cornerRadius = 16;
    self.panel.layer.borderColor  = EdCyan().CGColor;
    self.panel.layer.borderWidth  = 1.0;
    self.panel.layer.shadowColor  = EdHex(0x9D5CFF, 1.0).CGColor;
    self.panel.layer.shadowRadius = 22;
    self.panel.layer.shadowOpacity = 0.65;
    self.panel.layer.shadowOffset  = CGSizeMake(0, 6);
    self.panel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.backdrop addSubview:self.panel];

    // ---- 标题（带渐变）----
    UILabel *title = [[UILabel alloc] init];
    title.text = @"编辑提示词";
    title.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel addSubview:title];
    [self attachGradientToLabel:title];

    // ---- 副标题：固定前缀提示 ----
    UILabel *hint = [[UILabel alloc] init];
    hint.text = prefixHint ?: @"";
    hint.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
    hint.textColor = EdHex(0x9AA0C8, 1.0);
    hint.numberOfLines = 0;
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel addSubview:hint];

    // ---- 输入框容器 ----
    UIView *inputBox = [[UIView alloc] init];
    inputBox.backgroundColor = EdInputBg();
    inputBox.layer.cornerRadius = 10;
    inputBox.layer.borderColor = [EdCyan() colorWithAlphaComponent:0.55].CGColor;
    inputBox.layer.borderWidth = 1.0;
    inputBox.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel addSubview:inputBox];

    self.textView = [[UITextView alloc] init];
    self.textView.backgroundColor = UIColor.clearColor;
    self.textView.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    self.textView.textColor = UIColor.whiteColor;
    self.textView.tintColor = EdCyan();
    self.textView.text = initialText ?: @"";
    self.textView.delegate = self;
    self.textView.textContainerInset = UIEdgeInsetsMake(10, 8, 10, 8);
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.keyboardAppearance = UIKeyboardAppearanceDark;
    [inputBox addSubview:self.textView];

    self.placeholderLbl = [[UILabel alloc] init];
    self.placeholderLbl.text = @"比如：总结今天的工作进展，列出待办事项";
    self.placeholderLbl.font = self.textView.font;
    self.placeholderLbl.textColor = EdHex(0x6A6F8E, 1.0);
    self.placeholderLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [inputBox addSubview:self.placeholderLbl];
    [self refreshPlaceholder];

    // ---- 底部按钮 ----
    UIControl *cancelBtn = [self makeButtonTitled:@"取消" tinted:EdHex(0x9AA0C8, 1.0) action:@selector(onCancel)];
    UIControl *saveBtn   = [self makeButtonTitled:@"保存" tinted:EdCyan()             action:@selector(onSaveTap)];
    saveBtn.layer.borderColor = EdCyan().CGColor;
    saveBtn.layer.borderWidth = 1.0;
    saveBtn.backgroundColor = [EdCyan() colorWithAlphaComponent:0.10];
    saveBtn.layer.shadowColor = EdCyan().CGColor;
    saveBtn.layer.shadowRadius = 6;
    saveBtn.layer.shadowOpacity = 0.5;
    saveBtn.layer.shadowOffset = CGSizeZero;

    cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
    saveBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.panel addSubview:cancelBtn];
    [self.panel addSubview:saveBtn];

    // ---- 约束 ----
    self.panelCenterY = [self.panel.centerYAnchor constraintEqualToAnchor:self.backdrop.centerYAnchor];

    [NSLayoutConstraint activateConstraints:@[
        // panel
        [self.panel.widthAnchor    constraintEqualToConstant:300],
        [self.panel.centerXAnchor  constraintEqualToAnchor:self.backdrop.centerXAnchor],
        self.panelCenterY,

        // title —— 内边距加大，避开圆角
        [title.leadingAnchor       constraintEqualToAnchor:self.panel.leadingAnchor  constant:24],
        [title.trailingAnchor      constraintLessThanOrEqualToAnchor:self.panel.trailingAnchor constant:-24],
        [title.topAnchor           constraintEqualToAnchor:self.panel.topAnchor      constant:22],

        // hint
        [hint.leadingAnchor        constraintEqualToAnchor:self.panel.leadingAnchor  constant:24],
        [hint.trailingAnchor       constraintEqualToAnchor:self.panel.trailingAnchor constant:-24],
        [hint.topAnchor            constraintEqualToAnchor:title.bottomAnchor        constant:8],

        // input
        [inputBox.leadingAnchor    constraintEqualToAnchor:self.panel.leadingAnchor  constant:18],
        [inputBox.trailingAnchor   constraintEqualToAnchor:self.panel.trailingAnchor constant:-18],
        [inputBox.topAnchor        constraintEqualToAnchor:hint.bottomAnchor         constant:14],
        [inputBox.heightAnchor     constraintEqualToConstant:120],

        [self.textView.leadingAnchor   constraintEqualToAnchor:inputBox.leadingAnchor],
        [self.textView.trailingAnchor  constraintEqualToAnchor:inputBox.trailingAnchor],
        [self.textView.topAnchor       constraintEqualToAnchor:inputBox.topAnchor],
        [self.textView.bottomAnchor    constraintEqualToAnchor:inputBox.bottomAnchor],

        [self.placeholderLbl.leadingAnchor   constraintEqualToAnchor:inputBox.leadingAnchor  constant:13],
        [self.placeholderLbl.trailingAnchor  constraintEqualToAnchor:inputBox.trailingAnchor constant:-13],
        [self.placeholderLbl.topAnchor       constraintEqualToAnchor:inputBox.topAnchor      constant:11],

        // buttons
        [cancelBtn.leadingAnchor   constraintEqualToAnchor:self.panel.leadingAnchor  constant:14],
        [cancelBtn.bottomAnchor    constraintEqualToAnchor:self.panel.bottomAnchor   constant:-14],
        [cancelBtn.heightAnchor    constraintEqualToConstant:36],
        [cancelBtn.widthAnchor     constraintEqualToConstant:80],

        [saveBtn.trailingAnchor    constraintEqualToAnchor:self.panel.trailingAnchor constant:-14],
        [saveBtn.bottomAnchor      constraintEqualToAnchor:self.panel.bottomAnchor   constant:-14],
        [saveBtn.heightAnchor      constraintEqualToConstant:36],
        [saveBtn.widthAnchor       constraintEqualToConstant:80],

        [inputBox.bottomAnchor     constraintEqualToAnchor:saveBtn.topAnchor         constant:-14],
    ]];

    // 入场动画
    [self animateIn];

    // 键盘监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKbWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKbWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Animations

- (void)animateIn {
    self.backdrop.alpha = 1.0;
    self.panel.transform = CGAffineTransformMakeScale(0.85, 0.85);
    self.panel.alpha = 0;

    [UIView animateWithDuration:0.20 animations:^{
        self.backdrop.backgroundColor = EdHex(0x000000, 0.45);
    }];
    [UIView animateWithDuration:0.40 delay:0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.panel.transform = CGAffineTransformIdentity;
        self.panel.alpha = 1.0;
    } completion:nil];
}

- (void)dismissThenCallback:(NSString *)textOrNil {
    void (^cb)(NSString *) = self.onSave;
    self.onSave = nil;
    [self.textView resignFirstResponder];
    [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.backdrop.backgroundColor = EdHex(0x000000, 0.0);
        self.panel.alpha = 0;
        self.panel.transform = CGAffineTransformMakeScale(0.85, 0.85);
    } completion:^(BOOL finished) {
        [self.backdrop removeFromSuperview];
        self.backdrop = nil;
        self.panel = nil;
        if (cb) cb(textOrNil);
    }];
}

#pragma mark - 渐变标题（与 ActionMenu 同款）

- (void)attachGradientToLabel:(UILabel *)label {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!label.text.length) return;
        // 关键：强制让 label 的 frame 由约束 (constant:24/22) 解算到位
        // —— 不加这行的话 label.frame 还是 (0,0,0,0)，渐变会被贴到 panel 左上角
        // 而不是 24/22 的位置，看起来就像"标题贴边"。
        [label.superview layoutIfNeeded];

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
        CAGradientLayer *g = [CAGradientLayer layer];
        g.colors = @[(id)EdCyan().CGColor, (id)EdMagenta().CGColor];
        g.startPoint = CGPointMake(0.0, 0.5);
        g.endPoint   = CGPointMake(1.0, 0.5);
        g.mask = m;
        CGPoint origin = [label convertPoint:CGPointZero toView:label.superview];
        g.frame = CGRectMake(origin.x, origin.y, sz.width + 2, sz.height);
        [label.superview.layer insertSublayer:g above:label.layer];
        label.hidden = YES;
    });
}

#pragma mark - 键盘避让

- (void)onKbWillShow:(NSNotification *)n {
    CGFloat kbH = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
    NSTimeInterval dur = [n.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    self.panelCenterY.constant = -kbH * 0.45; // 上移 45% 键盘高度，留出操作空间
    [UIView animateWithDuration:dur animations:^{ [self.backdrop layoutIfNeeded]; }];
}

- (void)onKbWillHide:(NSNotification *)n {
    NSTimeInterval dur = [n.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    self.panelCenterY.constant = 0;
    [UIView animateWithDuration:dur animations:^{ [self.backdrop layoutIfNeeded]; }];
}

#pragma mark - Buttons

- (UIControl *)makeButtonTitled:(NSString *)t tinted:(UIColor *)tint action:(SEL)sel {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:tint forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    b.layer.cornerRadius = 10;
    b.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.04];
    [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)onCancel    { [self dismissThenCallback:nil]; }
- (void)onSaveTap   {
    NSString *t = self.textView.text ?: @"";
    [self dismissThenCallback:t]; // 由调用方决定空字符串是不是"删除"
}

- (void)onBackdropTap {
    if ([self.textView isFirstResponder]) {
        [self.textView resignFirstResponder];
    } else {
        [self onCancel];
    }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView { [self refreshPlaceholder]; }
- (void)refreshPlaceholder {
    self.placeholderLbl.hidden = self.textView.text.length > 0;
}

#pragma mark - Gesture delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldReceiveTouch:(UITouch *)touch {
    // 仅 panel 外的 tap 才走 backdrop 的关闭/收键盘逻辑；
    // panel 内的 tap（如点 Save / 在 TextView 中输入）保持给原 control。
    CGPoint p = [touch locationInView:self.panel];
    return ![self.panel pointInside:p withEvent:nil];
}

@end

#pragma mark -

@implementation WKAISummaryPromptEditor

+ (void)presentFromView:(UIView *)anchorView
              prefixHint:(NSString *)prefixHint
             initialText:(NSString *)initialText
                  onSave:(void (^)(NSString *))onSave {
    UIWindow *win = anchorView.window;
    if (!win) return;
    _WKAISummaryEditorOwner *o = [_WKAISummaryEditorOwner new];
    o.onSave = onSave;
    [o presentInWindow:win anchor:anchorView prefixHint:prefixHint initialText:initialText];
    objc_setAssociatedObject(o.backdrop, _cmd, o, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
