//
//  WKViewItemCell.m
//  WuKongBase
//
//  Created by tt on 2020/1/21.
//

#import "WKViewItemCell.h"
#import "WKLabelItemCell.h"
#import "WKResource.h"
#import "WKApp.h"
@implementation WKViewItemModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.bottomLeftSpace  = @(20.0f);
    }
    return self;
}

- (Class)cell {
    return WKViewItemCell.class;
}


@end

@interface WKViewItemCell ()



@end

@implementation WKViewItemCell

- (void)setupUI {
    [super setupUI];
    self.labelLbl = [[UILabel alloc] init];
    [self.labelLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
    [self.contentView addSubview:self.labelLbl];
    
    self.valueView = [[UIView alloc] init];
    [self.contentView addSubview:self.valueView];
}

- (void)refresh:(WKViewItemModel *)model {
    [super refresh:model];
    self.labelLbl.text = model.label;
    [self.labelLbl sizeToFit];

    if(model.labelColor) {
        [self.labelLbl setTextColor:model.labelColor];
    }else{
        [self.labelLbl setTextColor:[WKApp shared].config.defaultTextColor];
    }
    
   
    
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat labelLeft = 15.0f;
    self.labelLbl.lim_top = self.lim_height/2.0f - self.labelLbl.lim_height/2.0f;
    self.labelLbl.lim_left = labelLeft;
    
    CGFloat valueLeft = 10.0f;
    self.valueView.lim_height = self.lim_height;
    CGFloat arrowRight = 10.0f;
    self.valueView.lim_width = self.lim_width - ( self.labelLbl.lim_left + self.labelLbl.lim_width) - valueLeft - self.arrowImgView.lim_width - arrowRight - 10.0f;
    self.valueView.lim_left = self.labelLbl.lim_right + valueLeft;

}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
@end
