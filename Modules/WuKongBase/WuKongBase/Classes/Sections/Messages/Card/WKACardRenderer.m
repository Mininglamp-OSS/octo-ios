//
//  WKACardRenderer.m
//  WuKongBase
//

#import "WKACardRenderer.h"
#import "WKACardHostConfig.h"
#import <AdaptiveCards/ACRRenderer.h>
#import <AdaptiveCards/ACRRenderResult.h>
#import <AdaptiveCards/ACRView.h>
#import <AdaptiveCards/ACOAdaptiveCard.h>
#import <AdaptiveCards/ACOAdaptiveCardParseResult.h>
#import <AdaptiveCards/ACOHostConfig.h>
#import <AdaptiveCards/ACOEnums.h>

@implementation WKACardRenderResult
@end

@implementation WKACardRenderer

+ (NSCache<NSString *, NSNumber *> *)measureCache {
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSCache new];
        cache.countLimit = 500;
    });
    return cache;
}

+ (NSString *)cardJSONString:(NSDictionary *)cardJSON {
    if (![cardJSON isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:cardJSON options:0 error:nil];
    if (!data) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (NSString *)measureKeyForFingerprint:(NSString *)fp width:(CGFloat)width dark:(BOOL)dark {
    return [NSString stringWithFormat:@"%@|w%.0f|d%d", fp ?: @"", width, dark ? 1 : 0];
}

+ (WKACardRenderResult *)renderCard:(NSDictionary *)cardJSON
                              width:(CGFloat)width
                               dark:(BOOL)dark
                           delegate:(id<ACRActionDelegate>)delegate {
    WKACardRenderResult *out = [WKACardRenderResult new];
    out.succeeded = NO;
    out.size = CGSizeMake(width, 0);

    // [octo] Q2/Q3：把 Input.ChoiceSet 一律渲染成 expanded(内联单选列表)。ACR 的 compact
    // 下拉是把选项列表 [window addSubview]，样式差且不随会话页 VC 消失(关页面残留)。
    // expanded 已跑通(圆圈+选中+提交),彻底绕开那个 window 浮层。
    NSDictionary *effectiveCard = [self wk_cardByForcingExpandedChoiceSets:cardJSON];
    NSString *payload = [self cardJSONString:effectiveCard];
    if (payload.length == 0) {
        return out;
    }

    ACOAdaptiveCardParseResult *parse = [ACOAdaptiveCard fromJson:payload];
    if (!parse.isValid || !parse.card) {
        return out;
    }
    out.card = parse.card;

    ACOHostConfig *config = [WKACardHostConfig hostConfigForDark:dark];
    ACRTheme theme = dark ? ACRThemeDark : ACRThemeLight;

    ACRRenderResult *result = nil;
    @try {
        if (delegate) {
            result = [ACRRenderer render:parse.card config:config widthConstraint:width delegate:delegate theme:theme];
        } else {
            result = [ACRRenderer render:parse.card config:config widthConstraint:width theme:theme];
        }
    } @catch (NSException *ex) {
        result = nil;
    }

    if (!result || !result.succeeded || !result.view) {
        return out;
    }

    out.view = result.view;
    out.succeeded = YES;
    // [octo] 修复 ACR 系统性把 FactSet 渲染成 hidden 的 bug（configVisibility 基于
    // GetIsVisible 误隐藏 FactSet 的 ACRColumnSetView；web 用另一套 JS SDK 不受影响）。
    // 在测高前 un-hide，让 UIStackView 重排、高度正确。
    [self wk_unhideHiddenFactSetsInView:result.view];
    out.size = [self fittingSizeOfView:result.view width:width];
    return out;
}

+ (void)wk_unhideHiddenFactSetsInView:(UIView *)view {
    if (!view) return;
    for (UIView *sub in view.subviews) {
        if (sub.hidden && [NSStringFromClass([sub class]) isEqualToString:@"ACRColumnSetView"]) {
            sub.hidden = NO;
        }
        [self wk_unhideHiddenFactSetsInView:sub];
    }
}

/// 返回渲染前 sanitize 过的卡片深拷贝(不改原字典)：
/// - Q2/Q3：Input.ChoiceSet 的 style 一律改 expanded(绕开 ACR 的 window 浮层下拉)。
/// - Q1：Input.Toggle 缺 title 时补上(AC 的 title 必填且不能空，否则整卡解析失败
///   RequiredPropertyMissing；web 的 JS SDK 宽松所以能显示)。用 label 提升为 title
///   并移除 label 避免重复，无 label 则兜底。
+ (NSDictionary *)wk_cardByForcingExpandedChoiceSets:(NSDictionary *)cardJSON {
    id transformed = [self wk_sanitizeNode:cardJSON];
    return [transformed isKindOfClass:[NSDictionary class]] ? transformed : cardJSON;
}

+ (id)wk_sanitizeNode:(id)node {
    if ([node isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *m = [NSMutableDictionary dictionaryWithCapacity:[node count]];
        for (id key in (NSDictionary *)node) {
            m[key] = [self wk_sanitizeNode:((NSDictionary *)node)[key]];
        }
        id type = m[@"type"];
        if ([type isKindOfClass:[NSString class]]) {
            if ([type isEqualToString:@"Input.ChoiceSet"]) {
                m[@"style"] = @"expanded";
            } else if ([type isEqualToString:@"Input.Toggle"]) {
                NSString *title = [m[@"title"] isKindOfClass:[NSString class]] ? m[@"title"] : nil;
                if (title.length == 0) {
                    NSString *label = [m[@"label"] isKindOfClass:[NSString class]] ? m[@"label"] : nil;
                    if (label.length > 0) {
                        m[@"title"] = label;
                        [m removeObjectForKey:@"label"];  // 提升为 title，避免与上方 label 重复
                    } else {
                        m[@"title"] = @"开关";
                    }
                }
            }
        }
        return m;
    }
    if ([node isKindOfClass:[NSArray class]]) {
        NSMutableArray *a = [NSMutableArray arrayWithCapacity:[(NSArray *)node count]];
        for (id item in (NSArray *)node) {
            [a addObject:[self wk_sanitizeNode:item]];
        }
        return a;
    }
    return node;
}

+ (CGSize)fittingSizeOfView:(ACRView *)view width:(CGFloat)width {
    if (!view) {
        return CGSizeMake(width, 0);
    }
    // 先在目标宽度下强制布局一遍，让文本按真实宽度换行（否则 FactSet/RichText 的
    // 换行高度会被低估，导致卡片底部被裁 —— #1 内容不全的根因）。
    view.frame = CGRectMake(0, 0, width, 100000);
    [view setNeedsLayout];
    [view layoutIfNeeded];

    // 1) Auto Layout 拟合高度
    CGSize fit = [view systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                     withHorizontalFittingPriority:UILayoutPriorityRequired
                           verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGFloat fitH = ceil(fit.height);

    // 2) 实际子视图并集底部（防止 systemLayout 低估某些 ACR 元素的高度）
    CGFloat unionBottom = 0;
    for (UIView *sub in view.subviews) {
        if (sub.hidden) continue;
        unionBottom = MAX(unionBottom, CGRectGetMaxY(sub.frame));
    }
    unionBottom = ceil(unionBottom);

    CGFloat h = MAX(fitH, unionBottom);
    if (h <= 0) {
        h = ceil(view.frame.size.height);
    }
    return CGSizeMake(width, h);
}

+ (CGSize)measureCard:(NSDictionary *)cardJSON
                width:(CGFloat)width
                 dark:(BOOL)dark
          fingerprint:(NSString *)fingerprint {
    if (width <= 0 || ![cardJSON isKindOfClass:[NSDictionary class]]) {
        return CGSizeMake(MAX(width, 0), 0);
    }
    NSString *key = [self measureKeyForFingerprint:fingerprint width:width dark:dark];
    NSNumber *cached = [[self measureCache] objectForKey:key];
    if (cached) {
        return CGSizeMake(width, cached.doubleValue);
    }

    // ACR 渲染需在主线程创建 UIView
    __block CGSize measured = CGSizeMake(width, 0);
    void (^work)(void) = ^{
        WKACardRenderResult *r = [self renderCard:cardJSON width:width dark:dark delegate:nil];
        measured = r.size;
    };
    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_sync(dispatch_get_main_queue(), work);
    }

    if (measured.height > 0) {
        [[self measureCache] setObject:@(measured.height) forKey:key];
    }
    return measured;
}

+ (void)invalidateMeasureForFingerprint:(NSString *)fingerprint {
    if (fingerprint.length == 0) {
        return;
    }
    // 指纹前缀匹配的 key 无法逐一枚举（NSCache 不支持遍历），改为整体清空。
    // 卡片编辑属低频事件，清空测量缓存代价可接受（下次显示重算）。
    [[self measureCache] removeAllObjects];
}

@end
