// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMentionUserCell.m
//  WuKongBase
//
//  Created by tt on 2021/11/3.
//

#import "WKMentionUserCell.h"
#import "WKExternalViewerResolver.h"

@implementation WKMentionUserCellModel

+(instancetype) uid:(NSString*)uid  name:(NSString*)name avatarURL:(NSURL*)avatarURL robot:(BOOL)robot{
    return [self uid:uid name:name avatarURL:avatarURL robot:robot extras:nil];
}

+(instancetype) uid:(NSString*)uid name:(NSString*)name avatarURL:(NSURL*)avatarURL robot:(BOOL)robot extras:(NSDictionary*)extras {
    WKMentionUserCellModel *model = [WKMentionUserCellModel new];
    model.uid = uid;
    model.name = name;
    model.avatarURL = avatarURL;
    model.robot = robot;
    model.extras = extras;
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

    // @Mention 候选菜单外部成员 @SpaceName 标识。
    // 规则与 WKMemberCell () / Android RemindMemberAdapter 对齐：
    //   isExternal && sourceSpaceName.length > 0 → nameLbl.attributedText = baseName + 灰色 " @SpaceName"
    //   否则走 plain text，并把 attributedText 重置为 nil（attributedText 和
    //   text 在 UILabel 上互斥，不清理会残留上一次 render 的富文本 — 反复翻车的坑点）。
    NSString *baseName = model.name ?: @"";
    WKExternalResolveResult *res = [WKExternalViewerResolver resolveFromExtras:model.extras
                                                                 viewerSpaceId:[WKExternalViewerResolver currentViewerSpaceId]];
    if (res.isExternal && res.sourceSpaceName.length > 0) {
        self.nameLbl.attributedText = [self buildAttrWithBase:baseName spaceName:res.sourceSpaceName];
    } else {
        self.nameLbl.attributedText = nil;
        self.nameLbl.text = baseName;
    }

    [self.avatarImgView setUrl:model.avatarURL.absoluteString];
    if([model.uid isEqualToString:@"all"]) {
        self.avatarImgView.avatarImgView.image = [self imageName:@"Conversation/Panel/MentionAll"];
    }
    self.robotIdentityImgView.hidden = !model.robot;
}

// 昵称 + 灰色 " @SpaceName" 后缀，与 WKMemberCell 保持视觉一致（#999999 / 14pt）。
- (NSAttributedString *)buildAttrWithBase:(NSString *)baseName spaceName:(NSString *)spaceName {
    UIFont *nameFont = self.nameLbl.font ?: [[WKApp shared].config appFontOfSize:16.0f];
    UIColor *nameColor = self.nameLbl.textColor ?: [WKApp shared].config.defaultTextColor ?: [UIColor blackColor];
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:baseName
                                                                             attributes:@{NSFontAttributeName: nameFont,
                                                                                          NSForegroundColorAttributeName: nameColor}];
    UIColor *suffixColor = [UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0f];
    NSString *suffix = [NSString stringWithFormat:@" @%@", spaceName];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:suffix
                                                                 attributes:@{NSFontAttributeName: [[WKApp shared].config appFontOfSize:14.0f],
                                                                              NSForegroundColorAttributeName: suffixColor}]];
    return attr;
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
