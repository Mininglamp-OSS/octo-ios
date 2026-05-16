//
//  WKIconSwitchButton.m
//  WuKongBase
//
//  Created by tt on 2022/11/1.
//

#import "WKIconSwitchButton.h"
#import "WKApp.h"
#import "UIView+WK.h"
@interface WKIconSwitchButton ()

@property(nonatomic,assign) CGSize iconSize;
@property(nonatomic,strong) UIFont *titleFontInner;

@property(nonatomic,strong) UITapGestureRecognizer *tapGesture;

@end

@implementation WKIconSwitchButton


- (instancetype)initWithIconSize:(CGSize)size {
    self = [super init];
    if(self) {
        self.iconSize = size;
        
        self.userInteractionEnabled = YES;
        
        [self addSubview:self.onIconImgView];
        [self addSubview:self.offIconImgView];
        
        [self addSubview:self.onTitleLbl];
        [self addSubview:self.offTitleLbl];
        
        [self addGestureRecognizer:self.tapGesture];
        
        self.on = false;
        
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat titleLblTopSpace = 5.0f;
    CGFloat width = MAX( MAX(self.onTitleLbl.lim_width,self.offTitleLbl.lim_width), self.iconSize.width);
    CGFloat height = self.iconSize.height + titleLblTopSpace + self.onTitleLbl.lim_height;
    
    if(self.width>0) {
        width = self.width;
    }
    self.lim_size = CGSizeMake(width, height);
    
    self.onIconImgView.lim_centerX_parent = self;
    self.onTitleLbl.lim_top = self.onIconImgView.lim_bottom + titleLblTopSpace;
    self.onTitleLbl.lim_centerX_parent = self;
    
    self.offIconImgView.lim_centerX_parent = self;
    self.offTitleLbl.lim_top = self.offIconImgView.lim_bottom + titleLblTopSpace;
    self.offTitleLbl.lim_centerX_parent = self;
}

- (void)setOn:(BOOL)on {
    _on = on;
    
    self.onIconImgView.hidden = !on;
    self.onTitleLbl.hidden = !on;
    
    self.offIconImgView.hidden = on;
    self.offTitleLbl.hidden = on;
}

- (UIImageView *)onIconImgView {
    if(!_onIconImgView) {
        _onIconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.iconSize.width, self.iconSize.height)];
    }
    return _onIconImgView;
}

- (UIImageView *)offIconImgView {
    if(!_offIconImgView) {
        _offIconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.iconSize.width, self.iconSize.height)];
    }
    return _offIconImgView;
}

- (UILabel *)onTitleLbl {
    if(!_onTitleLbl) {
        _onTitleLbl = [[UILabel alloc] init];
        _onTitleLbl.font = [WKApp.shared.config appFontOfSize:15.0f];
        _onTitleLbl.textColor = [UIColor whiteColor];
    }
    return _onTitleLbl;
}

- (UILabel *)offTitleLbl {
    if(!_offTitleLbl) {
        _offTitleLbl = [[UILabel alloc] init];
        _offTitleLbl.font = [WKApp.shared.config appFontOfSize:15.0f];
        _offTitleLbl.textColor = [UIColor whiteColor];
    }
    return _offTitleLbl;
}

- (UIFont *)titleFont {
    if(!_titleFontInner) {
        _titleFontInner =  [WKApp.shared.config appFontOfSize:15.0f];
    }
    return _titleFontInner;
}

- (void)setTitleFont:(UIFont *)titleFont {
    _titleFontInner = titleFont;
    
    self.onTitleLbl.font = titleFont;
    self.offTitleLbl.font = titleFont;
}

- (UITapGestureRecognizer *)tapGesture {
    if(!_tapGesture) {
        _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapPressed)];
    }
    return _tapGesture;
}

-(void) tapPressed {
    self.on = !self.on;
    if(self.onSwitch) {
        self.onSwitch(self.on);
    }
}


@end
