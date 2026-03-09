//
//  WKMeItemCell.m
//  WuKongBase
//
//  Created by tt on 2020/6/9.
//

#import "WKMeItemCell.h"

@implementation WKMeItemModel

-(Class) cell {
    return WKMeItemCell.class;
}
@end

@interface WKMeItemCell ()
@property(nonatomic,strong) UIImageView *iconImageView; // 头像
@property(nonatomic,strong) UILabel *titleLbl; // 标题
@property(nonatomic,strong) UIImageView *arrowImgView; // 箭头

@end

@implementation WKMeItemCell

+(CGSize) sizeForModel:(WKMeItemModel*)model{
    return  CGSizeMake(WKScreenWidth, 60.0f);
}
- (void)setupUI {
    [super setupUI];
    CGFloat iconSize = 30.0f;
    self.iconImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, iconSize, iconSize)];
    self.iconImageView.layer.masksToBounds = YES;
    self.iconImageView.layer.cornerRadius = 5.0f;
    [self.contentView addSubview:self.iconImageView];
    
    self.titleLbl = [[UILabel alloc] init];
    [self.titleLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
    [self.contentView addSubview:self.titleLbl];
    
    self.arrowImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 7.0f, 12.0f)];
    self.arrowImgView.image = [self imageName:@"Common/Index/ArrowRight"];
    [self.contentView addSubview:self.arrowImgView];
}

- (void)refresh:(WKMeItemModel*)cellModel {
    [super refresh:cellModel];
    self.titleLbl.text = cellModel.title;
    self.iconImageView.image = cellModel.icon;
    
    self.titleLbl.textColor = [WKApp shared].config.defaultTextColor;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat iconLeft = 15.0f;
    self.iconImageView.lim_top = self.lim_height/2.0f - self.iconImageView.lim_height/2.0f;
    self.iconImageView.lim_left = iconLeft;
    
    CGFloat arrowRight = 10.0f;
    self.arrowImgView.lim_left = self.lim_width - arrowRight - self.arrowImgView.lim_width;
    self.arrowImgView.lim_top = self.lim_height/2.0f - self.arrowImgView.lim_height/2.0f;
    
    CGFloat titleLeft = 10.0f;
    CGFloat titleRight = 10.0f;
    self.titleLbl.lim_left = self.iconImageView.lim_right + titleLeft;
    self.titleLbl.lim_width = self.lim_width - self.titleLbl.lim_left - titleRight;
    self.titleLbl.lim_height = self.lim_height;
    
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
