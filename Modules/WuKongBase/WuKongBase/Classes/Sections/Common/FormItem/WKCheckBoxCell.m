//
//  WKCheckBoxCell.m
//  WuKongBase
//
//  Created by tt on 2023/9/28.
//

#import "WKCheckBoxCell.h"
#import "WKCheckBox.h"
#import "WKApp.h"
@implementation WKCheckBoxModel

- (Class)cell {
    return WKCheckBoxCell.class;
}

@end

@interface WKCheckBoxCell ()<WKCheckBoxDelegate>

@property(nonatomic,strong) WKCheckBox *checkbox;

@property(nonatomic,strong) WKCheckBoxModel *model;
 
@end

@implementation WKCheckBoxCell

- (void)setupUI {
    [super setupUI];
    [self.valueView addSubview:self.checkbox];
    
    self.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(checkboxPressed)];
    [self addGestureRecognizer:tap];
}

- (void)refresh:(WKCheckBoxModel *)model {
    [super refresh:model];
    self.model = model;
    
    self.checkbox.on = model.on;
    
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.checkbox.lim_left = self.valueView.lim_width - self.checkbox.lim_width;
    self.checkbox.lim_centerY_parent = self.valueView;
}

- (WKCheckBox *)checkbox {
    if(!_checkbox) {
        _checkbox = [[WKCheckBox alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 24.0f, 24.0f)];
        _checkbox.onFillColor = [WKApp shared].config.themeColor;
        _checkbox.onCheckColor = [UIColor whiteColor];
        _checkbox.onAnimationType = BEMAnimationTypeBounce;
        _checkbox.offAnimationType = BEMAnimationTypeBounce;
        _checkbox.animationDuration = 0.0f;
        _checkbox.lineWidth = 1.0f;
        _checkbox.tintColor = [UIColor grayColor];
        _checkbox.onTintColor =[WKApp shared].config.themeColor;
        _checkbox.delegate = self;
    }
    return _checkbox;
}

-(void) checkboxPressed {
    [self.checkbox setOn:!self.checkbox.on animated:YES];
    if(self.model.onCheck) {
        self.model.onCheck(self.checkbox.on);
    }
    
}

- (void)didTapCheckBox:(WKCheckBox*)checkBox {
    if(self.model.onCheck) {
        self.model.onCheck(checkBox.on);
    }
}

@end
