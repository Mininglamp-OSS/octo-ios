//
//  WKActionSheetItem2.m
//  WuKongBase
//
//  Created by tt on 2020/6/21.
//

#import "WKActionSheetItem2.h"
#import "WKConstant.h"
#import "WKApp.h"



#define ItemHeight 50.0f
@interface WKActionSheetItem2 ()

@property(nonatomic,strong) UIView *bottomLineView;

@end

@implementation WKActionSheetItem2


- (void)setShowBottomLine:(BOOL)showBottomLine {
    [self.bottomLineView removeFromSuperview];
    if(showBottomLine) {
        [self addSubview:self.bottomLineView];
        [self bringSubviewToFront:self.bottomLineView];
    }
}

- (UIView *)bottomLineView {
    if(!_bottomLineView) {
        _bottomLineView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.lim_height-0.5f, WKScreenWidth, 0.5f)];
        [_bottomLineView setBackgroundColor:[WKApp shared].config.backgroundColor];
    }
    return _bottomLineView;
}
@end

@interface WKActionSheetTipItem2 ()
@property(nonatomic,copy) NSString *tip;

@end

@implementation WKActionSheetTipItem2

+ (WKActionSheetTipItem2 *)initWithTip:(NSString *)tip {
    WKActionSheetTipItem2 *item = [WKActionSheetTipItem2 new];
    item.tip = tip;
    return item;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] initWithFrame:CGRectMake(30.0f, 20.0f, WKScreenWidth-40.0f, 0.0f)];
        [_tipLbl setFont:[[WKApp shared].config appFontOfSize:13.0f]];
        [_tipLbl setTextColor:[UIColor grayColor]];
        [_tipLbl setTextAlignment:NSTextAlignmentCenter];
        _tipLbl.numberOfLines = 0.0f;
        [self addSubview:_tipLbl];
    }
    return _tipLbl;
}

- (void)setTip:(NSString *)tip {
    _tip = tip;
    self.tipLbl.text = tip;
    [self.tipLbl sizeToFit];
    
    self.tipLbl.lim_left = WKScreenWidth/2.0f - self.tipLbl.lim_width/2.0f;
    self.lim_height = self.tipLbl.lim_height + 40.0f;
}


@end

@interface WKActionSheetButtonItem2 ()
@property(nonatomic,copy) NSString *title;
@property(nonatomic,strong) UIButton *btn;

@end
@implementation WKActionSheetButtonItem2

+ (WKActionSheetButtonItem2 *)initWithTitle:(NSString *)title onClick:(onItemClick)onItemClick{
    WKActionSheetButtonItem2 *item = [[WKActionSheetButtonItem2 alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, ItemHeight)];
    item.onItemClick = onItemClick;
    item.title = title;
    return item;
}

+ (WKActionSheetButtonItem2 *)initWithAlertTitle:(NSString *)alertTitle onClick:(onItemClick)onItemClick{
    WKActionSheetButtonItem2 *item = [[WKActionSheetButtonItem2 alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, ItemHeight)];
    item.onItemClick = onItemClick;
    item.title = alertTitle;
    [item.btn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    return item;
}

- (UIButton *)btn {
    if(!_btn) {
        _btn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, self.lim_height)];
        [_btn setTitleColor:[WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
        [[_btn titleLabel] setFont:[[WKApp shared].config appFontOfSize:16.0f]];
         [_btn addTarget:self action:@selector(btnPresssed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_btn];
    }
    return _btn;
}

- (void)setTitle:(NSString *)title {
    _title = title;
    
    [self.btn setTitle:title forState:UIControlStateNormal];
}
-(void) btnPresssed {
    if(self.onItemClick) {
        self.onItemClick();
    }
}

@end


@interface WKActionSheetButtonSubtitleItem2 ()
@property(nonatomic,copy) NSString *title;
@property(nonatomic,copy) NSString *subtitle;
@property(nonatomic,strong) UIView *box;
@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,strong) UILabel *subtitleLbl;

@end
@implementation WKActionSheetButtonSubtitleItem2

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.box];
    }
    return self;
}


+ (WKActionSheetButtonSubtitleItem2 *)initWithTitle:(NSString *)title subtitle:(NSString*)subtitle onClick:(onItemClick)onItemClick{
    WKActionSheetButtonSubtitleItem2 *item = [[WKActionSheetButtonSubtitleItem2 alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, ItemHeight)];
    item.onItemClick = onItemClick;
    item.title = title;
    item.subtitle = subtitle;
    return item;
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.lim_width, 16.0f)];
        _titleLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
        _titleLbl.textAlignment = NSTextAlignmentCenter;
    }
    return _titleLbl;
}

-(UILabel*) subtitleLbl {
    if(!_subtitleLbl) {
        _subtitleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 16.0f, self.lim_width, 14.0f)];
        _subtitleLbl.textColor = [WKApp shared].config.tipColor;
        _subtitleLbl.font = [[WKApp shared].config appFontOfSize:13.0f];
        _subtitleLbl.textAlignment = NSTextAlignmentCenter;
    }
    return _subtitleLbl;
}

- (UIView *)box {
    if(!_box) {
        _box = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.lim_width, self.lim_height)];
        [_box addSubview:self.titleLbl];
        _box.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pressed)];
        [_box addGestureRecognizer:tap];
        [_box addSubview:self.subtitleLbl];
    }
    return _box;
}

-(void) pressed {
    if(self.onItemClick) {
        self.onItemClick();
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.titleLbl.lim_width = self.lim_width;
    self.subtitleLbl.hidden = YES;
    if(!self.subtitle || [self.subtitle isEqualToString:@""]) {
        self.titleLbl.lim_top = 0.0f;
        self.titleLbl.lim_height = self.lim_height;
    }else{
        self.subtitleLbl.hidden = NO;
        self.titleLbl.lim_height = 20.0f;
        self.subtitleLbl.lim_top = self.titleLbl.lim_bottom+2.0f;
        
        self.titleLbl.lim_top = self.lim_height/2.0f - (self.titleLbl.lim_height + self.subtitleLbl.lim_height + 2.0f)/2.0f;
        
    }
}

- (void)setTitle:(NSString *)title {
    _title = title;
    self.titleLbl.text = title;
}

-(void) setSubtitle:(NSString *)subtitle {
    _subtitle = subtitle;
    self.subtitleLbl.text = subtitle;
}
-(void) btnPresssed {
    if(self.onItemClick) {
        self.onItemClick();
    }
}

@end

#define LineWidth  10.0f
@interface WKActionSheetCancelItem2 ()
@property(nonatomic,copy) NSString *title;
@property(nonatomic,strong) UIButton *btn;
@property(nonatomic,strong) UIView *bigLineView;
@property(nonatomic,strong) onItemClick onItemClick;
@end
@implementation WKActionSheetCancelItem2

+ (WKActionSheetCancelItem2 *)initWithTitle:(NSString *)title onClick:(onItemClick)onItemClick {
    WKActionSheetCancelItem2 *item = [[WKActionSheetCancelItem2 alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, ItemHeight+LineWidth)];
    item.onItemClick = onItemClick;
    [item addSubview:item.bigLineView];
    item.title = title;
    return item;
}

- (UIView *)bigLineView {
    if(!_bigLineView) {
        _bigLineView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth,LineWidth)];
        [_bigLineView setBackgroundColor:[WKApp shared].config.backgroundColor];
    }
    return _bigLineView;
}

- (void)setTitle:(NSString *)title {
    _title = title;
    
    [self.btn setTitle:title forState:UIControlStateNormal];
}

- (UIButton *)btn {
    if(!_btn) {
        _btn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, self.bigLineView.lim_bottom, WKScreenWidth, ItemHeight)];
        [_btn setTitleColor:[WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
        [[_btn titleLabel] setFont:[[WKApp shared].config appFontOfSize:16.0f]];
        [_btn addTarget:self action:@selector(btnPresssed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_btn];
    }
    return _btn;
}

-(void) btnPresssed {
    if(self.onItemClick) {
        self.onItemClick();
    }
}

@end
