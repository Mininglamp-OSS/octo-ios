//
//  WKIconTitleItemCell.m
//  WuKongBase
//
//  Created by tt on 2020/2/2.
//

#import "WKIconTitleItemCell.h"
#import <SDWebImage/UIImageView+WebCache.h>
@implementation WKIconTitleItemModel

- (NSNumber *)width {
    if(!_width) {
        _width = @(44.0f);
    }
    return _width;
}

- (NSNumber *)height {
    if(!_height) {
        _height = @(44.0f);
    }
    return _height;
}
-(Class) cell {
    return WKIconTitleItemCell.class;
}

@end

@interface WKIconTitleItemCell ()

@end

@implementation WKIconTitleItemCell

+(CGSize) sizeForModel:(WKIconTitleItemModel*)model{
    return  CGSizeMake(WKScreenWidth, model.height.floatValue + 20.0f);
}
- (void)setupUI {
    [super setupUI];
//    self.bottomLineView.hidden =  NO;
    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.layer.masksToBounds = YES;
    self.iconImageView.layer.cornerRadius = 5.0f;
    [self addSubview:self.iconImageView];
    
    self.titleLbl = [[UILabel alloc] init];
    [self.titleLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
    [self.titleLbl setTextColor:[UIColor colorWithRed:49.0f/255.0f green:49.0f/255.0f blue:49.0f/255.0f alpha:1.0f]];
    [self addSubview:self.titleLbl];
}

- (void)refresh:(WKIconTitleItemModel*)cellModel {
    [super refresh:cellModel];
    self.titleLbl.text = cellModel.title;
    if(cellModel.icon) {
        self.iconImageView.image = cellModel.icon;
    }else {
        [self.iconImageView lim_setImageWithURL:[NSURL URLWithString:cellModel.iconURL]];
    }
    
    self.iconImageView.lim_size = CGSizeMake(cellModel.width.floatValue, cellModel.height.floatValue);
    
    if(cellModel.circular) {
        self.iconImageView.layer.cornerRadius = self.iconImageView.lim_height/2.0f;
    }else {
        self.iconImageView.layer.cornerRadius = 5.0f;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat iconLeft = 20.0f;
    self.iconImageView.lim_top = self.lim_height/2.0f - self.iconImageView.lim_height/2.0f;
    self.iconImageView.lim_left = iconLeft;
    
    CGFloat titleLeft = 10.0f;
    CGFloat titleRight = 10.0f;
    self.titleLbl.lim_left = self.iconImageView.lim_right + titleLeft;
    self.titleLbl.lim_width = self.lim_width - self.titleLbl.lim_left - titleRight;
    self.titleLbl.lim_height = self.lim_height;
    
//    self.bottomLineView.lim_left = iconLeft + self.iconImageView.lim_width + titleLeft;
//    self.bottomLineView.lim_width = self.lim_width -self.bottomLineView.lim_left;
    
    
}


@end
