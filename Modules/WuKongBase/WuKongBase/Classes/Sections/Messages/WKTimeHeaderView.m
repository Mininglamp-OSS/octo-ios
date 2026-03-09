//
//  WKTimeHeaderView.m
//  WuKongBase
//
//  Created by tt on 2021/7/26.
//

#import "WKTimeHeaderView.h"

@interface WKTimeHeaderView ()


//@property(nonatomic,strong) UIImageView *dateBackgroudImgView;

@end

@implementation WKTimeHeaderView

- (instancetype)initWithReuseIdentifier:(nullable NSString *)reuseIdentifier {
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self) {
//        [self setBackgroundColor:[UIColor clearColor]];
        self.tintColor = [UIColor clearColor];
//        [self addSubview:self.dateBackgroudImgView];
        [self.contentView addSubview:self.dateLbl];
        
        // iOS 15 设置背景透明
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, 0.0);
        UIImage *blank = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        self.backgroundView = [[UIImageView alloc] initWithImage:blank];
    }
    return self;
}


- (void)prepareForReuse {
    [super prepareForReuse];
    self.alpha = 1;
}


+(NSString*) reuseId {
    return @"WKTimeHeaderView";
}

+(CGFloat) height {
    return 44.0f;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.dateLbl.lim_top = self.contentView.lim_height/2.0f - self.dateLbl.lim_height/2.0f;
    self.dateLbl.lim_left = self.contentView.lim_width/2.0f - self.dateLbl.lim_width/2.0f;
    
//    self.dateBackgroudImgView.lim_centerY_parent = self;
//    self.dateBackgroudImgView.lim_centerX_parent = self;
    
}

//- (UIImageView *)dateBackgroudImgView {
//    if(!_dateBackgroudImgView) {
//        _dateBackgroudImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 100.0f, 24.0f)];
//        _dateBackgroudImgView.image = [self imageName:@"time_bubble"];
//    }
//    return _dateBackgroudImgView;
//}

- (UILabel *)dateLbl {
    if(!_dateLbl) {
        _dateLbl = [[WKTipLabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 100.0f, 24.0f)];
       
        _dateLbl.layer.masksToBounds = YES;
        _dateLbl.layer.cornerRadius = 10.0f;
        _dateLbl.textAlignment = NSTextAlignmentCenter;
        _dateLbl.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        _dateLbl.textColor = [UIColor grayColor];
       
        [_dateLbl setFont:[[WKApp shared].config appFontOfSize:14.0f]];
    }
    return _dateLbl;
}
-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}


@end
