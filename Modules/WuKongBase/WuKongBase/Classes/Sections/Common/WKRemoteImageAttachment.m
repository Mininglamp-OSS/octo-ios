//
//  WKRemoteImageAttachment.m
//  WuKongRichTextEditor
//
//  Created by tt on 2022/7/28.
//

#import "WKRemoteImageAttachment.h"
#import <SDWebImage/SDWebImage.h>
@interface WKRemoteImageAttachment ()

@property(nonatomic,assign) BOOL isDownloading;

@end

@implementation WKRemoteImageAttachment

-(instancetype) initWithURL:(NSString*)url displaySize:(CGSize)displaySize {
    self = [super init];
    if(self) {
        self.url = url;
        self.displaySize = displaySize;
    }
    return self;
}


- (UIImage *)imageForBounds:(CGRect)imageBounds textContainer:(NSTextContainer *)textContainer characterIndex:(NSUInteger)charIndex {
    if(self.image) {
        return self.image;
    }
   
    return nil;
}

-(void) startDownload:(void(^)(UIImage *img))complete {
    if(self.image) {
        return;
    }
    if(self.isDownloading) {
        return;
    }
    // 命中 SDWebImage 缓存（内存或磁盘）就直接用，跳过 download——不然每次 cell refresh 都会
    // 新建一个 attachment 实例（self.image=nil），triggerImageDownloads 又会跑一遍下载，
    // 用户视觉上看到的就是图片「闪一下」。同 URL 走 SDImageCache 同一 key 必然命中。
    UIImage *cachedMem = [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:self.url];
    if (cachedMem) {
        self.image = cachedMem;
        if (complete) complete(cachedMem);
        return;
    }
    self.isDownloading = true;
    __weak typeof(self) weakSelf = self;
    // 走 SDWebImageManager 而非 raw downloader——它会先查 disk cache（命中则不发网络请求），
    // 拉完也会自动写回 memory cache（下次 cell 复用直接命中上面的 memory 分支）。
    [[SDWebImageManager sharedManager] loadImageWithURL:[NSURL URLWithString:self.url]
                                                options:0
                                               progress:nil
                                              completed:^(UIImage * _Nullable image,
                                                          NSData * _Nullable data,
                                                          NSError * _Nullable error,
                                                          SDImageCacheType cacheType,
                                                          BOOL finished,
                                                          NSURL * _Nullable imageURL) {
        weakSelf.isDownloading = false;
        if (image) {
            weakSelf.image = image;
            if (complete) {
                complete(image);
            }
        }
    }];
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer proposedLineFragment:(CGRect)lineFrag glyphPosition:(CGPoint)position characterIndex:(NSUInteger)charIndex {
    if(!CGSizeEqualToSize(self.displaySize, CGSizeZero)) {
        return CGRectMake(0.0f, 0.0f, self.displaySize.width, self.displaySize.height);
    }
    if(self.image) {
        return CGRectMake(0.0f, 0.0f, self.image.size.width,  self.image.size.height);
    }
    return CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
}

@end
