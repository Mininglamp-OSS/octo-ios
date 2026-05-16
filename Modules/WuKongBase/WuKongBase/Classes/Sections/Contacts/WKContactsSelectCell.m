//
//  WKContactsSelectCell.m
//  WuKongContacts
//
//  Created by tt on 2019/12/8.
//

#import "WKContactsSelectCell.h"
#import "WKContacts.h"
#import "WuKongBase.h"
#import "WKChannelUtil.h"
#import "WKRealnamePrefetcher.h"
@implementation WKContactsSelect



@end

@interface WKContactsSelectCell()<WKCheckBoxDelegate>

@property(nonatomic,strong) UILabel *botBadgeLbl;
// / Phase A —— 选人列表实名 ✓ 徽章（拉人 / 新建群）
@property(nonatomic,strong) UIImageView *realnameVerifiedImgView;

@end
@implementation WKContactsSelectCell



-(void) setupUI{
    [super setupUI];
    self.bottomLineView.hidden = YES;
    _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, 45.0f, 45.0f)];
    [self.contentView addSubview:_avatarImgView];
    
    _nameLbl = [[UILabel alloc] init];
    [_nameLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
    [self addSubview:_nameLbl];
    
    self.checkBox = [[WKCheckBox alloc] initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
    self.checkBox.onFillColor = [WKApp shared].config.themeColor;
    self.checkBox.onCheckColor = [UIColor whiteColor];
    self.checkBox.onTintColor = [WKApp shared].config.themeColor;
    self.checkBox.onAnimationType = BEMAnimationTypeBounce;
    self.checkBox.offAnimationType = BEMAnimationTypeBounce;
    self.checkBox.animationDuration = 0.0f;
    self.checkBox.lineWidth = 1.0f;
//    self.checkBox.tintColor = [UIColor grayColor];
    self.checkBox.delegate = self;
    [self addSubview:self.checkBox];

    _botBadgeLbl = [[UILabel alloc] init];
    _botBadgeLbl.text = @"AI";
    _botBadgeLbl.font = [[WKApp shared].config appFontOfSize:10.0f];
    _botBadgeLbl.textColor = [UIColor whiteColor];
    _botBadgeLbl.backgroundColor = [UIColor colorWithRed:136.0f/255.0f green:84.0f/255.0f blue:208.0f/255.0f alpha:1.0f];
    _botBadgeLbl.textAlignment = NSTextAlignmentCenter;
    _botBadgeLbl.layer.cornerRadius = 4.0f;
    _botBadgeLbl.layer.masksToBounds = YES;
    _botBadgeLbl.hidden = YES;
    [self.contentView addSubview:_botBadgeLbl];

    // 实名 ✓ 徽章
    _realnameVerifiedImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 12.0f, 12.0f)];
    _realnameVerifiedImgView.contentMode = UIViewContentModeScaleAspectFit;
    _realnameVerifiedImgView.image = [WKApp.shared loadImage:@"Common/ic_realname_verified_mini" moduleID:@"WuKongBase"];
    _realnameVerifiedImgView.hidden = YES;
    [self.contentView addSubview:_realnameVerifiedImgView];
}

+(NSString*) cellId{
    return @"WKContactsSelectCell";
}

-(void) refreshWithModel:(id)cellModel{
    _contactSelectModel = cellModel;
    
    [self.nameLbl setTextColor:[WKApp shared].config.defaultTextColor];
    
    self.avatarImgView.url = _contactSelectModel.avatar;
    self.nameLbl.text = _contactSelectModel.displayName;
    [self.nameLbl sizeToFit];
    self.checkBox.on = self.contactSelectModel.selected;

    self.botBadgeLbl.hidden = !_contactSelectModel.robot;
    if(_contactSelectModel.robot) {
        [self.botBadgeLbl sizeToFit];
        CGRect frame = self.botBadgeLbl.frame;
        frame.size.width += 8.0f;
        frame.size.height += 4.0f;
        self.botBadgeLbl.frame = frame;
    }

    // 实名 ✓ 徽章：只对人 + 非机器人显示。数据走 person 缓存（预拉取器
    // 在没数据时主动补一次 /users/<uid>，channelInfoUpdate 会驱动 reload）。
    BOOL canShowRealname = !_contactSelectModel.robot && _contactSelectModel.uid.length > 0;
    BOOL realnameVerified = NO;
    if(canShowRealname) {
        WKChannelInfo *personInfo = [[WKSDK shared].channelManager getChannelInfo:[[WKChannel alloc] initWith:_contactSelectModel.uid channelType:WK_PERSON]];
        NSNumber *flag = [WKChannelUtil isRealnameVerifiedFromExtra:personInfo.extra];
        // 兼容选人模型自带 extra 的场景（WKContacts.extra 也可能携带 realname_verified）
        if(flag == nil) {
            flag = [WKChannelUtil isRealnameVerifiedFromExtra:_contactSelectModel.extra];
        }
        realnameVerified = flag.boolValue;
    }
    self.realnameVerifiedImgView.hidden = !realnameVerified;
    if(canShowRealname && !realnameVerified) {
        [WKRealnamePrefetcher ensureFetched:_contactSelectModel.uid];
    }

    if(_contactSelectModel.mode == WKContactsModeSingle) {
        self.checkBox.hidden = YES;
        self.avatarImgView.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
        self.nameLbl.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
    }else {
        self.checkBox.hidden = NO;
        self.checkBox.userInteractionEnabled = !_contactSelectModel.disable;
        self.checkBox.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
        self.avatarImgView.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
        self.nameLbl.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
    }
    
   
    
//    if(_contactSelectModel.first) {
//        self.topLineView.hidden = NO;
//    }else {
//        self.topLineView.hidden = YES;
//    }
}


- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat avatarLeft = 10.0f;
    CGFloat nameLeft = 10.0f;
    CGFloat checkBoxLeft = 10.0f;
    self.checkBox.lim_left = checkBoxLeft;
    self.checkBox.lim_top = self.lim_height/2.0f - self.checkBox.lim_height/2.0f;
    if(_contactSelectModel.mode == WKContactsModeSingle) {
        self.avatarImgView.lim_left =  avatarLeft;
    }else {
        self.avatarImgView.lim_left = self.checkBox.lim_right + avatarLeft;
    }
    
    self.avatarImgView.lim_top = self.lim_height/2.0f - self.avatarImgView.lim_height/2.0f;
    self.nameLbl.lim_left = self.avatarImgView.lim_right + nameLeft;
    self.nameLbl.lim_top = self.lim_height/2.0f - self.nameLbl.lim_height/2.0f;

    // ：实名 → AI 串行排，徽章必出（长名内容由 sizeToFit 决定，列表多数场景够用）。
    CGFloat afterNameRight = self.nameLbl.lim_right;
    if (!self.realnameVerifiedImgView.hidden) {
        self.realnameVerifiedImgView.lim_width = 12.0f;
        self.realnameVerifiedImgView.lim_height = 12.0f;
        self.realnameVerifiedImgView.lim_left = afterNameRight + 6.0f;
        self.realnameVerifiedImgView.lim_top = self.nameLbl.lim_top + (self.nameLbl.lim_height - self.realnameVerifiedImgView.lim_height) / 2.0f;
        afterNameRight = self.realnameVerifiedImgView.lim_right;
    }
    if(!self.botBadgeLbl.hidden) {
        self.botBadgeLbl.lim_left = afterNameRight + 6.0f;
        self.botBadgeLbl.lim_top = self.nameLbl.lim_top + (self.nameLbl.lim_height - self.botBadgeLbl.lim_height) / 2.0f;
    }
    
//    if(_contactSelectModel.last) {
//        self.bottomLineView.lim_left =  0;
//        self.bottomLineView.lim_width = self.lim_width;
//    }else {
//        self.bottomLineView.lim_left = self.nameLbl.lim_left;
//        self.bottomLineView.lim_width = self.lim_width - self.nameLbl.lim_left;
//    }
    
}

#pragma mark - WKCheckBoxDelegate
- (void)didTapCheckBox:(WKCheckBox*)checkBox {
    self.contactSelectModel.selected = checkBox.on;
    if(_stateChangeCheckBk) {
        _stateChangeCheckBk(self.contactSelectModel);
    }
}
@end
