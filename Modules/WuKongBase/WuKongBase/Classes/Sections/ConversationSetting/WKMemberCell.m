//
//  WKMemberCell.m
//  WuKongBase
//
//  Created by tt on 2022/8/31.
//

#import "WKMemberCell.h"
#import "WuKongBase.h"
#import "WKOnlineBadgeView.h"
@interface WKMemberCell ()<WKCheckBoxDelegate>

@property(nonatomic,strong) WKUserAvatar *avatar;

@property(nonatomic,strong) UILabel *nameLbl;

@property(nonatomic,strong) WKCheckBox *checkBox;

@property(nonatomic,strong) WKOnlineBadgeView *onlineBadgeView;

@property(nonatomic,strong) UILabel *botBadgeLbl; // AI标识
@property(nonatomic,strong) UILabel *externalBadgeLbl; // 外部成员标识
@property(nonatomic,strong) UILabel *sourceSpaceLbl; // 来自 {source_space_name}

@property(nonatomic,strong) WKUserOnlineResp *online;

@end

@implementation WKMemberCell

- (void)setupUI {
    [super setupUI];

    [self.contentView addSubview:self.checkBox];
    [self.contentView addSubview:self.avatar];
    [self.contentView addSubview:self.nameLbl];
    [self.contentView addSubview:self.botBadgeLbl];
    [self.contentView addSubview:self.externalBadgeLbl];
    [self.contentView addSubview:self.sourceSpaceLbl];
    [self.avatar addSubview:self.onlineBadgeView];
}

- (void)refresh:(WKChannelMember*)member checkOn:(BOOL)checkOn online:(WKUserOnlineResp*)online{
    self.online = online;
    self.nameLbl.text = [self getName:member];
    
    self.avatar.url =  [WKApp.shared getImageFullUrl:member.memberAvatar].absoluteString;
    
    self.checkBox.hidden = !self.edit;
    self.checkBox.on = checkOn;
    
    [self.checkBox setEnabled:YES];
    if(self.disable) {
        [self.checkBox setEnabled:NO];
        self.contentView.alpha = 0.5f;
    }else{
        self.contentView.alpha = 1.0f;
    }
    
    
    // AI标识
    self.botBadgeLbl.hidden = !member.robot;
    if(member.robot) {
        [self.botBadgeLbl sizeToFit];
        CGRect frame = self.botBadgeLbl.frame;
        frame.size.width += 8.0f;
        frame.size.height += 4.0f;
        self.botBadgeLbl.frame = frame;
    }

    // 外部成员标识 + 来源 space
    BOOL isExternal = NO;
    if(member.extra && member.extra[@"is_external"]) {
        isExternal = [member.extra[@"is_external"] integerValue] == 1;
    }
    self.externalBadgeLbl.hidden = !isExternal;
    if(isExternal) {
        [self.externalBadgeLbl sizeToFit];
        CGRect frame = self.externalBadgeLbl.frame;
        frame.size.width += 8.0f;
        frame.size.height += 4.0f;
        self.externalBadgeLbl.frame = frame;
    }
    NSString *sourceSpaceName = nil;
    if(isExternal && member.extra && member.extra[@"source_space_name"]) {
        sourceSpaceName = member.extra[@"source_space_name"];
    }
    if(sourceSpaceName && sourceSpaceName.length > 0) {
        self.sourceSpaceLbl.hidden = NO;
        self.sourceSpaceLbl.text = [NSString stringWithFormat:LLang(@"来自 %@"), sourceSpaceName];
    } else {
        self.sourceSpaceLbl.hidden = YES;
        self.sourceSpaceLbl.text = nil;
    }

    self.onlineBadgeView.hidden = YES;
    if(online) {
        if(!online.online) {
            if ([[NSDate date] timeIntervalSince1970] - online.lastOffline<60) {
                self.onlineBadgeView.hidden = NO;
                           self.onlineBadgeView.tip = LLang(@"刚刚");
            }else if( online.lastOffline+60*60>[[NSDate date] timeIntervalSince1970]) {
                self.onlineBadgeView.hidden = NO;
                self.onlineBadgeView.tip =[NSString stringWithFormat:LLang(@"%0.0f分钟"),([[NSDate date] timeIntervalSince1970]-online.lastOffline)/60];
            }
        }else {
            self.onlineBadgeView.hidden = NO;
            self.onlineBadgeView.tip = nil;
        }
        
    }else {
        self.onlineBadgeView.hidden = YES;
        self.onlineBadgeView.tip = nil;
    }
    
}

-(NSString*) getName:(WKChannelMember*)member {
    WKChannelInfo *channelInfo = [WKSDK.shared.channelManager getCache:[WKChannel personWithChannelID:member.memberUid]];
    
    NSString *name;
    if(channelInfo && channelInfo.remark && ![channelInfo.remark isEqualToString:@""]) {
        name = channelInfo.remark;
    }
    if(!name) {
        name = member.displayName;
    }
    return name;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat leftSpace = 15.0f;
    CGFloat checkBoxRight = 0.0f;
    if(!self.checkBox.hidden) {
        self.checkBox.lim_left = leftSpace;
        self.checkBox.lim_centerY_parent = self.contentView;
        checkBoxRight = self.checkBox.lim_right;
    }

    self.avatar.lim_left = checkBoxRight + leftSpace;
    self.avatar.lim_centerY_parent = self.contentView;

    BOOL hasSourceSpace = !self.sourceSpaceLbl.hidden && self.sourceSpaceLbl.text.length > 0;

    self.nameLbl.lim_left = self.avatar.lim_right + leftSpace;
    if(hasSourceSpace) {
        // 双行布局：name 在上半区，sourceSpace 在下半区
        CGFloat nameH = 22.0f;
        CGFloat sourceH = 16.0f;
        CGFloat totalH = nameH + sourceH + 2.0f;
        CGFloat topPadding = MAX((self.contentView.lim_height - totalH) / 2.0f, 0.0f);
        self.nameLbl.lim_height = nameH;
        self.nameLbl.lim_top = topPadding;
    } else {
        self.nameLbl.lim_height = self.contentView.lim_height;
        self.nameLbl.lim_top = 0.0f;
    }
    self.nameLbl.lim_width = self.contentView.lim_width - self.nameLbl.lim_left - 40.0f;

    // 名字右侧的 badge：AI / 外部，可能同时存在，依次排列
    CGFloat textWidth = 0.0f;
    if(self.nameLbl.text.length > 0 && self.nameLbl.font) {
        textWidth = [self.nameLbl.text sizeWithAttributes:@{NSFontAttributeName: self.nameLbl.font}].width;
    }
    CGFloat badgeLeft = self.nameLbl.lim_left + MIN(textWidth, self.nameLbl.lim_width) + 6.0f;
    CGFloat badgeCenterY = hasSourceSpace ? (self.nameLbl.lim_top + self.nameLbl.lim_height / 2.0f) : (self.contentView.lim_height / 2.0f);
    if(!self.botBadgeLbl.hidden) {
        self.botBadgeLbl.lim_left = badgeLeft;
        self.botBadgeLbl.lim_top = badgeCenterY - self.botBadgeLbl.lim_height / 2.0f;
        badgeLeft = self.botBadgeLbl.lim_right + 4.0f;
    }
    if(!self.externalBadgeLbl.hidden) {
        self.externalBadgeLbl.lim_left = badgeLeft;
        self.externalBadgeLbl.lim_top = badgeCenterY - self.externalBadgeLbl.lim_height / 2.0f;
    }

    // 来源 space 子标题
    if(hasSourceSpace) {
        self.sourceSpaceLbl.lim_left = self.nameLbl.lim_left;
        self.sourceSpaceLbl.lim_top = self.nameLbl.lim_bottom + 2.0f;
        self.sourceSpaceLbl.lim_width = self.nameLbl.lim_width;
        self.sourceSpaceLbl.lim_height = 16.0f;
    }

    // 在线标记
    if(self.online && self.online.online) {
        self.onlineBadgeView.lim_left = self.avatar.lim_width - self.onlineBadgeView.lim_width;
    }else {
        self.onlineBadgeView.lim_left = self.avatar.lim_width - self.onlineBadgeView.lim_width + 4.0f;
    }
    self.onlineBadgeView.lim_top = self.avatar.lim_height - self.onlineBadgeView.lim_height;
}

- (WKOnlineBadgeView *)onlineBadgeView {
    if(!_onlineBadgeView) {
        _onlineBadgeView = [WKOnlineBadgeView initWithTip:nil];
    }
    return _onlineBadgeView;
}

- (WKUserAvatar *)avatar {
    if(!_avatar) {
        _avatar = [[WKUserAvatar alloc] init];
    }
    return _avatar;
}

- (UILabel *)nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
        _nameLbl.font = [WKApp.shared.config appFontOfSize:16.0f];
    }
    return _nameLbl;
}

- (UILabel *)botBadgeLbl {
    if(!_botBadgeLbl) {
        _botBadgeLbl = [[UILabel alloc] init];
        _botBadgeLbl.text = @"AI";
        _botBadgeLbl.font = [[WKApp shared].config appFontOfSize:10.0f];
        _botBadgeLbl.textColor = [UIColor whiteColor];
        _botBadgeLbl.backgroundColor = [UIColor colorWithRed:136.0f/255.0f green:84.0f/255.0f blue:208.0f/255.0f alpha:1.0f];
        _botBadgeLbl.textAlignment = NSTextAlignmentCenter;
        _botBadgeLbl.layer.cornerRadius = 4.0f;
        _botBadgeLbl.layer.masksToBounds = YES;
        _botBadgeLbl.hidden = YES;
    }
    return _botBadgeLbl;
}

- (UILabel *)externalBadgeLbl {
    if(!_externalBadgeLbl) {
        _externalBadgeLbl = [[UILabel alloc] init];
        _externalBadgeLbl.text = LLang(@"外部");
        _externalBadgeLbl.font = [[WKApp shared].config appFontOfSize:10.0f];
        _externalBadgeLbl.textColor = [UIColor whiteColor];
        _externalBadgeLbl.backgroundColor = [UIColor colorWithRed:136.0f/255.0f green:84.0f/255.0f blue:208.0f/255.0f alpha:1.0f];
        _externalBadgeLbl.textAlignment = NSTextAlignmentCenter;
        _externalBadgeLbl.layer.cornerRadius = 4.0f;
        _externalBadgeLbl.layer.masksToBounds = YES;
        _externalBadgeLbl.hidden = YES;
    }
    return _externalBadgeLbl;
}

- (UILabel *)sourceSpaceLbl {
    if(!_sourceSpaceLbl) {
        _sourceSpaceLbl = [[UILabel alloc] init];
        _sourceSpaceLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
        _sourceSpaceLbl.textColor = [UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0f];
        _sourceSpaceLbl.hidden = YES;
    }
    return _sourceSpaceLbl;
}

- (WKCheckBox *)checkBox {
    if(!_checkBox) {
        _checkBox = [[WKCheckBox alloc] initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
        _checkBox.onFillColor = [WKApp shared].config.themeColor;
        _checkBox.onCheckColor = [UIColor whiteColor];
        _checkBox.onAnimationType = BEMAnimationTypeBounce;
        _checkBox.offAnimationType = BEMAnimationTypeBounce;
        _checkBox.animationDuration = 0.0f;
        _checkBox.lineWidth = 1.0f;
    //    self.checkBox.tintColor = [UIColor grayColor];
        _checkBox.delegate = self;
    }
    return _checkBox;
}

- (void)didTapCheckBox:(WKCheckBox*)checkBox {
    if(self.onCheck) {
        self.onCheck(checkBox.on);
    }
}

@end
