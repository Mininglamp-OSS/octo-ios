//
//  WKContactsHeaderItemCell.m
//  WuKongContacts
//
//  Created by tt on 2020/1/4.
//

#import "WKContactsHeaderItemCell.h"
#import "WKBadgeView.h"
@interface WKContactsHeaderItemCell ()

@property(nonatomic,strong) WKImageView *icon; // 图标

@property(nonatomic,strong) UILabel *titleLbl; // 标题

@property(nonatomic,strong) WKBadgeView *badgeView; // 红点

@property(nonatomic,strong) UIImageView *avatarImgView; // 头像
@property(nonatomic,strong) WKBadgeView *avatarReddotView;  // 头像红点

@end

@implementation WKContactsHeaderItemCell

-(void) setupUI {
    self.icon = [[WKImageView alloc] initWithFrame:CGRectMake(0, 0, 50.0f, 50.0f)];
    self.titleLbl = [[UILabel alloc] init];
    [self.titleLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
   
    [self.contentView addSubview:self.icon];
    [self.contentView addSubview:self.titleLbl];
    [self.contentView addSubview:self.avatarImgView];
    self.badgeView = [WKBadgeView viewWithoutBadgeTip];
    self.avatarReddotView = [WKBadgeView viewWithoutBadgeTip];
    [self.contentView addSubview:self.avatarReddotView];
    [self.contentView addSubview:self.badgeView];
}

-(void)refresh:(WKContactsHeaderItem*)model {
    [super refresh:model];
    
    [self setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    
    [self.titleLbl setTextColor:[WKApp shared].config.defaultTextColor];
    
    if( model.icon && ([model.icon hasPrefix:@"http"] || [ model.icon hasPrefix:@"https"])) {
        [self.icon loadImage:[NSURL URLWithString:model.icon]];
    }else {
        self.icon.image = [[WKApp shared] loadImage:model.icon moduleID:model.moduleID];
    }
    self.titleLbl.text = model.title;
    [self.titleLbl sizeToFit];
    self.badgeView.badgeValue  = @"";
    if(model.badgeValue && ![model.badgeValue isEqualToString:@""]) {
        self.badgeView.badgeValue = model.badgeValue;
        self.badgeView.hidden = NO;
    }else {
        self.badgeView.hidden = YES;
    }
    self.avatarImgView.hidden = YES;
    self.avatarReddotView.hidden = YES;
    if(model.avatarURL && ![model.avatarURL isEqualToString:@""]) {
        self.avatarImgView.hidden = NO;
        self.avatarReddotView.hidden = NO;
        self.avatarReddotView.badgeValue = @"";
        [self.avatarImgView lim_setImageWithURL:[NSURL URLWithString:model.avatarURL] placeholderImage:[WKApp.shared config].defaultAvatar];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.icon.lim_left = 15.0f;
    self.icon.lim_top = self.lim_height/2.0f - self.icon.lim_height/2.0f;
    self.titleLbl.lim_left = self.icon.lim_right + 10.0f;
    self.titleLbl.lim_top = self.lim_height/2.0f - self.titleLbl.lim_height/2.0f;
    self.badgeView.lim_left = self.titleLbl.lim_left + self.titleLbl.lim_width + 10.0f;
    self.badgeView.lim_top = self.lim_height/2.0f - self.badgeView.lim_height/2.0f;
    
    self.avatarImgView.lim_centerY_parent = self.contentView;
    self.avatarImgView.lim_left = self.contentView.lim_width - self.avatarImgView.lim_width - 20.0f;
    
    self.avatarReddotView.lim_left = self.avatarImgView.lim_left+self.avatarImgView.lim_width - self.avatarReddotView.lim_width/2.0f;
    self.avatarReddotView.lim_top =  self.avatarImgView.lim_top + 2.0f;
    
}

- (UIImageView *)avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        _avatarImgView.layer.masksToBounds = YES;
        _avatarImgView.layer.cornerRadius = _avatarImgView.lim_height/2.0f;
    }
    return _avatarImgView;
}



+ (NSString *)cellId {
    return @"WKContactsHeaderItemCell";
}

@end
