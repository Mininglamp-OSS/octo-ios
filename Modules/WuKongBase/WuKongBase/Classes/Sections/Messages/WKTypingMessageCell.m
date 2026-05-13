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
    [attrStr lim_parse:@"1"];
    CGFloat width = 44.0f;
    CGSize size = [attrStr size:width];

    CGFloat nicknameWidth = 0.0f;
    if([self isShowName:model]) {
        // 使用包含AI标识宽度的计算，避免气泡太窄导致AI标识被裁剪
        nicknameWidth = [self getNicknameRowWidth:model];
    }

    return CGSizeMake(MAX(width, nicknameWidth), size.height);
}

// 参考 WKTextMessageCell：将昵称空间放入 contentEdgeInsets，使昵称在气泡内部
+(UIEdgeInsets) contentEdgeInsets:(WKMessageModel*)model {
    UIEdgeInsets edgeInsets = [super contentEdgeInsets:model];
    if([self isShowName:model]) {
        return UIEdgeInsetsMake(edgeInsets.top + WK_NICKNAME_HEIGHT + 10.0f, edgeInsets.left, edgeInsets.bottom, edgeInsets.right);
    }
    return edgeInsets;
}

// 参考 WKTextMessageCell：昵称空间已在 contentEdgeInsets 中，bubbleEdgeInsets.top 设为 0
+(UIEdgeInsets) bubbleEdgeInsets:(WKMessageModel*) model contentSize:(CGSize)contentSize {
    UIEdgeInsets bubbleInsets = [super bubbleEdgeInsets:model contentSize:contentSize];
    return UIEdgeInsetsMake(0.0f, bubbleInsets.left, bubbleInsets.bottom, bubbleInsets.right);
}

// 参考 WKTextMessageCell：将昵称定位到气泡内部（正值 lim_top），而不是父类的负值
-(void) layoutName {
    WKBubblePostion position = [[self class] bubblePosition:self.messageModel];
    if(!self.nameLbl.hidden) {
        if(position == WKBubblePostionFirst || position == WKBubblePostionSingle) {
            self.nameLbl.lim_left = WK_CONTENT_INSETS.left + WKLastBubbleOffsetSpace;
        } else {
            self.nameLbl.lim_left = WK_CONTENT_INSETS.left;
        }

        self.nameLbl.lim_top = WK_CONTENT_INSETS.top;
        CGSize fitSize = [self.nameLbl sizeThatFits:CGSizeMake(self.messageContentView.lim_width, WK_NICKNAME_HEIGHT)];
        self.nameLbl.lim_width = MIN(fitSize.width, self.messageContentView.lim_width);
    } else {
        self.nameLbl.lim_width = self.messageContentView.lim_width;
    }

    // YUJ-381 实名 ✓ 徽章 + Bot 标识：与 WKTextMessageCell 一致的 realname → bot 串行布局。
    CGFloat afterNameRight = self.nameLbl.lim_left + self.nameLbl.lim_width;
    if (!self.realnameVerifiedImgView.hidden) {
        self.realnameVerifiedImgView.lim_width = 12.0f;
        self.realnameVerifiedImgView.lim_height = 12.0f;
        self.realnameVerifiedImgView.lim_left = afterNameRight + 6.0f;
        self.realnameVerifiedImgView.lim_top = self.nameLbl.lim_top + (self.nameLbl.lim_height - self.realnameVerifiedImgView.lim_height) / 2.0f;
        afterNameRight = self.realnameVerifiedImgView.lim_left + self.realnameVerifiedImgView.lim_width;
    }
    self.botBadgeLbl.lim_left = afterNameRight + 6.0f;
    self.botBadgeLbl.lim_top = self.nameLbl.lim_top + (self.nameLbl.lim_height - self.botBadgeLbl.lim_height) / 2.0f;
}

- (void)initUI {
    [super initUI];
    self.typingIndicatorView = [[DGActivityIndicatorView alloc] initWithType:DGActivityIndicatorAnimationTypeThreeDots tintColor:[UIColor grayColor] size:30.0f];
    [self.messageContentView addSubview:self.typingIndicatorView];
    self.trailingView.timeLbl.hidden = YES;
}


- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    [self.typingIndicatorView startAnimating];
}


- (void)layoutSubviews {
    [super layoutSubviews];
    self.typingIndicatorView.frame = self.messageContentView.bounds;
}


@end
