//
//  WKMentionUserCell.m
//  WuKongBase
//
//  Created by tt on 2021/11/3.
//

#import "WKMentionUserCell.h"

@implementation WKMentionUserCellModel

+(instancetype) uid:(NSString*)uid  name:(NSString*)name avatarURL:(NSURL*)avatarURL robot:(BOOL)robot{
    WKMentionUserCellModel *model = [WKMentionUserCellModel new];
    model.uid = uid;
    model.name = name;
    model.avatarURL = avatarURL;
    model.robot = robot;
    return model;
}

- (NSString *)name {
    WKChannelInfo *channelInfo = [WKSDK.shared.channelManager getCache:[WKChannel personWithChannelID:self.uid]];
    if(channelInfo) {
        return channelInfo.displayName;
    }
    return _name;
}

+(instancetype) uid:(NSString*)uid name:(NSString*)name {
    return [self uid:uid name:name avatarURL:nil robot:false];
}

- (NSNumber *)showBottomLine {
    return @(0);
}

- (NSNumber *)showTopLine {
    return @(0);
}

@end

@interface WKMentionUserCell ()

@property(nonatomic,strong) WKUserAvatar *avatarImgView;

@property(nonatomic,strong) UILabel *nameLbl;

@property(nonatomic,strong) UIImageView *robotIdentityImgView;

@end

@implementation WKMentionUserCell

- (void)setupUI {
    [super setupUI];
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    [self addSubview:self.avatarImgView];
    [self addSubview:self.nameLbl];
    [self addSubview:self.robotIdentityImgView];
}

- (void)refresh:(WKMentionUserCellModel *)model {
    [super refresh:model];
    
    self.nameLbl.text = model.name;
    [self.avatarImgView setUrl:model.avatarURL.absoluteString];
    if([model.uid isEqualToString:@"all"]) {
        self.avatarImgView.avatarImgView.image = [self imageName:@"Conversation/Panel/MentionAll"];
    }
    self.robotIdentityImgView.hidden = !model.robot;
}


- (void)layoutSubviews{
    [super layoutSubviews];
    
    self.avatarImgView.lim_left = 10.0f;
    self.avatarImgView.lim_centerY_parent = self;
    
    [self.nameLbl sizeToFit];
    self.nameLbl.lim_left = self.avatarImgView.lim_right + 10.0f;
    self.nameLbl.lim_centerY_parent = self;
    
    self.robotIdentityImgView.lim_left = self.nameLbl.lim_right + 5.0f;
    self.robotIdentityImgView.lim_centerY_parent = self;
}

- (WKUserAvatar *)avatarImgView {
    if(!_avatarImgView) {
        CGSize avatarSize = [WKApp shared].config.smallAvatarSize;
        _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, avatarSize.width, avatarSize.height)];
    }
    return _avatarImgView;
}

- (UIImageView *)robotIdentityImgView {
    if(!_robotIdentityImgView) {
        _robotIdentityImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 16.0f, 16.0f)];
        _robotIdentityImgView.image = [self imageName:@"Common/Index/IconRobot"];
        _robotIdentityImgView.image = [_robotIdentityImgView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        
        [_robotIdentityImgView setTintColor:[WKApp shared].config.themeColor];
    }
    return _robotIdentityImgView;
}

- (UILabel *)nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
        _nameLbl.textColor = [WKApp shared].config.defaultTextColor;
        _nameLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
    }
    return _nameLbl;
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
