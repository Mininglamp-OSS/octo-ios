//
//  WKContactsCell.m
//  WuKongContacts
//
//  Created by tt on 2019/12/8.
//

#import "WKContactsCell.h"
#import "WKContacts.h"
#import <Masonry/Masonry.h>
#import <WuKongBase/WKOnlineBadgeView.h>
@implementation WKContactsCellModel


@end

@interface WKContactsCell()

@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UILabel *nameLbl;
@property(nonatomic,strong) UILabel *subtitleLbl;
@property(nonatomic,strong) WKContactsCellModel *contactModel;

@property(nonatomic,strong) WKOnlineBadgeView *onlineBadgeView; // 在线状态view

@end
@implementation WKContactsCell




-(void) setupUI{
    [super setupUI];
    self.topLineView.hidden = YES;
    self.bottomLineView.hidden = YES;
    
    CGFloat avatarWidth = 50.0f;
    CGFloat avatarheight = 50.0f;
    _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, avatarWidth, avatarheight)];
    [self.contentView addSubview:_avatarImgView];
    
    _nameLbl = [[UILabel alloc] init];
    [_nameLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
    [self.contentView addSubview:_nameLbl];
    
    
    _subtitleLbl = [[UILabel alloc] init];
    [_subtitleLbl setFont:[WKApp.shared.config appFontOfSize:12.0f]];
    [_subtitleLbl setTextColor:WKApp.shared.config.tipColor];
    [self.contentView addSubview:_subtitleLbl];
    
    [self.contentView addSubview:self.onlineBadgeView];
    
}

- (WKOnlineBadgeView *)onlineBadgeView {
    if(!_onlineBadgeView) {
        _onlineBadgeView = [WKOnlineBadgeView initWithTip:nil];
    }
    return _onlineBadgeView;
}

+(NSString*) cellId{
    return @"WKContactsCell";
}

- (void)refresh:(id)cellModel {
    [super refresh:cellModel];
    
    [self.nameLbl setTextColor:[WKApp shared].config.defaultTextColor];
    
    _contactModel = cellModel;
    [self.avatarImgView.avatarImgView lim_setImageWithURL:[NSURL URLWithString:_contactModel.avatar] placeholderImage:[WKApp shared].config.defaultAvatar];
    self.nameLbl.text = _contactModel.name;
    [self.nameLbl sizeToFit];
    
    self.subtitleLbl.hidden = YES;
    if(self.contactModel.channelInfo.lastOffline>0) {
        self.subtitleLbl.hidden = NO;
        self.subtitleLbl.text = [WKOnlineStatusManager.shared onlineStatusDetailTip:self.contactModel.channelInfo];
        [self.subtitleLbl sizeToFit];
    }
  
    
    self.onlineBadgeView.hidden = YES;
    if(_contactModel.online) {
         self.onlineBadgeView.hidden = NO;
        self.onlineBadgeView.tip = nil;
    }else if( [[NSDate date] timeIntervalSince1970] - _contactModel.lastOffline<60) {
        self.onlineBadgeView.hidden = NO;
                   self.onlineBadgeView.tip =LLang(@"刚刚");
    } else if(_contactModel.lastOffline+60*60>[[NSDate date] timeIntervalSince1970]) {
        self.onlineBadgeView.hidden = NO;
        self.onlineBadgeView.tip =[NSString stringWithFormat:LLang(@"%0.0f分钟"),([[NSDate date] timeIntervalSince1970]-_contactModel.lastOffline)/60];
    }
    
}


- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat nameLeft = 10.0f;
    CGFloat avatarLeft = 15.0f;
    // 头像
    self.avatarImgView.lim_left = avatarLeft;
    self.avatarImgView.lim_top = self.lim_height/2.0f - self.avatarImgView.lim_height/2.0f;
    
    // 在线状态
    if(self.contactModel.online) {
        self.onlineBadgeView.lim_left = self.avatarImgView.lim_right - self.onlineBadgeView.lim_width;
    }else{
        self.onlineBadgeView.lim_left = self.avatarImgView.lim_left + (self.avatarImgView.lim_width/2.0f - self.onlineBadgeView.lim_width/2.0f);
    }
    
    self.onlineBadgeView.lim_top = self.avatarImgView.lim_bottom - self.onlineBadgeView.lim_height;
    
    // 名字
    self.nameLbl.lim_left = self.avatarImgView.lim_right + nameLeft;
    
    
    if(self.subtitleLbl.hidden) {
        self.nameLbl.lim_top = self.lim_height/2.0f - self.nameLbl.lim_height/2.0f;
    }else{
        CGFloat subtitleTopSpace = 4.0f;
        self.nameLbl.lim_top = self.lim_height/2.0f - (self.nameLbl.lim_height+self.subtitleLbl.lim_height+subtitleTopSpace)/2.0f;
        
        self.subtitleLbl.lim_left = self.nameLbl.lim_left;
        self.subtitleLbl.lim_top = self.nameLbl.lim_bottom + subtitleTopSpace;
    }
    
    if(_contactModel.last) {
        self.bottomLineView.lim_left =  0;
        self.bottomLineView.lim_width = self.lim_width;
    }else {
        self.bottomLineView.lim_left = self.nameLbl.lim_left;
        self.bottomLineView.lim_width = self.lim_width - self.nameLbl.lim_left;
    }
}

@end
