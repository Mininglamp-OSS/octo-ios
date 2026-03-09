//
//  LMOnlineBadgeView.m
//  WuKongBase
//
//  Created by tt on 2020/8/27.
//

#import "WKOnlineBadgeView.h"
#import "UIView+WK.h"
#import "WKApp.h"
@interface WKOnlineBadgeView ()



@property(nonatomic,strong) UILabel *circleLbl;

@property(nonatomic,assign) CGRect oldFrame;

@end

@implementation WKOnlineBadgeView

+(instancetype) initWithTip:(NSString*)tip {
    WKOnlineBadgeView *v = [[WKOnlineBadgeView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 15.0f, 15.0f)];
    v.tip = tip;
    return v;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.layer.masksToBounds = YES;
        self.layer.cornerRadius = self.frame.size.height/2.0f;
        [self addSubview:self.circleLbl];
        self.oldFrame = frame;
    }
    return self;
}

#define circleWidth 4.0f
#define tipFont  [[WKApp shared].config appFontOfSizeMedium:10.0f]
- (UIView *)circleLbl {
    if(!_circleLbl) {
        _circleLbl = [[UILabel alloc] init];
        _circleLbl.font = tipFont;
        [self layoutCirCleView];
    }
    return _circleLbl;
}


-(void) layoutCirCleView {
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.oldFrame.size.width, self.oldFrame.size.height);
    self.circleLbl.frame =CGRectMake(circleWidth/2.0f, circleWidth/2.0f, self.frame.size.width - circleWidth, self.frame.size.height -circleWidth );
    self.circleLbl.layer.masksToBounds = YES;
    self.circleLbl.layer.cornerRadius = self.circleLbl.frame.size.height/2.0f;
    [self.circleLbl setBackgroundColor:[UIColor colorWithRed:124.0f/255.0f green:208.0f/255.0f blue:83.0f/255.0f alpha:1.0f]];
    [self.circleLbl setTextAlignment:NSTextAlignmentCenter];
}

-(void) layoutCirCleViewWithTip {
    CGSize tipSize = CGSizeMake(34.0f, 12.0f);
    
    CGFloat newCircleWidth = circleWidth;
    self.lim_width = tipSize.width + newCircleWidth;
    self.lim_height = tipSize.height + newCircleWidth;
    self.layer.cornerRadius = self.lim_height/2.0f;
    
    self.circleLbl.frame =CGRectMake(newCircleWidth/2.0f, newCircleWidth/2.0f, tipSize.width, self.frame.size.height -newCircleWidth );
    self.circleLbl.layer.cornerRadius = self.circleLbl.lim_height/2.0f;
    self.circleLbl.text = self.tip;
    self.circleLbl.textColor = [UIColor colorWithRed:124.0f/255.0f green:208.0f/255.0f blue:83.0f/255.0f alpha:1.0f];
    self.circleLbl.backgroundColor = [UIColor colorWithRed:238.0f/255.0f green:249.0f/255.0f blue:233.0f/255.0f alpha:1.0f];
}


- (CGSize) getTextSize:(NSString*) text maxWidth:(CGFloat)maxWidth{
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.alignment = NSTextAlignmentCenter;
   NSAttributedString *string = [[NSAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:tipFont, NSParagraphStyleAttributeName:style}];
    CGSize size =  [string boundingRectWithSize:CGSizeMake(maxWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil].size;
    return size;
}


- (void)setTip:(NSString *)tip {
    _tip = tip;
    if(tip && ![tip isEqualToString:@""]) {
        [self layoutCirCleViewWithTip];
    }else {
        [self layoutCirCleView];
    }
}

@end
