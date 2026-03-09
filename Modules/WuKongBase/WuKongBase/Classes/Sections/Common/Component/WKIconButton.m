//
//  WKIconButton.m
//  WuKongBase
//
//  Created by tt on 2022/11/1.
//

#import "WKIconButton.h"
#import "UIView+WK.h"
#import "WKApp.h"
@interface WKIconButton ()

@property(nonatomic,strong) UITapGestureRecognizer *tapGesture;

@end

@implementation WKIconButton

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.userInteractionEnabled = YES;
        [self addGestureRecognizer:self.tapGesture];
        [self addSubview:self.imageView];
        [self addSubview:self.titleLbl];
        
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat titleLblTopSpace = 5.0f;
    CGFloat width = MAX(self.titleLbl.lim_width, self.imageView.lim_width);
    CGFloat height = self.imageView.lim_height + titleLblTopSpace + self.titleLbl.lim_height;
    if(self.width>0) {
        width = self.width;
    }
    self.lim_size = CGSizeMake(width, height);
    
    self.imageView.lim_centerX_parent = self;
    self.titleLbl.lim_top = self.imageView.lim_bottom + titleLblTopSpace;
    self.titleLbl.lim_centerX_parent = self;
    
    
}

- (UIImageView *)imageView {
    if(!_imageView) {
        _imageView = [[UIImageView alloc] init];
    }
    return _imageView;
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.font = [WKApp.shared.config appFontOfSize:15.0f];
        _titleLbl.textColor = [UIColor whiteColor];
    }
    return _titleLbl;
}

- (UITapGestureRecognizer *)tapGesture {
    if(!_tapGesture) {
        _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapPress)];
    }
    return _tapGesture;
}

-(void) tapPress {
    if(self.onClick) {
        self.onClick();
    }
}
@end
