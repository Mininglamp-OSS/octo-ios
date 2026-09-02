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


// 宽度变化后重排自己。外部(旋转/分屏回调)只需要调这一个方法,不要靠"重新赋值同一个
// title/rightView"去触发 setter 副作用——那种写法会把 setter 永久锁死在"不能加幂等早退"
// 的状态上,而这是个全模块共用的类。定位公式统一放在下面三个 wk_position* 里,setter 和
// 这里共用同一份实现。
//
// 未覆盖: subtitleLabel。它在 setSubtitle: 里用 WKScreenWidth/2 居中(同一族的老毛病:
// 用屏幕宽而不是自己的宽,且只算一次),但本页面不用 subtitle,这个 PR 不扩范围,另开处理。
- (void)wk_relayoutForWidth:(CGFloat)width {
    if (width <= 0) return;
    CGRect frame = self.frame;
    if (frame.size.width != width) {
        frame.size.width = width;
        self.frame = frame;
    }
    [self wk_positionTitleLabel];
    [self wk_positionLeftView];
    [self wk_positionRightView];
}

- (void)setTitle:(NSString *)title {
    _title = title;
    self.titleLabel.text = title;
    [self wk_positionTitleLabel];
}

- (void)wk_positionTitleLabel {
    [self.titleLabel sizeToFit];

    if(self.titleLabel.lim_width>titleMaxWidth) {
        self.titleLabel.lim_width = titleMaxWidth;
    }
    if(self.largeTitle) {
        // largeTitle 左对齐，但若已显示返回按钮，需让位避免重叠
        self.titleLabel.lim_left = self.showBackButton ? 60.0f : 20.0f;
    }else {
        self.titleLabel.lim_left = self.lim_width/2.0f - self.titleLabel.lim_width/2.0f;
    }
    CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    self.titleLabel.lim_top = (self.lim_height - statusHeight)/2.0f - self.titleLabel.lim_height/2.0f + statusHeight;
}

- (void)setLeftView:(UIView *)leftView {
    // 传进来的就是当前这个 leftView 时只重定位,不摘下来重挂: removeFromSuperview +
    // addSubview 会把它挪到 nav bar 的最前面(z-order 变化,长标题会盖住右侧按钮),
    // 旋转期间每次重排都做一遍完全没必要。
    if (leftView && leftView == _leftView) {
        [self wk_positionLeftView];
        self.titleLabel.hidden = YES;
        return;
    }
    if (_leftView) {
        [_leftView removeFromSuperview];
        _leftView = nil;
    }
    if (leftView) {
        _leftView = leftView;
        [self wk_positionLeftView];
        [self addSubview:_leftView];
        self.titleLabel.hidden = YES;
    } else {
        self.titleLabel.hidden = NO;
    }
}

- (void)wk_positionLeftView {
    if (!_leftView) return;
    CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    if (_leftView.lim_height == 0) {
        _leftView.lim_height = self.lim_height - statusHeight;
    }
    _leftView.lim_left = 16.0f;
    _leftView.lim_top = (self.lim_height - statusHeight) / 2.0f - _leftView.lim_height / 2.0f + statusHeight;
}

- (void)setRightView:(UIView *)rightView {
    if(!rightView) {
        rightView = [[UIView alloc] init];
    }
    // 同 setLeftView:,同一个 view 只重定位不重挂。
    if(rightView == _rightView) {
        [self wk_positionRightView];
        return;
    }
    if(_rightView) {
        [_rightView removeFromSuperview];
        _rightView = nil;
    }
    if(rightView) {
        _rightView = rightView;
       // [_rightView setBackgroundColor:[UIColor clearColor]];
        [self wk_positionRightView];
        [self addSubview:_rightView];
    }
}

- (void)wk_positionRightView {
    if(!_rightView) return;

    CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    if(_rightView.lim_height==0) {
        _rightView.lim_height = self.lim_height - statusHeight;
    }

    if(_rightView.lim_width<=0) {
        _rightView.lim_width = _rightView.lim_height;
    }

    _rightView.lim_left = self.lim_width - _rightView.lim_width - 20.0f;

    _rightView.lim_top = (self.lim_height - statusHeight)/2.0f - _rightView.lim_height/2.0f + statusHeight;
}

- (void)setShowBackButton:(BOOL)showBackButton {
    _showBackButton = showBackButton;
    if(showBackButton) {
        [self addSubview:self.backButton];
        // largeTitle 模式下标题左对齐 x=20，与返回按钮(x=15,w=44)重叠，需让位
        if(self.largeTitle && self.titleLabel.lim_left < 60.0f) {
            self.titleLabel.lim_left = 60.0f;
        }
    }else {
        [self.backButton removeFromSuperview];
        if(self.largeTitle) {
            self.titleLabel.lim_left = 20.0f;
        }
    }

}

-(UIImage*) getImageWithName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
