//
//  WKPanel.m
//  WuKongBase
//
//  Created by tt on 2020/1/11.
//

#import "WKPanel.h"
#import "UIView+CornerRadius.h"
#import "WuKongBase.h"

#define cornerRadiHeight 15.0f
@interface WKPanel ()

@end

@implementation WKPanel

-(instancetype) initWithContext:(id<WKConversationContext>) context {
    self = [super init];
    if(self) {
        self.context = context;
        self.backgroundColor =[WKApp shared].config.backgroundColor;
        self.contentView.backgroundColor = [WKApp shared].config.backgroundColor;
        [self addSubview:self.contentView];
    }
    return self;
}

-(void) inputInsertText:(NSString *)text {
    [self.context inputInsertText:text];
}

-(void) layoutPanel:(CGFloat)height {
    self.frame = CGRectMake(0, 0, WKScreenWidth,height);
    self.contentView.frame = CGRectMake(0.0f, cornerRadiHeight/2.0f, WKScreenWidth, height - cornerRadiHeight/2.0f);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self clipCornerWithView:YES andTopRight:YES andBottomLeft:false andBottomRight:false cornerRadii:CGSizeMake(cornerRadiHeight, cornerRadiHeight)];
}


- (UIView *)contentView {
    if(!_contentView) {
        _contentView = [[UIView alloc] init];
    }
    return _contentView;
}

@end
