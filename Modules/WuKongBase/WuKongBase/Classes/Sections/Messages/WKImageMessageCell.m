//
//  WKImageMessageCell.m
//  WuKongBase
//
//  Created by tt on 2020/1/14.
//

#import "WKImageMessageCell.h"
#import "WKMessageModel.h"
#import "UIImage+WK.h"
#import <YBImageBrowser/YBImageBrowser.h>
#import "WKDefaultWebImageMediator.h"
#import "WKResource.h"
#import "WKLoadProgressView.h"
#import <SDWebImage/SDWebImage.h>
#import <SDWebImage/NSData+ImageContentType.h>
#import <YYImage/YYImage.h>
#import <WuKongBase/WuKongBase-Swift.h>
#import "WKKeyboardService.h"

#define flameImageSize CGSizeMake(150.0f, 150.0f)

@interface WKImageMessageCell ()
@property(nonatomic,strong) UIImageView *imgView;



@property(nonatomic,strong) WKLoadProgressView *progressView;

// 上传任务
@property(nonatomic,strong) WKMessageFileUploadTask *uploadTask;

@property(nonatomic,strong) UIVisualEffectView *visualEffectView;


@end

@implementation WKImageMessageCell

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    WKImageContent *imageContent = (WKImageContent*)model.content;
    
    if(imageContent.flame) {
        return flameImageSize;
    }
    
    CGSize size = [UIImage lim_sizeWithImageOriginSize:CGSizeMake(imageContent.width, imageContent.height)];
    if(size.height <= 0) {
        size.height = 80.0f;
    }
    if(size.width <= 0) {
        size.width = 80.0f;
    }
    
    CGFloat minWidth = 150.f;
    CGFloat minHeight = 150.0f;
    if(size.width == size.height && size.height < minHeight) {
        CGFloat scale = minHeight/size.height;
        size = CGSizeMake(scale*size.width, minHeight);
    } else if(size.width<size.height && size.height<minHeight) {
        CGFloat scale = minHeight/size.height;
        size = CGSizeMake(size.width *scale, minHeight);
    }else if(size.width>size.height && size.width<minWidth) {
        CGFloat scale = minWidth/size.width;
        size = CGSizeMake(minWidth, size.height*scale);
    }
    if(size.width <=0.0f && size.height<=0.0f) {
        return CGSizeMake(minWidth, minHeight);
    }
    return size;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    if(self.uploadTask) {
        [self.uploadTask removeListener:self];
    }
    if(self.messageModel) {
        WKImageContent *imageContent = (WKImageContent*)self.messageModel.content;
        [imageContent releaseData];
    }
}

-(void) initUI {
    [super initUI];
    
    CGFloat imageViewRadius = 5.0f;
    
    self.imgView = [[WKImageView alloc] init];
    self.imgView.layer.masksToBounds = YES;
    self.imgView.layer.cornerRadius = imageViewRadius;
    self.imgView.clipsToBounds = YES;
    self.imgView.contentMode = UIViewContentModeScaleAspectFill;
    if([WKApp shared].config.style == WKSystemStyleDark) {
        [self.imgView setSd_imageIndicator:SDWebImageActivityIndicator.whiteIndicator];
    }else {
        [self.imgView setSd_imageIndicator:SDWebImageActivityIndicator.grayIndicator];
    }
    
    [self.messageContentView addSubview:self.imgView];
    [self.messageContentView sendSubviewToBack:self.imgView];
    
    self.progressView = [[WKLoadProgressView alloc] initWithFrame:CGRectMake(18, 0, 44, 44)];
    self.progressView.maxProgress = 1.0f;
    self.progressView.backgroundColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:0.7];
    self.progressView.layer.masksToBounds = YES;
    self.progressView.layer.cornerRadius = imageViewRadius;
    [self.messageContentView addSubview:self.progressView];
    
    if(WKApp.shared.config.style == WKSystemStyleDark) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        self.visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    }else {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        self.visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    }
    self.visualEffectView.layer.masksToBounds = YES;
    self.visualEffectView.layer.cornerRadius = imageViewRadius;
    [self.messageContentView addSubview:self.visualEffectView];
    
    [self.flameBox removeFromSuperview];
    self.flameBox.lim_size = CGSizeMake(60.0f, 60.0f);
    [self.messageContentView addSubview:self.flameBox];
    
    [self.messageContentView bringSubviewToFront:self.trailingView];
   
    
}

- (void)refresh:(WKMessageModel *)model {
    
    model.flameIconSizeFactor = 1.2f;
    model.flameNode.view.lim_size =  CGSizeMake(60.0f, 60.0f);
    
    [super refresh:model];
    self.messageModel = model;
    WKImageContent *imageContent = (WKImageContent*)model.content;
    CGSize imageSize = [WKImageMessageCell contentSizeForMessage:model];
    self.imgView.lim_width = imageSize.width;
    self.imgView.lim_height = imageSize.height;
    self.imgView.image = nil;
    [[self.imgView sd_imageIndicator] stopAnimatingIndicator];
    
    if(model.content.flame) {
        self.visualEffectView.hidden = NO;
    }else{
        self.visualEffectView.hidden = YES;
    }
      
    NSData *orgData = imageContent.originalImageData;
    if(orgData) {
        [self setImageWithData:orgData];
    }else {
        NSData *thumbData = [imageContent thumbnailData];
        if(thumbData) {
            [self setImageWithData:thumbData];
        }else{
            [[self.imgView sd_imageIndicator] startAnimatingIndicator];
            NSURL *url = [[WKApp shared] getImageFullUrl:imageContent.remoteUrl];
            [self.imgView lim_setImageWithURL:url options:SDWebImageProgressiveLoad|SDWebImageScaleDownLargeImages context:@{
                SDWebImageContextStoreCacheType: @(SDImageCacheTypeAll),
            } completed:nil];
        }
    }
    
    // 更新上传进度
    [self updateProgress];
    
   
}

-(void) setImageWithData:(NSData*)data {
    SDImageFormat imgFmt = [NSData sd_imageFormatForImageData:data];
    if(imgFmt == SDImageFormatGIF) {
        self.imgView.image = [[SDImageGIFCoder sharedCoder] decodedImageWithData:data options:0];
    }else {
        self.imgView.image = [[UIImage alloc] initWithData:data];
    }
}

// 更新上传进度
-(void) updateProgress {
      __weak typeof(self) weakSelf = self;
    // 上传进度控制
    self.uploadTask = [[WKSDK shared] getMessageFileUploadTask:self.messageModel.message];
    if(self.uploadTask) {
        [self.uploadTask addListener:^{
            if(weakSelf.uploadTask.status == WKTaskStatusProgressing) {
                if (![NSThread isMainThread]) {
                     dispatch_sync(dispatch_get_main_queue(), ^{
                         weakSelf.progressView.hidden = NO;
                         [weakSelf.progressView setProgress:weakSelf.uploadTask.progress];
                     });
                 }else {
                     weakSelf.progressView.hidden = NO;
                     [weakSelf.progressView setProgress:weakSelf.uploadTask.progress];
                 }
                
            }else {
                weakSelf.progressView.hidden = YES;
               [weakSelf.progressView setProgress:0];
            }
        } target:self];
       
    }else {
        self.progressView.hidden = YES;
        [self.progressView setProgress:0];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
     self.progressView.frame = self.messageContentView.bounds;
    
    self.visualEffectView.lim_size = self.messageContentView.lim_size;
    
    self.flameBox.lim_centerX_parent = self.messageContentView;
    self.flameBox.lim_centerY_parent = self.messageContentView;
    
}

- (BOOL)tailWrap {
    return true;
}

-(void) onTap {
    if(!self.messageModel) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    
    WKImageBrowser *imageBrowser = [[WKImageBrowser alloc] init];
    imageBrowser.toolViewHandlers = @[];
    imageBrowser.webImageMediator = [WKDefaultWebImageMediator new];
    imageBrowser.conversationContext = self.conversationContext;
    imageBrowser.onEditFinish = ^(UIImage *img) {
        WKImageContent *content = [WKImageContent initWithImage:img];
        [weakSelf.conversationContext sendMessage:content];
    };
    if(self.messageModel.content.flame) {
        YBIBImageData *data = [YBIBImageData new];
        data.extraData = @{@"message":self.messageModel};
        WKImageContent *imageContent = (WKImageContent*)self.messageModel.content;
        NSData *orgData = imageContent.originalImageData;
        if(orgData) {
            data.image = ^UIImage * _Nullable{
                return [YYImage imageWithData:orgData];
            };
        }
        if(!data.image) {
            data.imageURL = [[WKApp shared] getImageFullUrl:imageContent.remoteUrl];
        }
        imageBrowser.dataSourceArray = @[data];
        imageBrowser.currentPage =1; // currentPage需要放在dataSourceArray后面
        [imageBrowser showToView:[WKApp.shared findWindow]];
        
        self.messageModel.startingFlameFlag = false;
        if(!weakSelf.messageModel.viewed) {
            [WKSDK.shared.flameManager didViewed:@[weakSelf.messageModel.message]];
        }
       
        weakSelf.messageModel.OnFlameFinished = ^{
            [imageBrowser hide];
        };
        return;
    }
  
    
    
    NSArray<NSString*> *dates = [self.conversationContext dates];
    if(dates) {
        NSInteger mpos = 0;
        NSMutableArray<id<YBIBDataProtocol>> *dataArray = [NSMutableArray array];
        for (NSInteger i=dates.count-1; i>=0; i--) {
            NSString *date = dates[i];
            NSArray<WKMessageModel*> *messages = [self.conversationContext messagesAtDate:date];
            if(messages && messages.count>0) {
                for (NSInteger j=messages.count-1; j>=0; j--) {
                    WKMessageModel *messageModel = messages[j];
                    if(messageModel.contentType != WK_IMAGE || messageModel.revoke || messageModel.message.isDeleted) {
                        continue;
                    }
                    YBIBImageData *data = [YBIBImageData new];
                    data.extraData = @{@"message":messageModel};
                    WKImageContent *imageContent = (WKImageContent*)messageModel.content;
                    NSData *orgData = imageContent.originalImageData;
                    if(orgData) {
                        data.image = ^UIImage * _Nullable{
                            return [YYImage imageWithData:orgData];
                        };
                    }
                    UITableViewCell *cell = [self.conversationContext cellForRowAtIndex:[NSIndexPath indexPathForRow:j inSection:i]];
                    if(cell && [cell isKindOfClass:[WKImageMessageCell class]]) {
                        UIImage *image = ((WKImageMessageCell*)cell).imgView.image;
                        if(image) {
                            // TODO: 以下代码会使点开图片的速度变慢
                            NSData *imgData = [[SDImageCodersManager sharedManager] encodedDataWithImage:image format:[image sd_imageFormat] options:nil];
                            if (imgData) {
                                data.image = ^UIImage * _Nullable{
                                    return [YYImage imageWithData:imgData];
                                };
                            }
                        }
                        data.projectiveView = ((WKImageMessageCell*)cell).imgView;
                    }
                    if(!data.image) {
                        data.imageURL = [[WKApp shared] getImageFullUrl:imageContent.remoteUrl];
                    }
                    [dataArray insertObject:data atIndex:0];
                    
                    if(self.messageModel.clientSeq == messageModel.clientSeq) {
                        mpos = dataArray.count;
                    }
                }
            }
        }
       
        imageBrowser.dataSourceArray = dataArray;
        imageBrowser.currentPage =dataArray.count - mpos; // currentPage需要放在dataSourceArray后面
       
        [imageBrowser showToView:[WKApp.shared findWindow]];
       
    }
    
}



+(BOOL) hiddenBubble {
    return YES;
}


-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}


@end
