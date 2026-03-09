//
//  WKImageMessageContent.m
//  WuKongIMSDK
//
//  Created by tt on 2020/1/13.
//

#import "WKImageContent.h"
#import "WKConst.h"
#import "WKMediaUtil.h"
#import "WKFileUtil.h"
#import "WKSDK.h"
#import "WKMOSContentConvertManager.h"
@interface WKImageContent ()
@property(nonatomic,strong) UIImage  *orgImage;

@property(nonatomic,strong) NSData *data;

@property(nonatomic,strong) NSData *thumbData;

@property(nonatomic,copy) NSString *_localPath; // 本地路径
@end

@implementation WKImageContent

+ (instancetype)initWithImage:(UIImage *)image {
    WKImageContent *content = [WKImageContent new];
    content.width = image.size.width;
    content.height = image.size.height;
    content.orgImage = image;
    return content;
}


+ (instancetype)initWithData:(NSData *)data width:(CGFloat)width height:(CGFloat)height {
   
    return [self initWithData:data width:width height:height thumbData:nil];
}

+ (instancetype)initWithData:(NSData *)data width:(CGFloat)width height:(CGFloat)height thumbData:(NSData*)thumbData {
    WKImageContent *content = [WKImageContent new];
    content.data = data;
    content.width = width;
    content.height = height;
    content.thumbData = thumbData;
    return content;
}

- (UIImage *)originalImage {
    if(!self.orgImage) {
        self.orgImage = [UIImage imageWithContentsOfFile:[self localPath]];
    }
    return self.orgImage;
}

- (NSData *)originalImageData {
    return [[NSData alloc] initWithContentsOfFile:[self localPath]];
}



-(UIImage*) thumbnailImage {
    if(!_thumbnailImage) {
        _thumbnailImage = [UIImage imageWithContentsOfFile:[self thumbPath]];
    }
    return _thumbnailImage;
}

- (NSData *)thumbnailData {
    return [[NSData alloc] initWithContentsOfFile:[self thumbPath]];
}

- (NSString *)extension {
    return @"";
}

- (void) writeDataToLocalPath {
    [super writeDataToLocalPath];
    // 获取本地路径
   if(self.orgImage) {
       self.width = self.orgImage.size.width;
       self.height = self.orgImage.size.height;
       
        NSData *thumdData = [self compressImageSize:self.orgImage toByte:[WKSDK shared].options.imageMaxBytes];
                                      [thumdData writeToFile:self.thumbPath atomically:YES];
       
       [UIImagePNGRepresentation(self.orgImage) writeToFile:self.localPath atomically:YES];
    }
    if(self.data) {
        if(self.thumbData) {
             [self.thumbData writeToFile:self.thumbPath atomically:YES];
        }else {
            NSData *thumbData = [self compressImageSize:[UIImage imageWithData:self.data] toByte:[WKSDK shared].options.imageMaxBytes];
            [thumbData writeToFile:self.thumbPath atomically:YES];
        }
       
        [self.data writeToFile:self.localPath atomically:YES];
    }
}

/*!
 *  @brief 使图片压缩后刚好小于指定大小
 *
 *  @param image 当前要压缩的图 maxLength 压缩后的大小
 *
 *  @return 图片对象
 */
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

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    self.remoteUrl = contentDic[@"url"];
    self.width = contentDic[@"width"]?[contentDic[@"width"] floatValue]:0;
    self.height = contentDic[@"height"]?[contentDic[@"height"] floatValue]:0;
}

- (NSDictionary *)encodeWithJSON {
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
    [dataDict setObject:self.remoteUrl?:@"" forKey:@"url"];
    [dataDict setObject:@(self.width) forKey:@"width"];
    [dataDict setObject:@(self.height) forKey:@"height"];
    return dataDict;
}

+(NSNumber*) contentType {
    return @(WK_IMAGE);
}

- (NSString *)conversationDigest {
    return @"[图片]";
}

- (NSString *)searchableWord {
    return @"[图片]";
}

- (BOOL)viewedOfVisible {
    if(self.message && self.message.isSend) {
        return true;
    }
    return false;
}

-(void) releaseData {
    self.orgImage = nil;
    self.thumbnailImage = nil;
    self.thumbData = nil;
    self.data = nil;
}
@end
