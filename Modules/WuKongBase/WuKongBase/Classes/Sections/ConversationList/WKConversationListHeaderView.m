//
//  WKConversationListHeaderView.m
//  WuKongBase
//
//  Created by tt on 2021/9/17.
//

#import "WKConversationListHeaderView.h"
#import "WuKongBase.h"
#import "WKSearchbarView.h"
#import "WKGlobalSearchResultController.h"
#import "WKPCOnlineVC.h"
#define networkErrorViewHeight 50.0f

@interface WKConversationListHeaderView ()

@property(nonatomic,strong) UIView *contentView;

@property(nonatomic,assign) BOOL showEmpty; // 是否显示空白部分

// ---------- 网络错误 ----------
@property(nonatomic,strong) UIView *networkErroView; // 网络错误视图
@property(nonatomic,strong) UILabel *warnLbl;

// ---------- 搜索bar ----------
@property(nonatomic,strong) UIView *searchbarBoxView;
@property(nonatomic,strong) WKSearchbarView *searchbarView;

// ---------- pc在线 ----------

@property(nonatomic,strong) WKPCOnlineBarView *pcOnlineBarView;



@end

@implementation WKConversationListHeaderView

- (instancetype)init
{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 0.0f)];
    if (self) {
        [self setupUI];
    }
    return self;
}

-(void) setupUI {
    [self addSubview:self.contentView];
    
    [self.searchbarBoxView addSubview:self.searchbarView];
    [self.contentView addSubview:self.searchbarBoxView];
    self.searchbarView.lim_centerX_parent = self.searchbarBoxView;
    
    _showEmpty = true;
    [self.contentView addSubview:self.tableHeaderBottomEmptyView];
    
}

- (void)viewConfigChange:(WKViewConfigChangeType)type{
    if([WKApp shared].config.style == WKSystemStyleDark) {
        self.networkErroView.backgroundColor = [UIColor colorWithRed:115.0f/255.0f green:46.0f/255.0f blue:43.0f/255.0f alpha:1.0f];
        self.warnLbl.textColor = [UIColor colorWithRed:142.0f/255.0f green:142.0f/255.0f blue:142.0f/255.0f alpha:1.0f];
    }else{
        self.warnLbl.textColor = [UIColor colorWithRed:231.0f/255.0f green:88.0f/255.0f blue:73.0f/255.0f alpha:1.0f];
        self.networkErroView.backgroundColor = [UIColor colorWithRed:251.0f/255.0f green:234.0f/255.0f blue:231.0f/255.0f alpha:1.0f];
    }
    [self.pcOnlineBarView setBackgroundColor:[WKApp shared].config.backgroundColor];
}

- (void)setShowEmpty:(BOOL)showEmpty {
    if(_showEmpty == showEmpty) {
        return;
    }
    _showEmpty = showEmpty;
    
    [self.tableHeaderBottomEmptyView removeFromSuperview];
    if(showEmpty) {
        [self.contentView addSubview:self.tableHeaderBottomEmptyView];
    }
    [self layoutSubviews];
}

- (void)setShowNetworkError:(BOOL)showNetworkError {
    if(_showNetworkError == showNetworkError) {
        return;
    }
    _showNetworkError = showNetworkError;
    
    [self.networkErroView removeFromSuperview];
    
    self.showEmpty = !showNetworkError;
    if(showNetworkError) {
        self.showEmpty = false;
        [self.contentView addSubview:self.networkErroView];
    }else{
        self.showEmpty = true;
    }
    if([WKApp shared].config.style == WKSystemStyleDark) {
        self.networkErroView.backgroundColor = [UIColor colorWithRed:115.0f/255.0f green:46.0f/255.0f blue:43.0f/255.0f alpha:1.0f];
        self.warnLbl.textColor = [UIColor colorWithRed:142.0f/255.0f green:142.0f/255.0f blue:142.0f/255.0f alpha:1.0f];
    }else{
        self.warnLbl.textColor = [UIColor colorWithRed:231.0f/255.0f green:88.0f/255.0f blue:73.0f/255.0f alpha:1.0f];
        self.networkErroView.backgroundColor = [UIColor colorWithRed:251.0f/255.0f green:234.0f/255.0f blue:231.0f/255.0f alpha:1.0f];
    }
    [self layoutSubviews];
}

- (void)setShowPCOnline:(BOOL)showPCOnline {
    if(_showPCOnline == showPCOnline) {
        return;
    }
    _showPCOnline = showPCOnline;
    
    [self.pcOnlineBarView removeFromSuperview];
    if(showPCOnline) {
        self.showEmpty = false;
        self.pcOnlineBarView.tipLbl.text = [NSString stringWithFormat:LLang(@"%@%@已经登录"),[WKOnlineStatusManager.shared deviceName:self.pcDeviceFlag],[WKApp shared].config.appName];
        [self.pcOnlineBarView.tipLbl sizeToFit];
        [self.contentView addSubview:self.pcOnlineBarView];
    }else{
        self.showEmpty = true;
    }
    [self layoutSubviews];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    NSArray *subviews = self.contentView.subviews;
    
    UIView *preView;
    for (UIView *view in subviews) {
        if(!preView) {
            view.lim_top = 10.0f;
        }else {
            view.lim_top = preView.lim_bottom;
        }
        view.lim_centerX_parent = self.contentView;
        preView = view;
    }
    self.contentView.lim_height = preView.lim_bottom;
    self.lim_size = self.contentView.lim_size;
}

- (UIView *)networkErroView {
    if(!_networkErroView) {
        _networkErroView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, networkErrorViewHeight)];
        UIImageView *warnIcon = [[UIImageView alloc] initWithFrame:CGRectMake(20.0f, 0.0f, 26.0f, 26.0f)];
        [warnIcon setImage:[self imageName:@"ConversationList/Index/NetworkStatusFail"]];
        warnIcon.lim_top = _networkErroView.lim_height/2.0f - warnIcon.lim_height/2.0f;
        [_networkErroView addSubview:warnIcon];
        
         _warnLbl = [[UILabel alloc] init];
        [_warnLbl setText:LLang(@"当前网络不可用，请检查网络设置")];
        [_warnLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
        [_warnLbl sizeToFit];
        _warnLbl.lim_top = _networkErroView.lim_height/2.0f - _warnLbl.lim_height/2.0f;
        _warnLbl.lim_left = warnIcon.lim_right + 20.0f;
        [_networkErroView addSubview:_warnLbl];
    }
    return _networkErroView;
}

- (WKSearchbarView *)searchbarView {
    if(!_searchbarView) {
        _searchbarView = [[WKSearchbarView alloc] initWithFrame:CGRectMake(15.0f, 0.0f, WKScreenWidth - 30.0f, 36.0f)];
        _searchbarView.placeholder = LLang(@"搜索");
        _searchbarView.onClick = ^{
            WKGlobalSearchResultController *vc = [WKGlobalSearchResultController new];
            [[WKNavigationManager shared] pushViewController:vc animated:NO];
        };
        
    }
    return _searchbarView;
}

- (UIView *)tableHeaderBottomEmptyView {
    if(!_tableHeaderBottomEmptyView) {
        _tableHeaderBottomEmptyView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 10.0f)];
        [_tableHeaderBottomEmptyView setBackgroundColor:[UIColor whiteColor]];
    }
    return _tableHeaderBottomEmptyView;
   
}

- (UIView *)searchbarBoxView {
    if(!_searchbarBoxView) {
        _searchbarBoxView = [[UIView alloc] init];
        _searchbarBoxView.lim_size = CGSizeMake(self.searchbarView.bounds.size.width, self.searchbarView.bounds.size.height + 10.0f);
    }
    return _searchbarBoxView;
}

- (UIView *)contentView {
    if(!_contentView) {
        _contentView = [[UIView alloc] init];
        _contentView.lim_size = self.lim_size;
    }
    return _contentView;
}

- (WKPCOnlineBarView *)pcOnlineBarView {
    if(!_pcOnlineBarView) {
        _pcOnlineBarView = [[WKPCOnlineBarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 48.0f)];
        [_pcOnlineBarView setBackgroundColor:[WKApp shared].config.backgroundColor];
        _pcOnlineBarView.userInteractionEnabled = YES;
        [_pcOnlineBarView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onPCOnlineTap)]];
    }
    return _pcOnlineBarView;
}

-(void) onPCOnlineTap {
    WKPCOnlineVC *vc = [WKPCOnlineVC new];
    vc.mute = WKOnlineStatusManager.shared.muteOfApp;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

-(UIImage*) imageName:(NSString*)name {
    return LImage(name);
}

@end


@interface WKPCOnlineBarView ()

@property(nonatomic,strong) UIImageView *iconImgView;



@end

@implementation WKPCOnlineBarView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.iconImgView];
        [self addSubview:self.tipLbl];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.iconImgView.lim_left = 32.0f;
    self.iconImgView.lim_centerY_parent = self;
    
    self.tipLbl.lim_left = self.iconImgView.lim_right + 28.0f;
    self.tipLbl.lim_centerY_parent = self;
    
    
}

- (UIImageView *)iconImgView {
    if(!_iconImgView) {
        _iconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 20.0f, 20.0f)];
        _iconImgView.image = [self imageName:@"ConversationList/Index/PCOnline"];
    }
    return _iconImgView;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] init];
        _tipLbl.textColor = [UIColor grayColor];
        _tipLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
    }
    return _tipLbl;
}


-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
