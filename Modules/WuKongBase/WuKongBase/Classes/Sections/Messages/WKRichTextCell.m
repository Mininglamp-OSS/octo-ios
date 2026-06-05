//
//  WKRichTextCell.m
//  WuKongBase
//

#import "WKRichTextCell.h"
#import "WKRichTextContent.h"
#import "WKApp.h"
#import "UIView+WK.h"
#import "WKMessageTextView.h"
#import "NSMutableAttributedString+WK.h"
#import "WKRemoteImageAttachment.h"
#import "WKMatchToken.h"
#import "UIImage+WK.h"
#import "WKNavigationManager.h"
#import "WKMessageLongMenusItem.h"
#import "WKImageBrowser.h"
#import <WuKongBase/WuKongBase-Swift.h>
#import <YBImageBrowser/YBImageBrowser.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <objc/runtime.h>

// 按 block 处理的截断阈值（累计纯文本字符数），勿在 block 内部切断（契约 §5.2）。
static const NSInteger kRichTextTruncateThreshold = 10000;
// 单条消息最多渲染/下载的图片块数；超出则截断走"查看全文"，避免 100+ 纯图消息
// 全量渲染+下载（纯图消息不产生文本字符，仅靠文本阈值无法触发截断）。
static const NSInteger kRichTextMaxImageCount = 20;
static const CGFloat kViewFullTextBtnHeight = 36.0f;
// 内联图片的最大边长（避免单图撑满气泡）。
static const CGFloat kRichTextImageMaxLength = 220.0f;

// 选区模式关联对象 keys：menus 是当前菜单项数组；active 标志在选区生命周期内为 @YES，
// 用于 canPerformAction: 屏蔽系统编辑菜单。
static const char kRichTextSelMenusKey = 0;
static const char kRichTextSelActiveKey = 0;
// refresh: 内容指纹 key——同一 cell 同一消息再次 bind 时跳过 attributedText 重设，保留
// 已下载的 attachment image，避免「图片闪一下」(详见 refresh: 注释)。
static const char kRichTextLastRenderKey = 0;
// 选区期间被临时禁用的手势——end 时按原状还原。与 WKTextMessageCell 同款思路（kSelNavKey /
// kSelTableViewKey），避免选区拖句柄时被「右滑返回」/「table 上下滑」抢手势。
static const char kRichTextSelNavPansKey = 0;       // NSArray<UIPanGestureRecognizer*>* 记录被禁用的 nav.view 上的 pan
static const char kRichTextSelTableViewKey = 0;     // UITableView*（assign，弱引用）记录被禁用的 table
static const char kRichTextSelTableScrollWasEnabledKey = 0; // NSNumber 记录 table 原本的 scrollEnabled
// 选区期间禁掉 cell 自身的 TapLongTap 识别器——它在 contentView 上 grab touchesBegan 后
// textView 选区句柄 pan 就拿不到 touchesBegan（UIKit 规则：识别器没收到 began 不能 mid-
// touch 启动）。end 时按原状还原。详见 startInBubbleTextSelectionWithMenuItems: 注释。
static const char kRichTextSelTapWrapWasEnabledKey = 0;
// textLbl.scrollEnabled 原值（iOS quirk 修复：选区期间临时打开，end 时按原状还原）。
static const char kRichTextSelScrollWasEnabledKey = 0;
// 全选时的初始 range，textViewDidChangeSelection: 拿到比较「现在的选区是否仍是全选」用——
// 拖句柄后只要不再等于这个就切到「部分选区菜单」（仅复制 + 全选）。
static const char kRichTextSelInitialRangeKey = 0;
// bubbleBackgroundView.userInteractionEnabled 原值（UIImageView 默认 NO 会吞掉所有触摸 →
// hitTest 退回 mainContainerNode，textLbl 拿不到 touch；选区期间临时打开，end 时按原状还原）。
static const char kRichTextSelBubbleUIWasEnabledKey = 0;
// 选区期间临时把 textLbl.delegate 指到 self（iOS 16+ 用 UITextViewDelegate 的
// editMenuForTextInRange:suggestedActions: 返回空 menu 压系统编辑菜单——UIMenuController 已
// 在 iOS 16+ 被 UIEditMenuInteraction 替代，老 canPerformAction: + willShowNotification
// 路径管不到新菜单）。end 时还原。
static const char kRichTextSelOrigDelegateKey = 0;

@interface WKRichTextCell ()

@property(nonatomic,strong) WKMessageTextView *textLbl;
@property(nonatomic,strong) UIButton *viewFullTextBtn;

@end

// 一个全屏 transparent view：
//   - 在 passthroughView（即 textLbl）和 popup card 的 frame 区域 pointInside 返回 NO，
//     让句柄、菜单按钮的 touch 穿透到下面真实视图；
//   - 其它区域 pointInside 返回 YES + 收到 touchUpInside 后调 onTap → 触发 dismiss。
// 之前用 window-level UITapGestureRecognizer 不稳：键盘弹起 / 第二个 UIWindow 出现时
// gesture 不一定 fire，overlay 走 hitTest 优先级最高，所有 outside touch 必拦得到。
@interface WKRichTextCell () <UITextViewDelegate>
@end

@interface _WKRichSelOverlayView : UIControl
@property(nonatomic, weak) UIView *passthroughView;
@property(nonatomic, copy) void(^onTap)(void);
@end

@implementation WKRichTextCell

#pragma mark - 构建 attributed 正文（渲染与测量共用）

/// 把 blocks 渲染成 attributed string：text 块走 appendText，image 块走
/// appendRemoteImage（新建 WKRemoteImageToken，不走 entities offset 路线）。
/// 按 blocks 顺序穿插；超长按 block 截断，不切断图片块。
+ (NSMutableAttributedString*)attributedStringForMessage:(WKMessageModel*)model truncated:(BOOL*)truncated {
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
    attr.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
    attr.textColor = model.isSend ? [WKApp shared].config.messageSendTextColor : [WKApp shared].config.messageRecvTextColor;

    if (![model.content isKindOfClass:[WKRichTextContent class]]) {
        if (truncated) { *truncated = NO; }
        return attr;
    }
    WKRichTextContent *content = (WKRichTextContent*)model.content;

    CGFloat maxWidth = [WKApp shared].config.messageContentMaxWidth;
    NSInteger accumulated = 0;
    NSInteger imageCount = 0;
    BOOL didTruncate = NO;

    for (WKRichTextBlock *block in content.content) {
        // 文本累计过阈值则丢弃后续整块（含图片），不切碎单块。
        if (accumulated >= kRichTextTruncateThreshold) {
            didTruncate = YES;
            break;
        }

        if (block.type == WKRichTextBlockTypeImage) {
            if (block.url.length == 0) {
                continue;
            }
            // 图片数过上限只跳过多余图片（不中断整个循环），后续文本块仍渲染：
            // 既避免 100+ 图全量渲染+下载，又不把跟在大量图片后的短文本藏进"查看全文"。
            if (imageCount >= kRichTextMaxImageCount) {
                didTruncate = YES;
                continue;
            }
            // 图片独占一行，前后补换行，保证穿插清晰。
            if (attr.length > 0 && ![attr.string hasSuffix:@"\n"]) {
                [attr appendText:@"\n"];
            }
            CGSize displaySize = [[self class] displaySizeForBlock:block maxWidth:maxWidth];
            WKRemoteImageToken *token = [WKRemoteImageToken new];
            token.text = @"￼"; // object replacement char，承载 attachment
            token.url = block.url;
            token.size = displaySize;
            [attr appendRemoteImage:token];
            [attr appendText:@"\n"];
            imageCount += 1;
        } else if (block.type == WKRichTextBlockTypeText) {
            NSString *text = block.text ?: @"";
            if (text.length == 0) {
                continue;
            }
            // 文本可安全在 block 内截断（图片块绝不切断）：单个超长文本块只取
            // 剩余预算的前缀，其余丢弃并标记截断，走"查看全文"。
            NSInteger remaining = kRichTextTruncateThreshold - accumulated;
            if ((NSInteger)text.length > remaining) {
                text = [text substringToIndex:remaining];
                didTruncate = YES;
            }
            [attr appendText:text];
            accumulated += text.length;
        }
    }

    // 去掉末尾多余换行，避免气泡底部出现空行。
    while (attr.length > 0 && [attr.string hasSuffix:@"\n"]) {
        [attr deleteCharactersInRange:NSMakeRange(attr.length - 1, 1)];
    }

    if (truncated) { *truncated = didTruncate; }
    return attr;
}

+ (CGSize)displaySizeForBlock:(WKRichTextBlock*)block maxWidth:(CGFloat)maxWidth {
    CGFloat w = block.width > 0 ? block.width : 200.0f;
    CGFloat h = block.height > 0 ? block.height : 200.0f;
    CGFloat maxLength = MIN(maxWidth, kRichTextImageMaxLength);
    CGSize size = [UIImage lim_sizeWithImageOriginSize:CGSizeMake(w, h) maxLength:maxLength];
    if (size.width <= 0) { size.width = 80.0f; }
    if (size.height <= 0) { size.height = 80.0f; }
    return size;
}

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    CGFloat maxWidth = [WKApp shared].config.messageContentMaxWidth;
    BOOL truncated = NO;
    NSMutableAttributedString *attr = [[self class] attributedStringForMessage:model truncated:&truncated];
    CGSize size = [attr size:maxWidth];
    size.width = ceil(size.width) + 1.0f;
    size.height = ceil(size.height) + 1.0f;
    if (truncated) {
        size.height += kViewFullTextBtnHeight;
        size.width = MAX(size.width, maxWidth);
    }
    return size;
}

#pragma mark - UI

-(void) initUI {
    [super initUI];
    self.textLbl = [[WKMessageTextView alloc] init];
    [self.textLbl setFont:[[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize]];
    [self.messageContentView addSubview:self.textLbl];

    self.viewFullTextBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.viewFullTextBtn setTitle:LLang(@"查看全文") forState:UIControlStateNormal];
    [self.viewFullTextBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
    self.viewFullTextBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
    self.viewFullTextBtn.backgroundColor = [[WKApp shared].config.themeColor colorWithAlphaComponent:0.1];
    self.viewFullTextBtn.layer.cornerRadius = 4.0f;
    self.viewFullTextBtn.layer.masksToBounds = YES;
    self.viewFullTextBtn.hidden = YES;
    [self.viewFullTextBtn addTarget:self action:@selector(viewFullTextTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.messageContentView addSubview:self.viewFullTextBtn];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    BOOL truncated = NO;
    NSMutableAttributedString *attr = [[self class] attributedStringForMessage:model truncated:&truncated];
    // 内容指纹：clientMsgNo + 纯文本 hash + truncated 标记。绝大多数 refresh 触发（成员/
    // channelInfo 更新等）内容并没变，重设 attributedText 会让现有 attachment 的 image
    // 引用全部丢失（旧实例被释放，新实例 image=nil），triggerImageDownloads 又跑一遍下载 →
    // 视觉上「图片闪一下」。指纹相同就跳过设值，保留旧 attachments 的已下载 image。
    NSString *key = [NSString stringWithFormat:@"%@|%lu|%d",
                     model.clientMsgNo ?: @"",
                     (unsigned long)[attr.string hash],
                     truncated];
    NSString *lastKey = objc_getAssociatedObject(self, &kRichTextLastRenderKey);
    if (![key isEqualToString:lastKey]) {
        objc_setAssociatedObject(self, &kRichTextLastRenderKey, key, OBJC_ASSOCIATION_COPY_NONATOMIC);
        self.textLbl.attributedText = attr;
        self.viewFullTextBtn.hidden = !truncated;
        [self triggerImageDownloads:attr forModel:model];
    } else {
        // 同一内容 cell 再 bind（比如 channelInfo 刷新触发的 refresh:）：
        // 只刷一次按钮可见性，attachments 复用原图，零下载零闪烁。
        self.viewFullTextBtn.hidden = !truncated;
    }
}

/// 触发远程图片下载；下载完成后若 cell 仍展示同一消息，只刷新对应 attachment 的 glyph
/// 范围（layoutManager 重画那段，imageForBounds: 拿到刚就绪的 self.image），显示尺寸固定，
/// 无需重算 cell 高度或重设 attributedText——后者会触发整段 re-layout，多张图持续下载时
/// 视觉上就是「图片连环闪」（user-report repro）。
- (void)triggerImageDownloads:(NSAttributedString*)attr forModel:(WKMessageModel*)model {
    if (attr.length == 0) { return; }
    __weak typeof(self) weakSelf = self;
    NSString *msgKey = model.clientMsgNo;
    [attr enumerateAttribute:NSAttachmentAttributeName
                     inRange:NSMakeRange(0, attr.length)
                     options:0
                  usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (![value isKindOfClass:[WKRemoteImageAttachment class]]) { return; }
        WKRemoteImageAttachment *attachment = (WKRemoteImageAttachment*)value;
        // attachment.image 可能已被 startDownload 同步路径（SDImageCache 内存命中）写好——
        // 此时不需要任何重绘动作，attr 第一次上 textLbl 时 imageForBounds: 就拿到了。
        if (attachment.image) { return; }
        NSRange capturedRange = range;
        [attachment startDownload:^(UIImage *img) {
            dispatch_async(dispatch_get_main_queue(), ^{
                typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) { return; }
                // 防止 cell 复用错位：仅当仍是同一消息才刷新。
                if (![strongSelf.messageModel.clientMsgNo isEqualToString:msgKey]) { return; }
                NSLayoutManager *lm = strongSelf.textLbl.layoutManager;
                NSTextContainer *tc = strongSelf.textLbl.textContainer;
                if (capturedRange.location + capturedRange.length > strongSelf.textLbl.attributedText.length) {
                    [strongSelf.textLbl setNeedsDisplay];
                    return;
                }
                NSRange glyphRange = [lm glyphRangeForCharacterRange:capturedRange actualCharacterRange:NULL];
                // 只 invalidate 这段 glyph 的「显示」（不动 layout），layoutManager 下一次绘制时
                // 会重新调 attachment.imageForBounds:，此时 self.image 已就绪，原地刷新无闪烁。
                [lm invalidateDisplayForGlyphRange:glyphRange];
                // 触发 redraw（layoutManager invalidateDisplay 只标记不立即重绘）。
                (void)tc;
                [strongSelf.textLbl setNeedsDisplay];
            });
        }];
    }];
}

-(void) viewFullTextTapped {
    NSString *fullText = @"";
    if ([self.messageModel.content isKindOfClass:[WKRichTextContent class]]) {
        WKRichTextContent *content = (WKRichTextContent*)self.messageModel.content;
        // Phase 1：查看全文仅展示纯文本（图片块此处不重排渲染），plain 优先；
        // 缺失时 conversationDigest 遍历 content 兜底（图片→[图片] 占位），勿丢字。
        // 图文完整重排留 Phase 2。
        fullText = content.plain.length > 0 ? content.plain : [content conversationDigest];
    }
    UIViewController *vc = [[UIViewController alloc] init];
    vc.title = LLang(@"查看全文");
    vc.view.backgroundColor = [WKApp shared].config.backgroundColor;
    UITextView *textView = [[UITextView alloc] initWithFrame:vc.view.bounds];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textView.text = fullText;
    textView.editable = NO;
    textView.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
    textView.textColor = [WKApp shared].config.defaultTextColor;
    textView.backgroundColor = [UIColor clearColor];
    textView.contentInset = UIEdgeInsetsMake(10, 10, 10, 10);
    [vc.view addSubview:textView];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

#pragma mark - 点击图片 attachment 弹大图预览

// 单击命中文字气泡里某个 image attachment → 用 WKImageBrowser 弹全屏预览，
// dataSource = 这条消息里所有 image block（按 attributedText 中 attachment 出现顺序），
// currentPage = 命中的那一张，左右滑切换相邻图。与 WKImageMessageCell / caption editor
// 共用同一套 YBImageBrowser 方案，避免引第二套预览组件。
- (void)onTapWithGestureRecognizer:(TapLongTapOrDoubleTapGestureRecognizerWrap*)gesture {
    [super onTapWithGestureRecognizer:gesture];

    if (gesture.gesture == nil) return;
    CGPoint pointInTextLbl = [gesture.gesture locationInView:self.textLbl];
    if (!CGRectContainsPoint(self.textLbl.bounds, pointInTextLbl)) return;
    NSUInteger charIndex = [self _wkRichCharacterIndexAtPoint:pointInTextLbl];
    if (charIndex == NSNotFound) return;
    NSAttributedString *attr = self.textLbl.attributedText;
    if (charIndex >= attr.length) return;
    id attach = [attr attribute:NSAttachmentAttributeName atIndex:charIndex effectiveRange:nil];
    if (![attach isKindOfClass:[WKRemoteImageAttachment class]]) return;
    [self _wkRichShowImageBrowserAtCharIndex:charIndex];
}

// 把 point（textLbl 坐标系）映射回 attributedText 的 character index；NSNotFound 表示
// 点击落在 layout container 之外，layoutManager 接口会返回最近的 glyph，所以这里再做一次
// glyph rect 校验：实际 enclosing rect 不包 point 就视为未命中（防止点空白处误开图）。
- (NSUInteger)_wkRichCharacterIndexAtPoint:(CGPoint)point {
    NSAttributedString *attr = self.textLbl.attributedText;
    if (attr.length == 0) return NSNotFound;
    NSLayoutManager *lm = self.textLbl.layoutManager;
    NSTextContainer *tc = self.textLbl.textContainer;
    [lm ensureLayoutForTextContainer:tc];
    // 把 point 转到 textContainer 坐标系（去掉 textContainerInset）。
    UIEdgeInsets inset = self.textLbl.textContainerInset;
    CGPoint ptInContainer = CGPointMake(point.x - inset.left, point.y - inset.top);
    NSUInteger glyphIndex = [lm glyphIndexForPoint:ptInContainer inTextContainer:tc];
    if (glyphIndex >= [lm numberOfGlyphs]) return NSNotFound;
    CGRect glyphRect = [lm boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1) inTextContainer:tc];
    if (!CGRectContainsPoint(glyphRect, ptInContainer)) return NSNotFound;
    return [lm characterIndexForGlyphAtIndex:glyphIndex];
}

- (void)_wkRichShowImageBrowserAtCharIndex:(NSUInteger)hitCharIndex {
    NSAttributedString *attr = self.textLbl.attributedText;
    NSMutableArray<YBIBImageData *> *dataSource = [NSMutableArray array];
    __block NSInteger hitIdx = -1;
    __block NSInteger runningIdx = 0;
    [attr enumerateAttribute:NSAttachmentAttributeName
                     inRange:NSMakeRange(0, attr.length)
                     options:0
                  usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (![value isKindOfClass:[WKRemoteImageAttachment class]]) return;
        WKRemoteImageAttachment *att = (WKRemoteImageAttachment *)value;
        YBIBImageData *item = [YBIBImageData new];
        if (att.url.length > 0) {
            item.imageURL = [NSURL URLWithString:att.url];
        }
        // 命中已经下载好的 attachment：用 block 形式同步给图，避免预览器一开始要等网络回掉。
        if (att.image) {
            UIImage *cached = att.image;
            item.image = ^UIImage *_Nullable{ return cached; };
        }
        [dataSource addObject:item];
        if (hitCharIndex >= range.location && hitCharIndex < NSMaxRange(range)) {
            hitIdx = runningIdx;
        }
        runningIdx++;
    }];
    if (dataSource.count == 0) return;
    if (hitIdx < 0) hitIdx = 0;
    WKImageBrowser *browser = [[WKImageBrowser alloc] init];
    browser.dataSourceArray = dataSource;
    browser.currentPage = hitIdx; // 0-based，setCurrentPage 内部 clamp 到 numberOfCells-1

    // 预览期间禁掉 nav 上的所有 UIPanGestureRecognizer（含 interactivePopGesture）——
    // YBImageBrowser 自己的左右翻页 UICollectionView 在最上层吃滑动，但 iOS 的边缘右滑
    // 仍能命中 nav.view 的 pan，单图预览时一不小心就退回会话列表（看着像 ScrollView 边
    // 缘回弹却实际 pop 走了）。这里把 pop 手势临时关掉，onDealloc 还原；多图场景下也无副
    // 作用（用户横滑切的是 collection 本体不是 nav pop）。
    UIResponder *responder = self;
    UINavigationController *nav = nil;
    while (responder) {
        if ([responder isKindOfClass:[UINavigationController class]]) {
            nav = (UINavigationController *)responder;
            break;
        }
        responder = [responder nextResponder];
    }
    NSMutableArray<UIPanGestureRecognizer *> *disabledNavPans = [NSMutableArray array];
    if (nav) {
        for (UIGestureRecognizer *gr in nav.view.gestureRecognizers) {
            if ([gr isKindOfClass:[UIPanGestureRecognizer class]] && gr.enabled) {
                gr.enabled = NO;
                [disabledNavPans addObject:(UIPanGestureRecognizer *)gr];
            }
        }
    }
    browser.onDealloc = ^{
        for (UIPanGestureRecognizer *gr in disabledNavPans) {
            gr.enabled = YES;
        }
    };
    [browser show];
}

-(void) layoutSubviews {
    [super layoutSubviews];
    CGFloat contentW = self.messageContentView.lim_width;
    if (self.viewFullTextBtn.hidden) {
        self.textLbl.frame = CGRectMake(0, 0, contentW, self.messageContentView.lim_height);
    } else {
        CGFloat textH = self.messageContentView.lim_height - kViewFullTextBtnHeight;
        if (textH < 0) { textH = 0; }
        self.textLbl.frame = CGRectMake(0, 0, contentW, textH);
        self.viewFullTextBtn.frame = CGRectMake(0, textH, contentW, kViewFullTextBtnHeight);
    }
}

#pragma mark - 气泡内文字选区（原生 UITextView 选区拖句柄 + 复用 WK_TEXT 同款图标网格 popup）
//
// 目标：与 WK_TEXT 长按 UX 完全一致——
//   1) 长按 → textLbl 进入原生 iOS 选区模式（句柄可拖、可选片段）；
//   2) 选区上方挂一张图标网格菜单卡（与 WKTextMessageCell wk_showSelectionMenuForRange:
//      同款样式：reply/forward/copy/...），不带 dim overlay，句柄可继续拖；
//   3) 选片段后 Copy 用拖出来的 selectedText，不强行回退到整段 plain。
// 不复制 WK_TEXT 那一整套自绘 WKSelectionHandle / kSel* KVO / 段切换基础设施——
// 原生 UITextView 选区在 RichText 内嵌 image attachment 场景下能直接用，
// 复杂度和踩坑面都小一个量级。

static const NSInteger kRichTextSelPopupTag = 0x57524D54;   // 'WRMT' popup card tag
static const NSInteger kRichTextSelOverlayTag = 0x57524F56;  // 'WROV' transparent overlay tag

// 调试日志：WKRichSelLog 在 DEBUG 下打印，发布构建空操作（避免 NSLog 上线）。
#if DEBUG
#define WKRichSelLog(fmt, ...) NSLog(@"[WKRichSel] " fmt, ##__VA_ARGS__)
#else
#define WKRichSelLog(fmt, ...) do {} while (0)
#endif

// Forward declaration of the overlay subclass (defined at bottom of file).
@class _WKRichSelOverlayView;

- (void)startInBubbleTextSelectionWithMenuItems:(NSArray *)menuItems {
    if (self.textLbl.isFirstResponder) {
        WKRichSelLog(@"start: already first responder, skip");
        return;
    }
    if (self.textLbl.attributedText.length == 0) {
        // 纯空气泡（无 text 也无 image 占位）—— 选区无意义；直接返回，长按视同无效。
        WKRichSelLog(@"start: empty attributedText, skip");
        return;
    }
    WKRichSelLog(@"start: menuItems=%lu attrLen=%lu textLbl=%@",
                 (unsigned long)menuItems.count,
                 (unsigned long)self.textLbl.attributedText.length,
                 NSStringFromCGRect(self.textLbl.frame));

    NSArray *captured = menuItems ?: @[];
    objc_setAssociatedObject(self, &kRichTextSelMenusKey, captured, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // active 必须在 becomeFirstResponder / 设 selectedRange 前置位——
    // 这两步会触发 UIKit 询问 canPerformAction:，active=YES 时全返 NO，
    // 系统编辑菜单就不会瞬闪一下出来与我们自己的卡片打架。
    objc_setAssociatedObject(self, &kRichTextSelActiveKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 选区句柄拖动 / textView 内点击时 UIKit 都会请求重弹系统菜单——监听一次系统菜单
    // willShow，立刻关掉它，再补一次我们自己的卡片重定位（与最新选区联动）。
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_wkRichSelMenuWillShow:)
                                                 name:UIMenuControllerWillShowMenuNotification
                                               object:nil];

    self.textLbl.editable = NO;
    self.textLbl.selectable = YES;
    // iOS 私底下有个坑：UITextView `selectable=YES + scrollEnabled=NO` 路径下，
    // _UITextSelectionLollipopView（句柄圆形末端）frame 始终保持 {0,0,0,0}，
    // 即「Lollipop view 存在但没尺寸」→ 用户摸到了那一带也没东西可拖，
    // 整段 selection range adjustment gesture 就形同失效。WKMessageTextView 默认
    // 走 display-only 模式 scrollEnabled=NO（用 UILabel 同款），所以我们必须
    // 在选区生命周期内临时打开 scrollEnabled，让 UIKit 走它「正常的可滚动 textView」
    // selection 布局路径，lollipop 才会被摆到 selection 两端。endInBubbleTextSelection
    // 还原回 NO，不影响展示态。
    objc_setAssociatedObject(self, &kRichTextSelScrollWasEnabledKey,
                             @(self.textLbl.scrollEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.textLbl.scrollEnabled = YES;
    // bubbleBackgroundView 是 UIImageView，默认 userInteractionEnabled=NO → 触摸命中 bubble
    // 但 bubble 把 hitTest 返 nil，UIKit 退回到上一层（mainContainerNode 那个 _ASDisplayView），
    // textLbl/lollipop 永远摸不到。这是诊断日志直接抓到的现象：lollipop 已正确摆到选区两端，
    // 用户手指也按对位置，但 windowSpy 的 hitTest 始终命中 _ASDisplayView。选区生命周期内
    // 临时把 bubble 打开 ui，end 时还原；不直接改 WKMessageCell 全局打开，免得影响别的 cell。
    UIView *bubble = self.bubbleBackgroundView;
    if (bubble) {
        objc_setAssociatedObject(self, &kRichTextSelBubbleUIWasEnabledKey,
                                 @(bubble.userInteractionEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        bubble.userInteractionEnabled = YES;
    }
    // 把 textLbl.delegate 临时指向 self——iOS 16+ 的 UIEditMenuInteraction 是通过
    // UITextViewDelegate.textView:editMenuForTextInRange:suggestedActions: 拿到 system menu
    // 候选项的。返回空 UIMenu / nil 就能彻底压住系统编辑菜单（之前 canPerformAction:
    // 返 NO + UIMenuControllerWillShowMenuNotification 监听只对老 UIMenuController 路径
    // 有效，iOS 16+ UITextView 默认走新接口，老路径根本不 fire）。end 时还原原 delegate。
    objc_setAssociatedObject(self, &kRichTextSelOrigDelegateKey, self.textLbl.delegate,
                             OBJC_ASSOCIATION_ASSIGN);
    self.textLbl.delegate = (id<UITextViewDelegate>)self;
    // tintColor 决定 UITextView 选区底色 + 句柄颜色。WKMessageCell 链路上偶有把 tintColor 设成
    // clear 的（具体在哪个 ancestor 不重要），导致选区透明看不见。这里显式强制系统蓝，
    // endInBubbleTextSelection 也无需还原——textLbl 平时不可选，tintColor 不影响展示态。
    if (@available(iOS 13.0, *)) {
        self.textLbl.tintColor = [UIColor systemBlueColor];
    } else {
        self.textLbl.tintColor = [UIColor colorWithRed:0.0f green:122.0f/255.0f blue:1.0f alpha:1.0f];
    }
    // 强制 textContainer 先按当前 bounds 完整布局——RichText 内嵌 image attachment 的场景
    // 下，UITextView 从 selectable=NO 切到 YES 时偶发选区只覆盖第一个 line fragment（image
    // 那行），下面的文字行 selection rect 未生成。提前 ensureLayout 把所有 glyph 排好，
    // 后面的 selectedRange 就能拿到完整 line fragments。
    [self.textLbl.layoutManager ensureLayoutForTextContainer:self.textLbl.textContainer];
    [self.textLbl becomeFirstResponder];
    // 选区起点跳过领头 image attachment + 空白/换行——句柄应当从「文字部分」起，
    // 而不是从图片左上角起（用户体验：拖句柄收的就是文字片段，没人想拖一张图）。
    // 末位也同样 trim 尾部 attachment + 空白，保持对称。
    NSRange textRange = [[self class] _wkRichSelTextRangeInAttributedString:self.textLbl.attributedText];
    if (textRange.length == 0) {
        // 纯图消息（无任何文字 block）—— 拖句柄无意义，退化到 selectAll 让用户至少能 Copy 整段。
        [self.textLbl selectAll:nil];
    } else {
        self.textLbl.selectedRange = textRange;
    }
    WKRichSelLog(@"start: textRange=%@ finalSelectedRange=%@",
                 NSStringFromRange(textRange),
                 NSStringFromRange(self.textLbl.selectedRange));

    // 记下「全选时」的 range，用于 textViewDidChangeSelection: 里判断当前选区是否仍 full。
    // 用户拖句柄改了选区 → 不再等于这个 → 切到部分选区菜单（复制 + 全选）。
    objc_setAssociatedObject(self, &kRichTextSelInitialRangeKey,
                             [NSValue valueWithRange:self.textLbl.selectedRange],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // UITextView 的 selectedRange KVO 苹果未保证（UIKit 改 range 时不一定走 setter），
    // 实测拖句柄期间 KVO 完全不 fire —— 这就是「拖完不切部分菜单」的根因。换成官方
    // textViewDidChangeSelection: delegate 钩子，是 UITextView 选区变化的权威通知。
    // delegate 已经在前面被指向 self（为了拦 iOS 16+ edit menu）。

    // 选区拖句柄时屏蔽全局滑动手势：
    //   1) 右滑返回（UINavigationController.view 上的 interactivePopGestureRecognizer
    //      实质就是个 UIPanGestureRecognizer），拖句柄过气泡左缘会被它吃掉。
    //   2) 父 tableView 的纵向滚动，拖句柄上下越过气泡边沿会被 table 顺势滚走。
    // 与 WKTextMessageCell 同款思路（kSelNavKey / kSelTableViewKey），end 时按原状还原。
    [self _wkRichSelLockEnclosingScrollGestures];

    // 兜底关闭路径：透明 overlay 罩在 window 上，textLbl 区域 + 我们自己的菜单卡区域
    // 都从 pointInside 漏空（句柄和按钮照常工作），其它任意位置一点就 dismiss。
    // 之前用 window-level UITapGestureRecognizer 在某些 iOS 版本/键盘弹出态下不稳，
    // overlay UIView 比 gesture 路径稳得多（hitTest 优先级最高，不被其它 gesture 抢）。
    UIWindow *window = self.window ?: [UIApplication sharedApplication].windows.firstObject;
    [[window viewWithTag:kRichTextSelOverlayTag] removeFromSuperview]; // 清干净（防 cell 复用残留）
    _WKRichSelOverlayView *overlay = [[_WKRichSelOverlayView alloc] initWithFrame:window.bounds];
    overlay.tag = kRichTextSelOverlayTag;
    overlay.passthroughView = self.textLbl;
    __weak typeof(self) weakSelf = self;
    overlay.onTap = ^{
        WKRichSelLog(@"overlay tapped → dismiss");
        [weakSelf endInBubbleTextSelection];
    };
    [window addSubview:overlay];

    [self _wkRichSelShowPopup];
}

#pragma mark - 选区期间手势屏蔽（与 end 时按原状还原配对）

- (void)_wkRichSelLockEnclosingScrollGestures {
    // —— 0. cell 自己的 TapLongTap 识别器 ——
    // 不禁掉的话：用户按下选区句柄 → wrap.gesture(OctoTapLongTapOrDoubleTapRecognizer)
    // 在 contentView 上 grab touchesBegan 进 awaitingFirstUp。同一时刻 textView 的选区
    // pan 想 begin → 因 wrap 设了 shouldRecognizeSimultaneouslyWith UIPanGestureRecognizer
    // = false，pan 被告知「等 wrap fail」。用户一移动 → wrap 在 touchesMoved 里因距离
    // 超阈值才 cancelInternal，但此时 textView pan 已经错过 touchesBegan → UIKit 规则
    // 不允许 mid-touch 启动它 → 句柄一动不动。
    // WK_TEXT 没踩这个坑是因为它的 WKSelectionHandle 是 window 子视图，自带独立 pan，
    // cell 的 wrap 根本看不到那些 touch（不在 contentView 上）。我们用原生 native handles
    // 必须先把 wrap 禁了，让 textView 选区 pan 完整拿到 touch 序列。
    // wrap 属性是 WKMessageCell.m 私有 extension，不暴露到 .h；这里在 contentView 上
    // 直接按类查 OctoTapLongTapOrDoubleTapRecognizer 实例（WKMessageCell.initUI 唯一一个），
    // 避免为这个修复改 .h 增加新公共 API。
    UIGestureRecognizer *tapWrap = [self _wkRichFindTapRecognizer];
    if (tapWrap) {
        objc_setAssociatedObject(self, &kRichTextSelTapWrapWasEnabledKey, @(tapWrap.enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        tapWrap.enabled = NO;
    }

    // —— 1. nav.view 上所有 pan（涵盖 interactivePopGesture 及任何自定义 pan）——
    UIResponder *responder = self;
    UINavigationController *navHit = nil;
    while (responder) {
        if ([responder isKindOfClass:[UINavigationController class]]) {
            navHit = (UINavigationController *)responder;
            break;
        }
        responder = [responder nextResponder];
    }
    if (navHit) {
        NSMutableArray<UIPanGestureRecognizer *> *disabled = [NSMutableArray array];
        for (UIGestureRecognizer *gr in navHit.view.gestureRecognizers) {
            if ([gr isKindOfClass:[UIPanGestureRecognizer class]] && gr.enabled) {
                gr.enabled = NO;
                [disabled addObject:(UIPanGestureRecognizer *)gr];
            }
        }
        objc_setAssociatedObject(self, &kRichTextSelNavPansKey, disabled, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // —— 2. 包含 cell 的 UITableView 纵向滚动 ——
    UIView *v = self.superview;
    while (v && ![v isKindOfClass:[UITableView class]]) v = v.superview;
    if ([v isKindOfClass:[UITableView class]]) {
        UITableView *tv = (UITableView *)v;
        objc_setAssociatedObject(self, &kRichTextSelTableScrollWasEnabledKey, @(tv.scrollEnabled),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        tv.scrollEnabled = NO;
        objc_setAssociatedObject(self, &kRichTextSelTableViewKey, tv, OBJC_ASSOCIATION_ASSIGN);
    }
}

- (void)_wkRichSelUnlockEnclosingScrollGestures {
    // 还原 wrap.gesture。
    UIGestureRecognizer *tapWrap = [self _wkRichFindTapRecognizer];
    NSNumber *wrapWasEnabled = objc_getAssociatedObject(self, &kRichTextSelTapWrapWasEnabledKey);
    if (tapWrap && wrapWasEnabled) {
        tapWrap.enabled = wrapWasEnabled.boolValue;
    }
    objc_setAssociatedObject(self, &kRichTextSelTapWrapWasEnabledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSArray<UIPanGestureRecognizer *> *disabled = objc_getAssociatedObject(self, &kRichTextSelNavPansKey);
    for (UIPanGestureRecognizer *gr in disabled) {
        gr.enabled = YES;
    }
    objc_setAssociatedObject(self, &kRichTextSelNavPansKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UITableView *tv = objc_getAssociatedObject(self, &kRichTextSelTableViewKey);
    NSNumber *wasEnabled = objc_getAssociatedObject(self, &kRichTextSelTableScrollWasEnabledKey);
    if (tv && wasEnabled) {
        tv.scrollEnabled = wasEnabled.boolValue;
    }
    objc_setAssociatedObject(self, &kRichTextSelTableViewKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, &kRichTextSelTableScrollWasEnabledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// 在 contentView 已挂的识别器里找 cell 自家的 TapLongTap 识别器（来自 WKMessageCell.initUI 的
// tapLongTapOrDoubleTapGestureRecognizerWrap.gesture）。OctoTapLongTapOrDoubleTapRecognizer 是
// Swift 类，通过 WuKongBase-Swift.h 桥接到 ObjC，按类型匹配即可。
- (UIGestureRecognizer *)_wkRichFindTapRecognizer {
    for (UIGestureRecognizer *gr in self.contentView.gestureRecognizers) {
        if ([gr isKindOfClass:[OctoTapLongTapOrDoubleTapRecognizer class]]) {
            return gr;
        }
    }
    return nil;
}

- (void)endInBubbleTextSelection {
    if (!objc_getAssociatedObject(self, &kRichTextSelActiveKey)) {
        return;
    }
    WKRichSelLog(@"end");
    objc_setAssociatedObject(self, &kRichTextSelActiveKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    objc_setAssociatedObject(self, &kRichTextSelInitialRangeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIMenuControllerWillShowMenuNotification object:nil];
    [self _wkRichSelHidePopup];

    UIWindow *window = self.window ?: [UIApplication sharedApplication].windows.firstObject;
    [[window viewWithTag:kRichTextSelOverlayTag] removeFromSuperview];

    UIMenuController *mc = [UIMenuController sharedMenuController];
    if (@available(iOS 13.0, *)) {
        [mc hideMenuFromView:self.textLbl];
    } else {
        [mc setMenuVisible:NO animated:NO];
    }

    self.textLbl.selectedRange = NSMakeRange(0, 0);
    [self.textLbl resignFirstResponder];
    // 还原 scrollEnabled（start 时为了 lollipop 摆位置临时打开了）。
    NSNumber *scrollWas = objc_getAssociatedObject(self, &kRichTextSelScrollWasEnabledKey);
    if (scrollWas) {
        self.textLbl.scrollEnabled = scrollWas.boolValue;
    }
    objc_setAssociatedObject(self, &kRichTextSelScrollWasEnabledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // 还原 bubbleBackgroundView.userInteractionEnabled（start 时为了让 touch 能下沉到 textLbl
    // 临时打开了）。
    UIView *bubble = self.bubbleBackgroundView;
    NSNumber *bubbleUIWas = objc_getAssociatedObject(self, &kRichTextSelBubbleUIWasEnabledKey);
    if (bubble && bubbleUIWas) {
        bubble.userInteractionEnabled = bubbleUIWas.boolValue;
    }
    objc_setAssociatedObject(self, &kRichTextSelBubbleUIWasEnabledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // 还原 textLbl.delegate（start 时为了拦 iOS 16+ edit menu 临时指向 self 了）。
    // 用 objc_getAssociatedObject 拿原值，可能为 nil（之前就没设 delegate），直接赋回去即可。
    id<UITextViewDelegate> origDelegate = objc_getAssociatedObject(self, &kRichTextSelOrigDelegateKey);
    self.textLbl.delegate = origDelegate;
    objc_setAssociatedObject(self, &kRichTextSelOrigDelegateKey, nil, OBJC_ASSOCIATION_ASSIGN);
    // 退出后立刻禁可选，避免后续点击在气泡上又触发系统选区，与单元格自身长按竞态。
    self.textLbl.selectable = NO;

    objc_setAssociatedObject(self, &kRichTextSelMenusKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 解锁选区期间禁的 nav 右滑返回 + table 上下滚（与 lock 配对）。
    [self _wkRichSelUnlockEnclosingScrollGestures];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    // 选区激活期间所有系统菜单项一律隐藏（Copy / Look up / Translate / Share）—
    // 让我们自己的卡片菜单接管显示和复制逻辑，避免双菜单并存。
    // 注意：这条路径只覆盖老 UIMenuController；iOS 16+ UITextView 走 UIEditMenuInteraction，
    // 由 UITextViewDelegate.textView:editMenuForTextIn:suggestedActions: 接管（见下方）。
    if (objc_getAssociatedObject(self, &kRichTextSelActiveKey)) {
        WKRichSelLog(@"[diag] canPerformAction: %@ sender=%@ → block",
                     NSStringFromSelector(action), NSStringFromClass([sender class]));
        return NO;
    }
    return [super canPerformAction:action withSender:sender];
}

// iOS 16+ UIEditMenuInteraction 出菜单走的钩子。选区激活时返回空 UIMenu → 系统菜单
// 不显示，我们自己的网格 popup 接管。pre-iOS-16 不会调到这里，老路径走 canPerformAction:
// + UIMenuControllerWillShowMenuNotification（已在 start 时挂上）。
- (UIMenu *)textView:(UITextView *)textView
   editMenuForTextInRange:(NSRange)range
        suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions API_AVAILABLE(ios(16.0)) {
    if (objc_getAssociatedObject(self, &kRichTextSelActiveKey)) {
        WKRichSelLog(@"[diag] editMenuForTextIn:%@ suggested=%lu → returning empty UIMenu",
                     NSStringFromRange(range), (unsigned long)suggestedActions.count);
        return [UIMenu menuWithChildren:@[]];
    }
    return nil;
}

- (void)_wkRichSelMenuWillShow:(NSNotification *)note {
    // UIKit 想弹系统菜单时立刻关掉；句柄/点击触发的菜单重弹，则在下一拍刷新自己的卡片
    // 位置（跟随选区移动）。
    if (!objc_getAssociatedObject(self, &kRichTextSelActiveKey)) return;
    WKRichSelLog(@"system menu willShow → hide + reshow our popup");
    UIMenuController *mc = [UIMenuController sharedMenuController];
    if (@available(iOS 13.0, *)) {
        [mc hideMenuFromView:self.textLbl];
    } else {
        [mc setMenuVisible:NO animated:NO];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!objc_getAssociatedObject(self, &kRichTextSelActiveKey)) return;
        [self _wkRichSelShowPopup];
    });
}

// 拖句柄改 selectedRange → textViewDidChangeSelection: 触发 → popup 重画（按全选/部分
// 切换菜单 + 跟随选区重定位）。与 WK_TEXT wk_showSelectionMenuForRange:isAll: 同款 UX：
// 全选显示完整菜单，部分选区显示「复制 + 全选」。range.length==0（句柄拖到重合）不刷 popup。
// 选 KVO 还是 delegate？UITextView 的 selectedRange 实测 KVO 不 fire（UIKit 改 range 不一定
// 走 setter），delegate textViewDidChangeSelection: 是 Apple 文档背书的权威通知。
- (void)textViewDidChangeSelection:(UITextView *)textView {
    if (textView != self.textLbl) return;
    if (!objc_getAssociatedObject(self, &kRichTextSelActiveKey)) return;
    WKRichSelLog(@"[diag] selectionChanged → range=%@", NSStringFromRange(textView.selectedRange));
    if (textView.selectedRange.length == 0) return;
    // dispatch_async 让 UITextView 完成本帧选区内部 layout（lollipop 位置 / glyph 测量）
    // 后再读 selectionRectInWindow，否则定位偏一个 glyph。同时避开 delegate 回调里直接
    // 改 UIKit 状态的潜在 reentrancy。
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!objc_getAssociatedObject(self, &kRichTextSelActiveKey)) return;
        [self _wkRichSelShowPopup];
    });
}

#pragma mark - 自定义图标网格菜单卡（同 WK_TEXT 风格）

- (void)_wkRichSelHidePopup {
    UIWindow *window = self.window ?: [UIApplication sharedApplication].windows.firstObject;
    UIView *old = [window viewWithTag:kRichTextSelPopupTag];
    [old removeFromSuperview];
}

- (void)_wkRichSelShowPopup {
    [self _wkRichSelHidePopup];

    NSArray<WKMessageLongMenusItem *> *fullItems = objc_getAssociatedObject(self, &kRichTextSelMenusKey);
    if (fullItems.count == 0) return;

    UIWindow *window = self.window ?: [UIApplication sharedApplication].windows.firstObject;
    if (!window) return;

    // 与 WK_TEXT wk_showSelectionMenuForRange:isAll: 同款分支：
    //   - 全选（== 初始全选 range）: 显示完整菜单（reply/forward/copy/...）
    //   - 部分选区：仅「复制 + 全选」两项，与系统编辑菜单部分选区时的精简菜单一致
    NSValue *initRangeVal = objc_getAssociatedObject(self, &kRichTextSelInitialRangeKey);
    NSRange initRange = initRangeVal ? initRangeVal.rangeValue : NSMakeRange(NSNotFound, 0);
    NSRange currentRange = self.textLbl.selectedRange;
    BOOL isAll = (initRange.location != NSNotFound &&
                  currentRange.location == initRange.location &&
                  currentRange.length == initRange.length);

    // 统一 button 模型：每项 {title, icon, action}，full / partial 走同一份渲染 + 同一份 tap dispatch。
    NSMutableArray<NSDictionary *> *btns = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    if (isAll) {
        for (WKMessageLongMenusItem *item in fullItems) {
            WKMessageLongMenusItem *captured = item;
            BOOL isCopy = [item.title isEqualToString:LLang(@"复制")];
            void (^action)(void) = ^{
                typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                // 复制项：全选时直接走 plain（与已注册的 Copy handler 行为一致）。
                if (isCopy) {
                    NSString *full = strongSelf.textLbl.text ?: @"";
                    if (full.length > 0) [[UIPasteboard generalPasteboard] setString:full];
                    UIView *topView = [WKNavigationManager shared].topViewController.view;
                    [topView showHUDWithHide:LLang(@"已复制")];
                    [strongSelf endInBubbleTextSelection];
                    return;
                }
                [strongSelf endInBubbleTextSelection];
                if (captured.onTap) captured.onTap(strongSelf.conversationContext);
            };
            [btns addObject:@{@"title": item.title ?: @"",
                              @"icon":  item.icon ?: [NSNull null],
                              @"action": action}];
        }
    } else {
        // 部分选区菜单：仅「复制 + 全选」。
        // 找出 fullItems 里 Copy 项的 icon 复用（保持视觉一致）。
        UIImage *copyIcon = nil;
        for (WKMessageLongMenusItem *it in fullItems) {
            if ([it.title isEqualToString:LLang(@"复制")]) { copyIcon = it.icon; break; }
        }
        // 复制选中片段。range 在 dispatch 那一帧可能已被句柄改了——所以 capture 当下 text 快照
        // 与 range 一起塞进 block，避免 action 触发时再读已经变了的 selectedRange。
        NSRange snapRange = currentRange;
        NSString *snapText = [self.textLbl.text copy] ?: @"";
        void (^copyAction)(void) = ^{
            typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            NSString *piece = @"";
            if (snapRange.length > 0 && NSMaxRange(snapRange) <= snapText.length) {
                piece = [snapText substringWithRange:snapRange];
            }
            if (piece.length > 0) [[UIPasteboard generalPasteboard] setString:piece];
            UIView *topView = [WKNavigationManager shared].topViewController.view;
            [topView showHUDWithHide:LLang(@"已复制")];
            [strongSelf endInBubbleTextSelection];
        };
        [btns addObject:@{@"title": LLang(@"复制"),
                          @"icon":  copyIcon ?: [NSNull null],
                          @"action": copyAction}];
        // 全选：把 selectedRange 调回初始全选 range，菜单会通过 KVO 重画切回完整菜单。
        // dismiss=NO 留住选区不退出（与 WK_TEXT 同款行为，全选项是「就地切回全选」而不是关菜单）。
        void (^selectAllAction)(void) = ^{
            typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (initRange.location != NSNotFound &&
                NSMaxRange(initRange) <= strongSelf.textLbl.attributedText.length) {
                strongSelf.textLbl.selectedRange = initRange;
            }
        };
        [btns addObject:@{@"title": LLang(@"全选"),
                          @"icon":  [NSNull null],
                          @"action": selectAllAction}];
    }

    // —— 卡片几何 ——
    NSInteger total = btns.count;
    NSInteger colCount = MIN(4, total);
    NSInteger rowCount = (total + colCount - 1) / colCount;
    CGFloat hPad = 12;
    CGFloat cardW = isAll ? MIN(window.frame.size.width - 24, 380)
                          : (56 * colCount + hPad * 2);  // 部分菜单紧凑：每格 56pt
    CGFloat cellW = (cardW - hPad * 2) / colCount;
    CGFloat iconSz = isAll ? 22 : 18;
    CGFloat cellH = 12 + iconSz + 4 + 13 + 10;
    CGFloat cardH = rowCount * cellH + 8;
    CGFloat cornerR = 14;

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cardW, cardH)];
    card.tag = kRichTextSelPopupTag;
    card.layer.cornerRadius = cornerR;
    card.clipsToBounds = NO;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.18;
    card.layer.shadowRadius = 12;
    card.layer.shadowOffset = CGSizeMake(0, 4);

    UIView *clipView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cardW, cardH)];
    clipView.backgroundColor = [WKApp shared].config.style == WKSystemStyleDark
        ? [UIColor colorWithRed:0.18 green:0.18 blue:0.20 alpha:1]
        : [UIColor colorWithRed:0.97 green:0.97 blue:0.97 alpha:1];
    clipView.layer.cornerRadius = cornerR;
    clipView.clipsToBounds = YES;
    [card addSubview:clipView];

    UIFont *textFont = [UIFont systemFontOfSize:11];
    UIColor *textColor = [WKApp shared].config.defaultTextColor;

    for (NSInteger i = 0; i < total; i++) {
        NSDictionary *info = btns[i];
        NSInteger col = i % colCount, row = i / colCount;
        CGFloat cellX = hPad + col * cellW, cellY = 4 + row * cellH;

        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(cellX, cellY, cellW, cellH)];
        [btn setBackgroundImage:[self _wkRichSelImageWithColor:[UIColor colorWithWhite:0.5 alpha:0.15]]
                       forState:UIControlStateHighlighted];

        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake((cellW - iconSz) / 2, 12, iconSz, iconSz)];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.tintColor = textColor;
        id icon = info[@"icon"];
        iv.image = (icon && icon != [NSNull null]) ? (UIImage *)icon : [UIImage systemImageNamed:@"ellipsis"];
        [btn addSubview:iv];

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(2, 12 + iconSz + 4, cellW - 4, 13)];
        lbl.text = info[@"title"];
        lbl.font = textFont;
        lbl.textColor = textColor;
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.adjustsFontSizeToFitWidth = YES;
        lbl.minimumScaleFactor = 0.8;
        [btn addSubview:lbl];

        // tap → 直接调 captured action block（不再走 tag-into-array dispatch）。
        objc_setAssociatedObject(btn, "wkRichSelBtnAction", info[@"action"], OBJC_ASSOCIATION_COPY_NONATOMIC);
        [btn addTarget:self action:@selector(_wkRichSelMenuItemTapped:) forControlEvents:UIControlEventTouchUpInside];
        [clipView addSubview:btn];

        if (col < colCount - 1 && i < total - 1) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(cellX + cellW - 0.25, cellY + 8, 0.5, cellH - 16)];
            sep.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.3];
            [clipView addSubview:sep];
        }
    }

    // 定位：尽量在选区上方；空间不够放到选区下方；与 WK_TEXT 留 handleGap=28pt，避开句柄。
    CGRect selFrame = [self _wkRichSelCurrentSelectionRectInWindow];
    CGFloat safeTop = window.safeAreaInsets.top + 8;
    CGFloat safeBot = window.frame.size.height - window.safeAreaInsets.bottom - 80;
    CGFloat cardX = MAX(8, MIN(selFrame.origin.x, window.frame.size.width - cardW - 8));
    CGFloat handleGap = 28;
    CGFloat aboveY = selFrame.origin.y - cardH - handleGap;
    CGFloat belowY = CGRectGetMaxY(selFrame) + handleGap;
    CGFloat cardY = (aboveY >= safeTop) ? aboveY : belowY;
    cardY = MAX(safeTop, MIN(cardY, safeBot - cardH));
    card.frame = CGRectMake(cardX, cardY, cardW, cardH);
    [window addSubview:card];

    card.alpha = 0;
    card.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        card.alpha = 1;
        card.transform = CGAffineTransformIdentity;
    } completion:nil];
}

// 命中当前 selectedRange 在 window 坐标系下的并集矩形，没选东西则退化到 textLbl 全 bounds。
- (CGRect)_wkRichSelCurrentSelectionRectInWindow {
    NSRange r = self.textLbl.selectedRange;
    NSUInteger textLen = self.textLbl.attributedText.length;
    if (r.length == 0 || NSMaxRange(r) > textLen) {
        return [self.textLbl convertRect:self.textLbl.bounds toView:nil];
    }
    NSLayoutManager *lm = self.textLbl.layoutManager;
    NSTextContainer *tc = self.textLbl.textContainer;
    [lm ensureLayoutForTextContainer:tc];
    NSUInteger startGlyph = [lm glyphIndexForCharacterAtIndex:r.location];
    NSUInteger endIdx = NSMaxRange(r) - 1;
    NSUInteger endGlyph = [lm glyphIndexForCharacterAtIndex:endIdx];
    CGRect startRect = [lm boundingRectForGlyphRange:NSMakeRange(startGlyph, 1) inTextContainer:tc];
    CGRect endRect = [lm boundingRectForGlyphRange:NSMakeRange(endGlyph, 1) inTextContainer:tc];
    CGRect unionRect = CGRectUnion(startRect, endRect);
    return [self.textLbl convertRect:unionRect toView:nil];
}

/// 取 attr 里第一个/最后一个非 attachment 非换行字符之间的 range——即「真正的文字部分」。
/// 用于选区起点跳过领头 image attachment + 它前后的 \n（attributedStringForMessage 给图片
/// 块前后各补了一个 \n 用来视觉分行），结果是用户看到的 caption 文字范围。
/// 纯图消息（无任何 text block）→ 返回 length=0，由调用方退化到 selectAll。
+ (NSRange)_wkRichSelTextRangeInAttributedString:(NSAttributedString *)attr {
    if (attr.length == 0) return NSMakeRange(0, 0);
    NSString *s = attr.string;
    NSUInteger first = NSNotFound;
    for (NSUInteger i = 0; i < attr.length; i++) {
        id at = [attr attribute:NSAttachmentAttributeName atIndex:i effectiveRange:nil];
        unichar c = [s characterAtIndex:i];
        if (at) continue;
        if (c == '\n' || c == '\r' || c == ' ' || c == '\t') continue;
        first = i;
        break;
    }
    if (first == NSNotFound) return NSMakeRange(0, 0);
    NSUInteger last = first;
    for (NSInteger i = (NSInteger)attr.length - 1; i >= (NSInteger)first; i--) {
        id at = [attr attribute:NSAttachmentAttributeName atIndex:i effectiveRange:nil];
        unichar c = [s characterAtIndex:i];
        if (at) continue;
        if (c == '\n' || c == '\r' || c == ' ' || c == '\t') continue;
        last = i;
        break;
    }
    return NSMakeRange(first, last + 1 - first);
}

- (UIImage *)_wkRichSelImageWithColor:(UIColor *)color {
    CGRect r = CGRectMake(0, 0, 1, 1);
    UIGraphicsBeginImageContextWithOptions(r.size, NO, 0);
    [color setFill];
    UIRectFill(r);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (void)_wkRichSelMenuItemTapped:(UIButton *)btn {
    void (^action)(void) = objc_getAssociatedObject(btn, "wkRichSelBtnAction");
    if (action) action();
}

- (void)prepareForReuse {
    [super prepareForReuse];
    // cell 复用前确保退出选区，避免上一条消息的选区/菜单残留到新消息。
    [self endInBubbleTextSelection];
    // 同时清掉内容指纹——下个消息不论 hash 是否巧合相同都强制走完整 attributedText set
    // 路径，否则新消息会复用旧 attachments 的下载结果（不同 URL 显示同一张图）。
    objc_setAssociatedObject(self, &kRichTextLastRenderKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

// 选区激活期间禁掉 cell 自身的「长按出菜单」上下文手势：拖 native UITextView 选区句柄时
// 触摸会同时被 cell 的 OctoContextGesture 拿到（它认得是 long-press → 又弹一轮菜单 + 气泡
// 缩放反馈），与选区拖动撞车。WKTextMessageCell 用 wk_isInSelectionMode 守门同样的事，
// 这里复用 kRichTextSelActiveKey 标志，return NO 把上下文手势 begin 拦掉，让 textView
// 选区拿到完整 touch sequence。
- (BOOL)shouldBeginContextGestureAtPoint:(CGPoint)point {
    if (objc_getAssociatedObject(self, &kRichTextSelActiveKey)) {
        return NO;
    }
    return [super shouldBeginContextGestureAtPoint:point];
}

@end

#pragma mark - _WKRichSelOverlayView（透明罩，挂在 window 上接管 outside-tap）

@implementation _WKRichSelOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        [self addTarget:self action:@selector(_tapped) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    // passthroughView（textLbl）区域：让句柄/textView native gesture 拿到 touch。
    UIView *pt = self.passthroughView;
    BOOL inText = NO, inCard = NO;
    if (pt && pt.window) {
        CGRect inWindow = [pt convertRect:pt.bounds toView:self];
        // 上下额外放出 32pt，覆盖系统选区句柄（句柄会伸出 textLbl bounds 之外）。
        CGRect handleSafe = CGRectInset(inWindow, -4, -32);
        inText = CGRectContainsPoint(handleSafe, point);
    }
    // popup card 区域：让按钮自己拿 touch。
    UIWindow *win = self.window ?: [UIApplication sharedApplication].windows.firstObject;
    UIView *card = [win viewWithTag:kRichTextSelPopupTag];
    if (card) {
        CGRect cardInOverlay = [card convertRect:card.bounds toView:self];
        inCard = CGRectContainsPoint(cardInOverlay, point);
    }
    BOOL inside = !inText && !inCard;
    // 触摸（touchesBegan 类）才打日志；hover / hint 之类不打，否则日志洪流。
    if (event && event.type == UIEventTypeTouches) {
        UITouch *t = event.allTouches.anyObject;
        if (t && t.phase == UITouchPhaseBegan) {
            WKRichSelLog(@"[diag] overlay pointInside touch began at %@ → inText=%d inCard=%d inside=%d",
                         NSStringFromCGPoint(point), inText, inCard, inside);
        }
    }
    return inside;
}

- (void)_tapped {
    if (self.onTap) self.onTap();
}

@end
