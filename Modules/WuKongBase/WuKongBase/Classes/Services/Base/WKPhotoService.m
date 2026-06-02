//
//  WKPhotoService.m
//  Pods
//
//  Created by tt on 2020/7/29.
//

#import "WKPhotoService.h"
#import "WKActionSheetView2.h"
#import "WKMediaPickerController.h"
#import "WuKongBase.h"
#import "NSData+ImageFormat.h"
#import "WKVideoLoadProgressHUD.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <PhotosUI/PhotosUI.h>
@interface WKPhotoService ()<UIImagePickerControllerDelegate,UINavigationControllerDelegate, PHPickerViewControllerDelegate>

@property(strong,nonatomic)UIImagePickerController *pickerC;
@property(nonatomic,strong) WKMediaFetcher *mediaFetcher;
@property(nonatomic,copy) getPhotoCompleteBlock completeBlock;
@property(nonatomic,copy) getAvatarMediaBlock avatarMediaBlock;

@end

@implementation WKPhotoService
static WKPhotoService *_instance;
+ (WKPhotoService *)shared {
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    return _instance;
}

-(void) getPhotoFromCamera:(getPhotoCompleteBlock)complete {
    self.completeBlock = complete;
    //显示拍照
       [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(!granted){
                    NSString *cancelButtonTitle = LLang(@"取消");
                    NSString *otherButtonTitle = LLang(@"确认");
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:LLang(@"权限提醒") message:LLang(@"请在设置里打开图片读取权限！") preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelButtonTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                        
                    }];
                    
                    UIAlertAction *otherAction = [UIAlertAction actionWithTitle:otherButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    }];
                    [alertController addAction:cancelAction];
                    [alertController addAction:otherAction];
                    return;
                }
                if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                    NSString *cancelButtonTitle = LLang(@"取消");
                    NSString *otherButtonTitle = LLang(@"确认");
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:LLang(@"权限提醒") message:LLang(@"请在设置里打开图片读取权限！") preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelButtonTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                        
                    }];
                    
                    UIAlertAction *otherAction = [UIAlertAction actionWithTitle:otherButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    }];
                    [alertController addAction:cancelAction];
                    [alertController addAction:otherAction];
                    return;
                }
                if(self.pickerC) {
                    self.pickerC = nil;
                }
                self.pickerC = [[UIImagePickerController alloc] init];
                self.pickerC.sourceType = UIImagePickerControllerSourceTypeCamera;
                self.pickerC.delegate = self;
                [[[WKNavigationManager shared] topViewController] presentViewController:self.pickerC animated:YES completion:nil];
            });
        }];
}

-(void) getPhotoOneFromLibrary:(getPhotoCompleteBlock)complete {
    self.completeBlock = complete;

    if (@available(iOS 14, *)) {
        // iOS 14+ 使用 PHPickerViewController，无需相册权限，始终能显示全部相册
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.selectionLimit = 1;
        config.filter = [PHPickerFilter imagesFilter];
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [[[WKNavigationManager shared] topViewController] presentViewController:picker animated:YES completion:nil];
    } else {
        // iOS 14 以下使用旧的 TZImagePickerController
        self.mediaFetcher = [[WKMediaFetcher alloc] init];
        self.mediaFetcher.limit = 1;
        self.mediaFetcher.mediaTypes = @[(NSString*)kUTTypeImage];
        __weak typeof(self) weakSelf = self;
        [self.mediaFetcher fetchPhotoFromLibrary:^(UIImage *img, NSString *path,bool isOrg, PHAssetMediaType type,NSInteger left) {
            weakSelf.mediaFetcher = nil;
            switch (type) {
                case PHAssetMediaTypeImage:
                    if (path) {
                        if ([path.pathExtension isEqualToString:@"HEIC"]){
                            if (@available(iOS 13.0, *)) {
                                UIImage * originImage =  [[SDImageHEICCoder sharedCoder] decodedImageWithData:[[NSData alloc] initWithContentsOfFile:path] options:@{SDImageCoderEncodeCompressionQuality:@(0.9)}];
                                if(weakSelf.completeBlock) {
                                    weakSelf.completeBlock(originImage);
                                }
                            }
                        }else{
                            UIImage *image = [UIImage imageWithContentsOfFile:path];
                            if(weakSelf.completeBlock) {
                                weakSelf.completeBlock(image);
                            }
                        }
                    }else {
                        if(weakSelf.completeBlock) {
                            weakSelf.completeBlock(img);
                        }
                    }
                    break;
                case PHAssetMediaTypeVideo:
                case PHAssetMediaTypeAudio:
                case PHAssetMediaTypeUnknown:
                    break;
            }
        } cancel:^{
            weakSelf.mediaFetcher = nil;
        }];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [[WKNavigationManager shared].topViewController dismissViewControllerAnimated:YES completion:nil];
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    if(self.completeBlock) {
        self.completeBlock(img);
    }
}

#pragma mark - PHPickerViewControllerDelegate
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14)) {
    [picker dismissViewControllerAnimated:YES completion:nil];

    // 头像 (图片/视频) 入口：拿原始字节 + 区分视频
    if (self.avatarMediaBlock) {
        getAvatarMediaBlock cb = self.avatarMediaBlock;
        self.avatarMediaBlock = nil;
        if (results.count == 0) {
            cb(nil, nil, NO);
            return;
        }
        [self handleAvatarPickerResult:results.firstObject complete:cb];
        return;
    }

    // 旧入口：只关心 UIImage
    if (results.count == 0) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    PHPickerResult *result = results.firstObject;
    if ([result.itemProvider canLoadObjectOfClass:[UIImage class]]) {
        [result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (object && [object isKindOfClass:[UIImage class]] && weakSelf.completeBlock) {
                    weakSelf.completeBlock((UIImage *)object);
                }
            });
        }];
    }
}

- (void)handleAvatarPickerResult:(PHPickerResult *)result
                        complete:(getAvatarMediaBlock)complete API_AVAILABLE(ios(14)) {
    NSItemProvider *provider = result.itemProvider;
    NSArray<NSString *> *types = provider.registeredTypeIdentifiers;

    // 视频判定：有 public.movie 或子类型
    BOOL isVideo = NO;
    for (NSString *t in types) {
        if ([t isEqualToString:(NSString *)kUTTypeMovie] ||
            [t isEqualToString:(NSString *)kUTTypeVideo] ||
            UTTypeConformsTo((__bridge CFStringRef)t, kUTTypeMovie)) {
            isVideo = YES;
            break;
        }
    }

    if (isVideo) {
        // 大视频从相册导出 + 拷贝到沙盒可能很慢（iCloud 下载 / HEVC 转换 / 文件复制），
        // 期间界面静止用户不知道在等。这里上一个带进度 + 取消的浮层：
        //   - 0% ~ 70%: NSItemProvider 导出阶段（loadFileRepresentation 返回 NSProgress）
        //   - 70% ~ 100%: 拷贝到 NSTemporaryDirectory 阶段（自己分块统计）
        WKVideoLoadProgressHUD *hud =
            [WKVideoLoadProgressHUD showWithTitle:LLang(@"正在加载视频…")];

        // 取消标志：main 写 / background 读，单字节布尔无需原子化（最坏延迟一个 chunk）
        __block BOOL cancelled = NO;
        __block NSProgress *loadProgress = nil;
        __block dispatch_source_t pollTimer = nil;

        void (^stopPoll)(void) = ^{
            if (pollTimer) {
                dispatch_source_cancel(pollTimer);
                pollTimer = nil;
            }
        };

        hud.onCancel = ^{
            cancelled = YES;
            if (loadProgress && !loadProgress.isCancelled) {
                [loadProgress cancel];
            }
            stopPoll();
            [hud dismiss];
            complete(nil, nil, NO);
        };

        loadProgress = [provider loadFileRepresentationForTypeIdentifier:(NSString *)kUTTypeMovie
                                                       completionHandler:^(NSURL * _Nullable url,
                                                                           NSError * _Nullable error) {
            stopPoll();
            if (cancelled) return; // hud 已 dismiss、complete 已回调

            if (!url) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [hud dismiss];
                    complete(nil, nil, NO);
                });
                return;
            }

            // 阶段 1 完成，HUD 拉到 70%
            [hud setProgress:0.7];

            // 阶段 2：分块拷贝到 NSTemporaryDirectory，剩下 30% 用作进度
            NSString *fileName = [[NSUUID UUID].UUIDString
                                  stringByAppendingPathExtension:url.pathExtension ?: @"mov"];
            NSURL *dst = [NSURL fileURLWithPath:
                          [NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];

            BOOL copyOK = [WKPhotoService wk_copyFileWithProgress:url
                                                              to:dst
                                                       cancelled:^BOOL{ return cancelled; }
                                                        progress:^(double frac) {
                [hud setProgress:0.7 + frac * 0.3];
            }];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (cancelled) {
                    [[NSFileManager defaultManager] removeItemAtURL:dst error:nil];
                    return; // hud/complete 已由 onCancel 处理
                }
                [hud setProgress:1.0];
                [hud dismiss];
                complete(nil, copyOK ? dst : nil, NO);
            });
        }];

        // 用一个 100ms 的 GCD timer 轮询 NSProgress.fractionCompleted。
        // 比 KVO 简单，且 NSProgress 在 iCloud 下载场景下不一定每帧都触发 KVO，
        // 轮询更平滑。
        if (loadProgress) {
            pollTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0,
                                               0, dispatch_get_main_queue());
            dispatch_source_set_timer(pollTimer,
                                      dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC),
                                      100 * NSEC_PER_MSEC,
                                      20 * NSEC_PER_MSEC);
            dispatch_source_set_event_handler(pollTimer, ^{
                if (cancelled) { stopPoll(); return; }
                double frac = loadProgress.fractionCompleted;
                [hud setProgress:frac * 0.7]; // 阶段 1 占 0-70%
            });
            dispatch_resume(pollTimer);
        }

        return;
    }

    // 图片：拿原始字节，magic-bytes 判动图
    NSString *imageType = nil;
    for (NSString *t in types) {
        if (UTTypeConformsTo((__bridge CFStringRef)t, kUTTypeImage)) {
            imageType = t;
            break;
        }
    }
    if (!imageType) {
        // 兜底回退到 UIImage 加载（HEIC 等转换由系统处理）
        if ([provider canLoadObjectOfClass:[UIImage class]]) {
            [provider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
                NSData *data = nil;
                if ([object isKindOfClass:[UIImage class]]) {
                    data = UIImageJPEGRepresentation((UIImage *)object, 0.9);
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    complete(data, nil, NO);
                });
            }];
        } else {
            complete(nil, nil, NO);
        }
        return;
    }

    [provider loadDataRepresentationForTypeIdentifier:imageType
                                    completionHandler:^(NSData * _Nullable data,
                                                        NSError * _Nullable error) {
        // HEIC 不是动图，但 SDAnimatedImageView 不认；交给上层走静态分支即可。
        BOOL animated = [NSData wk_isAnimatedImageData:data];
        dispatch_async(dispatch_get_main_queue(), ^{
            complete(data, nil, animated);
        });
    }];
}

- (void)getAvatarMediaFromLibrary:(getAvatarMediaBlock)complete {
    self.avatarMediaBlock = complete;
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.selectionLimit = 1;
        config.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[
            [PHPickerFilter imagesFilter],
            [PHPickerFilter videosFilter],
        ]];
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [[[WKNavigationManager shared] topViewController] presentViewController:picker animated:YES completion:nil];
    } else {
        // iOS 14 以下：降级走旧的 UIImage 流程，无视频
        __weak typeof(self) ws = self;
        [self getPhotoOneFromLibrary:^(UIImage * _Nonnull image) {
            NSData *data = UIImageJPEGRepresentation(image, 0.9);
            if (ws.avatarMediaBlock) {
                getAvatarMediaBlock cb = ws.avatarMediaBlock;
                ws.avatarMediaBlock = nil;
                cb(data, nil, NO);
            }
        }];
    }
}


//图片质量压缩到某一范围内，如果后面用到多，可以抽成分类或者工具类,这里压缩递减比二分的运行时间长，二分可以限制下限。
- (NSData *)compressImageSize:(UIImage *)image toByte:(NSUInteger)maxLength{
    //首先判断原图大小是否在要求内，如果满足要求则不进行压缩，over
    CGFloat compression = 1;
    NSData *data = UIImageJPEGRepresentation(image, compression);
    if (data.length < maxLength) return data;
    //原图大小超过范围，先进行“压处理”，这里 压缩比 采用二分法进行处理，6次二分后的最小压缩比是0.015625，已经够小了
    CGFloat max = 1;
    CGFloat min = 0;
    for (int i = 0; i < 6; ++i) {
        compression = (max + min) / 2;
        data = UIImageJPEGRepresentation(image, compression);
        if (data.length < maxLength * 0.9) {
            min = compression;
        } else if (data.length > maxLength) {
            max = compression;
        } else {
            break;
        }
    }
    //判断“压处理”的结果是否符合要求，符合要求就over
    UIImage *resultImage = [UIImage imageWithData:data];
    if (data.length < maxLength) return data;
    
    //缩处理，直接用大小的比例作为缩处理的比例进行处理，因为有取整处理，所以一般是需要两次处理
    NSUInteger lastDataLength = 0;
    while (data.length > maxLength && data.length != lastDataLength) {
        lastDataLength = data.length;
        //获取处理后的尺寸
        CGFloat ratio = (CGFloat)maxLength / data.length;
        CGSize size = CGSizeMake((NSUInteger)(resultImage.size.width * sqrtf(ratio)),
                                 (NSUInteger)(resultImage.size.height * sqrtf(ratio)));
        //通过图片上下文进行处理图片
        UIGraphicsBeginImageContext(size);
        [resultImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
        resultImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        //获取处理后图片的大小
        data = UIImageJPEGRepresentation(resultImage, compression);
    }

    return data;
}

#pragma mark - 分块拷贝（带进度 + 可取消）

// 用 NSFileHandle 256KB 分块流式拷贝，每写完一块回调进度。
// 比 NSFileManager copyItemAtURL 慢一点点，但能给 UI 实时进度，也能在中途
// 检测 cancelled 立刻退出。
//
// 失败 / cancelled 时会清理掉 dst 已写出的半截文件。
+ (BOOL)wk_copyFileWithProgress:(NSURL *)src
                             to:(NSURL *)dst
                      cancelled:(BOOL(^)(void))cancelled
                       progress:(void(^)(double frac))progress {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:src.path error:nil];
    uint64_t total = [attrs[NSFileSize] unsignedLongLongValue];

    NSFileHandle *in = [NSFileHandle fileHandleForReadingFromURL:src error:nil];
    if (!in) return NO;

    [fm removeItemAtURL:dst error:nil];
    if (![fm createFileAtPath:dst.path contents:nil attributes:nil]) {
        [in closeFile];
        return NO;
    }
    NSFileHandle *out = [NSFileHandle fileHandleForWritingToURL:dst error:nil];
    if (!out) {
        [in closeFile];
        [fm removeItemAtURL:dst error:nil];
        return NO;
    }

    const NSUInteger chunk = 256 * 1024; // 256 KB
    uint64_t copied = 0;
    BOOL aborted = NO;

    while (YES) {
        if (cancelled && cancelled()) { aborted = YES; break; }
        @autoreleasepool {
            NSData *data = nil;
            @try { data = [in readDataOfLength:chunk]; }
            @catch (NSException *e) { aborted = YES; break; }
            if (data.length == 0) break;
            @try { [out writeData:data]; }
            @catch (NSException *e) { aborted = YES; break; }
            copied += data.length;
            if (total > 0 && progress) {
                progress((double)copied / (double)total);
            }
        }
    }

    [in closeFile];
    [out closeFile];

    if (aborted) {
        [fm removeItemAtURL:dst error:nil];
        return NO;
    }
    return YES;
}

@end
