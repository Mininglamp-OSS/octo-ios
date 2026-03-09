//
//  WKEmojiCollectionTitleHeader.m
//  WuKongBase
//
//  Created by tt on 2021/10/22.
//

#import "WKEmojiCollectionTitleHeader.h"
#import "WuKongBase.h"
@interface WKEmojiCollectionTitleHeader ()



@end

@implementation WKEmojiCollectionTitleHeader

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.titleLbl];
    }
    return self;
}

- (void)layoutSubviews {
    
    self.titleLbl.lim_centerY_parent = self;
    self.titleLbl.lim_left = 10.0f;
}


- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
    }
    return _titleLbl;
}

@end
