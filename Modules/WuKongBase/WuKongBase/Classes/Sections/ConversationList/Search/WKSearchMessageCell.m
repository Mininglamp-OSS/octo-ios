//
//  WKSearchMessageCell.m
//  WuKongBase
//
//  Created by tt on 2020/5/10.
//

#import "WKSearchMessageCell.h"
#import <SDWebImage/SDWebImage.h>
#import "WKApp.h"
#import "WuKongBase.h"
@implementation WKSearchMessageModel

- (Class)cell {
    return WKSearchMessageCell.class;
}

- (NSNumber *)showArrow {
    return @(NO);
}

@end

@interface WKSearchMessageCell ()

@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UILabel *nameLbl;
@property(nonatomic,strong) UILabel *contentLbl;
@property(nonatomic,strong) UILabel *timeLbl;

@end

@implementation WKSearchMessageCell

+ (CGSize)sizeForModel:(WKFormItemModel *)model {
    return CGSizeMake(WKScreenWidth, WKDefaultAvatarSize.height + 10.0f + 10.0f);
}

- (void)setupUI {
    [super setupUI];
    
    // avatar
    self.avatarImgView = [[WKUserAvatar alloc] init];
    [self addSubview:self.avatarImgView];
    
    // name
    self.nameLbl = [[UILabel alloc] init];
    [self addSubview:self.nameLbl];
    
    // content
    self.contentLbl = [[UILabel alloc] init];
    [self.contentLbl setFont:[WKApp.shared.config appFontOfSize:14.0f]];
    [self.contentLbl setTextColor:[UIColor grayColor]];
    [self addSubview:self.contentLbl];
    
    // time
    self.timeLbl = [[UILabel alloc] init];
    [self.timeLbl setFont:[WKApp.shared.config appFontOfSize:12.0f]];
    [self.timeLbl setTextColor:[UIColor grayColor]];
    [self addSubview:self.timeLbl];
}

- (void)refresh:(WKSearchMessageModel *)model {
    [super refresh:model];
    
    NSString *avatar = @"";
    NSString *name = @"";
    
    WKChannelInfo *channelInfo = [WKSDK.shared.channelManager getChannelInfo:model.channel];
    if(channelInfo) {
        avatar = [WKApp.shared getImageFullUrl:channelInfo.logo].absoluteString;
        name = channelInfo.displayName;
    }else {
        [WKSDK.shared.channelManager fetchChannelInfo:model.channel];
    }
    
    self.avatarImgView.url = avatar;
    self.nameLbl.text = name;
    self.contentLbl.attributedText = nil;
    if(model.content && ![model.content isEqualToString:@""]) {
        self.contentLbl.attributedText = [self highlightText:model.content];
    }else {
        self.contentLbl.text = [NSString stringWithFormat:LLang(@"%d 条相关聊天记录"),[model.messageCount intValue]];
    }
    
    self.timeLbl.text = [WKTimeTool getTimeStringAutoShort2:[NSDate dateWithTimeIntervalSince1970:model.timestamp] mustIncludeTime:true];
    [self.timeLbl sizeToFit];
    
}

-(NSMutableAttributedString*)  highlightText:(NSString*)text {
    NSMutableAttributedString* attributedString = [[NSMutableAttributedString alloc] initWithString:text];
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"<mark>(.*?)</mark>" options:NSRegularExpressionCaseInsensitive error:nil];
    
    NSArray* matches = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    
    for (NSTextCheckingResult* match in [matches reverseObjectEnumerator]) {
        NSRange contentRange = [match rangeAtIndex:1];
        NSString* content = [text substringWithRange:contentRange]; // 提取内容
        NSAttributedString* highlightedString = [[NSAttributedString alloc] initWithString:content attributes:@{NSForegroundColorAttributeName: WKApp.shared.config.themeColor}];
        // 替换 <mark> 标签部分，并保留属性
        [attributedString replaceCharactersInRange:[match range] withAttributedString:highlightedString];
    }
    
    return attributedString;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // avatar
    self.avatarImgView.lim_left = 20.0f;
    self.avatarImgView.lim_top = [self lim_centerY:self.avatarImgView];
    
    
    // name
    CGFloat nameLeftSpace = 15.0f;
    CGFloat nameHeight = 20.0f;
    self.nameLbl.lim_width = self.lim_width -( self.avatarImgView.lim_right + nameLeftSpace + 20.0f);
    self.nameLbl.lim_height = nameHeight;
    self.nameLbl.lim_left = self.avatarImgView.lim_right + nameLeftSpace;
    
    self.nameLbl.lim_top = 10.0f;
    
    // content
    self.contentLbl.lim_width = self.nameLbl.lim_width;
    self.contentLbl.lim_height = 15.0f;
    self.contentLbl.lim_left = self.nameLbl.lim_left;
    self.contentLbl.lim_top = self.nameLbl.lim_bottom + 10.0f;
    
    self.timeLbl.lim_top = self.nameLbl.lim_top;
    self.timeLbl.lim_left = self.lim_width - self.timeLbl.lim_width - 10.0f;
}

@end
