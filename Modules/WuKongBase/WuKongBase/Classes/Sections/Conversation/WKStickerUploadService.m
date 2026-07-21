//
//  WKStickerUploadService.m
//  WuKongBase
//

#import "WKStickerUploadService.h"
#import "WKAPIClient.h"
#import "WKApp.h"
#import "WKConstant.h"
#import "WKLogs.h"
#import "WKStickerPackage.h"
#import <UIKit/UIKit.h>

NSString *const WKStickerUploadErrorDomain = @"WKStickerUploadErrorDomain";

@implementation WKStickerUploadService

#pragma mark - limits

+ (WKStickerUploadLimits)currentLimits {
    // 本期硬编码默认（与 web StickerUploadConfig 的 fallback 一致）：
    // 1MB / 512px 长边。未来接入 WKApp.remoteConfig.stickerUploadLimits 只改这一处。
    return (WKStickerUploadLimits){ .maxSizeKB = 1024, .maxDimension = 512 };
}

+ (NSArray<NSString *> *)allowedExtensions {
    return @[@"gif", @"png", @"jpg", @"jpeg", @"webp"];
}

#pragma mark - detection

+ (NSString *)detectExtensionForImageData:(NSData *)data {
    if (data.length < 4) return nil;
    const uint8_t *b = (const uint8_t *)data.bytes;
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return @"png";
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return @"jpg";
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) return @"gif";
    if (data.length >= 12 && b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) return @"webp";
    return nil;
}

+ (NSString *)mimeForExtension:(NSString *)ext {
    if ([ext isEqualToString:@"png"])  return @"image/png";
    if ([ext isEqualToString:@"jpg"])  return @"image/jpeg";
    if ([ext isEqualToString:@"jpeg"]) return @"image/jpeg";
    if ([ext isEqualToString:@"gif"])  return @"image/gif";
    if ([ext isEqualToString:@"webp"]) return @"image/webp";
    return @"image/png";
}

#pragma mark - upload

+ (void)uploadStickerData:(NSData *)imageData
                 progress:(void (^)(float))progress
               completion:(void (^)(WKSticker * _Nullable, NSError * _Nullable))completion {
    void (^finish)(WKSticker *, NSError *) = ^(WKSticker *sticker, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(sticker, error);
        });
    };

    if (imageData.length == 0) {
        WKLogError(@"[Sticker/upload] ABORT empty data");
        finish(nil, [self errorWithCode:WKStickerUploadErrorUnknown message:@"empty data"]);
        return;
    }

    // Format 探测：仅用于取扩展名 + 文件名。大小/分辨率/白名单交给服务端 —— 与
    // web StickerUploadConfig 的 remote config 契约一致，不硬编码本地规则。
    NSString *ext = [self detectExtensionForImageData:imageData];
    BOOL extDetected = ext != nil;
    if (!extDetected) ext = @"png";
    UIImage *image = [[UIImage alloc] initWithData:imageData];
    CGFloat w = image ? image.size.width : 0;
    CGFloat h = image ? image.size.height : 0;
    WKLogInfo(@"[Sticker/upload] STEP1 bytes=%lu ext=%@(detected=%d) decode=%@ size=%.0fx%.0f",
              (unsigned long)imageData.length, ext, extDetected, image ? @"OK" : @"nil", w, h);

    NSString *uuid = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    NSString *fileName = [NSString stringWithFormat:@"%@.%@", uuid, ext];
    NSString *mimeType = [self mimeForExtension:ext];
    NSString *encodedName = [fileName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] ?: fileName;

    // 服务端要求两步走（modules/file/api.go getFilePath + uploadFile）:
    //  1) GET  /file/upload?type=sticker&filename=xxx.ext
    //     → 服务端按 loginUID 生成 path=/{uid}/{uuid}.ext, 回 { url: <完整 upload URL> }
    //  2) POST 那个完整 URL (multipart file field "file")
    //     → 上传后端会做 uid 段校验、魔数校验、大小/尺寸校验
    // 上一版直接 POST /file/upload?type=sticker&filename=... 缺 path query 参数,
    // uploadFile 里 `strings.HasPrefix(uploadPath, "/"+loginUID+"/")` 失败, 400
    // "无效的文件路径"。
    NSString *addrPath = [NSString stringWithFormat:@"file/upload?type=sticker&filename=%@", encodedName];
    WKLogInfo(@"[Sticker/upload] STEP2 GET %@", addrPath);
    [[WKAPIClient sharedClient] GET:addrPath parameters:nil].then(^(id addrResp) {
        WKLogInfo(@"[Sticker/upload] STEP2 resp class=%@ resp=%@", NSStringFromClass([addrResp class]), addrResp);
        NSString *uploadURL = nil;
        if ([addrResp isKindOfClass:NSDictionary.class]) {
            uploadURL = ((NSDictionary *)addrResp)[@"url"];
        }
        if (uploadURL.length == 0) {
            WKLogError(@"[Sticker/upload] STEP2 empty url in resp");
            finish(nil, [self errorWithCode:WKStickerUploadErrorNetworkFailed message:@"empty upload url"]);
            return;
        }
        WKLogInfo(@"[Sticker/upload] STEP3 POST multipart to url=%@ mime=%@ file=%@ size=%lu",
                  uploadURL, mimeType, fileName, (unsigned long)imageData.length);
        // 用自定义 multipart 变体：指定 fileField="file"（服务端 c.Request.FormFile("file")
        // 匹配）、显式 mimeType（默认 * 会走服务端从扩展名兜底，稳妥起见传对应 MIME）。
        [[WKAPIClient sharedClient] fileUpload:uploadURL
                                    formFields:nil
                                      fileData:imageData
                                      fileName:fileName
                                     fileField:@"file"
                                      mimeType:mimeType
                                       timeout:60.0
                              completeCallback:^(id  _Nullable resp, NSError * _Nullable error) {
            if (error) {
                WKLogError(@"[Sticker/upload] STEP3 PUT-multipart FAIL err=%@ domain=%@ code=%ld userInfo=%@",
                           error, error.domain, (long)error.code, error.userInfo);
                // 工程 config.errorHandler 把服务端返回的 msg（如"贴纸尺寸不能超过 512×512 像素"）
                // 塞进 error.domain（见 WKApp.m:686 setErrorHandler），透传给 UI 让用户看到
                // 具体原因，而不是笼统的"添加失败"。
                finish(nil, [self errorWithCode:WKStickerUploadErrorNetworkFailed message:error.domain ?: (error.localizedDescription ?: @"")]);
                return;
            }
            WKLogInfo(@"[Sticker/upload] STEP3 upload OK resp class=%@ resp=%@", NSStringFromClass([resp class]), resp);
            NSString *downloadUrl = nil;
            NSString *retExt = ext;
            NSString *stickerHandle = nil;
            if ([resp isKindOfClass:NSDictionary.class]) {
                NSDictionary *d = (NSDictionary *)resp;
                downloadUrl = d[@"path"] ?: d[@"url"] ?: d[@"downloadUrl"];
                if ([d[@"ext"] isKindOfClass:NSString.class]) {
                    NSString *e = d[@"ext"];
                    // 服务端 ext 可能带前导 "."（filepath.Ext），去掉方便存 model.format
                    retExt = [e hasPrefix:@"."] ? [e substringFromIndex:1] : e;
                }
                stickerHandle = d[@"sticker_handle"];
            }
            if (downloadUrl.length == 0) {
                WKLogError(@"[Sticker/upload] STEP3 empty downloadUrl in resp: %@", resp);
                finish(nil, [self errorWithCode:WKStickerUploadErrorNetworkFailed message:@"empty upload result"]);
                return;
            }
            [self registerSticker:downloadUrl
                        imageSize:CGSizeMake(w, h)
                           format:retExt
                           handle:stickerHandle
                       completion:finish];
        }];
    }).catch(^(NSError *error) {
        WKLogError(@"[Sticker/upload] STEP2 GET FAIL err=%@ domain=%@ code=%ld userInfo=%@",
                   error, error.domain, (long)error.code, error.userInfo);
        finish(nil, [self errorWithCode:WKStickerUploadErrorNetworkFailed message:error.domain ?: (error.localizedDescription ?: @"")]);
    });
}

+ (void)registerSticker:(NSString *)downloadUrl
              imageSize:(CGSize)size
                 format:(NSString *)format
                 handle:(nullable NSString *)handle
             completion:(void (^)(WKSticker *, NSError *))finish {
    NSMutableDictionary *params = [@{
        @"path": downloadUrl ?: @"",
        @"width": @(size.width),
        @"height": @(size.height),
    } mutableCopy];
    if (format.length > 0) params[@"format"] = format;
    // sticker_handle 是服务端签发的（当 OCTO_MASTER_KEY 配置时），
    // /sticker/user 校验它证明该 path 由本人经贴纸上传门产生（防他人上传或
    // 非 sticker 桶 path 注册成表情）。当 sticker.handle_required=true 时必需。
    if (handle.length > 0) params[@"handle"] = handle;
    WKLogInfo(@"[Sticker/upload] STEP4 POST sticker/user params=%@", params);

    [[WKAPIClient sharedClient] POST:@"sticker/user" parameters:params].then(^(id resp){
        WKLogInfo(@"[Sticker/upload] STEP4 POST OK resp class=%@ resp=%@", NSStringFromClass([resp class]), resp);
        // 刷新内存缓存并广播
        [[WKApp shared] loadCollectStickers].then(^(NSArray *stickers){
            WKLogInfo(@"[Sticker/upload] STEP5 collectStickers reload count=%lu", (unsigned long)stickers.count);
            [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_STICKERS_UPDATED object:nil];
            WKSticker *created = nil;
            if ([resp isKindOfClass:[WKSticker class]]) {
                created = (WKSticker *)resp;
            } else {
                // 后端仅返回状态时，用 downloadUrl 反查最新缓存
                for (WKSticker *s in WKApp.shared.collectStickers) {
                    if ([s.path isEqualToString:downloadUrl]) { created = s; break; }
                }
            }
            finish(created, nil);
        }).catch(^(NSError *reloadErr){
            // sticker/user 已成功（表情已在服务端注册），仅本地缓存 reload 失败。
            // 必须仍调 finish，否则调用方的 HUD spinner 永久不消失（需强杀）。按成功处理并广播，
            // 让面板随 WKNOTIFY_STICKERS_UPDATED / 下次缓存加载补齐。
            WKLogError(@"[Sticker/upload] STEP5 collectStickers reload FAIL err=%@", reloadErr);
            [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_STICKERS_UPDATED object:nil];
            finish(nil, nil);
        });
    }).catch(^(NSError *error){
        WKLogError(@"[Sticker/upload] STEP4 POST FAIL err=%@ domain=%@ code=%ld userInfo=%@",
                   error, error.domain, (long)error.code, error.userInfo);
        // 后端配额错误码：与 web `err.server.sticker.quota_exceeded` 对齐
        NSInteger code = WKStickerUploadErrorNetworkFailed;
        NSString *domain = error.domain ?: @"";
        if ([domain containsString:@"quota_exceeded"] || error.code == 429) {
            code = WKStickerUploadErrorQuotaExceeded;
        }
        finish(nil, [self errorWithCode:code message:domain]);
    });
}

+ (NSError *)errorWithCode:(NSInteger)code message:(NSString *)msg {
    return [NSError errorWithDomain:WKStickerUploadErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: msg ?: @""}];
}

@end
