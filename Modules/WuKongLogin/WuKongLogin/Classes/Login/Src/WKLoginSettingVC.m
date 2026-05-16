//
//  WKSettingVC.m
//  WuKongLogin
//
//  Created by tt on 2023/7/22.
//

#import "WKLoginSettingVC.h"

@interface WKLoginSettingVC ()

@property(nonatomic,strong) UILabel *schemeLbl;
@property(nonatomic,strong) UISegmentedControl *schemeSegmentedCtrl;

@property(nonatomic,strong) UILabel *serverAddrLbl;
@property(nonatomic,strong) UITextField *serverAddrFd; // 服务器地址

@property(nonatomic,strong) UILabel *portLbl;  // 端口
@property(nonatomic,strong) UITextField *portFd; // 服务器端口

@property(nonatomic,strong) UIButton *okBtn;

@property(nonatomic,strong) UIButton *resetBtn; // 重置

@end

@implementation WKLoginSettingVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = LLang(@"服务器配置");
    
    self.view.backgroundColor = WKApp.shared.config.backgroundColor;
    
    // scheme
    [self.view addSubview:self.schemeLbl];
    [self.view addSubview:self.schemeSegmentedCtrl];
    
    // serverAddr
    [self.view addSubview:self.serverAddrLbl];
    [self.view addSubview:self.serverAddrFd];
    
    // port
    [self.view addSubview:self.portLbl];
    [self.view addSubview:self.portFd];
    
    [self.view addSubview:self.okBtn];
    [self.view addSubview:self.resetBtn];
    
    [self layout];
    
    NSUserDefaults *userDefaults =[NSUserDefaults standardUserDefaults];
    NSString *serverIP = [userDefaults objectForKey:@"server_ip"];
    if(serverIP && ![serverIP isEqualToString:@""]) {
        self.serverAddrFd.text = serverIP;
        self.portFd.text = [userDefaults objectForKey:@"server_port"];
        
        BOOL serverHttps = [userDefaults boolForKey:@"server_https"];
        if(serverHttps) {
            self.schemeSegmentedCtrl.selectedSegmentIndex = 1;
        }else {
            self.schemeSegmentedCtrl.selectedSegmentIndex = 0;
        }
    }
}

-(void) layout {
    
    CGFloat labelToFdSpace = 20.0f;
    CGFloat leftSpace = 10.0f;
    CGFloat topSpace =30.0f;
    
    CGFloat valueWidth = 180.0f;
    
    self.schemeLbl.lim_top = WKApp.shared.config.visibleEdgeInsets.top + 80.0f;
    self.schemeLbl.lim_left = leftSpace;
    
    self.schemeSegmentedCtrl.lim_left = self.schemeLbl.lim_right + labelToFdSpace;
    self.schemeSegmentedCtrl.lim_top = self.schemeLbl.lim_top - 8.0f;
    
    self.serverAddrLbl.lim_left = leftSpace;
    self.serverAddrLbl.lim_top = self.schemeLbl.lim_bottom + topSpace;
    
    self.serverAddrFd.lim_left = self.serverAddrLbl.lim_right + labelToFdSpace;
    self.serverAddrFd.lim_top = self.serverAddrLbl.lim_top - 8.0f;
    self.serverAddrFd.lim_size = CGSizeMake(valueWidth, 40.0f);
    
    self.portLbl.lim_left = leftSpace;
    self.portLbl.lim_top = self.serverAddrLbl.lim_bottom + topSpace;
    
    self.portFd.lim_left = self.portLbl.lim_right + labelToFdSpace;
    self.portFd.lim_top = self.portLbl.lim_top - 8.0f;
    self.portFd.lim_size = CGSizeMake(valueWidth, 40.0f);
    
    self.okBtn.lim_top = self.portLbl.lim_bottom + 80.0f;
    self.okBtn.lim_centerX_parent = self.view;
    
    self.resetBtn.lim_top = self.okBtn.lim_bottom + 20.0f;
    self.resetBtn.lim_centerX_parent = self.view;
}

- (UILabel *)schemeLbl {
    if(!_schemeLbl) {
        _schemeLbl = [[UILabel alloc] init];
        _schemeLbl.text = LLang(@"协议");
        _schemeLbl.lim_width = 100.0f;
        _schemeLbl.lim_height = 20.0f;
    }
    return _schemeLbl;
}

- (UISegmentedControl *)schemeSegmentedCtrl {
    if(!_schemeSegmentedCtrl) {
        _schemeSegmentedCtrl = [[UISegmentedControl alloc] initWithItems:@[@"http",@"https"]];
        _schemeSegmentedCtrl.selectedSegmentIndex = 0;
        
    }
    return _schemeSegmentedCtrl;
}


- (UILabel *)serverAddrLbl {
    if(!_serverAddrLbl) {
        _serverAddrLbl = [[UILabel alloc] init];
        _serverAddrLbl.text = LLang(@"服务器地址");
        _serverAddrLbl.lim_width = 100.0f;
        _serverAddrLbl.lim_height = 20.0f;
    }
    return _serverAddrLbl;
}

- (UITextField *)serverAddrFd {
    if(!_serverAddrFd) {
        _serverAddrFd = [[UITextField alloc] init];
        _serverAddrFd.placeholder = @"127.0.0.1";
    }
    return _serverAddrFd;
}

- (UILabel *)portLbl {
    if(!_portLbl) {
        _portLbl = [[UILabel alloc] init];
        _portLbl.text = LLang(@"端口");
        _portLbl.lim_width = 100.0f;
        _portLbl.lim_height = 20.0f;
    }
    return _portLbl;
}

- (UITextField *)portFd {
    if(!_portFd) {
        _portFd = [[UITextField alloc] init];
        _portFd.placeholder = @"8090";
    }
    return _portFd;
}

- (UIButton *)okBtn {
    if(!_okBtn) {
        _okBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.lim_width - 80.0f, 50.0f)];
        [_okBtn setTitle:LLang(@"提交") forState:UIControlStateNormal];
        _okBtn.backgroundColor = WKApp.shared.config.themeColor;
        _okBtn.layer.masksToBounds = YES;
        _okBtn.layer.cornerRadius = 4.0f;
        [_okBtn addTarget:self action:@selector(okPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _okBtn;
}

-(UIButton*) resetBtn {
    if(!_resetBtn) {
        _resetBtn = [[UIButton alloc] init];
        [_resetBtn setTitle:LLang(@"重置配置") forState:UIControlStateNormal];
        [[_resetBtn titleLabel] setFont:[WKApp.shared.config appFontOfSize:15.0f]];
        [_resetBtn setTitleColor:WKApp.shared.config.defaultTextColor forState:UIControlStateNormal];
        [_resetBtn sizeToFit];
        [_resetBtn addTarget:self action:@selector(resetPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _resetBtn;
}

-(void) okPressed {
    NSUserDefaults *userDefaults =[NSUserDefaults standardUserDefaults];
    if([[self.serverAddrFd.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""]) {
        [userDefaults setObject:@"127.0.0.1" forKey:@"server_ip"];
    }else{
        [userDefaults setObject:[self.serverAddrFd.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:@"server_ip"];
    }
    if(self.schemeSegmentedCtrl.selectedSegmentIndex == 1) {
        [userDefaults setBool:YES forKey:@"server_https"];
    }else{
        [userDefaults setBool:NO forKey:@"server_https"];
    }
    
    if([[self.portFd.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""]) {
        [userDefaults setObject:@"8090" forKey:@"server_port"];
    }else {
        [userDefaults setObject:[self.portFd.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:@"server_port"];
    }
    
    [userDefaults synchronize];
    
    [self.class setAppConfigIfNeed];
    
    [WKNavigationManager.shared popViewControllerAnimated:YES];
}

-(void) resetPressed {
    NSUserDefaults *userDefaults =[NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey:@"server_ip"];
    [userDefaults removeObjectForKey:@"server_https"];
    [userDefaults removeObjectForKey:@"server_port"];
    [userDefaults synchronize];
    
    self.serverAddrFd.text = @"";
    self.portFd.text = @"";
    self.schemeSegmentedCtrl.selectedSegmentIndex = 0;
    
    [self.view showHUDWithHide:LLang(@"重置成功！，请重启APP。")];
}

+(void) setAppConfigIfNeed {
    NSUserDefaults *userDefaults =[NSUserDefaults standardUserDefaults];
    NSString *serverIP = [userDefaults objectForKey:@"server_ip"];
    if(serverIP && ![serverIP isEqualToString:@""]) {
        NSString *serverPort = [userDefaults objectForKey:@"server_port"];
        BOOL serverHttps = [userDefaults boolForKey:@"server_https"];
        NSString *serverAddr = @"http://";
        if(serverHttps) {
            serverAddr = @"https://";
        }
        serverAddr = [NSString stringWithFormat:@"%@%@:%@",serverAddr,serverIP,serverPort];
        NSString *apiAddr =  [NSString stringWithFormat:@"%@/v1/",serverAddr];
        NSString *webURL = [NSString stringWithFormat:@"%@/web/",serverAddr];
        
        WKAppConfig *config = WKApp.shared.config;
        config.apiBaseUrl = apiAddr; // api地址
        config.fileBaseUrl = apiAddr; // 文件上传地址
        config.fileBrowseUrl = apiAddr; // 文件预览地址
        config.imageBrowseUrl = apiAddr; // 图片预览地址
        config.reportUrl = [NSString stringWithFormat:@"%@report/html",serverAddr]; //举报地址
        config.privacyAgreementUrl = [NSString stringWithFormat:@"%@privacy_policy.html",webURL]; //隐私协议
        config.userAgreementUrl = [NSString stringWithFormat:@"%@user_agreement.html",webURL]; //用户协议
        
        WKAPIClientConfig *apiConfig = WKAPIClient.sharedClient.config;
        apiConfig.baseUrl = apiAddr;
        WKAPIClient.sharedClient.config = apiConfig; // 这里目的是重新触发WKAPIClient的setConfig方法
    }
}

@end
