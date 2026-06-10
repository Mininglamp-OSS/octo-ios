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

// 所有图片消息 cell 共享的后台解码队列。
// concurrent + USER_INITIATED:
//   - GIF preloadAllFrames 是 CPU-bound,串行会让多张图排队首屏延迟
//   - 上限并发由系统按 QoS 自动管控,无需手工 semaphore
//   - cell 离屏 / clientSeq 不再匹配时,result 在主线程被 guard 掉,bg 任务自身不强求 cancel
static dispatch_queue_t WKImageMessageCellDecodeQueue(void) {
    static dispatch_queue_t q;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INITIATED, 0);
        q = dispatch_queue_create("com.octo.imagemsg.decode", attr);
    });
    return q;
}

// preloadAllFrames 阈值。
// 超过任一阈值的动图只摸首帧 (避免 OOM),代价是首帧之后的帧仍 on-demand 解码,
// 可能继续 HANG —— 但相比"超大 GIF 全帧驻留几十 MB"更安全。
//   - 5MB 是一张全屏 GIF 的典型上限
//   - 80 帧 ≈ 一般 GIF 8~10s 内容
static const NSUInteger kWKImagePreloadMaxBytes = 5 * 1024 * 1024;
static const NSUInteger kWKImagePreloadMaxFrames = 80;

@interface WKImageMessageCell ()
@property(nonatomic,strong) WKImageView *imgView;



@property(nonatomic,strong) WKLoadProgressView *progressView;

// 上传任务
@property(nonatomic,strong) WKMessageFileUploadTask *uploadTask;

@property(nonatomic,strong) UIVisualEffectView *visualEffectView;


@end

@implementation WKImageMessageCell

// 接管 imgView 动图 lifecycle（WKImageView autoPlay=NO 后必须显式 setDisplayed）。
// 没有这一对的话，GIF 图片消息会永远静止——因为根 fix 关掉了 autoPlay。
- (void)onWillDisplay {
    [super onWillDisplay];
    [self.imgView wk_setDisplayed:YES];
}

- (void)onEndDisplay {
    [super onEndDisplay];
    [self.imgView wk_setDisplayed:NO];
}

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    if (![model.content isKindOfClass:[WKImageContent class]]) {
        return CGSizeMake(100, 100); // 竞态兜底
    }
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
    if([self.messageModel.content isKindOfClass:[WKImageContent class]]) {
        [(WKImageContent*)self.messageModel.content releaseData];
    }
}

-(void) initUI {
    [super initUI];
    
    CGFloat imageViewRadius = 5.0f;
    
    self.imgView = [[WKImageView alloc] init];
    // 聊天 cell 专属：关掉图片消息动图自动播放。配合 onWillDisplay/onEndDisplay 的
    // wk_setDisplayed 实现"只有 visible 区动图才动"。
    self.imgView.autoPlayAnimatedImage = NO;
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
    // 主线程清旧图: cell 复用 / 同 cell 切消息时,不让上一张图在 bg-decode 期间残留
    self.imgView.image = nil;
    [[self.imgView sd_imageIndicator] stopAnimatingIndicator];

    if(model.content.flame) {
        self.visualEffectView.hidden = NO;
    }else{
        self.visualEffectView.hidden = YES;
    }

    // 本地数据 (originalImageData / thumbnailData) 走 bg-decode 管线;
    // 仅当两者都没有时才走 SDWebImage URL 路径 (它本身已经异步)。
    //
    // 旧实现把 [NSData initWithContentsOfFile:] + [SDAnimatedImage imageWithData:]
    // 全部放在主线程,然后挂一个 lazy CGImage 上 layer,CA::Transaction::commit 阶段
    // 触发 GIFReadPlugin 现场逐行解码 → 100~150ms HANG/帧。
    //
    // 路径计算是廉价字符串拼接,主线程算好传进去即可;真正的 disk I/O + parse + 全帧
    // force-decode 都在 bg 队列里完成,回主线程只剩 setImage 一次赋值。
    NSString *localPath = [imageContent localPath];
    NSString *thumbPath = [imageContent thumbPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *loadPath = nil;
    if ([fm fileExistsAtPath:localPath]) {
        loadPath = localPath;
    } else if ([fm fileExistsAtPath:thumbPath]) {
        loadPath = thumbPath;
    }

    if (loadPath) {
        uint32_t expectClientSeq = model.clientSeq;
        __weak typeof(self) weakSelf = self;
        dispatch_async(WKImageMessageCellDecodeQueue(), ^{
            NSData *data = [NSData dataWithContentsOfFile:loadPath
                                                  options:NSDataReadingMappedIfSafe
                                                    error:nil];
            if (data.length == 0) {
                return;
            }
            // 优先按动图解;非动图 (PNG/JPEG/单帧 GIF) imageWithData: 返回 nil,回退普通 UIImage
            UIImage *img = [SDAnimatedImage imageWithData:data];
            if ([img isKindOfClass:[SDAnimatedImage class]]) {
                SDAnimatedImage *animImg = (SDAnimatedImage *)img;
                NSUInteger frameCount = animImg.animatedImageFrameCount;
                if (data.length <= kWKImagePreloadMaxBytes && frameCount <= kWKImagePreloadMaxFrames) {
                    // 全部帧预解 → frame map 写满,player 取帧零成本,CA::commit 不再现场解码
                    [animImg preloadAllFrames];
                } else {
                    // 超阈值大图: 只把首帧 ImageIO 读出来 (让 layer 第一次上屏不阻塞),
                    // 后续帧仍 on-demand。先保住"首屏不卡",其余靠 SDAnimatedImagePlayer
                    // 自己的 frame buffer。
                    (void)[animImg animatedImageFrameAtIndex:0];
                }
            } else {
                UIImage *staticImg = [[UIImage alloc] initWithData:data];
                if (staticImg) {
                    // 静态图: 把 lazy IIOProvider backing 换成 CGBitmapContext backing
                    img = [SDImageCoderHelper decodedImageWithImage:staticImg];
                } else {
                    img = nil;
                }
            }
            if (!img) {
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                // cell-identity 校验: bg 解码期间 cell 已被 TableView 复用给其他消息时,
                // 不能再覆盖回去。clientSeq 是消息唯一标识 (uint32_t,同一会话内不重复)。
                if (strongSelf.messageModel.clientSeq != expectClientSeq) return;
                strongSelf.imgView.image = img;
            });
        });
    } else {
        // 本地无文件,走 URL 异步管线
        [[self.imgView sd_imageIndicator] startAnimatingIndicator];
        NSURL *url = [[WKApp shared] getImageFullUrl:imageContent.remoteUrl];
        // 不能加 SDWebImageScaleDownLargeImages —— SDWebImage 5.5.0+ 把动图也按
        // imageThumbnailPixelSize 走,结果只解出单帧静态图,GIF / APNG / 动 WebP
        // 在气泡里就不动了。SDWebImageProgressiveLoad 对动图也不安全(流式解码
        // 中途的 partial 帧会替换掉完整动图)。聊天图片本身不会特别大,按原样
        // 解一次即可。
        [self.imgView lim_setImageWithURL:url options:0 context:@{
            SDWebImageContextStoreCacheType: @(SDImageCacheTypeAll),
        } completed:nil];
    }

    // 更新上传进度
    [self updateProgress];


}

// 旧的 setImageWithData: 同步主线程解码路径已被 refresh: 内联的 bg-decode 管线替代,
// 这里不再保留 —— 任何外部调用都应改走 refresh:。

// 更新上传进度
-(void) updateProgress {
      __weak typeof(self) weakSelf = self;
    // 上传进度控制
    self.uploadTask = [[WKSDK shared] getMessageFileUploadTask:self.messageModel.message];
    if(self.uploadTask) {
        [self.uploadTask addListener:^{
            if(weakSelf.uploadTask.status == WKTaskStatusProgressing) {
                if (![NSThread isMainThread]) {
                     dispatch_async(dispatch_get_main_queue(), ^{
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
                            NSData *imgData = nil;
                            // SDAnimatedImage 直接拿原始多帧字节，跳过 re-encode
                            // (re-encode 对 GIF/APNG/动 WebP 经常只输出当前帧，
                            // 大图浏览器拿到的就是静态图)。
                            if ([image conformsToProtocol:@protocol(SDAnimatedImage)]) {
                                imgData = [(id<SDAnimatedImage>)image animatedImageData];
                            }
                            if (!imgData) {
                                // TODO: 以下代码会使点开图片的速度变慢
                                imgData = [[SDImageCodersManager sharedManager] encodedDataWithImage:image format:[image sd_imageFormat] options:nil];
                            }
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
