//
//  WKUserAuthVC.m
//  WuKongBase
//
//  Created by tt on 2023/9/12.
//

#import "WKUserAuthView.h"

#define defaultActionSheetHeight 350.0f

@interface WKUserAuthUserUserView : UIView

@property(nonatomic,strong) UIView *firstLine;

@property(nonatomic,strong) UIView *secondLine;

@property(nonatomic,strong) WKUserAvatar *avatarImgView;

@property(nonatomic,strong) UILabel *nameLbl;

@property(nonatomic,strong) UILabel *tipLbl;

@end

@interface WKUserAuthContentView : UIView

@property(nonatomic,strong) UIImageView *logoImgView;

@property(nonatomic,strong) UILabel *titleLbl;

@property(nonatomic,strong) UILabel *tipLbl;

@property(nonatomic,strong) WKUserAuthUserUserView *userView;

@property(nonatomic,strong) UIButton *cancelBtn;

@property(nonatomic,strong) UIButton *okBtn;


@end


@interface WKUserAuthView ()

@property(nonatomic,strong) UIView *maskView;

@property(nonatomic,strong) UIView *actionSheetBoxView;

@property(nonatomic,strong) WKUserAuthContentView *actionSheetContentView;

@end

@implementation WKUserAuthView

- (instancetype)init
{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, WKScreenHeight)];
    if (self) {
        [self setupUI];
    }
    return self;
}

-(void) setupUI {
    [self addSubview:self.maskView];
    [self addSubview:self.actionSheetBoxView];
    
    [self.actionSheetBoxView addSubview:self.actionSheetContentView];
    
    
}

- (void)setAppName:(NSString *)appName {
    self.actionSheetContentView.titleLbl.text = [NSString stringWithFormat:@"%@ %@",appName,@"申请"];
    [self.actionSheetContentView.titleLbl sizeToFit];
}

- (void)setAppLogo:(NSString *)appLogo {
    [self.actionSheetContentView.logoImgView lim_setImageWithURL:[NSURL URLWithString:appLogo] placeholderImage:WKApp.shared.config.defaultPlaceholder];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    
    CGFloat offset = 20.0f;
    
    self.actionSheetContentView.lim_top = -offset;
    
    if(self.show) {
        self.actionSheetBoxView.lim_top =  WKScreenHeight - self.actionSheetBoxView.lim_height;
    }else {
        self.actionSheetBoxView.lim_top = WKScreenHeight;
    }
    [self.actionSheetContentView layoutSubviews];
}

- (UIView *)maskView {
    if(!_maskView) {
        _maskView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, WKScreenHeight)];
        _maskView.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.5f];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(maskViewPressed)];
        _maskView.userInteractionEnabled = YES;
        [_maskView  addGestureRecognizer:tap];
    }
    return _maskView;
}

-(void) maskViewPressed {
    if(self.onClose) {
        self.onClose();
    }
}

- (UIView *)actionSheetBoxView {
    if(!_actionSheetBoxView) {
        _actionSheetBoxView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, defaultActionSheetHeight)];
        _actionSheetBoxView.backgroundColor = WKApp.shared.config.cellBackgroundColor;
        _actionSheetBoxView.lim_top = WKScreenHeight;
    }
    return _actionSheetBoxView;
}

- (WKUserAuthContentView *)actionSheetContentView {
    if(!_actionSheetContentView) {
        _actionSheetContentView = [[WKUserAuthContentView alloc] init];
        _actionSheetContentView.backgroundColor = WKApp.shared.config.cellBackgroundColor;
        _actionSheetContentView.layer.masksToBounds = YES;
        _actionSheetContentView.layer.cornerRadius = 10.0f;
        
        [_actionSheetContentView.cancelBtn addTarget:self action:@selector(cancelBtnPressed) forControlEvents:UIControlEventTouchUpInside];
        [_actionSheetContentView.okBtn addTarget:self action:@selector(okBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _actionSheetContentView;
}

-(void) cancelBtnPressed {
    if(self.onClose) {
        self.onClose();
    }
}

-(void) okBtnPressed {
    if(self.onAllow) {
        self.onAllow();
    }
}

@end


@implementation WKUserAuthContentView

- (instancetype)init
{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, defaultActionSheetHeight)];
    if (self) {
        [self setupUI];
    }
    return self;
}

-(void) setupUI {
    [self addSubview:self.logoImgView];
    [self addSubview:self.titleLbl];
    [self addSubview:self.tipLbl];
    [self addSubview:self.userView];
    
    [self addSubview:self.okBtn];
    [self addSubview:self.cancelBtn];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat topSpace = 30.0f;
    CGFloat leftSpace = 15.0f;
    
    // logo
    self.logoImgView.lim_top = topSpace + 2.0f;
    self.logoImgView.lim_left = leftSpace;
    
    // title
    self.titleLbl.lim_top = topSpace;
    self.titleLbl.lim_left = self.logoImgView.lim_right + 10.0f;
    
    // tip
    self.tipLbl.lim_left = self.logoImgView.lim_left;
    self.tipLbl.lim_top = self.titleLbl.lim_bottom + 30.0f;
    
    // user
    self.userView.lim_top = self.tipLbl.lim_bottom + 20.0f;
    self.userView.lim_left = 0.0f;
    
    // button
    
    CGFloat btnBtwSpace = 20.0f;
    
    CGFloat contentWidth = self.cancelBtn.lim_width + btnBtwSpace + self.okBtn.lim_width;
    
    self.cancelBtn.lim_left = (self.lim_width - contentWidth)/2.0f;
    self.cancelBtn.lim_top = self.userView.lim_bottom + 40.0f;
    
    self.okBtn.lim_top = self.cancelBtn.lim_top;
    self.okBtn.lim_left = self.cancelBtn.lim_right + btnBtwSpace;
}

- (UIImageView *)logoImgView {
    if(!_logoImgView) {
        _logoImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 20.0f, 20.0f)];
        _logoImgView.backgroundColor = [UIColor greenColor];
        _logoImgView.layer.cornerRadius = _logoImgView.lim_height/4.0f;
    }
    return _logoImgView;
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.textColor = WKApp.shared.config.defaultTextColor;
        _titleLbl.font = [WKApp.shared.config appFontOfSize:15.0f];
        _titleLbl.text = @"某某公司 申请";
        [_titleLbl sizeToFit];
    }
    return _titleLbl;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] init];
        _tipLbl.font = [WKApp.shared.config appFontOfSizeMedium:18.0f];
        _tipLbl.text = LLang(@"获取你的昵称、头像");
        [_tipLbl sizeToFit];
    }
    return _tipLbl;
}

- (WKUserAuthUserUserView *)userView {
    if(!_userView) {
        _userView = [[WKUserAuthUserUserView alloc] init];
    }
    return _userView;
}

- (UIButton *)cancelBtn {
    if(!_cancelBtn) {
        _cancelBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 120.0f, 44.0f)];
        [_cancelBtn setTitle:LLang(@"取消") forState:UIControlStateNormal];
        [_cancelBtn setTitleColor:WKApp.shared.config.themeColor forState:UIControlStateNormal];
        _cancelBtn.backgroundColor = [UIColor colorWithRed:240.0f/255.0f green:240.0f/255.0f blue:240.0f/255.0f alpha:1.0f];
        _cancelBtn.layer.masksToBounds = YES;
        _cancelBtn.layer.cornerRadius = 4.0f;
    }
    return _cancelBtn;
}

- (UIButton *)okBtn {
    if(!_okBtn) {
        _okBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 120.0f, 44.0f)];
        [_okBtn setTitle:LLang(@"允许") forState:UIControlStateNormal];
        [_okBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _okBtn.backgroundColor = WKApp.shared.config.themeColor;
        _okBtn.layer.masksToBounds = YES;
        _okBtn.layer.cornerRadius = 4.0f;
    }
    return _okBtn;
}

@end



@implementation WKUserAuthUserUserView

- (instancetype)init
{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 80.0f)];
    if (self) {
        [self addSubview:self.firstLine];
        [self addSubview:self.avatarImgView];
        [self addSubview:self.nameLbl];
        [self addSubview:self.tipLbl];
        [self addSubview:self.secondLine];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.firstLine.lim_top = 0.0f;
    
    self.avatarImgView.lim_top = self.firstLine.lim_bottom + 10.0f;
    self.avatarImgView.lim_left = self.firstLine.lim_left;
    
    self.nameLbl.lim_left = self.avatarImgView.lim_right + 10.0f;
    self.nameLbl.lim_top = self.avatarImgView.lim_top;
    
    self.tipLbl.lim_top = self.nameLbl.lim_bottom + 10.0f;
    self.tipLbl.lim_left = self.nameLbl.lim_left;
    
    self.secondLine.lim_top = self.avatarImgView.lim_bottom + 10.0f;
    
}

- (UIView *)firstLine {
    if(!_firstLine) {
        _firstLine = [[UIView alloc] initWithFrame:CGRectMake(15.0f, 0.0f, self.lim_width - 30.0f, 1.0f)];
        _firstLine.backgroundColor = WKApp.shared.config.lineColor;
    }
    return _firstLine;
}

- (UIView *)secondLine {
    if(!_secondLine) {
        _secondLine = [[UIView alloc] initWithFrame:CGRectMake(15.0f, 0.0f, self.lim_width - 30.0f, 1.0f)];
        _secondLine.backgroundColor = WKApp.shared.config.lineColor;
    }
    return _secondLine;
}

- (WKUserAvatar *)avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[WKUserAvatar alloc] init];
        _avatarImgView.url = [WKAvatarUtil getAvatar:WKApp.shared.loginInfo.uid];
    }
    return _avatarImgView;
}

- (UILabel *)nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
        _nameLbl.text = WKApp.shared.loginInfo.extra[@"name"]?:@"";
        _nameLbl.font = [WKApp.shared.config appFontOfSize:16.0f];
        [_nameLbl sizeToFit];
    }
    return _nameLbl;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] init];
        NSString *text = [NSString stringWithFormat:@"%@昵称头像",WKApp.shared.config.appName];
        _tipLbl.text = LLang(text);
        _tipLbl.textColor = WKApp.shared.config.tipColor;
        _tipLbl.font = [WKApp.shared.config appFontOfSize:15.0f];
        [_tipLbl sizeToFit];
       
    }
    return _tipLbl;
}


@end
