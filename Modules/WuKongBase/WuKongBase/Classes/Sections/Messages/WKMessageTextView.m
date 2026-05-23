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
- (instancetype)initWithFrame:(CGRect)frame textContainer:(nullable NSTextContainer *)textContainer {
    // 显式传入 textContainer 即走 TextKit 1（NSTextContainer 是 TextKit 1 类型），
    // 直接走父类指定初始化器即可。
    self = [super initWithFrame:frame textContainer:textContainer];
    if (self) {
        [self wk_configureDisplayOnly];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (@available(iOS 16.0, *)) {
        self = [super initUsingTextLayoutManager:NO];
        if (self) {
            self.frame = frame;
            [self wk_configureDisplayOnly];
        }
        return self;
    }
    self = [super initWithFrame:frame];
    if (self) {
        [self wk_configureDisplayOnly];
    }
    return self;
}

- (instancetype)init {
    if (@available(iOS 16.0, *)) {
        self = [super initUsingTextLayoutManager:NO];
    } else {
        self = [super init];
    }
    if (self) {
        [self wk_configureDisplayOnly];
    }
    return self;
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
