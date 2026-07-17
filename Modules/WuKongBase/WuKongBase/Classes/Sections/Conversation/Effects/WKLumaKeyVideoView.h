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
/// 可被 protectCrossfadeTime 做时间门控（见下）。
@property (nonatomic, assign) CGFloat centerProtectRadius;
/// 中心保护盘圆心（归一化坐标，原点左上 (0,0)~(1,1)）。默认 {0.5,0.5} 即画面几何正中。
/// 素材主体不在正中时（如偏上的徽标）可上移，避免盘子下半罩到主体下方的空黑背景成黑圈。
@property (nonatomic, assign) CGPoint centerProtectCenter;
/// 中心保护区边缘过渡软度（相对短边比例）。默认 0.12。
@property (nonatomic, assign) CGFloat centerProtectSoftness;
/// 背景"半透明纱"：被判为背景的像素不全删，alpha 随其亮度在 [floor, ceil] 间线性变化。
/// 越暗（如四角近黑）越接近 floor（更透，露出聊天页）；
/// 越亮（如底部蓝光晕）越接近 ceil（保留更多，留住光晕氛围）。
@property (nonatomic, assign) CGFloat backgroundAlphaFloor;  // 默认 0.05
@property (nonatomic, assign) CGFloat backgroundAlphaCeil;   // 默认 0.45

/// 眼部（小范围）保护圈 —— 比 centerProtectRadius 更小、可定位的保护圆。
/// 用途：补住主体内部那点与背景同为暗色、luma 无法区分的细节（如深色眼睛/眉毛）。
/// 半径 > 0 时**全程常驻**（0→结束，与下面中心盘的时间门控无关）；半径 <= 0 关闭（默认关闭）。
@property (nonatomic, assign) CGPoint eyeProtectCenter;      // 归一化坐标，原点左上 (0,0)~(1,1)。默认 {0.5,0.5}
@property (nonatomic, assign) CGFloat eyeProtectRadius;      // 相对画面短边比例。默认 0（关闭）
@property (nonatomic, assign) CGFloat eyeProtectSoftness;    // 边缘过渡软度（相对短边）。默认 0

/// 中心保护盘的"延时出现"时间门控：为"主体甩入、定格后才该出现完整黑盘"的素材设计。
///   startTime <= 0（默认）：中心盘从头常驻全强度（即 Action/Classy 的原始行为，等价旧逻辑）。
///   startTime > 0：
///     播放时间 < startTime               → 中心盘强度 0（不出现，靠眼部小圈补眼睛即可）；
///     [startTime, +rampDuration] 内      → 中心盘线性淡入；
///     之后                               → 中心盘全强度。
/// 眼部小圈不受此门控影响（若开启则全程常驻），二者叠加取 max。
@property (nonatomic, assign) NSTimeInterval centerProtectStartTime;    // 秒。默认 0（从头常驻）
@property (nonatomic, assign) NSTimeInterval centerProtectRampDuration; // 秒。默认 0（在 startTime 处瞬现）

/// 是否带原声播放（视频自带 aac 音轨）。默认 NO（静音）。
@property (nonatomic, assign) BOOL soundEnabled;

/// 开始播放一次。completion 在播放自然结束（或失败）后回调一次。
- (void)playWithCompletion:(nullable void (^)(void))completion;

/// 立即停止并释放播放资源（invalidate displayLink / 暂停 player / 断开 output）。
- (void)stop;

@end

NS_ASSUME_NONNULL_END
