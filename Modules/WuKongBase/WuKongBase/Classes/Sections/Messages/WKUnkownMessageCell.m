//
//  WKUnkownMessageCell.m
//  WuKongBase
//
//  Created by tt on 2020/1/11.
//

#import "WKUnkownMessageCell.h"
#import "WKApp.h"
#import "WKTimeTool.h"
#define tipFontSize 15.0f

@interface WKUnkownMessageCell()

@property(nonatomic,strong) UILabel *textLbl;

@end

@implementation WKUnkownMessageCell

+ (CGSize) contentSizeForMessage:(WKMessageModel *)model {
    
    return CGSizeMake([WKApp shared].config.messageContentMaxWidth, 44.0f);
}

-(void) initUI {
    [super initUI];
    self.textLbl = [[UILabel alloc] init];
    self.textLbl.numberOfLines = 0;
    self.textLbl.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
    self.textLbl.lineBreakMode = NSLineBreakByWordWrapping;
    [self.messageContentView addSubview:self.textLbl];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
//    self.trailingView.hidden = YES;
    self.textLbl.text =[WKApp shared].config.unkownMessageText;
    [self.textLbl sizeToFit];
    
    if(model.isSend) {
        self.textLbl.textColor =  [WKApp shared].config.messageSendTextColor;
    }else {
        self.textLbl.textColor = [WKApp shared].config.messageRecvTextColor;
    }
   
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.textLbl.lim_width = self.messageContentView.lim_width;
    [self.textLbl sizeToFit];

}

@end
