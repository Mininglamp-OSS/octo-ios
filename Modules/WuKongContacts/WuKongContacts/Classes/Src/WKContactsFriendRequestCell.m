//
//  WKContactsFriendRequestCell.m
//  WuKongContacts
//
//  Created by tt on 2020/1/5.
//

#import "WKContactsFriendRequestCell.h"
#import "WKContactsManager.h"
#import "WKAvatarUtil.h"
@interface WKContactsFriendRequestCell ()
@property(nonatomic,strong) WKUserAvatar *avatarImgView; // 图标
@property(nonatomic,strong) UILabel *nameLbl; // 标题
@property(nonatomic,strong) UILabel *remarkLbl; // 备注
@property(nonatomic,strong) UIButton *okBtn; // 确认按钮

@property(nonatomic,strong) WKFriendRequestDBModel *model;

@end

@implementation WKContactsFriendRequestCell

-(void) setupUI {
    [super setupUI];
    self.bottomLineView.hidden = YES;
    self.avatarImgView = [[WKUserAvatar alloc] init];
    [self.contentView addSubview:self.avatarImgView];
    self.avatarImgView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onAvatarPressed)];
    [self.avatarImgView addGestureRecognizer:tap];
    
    self.nameLbl = [[UILabel alloc] init];
    [self.contentView addSubview:self.nameLbl];
    
    self.remarkLbl = [[UILabel alloc] init];
    [self.remarkLbl setFont:[UIFont systemFontOfSize:14.0f]];
    [self.remarkLbl setTextColor:[UIColor grayColor]];
    [self.contentView addSubview:self.remarkLbl];
    
    self.okBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60.0f, 30.0f)];
    [self.okBtn setBackgroundColor:[WKApp shared].config.themeColor];
    [self.okBtn.titleLabel setFont:[[WKApp shared].config appFontOfSize:15.0f]];
    self.okBtn.layer.masksToBounds = YES;
    self.okBtn.layer.cornerRadius = 4.0f;
    [self.okBtn setTitle:LLang(@"确认") forState:UIControlStateNormal];
    [self.okBtn addTarget:self action:@selector(onPassPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.okBtn];
}

-(void) onPassPressed {
    if(self.onPass) {
        self.onPass(self.model);
    }
}

-(void) onAvatarPressed {
    [[WKApp shared] invoke:WKPOINT_USER_INFO param:@{
        @"uid": self.model.uid,
    }];
}

-(void)refresh:(WKFriendRequestDBModel*)model {
    self.model = model;
    self.avatarImgView.url = [WKAvatarUtil getFullAvatarWIthPath:model.avatar];
    self.nameLbl.text = model.name;
    [self.nameLbl sizeToFit];
    self.remarkLbl.text = model.remark;
    [self.remarkLbl sizeToFit];
    
    if(model.status == WKFriendRequestStatusWaitSure) {
        self.okBtn.enabled = YES;
        [self.okBtn setTitle:LLang(@"确认") forState:UIControlStateNormal];
        [self.okBtn setBackgroundColor:[WKApp shared].config.themeColor];
    }else {
        self.okBtn.enabled = NO;
        [self.okBtn setTitle:LLang(@"已确认") forState:UIControlStateNormal];
        [self.okBtn setBackgroundColor:[[WKApp shared].config.themeColor colorWithAlphaComponent:0.5f]];
    }
}

-(void) layoutSubviews {
    [super layoutSubviews];
    
    self.avatarImgView.lim_left = 10.0f;
    self.avatarImgView.lim_top = self.lim_height/2.0f - self.avatarImgView.lim_height/2.0f;
    
    self.nameLbl.lim_top = 15.0f;
    self.nameLbl.lim_left = self.avatarImgView.lim_right + 10.0f;
    
    self.remarkLbl.lim_top = self.nameLbl.lim_bottom + 10.0f;
    self.remarkLbl.lim_left = self.nameLbl.lim_left;
    
    self.okBtn.lim_left = self.lim_width - self.okBtn.lim_width - 10.0f;
    self.okBtn.lim_top = self.lim_height/2.0f - self.okBtn.lim_height/2.0f;
    
//    if(self.last) {
//        self.bottomLineView.lim_left =  0;
//        self.bottomLineView.lim_width = self.lim_width;
//    }else {
//        self.bottomLineView.lim_left = self.nameLbl.lim_left;
//        self.bottomLineView.lim_width = self.lim_width - self.nameLbl.lim_left;
//    }
}

+ (NSString *)cellId {
    return @"WKContactsFriendRequestCell";
}
@end
