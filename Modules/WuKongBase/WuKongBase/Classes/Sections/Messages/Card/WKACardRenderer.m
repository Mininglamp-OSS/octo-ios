//
//  WKACardRenderer.m
//  WuKongBase
//

#import "WKACardRenderer.h"
#import "WKACardHostConfig.h"
#import <os/lock.h>
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

// ───────── 主线程耗时聚合探针 ─────────
// 关掉：把 WKPerfProbeOn 置 NO。按 label 累计 (count/总耗时/最大单次)，每 ~1s dump 一行，
// 避免 per-call 刷屏，并能一眼看出哪个组件×阶段吃主线程。
static const BOOL WKPerfProbeOn = NO;
+ (void)perfAccrue:(NSString *)label ms:(double)ms {
    if (!WKPerfProbeOn || label.length == 0) return;
    static NSMutableDictionary<NSString *, NSMutableArray<NSNumber *> *> *acc; // label -> [count,totalMs,maxMs]
    static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
    static CFTimeInterval lastDump = 0;
    os_unfair_lock_lock(&lock);
    if (!acc) acc = [NSMutableDictionary dictionary];
    NSMutableArray<NSNumber *> *e = acc[label];
    if (!e) { e = [@[@0, @0.0, @0.0] mutableCopy]; acc[label] = e; }
    e[0] = @(e[0].integerValue + 1);
    e[1] = @(e[1].doubleValue + ms);
    e[2] = @(MAX(e[2].doubleValue, ms));
    CFTimeInterval now = CACurrentMediaTime();
    if (lastDump == 0) lastDump = now;
    if (now - lastDump >= 1.0) {
        NSArray *keys = [acc.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            return [acc[b][1] compare:acc[a][1]]; // 总耗时降序
        }];
        NSMutableString *s = [NSMutableString stringWithFormat:@"[WKPerfProbe/%.1fs]", now - lastDump];
        for (NSString *k in keys) {
            NSMutableArray<NSNumber *> *v = acc[k];
            [s appendFormat:@" | %@ n=%@ sum=%.0f max=%.1f", k, v[0], v[1].doubleValue, v[2].doubleValue];
        }
        NSLog(@"%@", s);
        [acc removeAllObjects];
        lastDump = now;
    }
    os_unfair_lock_unlock(&lock);
}

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
    return [self renderCard:cardJSON width:width dark:dark delegate:delegate measureSize:YES];
}

/// 给 ACR 视图树构建/测高提供一个**显式的 current trait collection**。
///
/// 为什么必须有（现网 EXC_BAD_ACCESS 根因，build 74 独有，5 份同栈）:
///
/// ACR 的视图树是 windowless 构建的 —— `ACRRenderer render:` 建树、`fittingSizeOfView:`
/// 用 100000 高强制 layout，全程没有 superview / window。而树里到处是**动态颜色**:
/// 我们自己的 WKCardAccent.h(`+[UIColor colorWithDynamicProvider:]`)、以及 UIKit 自带的
/// 系统色(UILabel.textColor / UISwitch.onTintColor / systemBackground 等全是动态的)。
/// 动态色必须对着一个 trait collection 求值; 既没有 window 可以往上找, 也没有 current
/// trait collection, UIKit 就退到
/// `+[UITraitCollection _currentTraitCollectionWithFallback:markFallback:]`
/// → `_UIGetCurrentFallbackTraitCollection` (文件名 `_UIFallbackEnvironment_NonARC.m`,
/// NonARC = 那个全局是**不持有**的裸指针)。视图树随后被整棵丢弃, 全局就成了野指针;
/// 下一个无辜的读者(`[WKConversationVC new]` 的 `_populateInitialTraitCollection`、
/// 会话列表 reloadData 求默认行高的 `__UIFontForTextStyle`)一 objc_msgSend 就 SIGSEGV
/// (报告里的 "possible pointer authentication failure" 即 isa 已被复用覆盖)。
///
/// `performAsCurrentTraitCollection:` 会压入一个**真实存在且被持有**的 current trait
/// collection, UIKit 于是根本不会去碰那个 fallback 全局。
///
/// 顺带修正一处隐性错误: 之前 windowless 求值时 fallback 命中的是"系统当前外观",
/// 与本次渲染显式传入的 `dark:` 可能相反 —— 深色卡片有可能拿浅色动态色求值。
/// 这里用 dark 构造 trait collection, 让动态色与 host config / ACRTheme 三者一致。
+ (UITraitCollection *)wk_traitCollectionForDark:(BOOL)dark {
    UITraitCollection *styleTC =
        [UITraitCollection traitCollectionWithUserInterfaceStyle:(dark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight)];

    // 以真实 key window 的 traits 为底，只覆盖 userInterfaceStyle —— 这样动态字号
    // (preferredContentSizeCategory)、size class、displayScale 等都保持用户的真实值。
    // 若只用 traitCollectionWithUserInterfaceStyle:，其余维度是 Unspecified，会退到
    // 默认值(如字号按 Large 算)，卡片高度可能与真机外观不一致。
    // 注意: UITraitCollection 是不可变值对象，持有它不会持有 window，不会造成循环引用。
    UITraitCollection *base = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        for (UIWindow *w in ws.windows) {
            if (w.isKeyWindow) { base = w.traitCollection; break; }
        }
        if (!base) base = ws.traitCollection;
        if (base) break;
    }
    if (!base) return styleTC;
    // 后面的集合覆盖前面的同名 trait，故 styleTC 放最后。
    return [UITraitCollection traitCollectionWithTraitsFromCollections:@[base, styleTC]];
}

+ (WKACardRenderResult *)renderCard:(NSDictionary *)cardJSON
                              width:(CGFloat)width
                               dark:(BOOL)dark
                           delegate:(id<ACRActionDelegate>)delegate
                        measureSize:(BOOL)measureSize {
    // 整个建树 + 测高都必须在 current trait collection 内（见
    // wk_traitCollectionForDark: 的注释）。展示路径同样要包 —— 视图是在
    // `ACRRenderer render:` 里建好之后才被塞进 cell 的，建树那一刻它也还是 windowless。
    //
    // performAsCurrentTraitCollection: 要求主线程。本方法的两个调用方都已保证:
    // +measureCard 非主线程时 dispatch_sync 到主线程; 展示路径由 cell 的 refresh: 调用。
    if (![NSThread isMainThread]) {
        __block WKACardRenderResult *r = nil;
        dispatch_sync(dispatch_get_main_queue(), ^{
            r = [self renderCard:cardJSON width:width dark:dark delegate:delegate measureSize:measureSize];
        });
        return r;
    }
    __block WKACardRenderResult *result = nil;
    [[self wk_traitCollectionForDark:dark] performAsCurrentTraitCollection:^{
        result = [self wk_renderCardUnderCurrentTraits:cardJSON width:width dark:dark delegate:delegate measureSize:measureSize];
    }];
    return result;
}

+ (WKACardRenderResult *)wk_renderCardUnderCurrentTraits:(NSDictionary *)cardJSON
                                                   width:(CGFloat)width
                                                    dark:(BOOL)dark
                                                delegate:(id<ACRActionDelegate>)delegate
                                             measureSize:(BOOL)measureSize {
    WKACardRenderResult *out = [WKACardRenderResult new];
    out.succeeded = NO;
    out.size = CGSizeMake(width, 0);

    CFTimeInterval __tSanitize = CACurrentMediaTime();
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
    CFTimeInterval __tParse = CACurrentMediaTime();
    [WKACardRenderer perfAccrue:@"card.parse(C++)" ms:(__tParse - __tSanitize) * 1000.0];

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
    CFTimeInterval __tRender = CACurrentMediaTime();
    // 建 ACR 视图树耗时(主线程；无论 heightForRow-main 还是 precache 的 dispatch_sync-main)。
    [WKACardRenderer perfAccrue:@"card.build(ACR树)" ms:(__tRender - __tParse) * 1000.0];

    out.view = result.view;
    out.succeeded = YES;
    // [octo] 修复 ACR 系统性把 FactSet 渲染成 hidden 的 bug（configVisibility 基于
    // GetIsVisible 误隐藏 FactSet 的 ACRColumnSetView；web 用另一套 JS SDK 不受影响）。
    // 在测高前 un-hide，让 UIStackView 重排、高度正确。
    [self wk_unhideHiddenFactSetsInView:result.view];
    // 展示路径 measureSize=NO：跳过 fittingSizeOfView（~6ms 的 100000-layout），行高由
    // +measureCard 缓存供给、result.size 不被读取。测高路径 measureSize=YES 才测。
    if (!measureSize) {
        return out;
    }
    out.size = [self fittingSizeOfView:result.view width:width];
    CFTimeInterval __tMeasure = CACurrentMediaTime();
    [WKACardRenderer perfAccrue:@"card.layout(测高)" ms:(__tMeasure - __tRender) * 1000.0];
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
    // cache MISS：这里会同步渲一个 ACRView 量高再丢弃(很贵)。若非主线程还会 dispatch_sync 到
    // 主线程阻塞。大量卡片 miss(如首次滑入/回前台)会集中打主线程。按“是否在主线程 miss”分标签。
    BOOL __onMain = [NSThread isMainThread];
    CFTimeInterval __t0 = CACurrentMediaTime();
    __block CGSize measured = CGSizeMake(width, 0);
    void (^work)(void) = ^{
        WKACardRenderResult *r = [self renderCard:cardJSON width:width dark:dark delegate:nil];
        measured = r.size;
    };
    if (__onMain) {
        work();
    } else {
        dispatch_sync(dispatch_get_main_queue(), work);
    }
    [WKACardRenderer perfAccrue:(__onMain ? @"card.measureCard.MISS(主线程直算)"
                                          : @"card.measureCard.MISS(precache→主线程)")
                             ms:(CACurrentMediaTime() - __t0) * 1000.0];

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
