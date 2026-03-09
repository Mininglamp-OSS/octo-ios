//
//  WKHistorySpliteTipCell.m
//  WuKongBase
//
//  Created by tt on 2020/10/8.
//

#import "WKHistorySplitTipCell.h"
#import "WuKongBase.h"
@interface WKHistorySplitTipCell ()

@property(nonatomic,strong) UIView *spliteLineView1;
@property(nonatomic,strong) UIView *spliteLineView2;

@property(nonatomic,strong) UILabel *tipLbl;

@end

@implementation WKHistorySplitTipCell

+ (CGSize)sizeForMessage:(WKMessageModel *)model {
    return CGSizeMake(WKScreenWidth, 40.0f);
}

- (void)initUI {
    [super initUI];
    [self setBackgroundColor:[UIColor clearColor]];
    [self.contentView addSubview:self.spliteLineView1];
    [self.contentView addSubview:self.spliteLineView2];
    [self.contentView addSubview:self.tipLbl];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    
    self.tipLbl.text = LLang(@"以上为历史消息");
    [self.tipLbl sizeToFit];
    
    if([WKApp shared].config.style == WKSystemStyleDark) {
        [self.spliteLineView1 setBackgroundColor:[UIColor colorWithRed:30.0f/255.0f green:30.0f/255.0f blue:30.0f/255.0f alpha:1.0f]];
        [self.spliteLineView2 setBackgroundColor:[UIColor colorWithRed:30.0f/255.0f green:30.0f/255.0f blue:30.0f/255.0f alpha:1.0f]];
    }else{
        [self.spliteLineView1 setBackgroundColor: [WKApp shared].config.tipColor];
        [self.spliteLineView2 setBackgroundColor: [WKApp shared].config.tipColor];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat tipToLineSpace = 10.0f;
    
    self.spliteLineView1.lim_left = 15.0f;
    self.spliteLineView1.lim_width = (self.lim_width - self.spliteLineView1.lim_left*2 - self.tipLbl.lim_width-tipToLineSpace*2)/2.0f;
    self.spliteLineView1.lim_centerY_parent = self.contentView;
    
    self.tipLbl.lim_left = self.spliteLineView1.lim_right + tipToLineSpace;
    self.tipLbl.lim_top = self.contentView.lim_height/2.0f - self.tipLbl.lim_height/2.0f;
    
    self.spliteLineView2.lim_left = self.tipLbl.lim_right +tipToLineSpace;
    self.spliteLineView2.lim_width = self.spliteLineView1.lim_width;
    self.spliteLineView2.lim_top = self.spliteLineView1.lim_top;
}


- (UIView *)spliteLineView1 {
    if(!_spliteLineView1) {
        _spliteLineView1 = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, 0.5f)];
    }
    return _spliteLineView1;
}

- (UIView *)spliteLineView2 {
    if(!_spliteLineView2) {
        _spliteLineView2 = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, 0.5f)];
    }
    return _spliteLineView2;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] init];
        _tipLbl.font = [[WKApp shared].config appFontOfSize:13.0f];
        _tipLbl.textColor = [WKApp shared].config.tipColor;
    }
   return _tipLbl;
}
@end
