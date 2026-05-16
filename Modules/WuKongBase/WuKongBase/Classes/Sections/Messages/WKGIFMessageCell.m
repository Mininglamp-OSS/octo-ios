//
//  WKGIFMessageCell.m
//  WuKongBase
//
//  Created by tt on 2020/2/2.
//

#import "WKGIFMessageCell.h"
#import <SDWebImage/SDWebImage.h>
#import "WKGIFContent.h"
#import "UIImage+WK.h"
#import "WKResource.h"
#define WK_GIF_MAX_WIDTH 150.0f


@interface WKGIFMessageCell ()

@property(nonatomic,strong) SDAnimatedImageView *imgView;

@end

@implementation WKGIFMessageCell

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    WKGIFContent *content = (WKGIFContent*)model.content;
    CGFloat width = content.width;
    CGFloat height = content.height;
    if(content.width <= 0) {
        width = 100.0f;
    }
    if(content.height <= 0) {
        height = 100.0f;
    }
    return  [UIImage lim_sizeWithImageOriginSize:CGSizeMake(width, height) maxLength:WK_GIF_MAX_WIDTH];
}

- (void)initUI {
    [super initUI];
    self.imgView = [[SDAnimatedImageView alloc] init];
    [self.imgView setSd_imageIndicator:SDWebImageActivityIndicator.grayIndicator];
    self.imgView.layer.masksToBounds = YES;
    self.imgView.layer.cornerRadius = 5.0f;
    [self.messageContentView addSubview:self.imgView];
    [self.messageContentView sendSubviewToBack:self.imgView];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    WKGIFContent *content = (WKGIFContent*)model.content;
    [self.imgView lim_setImageWithURL:[[WKApp shared] getImageFullUrl:content.url]];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.imgView.lim_size = self.messageContentView.lim_size;
    
    
}

- (BOOL)tailWrap {
    return true;
}


+(BOOL) hiddenBubble {
    return YES;
}


-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}
@end
