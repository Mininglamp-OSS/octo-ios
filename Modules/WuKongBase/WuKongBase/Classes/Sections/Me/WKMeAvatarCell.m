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
    CGFloat h = model.cellHeight > 0 ? model.cellHeight : 52.0f;
    return CGSizeMake(WKScreenWidth, h);
}

- (void)setupUI {
    [super setupUI];

    self.avatarImgView.layer.cornerRadius = 8.0f;
    self.avatarImgView.layer.masksToBounds = YES;
    [self.valueView addSubview:self.avatarImgView];
}

- (WKUserAvatar *)avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, 32.0f, 32.0f)];
    }
    return _avatarImgView;
}

- (void)refresh:(WKMeAvatarModel*)cellModel {
    [super refresh:cellModel];
    WKChannel *channel = cellModel.extra;
    if (channel && [channel isKindOfClass:[WKChannel class]] && channel.channelType == WK_GROUP) {
        WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:channel];
        NSString *avatarURL;
        if (info.logo && [info.logo hasPrefix:@"http"]) {
            NSString *key = (info.avatarCacheKey.length > 0) ? info.avatarCacheKey : @"0";
            NSString *sep = [info.logo containsString:@"?"] ? @"&" : @"?";
            avatarURL = [NSString stringWithFormat:@"%@%@v=%@", info.logo, sep, key];
        } else {
            avatarURL = [WKAvatarUtil getGroupAvatar:channel.channelId cacheKey:info.avatarCacheKey];
        }
        [_avatarImgView setUrl:avatarURL];
    } else {
        WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:[WKApp shared].loginInfo.uid]];
        [_avatarImgView setUrl:[WKAvatarUtil getAvatar:[WKApp shared].loginInfo.uid cacheKey:info.avatarCacheKey]];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.avatarImgView.lim_top = self.lim_height/2.0f - self.avatarImgView.lim_height/2.0f;
    self.avatarImgView.lim_left = self.valueView.lim_width - self.avatarImgView.lim_width;
}

@end
