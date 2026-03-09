//
//  WKEmojiCell.m
//  WuKongBase
//
//  Created by tt on 2020/1/9.
//

#import "WKEmojiCell.h"

#import "UIView+WK.h"

@interface WKEmojiCell ()

@property(nonatomic,strong) UIImageView *emojiImgView;

@end
@implementation WKEmojiCell


+(NSString *)reuseIdentifier
{
    return NSStringFromClass(self);
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.emojiImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
        [self addSubview:self.emojiImgView];
        
    
    }
    return self;
}
-(void)setEmoji:(UIImage *)image {
    self.emojiImgView.image = image;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.emojiImgView.lim_left = self.lim_width/2.0f - self.emojiImgView.lim_width/2.0f;
    self.emojiImgView.lim_top = self.lim_height/2.0f - self.emojiImgView.lim_height / 2.0f;
}

@end
