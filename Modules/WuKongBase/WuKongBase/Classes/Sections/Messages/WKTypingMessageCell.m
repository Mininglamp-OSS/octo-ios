//
//  WKTypingMessageCell.m
//  WuKongBase
//
//  Created by tt on 2020/8/12.
//

#import "WKTypingMessageCell.h"
#import <DGActivityIndicatorView/DGActivityIndicatorView.h>
@interface WKTypingMessageCell ()
@property(nonatomic,strong) DGActivityIndicatorView *typingIndicatorView;
@end

@implementation WKTypingMessageCell

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] init];
    attrStr.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
    [attrStr lim_parse:@"1"]; // 随便给一个字符串，这里主要目的是计算出正文高度跟文本消息的正文高度一样 这样就不会出现闪烁的感觉
    CGFloat width = 44.0f;
    CGSize size = [attrStr size:width];
    return CGSizeMake(width, size.height);
}

- (void)initUI {
    [super initUI];
    self.typingIndicatorView = [[DGActivityIndicatorView alloc] initWithType:DGActivityIndicatorAnimationTypeThreeDots tintColor:[UIColor grayColor] size:30.0f];
    [self.messageContentView addSubview:self.typingIndicatorView];
    self.trailingView.timeLbl.hidden = YES;
    
}


- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    self.nameLbl.hidden = YES;
    [self.typingIndicatorView startAnimating];
}


- (void)layoutSubviews {
    [super layoutSubviews];
    self.typingIndicatorView.frame = self.messageContentView.bounds;
}


@end
