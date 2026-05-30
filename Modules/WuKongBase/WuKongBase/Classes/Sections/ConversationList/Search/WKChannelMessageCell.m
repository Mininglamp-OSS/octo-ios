//
//  WKChannelMessageCell.m
//  WuKongBase
//
//  Created by tt on 2020/8/14.
//

#import "WKChannelMessageCell.h"
#import <SDWebImage/SDWebImage.h>
#import "WKApp.h"
#import "WKTimeTool.h"
@implementation WKChannelMessageModel

- (Class)cell {
    return WKChannelMessageCell.class;
}

- (NSNumber *)showArrow {
    return @(NO);
}

@end

@interface WKChannelMessageCell ()
@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UILabel *nameLbl;
@property(nonatomic,strong) UILabel *contentLbl;
@property(nonatomic,strong) UILabel *timestampLbl;
@end

@implementation WKChannelMessageCell

+ (CGSize)sizeForModel:(WKFormItemModel *)model {
    return CGSizeMake(WKScreenWidth, 48.0f + 10.0f + 10.0f);
}

- (void)setupUI {
    [super setupUI];
    
    // avatar
    self.avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 48.0f, 48.0f)];
    [self addSubview:self.avatarImgView];
    
    // name
    self.nameLbl = [[UILabel alloc] init];
    [self addSubview:self.nameLbl];
    
    // content
    self.contentLbl = [[UILabel alloc] init];
    [self.contentLbl setFont:[UIFont systemFontOfSize:14.0f]];
    [self.contentLbl setTextColor:[UIColor grayColor]];
    [self addSubview:self.contentLbl];
    
    // timestamp
    self.timestampLbl = [[UILabel alloc] init];
    [self.timestampLbl setFont:[UIFont systemFontOfSize:14.0f]];
    [self.timestampLbl setTextColor:[UIColor grayColor]];
    [self addSubview:self.timestampLbl];
}

- (void)refresh:(WKChannelMessageModel *)model {
    [super refresh:model];
    
    self.avatarImgView.url = model.avatar;
    self.nameLbl.text = model.name;
    // 显示完整时分秒；当年省略年份，避免同一天多条消息无法区分具体时刻
    self.timestampLbl.text = [WKTimeTool searchResultTimeString:[NSDate dateWithTimeIntervalSince1970:model.timestamp.doubleValue]];
    [self.timestampLbl sizeToFit];
    self.contentLbl.attributedText = nil;
    if(model.content && ![model.content isEqualToString:@""]) {
         NSMutableAttributedString *contentAttr = [[NSMutableAttributedString alloc] initWithString:model.content];
        if(model.keyword && ![model.keyword isEqualToString:@""]) {
            NSRange colorRange = [[model.content lowercaseString] rangeOfString:[model.keyword lowercaseString]];
            [contentAttr addAttribute:NSForegroundColorAttributeName value:[WKApp shared].config.themeColor range:colorRange];
        }
        self.contentLbl.attributedText = contentAttr;
    }
    
}


- (void)layoutSubviews {
    [super layoutSubviews];
    
    // avatar
    self.avatarImgView.lim_left = 20.0f;
    self.avatarImgView.lim_top = [self lim_centerY:self.avatarImgView];
    
    //time
    self.timestampLbl.lim_left = WKScreenWidth - self.timestampLbl.lim_width - 10.0f;
    self.timestampLbl.lim_top = self.avatarImgView.lim_top;
    
    // name（右侧给 timestamp 留出空间，避免完整日期时间与较长昵称重叠）
    CGFloat nameLeftSpace = 15.0f;
    CGFloat nameHeight = 20.0f;
    self.nameLbl.lim_left = self.avatarImgView.lim_right + nameLeftSpace;
    self.nameLbl.lim_width = self.timestampLbl.lim_left - 8.0f - self.nameLbl.lim_left;
    self.nameLbl.lim_height = nameHeight;

    self.nameLbl.lim_top = 10.0f;

    // content（内容行不与右侧时间同行，可占满到右边距）
    self.contentLbl.lim_width = self.lim_width - self.nameLbl.lim_left - 20.0f;
    self.contentLbl.lim_height = 15.0f;
    self.contentLbl.lim_left = self.nameLbl.lim_left;
    self.contentLbl.lim_top = self.nameLbl.lim_bottom + 10.0f;
}
@end
