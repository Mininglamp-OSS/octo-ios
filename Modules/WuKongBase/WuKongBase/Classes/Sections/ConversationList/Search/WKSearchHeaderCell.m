//
//  WKSearchHeaderCell.m
//  WuKongBase
//
//  Created by tt on 2020/4/25.
//

#import "WKSearchHeaderCell.h"

@implementation WKSearchHeaderModel
- (Class)cell {
    return WKSearchHeaderCell.class;
}

@end

@interface WKSearchHeaderCell ()

@property(nonatomic,strong) UILabel *titleLbl;

@end

@implementation WKSearchHeaderCell

+(CGSize) sizeForModel:(WKFormItemModel*)model{
    return CGSizeMake(WKScreenWidth, 40.0f);
}

- (void)setupUI {
    [super setupUI];
    
    self.titleLbl = [[UILabel alloc] init];
    [self.titleLbl setFont:[UIFont systemFontOfSize:15.0f]];
    [self.titleLbl setTextColor:[UIColor grayColor]];
    [self addSubview:self.titleLbl];
    
}

- (void)refresh:(WKSearchHeaderModel *)model {
    [super refresh:model];
    self.titleLbl.text = model.title;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self.titleLbl sizeToFit];
    
    self.titleLbl.lim_left = 20.0f;
    self.titleLbl.lim_top = [self lim_centerY:self.titleLbl];
    
}
@end
