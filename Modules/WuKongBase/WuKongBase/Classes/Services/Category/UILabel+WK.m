// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  UILabel+WK.m
//  WuKongBase
//
//  Created by tt on 2021/7/27.
//

#import "UILabel+WK.h"
#import <objc/runtime.h>
#import <WuKongBase/WuKongBase-Swift.h>
static void * kClick = &kClick;
static void * kTokens = &kTokens;

@implementation UILabel (WK)

- (NSArray<id<WKMatchToken>> *)tokens {
    return objc_getAssociatedObject(self, kTokens);
}

-(void) setTokens:(NSArray<id<WKMatchToken>>*)tokens {
    return objc_setAssociatedObject(self, kTokens, tokens, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(void) setClick:(void(^)(id<WKMatchToken>))click {
    objc_setAssociatedObject(self, kClick, click, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

-(void(^)(id<WKMatchToken>)) click {
    return objc_getAssociatedObject(self, kClick);
}

-(void) onClick:(void(^)(id<WKMatchToken>))click {
    self.click = click;

    self.userInteractionEnabled = YES;
    [self removeAllGestureRecognizers];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    [self addGestureRecognizer:tap];
}

-(void) removeAllGestureRecognizers {
    NSArray *gestures = self.gestureRecognizers;
    if(gestures && gestures.count>0) {
        for (UITapGestureRecognizer *gesture in gestures) {
            [self removeGestureRecognizer:gesture];
        }
    }
}

-(void) onTap:(UITapGestureRecognizer*)gesture {
   id<WKMatchToken> token =  [self didTapAttributedTextInLabel:gesture];
    if(token) {
        if(self.click) {
            self.click(token);
        }
    }
}

#pragma mark - 共享UITextView用于精确点击检测

/// 获取共享的UITextView用于点击位置检测
/// 参考Android的LinkMovementMethod方案：使用文本视图自身的布局引擎做命中测试，
/// 避免UILabel内部布局与手动创建的NSLayoutManager之间的不一致问题
+(UITextView*) sharedHitTestTextView {
    static UITextView *textView;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        textView = [[UITextView alloc] init];
        textView.editable = NO;
        textView.scrollEnabled = NO;
        textView.textContainerInset = UIEdgeInsetsZero;
        textView.textContainer.lineFragmentPadding = 0;
    });
    return textView;
}

/// 使用UITextView的layoutManager精确查找点击位置对应的token
-(id<WKMatchToken>) findTokenAtPoint:(CGPoint)point {
    if(!self.tokens || self.tokens.count == 0) {
        return nil;
    }
    UILabel *label = self;
    NSAttributedString *attrText = label.attributedText;
    if(!attrText || attrText.length == 0) {
        return nil;
    }

    // 配置共享UITextView，使其布局与label一致
    UITextView *tv = [[self class] sharedHitTestTextView];
    tv.attributedText = attrText;
    tv.frame = CGRectMake(0, 0, label.bounds.size.width, label.bounds.size.height);
    tv.textContainer.maximumNumberOfLines = label.numberOfLines;
    tv.textContainer.lineBreakMode = label.lineBreakMode;

    NSLayoutManager *layoutManager = tv.layoutManager;
    NSTextContainer *textContainer = tv.textContainer;

    // 强制完成布局
    [layoutManager ensureLayoutForTextContainer:textContainer];

    // 遍历每个可点击的token，检查点击点是否落在其glyph区域内
    for (id<WKMatchToken> token in self.tokens) {
        if(token.type != WKatchTokenTypeLink &&
           token.type != WKatchTokenTypeLink2 &&
           token.type != WKatchTokenTypeMetion) {
            continue;
        }
        if(token.range.location + token.range.length > attrText.length) {
            continue;
        }

        NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:token.range actualCharacterRange:nil];

        // 枚举token对应的每个行片段矩形（处理跨行的情况）
        __block BOOL hit = NO;
        [layoutManager enumerateEnclosingRectsForGlyphRange:glyphRange
                                   withinSelectedGlyphRange:NSMakeRange(NSNotFound, 0)
                                            inTextContainer:textContainer
                                                 usingBlock:^(CGRect rect, BOOL *stop) {
            // 扩大2pt容差，让点击更容易命中
            CGRect expandedRect = CGRectInset(rect, -2, -2);
            if(CGRectContainsPoint(expandedRect, point)) {
                hit = YES;
                *stop = YES;
            }
        }];

        if(hit) {
            return token;
        }
    }
    return nil;
}

#pragma mark - 公开的点击检测方法

-(id<WKMatchToken>) didTapAttributedTextInLabel:(UITapGestureRecognizer *)tapGesture {
    CGPoint point = [tapGesture locationInView:self];
    return [self findTokenAtPoint:point];
}

-( id<WKMatchToken>) matchDidTapAttributedTextInLabelWithPoint:(CGPoint)locationOfTouchInLabel {
    return [self findTokenAtPoint:locationOfTouchInLabel];
}

- (BOOL)didTapAttributedTextInLabel:(UITapGestureRecognizer *)tapGesture inRange:(NSRange)targetRange {
    id<WKMatchToken> token = [self didTapAttributedTextInLabel:tapGesture];
    if(token && NSEqualRanges(token.range, targetRange)) {
        return YES;
    }
    return NO;
}

@end
