// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRichTextCaptionViewController.m
//  WuKongBase
//

#import "WKRichTextCaptionViewController.h"
#import "WKRichTextMentionPickerVC.h"
#import "WKInputMentionCache.h"
#import "WKPhotoBrowser.h"
#import "WKImageBrowser.h"
#import <YBImageBrowser/YBImageBrowser.h>
#import "WuKongBase.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

// 主题色 #7761F4（与相册选择器一致）。
static UIColor *WKCaptionThemeColor(void) {
    return [UIColor colorWithRed:119.0f/255.0f green:97.0f/255.0f blue:244.0f/255.0f alpha:1.0];
}

// 缩略图常量：3 列宫格，每格按容器宽度均分；保持 1:1 正方形（与微信选图预览一致）。
static const NSInteger kThumbCols = 3;
static const CGFloat kThumbGap  = 8.0f;
static const CGFloat kThumbPadX = 16.0f;
static const CGFloat kThumbPadY = 12.0f;
static const CGFloat kThumbDeleteSize = 22.0f; // × 按钮尺寸（与缩略图右上角重叠）

// 发送/选图硬上限——与微信对齐，「一次最多 9 张，总共最多 9 张」。后续如要放开，改这里 +
// 同步调整 sendRichTextMixedImageDatas:assetCount 校验即可。
static const NSInteger kRichTextMaxImages = 9;

// caption 输入框：font 16pt 系统字体；min=1 行；max=15 行 → 与外部 chat input 自动撑高的
// UX 一致（参考 WKGrowingTextView 同款节奏），超 15 行内部滚动而非继续撑高。
static const NSInteger kCaptionMaxLines = 15;
static const CGFloat   kCaptionFontSize = 16.0f;
static const CGFloat   kCaptionTextPadV = 10.0f; // captionView 上下内边距（与按钮垂直对齐基准）

@interface WKRichTextCaptionViewController () <UITextViewDelegate>
@property(nonatomic, strong) NSMutableArray<NSData *> *imageDatas;
@property(nonatomic, copy) NSString *initialCaption;
@property(nonatomic, strong) WKChannel *channel;
@property(nonatomic, strong) UIView *topBar;
@property(nonatomic, strong) UIScrollView *thumbScroll; // 3 列宫格 vertical scroll
@property(nonatomic, strong) UIView *captionBar;
@property(nonatomic, strong) UITextView *captionView;
@property(nonatomic, strong) UILabel *placeholderLabel;
@property(nonatomic, strong) NSLayoutConstraint *captionBarHeight;   // caption bar 总高（随文字行数撑）
@property(nonatomic, strong) NSLayoutConstraint *bottomBarConstraint; // caption bar bottom（键盘联动）
// 上一次 layout 时的宽度——viewDidLayoutSubviews 每次键盘升降 / caption bar 撑高都会触发，
// 但 cellW 只在屏幕宽度变化（旋转 / 初次 layout）时才需要重算。同宽就跳过重建，
// 避免在键盘弹/降、输入文字撑 bar 的所有 layout 路径上图片瓷砖 remove+add 闪一下。
@property(nonatomic, assign) CGFloat lastLaidOutWidth;
// 当前键盘高度（subtract safe area bottom），用于 captionBar 撑高时给图片区留最少 1 行的空间。
@property(nonatomic, assign) CGFloat currentKeyboardOverlap;
// @ 人选中累计列表（含 sentinel uid="all" / "__ais__"），onSend 时回传调用方。
@property(nonatomic, strong) NSMutableArray<WKInputMentionItem *> *mentions;
// 终态守卫：onSend / onCancel 只能触发一次（dismiss 动画期间防重入）。
@property(nonatomic, assign) BOOL settled;
// 防止「点 @ 按钮 / textView 检测到 @ 输入」双触发 picker。
@property(nonatomic, assign) BOOL pickerPresenting;
@end

@implementation WKRichTextCaptionViewController

- (instancetype)initWithImageDatas:(NSArray<NSData *> *)imageDatas
                    initialCaption:(NSString *)initialCaption
                           channel:(WKChannel *)channel {
    if (self = [super init]) {
        _imageDatas = [NSMutableArray arrayWithArray:imageDatas ?: @[]];
        _initialCaption = [initialCaption copy];
        _channel = channel;
        _mentions = [NSMutableArray array];
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
    // 注意顺序：buildCaptionBar 必须先建——buildThumbnails 的 grid scroll 把 bottom anchor 到
    // captionBar.top，依赖 captionBar 实例已经存在；反过来 captionBar.top 不依赖 grid scroll。
    [self buildCaptionBar];
    [self buildThumbnails];
    [self rebuildThumbnails];
    [self updateCaptionBarHeightAnimated:NO];

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
    scroll.showsVerticalScrollIndicator = YES;
    scroll.alwaysBounceVertical = NO;
    // 点缩略图空白区收键盘——cancelsTouchesInView=NO 不抢 imageView 上的 tap（onThumbnailTapped:）
    // 和 × 按钮的 touch，只在「点在 scroll 背景空白处」时触发 endEditing。
    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBackgroundTapped)];
    bgTap.cancelsTouchesInView = NO;
    [scroll addGestureRecognizer:bgTap];
    [self.view addSubview:scroll];
    self.thumbScroll = scroll;

    // 占满 topBar 与 captionBar 之间的纵向空间——captionBar 撑大时（输入文字行数变多），
    // grid scroll 区可视区会收缩，内部内容自动滚动；这样 9 张图 + 15 行文字也不会互相挤死。
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.topBar.bottomAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.captionBar.topAnchor],
    ]];
}

- (void)rebuildThumbnails {
    // 清空旧子视图（删图 / 加图 / 初始化共用）。
    for (UIView *v in [self.thumbScroll.subviews copy]) {
        [v removeFromSuperview];
    }

    BOOL canAddMore = self.imageDatas.count < kRichTextMaxImages;
    NSInteger totalTiles = (NSInteger)self.imageDatas.count + (canAddMore ? 1 : 0);
    if (totalTiles == 0) {
        // 防御：不会出现（canAddMore 在 9 张以内永远 true）。
        self.thumbScroll.contentSize = CGSizeZero;
        return;
    }

    // cell 边长按容器宽度均分。view 还没 layout 时（首次调用）bounds 为 0，退化到屏宽兜底。
    CGFloat containerW = self.view.bounds.size.width;
    if (containerW <= 0) containerW = [UIScreen mainScreen].bounds.size.width;
    CGFloat cellW = floor((containerW - kThumbPadX * 2 - kThumbGap * (kThumbCols - 1)) / kThumbCols);
    if (cellW < 60) cellW = 60; // 极窄屏兜底
    CGFloat cellH = cellW;

    for (NSInteger i = 0; i < (NSInteger)self.imageDatas.count; i++) {
        NSData *data = self.imageDatas[i];
        UIImage *img = [UIImage imageWithData:data];

        CGRect frame = [self _wkRichGridFrameAtIndex:i cellW:cellW cellH:cellH];
        UIImageView *iv = [[UIImageView alloc] initWithImage:img];
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.layer.cornerRadius = 8;
        iv.frame = frame;
        // 点缩略图弹大图预览：YBImageBrowser 自带左右滑切图 / 双指缩放 / 下拉收 ——
        // 与聊天 cell 已用方案 (WKImageMessageCell) 同一套，避免引第二套预览组件。
        iv.userInteractionEnabled = YES;
        iv.tag = i;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onThumbnailTapped:)];
        [iv addGestureRecognizer:tap];
        [self.thumbScroll addSubview:iv];

        UIButton *del = [UIButton buttonWithType:UIButtonTypeSystem];
        del.tag = i;
        del.frame = CGRectMake(CGRectGetMaxX(frame) - kThumbDeleteSize - 4,
                               CGRectGetMinY(frame) + 4,
                               kThumbDeleteSize, kThumbDeleteSize);
        del.layer.cornerRadius = kThumbDeleteSize / 2.0f;
        del.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
        del.tintColor = [UIColor whiteColor];
        if (@available(iOS 13.0, *)) {
            UIImage *icon = [UIImage systemImageNamed:@"xmark"];
            [del setImage:icon forState:UIControlStateNormal];
            [del setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightBold]
                                forImageInState:UIControlStateNormal];
        } else {
            [del setTitle:@"×" forState:UIControlStateNormal];
            [del setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            del.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        }
        [del addTarget:self action:@selector(onDeleteImage:) forControlEvents:UIControlEventTouchUpInside];
        [self.thumbScroll addSubview:del];
    }

    if (canAddMore) {
        // + 瓷砖：紧跟最后一张图后面（grid 下一格），未到 9 张时显示。
        // 删图删到 0 张也能从这里重新加；不需要退回去重新走相册入口。
        CGRect frame = [self _wkRichGridFrameAtIndex:self.imageDatas.count cellW:cellW cellH:cellH];
        UIButton *add = [UIButton buttonWithType:UIButtonTypeCustom];
        add.frame = frame;
        add.layer.cornerRadius = 8;
        add.layer.borderWidth = 1.0f;
        add.layer.borderColor = [UIColor colorWithWhite:0.78 alpha:1.0].CGColor;
        if (@available(iOS 13.0, *)) {
            add.backgroundColor = [UIColor tertiarySystemBackgroundColor];
        } else {
            add.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
        }
        [add setTitle:@"+" forState:UIControlStateNormal];
        [add setTitleColor:[UIColor colorWithWhite:0.55 alpha:1.0] forState:UIControlStateNormal];
        add.titleLabel.font = [UIFont systemFontOfSize:48 weight:UIFontWeightLight];
        // 把「+」往上挪一点视觉居中（UIButton system font baseline 偏低）。
        add.titleEdgeInsets = UIEdgeInsetsMake(-6, 0, 0, 0);
        [add addTarget:self action:@selector(onAddImageTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.thumbScroll addSubview:add];
    }

    NSInteger rows = (totalTiles + kThumbCols - 1) / kThumbCols;
    CGFloat contentH = kThumbPadY + rows * cellH + (rows - 1) * kThumbGap + kThumbPadY;
    self.thumbScroll.contentSize = CGSizeMake(containerW, contentH);
}

// 计算第 index 个格子在 thumbScroll 内容坐标的 frame（3 列宫格，行高 = cellH）。
- (CGRect)_wkRichGridFrameAtIndex:(NSInteger)index cellW:(CGFloat)cellW cellH:(CGFloat)cellH {
    NSInteger col = index % kThumbCols;
    NSInteger row = index / kThumbCols;
    CGFloat x = kThumbPadX + col * (cellW + kThumbGap);
    CGFloat y = kThumbPadY + row * (cellH + kThumbGap);
    return CGRectMake(x, y, cellW, cellH);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    if (w <= 0) return;
    // 同宽（键盘弹/降 / caption bar 撑高都不改 view 宽度）跳过重建——只在初次 layout
    // 或屏幕旋转时重算 cell 尺寸 + 重排瓷砖，避免每次 layout 都 remove+add 闪图片。
    if (fabs(w - self.lastLaidOutWidth) < 0.5) return;
    self.lastLaidOutWidth = w;
    [self rebuildThumbnails];
}

#pragma mark - 加图 (拍照 / 相册)

- (void)onAddImageTapped {
    [self.view endEditing:YES];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil
                                                                    message:nil
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"拍照")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *_) {
        [weakSelf presentCameraToAddImage];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"从相册选择")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *_) {
        [weakSelf presentAlbumToAddImage];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)presentCameraToAddImage {
    if (self.imageDatas.count >= kRichTextMaxImages) return;
    __weak typeof(self) weakSelf = self;
    [[WKPhotoBrowser shared] takePhoto:self doneBlock:^(UIImage *img, NSURL *url) {
        typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !img) return;
        // 拍照 0.8 质量 JPEG——与相册路径压缩参数对齐，避免某些场景一张原图几十 MB 拖垮发送。
        NSData *data = UIImageJPEGRepresentation(img, 0.8);
        if (data.length == 0) return;
        [strongSelf appendNewImageDatas:@[data]];
    } cancelBlock:nil];
}

- (void)presentAlbumToAddImage {
    NSInteger remaining = kRichTextMaxImages - (NSInteger)self.imageDatas.count;
    if (remaining <= 0) return;
    __weak typeof(self) weakSelf = self;
    [[WKPhotoBrowser shared] showPhotoLibraryWithSender:self
                              selectCompressImageBlock:^(NSArray<NSData *> * _Nonnull images,
                                                          NSArray<PHAsset *> * _Nonnull assets,
                                                          BOOL isOriginal) {
        typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || images.count == 0) return;
        // 即便 picker 已限上限，这里再 clamp 一次防御：万一图源出现非图 asset 导致 datas/assets
        // 数量不一致，硬截到剩余配额内。
        NSInteger take = MIN((NSInteger)images.count, remaining);
        if (take <= 0) return;
        NSArray<NSData *> *slice = [images subarrayWithRange:NSMakeRange(0, take)];
        [strongSelf appendNewImageDatas:slice];
    } maxSelectCount:remaining allowSelectVideo:NO];
}

- (void)appendNewImageDatas:(NSArray<NSData *> *)datas {
    if (datas.count == 0) return;
    [self.imageDatas addObjectsFromArray:datas];
    [self rebuildThumbnails];
    // 滚到最底，让用户看到刚加的图（+ 号停在新图下方/右下，体感连贯）。
    CGFloat targetY = MAX(0, self.thumbScroll.contentSize.height - self.thumbScroll.bounds.size.height);
    [self.thumbScroll setContentOffset:CGPointMake(0, targetY) animated:YES];
}

- (void)buildCaptionBar {
    UIView *bar = [UIView new];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) { bar.backgroundColor = [UIColor secondarySystemBackgroundColor]; }
    else { bar.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0]; }
    [self.view addSubview:bar];
    self.captionBar = bar;

    // @ 按钮（不依赖键盘输入 '@' 检测，DM 也能通过按钮 @AI）。
    UIButton *at = [UIButton buttonWithType:UIButtonTypeSystem];
    at.translatesAutoresizingMaskIntoConstraints = NO;
    [at setTitle:@"@" forState:UIControlStateNormal];
    [at setTitleColor:WKCaptionThemeColor() forState:UIControlStateNormal];
    at.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [at addTarget:self action:@selector(onAtTapped) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:at];

    UITextView *tv = [UITextView new];
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    tv.font = [UIFont systemFontOfSize:kCaptionFontSize];
    tv.backgroundColor = [UIColor clearColor];
    tv.delegate = self;
    tv.text = self.initialCaption ?: @"";
    // scrollEnabled 默认关：单行→未到上限的高度都让 textView 自己撑高（sizeThatFits 路径），
    // 到 15 行上限再切回 scrollEnabled=YES 让内部滚（updateCaptionBarHeightAnimated 里 toggle）。
    tv.scrollEnabled = NO;
    tv.textContainerInset = UIEdgeInsetsMake(6, 0, 6, 0);
    tv.textContainer.lineFragmentPadding = 0;
    [bar addSubview:tv];
    self.captionView = tv;

    UILabel *ph = [UILabel new];
    ph.translatesAutoresizingMaskIntoConstraints = NO;
    ph.text = LLang(@"说点什么…");
    ph.font = [UIFont systemFontOfSize:kCaptionFontSize];
    ph.textColor = [UIColor lightGrayColor];
    ph.hidden = tv.text.length > 0;
    [bar addSubview:ph];
    self.placeholderLabel = ph;

    UIButton *send = [UIButton buttonWithType:UIButtonTypeSystem];
    send.translatesAutoresizingMaskIntoConstraints = NO;
    NSString *sendTitle = LLang(@"发送");
    [send setTitle:sendTitle forState:UIControlStateNormal];
    [send setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    UIFont *sendFont = [UIFont boldSystemFontOfSize:16];
    send.titleLabel.font = sendFont;
    send.backgroundColor = WKCaptionThemeColor();
    send.layer.cornerRadius = 18;
    send.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
    [send addTarget:self action:@selector(onSendTapped) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:send];
    // 固定宽度 = 本地化"发送"文本宽 + 两侧 16pt padding（与 contentEdgeInsets 对齐）。
    // 不固定时，captionView 输入变长会通过 horizontal hugging/compression priority 把 send 压缩成
    // 0 宽看不见——本质是 send 没声明 intrinsicContentSize 优先权高于 textView。直接钉死宽度，
    // 不让 auto-layout 来回拉锯。中/英/其它语言宽度都按当前 LLang 文本算，长字也撑得开。
    CGFloat sendTextW = ceil([sendTitle sizeWithAttributes:@{NSFontAttributeName: sendFont}].width);
    CGFloat sendBtnW = sendTextW + 16 * 2;

    self.bottomBarConstraint = [bar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor];
    self.captionBarHeight = [bar.heightAnchor constraintEqualToConstant:[self minCaptionBarHeight]];
    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.bottomBarConstraint,
        self.captionBarHeight,

        // @ 按钮、发送按钮都钉在底部（与单行 textView 视觉对齐）；textView 多行撑高时
        // 这两个按钮就停留在最底一行，不跟着上移——与外部聊天输入框的体验对齐。
        [at.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:8],
        [at.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-10],
        [at.widthAnchor constraintEqualToConstant:32],
        [at.heightAnchor constraintEqualToConstant:36],

        [send.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-12],
        [send.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-10],
        [send.heightAnchor constraintEqualToConstant:36],
        [send.widthAnchor constraintEqualToConstant:sendBtnW],

        [tv.leadingAnchor constraintEqualToAnchor:at.trailingAnchor constant:4],
        [tv.trailingAnchor constraintEqualToAnchor:send.leadingAnchor constant:-12],
        [tv.topAnchor constraintEqualToAnchor:bar.topAnchor constant:kCaptionTextPadV],
        [tv.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-kCaptionTextPadV],

        [ph.leadingAnchor constraintEqualToAnchor:tv.leadingAnchor constant:5],
        [ph.centerYAnchor constraintEqualToAnchor:tv.centerYAnchor],
    ]];
}

#pragma mark - Caption 自动撑高（最高 15 行）
// 与外部 WKConversationInputPanel.WKGrowingTextView 同款节奏：scrollEnabled=NO 时 UITextView
// 的 intrinsic content size 跟着内容长，配合 height 约束实时更新就能拿到「行数变多 bar 撑高」
// 的效果。到 15 行封顶后切 scrollEnabled=YES，内部滚不再继续撑。

- (CGFloat)singleLineTextHeight {
    UIFont *f = [UIFont systemFontOfSize:kCaptionFontSize];
    // ceil 防 sub-pixel 把单行算成 0.5 行（视觉空挡）。
    return ceil(f.lineHeight);
}

- (CGFloat)maxTextHeight {
    return [self singleLineTextHeight] * kCaptionMaxLines;
}

- (CGFloat)minCaptionBarHeight {
    // 单行高度 + textView 内边距 + bar 上下边距。
    UITextView *probe = [UITextView new];
    CGFloat inset = probe ? 0 : 0; // 用我们自己设的 textContainerInset 6+6=12
    (void)inset;
    return [self singleLineTextHeight] + 12.0f + kCaptionTextPadV * 2;
}

- (void)updateCaptionBarHeightAnimated:(BOOL)animated {
    if (!self.captionView || !self.captionBarHeight) return;
    // 用 sizeThatFits 拿目标内容高度，再 clamp 到 [singleLine, max]。scrollEnabled=NO
    // 时 sizeThatFits 才反映完整内容高度，所以测量前先临时关掉（如果已经被切到 YES）。
    BOOL wasScrollEnabled = self.captionView.scrollEnabled;
    if (wasScrollEnabled) self.captionView.scrollEnabled = NO;
    CGFloat width = self.captionView.bounds.size.width;
    if (width <= 0) {
        // 还没 layout：用估算宽度（屏宽 - @按钮 - 发送按钮 - 边距），不至于第一次进入计算失真。
        CGFloat est = [UIScreen mainScreen].bounds.size.width - 8 - 32 - 4 - 12 - 36 - 12 - 16;
        width = MAX(est, 100);
    }
    CGSize fit = [self.captionView sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    CGFloat singleLine = [self singleLineTextHeight];
    CGFloat textInset = self.captionView.textContainerInset.top + self.captionView.textContainerInset.bottom; // 12
    CGFloat textH = MAX(fit.height, singleLine + textInset);
    CGFloat maxH = [self maxTextHeight] + textInset;

    // 键盘弹起 → 可视高度变小，captionBar 不能撑满到 15 行（否则图片区被压成 0 高度，
    // 用户连一张图都看不到）。动态算「不挤死图片区」的 captionBar 上限：
    //   availableBelowTop = view.height - safeTop - topBar - keyboard
    //   reserveForGrid    = 1 cellH + 2*padY（保证至少 1 行缩略图可见，配合 scroll 可上下翻）
    //   captionBarCapByLayout = availableBelowTop - reserveForGrid - safeBottom(键盘没盖到时)
    // 收键盘后 keyboard=0，约束自动恢复到 15 行上限，与之前行为一致。
    CGFloat viewH = self.view.bounds.size.height;
    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGFloat safeBottom = self.view.safeAreaInsets.bottom;
    CGFloat topBarH = 48; // 与 buildTopBar 常量保持一致
    CGFloat kbOverlap = self.currentKeyboardOverlap;
    CGFloat bottomInset = (kbOverlap > 0 ? kbOverlap : safeBottom); // 键盘起时 bar 顶到键盘上沿，键盘没起时顶到 safe bottom
    // 1 行最少留给 grid 的高度：1 个 cell + 上下 padding（cellW 用屏宽估算够稳）。
    CGFloat estContainerW = self.view.bounds.size.width > 0 ? self.view.bounds.size.width : [UIScreen mainScreen].bounds.size.width;
    CGFloat estCellH = floor((estContainerW - kThumbPadX * 2 - kThumbGap * (kThumbCols - 1)) / kThumbCols);
    CGFloat reserveForGrid = estCellH + kThumbPadY * 2;
    CGFloat captionCap = viewH - safeTop - topBarH - bottomInset - reserveForGrid;
    if (captionCap < singleLine + textInset + kCaptionTextPadV * 2) {
        // 极端窄屏 / 横屏键盘时给个下限，至少保证 1 行可输入。
        captionCap = singleLine + textInset + kCaptionTextPadV * 2;
    }
    CGFloat maxBarH = MIN(maxH + kCaptionTextPadV * 2, captionCap);

    BOOL needScroll = (textH + kCaptionTextPadV * 2) > maxBarH;
    CGFloat newBarH = needScroll ? maxBarH : (textH + kCaptionTextPadV * 2);

    self.captionView.scrollEnabled = needScroll;
    if (fabs(self.captionBarHeight.constant - newBarH) < 0.5) return;
    self.captionBarHeight.constant = newBarH;
    if (animated) {
        [UIView animateWithDuration:0.18 animations:^{
            [self.view layoutIfNeeded];
        }];
    } else {
        [self.view layoutIfNeeded];
    }
}

#pragma mark - Keyboard

- (void)keyboardWillChange:(NSNotification *)note {
    CGRect end = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGFloat overlap = CGRectGetHeight(self.view.bounds) - CGRectGetMinY([self.view convertRect:end fromView:nil]);
    CGFloat safeBottom = self.view.safeAreaInsets.bottom;
    self.currentKeyboardOverlap = overlap > 0 ? overlap : 0;
    // 键盘弹起时把输入栏顶到键盘上沿；收起时回到安全区底部。
    self.bottomBarConstraint.constant = overlap > 0 ? -(overlap - safeBottom) : 0;
    // 键盘弹起时可视高度变小，captionBar 最大可撑高度也要相应收紧——给图片区至少留 1 行。
    // 更新 caption bar 高度（也会动态调整 scrollEnabled），与键盘动画同步。
    [self updateCaptionBarHeightAnimated:NO];
    [UIView animateWithDuration:MAX(duration, 0.1) animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)onBackgroundTapped {
    // 键盘弹起态下点 grid 空白处（不在 imageView / + 瓷砖上）收键盘。
    if (self.captionView.isFirstResponder) {
        [self.view endEditing:YES];
    }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    self.placeholderLabel.hidden = textView.text.length > 0;
    [self updateCaptionBarHeightAnimated:YES];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    // 键盘输入 '@' 触发 picker（与主聊天输入框 WKConversationInputPanel.isMention: 行为对齐）。
    // 用「插入 + 立刻弹」而不是「拦截」：picker 取消时输入框里的 '@' 留着不动，符合直觉；
    // 选中时由 picker 回调自己再补 "<name> "。
    if ([text isEqualToString:@"@"]) {
        // 让 '@' 字符先插入，再异步弹 picker（避免布局/键盘竞态）。
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentMentionPickerWithKeyword:@""];
        });
        return YES;
    }
    // 反向删除已插入的 @mention 名（连同   一起删）。
    if ([text isEqualToString:@""] && range.length == 1) {
        // helper 把整段 mention 替换掉时返回 YES, 此时必须 return NO 让 UIKit 跳过
        // 它本次单字符删除——否则会在已被改写的文本上再执行一次原 range 删除, 多删一字.
        if ([self maybeRemoveMentionAtCursor:textView range:range]) {
            return NO;
        }
    }
    return YES;
}

#pragma mark - @ Mention

- (void)onAtTapped {
    // 通过按钮入口时把 '@' 也补进文字，picker 取消后用户也能直接打字（与 textView 路径一致）。
    NSRange sel = self.captionView.selectedRange;
    NSMutableString *txt = [self.captionView.text mutableCopy] ?: [NSMutableString string];
    [txt insertString:@"@" atIndex:sel.location];
    self.captionView.text = txt;
    self.captionView.selectedRange = NSMakeRange(sel.location + 1, 0);
    [self textViewDidChange:self.captionView];
    [self presentMentionPickerWithKeyword:@""];
}

- (void)presentMentionPickerWithKeyword:(NSString *)keyword {
    if (self.pickerPresenting) return;
    self.pickerPresenting = YES;

    __weak typeof(self) weakSelf = self;
    WKRichTextMentionPickerVC *picker = [[WKRichTextMentionPickerVC alloc] initWithChannel:self.channel
                                                                                   keyword:keyword];
    picker.onSelect = ^(WKMentionUserCellModel * _Nullable model) {
        typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.pickerPresenting = NO;
        if (!model) return; // 取消
        [strongSelf insertMentionForModel:model];
    };
    [self presentViewController:picker animated:YES completion:nil];
}

// 选中成员后：把光标前最近一个未结束的 '@' 替换成 "@<name> "，累积 WKInputMentionItem
// 进 mentions（含 sentinel uid）。沿用主聊天 WKInputAtEndChar=  约定，server 端按
// 同样字符识别 mention 边界。
- (void)insertMentionForModel:(WKMentionUserCellModel *)model {
    NSString *text = self.captionView.text ?: @"";
    NSRange sel = self.captionView.selectedRange;

    // 向前找最近的 '@'（光标位置 - 1 起反向扫，命中即停）；遇到换行/空格/mention 结束符停止。
    // WKInputAtEndChar = U+2004（多字节），按 unichar 直接比，不要按 UTF8 byte 比（UTF8String[0]
    // 取出的是 0xE2 而非 0x2004，错误地把 'â' 当成结束符撞断扫描）。
    unichar atEndChar = [WKInputAtEndChar characterAtIndex:0];
    NSInteger atPos = -1;
    NSInteger scanFrom = MIN((NSInteger)sel.location - 1, (NSInteger)text.length - 1);
    for (NSInteger i = scanFrom; i >= 0; i--) {
        unichar c = [text characterAtIndex:i];
        if (c == '@') { atPos = i; break; }
        if (c == '\n' || c == ' ' || c == atEndChar) { break; }
    }

    NSString *insertion = [NSString stringWithFormat:@"@%@%@", model.name ?: @"", WKInputAtEndChar];

    NSMutableString *out = [text mutableCopy];
    NSRange replaceRange;
    if (atPos >= 0) {
        // 替换从 '@' 到光标的那一段（含 '@' 自身，可能还含用户已输入的搜索关键字）。
        NSInteger from = atPos;
        NSInteger to = MIN((NSInteger)sel.location, (NSInteger)text.length);
        replaceRange = NSMakeRange(from, to - from);
    } else {
        // 找不到 '@'（异常路径，比如按钮入口已被清空）：插在光标位置。
        replaceRange = NSMakeRange(MIN((NSInteger)sel.location, (NSInteger)text.length), 0);
    }
    [out replaceCharactersInRange:replaceRange withString:insertion];
    self.captionView.text = out;
    self.captionView.selectedRange = NSMakeRange(replaceRange.location + insertion.length, 0);
    [self textViewDidChange:self.captionView];

    // 累积进 mentions（重复 uid 不去重——与主聊天 mentionCache 行为一致：同一人 @ 多次
    // 在 entities 上会生成多段 range，server 端按 uid+range 处理）。
    WKInputMentionItem *item = [WKInputMentionItem new];
    item.uid = model.uid ?: @"";
    item.name = model.name ?: @"";
    [self.mentions addObject:item];
}

// 用户按删除键删  （mention 末尾 sentinel char）时，把这个 mention 整段（"@<name> "）
// 一并删除，与 WKConversationInputPanel.delRangeForMention 同思路。避免半残留 mention 文本。
- (BOOL)maybeRemoveMentionAtCursor:(UITextView *)tv range:(NSRange)range {
    NSString *text = tv.text ?: @"";
    if (range.location >= text.length) return NO;
    NSString *willDel = [text substringWithRange:range];
    if (![willDel isEqualToString:WKInputAtEndChar]) return NO;

    // 反向找到与之配对的 '@'，整段一起删。
    NSInteger atPos = -1;
    for (NSInteger i = (NSInteger)range.location - 1; i >= 0; i--) {
        unichar c = [text characterAtIndex:i];
        if (c == '@') { atPos = i; break; }
        if (c == '\n') break;
    }
    if (atPos < 0) return NO;

    NSRange wholeRange = NSMakeRange(atPos, range.location + 1 - atPos);
    NSString *segment = [text substringWithRange:wholeRange]; // "@<name> "
    NSString *nameOnly = [segment substringWithRange:NSMakeRange(1, segment.length - 2)];
    // 同名 mention 从尾部移除一个（与插入顺序对偶；最常见场景是用户刚@错立刻删）。
    for (NSInteger i = (NSInteger)self.mentions.count - 1; i >= 0; i--) {
        if ([self.mentions[i].name isEqualToString:nameOnly]) {
            [self.mentions removeObjectAtIndex:i];
            break;
        }
    }
    NSMutableString *out = [text mutableCopy];
    [out deleteCharactersInRange:wholeRange];
    tv.text = out;
    tv.selectedRange = NSMakeRange(wholeRange.location, 0);
    [self textViewDidChange:tv];
    return YES;
}

#pragma mark - Actions

- (void)onDeleteImage:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)self.imageDatas.count) return;
    [self.imageDatas removeObjectAtIndex:idx];
    [self rebuildThumbnails];
}

- (void)onThumbnailTapped:(UITapGestureRecognizer *)gr {
    NSInteger idx = gr.view.tag;
    if (idx < 0 || idx >= (NSInteger)self.imageDatas.count) return;
    [self.view endEditing:YES];

    // 用 YBImageBrowser 装当前已选图（NSData → UIImage 同步给 block，避免一开始空白闪烁）。
    // 左右滑切图 / 双指缩放 / 下拉关 都内建；与聊天里 WKImageMessageCell 用的同款方案。
    NSArray<NSData *> *snapshot = [self.imageDatas copy];
    NSMutableArray<YBIBImageData *> *dataSource = [NSMutableArray arrayWithCapacity:snapshot.count];
    for (NSData *d in snapshot) {
        YBIBImageData *item = [YBIBImageData new];
        // image 是 block 形式，按需 decode；用 captured NSData 保证浏览器期间数据不被释放。
        item.image = ^UIImage *_Nullable{
            return [UIImage imageWithData:d];
        };
        [dataSource addObject:item];
    }
    if (dataSource.count == 0) return;

    WKImageBrowser *browser = [[WKImageBrowser alloc] init];
    browser.dataSourceArray = dataSource;
    browser.currentPage = idx; // YBImageBrowser 用 0-based；放在 dataSourceArray 之后
    // YBImageBrowser.show 默认挂到 [UIApplication keyWindow]——caption VC 是 fullScreen modal，
    // 它的 view 被 UIKit 装在专用 _UIPresentationContainerView 里，z-order 在 keyWindow.subviews
    // 之上，所以 browser 加到 window 就会被埋到 caption 下面看不见。这里改成 showToView:self.view，
    // 浏览器作为 caption VC 自己 view 的子视图盖在最上面，与模态层级一致。
    [browser showToView:self.view];
}

- (NSString *)trimmedCaption {
    NSString *raw = self.captionView.text ?: @"";
    return [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)onSendTapped {
    if (self.settled) return;
    NSString *caption = [self trimmedCaption];
    NSArray<NSData *> *finalImages = [self.imageDatas copy];
    if (finalImages.count == 0 && caption.length == 0) {
        // 全删了图又没文字：等同 cancel，不发任何东西。
        [self onCancelTapped];
        return;
    }
    self.settled = YES;
    [self.view endEditing:YES];
    void (^cb)(NSArray<NSData *> *, NSString *, NSArray<WKInputMentionItem *> *) = self.onSend;
    NSArray<WKInputMentionItem *> *mentionsSnapshot = [self.mentions copy];
    [self dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(finalImages, caption, mentionsSnapshot);
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
