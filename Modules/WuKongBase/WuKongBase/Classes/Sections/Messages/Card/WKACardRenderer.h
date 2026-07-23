//
//  WKACardRenderer.h
//  WuKongBase
//
//  Adaptive Cards 渲染 / 测量封装（基于 vendored MIT ACRRenderer）。
//  注意：ACR 渲染会创建 UIView，必须在主线程调用。
//
#import <UIKit/UIKit.h>
#import <AdaptiveCards/ACRActionDelegate.h>

@class ACRView;
@class ACOAdaptiveCard;

NS_ASSUME_NONNULL_BEGIN

@interface WKACardRenderResult : NSObject
@property(nonatomic,strong,nullable) ACRView *view;      // 渲染出的卡片视图
@property(nonatomic,strong,nullable) ACOAdaptiveCard *card; // 解析后的卡片（收集 inputs 用）
@property(nonatomic,assign) BOOL succeeded;
@property(nonatomic,assign) CGSize size;
@end

@interface WKACardRenderer : NSObject

/// 渲染卡片为可展示的 ACRView（主线程）。delegate 处理 Action.Submit/OpenUrl 等。
+ (WKACardRenderResult *)renderCard:(NSDictionary *)cardJSON
                              width:(CGFloat)width
                               dark:(BOOL)dark
                           delegate:(nullable id<ACRActionDelegate>)delegate;

/// 同上，但 measureSize=NO 时**跳过 fittingSizeOfView 测高**（out.size 不可用）。
/// 展示路径(cell refresh)行高另由 +measureCard 缓存供给、不读 result.size，故测高纯属浪费
/// (~6ms/次)——快滑复用时是主要卡顿源。测高路径(measureCard)才传 YES。
+ (WKACardRenderResult *)renderCard:(NSDictionary *)cardJSON
                              width:(CGFloat)width
                               dark:(BOOL)dark
                           delegate:(nullable id<ACRActionDelegate>)delegate
                        measureSize:(BOOL)measureSize;

/// 仅测量卡片高度（主线程），按 fingerprint+width+dark 缓存。供 +contentSizeForMessage。
+ (CGSize)measureCard:(NSDictionary *)cardJSON
                width:(CGFloat)width
                 dark:(BOOL)dark
          fingerprint:(NSString *)fingerprint;

/// 失效某指纹的测量缓存（卡片被编辑帧改写后调用）。
+ (void)invalidateMeasureForFingerprint:(NSString *)fingerprint;

/// 主线程耗时聚合探针：按 label(组件×阶段) 累计 count/总耗时/最大单次，每 ~1s dump 一行汇总。
/// 用于把卡顿定位到具体组件而非 per-call 刷屏。排查完关闭即可（见实现里的开关）。
+ (void)perfAccrue:(NSString *)label ms:(double)ms;

@end

NS_ASSUME_NONNULL_END
