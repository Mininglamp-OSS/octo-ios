//
//  WKGroupScanJoinVC.m
//  WuKongBase
//

#import "WKGroupScanJoinVC.h"
#import "WuKongBase.h"
#import "WKAvatarUtil.h"

@interface WKGroupScanJoinVC ()

@property(nonatomic,strong) UIView *cardView;
@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UILabel *nameLbl;
@property(nonatomic,strong) UILabel *memberCountLbl;
@property(nonatomic,strong) UIButton *joinBtn;

@end

@implementation WKGroupScanJoinVC

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.view addSubview:self.cardView];
    [self.cardView addSubview:self.avatarImgView];
    [self.cardView addSubview:self.nameLbl];
    [self.cardView addSubview:self.memberCountLbl];
    [self.cardView addSubview:self.joinBtn];

    // 设置数据
    NSString *avatarURL = self.groupAvatar;
    if(!avatarURL || avatarURL.length == 0) {
        avatarURL = [WKAvatarUtil getGroupAvatar:self.groupNo];
    } else {
        // 服务端返回的是相对路径，拼接完整URL
        avatarURL = [[NSURL URLWithString:avatarURL relativeToURL:[NSURL URLWithString:[WKApp shared].config.apiBaseUrl]] absoluteString];
    }
    [self.avatarImgView.avatarImgView lim_setImageWithURL:[NSURL URLWithString:avatarURL]];

    self.nameLbl.text = self.groupName ?: @"";
    self.memberCountLbl.text = [NSString stringWithFormat:LLang(@"%ld位成员"), (long)self.memberCount];
}

- (NSString *)langTitle {
    return LLang(@"群聊信息");
}

#pragma mark - Actions

-(void) joinBtnPressed {
    self.joinBtn.enabled = NO;
    [self.view showHUD];

    NSString *path = [NSString stringWithFormat:@"groups/%@/scanjoin?auth_code=%@", self.groupNo, self.authCode];
    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] GET:path parameters:nil].then(^{
        [weakSelf.view hideHud];
        WKConversationVC *vc = [WKConversationVC new];
        vc.channel = [[WKChannel alloc] initWith:weakSelf.groupNo channelType:WK_GROUP];
        [[WKNavigationManager shared] replacePushViewController:vc animated:YES];
    }).catch(^(NSError *error) {
        weakSelf.joinBtn.enabled = YES;
        [weakSelf.view hideHud];
        [weakSelf.view showHUDWithHide:error.domain];
    });
}

#pragma mark - UI Components

-(UIView*) cardView {
    if(!_cardView) {
        CGFloat width = WKScreenWidth - 80.0f;
        _cardView = [[UIView alloc] initWithFrame:CGRectMake(40.0f, 100.0f + [self visibleRect].origin.y, width, 260.0f)];
        _cardView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        _cardView.layer.cornerRadius = 10.0f;
        _cardView.layer.masksToBounds = YES;
    }
    return _cardView;
}

-(WKUserAvatar*) avatarImgView {
    if(!_avatarImgView) {
        CGFloat avatarSize = 64.0f;
        _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, avatarSize, avatarSize)];
        _avatarImgView.lim_left = self.cardView.lim_width / 2.0f - avatarSize / 2.0f;
        _avatarImgView.lim_top = 30.0f;
    }
    return _avatarImgView;
}

-(UILabel*) nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, self.avatarImgView.lim_bottom + 12.0f, self.cardView.lim_width - 40.0f, 22.0f)];
        _nameLbl.textAlignment = NSTextAlignmentCenter;
        _nameLbl.font = [[WKApp shared].config appFontOfSizeMedium:16.0f];
        _nameLbl.numberOfLines = 1;
    }
    return _nameLbl;
}

-(UILabel*) memberCountLbl {
    if(!_memberCountLbl) {
        _memberCountLbl = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, self.nameLbl.lim_bottom + 6.0f, self.cardView.lim_width - 40.0f, 18.0f)];
        _memberCountLbl.textAlignment = NSTextAlignmentCenter;
        _memberCountLbl.font = [UIFont systemFontOfSize:14.0f];
        _memberCountLbl.textColor = [UIColor grayColor];
    }
    return _memberCountLbl;
}

-(UIButton*) joinBtn {
    if(!_joinBtn) {
        CGFloat btnWidth = self.cardView.lim_width - 60.0f;
        _joinBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _joinBtn.frame = CGRectMake(30.0f, self.memberCountLbl.lim_bottom + 30.0f, btnWidth, 44.0f);
        [_joinBtn setTitle:LLang(@"加入群聊") forState:UIControlStateNormal];
        [_joinBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _joinBtn.titleLabel.font = [UIFont systemFontOfSize:16.0f weight:UIFontWeightMedium];
        _joinBtn.backgroundColor = [WKApp shared].config.themeColor;
        _joinBtn.layer.cornerRadius = 8.0f;
        _joinBtn.layer.masksToBounds = YES;
        [_joinBtn addTarget:self action:@selector(joinBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _joinBtn;
}

@end
