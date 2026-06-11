//
//  WKChatAnimatedImage.h
//  WuKongBase
//
//  SDAnimatedImage 子类: 强制每帧 bitmap backing。
//
//  根因 (Time Profiler 抓栈):
//    SDImageIOAnimatedCoder.animatedImageFrameAtIndex: 用
//    kCGImageSourceShouldCacheImmediately:YES 创建 CGImage,但返回的 CGImage 仍由
//    IIOImageProvider 背后承载 —— Image/IO 声称"已 cache",实际只是把 source 内部
//    块缓存住,CGImage 自身没有位图缓冲区。SDAnimatedImagePlayer 把这种 CGImage
//    赋给 CALayer.contents 时, CA::Transaction::commit → CA::Render::prepare_image →
//    IIOImageProviderInfo::CopyImageBlockSetWithOptions →
//    GIFReadPlugin::decodeIndexedColorFrame
//    依然在主线程现场跑一次 LZW + 颜色表展开。聊天详情若有动图头像 / 动图贴纸 /
//    动图消息可见,主线程占用一度到 78%。
//
//  修法:
//    override animatedImageFrameAtIndex:,把 super 返回的 IIO-backed UIImage 用
//    SDImageCoderHelper.CGImageCreateDecoded: 重画到 CGBitmapContext。新 CGImage
//    的 dataProvider 是堆上 RGBA 缓冲区,与 IIOImageProvider 完全脱钩;
//    layer.contents 拿到后 CA::commit 只做 memcpy,不再触发解码。
//
//  接入点:
//    1) WKImageMessageCell.refresh: 本地 bg-decode 路径直接 [WKChatAnimatedImage imageWithData:]
//    2) WKImageView 覆盖 sd_setImageWithURL: 的 funnel,通过
//       SDWebImageContextAnimatedImageClass 让 SDWebImage 解码出来的动图都是这个子类
//       —— 覆盖 WKUserAvatar (头像) / WKGIFMessageCell (动图消息) /
//       WKImageMessageCell URL 路径。
//
//    注: WKStickerImageView 的内部 stickerImgView 是 SDAnimatedImageView 直接子类
//    (不是 WKImageView),走 SDAnimatedImageView 自己的 sd_setImageWithURL: funnel,
//    第一行就把 SDWebImageContextAnimatedImageClass 强制覆为 [SDAnimatedImage class],
//    本注入对它无效。但贴纸默认 autoPlayAnimatedImage=NO + clearBufferWhenStopped=YES,
//    且只在用户主动操作时 startAnimating, 不像消息列表会持续可见,影响面比动图消息小,
//    暂未单独治理。
//
//  内存:
//    重画产物比 lazy CGImage 多约 1× 像素 (decodedRGBA = w*h*4)。preloadAllFrames
//    本来就把所有帧驻留,所以新增的是"每帧从 lazy 变 bitmap"的展开开销;不预解的
//    大图路径下,player.frameBuffer 内置 maxBufferCount 自管,稳态仍可控。

#import <SDWebImage/SDAnimatedImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKChatAnimatedImage : SDAnimatedImage
@end

NS_ASSUME_NONNULL_END
