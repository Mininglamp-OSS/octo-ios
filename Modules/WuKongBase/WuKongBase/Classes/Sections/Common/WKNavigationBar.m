//
//  WKNavigationBar.m
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import "WKNavigationBar.h"
#import "UIView+WK.h"
#import "WKApp.h"
#import "WKResource.h"
#import "WKNavigationManager.h"
#import "WKConstant.h"
#define titleMaxWidth self.lim_width - 60 - 60

@interface WKNavigationBar ()

@end

@implementation WKNavigationBar

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.titleLabel];
        [self addSubview:self.subtitleLabel];
    }
    return self;
}

- (UILabel *)titleLabel {
    if(!_titleLabel) {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [_titleLabel setTextColor:[WKApp shared].config.navBarTitleColor];
        
        CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        _titleLabel.lim_top = statusHeight + 10.0f;
        [_titleLabel setFont:[[WKApp shared].config appFontOfSizeMedium:17.0f]];
    }
    return _titleLabel;
}

- (UILabel *)subtitleLabel {
    if(!_subtitleLabel) {
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.hidden = YES;
        _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [_subtitleLabel setTextColor:[WKApp shared].config.navBarSubtitleColor];
        [_subtitleLabel setFont:[[WKApp shared].config appFontOfSize:10.0f]];
    }
    return _subtitleLabel;
}

- (void)setStyle:(WKNavigationBarStyle)style {
    _style = style;
    [self.titleLabel setTextColor:[WKApp shared].config.navBarTitleColor];
    UIImage *img;
    if(style == WKNavigationBarStyleWhite || style == WKNavigationBarStyleDark) {
        img = [[self getImageWithName:@"Common/Nav/BackWhite"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
       
    }else {
        img = [[self getImageWithName:@"Common/Nav/Back"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [self.backButton setImage:img forState:UIControlStateNormal];
}

- (void)setLargeTitle:(BOOL)largeTitle {
    _largeTitle = largeTitle;
    if(self.largeTitle) {
        [self.titleLabel setFont:[[WKApp shared].config appFontOfSizeMedium:25.0f]];
    }else{
        [self.titleLabel setFont:[[WKApp shared].config appFontOfSizeMedium:17.0f]];
    }
    
}

- (void)setSubtitle:(NSString *)subtitle {
    _subtitle = subtitle;
    if(subtitle && ![subtitle isEqualToString:@""]) {
        CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        _titleLabel.lim_top = statusHeight;
        self.subtitleLabel.hidden = NO;
        self.subtitleLabel.text = subtitle;
        [self.subtitleLabel sizeToFit];
        self.subtitleLabel.lim_top = self.titleLabel.lim_bottom;
        self.subtitleLabel.lim_left = WKScreenWidth/2.0f - self.subtitleLabel.lim_width/2.0f;
    }else {
         self.subtitleLabel.hidden = YES;
        CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        _titleLabel.lim_top = statusHeight + 10.0f;
    }
}

- (UIButton *)backButton {
    if(!_backButton) {
        CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        _backButton = [[UIButton alloc] initWithFrame:CGRectMake(15.0f, statusHeight, 44.0f, 44.0f)];
        UIImage *img = [self getImageWithName:@"Common/Nav/Back"];
        img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
         [_backButton setImage:img forState:UIControlStateNormal];
        
        [_backButton setImageEdgeInsets:UIEdgeInsetsMake(0, -20.0f, 0, 0)];
        [_backButton setBackgroundColor:[UIColor clearColor]];
        [_backButton setTintColor:WKApp.shared.config.navBarButtonColor];
        [_backButton addTarget:self action:@selector(backBtnPressed) forControlEvents:UIControlEventTouchUpInside];
        _backButton.lim_top = (self.lim_height - statusHeight)/2.0f - _backButton.lim_height/2.0f + statusHeight;
    }
    return _backButton;
}

-(void) backBtnPressed {
    if(self.onBack) {
        self.onBack();
    }else {
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    }
    
}


- (void)setTitle:(NSString *)title {
    _title = title;
    self.titleLabel.text = title;
    [self.titleLabel sizeToFit];
    
    if(self.titleLabel.lim_width>titleMaxWidth) {
        self.titleLabel.lim_width = titleMaxWidth;
    }
    if(self.largeTitle) {
        self.titleLabel.lim_left = 20.0f;
    }else {
        self.titleLabel.lim_left = self.lim_width/2.0f - self.titleLabel.lim_width/2.0f;
    }
    CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    self.titleLabel.lim_top = (self.lim_height - statusHeight)/2.0f - self.titleLabel.lim_height/2.0f + statusHeight;
    
    
}

- (void)setRightView:(UIView *)rightView {
    if(!rightView) {
        rightView = [[UIView alloc] init];
    }
    if(_rightView) {
        [_rightView removeFromSuperview];
        _rightView = nil;
    }
    if(rightView) {
        _rightView = rightView;
       // [_rightView setBackgroundColor:[UIColor clearColor]];
        
        CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        if(_rightView.lim_height==0) {
            _rightView.lim_height = self.lim_height - statusHeight;
        }
        
        if(_rightView.lim_width<=0) {
            _rightView.lim_width = _rightView.lim_height;
        }
        
        _rightView.lim_left = self.lim_width - _rightView.lim_width - 20.0f;
         
         _rightView.lim_top = (self.lim_height - statusHeight)/2.0f - _rightView.lim_height/2.0f + statusHeight;
        
       
        [self addSubview:_rightView];
    }
}

- (void)setShowBackButton:(BOOL)showBackButton {
    _showBackButton = showBackButton;
    if(showBackButton) {
        [self addSubview:self.backButton];
    }else {
        [self.backButton removeFromSuperview];
    }
    
}

-(UIImage*) getImageWithName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
