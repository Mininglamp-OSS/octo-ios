//
//  WKVideoLoadProgressHUD.h
//  WuKongBase
//
//  视频从相册加载到沙盒的进度浮层。
//  用户从 PHPicker 选了一个比较大的视频后，需要：
//    1) loadFileRepresentationForTypeIdentifier: 把视频从相册沙盒导出（iCloud
//       视频可能要下载，本地视频可能要解码 HEVC 转换），返回的 NSProgress 反映这一段
//    2) 把临时文件拷贝到我们自己的 NSTemporaryDirectory（picker 临时路径完成后会清）
//  两步加起来对几百 MB 的视频可能要 5-30 秒，期间界面静止，用户不知道发生了什么。
//
//  这个 HUD 提供：标题 + 圆形进度 + 百分比 + 取消按钮。
//  调用方在两步过程中分别更新 progress，取消时通过 onCancel 回调拿到信号去
//  cancel NSProgress / 删除部分文件 / 终止 callback。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKVideoLoadProgressHUD : UIView

/// 显示在 keyWindow 上，返回实例。
+ (instancetype)showWithTitle:(NSString *)title;

/// 更新进度 0.0–1.0
- (void)setProgress:(double)progress;

/// 隐藏并从 superview 移除
- (void)dismiss;

/// 用户点取消按钮时回调（main 线程）。设了 onCancel 后，取消按钮才会可见。
@property(nonatomic, copy, nullable) void (^onCancel)(void);

@end

NS_ASSUME_NONNULL_END
