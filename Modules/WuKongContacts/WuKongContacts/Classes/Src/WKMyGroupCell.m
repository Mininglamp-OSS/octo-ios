//
//  WKMyGroupCell.m
//  WuKongContacts
//
//  Created by tt on 2020/7/16.
//

#import "WKMyGroupCell.h"

@class WKMyGroupCell;

@implementation WKMyGroupModel

- (Class)cell {
    return WKMyGroupCell.class;
}

- (NSNumber *)showArrow {
    return @(false);
}

@end

@interface WKMyGroupCell ()

@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UILabel *nameLbl;

@end

@implementation WKMyGroupCell

+ (CGSize)sizeForModel:(WKFormItemModel *)model {
    return CGSizeMake(WKScreenWidth, 66.0f);
}
- (void)setupUI {
    [super setupUI];
    [self.contentView addSubview:self.avatarImgView];
    [self.contentView addSubview:self.nameLbl];
    
}

- (WKUserAvatar *)avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[WKUserAvatar alloc] init];
    }
    return _avatarImgView;
}

- (UILabel *)nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
        [_nameLbl setFont:[[WKApp shared].config appFontOfSizeMedium:16.0f]];
    }
    return _nameLbl;
}

- (void)refresh:(WKMyGroupModel *)model {
    [super refresh:model];
    self.avatarImgView.url = [WKAvatarUtil getGroupAvatar:model.groupNo];
    self.nameLbl.text = model.name;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.avatarImgView.lim_left = 15.0f;
    self.avatarImgView.lim_top = self.lim_height/2.0f  - self.avatarImgView.lim_height/2.0f;
    
    self.nameLbl.lim_left = self.avatarImgView.lim_right +  15.0f;
    self.nameLbl.lim_width = self.lim_width - self.avatarImgView.lim_right - self.nameLbl.lim_left - 30.0f;
    self.nameLbl.lim_height = self.lim_height;
    self.nameLbl.lim_top = self.lim_height/2.0f - self.nameLbl.lim_height/2.0f;
}
@end
