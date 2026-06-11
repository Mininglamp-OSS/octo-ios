//
//  WKMeVC2.m
//  WuKongBase
//
//  Created by tt on 2020/6/9.
//

#import "WKMeVC.h"
#import "WKMeInfoVC.h"
#import "WKServerSettingHelper.h"
#import "WKMeCardStyle.h"
@interface WKMeVC ()<WKChannelManagerDelegate>
@property(nonatomic,strong) WKeHeader *meHeader;
@property(nonatomic,assign) NSTimeInterval lastAppearTime;
@end

@implementation WKMeVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKMeVM new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationBar.hidden = YES;
    self.viewModel = [WKMeVM new];
    if (@available(iOS 11.0,*)) {
      self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }else{
      self.automaticallyAdjustsScrollViewInsets = NO;
    }
    // iOS 26+ Liquid Glass：底部留 tabbar 高度，最后一行可滑出浮岛遮挡
    if (@available(iOS 26.0, *)) {
        CGFloat tbH = self.tabBarController.tabBar.frame.size.height ?: 83;
        self.tableView.contentInset = UIEdgeInsetsMake(0, 0, tbH, 0);
    }
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    self.tableView.tableHeaderView = [self meHeader];

    [WKSDK.shared.channelManager addDelegate:self];
}

- (void)viewDidAppear:(BOOL)animated {
    CFAbsoluteTime _vdaStart = CFAbsoluteTimeGetCurrent();
    [super viewDidAppear:animated];
    CFAbsoluteTime _hdrStart = CFAbsoluteTimeGetCurrent();
    [self.meHeader reloadData];
    NSLog(@"[TabPerf] MeVC.viewDidAppear: super=%.1fms header=%.1fms",
          (_hdrStart - _vdaStart) * 1000, (CFAbsoluteTimeGetCurrent() - _hdrStart) * 1000);
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - self.lastAppearTime < 10) return;
    self.lastAppearTime = now;
    [WKSDK.shared.channelManager fetchChannelInfo:[WKChannel personWithChannelID:[WKApp shared].loginInfo.uid]];
}


- (void)dealloc {
    NSLog(@"WKMeVC dealloc...");
    [WKSDK.shared.channelManager removeDelegate:self];
}


-(void) viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    [self.meHeader reloadData];
}

-(UITableViewStyle) tableViewStyle {
    return UITableViewStyleInsetGrouped;
}

-(CGRect) tableViewFrame {
    return self.view.bounds;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    [cell wk_applyMeCardStyleAtIndexPath:indexPath inTableView:tableView];
}

-(void) setCustomTitle:(NSString*)title {
    self.title=title;
}



-(WKeHeader*) meHeader {
    if (!_meHeader) {
        CGFloat statusBarHeight = 0;
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = (UIWindowScene *)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
            statusBarHeight = scene.statusBarManager.statusBarFrame.size.height;
        } else {
            statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        }
        // HTML: status-bar 44 + gap 12 + card (104+在线行) ≈ 134
        _meHeader = [[WKeHeader alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, statusBarHeight + 134.0f)];
        [_meHeader setBackgroundColor:[UIColor clearColor]];
    }
    return _meHeader;
}

#pragma mark --- WKChannelManagerDelegate
- (void)channelInfoUpdate:(WKChannelInfo *)channelInfo {
    if(channelInfo.channel.channelType != WK_PERSON) {
        return;
    }
    if(![channelInfo.channel.channelId isEqualToString:WKApp.shared.loginInfo.uid]) {
        return;
    }
    NSLog(@"[Avatar] WKMeVC channelInfoUpdate, channelId=%@", channelInfo.channel.channelId);
    WKApp.shared.loginInfo.extra[@"name"] = channelInfo.name;
    [WKApp shared].loginInfo.extra[@"short_no"] = channelInfo.extra[@"short_no"];
    [WKApp shared].loginInfo.extra[@"sex"] = channelInfo.extra[@"sex"];
    // 同步实名认证状态
    id vVal = channelInfo.extra[@"realname_verified"];
    if(vVal) {
        [WKApp shared].loginInfo.realnameVerified = [vVal boolValue];
    }
    id rnVal = channelInfo.extra[@"real_name"];
    if([rnVal isKindOfClass:[NSString class]]) {
        [WKApp shared].loginInfo.realName = (NSString *)rnVal;
    }
    id tsVal = channelInfo.extra[@"realname_verified_at"];
    if(tsVal) {
        [WKApp shared].loginInfo.realnameVerifiedAt = [tsVal doubleValue];
    }
    [[WKApp shared].loginInfo save];

    [self.meHeader reloadData];
}

@end

#define avatarSize 48.0f
@interface WKeHeader ()

@property(nonatomic,strong) UIView *cardView;
@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UILabel *nameLbl;
@property(nonatomic,strong) UIImageView *verifiedCheckImgView; // 已实名 ✓ 勾
@property(nonatomic,strong) UIView *verifiedTagView;           // 已实名 tag
@property(nonatomic,strong) UILabel *verifiedTagLbl;
@property(nonatomic,strong) UILabel *shortNoLbl;
@property(nonatomic,strong) UIButton *copyBtn;
@property(nonatomic,strong) UIView *onlineDot;
@property(nonatomic,strong) UILabel *statusLbl;
@property(nonatomic,strong) UIImageView *arrowImgView;

@end
@implementation WKeHeader

-(instancetype) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        [self addSubview:self.cardView];
        [self.cardView addSubview:self.avatarImgView];
        [self.cardView addSubview:self.nameLbl];
        [self.cardView addSubview:self.verifiedCheckImgView];
        [self.cardView addSubview:self.verifiedTagView];
        [self.cardView addSubview:self.shortNoLbl];
        [self.cardView addSubview:self.copyBtn];
        [self.cardView addSubview:self.onlineDot];
        [self.cardView addSubview:self.statusLbl];
        [self.cardView addSubview:self.arrowImgView];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(meInfoPressed)];
        [self.cardView addGestureRecognizer:tap];

        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(serverSettingLongPressed:)];
        longPress.minimumPressDuration = 1.5;
        [self.cardView addGestureRecognizer:longPress];

        [self reloadData];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(avatarUpdate:) name:WKNOTIFY_USER_AVATAR_UPDATE object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(realnameVerified:) name:WKNOTIFY_REALNAME_VERIFIED object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKNOTIFY_USER_AVATAR_UPDATE object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKNOTIFY_REALNAME_VERIFIED object:nil];
}

-(void) avatarUpdate:(NSNotification*)noti {
    NSDictionary *data = noti.object;
    if(data && data[@"uid"] && [[WKApp shared].loginInfo.uid isEqualToString:data[@"uid"]]) {
        NSLog(@"[Avatar] WKeHeader received avatarUpdate notification");
        WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:[WKApp shared].loginInfo.uid]];
        self.avatarImgView.url = [WKAvatarUtil getAvatar:[WKApp shared].loginInfo.uid cacheKey:info.avatarCacheKey];
    }
}

-(void) realnameVerified:(NSNotification*)noti {
    [self reloadData];
}

- (UIView *)cardView {
    if(!_cardView) {
        CGFloat margin = 16.0f;
        CGFloat statusBarHeight = 0;
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = (UIWindowScene *)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
            statusBarHeight = scene.statusBarManager.statusBarFrame.size.height;
        } else {
            statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        }
        _cardView = [[UIView alloc] initWithFrame:CGRectMake(margin, statusBarHeight + 12.0f, self.lim_width - margin * 2, 122.0f)];
        _cardView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        _cardView.layer.cornerRadius = 16.0f;
        _cardView.layer.masksToBounds = YES;
        _cardView.userInteractionEnabled = YES;
    }
    return _cardView;
}

-(void) reloadData {
    NSLog(@"[Avatar] WKeHeader reloadData");
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:[WKApp shared].loginInfo.uid]];
    self.avatarImgView.url = [WKAvatarUtil getAvatar:[WKApp shared].loginInfo.uid cacheKey:info.avatarCacheKey];

    self.cardView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    self.nameLbl.textColor = [WKApp shared].config.defaultTextColor;
    // 浅色: 在白底卡片上的弱文本 (#1C1C23 α 0.4 = 设计稿同款)
    // 深色: 在 secondarySystemBackground 卡片上的弱文本, 用 defaultTextColor 同色系
    //       的浅灰 (#D0D1D2) 同样 α 0.4 避免黑压黑读不出。
    UIColor *tipColor;
    if (@available(iOS 13.0, *)) {
        tipColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull tc) {
            if (tc.userInterfaceStyle == UIUserInterfaceStyleDark || [WKApp shared].config.style == WKSystemStyleDark) {
                return [UIColor colorWithRed:0xD0/255.0 green:0xD1/255.0 blue:0xD2/255.0 alpha:0.6];
            }
            return [UIColor colorWithRed:0x1C/255.0 green:0x1C/255.0 blue:0x23/255.0 alpha:0.4];
        }];
    } else {
        tipColor = [UIColor colorWithRed:0x1C/255.0 green:0x1C/255.0 blue:0x23/255.0 alpha:0.4];
    }
    self.shortNoLbl.textColor = tipColor;

    NSString *displayName = [WKApp shared].loginInfo.displayName;
    self.nameLbl.text = displayName.length > 0 ? displayName : LLang(@"我");
    [self.nameLbl sizeToFit];

    // 实名认证 ✓ + 已实名 tag
    BOOL verified = [WKApp shared].loginInfo.realnameVerified;
    self.verifiedCheckImgView.hidden = !verified;
    self.verifiedTagView.hidden = !verified;

    NSString *shortNo = [WKApp shared].loginInfo.extra[@"short_no"];
    BOOL hasShort = shortNo && shortNo.length > 0;
    if(hasShort) {
        self.shortNoLbl.text = [NSString stringWithFormat:@"%@%@：%@", [WKApp shared].config.appName, LLang(@"号"), shortNo];
    } else {
        self.shortNoLbl.text = @"";
    }
    [self.shortNoLbl sizeToFit];
    self.copyBtn.hidden = !hasShort;

    // 在线状态（在 shortNo 行下方）
    WKConnectStatus connectStatus = [WKSDK shared].connectionManager.connectStatus;
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString *appVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    NSString *buildNumber = [infoDictionary objectForKey:@"CFBundleVersion"];
    NSString *statusText;
    if(connectStatus == WKConnected) {
        statusText = [NSString stringWithFormat:@"%@ · iOS v%@(%@)", LLang(@"在线"), appVersion, buildNumber];
        self.onlineDot.backgroundColor = [UIColor colorWithRed:52.0f/255.0f green:199.0f/255.0f blue:89.0f/255.0f alpha:1.0f];
    } else if(connectStatus == WKConnecting || connectStatus == WKPullingOffline) {
        statusText = [NSString stringWithFormat:@"%@ · iOS v%@(%@)", LLang(@"连接中"), appVersion, buildNumber];
        self.onlineDot.backgroundColor = [UIColor colorWithRed:255.0f/255.0f green:204.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
    } else {
        statusText = [NSString stringWithFormat:@"%@ · iOS v%@(%@)", LLang(@"离线"), appVersion, buildNumber];
        self.onlineDot.backgroundColor = [UIColor colorWithRed:199.0f/255.0f green:199.0f/255.0f blue:204.0f/255.0f alpha:1.0f];
    }
    self.statusLbl.text = statusText;
    self.statusLbl.textColor = tipColor;
    [self.statusLbl sizeToFit];

    [self setNeedsLayout];
}

-(WKUserAvatar*) avatarImgView {
    if (!_avatarImgView) {
        _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, avatarSize, avatarSize)];
        _avatarImgView.userInteractionEnabled = NO;
        _avatarImgView.layer.cornerRadius = 10.0f;
        _avatarImgView.layer.masksToBounds = YES;
    }
    return _avatarImgView;
}

-(UILabel*) nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
        [_nameLbl setFont:[[WKApp shared].config appFontOfSizeSemibold:16.0f]];
    }
    return _nameLbl;
}

-(UIImageView*) verifiedCheckImgView {
    if(!_verifiedCheckImgView) {
        _verifiedCheckImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 14.0f, 14.0f)];
        _verifiedCheckImgView.contentMode = UIViewContentModeScaleAspectFit;
        UIImage *img = nil;
        if (@available(iOS 13.0, *)) {
            UIImage *sys = [UIImage systemImageNamed:@"checkmark.seal.fill"];
            if(sys) {
                img = [sys imageWithTintColor:[UIColor colorWithRed:0 green:122.0f/255.0f blue:1.0f alpha:1.0f]
                                renderingMode:UIImageRenderingModeAlwaysOriginal];
            }
        }
        _verifiedCheckImgView.image = img;
        _verifiedCheckImgView.hidden = YES; // 默认隐藏，reloadData 控制
    }
    return _verifiedCheckImgView;
}

-(UIView*) verifiedTagView {
    if(!_verifiedTagView) {
        _verifiedTagView = [[UIView alloc] initWithFrame:CGRectZero];
        _verifiedTagView.layer.cornerRadius = 8.0f;
        _verifiedTagView.layer.masksToBounds = YES;
        _verifiedTagView.backgroundColor = [UIColor colorWithRed:0 green:122.0f/255.0f blue:1.0f alpha:0.12f];
        _verifiedTagLbl = [[UILabel alloc] init];
        _verifiedTagLbl.text = LLang(@"已实名");
        _verifiedTagLbl.font = [UIFont systemFontOfSize:11.0f];
        _verifiedTagLbl.textColor = [UIColor colorWithRed:0 green:122.0f/255.0f blue:1.0f alpha:1.0f];
        [_verifiedTagLbl sizeToFit];
        [_verifiedTagView addSubview:_verifiedTagLbl];
        _verifiedTagView.hidden = YES;
    }
    return _verifiedTagView;
}

-(UILabel*) shortNoLbl {
    if(!_shortNoLbl) {
        _shortNoLbl = [[UILabel alloc] init];
        [_shortNoLbl setFont:[UIFont systemFontOfSize:12.0f]];
    }
    return _shortNoLbl;
}

-(UIButton*) copyBtn {
    if(!_copyBtn) {
        _copyBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 18.0f, 18.0f)];
        _copyBtn.hidden = YES;
        UIImage *img = nil;
        if (@available(iOS 13.0, *)) {
            UIImage *sys = [UIImage systemImageNamed:@"doc.on.doc"];
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:12.0f weight:UIImageSymbolWeightRegular];
            sys = [sys imageByApplyingSymbolConfiguration:cfg];
            img = [sys imageWithTintColor:[UIColor colorWithRed:0x1C/255.0 green:0x1C/255.0 blue:0x23/255.0 alpha:0.4]
                            renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        [_copyBtn setImage:img forState:UIControlStateNormal];
        [_copyBtn addTarget:self action:@selector(copyShortNo) forControlEvents:UIControlEventTouchUpInside];
    }
    return _copyBtn;
}

-(UIImageView*) arrowImgView {
    if(!_arrowImgView) {
        _arrowImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 7.0f, 12.0f)];
        _arrowImgView.image = [self imageName:@"Common/Index/ArrowRight"];
    }
    return _arrowImgView;
}

-(UIView*) onlineDot {
    if(!_onlineDot) {
        _onlineDot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8.0f, 8.0f)];
        _onlineDot.layer.cornerRadius = 4.0f;
        _onlineDot.layer.masksToBounds = YES;
    }
    return _onlineDot;
}

-(UILabel*) statusLbl {
    if(!_statusLbl) {
        _statusLbl = [[UILabel alloc] init];
        [_statusLbl setFont:[UIFont systemFontOfSize:11.0f]];
    }
    return _statusLbl;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat padding = 16.0f;

    self.avatarImgView.lim_left = padding;
    self.avatarImgView.lim_top = (self.cardView.lim_height - avatarSize) / 2.0f;

    CGFloat textLeft = self.avatarImgView.lim_right + 12.0f;

    self.nameLbl.lim_left = textLeft;
    // 名字 + shortNo + 状态 整体竖直居中
    CGFloat nameH = self.nameLbl.lim_height;
    CGFloat shortH = self.shortNoLbl.lim_height;
    CGFloat statusH = self.statusLbl.lim_height;
    CGFloat groupH = nameH + 2.0f + shortH + 6.0f + statusH;
    CGFloat groupTop = (self.cardView.lim_height - groupH) / 2.0f;
    self.nameLbl.lim_top = groupTop;

    // ✓ 勾放在昵称右侧
    if(!self.verifiedCheckImgView.hidden) {
        self.verifiedCheckImgView.lim_left = self.nameLbl.lim_right + 6.0f;
        self.verifiedCheckImgView.lim_top  = self.nameLbl.lim_top + (self.nameLbl.lim_height - self.verifiedCheckImgView.lim_height) / 2.0f;
    }

    // "已实名" tag 放在勾右侧；若勾隐藏则紧贴昵称
    if(!self.verifiedTagView.hidden) {
        CGFloat tagPadH = 6.0f;
        CGFloat tagPadV = 2.0f;
        CGSize lblSize = [self.verifiedTagLbl sizeThatFits:CGSizeMake(120.0f, 20.0f)];
        self.verifiedTagLbl.frame = CGRectMake(tagPadH, tagPadV, lblSize.width, lblSize.height);
        self.verifiedTagView.frame = CGRectMake(0, 0, lblSize.width + tagPadH * 2, lblSize.height + tagPadV * 2);
        CGFloat anchorRight = self.verifiedCheckImgView.hidden ? self.nameLbl.lim_right : self.verifiedCheckImgView.lim_right;
        self.verifiedTagView.lim_left = anchorRight + 6.0f;
        self.verifiedTagView.lim_top = self.nameLbl.lim_top + (self.nameLbl.lim_height - self.verifiedTagView.lim_height) / 2.0f;
    }

    self.shortNoLbl.lim_left = textLeft;
    self.shortNoLbl.lim_top = self.nameLbl.lim_bottom + 2.0f;

    if(!self.copyBtn.hidden) {
        self.copyBtn.lim_left = self.shortNoLbl.lim_right + 4.0f;
        self.copyBtn.lim_top = self.shortNoLbl.lim_top + (self.shortNoLbl.lim_height - self.copyBtn.lim_height) / 2.0f;
    }

    // 第三行：在线圆点 + 状态文本
    self.onlineDot.lim_left = textLeft;
    self.onlineDot.lim_top = self.shortNoLbl.lim_bottom + 6.0f + (self.statusLbl.lim_height - self.onlineDot.lim_height) / 2.0f;
    self.statusLbl.lim_left = self.onlineDot.lim_right + 5.0f;
    self.statusLbl.lim_top = self.shortNoLbl.lim_bottom + 6.0f;

    self.arrowImgView.lim_left = self.cardView.lim_width - padding - self.arrowImgView.lim_width;
    self.arrowImgView.lim_top = (self.cardView.lim_height - self.arrowImgView.lim_height) / 2.0f;
}

#pragma mark - 事件

- (void)copyShortNo {
    NSString *shortNo = [WKApp shared].loginInfo.extra[@"short_no"];
    if(shortNo.length <= 0) return;
    UIPasteboard.generalPasteboard.string = shortNo;
    UIViewController *vc = [WKNavigationManager shared].topViewController;
    if(vc.view) {
        [vc.view showMsg:LLang(@"已复制")];
    }
}

- (void)serverSettingLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIViewController *vc = [WKNavigationManager shared].topViewController;
        if (vc) {
            [WKServerSettingHelper showServerSettingAlertInViewController:vc];
        }
    }
}

-(void) meInfoPressed{
    [[WKNavigationManager shared] pushViewController:[WKMeInfoVC new] animated:YES];
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}

@end
