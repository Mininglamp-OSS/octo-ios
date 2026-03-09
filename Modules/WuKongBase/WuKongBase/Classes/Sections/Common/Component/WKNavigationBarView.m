//
//  WKNavigationBarView.m
//  WuKongBase
//
//  Created by tt on 2020/6/8.
//

#import "WKNavigationBarView.h"
#import "UIView+WK.h"
@interface WKNavigationBarView ()

@property(nonatomic,strong) UILabel *titleLbl;

@end

@implementation WKNavigationBarView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.frame = CGRectMake(0, 0,  [UIScreen mainScreen].bounds.size.width, 88.0f);
    }
    return self;
}

-(void) setupUI {
    [self setBackgroundColor:[UIColor redColor]];
    [self addSubview:self.titleLbl];
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(15.0f, 0.0f, 120.0f, 35.0f)];
        [_titleLbl setFont:[UIFont fontWithName:@"PingFangSC-Semibold" size:27]];
        [_titleLbl setTextColor:[UIColor blackColor]];
    }
    return _titleLbl;
}

- (void)setTitle:(NSString *)title {
    _title = title;
    _titleLbl.text = title;
    [_titleLbl sizeToFit];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.titleLbl.lim_top = self.lim_height/2.0f - self.titleLbl.lim_height/2.0f;
}

@end
