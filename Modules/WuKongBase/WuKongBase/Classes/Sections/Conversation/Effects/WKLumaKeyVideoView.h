//
//  WKLumaKeyVideoView.h
//  WuKongBase
//
//  把一个**不带 alpha 通道**的普通视频（深色/纯色背景），运行时用 CoreImage
//  实时 lumakey 抠像（暗→透明、亮→不透明、中间灰度→半透明平滑过渡），
//  当作"透明视频"叠在上层播放。用于抖音直播礼物那种悬浮发光特效。
//
//  原理：AVPlayerItemVideoOutput 逐帧取 BGRA CVPixelBuffer → CIColorKernel
//  按亮度算 alpha（预乘）→ CIContext(Metal) 渲染进 CAMetalLayer。
//  纯 iOS 14+ 原生 API，无第三方依赖；不修改源素材。
//
//  ⚠️ lumakey 是"猜 alpha"，效果上限取决于素材背景纯净度。若日后换成真 alpha
//  素材（HEVC-with-alpha / RGBA），应另走"直接合成"路径，不要再 keying。

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKLumaKeyVideoView : UIView

/// 用一个视频文件 URL 初始化（本地文件）。
- (instancetype)initWithVideoURL:(NSURL *)videoURL;

/// 亮度抠像阈值：luma < threshold 完全透明。深蓝近黑背景默认 0.10。
@property (nonatomic, assign) CGFloat lumaThreshold;
/// 过渡软度：luma 在 [threshold, threshold+tolerance] 间从透明平滑到不透明。默认 0.12。
@property (nonatomic, assign) CGFloat lumaTolerance;

/// 中心保护区半径（相对画面短边的比例 0~1）：此圆内强制保留不透明，
/// 避免脸/眼睛等中间区域里的暗色细节被抠成透明。默认 0.30。设 0 关闭。
@property (nonatomic, assign) CGFloat centerProtectRadius;
/// 中心保护区边缘过渡软度（相对短边比例）。默认 0.12。
@property (nonatomic, assign) CGFloat centerProtectSoftness;
/// 背景"半透明纱"：被判为背景的像素不全删，alpha 随其亮度在 [floor, ceil] 间线性变化。
/// 越暗（如四角近黑）越接近 floor（更透，露出聊天页）；
/// 越亮（如底部蓝光晕）越接近 ceil（保留更多，留住光晕氛围）。
@property (nonatomic, assign) CGFloat backgroundAlphaFloor;  // 默认 0.05
@property (nonatomic, assign) CGFloat backgroundAlphaCeil;   // 默认 0.45

/// 是否带原声播放（视频自带 aac 音轨）。默认 NO（静音）。
@property (nonatomic, assign) BOOL soundEnabled;

/// 开始播放一次。completion 在播放自然结束（或失败）后回调一次。
- (void)playWithCompletion:(nullable void (^)(void))completion;

/// 立即停止并释放播放资源（invalidate displayLink / 暂停 player / 断开 output）。
- (void)stop;

@end

NS_ASSUME_NONNULL_END
