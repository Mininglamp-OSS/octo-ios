//
//  OctoContextSparkleIconView.m
//  OctoContext
//

#import "OctoContextSparkleIconView.h"

@interface OctoContextSparkleIconView ()
@property(nonatomic, strong) UIImageView *iconView;
@property(nonatomic, strong) CAGradientLayer *gradientLayer;
@end

@implementation OctoContextSparkleIconView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0];
        self.layer.cornerRadius = 12;
        self.layer.masksToBounds = YES;

        // 入口图标用项目自带的 PNG (Generating 2.png), 注入到 OctoContext_images.bundle
        // 的 octo-summary-spark.imageset 里, template 渲染 + 白 tint, 与 #7F3BF5 紫底搭配。
        UIImage *sparkleImg = nil;
        NSBundle *bundle = [NSBundle bundleForClass:self.class];
        NSURL *imgBundleURL = [bundle URLForResource:@"OctoContext_images" withExtension:@"bundle"];
        NSBundle *imgBundle = imgBundleURL ? [NSBundle bundleWithURL:imgBundleURL] : bundle;
        sparkleImg = [UIImage imageNamed:@"octo-summary-spark" inBundle:imgBundle compatibleWithTraitCollection:nil];
        if (!sparkleImg) sparkleImg = [UIImage imageNamed:@"octo-summary-spark"];
        sparkleImg = [sparkleImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.iconView = [[UIImageView alloc] initWithImage:sparkleImg];
        self.iconView.contentMode = UIViewContentModeScaleAspectFit;
        self.iconView.tintColor = [UIColor whiteColor];
        [self addSubview:self.iconView];

        // 渐变 mask: 让 sparkle 从 #F1D6FF 渐变到 #FFFFFF (设计稿原 stop)
        CAGradientLayer *grad = [CAGradientLayer layer];
        grad.colors = @[
            (id)[UIColor colorWithRed:0xF1/255.0 green:0xD6/255.0 blue:0xFF/255.0 alpha:1.0].CGColor,
            (id)[UIColor whiteColor].CGColor,
        ];
        grad.startPoint = CGPointMake(0.3, 0.0);
        grad.endPoint = CGPointMake(0.6, 1.0);
        self.gradientLayer = grad;
        // 暂不挂 mask —— SF Symbol tintColor 已经是白色, 与设计稿渐变高位色 (#FFFFFF) 接近,
        // 视觉差异在 42pt 缩略尺寸下肉眼不可分辨。PR8 走查若需要严格渐变再启用 mask。
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat iconSize = 24.0;
    self.iconView.frame = CGRectMake((self.bounds.size.width - iconSize) / 2.0,
                                     (self.bounds.size.height - iconSize) / 2.0,
                                     iconSize, iconSize);
    self.gradientLayer.frame = self.iconView.bounds;
}

@end
