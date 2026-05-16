//
//  WKLastImgView.m
//  WuKongBase
//
//  Created by tt on 2020/7/17.
//

#import "WKLastImgView.h"
#import "WuKongBase.h"
#import <Photos/Photos.h>
static NSDate *lastImgDate; // 最新一张图时间
@interface WKLastImgView ()
@property(nonatomic,strong) UIView *containerView;
@property(nonatomic,strong) UIImageView *lastImgView;
@property(nonatomic,strong) UILabel *tipLbl;
@property(nonatomic,strong) UIImage *image;
@property(nonatomic,strong) PHAsset *lastAsset;

@end

@implementation WKLastImgView

- (instancetype)init
{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f,80.0f, 130.0f)];
    if (self) {
        [self setBackgroundColor:[UIColor clearColor]];
        [self addSubview:self.containerView];
        [self.containerView addSubview:self.tipLbl];
        [self.containerView addSubview:self.lastImgView];
        if(!lastImgDate) {
            lastImgDate = [NSDate date];
        }
    }
    return self;
}

#pragma mark - Draw triangle
- (void)drawRect:(CGRect)rect {
    // 设置背景色
    [[UIColor whiteColor] set];
    //拿到当前视图准备好的画板
    CGContextRef context = UIGraphicsGetCurrentContext();
    //利用path进行绘制三角形
    CGContextBeginPath(context);
    CGPoint point = CGPointMake(self.lim_width/2.0f+5.0f, self.lim_height);
    // 设置起点
    CGContextMoveToPoint(context, point.x, point.y);
    // 画线
    CGContextAddLineToPoint(context, point.x - 10, point.y - 10);
    CGContextAddLineToPoint(context, point.x + 10, point.y - 10);
    CGContextClosePath(context);
    // 设置填充色
    [[UIColor whiteColor] setFill];
    // 设置边框颜色
    [[UIColor whiteColor] setStroke];
    // 绘制路径
    CGContextDrawPath(context, kCGPathFillStroke);
}

- (UIView *)containerView {
    if(!_containerView) {
        _containerView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.lim_width, self.lim_height - 10.0f)];
        [_containerView setBackgroundColor:[UIColor whiteColor]];
        _containerView.layer.masksToBounds = YES;
        _containerView.layer.cornerRadius = 4.0f;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(containerViewClick)];
        [_containerView addGestureRecognizer:tap];
    }
    return _containerView;
}

-(void) containerViewClick {
    if(self.onClick) {
        self.hidden = YES;
        __weak typeof(self) weakSelf = self;
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        [[PHImageManager defaultManager] requestImageForAsset:self.lastAsset targetSize:CGSizeMake(WKScreenWidth*3, WKScreenHeight*3) contentMode:PHImageContentModeDefault options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
              weakSelf.onClick(result);
        }];
        
//        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
//        [[PHImageManager defaultManager] requestImageDataForAsset:self.lastAsset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
//            UIImage * image = [UIImage imageWithData:imageData];
//            weakSelf.onClick(image);
//        }];
        
    }
}

- (UIImageView *)lastImgView {
    if(!_lastImgView) {
        _lastImgView = [[UIImageView alloc] initWithFrame:CGRectMake(2.0f, self.tipLbl.lim_bottom+2.0f, self.containerView.lim_width-4.0f, self.containerView.lim_width-4.0f)];
        _lastImgView.layer.masksToBounds = YES;
        _lastImgView.layer.cornerRadius = 4.0f;
        _lastImgView.contentMode = UIViewContentModeScaleAspectFill;
    }
    return _lastImgView;
}


- (void)showIfNeed {
    self.lastAsset =  [self getLastPHAsset];
    if(lastImgDate) {
        __weak typeof(self) weakSelf = self;
        NSTimeInterval lastImgTimeDiff = self.lastAsset.creationDate.timeIntervalSince1970 - lastImgDate.timeIntervalSince1970;
        if(lastImgTimeDiff!=0 && lastImgTimeDiff> 0 && lastImgTimeDiff < 5*60*60 ) { // 如果5分钟的新图，则显示
            self.hidden = NO;
            [self setLastImage:self.lastAsset];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                weakSelf.hidden = YES;
            });
        }
    }
    lastImgDate = self.lastAsset.creationDate;
}

-(void) resetCreateDate {
    lastImgDate = nil;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] initWithFrame:CGRectMake(2.0f, 0.0f, self.containerView.lim_width-4.0f, 0.0f)];
        _tipLbl.text = @"你可能要发送的照片：";
        _tipLbl.numberOfLines = 0;
        _tipLbl.lineBreakMode = NSLineBreakByWordWrapping;
        [_tipLbl setFont:[[WKApp shared].config appFontOfSize:12.0f]];
        [_tipLbl setTextColor:[WKApp shared].config.defaultTextColor];
        [_tipLbl sizeToFit];
        _tipLbl.lim_top = 5.0f;
    }
    return _tipLbl;
}

-(void) setLastImage:(PHAsset*)asset {
    __weak typeof(self) weakSelf  = self;
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(self.lastImgView.lim_width*3.0f, weakSelf.lastImgView.lim_height*3.0f) contentMode:PHImageContentModeDefault options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        weakSelf.lastImgView.image = result;
    }];
}

/// 获取最新的PHAsset对象
-(PHAsset*) getLastPHAsset {
    // 获取所有资源的集合，并按资源的创建时间排序
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    if (@available(iOS 9, *)) {
        options.fetchLimit = 1;
    }
    PHFetchResult *assetsFetchResults = [PHAsset fetchAssetsWithOptions:options];
    return [assetsFetchResults firstObject];
}
@end
