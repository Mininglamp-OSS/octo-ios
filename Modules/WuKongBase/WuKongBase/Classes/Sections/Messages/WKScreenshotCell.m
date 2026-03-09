//
//  WKScreenshotCell.m
//  WuKongBase
//
//  Created by tt on 2020/10/16.
//

#import "WKScreenshotCell.h"
#import "WKScreenshotContent.h"
#import "WKTipLabel.h"
@interface WKScreenshotCell ()
@property(nonatomic,strong) WKTipLabel *tipTextLbl;
@property(nonatomic,strong) WKMessageModel *messageModel;

@end

@implementation WKScreenshotCell

+ (CGSize)sizeForMessage:(WKMessageModel *)model {
    WKScreenshotContent *content = (WKScreenshotContent*)model.content;
    CGSize contentSize = CGSizeMake(0.0f, 0.0f);
    if(content.tip) {
        contentSize =  [[self class] getTextSize:content.tip maxWidth:WKScreenWidth - 20];
    }
    return CGSizeMake(contentSize.width+25.0f, contentSize.height+20.0f);
}


-(void) initUI {
    [super initUI];
    [self setBackgroundColor:[UIColor clearColor]];

    
    self.tipTextLbl = [[WKTipLabel alloc] init];
    [self.tipTextLbl setTextAlignment:NSTextAlignmentCenter];
    [self.tipTextLbl setFont:[UIFont systemFontOfSize:[WKApp shared].config.messageTipTimeFontSize]];
    [self.tipTextLbl setTextColor:[UIColor grayColor]];
    [self.tipTextLbl setBackgroundColor:[UIColor whiteColor]];
    self.tipTextLbl.layer.masksToBounds = YES;
    self.tipTextLbl.layer.cornerRadius = 10.0f;
    [self addSubview:self.tipTextLbl];
    
    
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    self.messageModel = model;
    WKScreenshotContent *content = (WKScreenshotContent*)model.content;
    
    self.tipTextLbl.text = content.tip;
    
    [self.tipTextLbl setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
}


- (void)layoutSubviews {
    [super layoutSubviews];
    if(!self.messageModel) {
        return;
    }
    CGSize contentSize = [[self class] sizeForMessage:self.messageModel];
    self.tipTextLbl.lim_size = CGSizeMake(contentSize.width-10.0f, contentSize.height-10.0f);
    self.tipTextLbl.lim_left = self.lim_width/2.0f - self.tipTextLbl.lim_width/2.0f;
}

+ (CGSize) getTextSize:(NSString*) text maxWidth:(CGFloat)maxWidth{
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.alignment = NSTextAlignmentCenter;
    NSAttributedString *string = [[NSAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:[WKApp shared].config.messageTipTimeFontSize], NSParagraphStyleAttributeName:style}];
    CGSize size =  [string boundingRectWithSize:CGSizeMake(maxWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil].size;
    return size;
}

@end
