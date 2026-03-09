//
//  WKMeAvatarCell.m
//  WuKongBase
//
//  Created by tt on 2020/6/23.
//

#import "WKMeAvatarCell.h"
#import "WKApp.h"
@implementation WKMeAvatarModel

- (Class)cell {
    return WKMeAvatarCell.class;
}

@end

@interface WKMeAvatarCell ()
@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@end

@implementation WKMeAvatarCell

+(CGSize) sizeForModel:(WKFormItemModel*)model{
    return CGSizeMake(WKScreenWidth, 84.0f);
}

- (void)setupUI {
    [super setupUI];
    
    [self.valueView addSubview:self.avatarImgView];
    
}

- (WKUserAvatar *)avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[WKUserAvatar alloc] init];
    }
    return _avatarImgView;
}

- (void)refresh:(WKMeAvatarModel*)cellModel {
    [super refresh:cellModel];
    [_avatarImgView setUrl:[WKAvatarUtil getAvatar:[WKApp shared].loginInfo.uid]];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.avatarImgView.lim_top = self.lim_height/2.0f - self.avatarImgView.lim_height/2.0f;
    self.avatarImgView.lim_left = self.valueView.lim_width - self.avatarImgView.lim_width;
}

@end
