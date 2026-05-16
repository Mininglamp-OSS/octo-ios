//
//  WKContactsFriendCell.m
//  WuKongContacts
//
//  Created by tt on 2021/9/22.
//

#import "WKContactsFriendCell.h"
#import "WKUserColorUtil.h"

@implementation WKContactsFriendModel



@end

@interface WKContactsFriendCell ()

@property(nonatomic,strong) UILabel *firstNameLbl;

@property(nonatomic,strong) UILabel *phoneLbl;

@property(nonatomic,strong) WKContactsFriendModel *contactsFriendModel;

@property(nonatomic,strong) UIButton *actionBtn;


@end

@implementation WKContactsFriendCell

-(void) setupUI{
    [super setupUI];
    
    [self.avatarImgView addSubview:self.firstNameLbl];
    [self.contentView addSubview:self.phoneLbl];
    [self.contentView addSubview:self.actionBtn];
    
}


-(void) refreshWithModel:(id)cellModel {
    [super refreshWithModel:cellModel];
    self.contactsFriendModel = cellModel;
    
    if(self.contactSelectModel.uid && ![self.contactSelectModel.uid isEqualToString:@""]) {
        self.firstNameLbl.hidden = YES;
        self.avatarImgView.url = [WKAvatarUtil getAvatar:self.contactSelectModel.uid];
    }else{
        self.firstNameLbl.hidden = NO;
        self.avatarImgView.avatarImgView.image = nil;
        [self.avatarImgView setBackgroundColor:[WKUserColorUtil userColor:self.contactSelectModel.name]];
        self.firstNameLbl.text = [self.contactSelectModel.name substringToIndex:1];
        [self.firstNameLbl sizeToFit];
    }
    
    [self.actionBtn setBackgroundColor:[WKApp shared].config.themeColor];
    [self.actionBtn setEnabled:YES];
    if(self.contactsFriendModel.isFriend) {
        [self.actionBtn setTitle:LLang(@"已添加") forState:UIControlStateNormal];
        [self.actionBtn setEnabled:NO];
        [self.actionBtn setBackgroundColor:[WKApp shared].config.tipColor];
    }else if(self.contactsFriendModel.vercode && ![self.contactsFriendModel.vercode isEqualToString:@""]){
        [self.actionBtn setTitle:LLang(@"添加") forState:UIControlStateNormal];
    }else{
        [self.actionBtn setTitle:LLang(@"邀请") forState:UIControlStateNormal];
    }
    if([self.contactsFriendModel.uid isEqualToString:WKApp.shared.loginInfo.uid]) {
        self.actionBtn.hidden = YES;
    }else{
        self.actionBtn.hidden = NO;
    }
    
    self.phoneLbl.text = self.contactsFriendModel.phone;
    [self.phoneLbl sizeToFit];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.firstNameLbl.lim_size = self.avatarImgView.lim_size;
    self.actionBtn.lim_centerY_parent = self.contentView;
    self.actionBtn.lim_left = self.contentView.lim_width - self.actionBtn.lim_width - 20.0f;
    
    CGFloat phoneTopSpace = 2.0f;
    
   CGFloat contentHeight = self.nameLbl.lim_height + phoneTopSpace + self.phoneLbl.lim_height;
    
    self.nameLbl.lim_top = self.contentView.lim_height/2.0f - contentHeight/2.0f;
    
    self.phoneLbl.lim_top = self.nameLbl.lim_bottom + phoneTopSpace;
    self.phoneLbl.lim_left = self.nameLbl.lim_left;
}

- (UILabel *)firstNameLbl {
    if(!_firstNameLbl) {
        _firstNameLbl = [[UILabel alloc] init];
        _firstNameLbl.font = [[WKApp shared].config appFontOfSizeSemibold:25.0f];
        _firstNameLbl.textColor = [UIColor whiteColor];
        _firstNameLbl.textAlignment = NSTextAlignmentCenter;
    }
    return _firstNameLbl;
}

- (UILabel *)phoneLbl {
    if(!_phoneLbl) {
        _phoneLbl = [[UILabel alloc] init];
        _phoneLbl.textColor = [WKApp shared].config.tipColor;
        _phoneLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
    }
    return _phoneLbl;
}

- (UIButton *)actionBtn {
    if(!_actionBtn) {
        _actionBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 60.0f, 30.0f)];
        [[_actionBtn titleLabel] setFont:[[WKApp shared].config appFontOfSize:14.0f]];
        _actionBtn.layer.masksToBounds = YES;
        _actionBtn.layer.cornerRadius = 12.0f;
        [_actionBtn addTarget:self action:@selector(actionPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _actionBtn;
}

-(void) actionPressed {
    if(self.delegate && [self.delegate respondsToSelector:@selector(contactsFriendCell:action:)]) {
        [self.delegate contactsFriendCell:self action:self.contactsFriendModel];
    }
}




@end
