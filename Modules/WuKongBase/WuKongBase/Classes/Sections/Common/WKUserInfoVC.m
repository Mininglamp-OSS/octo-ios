//
//  WKUserInfoVC.m
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import "WKUserInfoVC.h"
#import "WKUserInfoVM.h"
#import "WKUserAvatar.h"
#import "WKInputVC.h"
#import "WKActionSheetView2.h"
#import "WKWebViewVC.h"
#import "WKCopyLabel.h"
#import "WKConversationVC.h"
#define textToAvatarLeftSpace 10.0f // 文本距头像的左边距离

@interface WKUserInfoVC ()<WKUserInfoVMDelegate,WKChannelManagerDelegate>

// ---------- header ----------
@property(nonatomic,strong) UIView *userHeader;
@property(nonatomic,strong) WKUserAvatar *userAvatarView; // 用户头像
@property(nonatomic,strong) UIImageView *sexImgView; // 性别
@property(nonatomic,strong) WKCopyLabel *nameLbl; // 用户名称（如果有备注就是备注没有就是昵称,最大的名字）
@property(nonatomic,strong) WKUserFieldView *nicknameField; // 用户昵称(如果有备注则隐藏昵称)
@property(nonatomic,strong) WKUserFieldView *shortNoField; // 用户短编号
@property(nonatomic,strong) WKUserFieldView *nameInChannelField; // 群内昵称

@property(nonatomic,strong) UIView *userInfoBoxView; // 右边文字的容器

// ---------- footer ----------
@property(nonatomic,strong) UIView *footerHeader;
@property(nonatomic,strong) UIButton *sendBtn; // 发送消息
@property(nonatomic,strong) UIButton *addFriendBtn; // 添加好友

// ---------- 视频通话 ----------
@property(nonatomic,strong) UIButton *videoCallBtn; // 视频通话ß
@property(nonatomic,strong) videoCallSupportInvoke videocallInvoke;

// ---------- tableFooter ----------
@property(nonatomic,strong) UIView *tableFooterView;
@property(nonatomic,strong) UIView *tipView;
@property(nonatomic,strong) UIImageView *tipAlertImgView;
@property(nonatomic,strong) UILabel *tipLbl;



@end

@implementation WKUserInfoVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKUserInfoVM new];
        self.viewModel.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.videocallInvoke = [[WKApp shared] invoke:WKPOINT_VIDEOCALL_SUPPORT_FNC param:@{@"channel":[WKChannel personWithChannelID:self.uid]}];
    // header
    self.tableView.tableHeaderView = self.userHeader;
    [self.userHeader addSubview:self.userAvatarView];
    [self.userHeader addSubview:self.sexImgView];
    
    [self.userHeader addSubview:self.userInfoBoxView];
    
    // footer
    [self.view addSubview:self.footerHeader];
    if(self.videocallInvoke && ![WKApp.shared isSystemAccount:self.uid]) {
        [self.footerHeader addSubview:self.videoCallBtn];
    }
    [self.footerHeader addSubview:self.sendBtn];
    [self.footerHeader addSubview:self.addFriendBtn];
    
    // tableFooter
    self.tableView.tableFooterView = self.tableFooterView;
    [self.tableFooterView addSubview:self.tipView];
    [self.tipView addSubview:self.tipAlertImgView];
    [self.tipView addSubview:self.tipLbl];
   
   
    self.viewModel.uid = self.uid;
    self.viewModel.fromChannel = self.fromChannel;
    
    [self.viewModel initData];
    
    __weak typeof(self) weakSelf = self;
    [self.viewModel loadPersonChannelInfo:self.uid completion:^{
        [weakSelf refreshData];
    }];
    
    [[WKSDK shared].channelManager addDelegate:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(memberUpdate:) name:WKNOTIFY_GROUP_MEMBERUPDATE object:nil];
}



-(void) memberUpdate:(NSNotification*)notify {
    if(!self.fromChannel) {
        return;
    }
   NSDictionary *dataDict = notify.object;
   NSString *groupNo = dataDict[@"group_no"];
    if(groupNo && [groupNo isEqualToString:self.fromChannel.channelId]) {
        self.viewModel.memberOfMy = [[WKSDK shared].channelManager getMember:self.fromChannel uid:[WKApp shared].loginInfo.uid];
        self.viewModel.memberOfUser = [[WKSDK shared].channelManager getMember:self.fromChannel uid:self.uid];
        [self reloadData];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)dealloc {
    [[WKSDK shared].channelManager removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKNOTIFY_GROUP_MEMBERUPDATE object:nil];
}

// 获取需要显示的名字（如果有备注显示备注，没备注显示昵称）
-(NSString *) getShowName {
    if(self.viewModel.channelInfo.remark && ![self.viewModel.channelInfo.remark isEqualToString:@""]) {
        return self.viewModel.channelInfo.remark;
    }
    return self.viewModel.channelInfo.name;
}
// 刷新数据
-(void) refreshData {
    [self reloadData];
    
    if(self.viewModel.channelInfo) {
        self.userAvatarView.hidden = NO;
        self.footerHeader.hidden = NO;
    }
    
    [self.userInfoBoxView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    [self.userInfoBoxView addSubview:self.nameLbl];
    if(self.viewModel.channelInfo.remark && ![self.viewModel.channelInfo.remark isEqualToString:@""]) {
        self.nameLbl.text = self.viewModel.channelInfo.remark;
        self.nicknameField.hidden = NO;
        self.nicknameField.value = self.viewModel.channelInfo.name;
         [self.userInfoBoxView addSubview:self.nicknameField];
    }else {
        self.nameLbl.text = self.viewModel.channelInfo.name;
        self.nicknameField.hidden = YES;
    }
    [self.nameLbl sizeToFit];
    if(self.viewModel.memberOfUser && self.viewModel.memberOfUser.memberRemark && ![self.viewModel.memberOfUser.memberRemark isEqualToString:@""]) {
        self.nameInChannelField.value = self.viewModel.memberOfUser.memberRemark;
        self.nameInChannelField.hidden = NO;
        [self.userInfoBoxView addSubview:self.nameInChannelField];
    }else {
         self.nameInChannelField.hidden = YES;
    }
    // 悟空IM号
    NSString *shortNo = self.viewModel.channelInfo.extra[@"short_no"];
    self.shortNoField.value = shortNo?:@"";
    
    BOOL showShortNo = [self isFriend] || ![self forbiddenAddFriend] || [self isGroupManager];
    if(self.viewModel.isBlacklist && ![self isFriend]) { // 在黑名单内非好友一律不显示短号
        showShortNo = false;
    }
    if([shortNo isEqualToString:@""]) {
        showShortNo = false;
    }
    
    if(showShortNo) {
        [self.userInfoBoxView addSubview:self.shortNoField];
    }
    
    NSNumber *sex = self.viewModel.channelInfo.extra[@"sex"];
    if(sex && [sex integerValue] == 0) {
        [self.sexImgView setImage:[self imageName:@"Common/Index/SexWoman"]];
    }else {
        [self.sexImgView setImage:[self imageName:@"Common/Index/SexMan"]];
    }
    self.sendBtn.hidden = NO;
    if([self isSelf]) {
        self.footerHeader.hidden = YES;
    }else if([self isFriend]) {
        self.sendBtn.hidden = NO;
        self.addFriendBtn.hidden = YES;
    }else if(self.viewModel.channelInfo.follow == WKChannelInfoFollowStrange){
        self.sendBtn.hidden = YES;
        self.footerHeader.hidden = ![self hasVercode];
        if(self.viewModel.memberOfMy && (self.viewModel.memberOfMy.role==WKMemberRoleCreator || self.viewModel.memberOfMy.role==WKMemberRoleManager  )) {
            self.footerHeader.hidden = NO;
        }
    }else {
        self.footerHeader.hidden = YES;
    }

    
    if(self.viewModel.fromChannelInfo && ![self isFriend] && [self forbiddenAddFriend] && ![self isGroupManager]) {
        self.footerHeader.hidden = YES;
    }
    
    if(self.viewModel.channelInfo.status == WKChannelStatusBlacklist) {
        self.tipView.hidden = NO;
    }else {
         self.tipView.hidden = YES;
    }

    
    [self layoutUI];
}

-(BOOL) hasVercode {
    return self.vercode && ![self.vercode isEqualToString:@""];
}

- (NSString *)vercode {
    if(!_vercode || [_vercode isEqualToString:@""]) {
        _vercode = [self.viewModel.channelInfo extraValueForKey:WKChannelExtraKeyVercode];
    }
    return _vercode;
}

-(BOOL) isSelf {
    if([self.uid isEqualToString:[WKApp shared].loginInfo.uid]) {
        return true;
    }
    return false;
}

// 禁止群内添加好友
-(BOOL) forbiddenAddFriend {
    return self.viewModel.fromChannelInfo && self.viewModel.fromChannelInfo.extra[@"forbidden_add_friend"]?[self.viewModel.fromChannelInfo.extra[@"forbidden_add_friend"] boolValue]:false;
}

// 当前用户是否是群管理者（群主或群管理）
-(BOOL) isGroupManager {
    return self.viewModel.memberOfMy && (self.viewModel.memberOfMy.role == WKMemberRoleCreator || self.viewModel.memberOfMy.role == WKMemberRoleManager);
}

// 是否有是好友
-(BOOL) isFriend {
    return self.viewModel.channelInfo.follow == WKChannelInfoFollowFriend;
}
#define textTopSpace 5.0f
-(void) layoutUI {
    UIView *preView;
    for (UIView *view in self.userInfoBoxView.subviews) {
        if(!preView) {
            if(self.userInfoBoxView.subviews.count == 1) {
                view.lim_top = self.userAvatarView.lim_top + (self.userAvatarView.lim_height/2.0f - view.lim_height/2.0f);
            }else if(self.userInfoBoxView.subviews.count>2 && self.userInfoBoxView.subviews.count<4) {
                view.lim_top = self.userAvatarView.lim_top;
            } else if(self.userInfoBoxView.subviews.count>=4) {
                view.lim_top = self.userAvatarView.lim_top - textTopSpace;
            } else {
                view.lim_top = self.userAvatarView.lim_top + textTopSpace;
            }
            
        }else {
             view.lim_top = preView.lim_bottom + textTopSpace;
        }
        preView = view;
    }
    self.sexImgView.lim_left = self.nameLbl.lim_right + 5.0f + self.userAvatarView.lim_right + textToAvatarLeftSpace;
    self.sexImgView.lim_top = self.nameLbl.lim_top + 4.0f;
    if(preView) {
        self.userInfoBoxView.lim_height = preView.lim_bottom;
    }
}


// ---------- header ----------

- (UIView *)userHeader {
    if(!_userHeader) {
        _userHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, 120.0f)];
    }
    return _userHeader;
}

- (WKUserAvatar *)userAvatarView {
    if(!_userAvatarView) {
        _userAvatarView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 64.0f, 64.0f)];
        [_userAvatarView setUrl:[WKAvatarUtil getAvatar:self.uid]];
        _userAvatarView.lim_left = 20.0f;
        _userAvatarView.lim_top = self.userHeader.lim_height/2.0f - _userAvatarView.lim_height/2.0f;
        _userAvatarView.hidden = YES;
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
    data.imageURL = [NSURL URLWithString:[WKAvatarUtil getAvatar:self.uid]];
    data.projectiveView = imgView.avatarImgView;
    
    imageBrowser.dataSourceArray = @[data];
    
    [imageBrowser show];
    
}

- (UIImageView *)sexImgView {
    if(!_sexImgView) {
        _sexImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 16.0f, 16.0f)];
    }
    return _sexImgView;
}

- (WKCopyLabel *)nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[WKCopyLabel alloc] initWithFrame:CGRectMake(0.0f, self.userAvatarView.lim_top-5.0f, [self textMaxWidth], 20.0f)];
        _nameLbl.copyEnabled = YES;
        [_nameLbl setTextColor:[WKApp shared].config.defaultTextColor];
        [_nameLbl setFont:[[WKApp shared].config appFontOfSize:17.0f]];
    }
    return _nameLbl;
}

- (WKUserFieldView *)nicknameField {
    if(!_nicknameField) {
        _nicknameField = [[WKUserFieldView alloc] initWithField:LLang(@"昵称")];
        _nicknameField.frame = CGRectMake(0.0f, self.nameLbl.lim_bottom+5.0f, [self textMaxWidth], 17.0f);
    }
    return _nicknameField;
}

- (WKUserFieldView *)shortNoField {
    if(!_shortNoField) {
        _shortNoField = [[WKUserFieldView alloc] initWithField:[NSString stringWithFormat:@"%@号",[WKApp shared].config.appName]];
        _shortNoField.frame = CGRectMake(0.0f, self.nicknameField.lim_bottom+5.0f, [self textMaxWidth], 17.0f);
    }
    return _shortNoField;
}

- (WKUserFieldView *)nameInChannelField {
    if(!_nameInChannelField) {
        _nameInChannelField = [[WKUserFieldView alloc] initWithField:LLang(@"群昵称")];
        _nameInChannelField.frame = CGRectMake(0.0f, 0.0f, [self textMaxWidth], 17.0f);
        _nameInChannelField.hidden = YES;
    }
    return _nameInChannelField;
}
- (UIView *)userInfoBoxView {
    if(!_userInfoBoxView) {
        _userInfoBoxView = [[UIView alloc] initWithFrame:CGRectMake([self textLeftSpace], 0.0f, [self textMaxWidth], 0.0f)];
    }
    return _userInfoBoxView;
}

-(CGFloat) textLeftSpace {
    return textToAvatarLeftSpace + self.userAvatarView.lim_right;
}

-(CGFloat) textMaxWidth {
    return self.view.lim_width - self.userAvatarView.lim_right + textToAvatarLeftSpace;
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    if(type == WKViewConfigChangeTypeStyle) {
        self.footerHeader.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    }
    
}

// ---------- footer ----------
- (UIView *)footerHeader {
    if(!_footerHeader) {
        CGFloat height = 70.0f;
        CGFloat bottom = 0;
        if (@available(iOS 11.0, *)) {
            bottom = [[UIApplication sharedApplication].keyWindow safeAreaInsets].bottom;
        }
        _footerHeader = [[UIView alloc] initWithFrame:CGRectMake(0.0f,WKScreenHeight - (height+bottom), self.view.lim_width, height+bottom)];
        [_footerHeader setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        _footerHeader.hidden = YES;
    }
    return _footerHeader;
}
#define bottomBtnSpace 20.0f
- (UIButton *)sendBtn {
    if(!_sendBtn) {
        CGFloat width = self.view.lim_width - bottomBtnSpace*2;
        CGFloat leftSpace = self.footerHeader.lim_width/2.0f - width/2.0f;
        if(self.videocallInvoke) {
            width = (self.view.lim_width - bottomBtnSpace*3)/2.0f;
            leftSpace = self.videoCallBtn.lim_right + bottomBtnSpace;
        }
        _sendBtn = [[UIButton alloc] initWithFrame:CGRectMake(leftSpace, 0.0f, width, 40.0f)];
        [_sendBtn setBackgroundColor:[WKApp shared].config.themeColor];
        [[_sendBtn titleLabel] setFont:[[WKApp shared].config appFontOfSize:16.0f]];
        [_sendBtn setTitle:LLang(@"发消息") forState:UIControlStateNormal];
        [_sendBtn setImage:[self imageName:@"Common/Index/IconMsg"] forState:UIControlStateNormal];
        [_sendBtn setImageEdgeInsets:UIEdgeInsetsMake(2.0f, 0.0f, 0.0f, 4.0f)];
        _sendBtn.layer.masksToBounds = YES;
        _sendBtn.layer.cornerRadius = 4.0f;
        _sendBtn.lim_top = 15.0f;
        [_sendBtn addTarget:self action:@selector(sendBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _sendBtn;
}

- (UIButton *)videoCallBtn {
    if(!_videoCallBtn) {
        CGFloat width = (self.view.lim_width - bottomBtnSpace*3)/2.0f;
        CGFloat leftSpace = bottomBtnSpace;
        _videoCallBtn = [[UIButton alloc] initWithFrame:CGRectMake(leftSpace, 15.0f, width, 40.0f)];
        [_videoCallBtn setBackgroundColor:[UIColor colorWithRed:243.0f/255.0f green:243.0f/255.0f blue:243.0f/255.0f alpha:1.0f]];
        [[_videoCallBtn titleLabel] setFont:[[WKApp shared].config appFontOfSize:16.0f]];
        [_videoCallBtn setTitle:LLang(@"视频通话") forState:UIControlStateNormal];
         [_videoCallBtn setImage:[self imageName:@"Common/Index/IconVideocall"] forState:UIControlStateNormal];
         [_videoCallBtn setImageEdgeInsets:UIEdgeInsetsMake(2.0f, 0.0f, 0.0f, 4.0f)];
         _videoCallBtn.layer.masksToBounds = YES;
         _videoCallBtn.layer.cornerRadius = 4.0f;
        if([WKApp shared].config.style == WKSystemStyleDark) {
            [_videoCallBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        }else{
            [_videoCallBtn setTitleColor:[WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
        }
       
         [_videoCallBtn addTarget:self action:@selector(videocallBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _videoCallBtn;
}


-(UIButton*) addFriendBtn {
    if(!_addFriendBtn) {
        _addFriendBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.lim_width - 40.0f, 40.0f)];
        [_addFriendBtn setBackgroundColor:[WKApp shared].config.backgroundColor];
        [[_addFriendBtn titleLabel] setFont:[[WKApp shared].config appFontOfSize:16.0f]];
        [_addFriendBtn setTitleColor:[WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
        [_addFriendBtn setTitle:LLang(@"添加好友") forState:UIControlStateNormal];
        [_addFriendBtn setImage:[self imageName:@"Common/Index/AddFriend"] forState:UIControlStateNormal];
        [_addFriendBtn setImageEdgeInsets:UIEdgeInsetsMake(2.0f, 0.0f, 0.0f, 4.0f)];
        _addFriendBtn.layer.masksToBounds = YES;
        _addFriendBtn.layer.cornerRadius = 4.0f;
        _addFriendBtn.lim_left = self.footerHeader.lim_width/2.0f - _addFriendBtn.lim_width/2.0f;
        _addFriendBtn.lim_top = 15.0f;
        [_addFriendBtn addTarget:self action:@selector(addFriendPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _addFriendBtn;
}

// ---------- tip ----------

- (UIView *)tableFooterView {
    if(!_tableFooterView) {
        _tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 44.0f)];
    }
    return _tableFooterView;
}

- (UIView *)tipView {
    if(!_tipView) {
        _tipView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 20.0f, WKScreenWidth, 20.0f)];
        _tipView.hidden = YES;
    }
    return _tipView;
}

- (UIImageView *)tipAlertImgView {
    if(!_tipAlertImgView) {
        _tipAlertImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 16.0f, 16.0f)];
        [_tipAlertImgView setImage:[self imageName:@"Common/Index/Alert"]];
        _tipAlertImgView.lim_top = self.tipView.lim_height/2.0f - _tipAlertImgView.lim_height/2.0f;
        _tipAlertImgView.lim_left = self.tipLbl.lim_left - _tipAlertImgView.lim_width - 5.0f;
    }
    return _tipAlertImgView;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] init];
        [_tipLbl setFont:[[WKApp shared].config appFontOfSize:13.0f]];
        _tipLbl.text =LLang(@"已添加至黑名单，你将不再收到对方的消息");
        _tipLbl.textColor = [UIColor grayColor];
        _tipLbl.numberOfLines = 0;
        _tipLbl.lineBreakMode = NSLineBreakByWordWrapping;
        _tipLbl.lim_width = self.view.lim_width - 80.0f;
        [_tipLbl sizeToFit];
        _tipLbl.lim_top = self.tipView.lim_height/2.0f - _tipLbl.lim_height/2.0f;
        _tipLbl.lim_left =  self.tipView.lim_width/2.0f - _tipLbl.lim_width/2.0f + 8.0f;
    }
    return _tipLbl;
}


#pragma mark -- 事件
// 发送消息
-(void) sendBtnPressed {
    [[WKNavigationManager shared] popToRootViewControllerAnimated:NO];
    WKConversationVC *conversationVC = [WKConversationVC new];
    conversationVC.channel = self.viewModel.channelInfo.channel;
    [[WKNavigationManager shared] pushViewController:conversationVC animated:YES];
}
// 视频通话
-(void) videocallBtnPressed {
    if(self.videocallInvoke) {
        self.videocallInvoke([WKChannel personWithChannelID:self.uid],WKCallTypeAll);
    }
}
// 添加好友
-(void) addFriendPressed {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:LLang(@"你需要发送验证码申请，等对方通过") preferredStyle:UIAlertControllerStyleAlert];
    //增加确定按钮；
    __weak typeof(self) weakSelf = self;
    //增加取消按钮；
    [alertController addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleDefault handler:nil]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:LLang(@"确定") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *remarkFD = alertController.textFields.firstObject;
        [weakSelf.viewModel applyFriend:weakSelf.uid remark:remarkFD.text vercode:self.vercode].then(^{
            [weakSelf.view showHUDWithHide:LLang(@"发送成功！")];
        }).catch(^(NSError *err){
            [weakSelf.view showHUDWithHide:err.domain];
        });
        
    }]];
   
    //定义第一个输入框；
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = [NSString stringWithFormat:LLang(@"我是%@"),[WKApp shared].loginInfo.extra[@"name"]];
    }];
    [self.view.lim_viewController presentViewController:alertController animated:true completion:nil];
}

#pragma mark - WKChannelManagerDelegate

- (void)channelInfoUpdate:(WKChannelInfo *)channelInfo {
    if(self.fromChannel && [self.fromChannel isEqual:channelInfo.channel]) {
        self.viewModel.fromChannelInfo = channelInfo;
        [self refreshData];
    }else if(channelInfo.channel.channelType == WK_PERSON && [channelInfo.channel.channelId isEqualToString:self.uid]) {
        self.viewModel.channelInfo = channelInfo;
        [self refreshData];
    }
}

- (void)channelInfoDelete:(WKChannel *)channel oldChannelInfo:(WKChannelInfo * _Nullable)oldChannelInfo{
    if(channel.channelType == WK_PERSON && [channel.channelId isEqualToString:self.uid]) {
        [[WKSDK shared].channelManager fetchChannelInfo:channel];
    }
}

#pragma mark - WKUserInfoVMDelegate

// 修改备注
- (void)userInfoVMUpdateRemark:(WKUserInfoVM *)vm {
    __weak typeof(self) weakSelf = self;
    WKInputVC *inputVC = [WKInputVC new];
    inputVC.title = LLang(@"修改备注");
    inputVC.maxLength = 10;
    NSString *name = self.viewModel.channelInfo.name;
    if(self.viewModel.channelInfo.remark && ![self.viewModel.channelInfo.remark isEqualToString:@""] ) {
        name = self.viewModel.channelInfo.remark;
    }
    inputVC.defaultValue = name;
    [inputVC setOnFinish:^(NSString * _Nonnull value) {
        [weakSelf.viewModel updateRemark:value?:@""].then(^{
            self.viewModel.channelInfo.remark = value;
            [[WKSDK shared].channelManager updateChannelInfo:self.viewModel.channelInfo];
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
            if(weakSelf.fromChannel) { // 如果是从群进来的则通知更新群成员数据
                 [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_GROUP_MEMBERUPDATE object:nil];
            }
        }).catch(^(NSError *error){
            [[[WKNavigationManager shared] topViewController].view showHUDWithHide:error.domain];
        });
    }];
    [[WKNavigationManager shared] pushViewController:inputVC animated:YES];
}

// 解除好友关系
- (void)userInfoVMFreeFriend:(WKUserInfoVM *)vm {
    __weak typeof(self) weakSelf = self;
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:[NSString stringWithFormat:LLang(@"将联系人“%@”删除，同时删除与该联系人的聊天记录"),[self getShowName]]];
    [sheet addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLangW(@"删除联系人",weakSelf) onClick:^{
        [weakSelf.viewModel deleteFriend].then(^{
            WKChannel *channel = weakSelf.viewModel.channelInfo.channel;
            // 删除频道数据
            [[WKSDK shared].channelManager deleteChannelInfo:channel];
            // 删除最近会很
            [[WKSDK shared].conversationManager deleteConversation:channel];
            // 清除频道消息
            [[WKMessageManager shared] clearMessages:channel];
            [[WKNavigationManager shared] popToRootViewControllerAnimated:YES];
        }).catch(^(NSError *error){
            [[[WKNavigationManager shared] topViewController].view showHUDWithHide:error.domain];
        });
    }]];
    [sheet show];
}

// 添加黑名单
- (void)userInfoVMAddBlacklist:(WKUserInfoVM *)vm {
    __weak typeof(self) weakSelf = self;
     WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:LLang(@"加入黑名单，你将不再收到对方的消息。")];
    [sheet addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLangW(@"确认", weakSelf) onClick:^{
        [self.view showHUD];
        [weakSelf.viewModel addBlacklist].then(^{
            [weakSelf.view hideHud];
            WKChannel *channel = weakSelf.viewModel.channelInfo.channel;
            // 删除最近会很
            [[WKSDK shared].conversationManager deleteConversation:channel];
            // 修改频道为黑名单
            weakSelf.viewModel.channelInfo.status = WKChannelStatusBlacklist;
            [[WKSDK shared].channelManager updateChannelInfo:weakSelf.viewModel.channelInfo];
            [[WKNavigationManager shared] popToRootViewControllerAnimated:YES];
        }).catch(^(NSError *error){
            [weakSelf.view hideHud];
            [[[WKNavigationManager shared] topViewController].view showHUDWithHide:error.domain];
        });
    }]];
    [sheet show];
}

-(void) userInfoVMRemoveBlacklist:(WKUserInfoVM*)vm {
    __weak typeof(self) weakSelf = self;
    [self.view showHUD];
    [weakSelf.viewModel deleteBlacklist].then(^{
        [weakSelf.view hideHud];
        // 修改频道为非黑名单
        WKChannel *channel = weakSelf.viewModel.channelInfo.channel;
         weakSelf.viewModel.channelInfo.status = WKChannelStatusNormal;
        [[WKSDK shared].channelManager updateChannelInfo:weakSelf.viewModel.channelInfo];
        // 恢复最近会话
        [[WKSDK shared].conversationManager recoveryConversation:channel];
        [[WKNavigationManager shared] popToRootViewControllerAnimated:YES];
    }).catch(^(NSError *error){
        [weakSelf.view hideHud];
        [[[WKNavigationManager shared] topViewController].view showHUDWithHide:error.domain];
    });
}

- (void)userInfoVMReport:(WKUserInfoVM *)vm {
    WKWebViewVC *vc = [[WKWebViewVC alloc] init];
    vc.title = LLang(@"投诉");
    vc.url = [NSURL URLWithString:[WKApp shared].config.reportUrl];
    vc.channel = [[WKChannel alloc] initWith:self.uid channelType:WK_PERSON];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}



-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end


@interface WKUserFieldView ()

@property(nonatomic,strong) UILabel *fieldLbl;
@property(nonatomic,strong) WKCopyLabel *valueLbl;
@end

@implementation WKUserFieldView

- (instancetype)initWithField:(NSString *)field {
    WKUserFieldView *v = [WKUserFieldView new];
    v.fieldLbl.text = [NSString stringWithFormat:@"%@：",field];
    [v.fieldLbl sizeToFit];
    return v;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.userInteractionEnabled = YES;
        [self addSubview:self.fieldLbl];
        [self addSubview:self.valueLbl];
    }
    return self;
}

- (void)setValue:(NSString *)value {
    _value = value;
    self.valueLbl.text = value;
    [self.valueLbl sizeToFit];
}



- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.fieldLbl.lim_left = 0.0f;
    self.fieldLbl.lim_height = self.lim_height;
    
    self.valueLbl.lim_left = self.fieldLbl.lim_right;
    self.valueLbl.lim_height = self.lim_height;
    
}

- (UILabel *)fieldLbl {
    if(!_fieldLbl) {
        _fieldLbl = [[UILabel alloc] init];
        [_fieldLbl setFont:[[WKApp shared].config appFontOfSize:13.0f]];
        [_fieldLbl setTextColor:[UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0f]];
    }
    return _fieldLbl;
}

- (WKCopyLabel *)valueLbl {
    if(!_valueLbl) {
        _valueLbl = [[WKCopyLabel alloc] init];
        _valueLbl.copyEnabled = YES;
        [_valueLbl setFont:[[WKApp shared].config appFontOfSize:13.0f]];
        [_valueLbl setTextColor:[UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0f]];
    }
    return _valueLbl;
}

@end
