//
//  WKAvatarMediaFlow.h
//  WuKongBase
//
//  动图 / 视频头像选取流程的共享编排器。
//  3 个头像 VC (WKMeAvatarVC / WKBotAvatarVC / WKConversationGroupSettingVC) 复用。
//
//  调用方仍负责：
//    - 显示 action sheet (拍照 / 相册 / 保存图片)
//    - 静态图的裁剪 + 上传 (原 TOCropViewController 流程不变)
//    - 动图的上传逻辑 (因为 endpoint 各 VC 不同)
//
//  helper 负责：
//    - 调起 picker (图片 + 视频)
//    - 视频时长校验 → trimmer → 视频转 GIF → 预览确认
//    - 动图大小校验 → 必要时压缩 → 预览确认
//    - 失败时弹 toast
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKAvatarMediaFlow : NSObject

/// 入口：从相册挑选头像素材。会自动处理动图 / 视频路径；纯静态图回到 onStaticPicked。
/// @param host 调用方 VC (用于 push trimmer / preview)
/// @param onAnimated 用户在预览页确认后，最终的动图字节 (≤5 MB)。在 main 调用。
/// @param onStaticPicked 用户选了静态图。调用方应继续走原裁剪 / JPEG 压缩 / 上传流程。
+ (void)pickAvatarFromLibraryWithHost:(UIViewController *)host
                           onAnimated:(void (^)(NSData *gifData))onAnimated
                       onStaticPicked:(void (^)(UIImage *image))onStaticPicked;

@end

NS_ASSUME_NONNULL_END
