//
//  WKDarkModeVC.m
//  WuKongBase
//
//  Created by tt on 2020/12/11.
//

#import "WKDarkModeVC.h"

typedef NS_ENUM(NSInteger, WKAppearanceMode) {
    WKAppearanceModeSystem = 0,
    WKAppearanceModeLight,
    WKAppearanceModeDark,
};

@interface WKAppearanceOptionView : UIView
@property(nonatomic,assign) WKAppearanceMode mode;
@property(nonatomic,assign,getter=isSelected) BOOL selected;
@property(nonatomic,copy) void(^onTap)(WKAppearanceMode mode);
- (void)applyTitle:(NSString *)title;
@end

@interface WKDarkModeVC ()
@property(nonatomic,strong) UIScrollView *scrollView;
@property(nonatomic,strong) UIView *cardView;
@property(nonatomic,strong) NSArray<WKAppearanceOptionView*> *options;
@end

@implementation WKDarkModeVC

- (instancetype)init
{
    self = [super init];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;

    CGFloat margin = 16.0f;
    CGFloat topPad = 7.0f;          // 紧贴导航栏下方
    CGFloat cardW = self.view.bounds.size.width - margin * 2;
    CGFloat cardH = 240.0f;

    // ScrollView 撑满 nav 下方区域；cardView 放在 scrollView 内可滚动
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.scrollView];

    self.cardView = [[UIView alloc] initWithFrame:CGRectMake(margin, topPad, cardW, cardH)];
    self.cardView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    self.cardView.layer.cornerRadius = 16.0f;
    self.cardView.layer.masksToBounds = YES;
    [self.scrollView addSubview:self.cardView];

    NSArray<NSNumber*> *modes = @[@(WKAppearanceModeSystem), @(WKAppearanceModeLight), @(WKAppearanceModeDark)];
    NSArray<NSString*> *titles = @[LLang(@"跟随系统"), LLang(@"浅色模式"), LLang(@"深色模式")];
    NSMutableArray *opts = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;

    CGFloat optW = 80.0f;
    CGFloat optH = 199.0f;
    CGFloat innerPad = 20.0f;
    CGFloat gap = (cardW - innerPad * 2 - optW * 3) / 2.0f;
    for(NSInteger i = 0; i < modes.count; i++) {
        WKAppearanceOptionView *opt = [[WKAppearanceOptionView alloc] initWithFrame:CGRectMake(innerPad + i * (optW + gap), innerPad, optW, optH)];
        opt.mode = (WKAppearanceMode)[modes[i] integerValue];
        [opt applyTitle:titles[i]];
        opt.onTap = ^(WKAppearanceMode mode) {
            [weakSelf applyMode:mode];
        };
        [self.cardView addSubview:opt];
        [opts addObject:opt];
    }
    self.options = opts;

    [self syncSelection];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = self.navigationBar.lim_bottom;
    self.scrollView.frame = CGRectMake(0, top, self.view.bounds.size.width, self.view.bounds.size.height - top);
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, CGRectGetMaxY(self.cardView.frame) + 20.0f);
}

- (NSString *)langTitle {
    return LLang(@"外观");
}

#pragma mark - mode switching

- (void)applyMode:(WKAppearanceMode)mode {
    switch (mode) {
        case WKAppearanceModeSystem:
            [WKApp shared].config.darkModeWithSystem = YES;
            if (@available(iOS 13.0, *)) {
                if(UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    WKApp.shared.config.style = WKSystemStyleDark;
                } else {
                    WKApp.shared.config.style = WKSystemStyleLight;
                }
            }
            break;
        case WKAppearanceModeLight:
            [WKApp shared].config.darkModeWithSystem = NO;
            [WKApp shared].config.style = WKSystemStyleLight;
            break;
        case WKAppearanceModeDark:
            [WKApp shared].config.darkModeWithSystem = NO;
            [WKApp shared].config.style = WKSystemStyleDark;
            break;
    }
    [self syncSelection];
}

- (void)syncSelection {
    WKAppearanceMode current;
    if([WKApp shared].config.darkModeWithSystem) {
        current = WKAppearanceModeSystem;
    } else if([WKApp shared].config.style == WKSystemStyleDark) {
        current = WKAppearanceModeDark;
    } else {
        current = WKAppearanceModeLight;
    }
    for(WKAppearanceOptionView *opt in self.options) {
        opt.selected = (opt.mode == current);
    }
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    self.cardView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    [self syncSelection];
}

@end

#pragma mark - WKAppearanceOptionView

@interface WKAppearanceOptionView ()
@property(nonatomic,strong) UIImageView *preview;
@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,strong) UIView *radio;
@property(nonatomic,strong) UIImageView *checkmark;
@end

@implementation WKAppearanceOptionView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.preview = [[UIImageView alloc] init];
    self.preview.contentMode = UIViewContentModeScaleAspectFill;
    self.preview.layer.cornerRadius = 4.0f;
    self.preview.layer.masksToBounds = YES;
    [self addSubview:self.preview];

    self.titleLbl = [[UILabel alloc] init];
    self.titleLbl.font = [UIFont systemFontOfSize:12.0f];
    self.titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    self.titleLbl.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.titleLbl];

    self.radio = [[UIView alloc] init];
    self.radio.layer.cornerRadius = 9.0f;
    self.radio.layer.masksToBounds = YES;
    [self addSubview:self.radio];

    self.checkmark = [[UIImageView alloc] init];
    self.checkmark.contentMode = UIViewContentModeScaleAspectFit;
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"checkmark"];
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:10.0 weight:UIImageSymbolWeightBold];
        img = [img imageByApplyingSymbolConfiguration:cfg];
        img = [img imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        self.checkmark.image = img;
    }
    self.checkmark.hidden = YES;
    [self addSubview:self.checkmark];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapped)];
    [self addGestureRecognizer:tap];

    [self refreshAppearance];
}

- (void)applyTitle:(NSString*)title {
    self.titleLbl.text = title;
}

- (void)setMode:(WKAppearanceMode)mode {
    _mode = mode;
    [self refreshAppearance];
}

- (void)setSelected:(BOOL)selected {
    _selected = selected;
    [self refreshAppearance];
}

- (void)refreshAppearance {
    // 预览图来自工程内置素材
    NSString *imgName = nil;
    switch (self.mode) {
        case WKAppearanceModeSystem: imgName = @"Me/Index/AppearanceSystem"; break;
        case WKAppearanceModeLight:  imgName = @"Me/Index/AppearanceLight";  break;
        case WKAppearanceModeDark:   imgName = @"Me/Index/AppearanceDark";   break;
    }
    UIImage *img = [WKApp.shared loadImage:imgName moduleID:@"WuKongBase"];
    self.preview.image = img;

    if(self.isSelected) {
        self.radio.backgroundColor = [UIColor colorWithRed:0x1C/255.0 green:0x1C/255.0 blue:0x22/255.0 alpha:1.0];
        self.radio.layer.borderWidth = 0;
        self.checkmark.hidden = NO;
    } else {
        self.radio.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        self.radio.layer.borderWidth = 1.0f;
        self.radio.layer.borderColor = [UIColor colorWithRed:0xDD/255.0 green:0xDD/255.0 blue:0xDE/255.0 alpha:1.0].CGColor;
        self.checkmark.hidden = YES;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    self.preview.frame = CGRectMake(0, 0, w, 141.0f);
    self.titleLbl.frame = CGRectMake(0, 141.0f + 12.0f, w, 20.0f);
    self.radio.frame = CGRectMake((w - 18.0f)/2.0f, CGRectGetMaxY(self.titleLbl.frame) + 8.0f, 18.0f, 18.0f);
    self.checkmark.frame = CGRectMake(self.radio.frame.origin.x + 4.0f, self.radio.frame.origin.y + 5.0f, 10.0f, 8.0f);
}

- (void)onTapped {
    if(self.onTap) self.onTap(self.mode);
}

@end
