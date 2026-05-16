//
//  WKBlacklistCell.m
//  WuKongBase
//
//  Created by tt on 2020/6/26.
//

#import "WKBlacklistCell.h"

@implementation WKBlacklistModel


@end

@interface WKBlacklistCell ()
@property(nonatomic,strong) UILabel *nameLbl;
@end

@implementation WKBlacklistCell

- (void)setupUI {
    [super setupUI];
    [self addSubview:self.nameLbl];
}

- (void)refresh:(WKBlacklistModel*)cellModel {
    [super refresh:cellModel];
    self.nameLbl.text = cellModel.name;
    [self.nameLbl sizeToFit];
    
}

- (UILabel *)nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
    }
    return _nameLbl;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.nameLbl.lim_left = 15.0f;
    self.nameLbl.lim_top = self.lim_height/2.0f - self.nameLbl.lim_height/2.0f;
}

+ (NSString *)cellId {
    return @"WKBlacklistCell";
}

@end
