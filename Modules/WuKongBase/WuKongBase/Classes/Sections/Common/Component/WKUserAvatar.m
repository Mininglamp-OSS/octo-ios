//
//  WKUserAvatar.m
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import "WKUserAvatar.h"

#import "WKApp.h"
#import "UIView+WK.h"
#import "UIImageView+WK.h"


@interface WKUserAvatar ()
@property(nonatomic,strong) UIView *avatarBox;

@end

@implementation WKUserAvatar

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.borderWidth = 0.0f;
        [self setupUI];
    }
    return self;
}
- (instancetype)init
{
    return [self initWithFrame:CGRectMake(0.0f, 0.0f, WKDefaultAvatarSize.width, WKDefaultAvatarSize.height)];;
}

-(void) setupUI {
    [self addSubview:self.avatarBox];
    [self.avatarBox addSubview:self.avatarImgView];
    self.layer.shouldRasterize = YES;
    self.layer.rasterizationScale = [UIScreen mainScreen].scale;
}

- (UIImageView *)avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[WKImageView alloc] initWithFrame:CGRectMake(self.borderWidth/2.0f, self.borderWidth/2.0f, self.frame.size.width -self.borderWidth, self.frame.size.height - self.borderWidth)];
        _avatarImgView.layer.masksToBounds = YES;
        _avatarImgView.layer.cornerRadius = _avatarImgView.frame.size.width*0.4;
    }
    return _avatarImgView;
}

- (void)setUrl:(NSString *)url {
    _url = url;
    UIImage *memCached = [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:url];
    NSLog(@"[Avatar] setUrl: memoryCache=%@ url=%@", memCached ? @"HIT" : @"MISS", url);
    [_avatarImgView sd_setImageWithURL:[NSURL URLWithString:url]
                      placeholderImage:[WKApp shared].config.defaultAvatar
                               options:SDWebImageAllowInvalidSSLCertificates
                             completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        NSString *source = (cacheType == SDImageCacheTypeMemory) ? @"memory" :
                           (cacheType == SDImageCacheTypeDisk) ? @"disk" : @"network";
        NSLog(@"[Avatar] setUrl loaded: source=%@, hasImage=%@, error=%@", source, image ? @"YES" : @"NO", error);
    }];
}

// 跳过所有缓存，直接从服务器下载最新头像，下载后自动存入缓存
- (void)refreshUrlFromServer:(NSString *)url {
    _url = url;
    [_avatarImgView sd_setImageWithURL:[NSURL URLWithString:url]
                      placeholderImage:[WKApp shared].config.defaultAvatar
                               options:SDWebImageAllowInvalidSSLCertificates | SDWebImageFromLoaderOnly
                             completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        NSLog(@"[Avatar] refreshFromServer done: hasImage=%@, error=%@, url=%@", image ? @"YES" : @"NO", error, imageURL);
    }];
}

- (void)setBorderWidth:(CGFloat)borderWidth {
    _borderWidth = borderWidth;
    self.avatarImgView.frame = CGRectMake(borderWidth/2.0f, borderWidth/2.0f, self.frame.size.width -borderWidth, self.frame.size.height - borderWidth);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self.avatarBox setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
}


- (UIView *)avatarBox {
    if(!_avatarBox) {
        _avatarBox = [[UIView alloc] initWithFrame:self.bounds];
        _avatarBox.layer.masksToBounds = YES;
        _avatarBox.layer.cornerRadius = _avatarBox.frame.size.width*0.4;
    }
    return _avatarBox;
}

@end
