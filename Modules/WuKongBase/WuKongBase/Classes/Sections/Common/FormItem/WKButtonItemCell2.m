//
//  WKButtonItemCell2.m
//  WuKongBase
//
//  Created by tt on 2020/8/17.
//

#import "WKButtonItemCell2.h"
#import "WKApp.h"

@implementation WKButtonItemModel2

- (Class)cell {
    return WKButtonItemCell2.class;
}

- (NSNumber *)showArrow {
    return @(false);
}
@end

@interface WKButtonItemCell2 ()

@property(nonatomic,strong) UIButton *btn;

@property(nonatomic,strong) WKButtonItemModel2 *model;

@end
@implementation WKButtonItemCell2

+ (CGSize)sizeForModel:(WKButtonItemModel2 *)model {
    return CGSizeMake(model.width>0?model.width:WKScreenWidth, model.height>0?model.height:44.0f);
}

- (void)setupUI {
    [super setupUI];
    [self setBackgroundColor:[UIColor clearColor]];
    [self.contentView addSubview:self.btn];
}

- (UIButton *)btn {
    if(!_btn) {
        _btn = [[UIButton alloc] init];
        [_btn setBackgroundColor:[WKApp shared].config.themeColor];
        _btn.layer.masksToBounds = YES;
        _btn.layer.cornerRadius = 4.0f;
    }
    return _btn;
}

- (void)refresh:(WKButtonItemModel2*)cellModel {
    [super refresh:cellModel];
    self.model = cellModel;
    [self.btn setTitle:cellModel.title?:@"" forState:UIControlStateNormal];
    
    [self.btn removeTarget:self action:@selector(btnPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.btn addTarget:self action:@selector(btnPressed) forControlEvents:UIControlEventTouchUpInside];
}

-(void) btnPressed {
    if(self.model.onPressed) {
        self.model.onPressed();
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.btn.lim_height = self.lim_height;
    if(self.model.width>0) {
        self.btn.lim_width  = self.model.width;
    }else {
        self.btn.lim_width  = self.lim_width - 30.0f;
    }
    
    self.btn.lim_left = self.lim_width/2.0f - self.btn.lim_width/2.0f;
}
@end
