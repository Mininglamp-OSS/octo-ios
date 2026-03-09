//
//  WKCell.m
//  WuKongContacts
//
//  Created by tt on 2019/12/8.
//

#import "WKCell.h"
#import "UIView+WK.h"
#import "WKApp.h"
@interface WKCell (){
  
}


@end
@implementation WKCell


- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        
        [self setupUI];
    }
    return self;
}

-(void) setupUI{
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    self.topLineView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.lim_width, 0.5f)];
    [self.topLineView setBackgroundColor:[UIColor colorWithRed:217.0f/255.0f green:217.0f/255.0f blue:217.0f/255.0f alpha:1.0]];
    self.topLineView.hidden = YES;
    [self addSubview:self.topLineView];
    
    self.bottomLineView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.lim_width, 0.5f)];
    self.bottomLineView.hidden = YES;
    [self addSubview:self.bottomLineView];
    
    
}

+ (NSString *)cellId {
    return NSStringFromClass(self);
}
-(void) refresh:(id)cellModel{
    if([WKApp shared].config.style == WKSystemStyleDark) {
        [self.bottomLineView setBackgroundColor:[UIColor colorWithRed:32.0f/255.0f green:32.0f/255.0f blue:32.0f/255.0f alpha:1.0]];
    }else{
        [self.bottomLineView setBackgroundColor:[UIColor colorWithRed:240.0f/255.0f green:240.0f/255.0f blue:240.0f/255.0f alpha:1.0]];
    }
    
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.topLineView.lim_top = 0.0f;
    self.topLineView.lim_width = self.lim_width;
    
    self.bottomLineView.lim_width = self.lim_width;
    self.bottomLineView.lim_top = self.lim_height - 0.5f;
}

@end
