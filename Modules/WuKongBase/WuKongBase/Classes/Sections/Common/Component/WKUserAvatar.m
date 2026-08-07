//
//  WKUserAvatar.m
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import "WKUserAvatar.h"

#import "WKApp.h"
#import "WKAvatarUtil.h"
#import "UIView+WK.h"
#import "UIImageView+WK.h"


@interface WKUserAvatar ()
@property(nonatomic,strong) UIView *avatarBox;

@end

@implementation WKUserAvatar

// 诊断开关定义（声明在 .h）：保留为兼容性 no-op。
// 真正的根因 fix 现在在 WKImageView：默认 autoPlayAnimatedImage=NO + cell 显式控制 start/stop。
// 这个 flag 即使设 YES 也不会有额外效果（因为 WKImageView 已经默认不自动播放）。
const BOOL kDisableAvatarAnimation = NO;

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
        _avatarImgView.layer.cornerRadius = _avatarImgView.frame.size.width*0.5;
        // 诊断开关：关掉头像动图自动播放。SDAnimatedImageView 默认 autoPlayAnimatedImage=YES，
        // 群里多个动图头像会各自跑 CADisplayLink，主线程被持续薅 → HANG 100-150ms 周期。
        if (kDisableAvatarAnimation) {
            _avatarImgView.autoPlayAnimatedImage = NO;
        }
    }
    return _avatarImgView;
}

#pragma mark - 头像 placeholder（避免刷新时闪默认头像）

// 「上次成功加载过的头像」缓存：key = 去掉末尾 ?v= cache-buster 后的稳定 URL（同一身份）。
//
// 为什么需要：SDK 的 refreshAvatarCacheKey 会把 avatarCacheKey 换成新 UUID
// （fetchChannelInfo / 群成员变化 / 进「我的-个人资料」等入口都会触发），URL 上的 ?v=
// 一抖动，SDWebImage 就是全新的 cacheKey → 内存/磁盘双 miss → placeholder 立刻把
// imageView 刷成默认头像，等下载完才换回真头像，肉眼看到默认头像闪一下。
// 这里把同一身份上次加载成功的图当 placeholder：刷新期间继续显示老头像，新头像下载完
// 直接替换；只有这个身份从没加载成功过（用户确实没设过头像）才落到 config.defaultAvatar。
//
// NSCache 在内存告警时会自行释放，且只持有 SD 内存缓存里同一批 UIImage 的引用，
// 额外常驻开销可忽略。
+ (NSCache<NSString *, UIImage *> *)lastLoadedAvatarCache {
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 64;
        cache.totalCostLimit = 16 * 1024 * 1024; // 16MB
    });
    return cache;
}

+ (NSUInteger)costForImage:(UIImage *)image {
    CGFloat scale = image.scale > 0 ? image.scale : 1.0f;
    return (NSUInteger)(image.size.width * scale * image.size.height * scale * 4.0f);
}

// 返回该 url 对应身份的 placeholder，并回填稳定 key（供加载成功后回写缓存）
- (UIImage *)placeholderForURL:(NSString *)url stableKey:(NSString **)outStableKey {
    NSString *stableKey = url.length > 0 ? [WKAvatarUtil stableCacheKeyFromAvatarURL:url] : nil;
    if (outStableKey) {
        *outStableKey = stableKey;
    }
    UIImage *lastLoaded = nil;
    if (stableKey.length > 0) {
        lastLoaded = [[WKUserAvatar lastLoadedAvatarCache] objectForKey:stableKey];
    }
    // 当前 imageView 上显示的已经是同一身份的头像时也直接留着，别让它先变默认头像
    if (!lastLoaded && stableKey.length > 0 && _avatarImgView.image
        && [stableKey isEqualToString:[WKAvatarUtil stableCacheKeyFromAvatarURL:_url]]) {
        lastLoaded = _avatarImgView.image;
    }
    return lastLoaded ?: [WKApp shared].config.defaultAvatar;
}

- (void)rememberLoadedImage:(UIImage *)image forStableKey:(NSString *)stableKey {
    if (!image || stableKey.length == 0) {
        return;
    }
    [[WKUserAvatar lastLoadedAvatarCache] setObject:image
                                            forKey:stableKey
                                              cost:[WKUserAvatar costForImage:image]];
}

#pragma mark - 加载

- (void)setUrl:(NSString *)url {
    NSString *stableKey = nil;
    UIImage *placeholder = [self placeholderForURL:url stableKey:&stableKey];
    _url = url;
    __weak typeof(self) weakSelf = self;
    [_avatarImgView sd_setImageWithURL:[NSURL URLWithString:url]
                      placeholderImage:placeholder
                               options:SDWebImageAllowInvalidSSLCertificates
                             completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        [weakSelf rememberLoadedImage:image forStableKey:stableKey];
    }];
}

// 跳过所有缓存，直接从服务器下载最新头像，下载后自动存入缓存
- (void)refreshUrlFromServer:(NSString *)url {
    NSString *stableKey = nil;
    UIImage *placeholder = [self placeholderForURL:url stableKey:&stableKey];
    _url = url;
    __weak typeof(self) weakSelf = self;
    [_avatarImgView sd_setImageWithURL:[NSURL URLWithString:url]
                      placeholderImage:placeholder
                               options:SDWebImageAllowInvalidSSLCertificates | SDWebImageFromLoaderOnly
                             completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        [weakSelf rememberLoadedImage:image forStableKey:stableKey];
    }];
}

- (void)setBorderWidth:(CGFloat)borderWidth {
    _borderWidth = borderWidth;
    self.avatarImgView.frame = CGRectMake(borderWidth/2.0f, borderWidth/2.0f, self.frame.size.width -borderWidth, self.frame.size.height - borderWidth);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.avatarBox.frame = self.bounds;
    self.avatarBox.layer.cornerRadius = self.bounds.size.width * 0.5;
    CGFloat bw = self.borderWidth;
    self.avatarImgView.frame = CGRectMake(bw/2.0f, bw/2.0f, self.bounds.size.width - bw, self.bounds.size.height - bw);
    self.avatarImgView.layer.cornerRadius = self.avatarImgView.frame.size.width * 0.5;
    [self.avatarBox setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
}


- (UIView *)avatarBox {
    if(!_avatarBox) {
        _avatarBox = [[UIView alloc] initWithFrame:self.bounds];
        _avatarBox.layer.masksToBounds = YES;
        _avatarBox.layer.cornerRadius = _avatarBox.frame.size.width*0.5;
    }
    return _avatarBox;
}

@end
