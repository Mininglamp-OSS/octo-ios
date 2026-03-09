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
    self.isDownloading  = true;
    __weak typeof(self) weakSelf = self;
    [[SDWebImageDownloader sharedDownloader] downloadImageWithURL:[NSURL URLWithString:self.url] completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
        weakSelf.isDownloading = false;
        if(image) {
            weakSelf.image = image;
            if(complete) {
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
