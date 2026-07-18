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

    NSString *payload = [self cardJSONString:cardJSON];
    if (payload.length == 0) {
        return out;
    }

    ACOAdaptiveCardParseResult *parse = [ACOAdaptiveCard fromJson:payload];
    if (!parse.isValid || !parse.card) {
        NSLog(@"[WKCard][DIAG] parse invalid=%d errors=%@", !parse.isValid, parse.parseErrors);
        return out;
    }
    out.card = parse.card;
    // [WKCard][DIAG] 解析告警（掉元素/未知类型会在这里体现，定位 #1 内容不全）
    if (parse.parseWarnings.count > 0) {
        NSMutableArray *ws = [NSMutableArray array];
        for (id w in parse.parseWarnings) { [ws addObject:[w description] ?: @"?"]; }
        NSLog(@"[WKCard][DIAG] parseWarnings(%lu)=%@", (unsigned long)parse.parseWarnings.count, ws);
    }

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

/// 递归 un-hide 被 ACR 误隐藏的 FactSet(渲染为 ACRColumnSetView)。
/// 仅动 ACRColumnSetView：octo 卡片里唯一被误隐藏的就是 FactSet；显式 ColumnSet 均可见。
/// Agent 卡的 timeline_detail 是 ACRColumnView(容器)且默认折叠，不在此列，不受影响。
+ (void)wk_unhideHiddenFactSetsInView:(UIView *)view {
    if (!view) return;
    for (UIView *sub in view.subviews) {
        if (sub.hidden && [NSStringFromClass([sub class]) isEqualToString:@"ACRColumnSetView"]) {
            sub.hidden = NO;
        }
        [self wk_unhideHiddenFactSetsInView:sub];
    }
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
    if (fabs(fitH - unionBottom) > 1.0) {
        NSLog(@"[WKCard][DIAG] fittingSize mismatch fit=%.1f union=%.1f use=%.1f w=%.1f", fitH, unionBottom, h, width);
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
