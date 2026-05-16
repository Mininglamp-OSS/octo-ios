//
//  WKLabelItemSelectCell.m
//  WuKongBase
//
//  Created by tt on 2020/12/11.
//

#import "WKLabelItemSelectCell.h"
#import "WKApp.h"

@implementation WKLabelItemSelectModel

- (NSNumber *)showArrow {
    return @(NO);
}

- (Class)cell {
    return WKLabelItemSelectCell.class;
}

@end

@interface WKLabelItemSelectCell ()

@property(nonatomic,strong) UIImageView *selectImgView;

@end

@implementation WKLabelItemSelectCell

- (void)setupUI {
    [super setupUI];
    [self.contentView addSubview:self.selectImgView];
}

- (void)refresh:(WKLabelItemSelectModel *)model {
    [super refresh:model];
    self.selectImgView.hidden = !model.selected;
}

- (void)layoutSubviews {
    
    [super layoutSubviews];
    self.selectImgView.lim_centerY_parent = self.contentView;
    self.selectImgView.lim_left = self.contentView.lim_width - self.selectImgView.lim_width - 15.0f;
}

- (UIImageView *)selectImgView {
    if(!_selectImgView) {
        _selectImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 16.0f, 16.0f)];
        _selectImgView.image = [self getImageName:@"Common/Index/Tick"];
    }
    return _selectImgView;
}


-(UIImage*) getImageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
