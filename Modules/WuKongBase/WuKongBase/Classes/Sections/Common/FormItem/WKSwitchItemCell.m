//
//  WKSwitchItemCell.m
//  WuKongBase
//
//  Created by tt on 2020/1/22.
//

#import "WKSwitchItemCell.h"

@implementation WKSwitchItemModel

- (Class)cell {
    return WKSwitchItemCell.class;
}

@end

@interface WKSwitchItemCell ()

@property(nonatomic,strong) UISwitch *switchView;

@property(nonatomic,strong) WKSwitchItemModel *model;

@end
@implementation WKSwitchItemCell

- (void)setupUI {
    [super setupUI];
    self.valueView.hidden = YES;
    self.switchView = [[UISwitch alloc] init];
    [self.switchView setOnTintColor:[WKApp shared].config.themeColor];
    [self.switchView addTarget:self action:@selector(onSwitch) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.switchView];
    
}

- (void)refresh:(WKSwitchItemModel *)model {
    [super refresh:model];
    self.model = model;
    [self.switchView setOn:model.on?[model.on boolValue]:false animated:NO];
    [self.switchView setEnabled:!model.disable];
}

-(void) onSwitch{
    if(self.model.onSwitch) {
        self.model.onSwitch(self.switchView.on);
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.switchView.lim_left = self.valueView.lim_right - self.switchView.lim_width + 15.0f;
    self.switchView.lim_top = self.valueView.lim_height/2.0f - self.switchView.lim_height/2.0f;
    
    
}

@end
