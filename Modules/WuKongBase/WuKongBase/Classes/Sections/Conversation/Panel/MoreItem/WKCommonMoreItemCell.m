//
//  WKCommonMoreItemCell.m
//  WuKongBase
//
//  Created by tt on 2020/1/12.
//

#import "WKCommonMoreItemCell.h"
#import "UIView+WK.h"
@interface WKCommonMoreItemCell ()

@property(nonatomic,strong) UIImageView *iconImgView;
@property(nonatomic,strong) UILabel *titleLbl;

@end

@implementation WKCommonMoreItemCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.iconImgView = [[UIImageView alloc] init];
        [self addSubview:self.iconImgView];
        
        self.titleLbl = [[UILabel alloc] init];
        [self.titleLbl setFont:[UIFont systemFontOfSize:14.0f]];
        [self.titleLbl setTextColor:[UIColor grayColor]];
        [self addSubview:self.titleLbl];
    }
    return self;
}

- (void)refresh:(WKMoreItemModel *)model {
    [super refresh:model];
    self.iconImgView.image = model.image;
    
    self.titleLbl.text = model.title;
    [self.titleLbl sizeToFit];
}

- (void)layoutSubviews {
    [super layoutSubviews];
//    CGFloat iconMarginSpace = 15.0f;
    self.iconImgView.lim_size = CGSizeMake(40.0f, 40.0f);
    self.iconImgView.lim_left = self.lim_size.width/2.0f - self.iconImgView.lim_size.width/2.0f;
    
    self.titleLbl.lim_top = self.iconImgView.lim_bottom + 5.0f;
    self.titleLbl.lim_left = self.lim_size.width/2.0f - self.titleLbl.lim_size.width/2.0f;
}

@end
