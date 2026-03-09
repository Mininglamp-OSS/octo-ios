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
#import <MobileCoreServices/MobileCoreServices.h>
@interface WKPhotoService ()<UIImagePickerControllerDelegate,UINavigationControllerDelegate>

@property(strong,nonatomic)UIImagePickerController *pickerC;
@property(nonatomic,strong) WKMediaFetcher *mediaFetcher;
@property(nonatomic,copy) getPhotoCompleteBlock completeBlock;

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
    self.mediaFetcher = [[WKMediaFetcher alloc] init];
    self.mediaFetcher.limit = 1;
    self.mediaFetcher.mediaTypes = @[(NSString*)kUTTypeImage];
     __weak typeof(self) weakSelf = self;
    [self.mediaFetcher fetchPhotoFromLibrary:^(UIImage *img, NSString *path,bool isOrg, PHAssetMediaType type,NSInteger left) {
        weakSelf.mediaFetcher = nil;
        switch (type) {
            case PHAssetMediaTypeImage:
                if (path) { // path有值一般是选择了原图
                    //iOS 11 苹果采用了新的图片格式 HEIC ，如果采用原图会导致其他设备的兼容问题，在上层做好格式的兼容转换,压成 jpeg
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

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [[WKNavigationManager shared].topViewController dismissViewControllerAnimated:YES completion:nil];
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    if(self.completeBlock) {
        self.completeBlock(img);
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

@end
