//
//  WKStickerUploadService.h
//  WuKongBase
//
//  「我的表情」自定义表情上传服务：把 NSData 图片走 COS 预签名 PUT 直传 +
//  POST /sticker/user 注册到「我的表情」的完整流水抽出，供
//  WKMyStickerContentView (面板 tab) 与 WKStickerCollectionVC (整理页) 共用。
//
//  本地做三重预校验（扩展名 / 字节大小 / 图片宽高），服务端仍是最终防线。
//  上限来源：+ [currentLimits] 静态方法，本期硬编码默认，未来 hook 到
//  WKApp.remoteConfig 只改一处。
//

#import <Foundation/Foundation.h>

@class WKSticker;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WKStickerUploadError) {
    WKStickerUploadErrorUnknown = 0,
    WKStickerUploadErrorFormatUnsupported = 1001,   // 扩展名不在白名单
    WKStickerUploadErrorTooLarge          = 1002,   // 字节数超限
    WKStickerUploadErrorDimensionTooLarge = 1003,   // 宽或高超限
    WKStickerUploadErrorLocalWriteFailed  = 1004,   // 写 tmp 失败（少见）
    WKStickerUploadErrorNetworkFailed     = 1005,   // 凭证/PUT/注册任一步网络失败
    WKStickerUploadErrorQuotaExceeded     = 1006,   // 后端配额上限
};

extern NSString *const WKStickerUploadErrorDomain;

typedef struct {
    NSInteger maxSizeKB;     // 字节大小上限（KB）
    NSInteger maxDimension;  // 宽/高最大像素（长边）
} WKStickerUploadLimits;

@interface WKStickerUploadService : NSObject

// 当前生效的上传上限 + 允许的扩展名
+ (WKStickerUploadLimits)currentLimits;
+ (NSArray<NSString *> *)allowedExtensions; // ["gif","png","jpg","jpeg","webp"] 全小写不带点

// 从 image data 探测出扩展名（magic bytes）；不认识返回 nil
+ (nullable NSString *)detectExtensionForImageData:(NSData *)data;

// 静态入口：上传一张图片作为「我的表情」
// 内部：本地校验 → getUploadCredentialsForPath: → PUT → POST /sticker/user
// 成功后自动 [WKApp.shared loadCollectStickers] 并 post WKNOTIFY_STICKERS_UPDATED。
// completion 在主线程回调。error 的 domain 为 WKStickerUploadErrorDomain。
+ (void)uploadStickerData:(NSData *)imageData
                 progress:(nullable void (^)(float fraction))progress
               completion:(nullable void (^)(WKSticker * _Nullable sticker, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
