//
//  WKMeVC2.m
//  WuKongBase
//
//  Created by tt on 2020/6/9.
//

#import "WKMeVC.h"
#import "WKMeInfoVC.h"
#import "WKServerSettingHelper.h"
@interface WKMeVC ()<WKChannelManagerDelegate>
@property(nonatomic,strong) WKeHeader *meHeader;
@property(nonatomic,assign) NSTimeInterval lastAppearTime;
@property(nonatomic,strong) UILabel *versionLbl;
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
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 16.0f, 0, 16.0f);
    self.tableView.separatorColor = [WKApp shared].config.lineColor;
    self.tableView.tableHeaderView = [self meHeader];

    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, 60.0f)];
    footerView.backgroundColor = [UIColor clearColor];
    [footerView addSubview:self.versionLbl];
    self.versionLbl.lim_centerX_parent = footerView;
    self.versionLbl.lim_top = 20.0f;
    self.tableView.tableFooterView = footerView;

    [WKSDK.shared.channelManager addDelegate:self];
}

- (UILabel *)versionLbl {
    if(!_versionLbl) {
        _versionLbl = [[UILabel alloc] init];
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *appVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
        NSString *buildNumber = [infoDictionary objectForKey:@"CFBundleVersion"];
        _versionLbl.text = [NSString stringWithFormat:@"%@ · v%@ (%@)", [WKApp shared].config.appName, appVersion, buildNumber];
        _versionLbl.font = [UIFont systemFontOfSize:13.0f];
        _versionLbl.textColor = [WKApp shared].config.tipColor;
        [_versionLbl sizeToFit];
    }
    return _versionLbl;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.meHeader reloadData];
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
    self.tableView.separatorColor = [WKApp shared].config.lineColor;
    [self.meHeader reloadData];
}

-(UITableViewStyle) tableViewStyle {
    return UITableViewStyleInsetGrouped;
}

-(CGRect) tableViewFrame {
    return self.view.bounds;
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
        _meHeader = [[WKeHeader alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, statusBarHeight + 110.0f)];
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
    [[WKApp shared].loginInfo save];

    [self.meHeader reloadData];
}

@end

#define avatarSize 55.0f
@interface WKeHeader ()

@property(nonatomic,strong) UIView *cardView;
@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UILabel *nameLbl;
@property(nonatomic,strong) UILabel *shortNoLbl;
@property(nonatomic,strong) UILabel *statusLbl;
@property(nonatomic,strong) UIView *onlineDot;
@property(nonatomic,strong) UIImageView *arrowImgView;

@end
@implementation WKeHeader

-(instancetype) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        [self addSubview:self.cardView];
        [self.cardView addSubview:self.avatarImgView];
        [self.cardView addSubview:self.nameLbl];
        [self.cardView addSubview:self.shortNoLbl];
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
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKNOTIFY_USER_AVATAR_UPDATE object:nil];
}

-(void) avatarUpdate:(NSNotification*)noti {
    NSDictionary *data = noti.object;
    if(data && data[@"uid"] && [[WKApp shared].loginInfo.uid isEqualToString:data[@"uid"]]) {
        NSLog(@"[Avatar] WKeHeader received avatarUpdate notification");
        WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:[WKApp shared].loginInfo.uid]];
        self.avatarImgView.url = [WKAvatarUtil getAvatar:[WKApp shared].loginInfo.uid cacheKey:info.avatarCacheKey];
    }
}

- (UIView *)cardView {
    if(!_cardView) {
        CGFloat margin = 20.0f;
        CGFloat statusBarHeight = 0;
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = (UIWindowScene *)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
            statusBarHeight = scene.statusBarManager.statusBarFrame.size.height;
        } else {
            statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        }
        _cardView = [[UIView alloc] initWithFrame:CGRectMake(margin, statusBarHeight + 10.0f, self.lim_width - margin * 2, 90.0f)];
        _cardView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        _cardView.layer.cornerRadius = 12.0f;
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
    self.shortNoLbl.textColor = [WKApp shared].config.tipColor;
    self.statusLbl.textColor = [WKApp shared].config.tipColor;

    NSString *name = [WKApp shared].loginInfo.extra[@"name"];
    self.nameLbl.text = name ?: LLang(@"我");
    [self.nameLbl sizeToFit];

    NSString *shortNo = [WKApp shared].loginInfo.extra[@"short_no"];
    if(shortNo && ![shortNo isEqualToString:@""]) {
        self.shortNoLbl.text = [NSString stringWithFormat:@"%@ %@：%@", [WKApp shared].config.appName, LLang(@"号"), shortNo];
    } else {
        self.shortNoLbl.text = @"";
    }
    [self.shortNoLbl sizeToFit];

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
    [self.statusLbl sizeToFit];

    [self setNeedsLayout];
}

-(WKUserAvatar*) avatarImgView {
    if (!_avatarImgView) {
        _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, avatarSize, avatarSize)];
        _avatarImgView.userInteractionEnabled = NO;
    }
    return _avatarImgView;
}

-(UILabel*) nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
        [_nameLbl setFont:[[WKApp shared].config appFontOfSizeSemibold:18.0f]];
    }
    return _nameLbl;
}

-(UILabel*) shortNoLbl {
    if(!_shortNoLbl) {
        _shortNoLbl = [[UILabel alloc] init];
        [_shortNoLbl setFont:[UIFont systemFontOfSize:13.0f]];
        _shortNoLbl.textColor = [WKApp shared].config.tipColor;
    }
    return _shortNoLbl;
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
        [_statusLbl setFont:[UIFont systemFontOfSize:12.0f]];
        _statusLbl.textColor = [WKApp shared].config.tipColor;
    }
    return _statusLbl;
}

-(UIImageView*) arrowImgView {
    if(!_arrowImgView) {
        _arrowImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 7.0f, 12.0f)];
        _arrowImgView.image = [self imageName:@"Common/Index/ArrowRight"];
    }
    return _arrowImgView;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat padding = 16.0f;

    self.avatarImgView.lim_left = padding;
    self.avatarImgView.lim_top = (self.cardView.lim_height - avatarSize) / 2.0f;

    CGFloat textLeft = self.avatarImgView.lim_right + 12.0f;

    self.nameLbl.lim_left = textLeft;
    self.nameLbl.lim_top = self.avatarImgView.lim_top + 2.0f;

    self.shortNoLbl.lim_left = textLeft;
    self.shortNoLbl.lim_top = self.nameLbl.lim_bottom + 4.0f;

    self.onlineDot.lim_left = textLeft;
    self.onlineDot.lim_top = self.shortNoLbl.lim_bottom + 8.0f;

    self.statusLbl.lim_left = self.onlineDot.lim_right + 5.0f;
    self.statusLbl.lim_top = self.onlineDot.lim_top - (self.statusLbl.lim_height - self.onlineDot.lim_height) / 2.0f;

    self.arrowImgView.lim_left = self.cardView.lim_width - padding - self.arrowImgView.lim_width;
    self.arrowImgView.lim_top = (self.cardView.lim_height - self.arrowImgView.lim_height) / 2.0f;
}

#pragma mark - 事件

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
