//
//  WKMergeForwardCell.m
//  WuKongBase
//
//  Created by tt on 2020/10/12.
//

#import "WKMergeForwardCell.h"
#import "WKMergeForwardContent.h"
#import "WKMergeForwardDetailVC.h"
#import "WuKongBase.h"
@interface WKMergeForwardCell ()

@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,strong) UIView *messageBox;
@property(nonatomic,strong) UIView *lineView;
@property(nonatomic,strong) UILabel *descLbl;

@end

#define titleHeight 18.0f
#define titleTop 10.0f
#define messageBoxTop 4.0f
#define messageHeight 13.0f

#define lineTop 4.0f

#define descHeight 26.0f


@implementation WKMergeForwardCell

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    WKMergeForwardContent *content = (WKMergeForwardContent*)model.content;
    return CGSizeMake([WKApp shared].config.messageContentMaxWidth, titleTop + titleHeight + messageBoxTop + messageHeight*(content.msgs.count>4?4:content.msgs.count)+ lineTop+1.0f + descHeight);
}

- (void)initUI {
    [super initUI];
    self.messageContentView.layer.masksToBounds = YES;
    self.messageContentView.layer.cornerRadius = 4.0f;
    [self.messageContentView addSubview:self.titleLbl];
    [self.messageContentView addSubview:self.messageBox];
    [self.messageContentView addSubview:self.lineView];
    [self.messageContentView addSubview:self.descLbl];
    
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    WKMergeForwardContent *content = (WKMergeForwardContent*)model.content;

    self.titleLbl.text = content.title;

    [[self.messageBox subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    NSInteger displayCount = MIN((NSInteger)(content.msgs.count), 4);
    if(displayCount > 0) {
        // textLbl 的位置/宽度直接在这里同步设好，不依赖 layoutSubviews：
        // 父类 layoutSubviews 在 messageModel 未 set 时会提前 return（WKMessageCell.m:974），
        // 而 UITableView 在 cellForRow 之前可能已经触发过一次 layoutSubviews，
        // 那次跑完后 messageContentView.lim_size / messageBox 子 view frame 都没被撑开；
        // refresh 之后系统不一定再触发 layoutSubviews（行高没变时）。
        // 直接同步设 frame 可以彻底避开这个时机问题。
        CGFloat leftSpace = 10.0f;
        CGFloat lblW = [WKApp shared].config.messageContentMaxWidth - leftSpace * 2;
        for (NSInteger i=0; i<displayCount; i++) {
            WKMessage *message = content.msgs[i];
            UILabel *textLbl = [self messageTextLbl];
            textLbl.frame = CGRectMake(leftSpace, i * messageHeight, lblW, messageHeight);

            NSString *fromName = @"";
            if(message.from) {
                fromName = message.from.displayName;
            }else{
                [[WKSDK shared].channelManager fetchChannelInfo:[[WKChannel alloc] initWith:message.fromUid channelType:WK_PERSON]];
            }
            textLbl.text = [NSString stringWithFormat:@"%@：%@",fromName,[message.content conversationDigest]];
            [self.messageBox addSubview:textLbl];
        }
        // messageBox 自身高度也同步设好，避免 layoutSubviews 没跑时 height=0
        self.messageBox.lim_height = messageHeight * displayCount;
    }

    [self.messageContentView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    self.titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    self.lineView.backgroundColor = [WKApp shared].config.lineColor;

    self.trailingView.timeLbl.textColor = [WKApp shared].config.tipColor;
    self.trailingView.statusImgView.tintColor = [WKApp shared].config.tipColor;

    // schedule 一次完整 layoutSubviews，让 messageBox.lim_top / messageContentView 等也跟上
    [self setNeedsLayout];
}

- (void)onTap {
    WKMergeForwardDetailVC *vc = WKMergeForwardDetailVC.new;
    vc.mergeForwardContent = (WKMergeForwardContent*)self.messageModel.content;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat leftSpace = 10.0f;
    self.titleLbl.lim_top = titleTop;
    self.titleLbl.lim_left = 10.0f;
    self.titleLbl.lim_width = self.messageContentView.lim_width - leftSpace*2;
    
    self.messageBox.lim_top = self.titleLbl.lim_bottom + messageBoxTop;
    self.messageBox.lim_width = self.messageContentView.lim_width;
    self.messageBox.lim_height = messageHeight * self.messageBox.subviews.count;
    if(self.messageBox.subviews.count>0) {
        for (NSInteger i=0; i<self.messageBox.subviews.count; i++) {
            UIView *view = self.messageBox.subviews[i];
            view.lim_left = 10.0f;
            view.lim_top = i * view.lim_height;
            view.lim_width = self.messageContentView.lim_width - leftSpace*2;
        }
    }
    
    self.lineView.lim_width = self.messageContentView.lim_width - leftSpace*2;
    self.lineView.lim_left = leftSpace;
    self.lineView.lim_top = self.messageBox.lim_bottom + lineTop;
    
    self.descLbl.lim_top = self.lineView.lim_bottom;
    self.descLbl.lim_left = leftSpace;
    self.descLbl.lim_width = self.messageContentView.lim_width - leftSpace * 2;
    
}


- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, titleHeight)];
        _titleLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
    }
    return _titleLbl;
}

- (UIView *)messageBox {
    if(!_messageBox) {
        _messageBox = [[UIView alloc] init];
        _messageBox.userInteractionEnabled = NO;
    }
    return _messageBox;
}

-(UILabel*) messageTextLbl {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, messageHeight)];
    lbl.font = [[WKApp shared].config appFontOfSize:12.0f];
    lbl.textColor = [WKApp shared].config.tipColor;
    return lbl;
}

- (UIView *)lineView {
    if(!_lineView) {
        _lineView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, 1.0f)];
        [_lineView setBackgroundColor:[UIColor colorWithRed:246.0f/255.0f green:246.0f/255.0f blue:246.0f/255.0f alpha:1.0f]];
    }
    return _lineView;
}

- (UILabel *)descLbl {
    if(!_descLbl) {
        _descLbl = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, descHeight)];
        _descLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
        _descLbl.textColor = [WKApp shared].config.tipColor;
        _descLbl.text = LLang(@"聊天记录");
    }
    return _descLbl;
}


+ (BOOL)hiddenBubble {
    return YES;
}


@end
