//
//  WKConversationListSelectCell.m
//  WuKongBase
//
//  Created by tt on 2020/9/28.
//

#import "WKConversationListSelectCell.h"

@implementation WKConversationListSelectModel

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

- (NSNumber *)showArrow {
    return @(false);
}
-(Class) cell {
    return WKConversationListSelectCell.class;
}

@end

@interface WKConversationListSelectCell ()<WKCheckBoxDelegate>

@property(nonatomic,strong) UIImageView *iconImageView; // 头像
@property(nonatomic,strong) UILabel *titleLbl; // 标题

@property(nonatomic,strong) UILabel *valueLbl;
@property(nonatomic,strong) WKCheckBox *checkBox;
@property(nonatomic,strong) WKConversationListSelectModel *model;

@end

@implementation WKConversationListSelectCell


+(CGSize) sizeForModel:(WKConversationListSelectModel*)model{
    return  CGSizeMake(WKScreenWidth, model.height.floatValue + 20.0f);
}
- (void)setupUI {
    [super setupUI];
//    self.bottomLineView.hidden =  NO;
    
    // checkbox
    [self.contentView addSubview:self.checkBox];
    
    
    self.iconImageView = [[UIImageView alloc] init];
    self.iconImageView.layer.masksToBounds = YES;
    self.iconImageView.layer.cornerRadius = 5.0f;
    [self.contentView addSubview:self.iconImageView];
    
    self.titleLbl = [[UILabel alloc] init];
    [self.titleLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
    [self.titleLbl setTextColor:[WKApp shared].config.defaultTextColor];
    [self.contentView addSubview:self.titleLbl];
    
    [self.contentView addSubview:self.valueLbl];
}

- (void)refresh:(WKConversationListSelectModel*)cellModel {
    [super refresh:cellModel];
    self.model = cellModel;
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
    [self.checkBox setOn:cellModel.selected];
    self.checkBox.hidden = YES;
    if(cellModel.multiple) {
        self.checkBox.hidden = NO;
    }
    
    self.valueLbl.text = cellModel.value;
    
    
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if(self.model.multiple) {
        // checkbox
        self.checkBox.lim_left = 15.0f;
        self.checkBox.lim_top = self.lim_height/2.0f - self.checkBox.lim_height/2.0f;
    }else {
        self.checkBox.lim_left  = -self.checkBox.lim_width;
    }
   
    
    // icon
    CGFloat iconLeft = 15.0f;
    self.iconImageView.lim_top = self.lim_height/2.0f - self.iconImageView.lim_height/2.0f;
    self.iconImageView.lim_left = self.checkBox.lim_right + iconLeft;
    
    [self.valueLbl sizeToFit];
    
    // title
    CGFloat titleLeft = 10.0f;
    CGFloat titleRight = 10.0f;
    self.titleLbl.lim_left = self.iconImageView.lim_right + titleLeft;
    self.titleLbl.lim_width = self.lim_width - self.titleLbl.lim_left - titleRight - self.valueLbl.lim_width - 15.0f;
    self.titleLbl.lim_height = self.lim_height;
    
//    self.bottomLineView.lim_left = iconLeft + self.iconImageView.lim_width + titleLeft;
//    self.bottomLineView.lim_width = self.lim_width -self.bottomLineView.lim_left;
    
    // value
    self.valueLbl.lim_left = self.lim_width - self.valueLbl.lim_width - 15.0f;
    self.valueLbl.lim_centerY_parent = self;
    
}


- (UILabel *)valueLbl {
    if(!_valueLbl) {
        _valueLbl = [[UILabel alloc] init];
        _valueLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
        _valueLbl.textColor = [WKApp shared].config.tipColor;
    }
    return _valueLbl;
}
- (WKCheckBox *)checkBox {
    if(!_checkBox) {
        _checkBox = [[WKCheckBox alloc] initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
        _checkBox.onFillColor = [WKApp shared].config.themeColor;
        _checkBox.onCheckColor = [UIColor whiteColor];
        _checkBox.onAnimationType = BEMAnimationTypeBounce;
        _checkBox.offAnimationType = BEMAnimationTypeBounce;
        _checkBox.animationDuration = 0.0f;
        _checkBox.lineWidth = 1.0f;
    //    self.checkBox.tintColor = [UIColor grayColor];
        _checkBox.delegate = self;
    }
    return _checkBox;
}


@end
