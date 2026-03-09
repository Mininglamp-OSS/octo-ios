//
//  WKContactsInfoVC.m
//  WuKongContacts
//
//  Created by tt on 2019/12/31.
//

#import "WKContactsInfoVC.h"
#import "WKAvatarUtil.h"
@interface WKContactsInfoVC ()<UITableViewDelegate,UITableViewDataSource>
@property(nonatomic,strong) UITableView *tableView;
@property(nonatomic,strong) WKContactsInfoHeader *contactsInfoHeader;
@property(nonatomic,strong) WKContactsInfoFooter *contactsInfoFooter;
@property(nonatomic,strong) WKContactsInfoVM *contactsInfoVM;
@end

@implementation WKContactsInfoVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.contactsInfoVM = [WKContactsInfoVM new];
    [self.view addSubview:self.tableView];
    [self requestUserInfo];
}

- (NSString *)langTitle {
    return LLang(@"用户详情");
}

-(void)requestUserInfo {
    __weak typeof(self) weakSelf = self;
    [self.contactsInfoVM getUserInfo:self.uid].then(^(WKUserInfoResp *resp){
        [weakSelf.contactsInfoHeader refresh:resp];
        [weakSelf.contactsInfoFooter refresh:resp];
    });
}

-(UITableView*) tableView {
    if(!_tableView) {
        CGFloat tabBarHeight = self.tabBarController.tabBar.frame.size.height;
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.lim_width, self.view.lim_height-tabBarHeight) style:UITableViewStylePlain];
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.tableFooterView = self.contactsInfoFooter;
        _tableView.tableHeaderView = [self contactsInfoHeader];
    }
    return _tableView;
}

-(WKContactsInfoHeader*) contactsInfoHeader {
    if (!_contactsInfoHeader) {
        _contactsInfoHeader = [[WKContactsInfoHeader alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, 80.0f)];
        [_contactsInfoHeader setBackgroundColor:[UIColor whiteColor]];
    }
    return _contactsInfoHeader;
}

-(WKContactsInfoFooter*) contactsInfoFooter {
    if (!_contactsInfoFooter) {
        _contactsInfoFooter = [[WKContactsInfoFooter alloc] init];
    }
    return _contactsInfoFooter;
}

#pragma mark - UITableViewDelegate & UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}
@end


@interface WKContactsInfoHeader ()

@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UILabel *nameLbl;

@end
@implementation WKContactsInfoHeader

-(instancetype) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        [self addSubview:self.avatarImgView];
        [self addSubview:self.nameLbl];
    }
    return self;
}

-(WKUserAvatar*) avatarImgView {
    if (!_avatarImgView) {
        _avatarImgView = [[WKUserAvatar alloc] init];
    }
    return _avatarImgView;
}

-(UILabel*) nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
    }
    return _nameLbl;
}

-(void) refresh:(WKUserInfoResp*)model {
    self.nameLbl.text = model.name;
    [self.nameLbl sizeToFit];
    self.avatarImgView.url = [WKAvatarUtil getFullAvatarWIthPath:model.avatar];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.avatarImgView.lim_size = CGSizeMake(self.lim_size.height - 20.0f, self.lim_size.height - 20.0f);
    self.avatarImgView.lim_top = self.lim_height/2.0f - self.avatarImgView.lim_height/2.0f;
    self.avatarImgView.lim_left = 10.0f;
    
    self.nameLbl.lim_left = self.avatarImgView.lim_right + 10.0f;
    self.nameLbl.lim_centerY = self.avatarImgView.lim_centerY;

}

@end

@interface WKContactsInfoFooter ()
@property(nonatomic,strong) UIButton *addFriendBtn;
@property(nonatomic,strong) WKUserInfoResp *model;
@property(nonatomic,strong) WKContactsInfoVM *contactsInfoVM;
@end

@implementation WKContactsInfoFooter

-(instancetype) init {
    self = [super init];
    if(self) {
        self.frame = CGRectMake(0, 0, WKScreenWidth, 200.0f);
        self.contactsInfoVM = [WKContactsInfoVM new];
        [self addSubview:self.addFriendBtn];
    }
    return self;
}

-(void) refresh:(WKUserInfoResp*)model {
    self.model = model;
}

-(UIButton*) addFriendBtn {
    if(!_addFriendBtn) {
        _addFriendBtn = [[UIButton alloc] initWithFrame:CGRectMake(10.0f, 40.0f, WKScreenWidth - 20.0f, 44.0f)];
        _addFriendBtn.layer.masksToBounds = YES;
        _addFriendBtn.layer.cornerRadius = 10.0f;
        [_addFriendBtn addTarget:self action:@selector(addFriendPressed) forControlEvents:UIControlEventTouchUpInside];
        [_addFriendBtn setBackgroundColor:[UIColor blueColor]];
        [_addFriendBtn setTitle:LLang(@"添加好友") forState:UIControlStateNormal];
    }
    return _addFriendBtn;
}

-(void) addFriendPressed {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:LLang(@"你需要发送验证码申请，等对方通过") preferredStyle:UIAlertControllerStyleAlert];
    //增加确定按钮；
    __weak typeof(self) weakSelf = self;
    //增加取消按钮；
    [alertController addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleDefault handler:nil]];
    //定义第一个输入框；
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = [NSString stringWithFormat:LLang(@"我是%@"),[WKApp shared].loginInfo.extra[@"name"]];
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:LLang(@"确定") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *remarkFD = alertController.textFields.firstObject;
        [weakSelf.contactsInfoVM applyFriend:weakSelf.model.uid remark:remarkFD.text].catch(^(NSError *err){
            [weakSelf showMsg:err.domain];
        });
        
    }]];
   
    [self.lim_viewController presentViewController:alertController animated:true completion:nil];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
}


@end
