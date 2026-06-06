//
//  WKVideoLoadProgressHUD.m
//  WuKongBase
//

#import "WKVideoLoadProgressHUD.h"
#import "WKApp.h"
#import "WuKongBase.h"

static const CGFloat kCardW = 240.0f;
static const CGFloat kCardH = 200.0f;
static const CGFloat kRingSide = 72.0f;

@interface WKVideoLoadProgressHUD ()
@property(nonatomic, strong) UIView *card;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *percentLabel;
@property(nonatomic, strong) UIButton *cancelButton;
@property(nonatomic, strong) CAShapeLayer *trackLayer;
@property(nonatomic, strong) CAShapeLayer *progressLayer;
@end

@implementation WKVideoLoadProgressHUD

+ (instancetype)showWithTitle:(NSString *)title {
    UIWindow *win = [WKApp.shared findWindow] ?: [UIApplication sharedApplication].keyWindow;
    WKVideoLoadProgressHUD *hud = [[self alloc] initWithFrame:win.bounds];
    hud.titleLabel.text = title;
    [win addSubview:hud];
    return hud;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
        [self setupCard];
    }
    return self;
}

- (void)setupCard {
    self.card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kCardW, kCardH)];
    self.card.center = self.center;
    self.card.layer.cornerRadius = 14.0f;
    self.card.layer.masksToBounds = YES;
    self.card.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.98];
    [self addSubview:self.card];

    // 标题
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 18, kCardW - 32, 20)];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.titleLabel.textColor = [UIColor blackColor];
    [self.card addSubview:self.titleLabel];

    // 圆形进度
    CGFloat ringX = (kCardW - kRingSide) * 0.5;
    CGFloat ringY = 48;
    CGRect ringFrame = CGRectMake(ringX, ringY, kRingSide, kRingSide);

    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(kRingSide * 0.5, kRingSide * 0.5)
                                                        radius:kRingSide * 0.5 - 3
                                                    startAngle:-M_PI_2
                                                      endAngle:-M_PI_2 + 2 * M_PI
                                                     clockwise:YES];

    self.trackLayer = [CAShapeLayer layer];
    self.trackLayer.frame = ringFrame;
    self.trackLayer.path = path.CGPath;
    self.trackLayer.strokeColor = [UIColor colorWithWhite:0.88 alpha:1.0].CGColor;
    self.trackLayer.fillColor = [UIColor clearColor].CGColor;
    self.trackLayer.lineWidth = 4.0f;
    [self.card.layer addSublayer:self.trackLayer];

    self.progressLayer = [CAShapeLayer layer];
    self.progressLayer.frame = ringFrame;
    self.progressLayer.path = path.CGPath;
    self.progressLayer.strokeColor = ([WKApp shared].config.themeColor ?: [UIColor systemBlueColor]).CGColor;
    self.progressLayer.fillColor = [UIColor clearColor].CGColor;
    self.progressLayer.lineWidth = 4.0f;
    self.progressLayer.lineCap = kCALineCapRound;
    self.progressLayer.strokeEnd = 0.0;
    [self.card.layer addSublayer:self.progressLayer];

    // 百分比
    self.percentLabel = [[UILabel alloc] initWithFrame:ringFrame];
    self.percentLabel.textAlignment = NSTextAlignmentCenter;
    self.percentLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold];
    self.percentLabel.textColor = [UIColor blackColor];
    self.percentLabel.text = @"0%";
    [self.card addSubview:self.percentLabel];

    // 取消按钮（默认隐藏，setOnCancel 后显示）
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.cancelButton.frame = CGRectMake(0, kCardH - 44, kCardW, 44);
    [self.cancelButton setTitle:LLang(@"取消") forState:UIControlStateNormal];
    [self.cancelButton setTitleColor:[UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0]
                            forState:UIControlStateNormal];
    self.cancelButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.cancelButton.hidden = YES;
    [self.cancelButton addTarget:self action:@selector(cancelPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:self.cancelButton];

    // 分割线
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, kCardH - 44.5, kCardW, 0.5)];
    sep.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    [self.card addSubview:sep];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.card.center = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);
}

- (void)setOnCancel:(void (^)(void))onCancel {
    _onCancel = [onCancel copy];
    self.cancelButton.hidden = (onCancel == nil);
}

- (void)cancelPressed {
    if (self.onCancel) {
        self.onCancel();
    }
}

- (void)setProgress:(double)progress {
    if (![NSThread isMainThread]) {
        __weak typeof(self) ws = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [ws setProgress:progress]; });
        return;
    }
    double p = MAX(0.0, MIN(1.0, progress));
    // strokeEnd 直接设，CAShapeLayer 默认会带动画（短暂过渡）
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.15];
    self.progressLayer.strokeEnd = p;
    [CATransaction commit];
    self.percentLabel.text = [NSString stringWithFormat:@"%.0f%%", p * 100.0];
}

- (void)dismiss {
    if (![NSThread isMainThread]) {
        __weak typeof(self) ws = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [ws dismiss]; });
        return;
    }
    // 必须 nil 掉 onCancel: 调用方 (WKPhotoService) 在 block 里 strong-capture hud,
    // 形成 hud → _onCancel block → hud 闭环; 不主动断, HUD + 闭包链 (transitively 含
    // avatar VC 回调) 每次都漏 (PR #32 R7 review)。
    self.onCancel = nil;
    [UIView animateWithDuration:0.18
                     animations:^{ self.alpha = 0; }
                     completion:^(BOOL finished) { [self removeFromSuperview]; }];
}

@end
