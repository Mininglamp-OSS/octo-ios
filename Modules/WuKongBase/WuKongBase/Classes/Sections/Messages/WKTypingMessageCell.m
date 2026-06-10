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
    CGFloat nameMaxW = self.messageContentView.lim_width;
    if(!self.nameLbl.hidden) {
        if(position == WKBubblePostionFirst || position == WKBubblePostionSingle) {
            self.nameLbl.lim_left = WK_CONTENT_INSETS.left + WKLastBubbleOffsetSpace;
        } else {
            self.nameLbl.lim_left = WK_CONTENT_INSETS.left;
        }

        self.nameLbl.lim_top = WK_CONTENT_INSETS.top;
        CGSize fitSize = [self.nameLbl sizeThatFits:CGSizeMake(nameMaxW, WK_NICKNAME_HEIGHT)];
        self.nameLbl.lim_width = MIN(fitSize.width, nameMaxW);
    } else {
        self.nameLbl.lim_width = nameMaxW;
    }

    // 实名 ✓ + Bot(AI) 徽章统一布局（父类共享实现）。
    [self layoutNameRowBadgesWithMaxRowWidth:(self.nameLbl.hidden ? 0.0f : nameMaxW)];
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
