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

@property(nonatomic,strong) WKUserOnlineResp *online;

@end

@implementation WKMemberCell

- (void)setupUI {
    [super setupUI];
    
    [self.contentView addSubview:self.checkBox];
    [self.contentView addSubview:self.avatar];
    [self.contentView addSubview:self.nameLbl];
    [self.contentView addSubview:self.botBadgeLbl];
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
    
    self.nameLbl.lim_left = self.avatar.lim_right + leftSpace;
    self.nameLbl.lim_height = self.contentView.lim_height;
    self.nameLbl.lim_width = self.contentView.lim_width - self.nameLbl.lim_left - 40.0f;

    // AI标识
    if(!self.botBadgeLbl.hidden) {
        CGFloat textWidth = [self.nameLbl.text sizeWithAttributes:@{NSFontAttributeName: self.nameLbl.font}].width;
        self.botBadgeLbl.lim_left = self.nameLbl.lim_left + textWidth + 6.0f;
        self.botBadgeLbl.lim_centerY_parent = self.contentView;
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
