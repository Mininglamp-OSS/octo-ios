//
//  YBIBVideoTopBar.m
//  YBImageBrowserDemo
//
//  Created by 波儿菜 on 2019/7/11.
//  Copyright © 2019 杨波. All rights reserved.
//

#import "WKVideoTopBar.h"
#import "WKApp.h"

@interface WKVideoTopBar ()
@property (nonatomic, strong) UIButton *cancelButton;
@end

@implementation WKVideoTopBar

#pragma mark - life cycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.cancelButton];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat buttonWidth = 54;
    self.cancelButton.frame = CGRectMake(0, 0, buttonWidth, self.bounds.size.height);
}

#pragma mark - public

+ (CGFloat)defaultHeight {
    return 50;
}

#pragma mark - getter

- (UIButton *)cancelButton {
    if (!_cancelButton) {
        _cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_cancelButton setImage:[self getImageWithName:@"Conversation/VideoBrowser/ybib_cancel"] forState:UIControlStateNormal];
        _cancelButton.layer.shadowColor = UIColor.darkGrayColor.CGColor;
        _cancelButton.layer.shadowOffset = CGSizeMake(0, 1);
        _cancelButton.layer.shadowOpacity = 1;
        _cancelButton.layer.shadowRadius = 4;
    }
    return _cancelButton;
}

-(UIImage*) getImageWithName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
