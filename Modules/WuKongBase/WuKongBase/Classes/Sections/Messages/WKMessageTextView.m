//
//  WKMessageTextView.m
//  WuKongBase
//

#import "WKMessageTextView.h"
#import <objc/runtime.h>

static void *kWKMTVTokens = &kWKMTVTokens;

@implementation WKMessageTextView

- (instancetype)initWithFrame:(CGRect)frame textContainer:(nullable NSTextContainer *)textContainer {
    self = [super initWithFrame:frame textContainer:textContainer];
    if (self) {
        [self wk_configureDisplayOnly];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self wk_configureDisplayOnly];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self wk_configureDisplayOnly];
    }
    return self;
}

/// display-only 配置：外观与 UILabel 一致，默认不可选/不可编辑
/// UILabel(numberOfLines=0) 会忽略段落样式的 lineBreakMode 强制显示全部行；
/// UITextView 的 NSLayoutManager 会遵守段落样式的 lineBreakMode，
/// 导致 Down/markdown 渲染出的 TruncatingTail 段落被截断。
/// 重写 setAttributedText: 将所有段落样式归一化为 WordWrapping。
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText || attributedText.length == 0) {
        [super setAttributedText:attributedText];
        return;
    }
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

#pragma mark - touch delegate（参考 Android CursorHandle.onTouchEvent ACTION_MOVE/UP）

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    if (self.selectable) [self.selDelegate selectionTVTouchBegan];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    if (self.selectable) [self.selDelegate selectionTVTouchEnded];
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    if (self.selectable) [self.selDelegate selectionTVTouchEnded];
}

#pragma mark - 禁止系统 UIMenuController（文字选择菜单由我们自定义）

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    return NO; // 屏蔽系统菜单，由外部自定义网格菜单处理
}

- (BOOL)canBecomeFirstResponder {
    return self.selectable; // 只有开启选择时才允许成为 first responder
}

@end
