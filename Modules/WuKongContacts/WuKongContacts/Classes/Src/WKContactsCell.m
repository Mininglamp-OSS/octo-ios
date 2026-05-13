//
//  WKContactsCell.m
//  WuKongContacts
//
//  Created by tt on 2019/12/8.
//

#import "WKContactsCell.h"
#import "WKContacts.h"
#import <Masonry/Masonry.h>
#import <WuKongBase/WKOfficialTag.h>
#import <WuKongBase/WKConstant.h>
#import <WuKongBase/WKChannelUtil.h>
#import <WuKongBase/WKRealnamePrefetcher.h>

@implementation WKContactsCellModel

@end

@interface WKContactsCell()

@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UILabel *nameLbl;
@property(nonatomic,strong) WKContactsCellModel *contactModel;
@property(nonatomic,strong) UIView *onlineDot;
@property(nonatomic,strong) UILabel *aiBadgeLbl;
@property(nonatomic,strong) WKOfficialTag *officialTag;
// YUJ-381 / dmwork-web#1169 Phase A —— 通讯录 cell 实名 ✓ 徽章
@property(nonatomic,strong) UIImageView *realnameVerifiedImgView;

@end

@implementation WKContactsCell

-(void) setupUI{
    [super setupUI];
    self.topLineView.hidden = YES;
    self.bottomLineView.hidden = YES;

    CGFloat avatarSize = 36.0f;
    _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, avatarSize, avatarSize)];
    _avatarImgView.layer.cornerRadius = 9.0f;
    _avatarImgView.layer.masksToBounds = YES;
    _avatarImgView.avatarImgView.layer.cornerRadius = 9.0f;
    _avatarImgView.avatarImgView.layer.masksToBounds = YES;
    [self.contentView addSubview:_avatarImgView];

    _nameLbl = [[UILabel alloc] init];
    [_nameLbl setFont:[[WKApp shared].config appFontOfSize:15.0f]];
    [self.contentView addSubview:_nameLbl];

    _aiBadgeLbl = [[UILabel alloc] init];
    _aiBadgeLbl.text = @"AI";
    _aiBadgeLbl.font = [UIFont systemFontOfSize:9.0f weight:UIFontWeightBold];
    _aiBadgeLbl.textColor = [UIColor whiteColor];
    _aiBadgeLbl.textAlignment = NSTextAlignmentCenter;
    _aiBadgeLbl.layer.cornerRadius = 7.0f;
    _aiBadgeLbl.layer.masksToBounds = YES;
    _aiBadgeLbl.hidden = YES;
    [self.contentView addSubview:_aiBadgeLbl];

    _onlineDot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 8)];
    _onlineDot.layer.cornerRadius = 4.0f;
    _onlineDot.layer.borderWidth = 1.5f;
    _onlineDot.hidden = YES;
    [self.contentView addSubview:_onlineDot];

    _officialTag = [WKOfficialTag new];
    _officialTag.hidden = YES;
    [self.contentView addSubview:_officialTag];

    // YUJ-381：通讯录 cell 实名 ✓ 徽章
    _realnameVerifiedImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 12.0f, 12.0f)];
    _realnameVerifiedImgView.contentMode = UIViewContentModeScaleAspectFit;
    _realnameVerifiedImgView.image = [WKApp.shared loadImage:@"Common/ic_realname_verified_mini" moduleID:@"WuKongBase"];
    _realnameVerifiedImgView.hidden = YES;
    [self.contentView addSubview:_realnameVerifiedImgView];
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

    // Official tag
    self.officialTag.hidden = YES;
    NSString *category = _contactModel.channelInfo ? _contactModel.channelInfo.category : nil;
    if ([_contactModel.uid isEqualToString:[WKApp shared].config.systemUID]) {
        category = WKChannelCategoryService;
    }
    if (category && ![category isEqualToString:@""]) {
        if ([category isEqualToString:WKChannelCategoryService]) {
            self.officialTag.frame = CGRectMake(0, 0, 18, 18);
            self.officialTag.hidden = NO;
            self.officialTag.image = [WKApp.shared loadImage:@"ConversationList/Index/Official" moduleID:@"WuKongBase"];
        } else if ([category isEqualToString:WKChannelCategoryVisitor]) {
            self.officialTag.frame = CGRectMake(0, 0, 35, 18);
            self.officialTag.hidden = NO;
            self.officialTag.image = [WKApp.shared loadImage:@"ConversationList/Index/Visitor" moduleID:@"WuKongBase"];
        }
    }

    // AI badge
    self.aiBadgeLbl.hidden = !_contactModel.robot;
    if (_contactModel.robot) {
        _aiBadgeLbl.backgroundColor = WKApp.shared.config.themeColor;
        [self.aiBadgeLbl sizeToFit];
        CGRect frame = self.aiBadgeLbl.frame;
        frame.size.width = MAX(frame.size.width + 8.0f, 28.0f);
        frame.size.height = 14.0f;
        self.aiBadgeLbl.frame = frame;
    }

    // YUJ-381 实名 ✓ 徽章：仅人 + 非机器人。
    // 关键：优先读 SDK person 缓存（prefetcher 回写的就是这里、SDK push 也写这里），
    // cellModel.channelInfo 只作回退。否则当 WKContactsVC.performBatchUpdates 用
    // /friends API 数据覆盖 cellModel.channelInfo 时，新 info 的 extra 不带
    // realname_verified，徽章会「闪一下又被覆盖没」。person 缓存里的字段不会丢。
    BOOL canShowRealname = !_contactModel.robot && _contactModel.uid.length > 0;
    BOOL realnameVerified = NO;
    if(canShowRealname) {
        WKChannelInfo *personInfo = [[WKSDK shared].channelManager getChannelInfo:[[WKChannel alloc] initWith:_contactModel.uid channelType:WK_PERSON]];
        NSNumber *flag = [WKChannelUtil isRealnameVerifiedFromExtra:personInfo.extra];
        if(flag == nil) {
            // person 缓存还没数据时，看 cellModel 自带的 channelInfo（可能是 friends API 直接给的）
            flag = [WKChannelUtil isRealnameVerifiedFromExtra:_contactModel.channelInfo.extra];
        }
        realnameVerified = flag.boolValue;
    }
    self.realnameVerifiedImgView.hidden = !realnameVerified;
    if(canShowRealname && !realnameVerified) {
        [WKRealnamePrefetcher ensureFetched:_contactModel.uid];
    }

    // Online dot
    self.onlineDot.hidden = YES;
    UIColor *greenColor = [UIColor colorWithRed:11/255.0f green:135/255.0f blue:125/255.0f alpha:1.0f];
    _onlineDot.backgroundColor = greenColor;
    _onlineDot.layer.borderColor = [WKApp shared].config.cellBackgroundColor.CGColor;
    if (_contactModel.online) {
        self.onlineDot.hidden = NO;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat leftPad = 16.0f;
    CGFloat avatarToName = 12.0f;

    // Avatar
    self.avatarImgView.lim_left = leftPad;
    self.avatarImgView.lim_top = self.lim_height / 2.0f - self.avatarImgView.lim_height / 2.0f;

    // Online dot on bottom-right of avatar
    if (!self.onlineDot.hidden) {
        self.onlineDot.lim_left = self.avatarImgView.lim_right - self.onlineDot.lim_width;
        self.onlineDot.lim_top = self.avatarImgView.lim_bottom - self.onlineDot.lim_height;
    }

    // Name
    self.nameLbl.lim_left = self.avatarImgView.lim_right + avatarToName;
    self.nameLbl.lim_top = self.lim_height / 2.0f - self.nameLbl.lim_height / 2.0f;

    // Official tag + realname + AI badge after name
    CGFloat nextLeft = self.nameLbl.lim_right;
    if (!self.officialTag.hidden) {
        self.officialTag.lim_left = nextLeft + 4.0f;
        self.officialTag.lim_top = self.nameLbl.lim_top + (self.nameLbl.lim_height - self.officialTag.lim_height) / 2.0f;
        nextLeft = self.officialTag.lim_right;
    }
    if (!self.realnameVerifiedImgView.hidden) {
        self.realnameVerifiedImgView.lim_width = 12.0f;
        self.realnameVerifiedImgView.lim_height = 12.0f;
        self.realnameVerifiedImgView.lim_left = nextLeft + 6.0f;
        self.realnameVerifiedImgView.lim_top = self.nameLbl.lim_top + (self.nameLbl.lim_height - self.realnameVerifiedImgView.lim_height) / 2.0f;
        nextLeft = self.realnameVerifiedImgView.lim_right;
    }
    if (!self.aiBadgeLbl.hidden) {
        self.aiBadgeLbl.lim_left = nextLeft + 6.0f;
        self.aiBadgeLbl.lim_top = self.nameLbl.lim_top + (self.nameLbl.lim_height - self.aiBadgeLbl.lim_height) / 2.0f;
    }
}

@end
