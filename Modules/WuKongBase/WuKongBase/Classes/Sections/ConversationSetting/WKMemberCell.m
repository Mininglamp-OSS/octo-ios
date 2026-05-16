// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMemberCell.m
//  WuKongBase
//
//  Created by tt on 2022/8/31.
//

#import "WKMemberCell.h"
#import "WuKongBase.h"
#import "WKOnlineBadgeView.h"
#import "WKExternalViewerResolver.h"
#import "WKChannelUtil.h"
#import "WKRealnamePrefetcher.h"
@interface WKMemberCell ()<WKCheckBoxDelegate>

@property(nonatomic,strong) WKUserAvatar *avatar;

@property(nonatomic,strong) UILabel *nameLbl;

@property(nonatomic,strong) WKCheckBox *checkBox;

@property(nonatomic,strong) WKOnlineBadgeView *onlineBadgeView;

@property(nonatomic,strong) UILabel *botBadgeLbl; // AI标识

// 实名认证 ✓ 迷你徽章（/ Phase A）
// 12×12 pt 蓝勾，显示在昵称右侧 padding.left = 2pt；未实名隐藏，不加任何灰标。
@property(nonatomic,strong) UIImageView *realnameVerifiedImgView;

@property(nonatomic,strong) WKUserOnlineResp *online;

@end

@implementation WKMemberCell

- (void)setupUI {
    [super setupUI];

    [self.contentView addSubview:self.checkBox];
    [self.contentView addSubview:self.avatar];
    [self.contentView addSubview:self.nameLbl];
    [self.contentView addSubview:self.realnameVerifiedImgView];
    [self.contentView addSubview:self.botBadgeLbl];
    [self.avatar addSubview:self.onlineBadgeView];
}

- (void)refresh:(WKChannelMember*)member checkOn:(BOOL)checkOn online:(WKUserOnlineResp*)online{
    self.online = online;

    // v2 外部群：昵称后追加灰色「@SpaceName」内联后缀（/ web PR #1013 对齐）
    // 取代 v1 紫色「外部」Tag + 「来自 XX」副标题。判定走 viewer-relative。
    NSString *baseName = [self getName:member] ?: @"";
    NSString *viewerSpaceId = [WKExternalViewerResolver currentViewerSpaceId];
    WKExternalResolveResult *ext = [WKExternalViewerResolver resolveFromExtras:member.extra
                                                                 viewerSpaceId:viewerSpaceId];
    NSString *suffix = @"";
    if (ext.isExternal && ext.sourceSpaceName.length > 0) {
        // 自己查自己豁免：群成员列表里自己也可能显示 @Space，但当前用户与
        // home=当前 viewerSpaceId 匹配时 isExternal 已是 NO；无需额外判定。
        // viewerSpaceId 为空（未选空间）时 resolver 返回 isExternal=YES，但
        // 这种场景 sourceSpaceName 仍可显示，语义与 web 一致。
        //
        // : 对齐 android PR#141 () 换行方案 — @SpaceName 前
        // 插入 `\n` 强制换到第二行，避免长 baseName + @SpaceName 被 tail
        // truncate 折断（企微样式）。
        suffix = [NSString stringWithFormat:@"\n@%@", ext.sourceSpaceName];
    }
    if (suffix.length > 0) {
        // 多行 + word wrapping 以容纳第二行 @SpaceName
        self.nameLbl.numberOfLines = 2;
        self.nameLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:baseName
                                                                                attributes:@{NSFontAttributeName: self.nameLbl.font ?: [[WKApp shared].config appFontOfSize:16.0f],
                                                                                             NSForegroundColorAttributeName: [WKApp shared].config.defaultTextColor ?: [UIColor blackColor]}];
        UIColor *suffixColor = [UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0f];
        [attr appendAttributedString:[[NSAttributedString alloc] initWithString:suffix
                                                                     attributes:@{NSFontAttributeName: [[WKApp shared].config appFontOfSize:14.0f],
                                                                                  NSForegroundColorAttributeName: suffixColor}]];
        self.nameLbl.attributedText = attr;
    } else {
        // 非外部成员：保持单行显示（避免影响常规群布局）
        self.nameLbl.numberOfLines = 1;
        self.nameLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        self.nameLbl.attributedText = nil;
        self.nameLbl.text = baseName;
    }

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

    // 实名认证 ✓ 徽章（/ Phase A）
    // Tri-state fallback（P1-2）：仅在 member.extra 字段缺失（nil）时才
    // 回退到 person cache；显式 @NO 直接视为未实名，避免 stale person cache 给
    // 已取消实名的用户错误打勾。
    NSNumber *memberFlag = [WKChannelUtil isRealnameVerifiedFromExtra:member.extra];
    BOOL verified;
    if (memberFlag == nil) {
        WKChannelInfo *personInfo = [WKSDK.shared.channelManager getCache:[WKChannel personWithChannelID:member.memberUid]];
        NSNumber *personFlag = [WKChannelUtil isRealnameVerifiedFromExtra:personInfo.extra];
        verified = personFlag.boolValue; // nil 或 @NO → NO
    } else {
        verified = memberFlag.boolValue;
    }
    self.realnameVerifiedImgView.hidden = !verified;

    // ：未确认已实名时（member 显式 @NO 或两侧都缺数据），后台拉一次
    // /users/<uid> 把 person 缓存补齐，回写后 channelInfoUpdate 会驱动重刷。
    if(!verified && member.memberUid.length > 0) {
        [WKRealnamePrefetcher ensureFetched:member.memberUid];
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

    // v2 单行布局：昵称+「 @SpaceName」后缀已内联在 nameLbl.attributedText 里
    self.nameLbl.lim_left = self.avatar.lim_right + leftSpace;
    self.nameLbl.lim_height = self.contentView.lim_height;
    self.nameLbl.lim_top = 0.0f;

    // ：长昵称场景必须保证实名 / AI 徽章不被挤掉。
    // 先把要显示的 badge 总占用宽度算出来，nameLbl.lim_width 预留好这部分，
    // UILabel 默认 NSLineBreakByTruncatingTail 会自动 ... 截断。
    CGFloat rightSafePad = 15.0f;        // cell 末尾基础右边距
    CGFloat badgesWidth = 0.0f;
    CGFloat realnameBadgeW = 0.0f;
    if (!self.realnameVerifiedImgView.hidden) {
        realnameBadgeW = 12.0f;
        badgesWidth += realnameBadgeW + 2.0f; // 2pt gap from name
    }
    CGFloat botBadgeW = 0.0f;
    if (!self.botBadgeLbl.hidden) {
        botBadgeW = self.botBadgeLbl.lim_width;
        badgesWidth += botBadgeW + 6.0f;      // 6pt gap from前一个
    }
    CGFloat maxNameW = self.contentView.lim_width - self.nameLbl.lim_left - badgesWidth - rightSafePad;
    if (maxNameW < 0) maxNameW = 0;
    self.nameLbl.lim_width = maxNameW;

    // 名字右侧 badge 起点：用真实文本宽度（小于 lim_width 时贴紧），溢出时取 lim_right。
    CGFloat textWidth = 0.0f;
    if (self.nameLbl.attributedText.length > 0) {
        textWidth = [self.nameLbl.attributedText size].width;
    } else if(self.nameLbl.text.length > 0 && self.nameLbl.font) {
        textWidth = [self.nameLbl.text sizeWithAttributes:@{NSFontAttributeName: self.nameLbl.font}].width;
    }
    CGFloat afterNameRight = self.nameLbl.lim_left + MIN(textWidth, self.nameLbl.lim_width);
    CGFloat badgeCenterY = self.contentView.lim_height / 2.0f;

    // 实名认证 ✓ 徽章布局（）：贴在昵称右侧 padding.left = 2pt，12×12pt。
    if (!self.realnameVerifiedImgView.hidden) {
        self.realnameVerifiedImgView.lim_width = realnameBadgeW;
        self.realnameVerifiedImgView.lim_height = 12.0f;
        self.realnameVerifiedImgView.lim_left = afterNameRight + 2.0f;
        self.realnameVerifiedImgView.lim_top = badgeCenterY - self.realnameVerifiedImgView.lim_height / 2.0f;
        afterNameRight = self.realnameVerifiedImgView.lim_left + self.realnameVerifiedImgView.lim_width;
    }

    if(!self.botBadgeLbl.hidden) {
        self.botBadgeLbl.lim_left = afterNameRight + 6.0f;
        self.botBadgeLbl.lim_top = badgeCenterY - self.botBadgeLbl.lim_height / 2.0f;
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

- (UIImageView *)realnameVerifiedImgView {
    if(!_realnameVerifiedImgView) {
        _realnameVerifiedImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 12.0f, 12.0f)];
        _realnameVerifiedImgView.contentMode = UIViewContentModeScaleAspectFit;
        // 资源路径必须带 Common/ 前缀：Images.xcassets/Common/Contents.json 设了
        // provides-namespace: true（P0-1）。漏前缀会 imageNamed: 返 nil → 空框。
        _realnameVerifiedImgView.image = [[WKApp shared] loadImage:@"Common/ic_realname_verified_mini" moduleID:@"WuKongBase"];
        _realnameVerifiedImgView.hidden = YES;
    }
    return _realnameVerifiedImgView;
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
