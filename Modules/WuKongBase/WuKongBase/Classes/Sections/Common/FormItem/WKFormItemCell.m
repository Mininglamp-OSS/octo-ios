//
//  WKFormItemCell.m
//  WuKongBase
//
//  Created by tt on 2020/1/21.
//

#import "WKFormItemCell.h"
#import "UIView+WK.h"
#import "WKApp.h"
#import "WKConstant.h"
@interface WKFormItemCell ()

@property(nonatomic,strong) WKFormItemModel *model;

@end

@implementation WKFormItemCell

+(CGSize) sizeForModel:(WKFormItemModel*)model{
    return CGSizeMake(WKScreenWidth, model.cellHeight);
}

- (void)setupUI {
    [super setupUI];
    self.arrowImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 7.0f, 12.0f)];
    self.arrowImgView.image = [self getImageName:@"Common/Index/ArrowRight"];
    [self addSubview:self.arrowImgView];
}

-(void) refresh:(WKFormItemModel*)model {
    [super refresh:model];
    self.model = model;
    self.bottomLineView.hidden = model.showBottomLine?![model.showBottomLine boolValue]:true;
    self.topLineView.hidden = model.showTopLine?![model.showTopLine boolValue]:true;
    if(model.onClick) {
           self.arrowImgView.hidden = NO;
       }else {
           self.arrowImgView.hidden = YES;
       }
       if(model.showArrow!=nil) {
           self.arrowImgView.hidden = ![model.showArrow boolValue];
       }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat bottomleftSpace = self.model.bottomLeftSpace?[self.model.bottomLeftSpace floatValue]:0.0f;
    self.bottomLineView.lim_left = bottomleftSpace;
    self.bottomLineView.lim_width = self.lim_width - bottomleftSpace;
    
    CGFloat arrowRight = 10.0f;
    self.arrowImgView.lim_left = self.lim_width - arrowRight - self.arrowImgView.lim_width;
    self.arrowImgView.lim_top = self.lim_height/2.0f - self.arrowImgView.lim_height/2.0f;
}

-(UIImage*) getImageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

-(void) onWillDisplay {
    
}

-(void) onEndDisplay {
    
}
@end
