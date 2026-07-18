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

/// 仅测量卡片高度（主线程），按 fingerprint+width+dark 缓存。供 +contentSizeForMessage。
+ (CGSize)measureCard:(NSDictionary *)cardJSON
                width:(CGFloat)width
                 dark:(BOOL)dark
          fingerprint:(NSString *)fingerprint;

/// 失效某指纹的测量缓存（卡片被编辑帧改写后调用）。
+ (void)invalidateMeasureForFingerprint:(NSString *)fingerprint;

@end

NS_ASSUME_NONNULL_END
