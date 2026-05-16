//
//  WKFuncGroupEditItemCell.m
//  WuKongBase
//
//  Created by tt on 2022/5/5.
//

#import "WKFuncGroupEditItemCell.h"


@interface WKFuncGroupEditItemCell ()

@property(nonatomic,strong) UIImageView *iconImgView;
@property(nonatomic,strong) UILabel *nameLbl;



@end

@implementation WKFuncGroupEditItemCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self =  [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if(self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self.contentView addSubview:self.iconImgView];
        [self.contentView addSubview:self.nameLbl];
        [self.contentView addSubview:self.enableSwitch];
    }
    return self;
}

-(void) refresh:(WKFuncGroupEditItemModel *) model {
    self.iconImgView.image = model.itemIcon;
    self.nameLbl.text = model.title;
    [self.nameLbl sizeToFit];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.iconImgView.lim_left = 10.0f;
    self.iconImgView.lim_centerY_parent = self.contentView;
    
    self.nameLbl.lim_left = self.iconImgView.lim_right + 10.0f;
    self.nameLbl.lim_centerY_parent = self.contentView;
    
    self.enableSwitch.lim_centerY_parent = self.contentView;
    self.enableSwitch.lim_left = self.contentView.lim_width - self.enableSwitch.lim_width - 10.0f;
}


- (UIImageView *)iconImgView {
    if(!_iconImgView) {
        _iconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 30.0f, 22.5f)];
    }
    return _iconImgView;
}

- (UILabel *)nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
        _nameLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
    }
    return _nameLbl;
}

- (UISwitch *)enableSwitch {
    if(!_enableSwitch) {
        _enableSwitch = [[UISwitch alloc] init];
        [_enableSwitch addTarget:self action:@selector(enable:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _enableSwitch;
}

-(void) enable:(UISwitch*)sw {
    if(self.onSwitch) {
        self.onSwitch(sw.on);
    }
}


@end
