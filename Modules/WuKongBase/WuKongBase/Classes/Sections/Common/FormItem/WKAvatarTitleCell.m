//
//  WKAvatarTitleCell.m
//  WuKongBase
//
//  Created by tt on 2022/11/7.
//

#import "WKAvatarTitleCell.h"

@implementation WKAvatarTitleModel

- (Class)cell {
    return WKAvatarTitleCell.class;
}
- (CGFloat)defaultCellHeight {
    return 80.0f;
}
@end

@interface WKAvatarTitleCell ()

@property(nonatomic,strong) WKUserAvatar *userAvatarView;
@property(nonatomic,strong) UILabel *nameLbl;

@end

@implementation WKAvatarTitleCell


- (void)setupUI {
    [super setupUI];
    
    [self.contentView addSubview:self.userAvatarView];
    [self.contentView addSubview:self.nameLbl];
}

- (void)refresh:(WKAvatarTitleModel *)model {
    [super refresh:model];
    
    self.userAvatarView.url = model.avatar;
    self.nameLbl.text = model.name;
    [self.nameLbl sizeToFit];
}


- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.userAvatarView.lim_left = 15.0f;
    self.userAvatarView.lim_centerY_parent = self.contentView;
    
    self.nameLbl.lim_left = self.userAvatarView.lim_right + 10.0f;
    self.nameLbl.lim_centerY_parent = self.contentView;
    
}

- (UILabel *)nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
    }
    return _nameLbl;
}

- (WKUserAvatar *)userAvatarView {
    if(!_userAvatarView) {
        _userAvatarView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 64.0f, 64.0f)];
        _userAvatarView.lim_left = 20.0f;
        _userAvatarView.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarPressed:)];
        [_userAvatarView addGestureRecognizer:tap];
    }
    return _userAvatarView;
}

-(void) avatarPressed:(UIGestureRecognizer*)gesture  {
    WKUserAvatar *imgView = (WKUserAvatar*)gesture.view;
    YBImageBrowser *imageBrowser = [[YBImageBrowser alloc] init];
    imageBrowser.toolViewHandlers = @[WKBrowserToolbar.new];
    imageBrowser.webImageMediator = [WKDefaultWebImageMediator new];
    
    YBIBImageData *data = [YBIBImageData new];
    data.imageURL = [NSURL URLWithString: imgView.url];
    data.projectiveView = imgView.avatarImgView;
    imageBrowser.dataSourceArray = @[data];
    
    [imageBrowser show];
    
}

@end
