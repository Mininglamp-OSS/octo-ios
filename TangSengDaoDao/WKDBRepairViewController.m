//
//  WKDBRepairViewController.m
//  TangSengDaoDao
//

#import "WKDBRepairViewController.h"
#import "WKDBRecoveryManager.h"

static UIColor *AccentColor(void) {
    return [UIColor colorWithRed:0.40 green:0.27 blue:0.86 alpha:1.0]; // 紫色主题
}

@interface WKDBRepairViewController ()
@property(nonatomic, strong) UIImageView  *iconView;
@property(nonatomic, strong) UIProgressView *progressView;
@property(nonatomic, strong) UILabel      *titleLabel;
@property(nonatomic, strong) UILabel      *subtitleLabel;
@property(nonatomic, strong) UILabel      *stepLabel;
@property(nonatomic, strong) UIButton     *restartButton;
@end

@implementation WKDBRepairViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startRepair];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // 标题
    self.titleLabel = [UILabel new];
    self.titleLabel.text = @"数据库修复";
    self.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // 副标题
    self.subtitleLabel = [UILabel new];
    self.subtitleLabel.text = @"检测到数据库损坏，正在为您修复";
    self.subtitleLabel.font = [UIFont systemFontOfSize:14];
    self.subtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.numberOfLines = 0;
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // 扳手图标
    UIImage *wrenchImage = [UIImage systemImageNamed:@"wrench.and.screwdriver.fill"
                                  withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:72 weight:UIImageSymbolWeightMedium]];
    self.iconView = [[UIImageView alloc] initWithImage:wrenchImage];
    self.iconView.tintColor = AccentColor();
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.translatesAutoresizingMaskIntoConstraints = NO;

    // 进度条
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.progressView.progressTintColor = AccentColor();
    self.progressView.trackTintColor = [UIColor colorWithWhite:0.88 alpha:1.0];
    self.progressView.progress = 0;
    self.progressView.layer.cornerRadius = 2;
    self.progressView.clipsToBounds = YES;
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;

    // 步骤说明
    self.stepLabel = [UILabel new];
    self.stepLabel.text = @"准备开始...";
    self.stepLabel.font = [UIFont systemFontOfSize:13];
    self.stepLabel.textColor = [UIColor tertiaryLabelColor];
    self.stepLabel.textAlignment = NSTextAlignmentCenter;
    self.stepLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // 重启按钮（完成后显示）
    self.restartButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.restartButton setTitle:@"重启应用" forState:UIControlStateNormal];
    self.restartButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.restartButton.backgroundColor = AccentColor();
    [self.restartButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.restartButton.layer.cornerRadius = 12;
    self.restartButton.alpha = 0;
    self.restartButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.restartButton addTarget:self action:@selector(onRestart) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.titleLabel];
    [self.view addSubview:self.subtitleLabel];
    [self.view addSubview:self.iconView];
    [self.view addSubview:self.progressView];
    [self.view addSubview:self.stepLabel];
    [self.view addSubview:self.restartButton];

    [NSLayoutConstraint activateConstraints:@[
        // 标题居中偏上
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.iconView.topAnchor constant:-36],

        // 副标题
        [self.subtitleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.titleLabel.topAnchor constant:-8],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],

        // 扳手图标居中
        [self.iconView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.iconView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-20],
        [self.iconView.widthAnchor constraintEqualToConstant:80],
        [self.iconView.heightAnchor constraintEqualToConstant:80],

        // 进度条
        [self.progressView.topAnchor constraintEqualToAnchor:self.iconView.bottomAnchor constant:32],
        [self.progressView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:48],
        [self.progressView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-48],
        [self.progressView.heightAnchor constraintEqualToConstant:4],

        // 步骤说明
        [self.stepLabel.topAnchor constraintEqualToAnchor:self.progressView.bottomAnchor constant:12],
        [self.stepLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.stepLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [self.stepLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],

        // 重启按钮
        [self.restartButton.topAnchor constraintEqualToAnchor:self.stepLabel.bottomAnchor constant:36],
        [self.restartButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.restartButton.widthAnchor constraintEqualToConstant:200],
        [self.restartButton.heightAnchor constraintEqualToConstant:50],
    ]];

    [self startWrenchAnimation];
}

#pragma mark - 扳手旋转动画

- (void)startWrenchAnimation {
    CABasicAnimation *rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotation.fromValue = @(0);
    rotation.toValue   = @(M_PI * 2);
    rotation.duration  = 1.8;
    rotation.repeatCount = INFINITY;
    rotation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.iconView.layer addAnimation:rotation forKey:@"wrenchSpin"];
}

- (void)stopWrenchAnimation {
    [self.iconView.layer removeAnimationForKey:@"wrenchSpin"];
}

#pragma mark - 修复流程

- (void)startRepair {
    [[WKDBRecoveryManager shared]
        performRecoveryWithIMDBPath:self.imDBPath
        uid:self.uid
        progress:^(float p, NSString *step) {
            [self.progressView setProgress:p animated:YES];
            self.stepLabel.text = step;
        }
        completion:^(BOOL success, NSError *error) {
            if (success) {
                [self showRepairComplete];
            } else {
                [self showRepairFailed:error];
            }
        }
    ];
}

- (void)showRepairComplete {
    [self stopWrenchAnimation];

    // 扳手 → 对勾，带弹跳动画
    UIImage *doneImage = [UIImage systemImageNamed:@"checkmark.circle.fill"
                               withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:72 weight:UIImageSymbolWeightMedium]];
    [UIView transitionWithView:self.iconView
                      duration:0.4
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        self.iconView.image = doneImage;
                        self.iconView.tintColor = [UIColor systemGreenColor];
                    }
                    completion:nil];

    // 弹跳
    self.iconView.transform = CGAffineTransformMakeScale(0.7, 0.7);
    [UIView animateWithDuration:0.5
                          delay:0.1
         usingSpringWithDamping:0.5
          initialSpringVelocity:0.8
                        options:0
                     animations:^{ self.iconView.transform = CGAffineTransformIdentity; }
                     completion:nil];

    self.titleLabel.text = @"修复完成";
    self.subtitleLabel.text = @"数据库已重建，历史消息将在重启后从服务器同步";
    self.stepLabel.text = @"";
    [self.progressView setProgress:1.0 animated:YES];

    [UIView animateWithDuration:0.4 delay:0.5 options:0 animations:^{
        self.restartButton.alpha = 1;
    } completion:nil];
}

- (void)showRepairFailed:(NSError *)error {
    [self stopWrenchAnimation];
    UIImage *failImage = [UIImage systemImageNamed:@"xmark.circle.fill"
                               withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:72 weight:UIImageSymbolWeightMedium]];
    self.iconView.image = failImage;
    self.iconView.tintColor = [UIColor systemRedColor];
    self.titleLabel.text = @"修复失败";
    self.subtitleLabel.text = @"请尝试卸载并重新安装应用";
    self.stepLabel.text = error.localizedDescription ?: @"";
}

#pragma mark - 重启

- (void)onRestart {
    // 给用户 0.3s 视觉反馈再退出
    [UIView animateWithDuration:0.15 animations:^{
        self.restartButton.alpha = 0.6;
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            exit(0);
        });
    }];
}

@end
