// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKSearchbarView.m
//  AFNetworking
//
//  Created by tt on 2020/6/8.
//

#import "WKSearchbarView.h"
#import "WKResource.h"
#import "WuKongBase.h"
@interface WKSearchbarView ()

@property(nonatomic,strong) UIImageView *searchIconImgView;
@property(nonatomic,strong) UILabel *placeholderLbl;

@end

@implementation WKSearchbarView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

-(void) setupUI {
    self.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] init];
    [tap addTarget:self action:@selector(tap)];
    [self addGestureRecognizer:tap];
    
    self.layer.masksToBounds = YES;
    self.layer.cornerRadius = 4.0f;
    [self addSubview:self.searchIconImgView];
    [self addSubview:self.placeholderLbl];
}

-(void) tap {
    if(self.onClick) {
        self.onClick();
    }
}

- (UIImageView *)searchIconImgView {
    if(!_searchIconImgView) {
        _searchIconImgView = [[UIImageView alloc] initWithImage:[self imageName:@"Common/Index/IconSearch2"]];
        [_searchIconImgView setFrame:CGRectMake(0.0f, 0.0f, 20.0f, 20.0f)];
    }
    return _searchIconImgView;
}

- (UILabel *)placeholderLbl {
    if(!_placeholderLbl) {
        _placeholderLbl = [[UILabel alloc] init];
        [_placeholderLbl setTextColor:[UIColor grayColor]];
    }
    return _placeholderLbl;
}

- (void)setPlaceholder:(NSString *)placeholder {
    _placeholderLbl.text = placeholder;
    [_placeholderLbl sizeToFit];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [self setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    self.layer.cornerRadius = self.lim_height / 2.0f;

    CGFloat leftPadding = 12.0f;
    CGFloat iconTextGap = 6.0f;

    self.searchIconImgView.lim_left = leftPadding;
    self.searchIconImgView.lim_top = self.lim_height / 2.0f - self.searchIconImgView.lim_height / 2.0f;

    self.placeholderLbl.lim_left = self.searchIconImgView.lim_right + iconTextGap;
    self.placeholderLbl.lim_top = self.lim_height / 2.0f - self.placeholderLbl.lim_height / 2.0f;

}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
@end
