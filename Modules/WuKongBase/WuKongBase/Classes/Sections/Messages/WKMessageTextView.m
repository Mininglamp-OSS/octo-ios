//
//  WKMessageTextView.m
//  WuKongBase
//

#import "WKMessageTextView.h"
#import <objc/runtime.h>

static void *kWKMTVTokens = &kWKMTVTokens;

@implementation WKMessageTextView

// iOS 16+ 显式声明使用 TextKit 1（不通过 NSTextLayoutManager），避免运行时
// 从 TextKit 2 热切换到 TextKit 1 — 该热切换会在快速滑动 + 大量新建 cell 时
// 造成首帧 glyph 漏画，表现为「气泡正常占高、内容一片空白」。
//
// 实现方式：构造一个由 NSLayoutManager 拥有的 NSTextContainer（即 TextKit 1
// stack），通过 -initWithFrame:textContainer: 注入。UITextView 看到 textContainer
// 的 layoutManager 是 NSLayoutManager（而不是 NSTextLayoutManager），就一定走
// TextKit 1，不会再走默认的 TextKit 2。
//
// 不能用 +textViewUsingTextLayoutManager: — 那是工厂类方法返回裸 UITextView，
// 无法被子类化；也不能用 -initUsingTextLayoutManager:（UITextView 上不存在该
// 实例方法）。
+ (NSTextContainer *)wk_makeTextKit1Container {
    NSTextStorage *ts = [[NSTextStorage alloc] init];
    NSLayoutManager *lm = [[NSLayoutManager alloc] init];
    [ts addLayoutManager:lm];
    NSTextContainer *tc = [[NSTextContainer alloc] initWithSize:CGSizeZero];
    [lm addTextContainer:tc];
    return tc;
}

- (instancetype)initWithFrame:(CGRect)frame textContainer:(nullable NSTextContainer *)textContainer {
    // caller 没给 textContainer 时，自己造一个 TextKit 1 container 注入，
    // 否则父类会在 iOS 16+ 默认构造 TextKit 2 stack（NSTextLayoutManager）。
    if (!textContainer) {
        textContainer = [WKMessageTextView wk_makeTextKit1Container];
    }
    self = [super initWithFrame:frame textContainer:textContainer];
    if (self) {
        [self wk_configureDisplayOnly];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame textContainer:nil];
}

- (instancetype)init {
    return [self initWithFrame:CGRectZero textContainer:nil];
}

/// display-only 配置：外观与 UILabel 一致，默认不可选/不可编辑
/// UILabel(numberOfLines=0) 会忽略段落样式的 lineBreakMode 强制显示全部行；
/// UITextView 的 NSLayoutManager 会遵守段落样式的 lineBreakMode，
/// 导致 markdown (cmark-gfm) 渲染出的 TruncatingTail 段落被截断。
/// 重写 setAttributedText: 将所有段落样式归一化为 WordWrapping。
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText || attributedText.length == 0) {
        [super setAttributedText:attributedText];
        return;
    }
    attributedText = [attributedText copy];
    __block BOOL needsNormalize = NO;
    [attributedText enumerateAttribute:NSParagraphStyleAttributeName
                               inRange:NSMakeRange(0, attributedText.length)
                               options:0
                            usingBlock:^(NSParagraphStyle *style, NSRange range, BOOL *stop) {
        if (style && style.lineBreakMode != NSLineBreakByWordWrapping) {
            needsNormalize = YES;
            *stop = YES;
        }
    }];
    if (!needsNormalize) {
        [super setAttributedText:attributedText];
        return;
    }
    NSMutableAttributedString *normalized = [attributedText mutableCopy];
    [normalized enumerateAttribute:NSParagraphStyleAttributeName
                           inRange:NSMakeRange(0, normalized.length)
                           options:0
                        usingBlock:^(NSParagraphStyle *style, NSRange range, BOOL *stop) {
        if (style && style.lineBreakMode != NSLineBreakByWordWrapping) {
            NSMutableParagraphStyle *newStyle = [style mutableCopy];
            newStyle.lineBreakMode = NSLineBreakByWordWrapping;
            [normalized addAttribute:NSParagraphStyleAttributeName value:newStyle range:range];
        }
    }];
    [super setAttributedText:normalized];
}

- (void)wk_configureDisplayOnly {
    self.editable         = NO;
    self.selectable       = NO;   // 默认不可选，等同 UILabel；长按时按需开启
    self.scrollEnabled    = NO;
    self.backgroundColor  = [UIColor clearColor];
    self.textContainerInset = UIEdgeInsetsZero;
    // iOS 16+ 由 initUsingTextLayoutManager:NO 在创建时确定走 TextKit 1，
    // 不再通过访问 layoutManager 触发运行时热切换（旧实现会在快速滑动 +
    // 大量新建 cell 时造成首帧 glyph 漏画导致气泡空白）。
    // iOS 15- 默认就是 TextKit 1，无需额外动作。
    self.textContainer.lineFragmentPadding    = 0;
    self.textContainer.maximumNumberOfLines   = 0;  // 对应 UILabel.numberOfLines = 0
    self.textContainer.lineBreakMode          = NSLineBreakByWordWrapping;
    self.showsVerticalScrollIndicator   = NO;
    self.showsHorizontalScrollIndicator = NO;
    // 关闭链接长按预览（防止与消息长按冲突）
    self.allowsEditingTextAttributes = NO;
    if (@available(iOS 16.0, *)) {
        self.findInteractionEnabled = NO;
    }
}

#pragma mark - tokens（关联对象，与 UILabel+WK 接口一致）

- (NSArray<id<WKMatchToken>> *)tokens {
    return objc_getAssociatedObject(self, kWKMTVTokens);
}

- (void)setTokens:(NSArray<id<WKMatchToken>> *)tokens {
    objc_setAssociatedObject(self, kWKMTVTokens, tokens, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 点击命中检测（使用自身 layoutManager，无需外部共享 UITextView）

- (nullable id<WKMatchToken>)matchDidTapAttributedTextInLabelWithPoint:(CGPoint)point {
    if (!self.tokens || self.tokens.count == 0) return nil;
    NSAttributedString *attrText = self.attributedText;
    if (!attrText || attrText.length == 0) return nil;

    NSLayoutManager  *lm = self.layoutManager;
    NSTextContainer  *tc = self.textContainer;
    [lm ensureLayoutForTextContainer:tc];

    for (id<WKMatchToken> token in self.tokens) {
        WKatchTokenType type = token.type;
        if (type != WKatchTokenTypeLink &&
            type != WKatchTokenTypeLink2 &&
            type != WKatchTokenTypeMetion) {
            continue;
        }
        NSRange range = token.range;
        if (range.location + range.length > attrText.length) continue;

        NSRange glyphRange = [lm glyphRangeForCharacterRange:range actualCharacterRange:nil];
        __block BOOL hit = NO;
        [lm enumerateEnclosingRectsForGlyphRange:glyphRange
                         withinSelectedGlyphRange:NSMakeRange(NSNotFound, 0)
                                  inTextContainer:tc
                                       usingBlock:^(CGRect rect, BOOL *stop) {
            if (CGRectContainsPoint(CGRectInset(rect, -2, -2), point)) {
                hit = YES; *stop = YES;
            }
        }];
        if (hit) return token;
    }
    return nil;
}

// 不再使用系统选区 UI — 自定义句柄方案不需要 hitTest/pointInside/touch delegate 重写

@end
