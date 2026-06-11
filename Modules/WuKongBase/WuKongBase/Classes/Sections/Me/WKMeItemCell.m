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
@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,strong) UILabel *detailLbl;
@property(nonatomic,strong) UIImageView *arrowImgView;

@end

@implementation WKMeItemCell

+(CGSize) sizeForModel:(WKMeItemModel*)model{
    return  CGSizeMake(WKScreenWidth, 50.0f);
}
- (void)setupUI {
    [super setupUI];
    self.contentView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    self.backgroundColor = [WKApp shared].config.cellBackgroundColor;

    self.titleLbl = [[UILabel alloc] init];
    [self.titleLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
    [self.contentView addSubview:self.titleLbl];

    self.detailLbl = [[UILabel alloc] init];
    [self.detailLbl setFont:[UIFont systemFontOfSize:14.0f]];
    self.detailLbl.textColor = [WKApp shared].config.tipColor;
    self.detailLbl.textAlignment = NSTextAlignmentRight;
    self.detailLbl.hidden = YES;
    [self.contentView addSubview:self.detailLbl];

    self.arrowImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 7.0f, 12.0f)];
    self.arrowImgView.image = [self imageName:@"Common/Index/ArrowRight"];
    [self.contentView addSubview:self.arrowImgView];
}

- (void)refresh:(WKMeItemModel*)cellModel {
    [super refresh:cellModel];
    self.titleLbl.text = cellModel.title;
    self.titleLbl.textColor = [WKApp shared].config.defaultTextColor;

    if(cellModel.detail && ![cellModel.detail isEqualToString:@""]) {
        self.detailLbl.hidden = NO;
        self.detailLbl.text = cellModel.detail;
        [self.detailLbl sizeToFit];
    } else {
        self.detailLbl.hidden = YES;
    }

    // 默认显示箭头；model.showArrow = @(NO) 时隐藏
    if(cellModel.showArrow != nil) {
        self.arrowImgView.hidden = ![cellModel.showArrow boolValue];
    } else {
        self.arrowImgView.hidden = NO;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat padding = 16.0f;

    self.titleLbl.lim_left = padding;
    self.titleLbl.lim_width = self.lim_width - padding * 2 - 20.0f;
    self.titleLbl.lim_height = self.lim_height;

    CGFloat rightEdge = self.lim_width - padding;
    if(self.arrowImgView.hidden) {
        // 隐藏箭头时 detail 右端贴 padding
    } else {
        self.arrowImgView.lim_left = rightEdge - self.arrowImgView.lim_width;
        self.arrowImgView.lim_top = self.lim_height/2.0f - self.arrowImgView.lim_height/2.0f;
        rightEdge = self.arrowImgView.lim_left - 6.0f;
    }

    if(!self.detailLbl.hidden) {
        self.detailLbl.lim_left = rightEdge - self.detailLbl.lim_width;
        self.detailLbl.lim_top = self.lim_height/2.0f - self.detailLbl.lim_height/2.0f;
    }
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}

@end
