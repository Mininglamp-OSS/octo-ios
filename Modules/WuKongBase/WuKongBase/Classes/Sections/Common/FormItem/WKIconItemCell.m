//
//  WKIconItemCell.m
//  WuKongBase
//
//  Created by tt on 2020/1/22.
//

#import "WKIconItemCell.h"

@implementation WKIconItemModel

- (Class)cell {
    return WKIconItemCell.class;
}

@end

@interface WKIconItemCell ()


@end

@implementation WKIconItemCell


- (void)setupUI {
    [super setupUI];
    self.iconImgView = [[UIImageView alloc] init];
    [self.valueView addSubview:self.iconImgView];
}

- (void)refresh:(WKIconItemModel *)model {
    [super refresh:model];
    self.iconImgView.image = model.icon;
    self.iconImgView.lim_width = model.width?[model.width floatValue]:0.0f;
    self.iconImgView.lim_height = model.height?[model.height floatValue]:0.0f;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.iconImgView.lim_top = self.valueView.lim_height/2.0f - self.iconImgView.lim_height/2.0f;
    self.iconImgView.lim_left = self.valueView.lim_width - self.iconImgView.lim_width;
}

@end
