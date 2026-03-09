//
//  WKMeVC2.m
//  WuKongBase
//
//  Created by tt on 2020/6/9.
//

#import "WKMeVC.h"
#import "WKMeInfoVC.h"
@interface WKMeVC ()<WKChannelManagerDelegate>
@property(nonatomic,strong) WKeHeader *meHeader;
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
    // 下面代码为了让tableview充满
    if (@available(iOS 11.0,*)) {
      self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }else{
      self.automaticallyAdjustsScrollViewInsets = NO;
    }
    self.tableView.tableHeaderView = [self meHeader];
    
    [WKSDK.shared.channelManager addDelegate:self];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.meHeader reloadData];
}


- (void)dealloc {
    NSLog(@"WKMeVC dealloc...");
    [WKSDK.shared.channelManager removeDelegate:self];
}


-(CGRect) tableViewFrame {
    return self.view.bounds;
}

// 设置自定义标题
-(void) setCustomTitle:(NSString*)title {
//    self.titleLbl.text = title;
//     [_titleLbl sizeToFit];
    self.title=title;
}



-(WKeHeader*) meHeader {
    if (!_meHeader) {
        _meHeader = [[WKeHeader alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, 240.0f)];
        [_meHeader setBackgroundColor:[UIColor whiteColor]];
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
    [[SDImageCache sharedImageCache] removeImageForKey:WKApp.shared.loginInfo.uid withCompletion:nil];
    WKApp.shared.loginInfo.extra[@"name"] = channelInfo.name;
    [WKApp shared].loginInfo.extra[@"short_no"] = channelInfo.extra[@"short_no"];
    [WKApp shared].loginInfo.extra[@"sex"] = channelInfo.extra[@"sex"];
    [[WKApp shared].loginInfo save];
    
    [self.meHeader reloadData];
}

@end

#define avatarSize 90.0f
@interface WKeHeader ()

@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UIView *avatarBox;
@property(nonatomic,strong) UILabel *nameLbl;
@property(nonatomic,strong) UIImageView *bgImgView;
@property(nonatomic,strong) UIButton *detailBtn;

@end
@implementation WKeHeader

-(instancetype) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        [self addSubview:self.bgImgView];
        [self addSubview:self.avatarBox];
        [self.avatarBox addSubview:self.avatarImgView];
        [self addSubview:self.nameLbl];
        [self addSubview:self.detailBtn];
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
        self.avatarImgView.url = [WKAvatarUtil getAvatar:[WKApp shared].loginInfo.uid];
    }
}

- (UIImageView *)bgImgView {
    if(!_bgImgView) {
        _bgImgView = [[UIImageView alloc] initWithImage:[self imageName:@"Me/Index/MeBackground"]];
        _bgImgView.frame = self.bounds;
    }
    return _bgImgView;
}

- (UIButton *)detailBtn {
    if(!_detailBtn) {
        _detailBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 15.0f, 15.0f)];
        [_detailBtn setImage:[self imageName:@"Me/Index/MeDetail"] forState:UIControlStateNormal];
        _detailBtn.lim_top = 40.0f;
        _detailBtn.lim_left = self.lim_width - 15.0f - _detailBtn.lim_width;
        [_detailBtn addTarget:self action:@selector(meInfoPressed) forControlEvents:UIControlEventTouchUpInside];
        [_detailBtn sizeToFit];
    }
    return _detailBtn;
}

-(void) reloadData {
    self.avatarImgView.url = [WKAvatarUtil getAvatar:[WKApp shared].loginInfo.uid];
    self.nameLbl.textColor = [WKApp shared].config.defaultTextColor;
    self.nameLbl.text = [WKApp shared].loginInfo.extra[@"name"];
    [self.nameLbl sizeToFit];
}

-(WKUserAvatar*) avatarImgView {
    if (!_avatarImgView) {
        CGFloat size = avatarSize;
        _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, size, size)];
        _avatarImgView.userInteractionEnabled = YES;
        _avatarImgView.lim_centerX_parent = self.avatarBox;
        _avatarImgView.lim_centerY_parent = self.avatarBox;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(meInfoPressed)];
        [_avatarImgView addGestureRecognizer:tap];
    }
    return _avatarImgView;
}

- (UIView *)avatarBox {
    if(!_avatarBox) {
        CGFloat size = avatarSize+8.0f;
        _avatarBox = [[UIView alloc] initWithFrame:CGRectMake(self.lim_width/2.0f - size/2.0f, 58.0f, size, size)];
        _avatarBox.layer.masksToBounds = YES;
        _avatarBox.layer.cornerRadius = _avatarBox.lim_width*0.4;
        [_avatarBox setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    }
    return _avatarBox;
}

-(UILabel*) nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
        [_nameLbl setFont:[[WKApp shared].config appFontOfSizeSemibold:20.0f]];
    }
    return _nameLbl;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.nameLbl.lim_top = self.avatarBox.lim_bottom + 15.0f;
    self.nameLbl.lim_left = self.lim_width/2.0f - self.nameLbl.lim_width/2.0f;
    
}

#pragma mark - 事件

-(void) meInfoPressed{
    [[WKNavigationManager shared] pushViewController:[WKMeInfoVC new] animated:YES];
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
