// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRichTextCaptionViewController.m
//  WuKongBase
//

#import "WKRichTextCaptionViewController.h"
#import "WuKongBase.h"

// 主题色 #7761F4（与相册选择器一致）。
static UIColor *WKCaptionThemeColor(void) {
    return [UIColor colorWithRed:119.0f/255.0f green:97.0f/255.0f blue:244.0f/255.0f alpha:1.0];
}

@interface WKRichTextCaptionViewController () <UITextViewDelegate>
@property(nonatomic, copy) NSArray<NSData *> *imageDatas;
@property(nonatomic, copy) NSString *initialCaption;
@property(nonatomic, strong) UIView *topBar;
@property(nonatomic, strong) UIScrollView *thumbScroll;
@property(nonatomic, strong) UITextView *captionView;
@property(nonatomic, strong) UILabel *placeholderLabel;
@property(nonatomic, strong) NSLayoutConstraint *bottomBarConstraint;
// 终态守卫：onSend / onCancel 只能触发一次（dismiss 动画期间防重入）。
@property(nonatomic, assign) BOOL settled;
@end

@implementation WKRichTextCaptionViewController

- (instancetype)initWithImageDatas:(NSArray<NSData *> *)imageDatas
                    initialCaption:(NSString *)initialCaption {
    if (self = [super init]) {
        _imageDatas = [imageDatas copy] ?: @[];
        _initialCaption = [initialCaption copy];
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:1.0];
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    }
    [self buildTopBar];
    [self buildThumbnails];
    [self buildCaptionBar];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChange:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI

- (void)buildTopBar {
    UIView *bar = [UIView new];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:bar];

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    cancel.translatesAutoresizingMaskIntoConstraints = NO;
    [cancel setTitle:LLang(@"取消") forState:UIControlStateNormal];
    [cancel setTitleColor:WKCaptionThemeColor() forState:UIControlStateNormal];
    cancel.titleLabel.font = [UIFont systemFontOfSize:16];
    [cancel addTarget:self action:@selector(onCancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:cancel];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = LLang(@"添加描述");
    title.font = [UIFont boldSystemFontOfSize:17];
    title.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) { title.textColor = [UIColor labelColor]; }
    else { title.textColor = [UIColor blackColor]; }
    [bar addSubview:title];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bar.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [bar.heightAnchor constraintEqualToConstant:48],

        [cancel.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:16],
        [cancel.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],

        [title.centerXAnchor constraintEqualToAnchor:bar.centerXAnchor],
        [title.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
    ]];
    self.topBar = bar;
}

- (void)buildThumbnails {
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsHorizontalScrollIndicator = NO;
    [self.view addSubview:scroll];
    self.thumbScroll = scroll;

    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.topBar.bottomAnchor constant:12],
        [scroll.heightAnchor constraintEqualToConstant:160],
    ]];

    CGFloat side = 140, gap = 8, x = 16;
    for (NSData *data in self.imageDatas) {
        UIImage *img = [UIImage imageWithData:data];
        UIImageView *iv = [[UIImageView alloc] initWithImage:img];
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.layer.cornerRadius = 8;
        iv.frame = CGRectMake(x, 10, side, side);
        [scroll addSubview:iv];
        x += side + gap;
    }
    scroll.contentSize = CGSizeMake(x - gap + 16, 160);
}

- (void)buildCaptionBar {
    UIView *bar = [UIView new];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) { bar.backgroundColor = [UIColor secondarySystemBackgroundColor]; }
    else { bar.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0]; }
    [self.view addSubview:bar];

    UITextView *tv = [UITextView new];
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    tv.font = [UIFont systemFontOfSize:16];
    tv.backgroundColor = [UIColor clearColor];
    tv.delegate = self;
    tv.text = self.initialCaption ?: @"";
    tv.scrollEnabled = YES;
    [bar addSubview:tv];
    self.captionView = tv;

    UILabel *ph = [UILabel new];
    ph.translatesAutoresizingMaskIntoConstraints = NO;
    ph.text = LLang(@"说点什么…");
    ph.font = [UIFont systemFontOfSize:16];
    ph.textColor = [UIColor lightGrayColor];
    ph.hidden = tv.text.length > 0;
    [bar addSubview:ph];
    self.placeholderLabel = ph;

    UIButton *send = [UIButton buttonWithType:UIButtonTypeSystem];
    send.translatesAutoresizingMaskIntoConstraints = NO;
    [send setTitle:LLang(@"发送") forState:UIControlStateNormal];
    [send setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    send.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    send.backgroundColor = WKCaptionThemeColor();
    send.layer.cornerRadius = 18;
    send.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
    [send addTarget:self action:@selector(onSendTapped) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:send];

    self.bottomBarConstraint = [bar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.bottomBarConstraint,
        [bar.heightAnchor constraintEqualToConstant:56],

        [send.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-12],
        [send.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [send.heightAnchor constraintEqualToConstant:36],

        [tv.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:12],
        [tv.trailingAnchor constraintEqualToAnchor:send.leadingAnchor constant:-12],
        [tv.topAnchor constraintEqualToAnchor:bar.topAnchor constant:10],
        [tv.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-10],

        [ph.leadingAnchor constraintEqualToAnchor:tv.leadingAnchor constant:5],
        [ph.centerYAnchor constraintEqualToAnchor:tv.centerYAnchor],
    ]];
}

#pragma mark - Keyboard

- (void)keyboardWillChange:(NSNotification *)note {
    CGRect end = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGFloat overlap = CGRectGetHeight(self.view.bounds) - CGRectGetMinY([self.view convertRect:end fromView:nil]);
    CGFloat safeBottom = self.view.safeAreaInsets.bottom;
    // 键盘弹起时把输入栏顶到键盘上沿；收起时回到安全区底部。
    self.bottomBarConstraint.constant = overlap > 0 ? -(overlap - safeBottom) : 0;
    [UIView animateWithDuration:MAX(duration, 0.1) animations:^{
        [self.view layoutIfNeeded];
    }];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    self.placeholderLabel.hidden = textView.text.length > 0;
}

#pragma mark - Actions

- (NSString *)trimmedCaption {
    NSString *raw = self.captionView.text ?: @"";
    return [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)onSendTapped {
    if (self.settled) return;
    self.settled = YES;
    NSString *caption = [self trimmedCaption];
    [self.view endEditing:YES];
    // 把回调拷进局部强引用：dismiss completion 在 VC 被释放后才跑也能稳定触发（避免漏发）。
    void (^cb)(NSString *) = self.onSend;
    [self dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(caption);
    }];
}

- (void)onCancelTapped {
    if (self.settled) return;
    self.settled = YES;
    [self.view endEditing:YES];
    void (^cb)(void) = self.onCancel;
    [self dismissViewControllerAnimated:YES completion:^{
        if (cb) cb();
    }];
}

@end
