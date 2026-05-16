//
//  WKAutoDeleteView.m
//  WuKongBase
//
//  Created by tt on 2023/9/22.
//

#import "WKAutoDeleteView.h"
#import "WKApp.h"
#import "UIView+WK.h"
@interface WKAutoDeleteView ()



@end

@implementation WKAutoDeleteView

- (instancetype)init
{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, 24.0f, 24.0f)];
    if (self) {
        [self setupUI];
    }
    return self;
}

-(void) setupUI {
    self.layer.masksToBounds = YES;
    self.layer.cornerRadius = self.lim_height/2.0f;
    [self addSubview:self.iconImgView];
    [self.iconImgView addSubview:self.timeLbl];
    
    self.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.5f];
}

- (void)setSecond:(NSInteger)second {
    self.timeLbl.text =  [self formatSecond:second];
    
    self.timeLbl.textColor = [UIColor whiteColor];
    [self.iconImgView setTintColor:self.timeLbl.textColor];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.timeLbl.lim_size = self.iconImgView.lim_size;
    self.iconImgView.lim_centerX_parent = self;
    self.iconImgView.lim_centerY_parent = self;
}


- (UIImageView *)iconImgView {
    if(!_iconImgView) {
        _iconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.lim_width-2.0f, self.lim_height-2.0f)];
        UIImage *iconImgView = [[self imageName:@"ConversationList/Index/MsgAutodeleteBadge"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _iconImgView.image = iconImgView;
    }
    return _iconImgView;
}

- (UILabel *)timeLbl {
    if(!_timeLbl) {
        _timeLbl = [[UILabel alloc] init];
        _timeLbl.font = [WKApp.shared.config appFontOfSizeSemibold:9.0f];
        _timeLbl.textAlignment = NSTextAlignmentCenter;
    }
    return _timeLbl ;
}

-(NSString*) formatSecond:(NSInteger)second {
    if(second < 60 * 60 * 24) {
        return @"";
    }
    NSInteger day = second / (60 * 60 * 24);
    NSInteger week = day / 7;
    NSInteger month = day / 30;
    NSInteger year = month / 12;
    
    if(year>0) {
        return [NSString stringWithFormat:@"%ldy",(long)year];
    }
    if(month>0) {
        return [NSString stringWithFormat:@"%ldm",(long)month];
    }
    if(week>0) {
        return [NSString stringWithFormat:@"%ldw",(long)week];
    }
    if(day>0) {
        return [NSString stringWithFormat:@"%ldd",(long)day];
    }
    return @"";
}


-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}
@end
