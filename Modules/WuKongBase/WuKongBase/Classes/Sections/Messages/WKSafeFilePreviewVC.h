#import "WKBaseVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKSafeFilePreviewVC : WKBaseVC

- (instancetype)initWithFileURL:(NSURL *)fileURL title:(nullable NSString *)title;

+ (void)showFilePreview:(NSURL *)fileURL title:(NSString *)title;
+ (void)dismissPreview;

/// 以任意 VC 作为预览窗口的根(供 zip 浏览器等复用同一独立 Window 机制)。
+ (void)showRootViewController:(UIViewController *)rootVC;
/// 预览窗口当前是否已展示。
+ (BOOL)isShowing;

@end

NS_ASSUME_NONNULL_END
