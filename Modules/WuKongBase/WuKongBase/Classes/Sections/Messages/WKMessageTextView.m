//
//  WKMessageTextView.m
//  WuKongBase
//

#import "WKMessageTextView.h"
#import <objc/runtime.h>

static void *kWKMTVTokens = &kWKMTVTokens;

@implementation WKMessageTextView

// iOS 16+ UITextView 默认 TextKit 2，但本类的高度测量、点击命中、段落样式
// 归一化都假定 TextKit 1（NSLayoutManager / NSTextContainer 路径）。需要让
// 实例稳定回落到 TK1。
//
// 历史尝试（都失败）:
//   1) 旧实现：访问 self.layoutManager 触发 TK2→TK1 热切换 → 工作但偶发首
//      帧空白（快速滑动 + 大量新建 cell 时 glyph 漏画）。
//   2) 自建 TextStorage/LayoutManager/TextContainer 通过
//      -initWithFrame:textContainer: 注入 → iOS 26.4.2 上 super init 内部
//      _UITextKit1LayoutController 仍断言 "text container must already
//      have a layout manager"，无论 ts/lm 是否还活着。Apple 头文件唯一
//      官方 TK1 入口是类工厂 +textViewUsingTextLayoutManager:，无法被
//      子类化继承到 -initWithFrame:textContainer: 路径。
//
// 取舍：方案 1 的"首帧空白"是渲染瑕疵，方案 2 是硬崩。回到方案 1，并把
// 热切换的触发集中在构造完成后的 wk_configureDisplayOnly 里 — 不在 super
// init 期间 fiddle with textContainer。首帧空白若真复发，单独通过
// setAttributedText: 后强制 ensureLayoutForTextContainer: 修复。
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
    // 强制让 TK2 fallback 到 TK1：iOS 16+ 默认 TK2，读取 layoutManager 会触发
    // UIKit 内部用新 NSLayoutManager 替换 NSTextLayoutManager（Apple UITextView.h
    // 第 273 行明确文档此行为）。本类的高度测量 / 命中检测 / 段落样式归一化
    // 都基于 TK1 的 NSLayoutManager + NSTextContainer 路径，必须在所有实例上
    // 统一切到 TK1，否则测量（TK1）和显示（TK2）会不一致。
    //
    // 不在 super init 期间通过传 textContainer 强制 TK1 — 那条路径在 iOS 26.4.2
    // 上必崩 _UITextKit1LayoutController（详见类顶部注释）。
    (void)self.layoutManager;
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
