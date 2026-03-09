//
//  WKSchemaManager.m
//  WuKongBase
//
//  Created by tt on 2022/4/29.
//

#import "WKSchemaManager.h"
#import "WuKongBase.h"

@interface WKSchemaRequest ()

@property(nonatomic,strong) NSURLComponents *urlComponents;

@end

@implementation WKSchemaRequest

+(WKSchemaRequest*) url:(NSURL*)url {
    WKSchemaRequest *request = [WKSchemaRequest new];
    request.url = url;
    request.urlComponents =  [[NSURLComponents alloc] initWithString:request.url.absoluteString];
    return request;
}

-(BOOL) isAppSchema {
    return [self.url.scheme hasPrefix:[WKApp shared].config.appSchemaPrefix];
}

- (NSDictionary<NSString*,NSString*> *)queryItems {
    NSMutableDictionary *paramDict = [NSMutableDictionary dictionary];
    if(self.urlComponents.queryItems) {
        for (NSURLQueryItem *item in self.urlComponents.queryItems) {
            paramDict[item.name] = item.value;
        }
    }
    return paramDict;
}

@end

@implementation WKSchemaManager

static WKSchemaManager *_instance = nil;
+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone ];
    });
    return _instance;
}

+(instancetype) shared{
    if (_instance == nil) {
        _instance = [[super alloc]init];
        [_instance setup];
    }
    return _instance;
}

-(void) setup {
    
    // 申请加好友
    [self registerHandler:@"ui.friend.apply" handler:^BOOL(WKSchemaRequest * _Nonnull request) {
        if(![request isAppSchema]) {
            return false;
        }
        NSString *host = request.url.host;
        NSString *path = request.url.path;
       
        if(![host isEqualToString:@"friend"] || ![path isEqualToString:@"/apply"]) {
            return false;
        }
       NSDictionary *paramDict =  [request queryItems];
        NSString *uid =  paramDict[@"uid"];
        [self toApplyFriend:uid];
        return true;
    }];
    
    // 用户协议
    [self registerHandler:@"ui.app.userprotocol" handler:^BOOL(WKSchemaRequest * _Nonnull request) {
        if(![request isAppSchema]) {
            return false;
        }
        NSString *host = request.url.host;
        NSString *path = request.url.path;
       
        if(![host isEqualToString:@"app"] || ![path isEqualToString:@"/userprotocol"]) {
            return false;
        }
        WKWebViewVC *vc = [WKWebViewVC new];
        vc.url = [NSURL URLWithString:WKApp.shared.config.userAgreementUrl];
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
        return true;
    }];
}

-(void) toApplyFriend:(NSString*)toUID {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:LLang(@"你需要发送验证码申请，等对方通过") preferredStyle:UIAlertControllerStyleAlert];
    //增加确定按钮；
    __weak typeof(self) weakSelf = self;
    //增加取消按钮；
    [alertController addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleDefault handler:nil]];
    //定义第一个输入框；
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = [NSString stringWithFormat:LLang(@"我是%@"),[WKApp shared].loginInfo.extra[@"name"]];
    }];
    UIView *topView = [WKNavigationManager shared].topViewController.view;
    [alertController addAction:[UIAlertAction actionWithTitle:LLang(@"确定") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *remarkFD = alertController.textFields.firstObject;
        [weakSelf applyFriend:toUID remark:remarkFD.text vercode:@""].then(^{
            [topView showHUDWithHide:LLang(@"发送成功！")];
        }).catch(^(NSError *err){
            [topView showHUDWithHide:err.domain];
        });
        
    }]];
    [[WKNavigationManager shared].topViewController presentViewController:alertController animated:true completion:nil];
}
-(AnyPromise*) applyFriend:(NSString*)uid remark:(NSString*)remark vercode:(NSString*)vercode{
    return [[WKAPIClient sharedClient] POST:@"friend/apply" parameters:@{@"to_uid":uid?:@"",@"remark":remark?:@"",@"vercode":vercode?:@""}];
}

-(void) registerHandler:(NSString*)sid handler:(WKSchemaHandler)handler {
    [[WKApp shared] setMethod:sid handler:^id _Nullable(id  _Nonnull param) {
        
        bool interrupt =  handler(param);
        return @(interrupt);
    } category:[self category]];
}
-(void) handle:(WKSchemaRequest*)request {
    NSArray<WKEndpoint*> *endpoints = [[WKApp shared] getEndpointsWithCategory:[self category]];
    if(endpoints) {
        for (WKEndpoint *endpoint in endpoints) {
            id obj = endpoint.handler(request);
            if([obj boolValue]) {
                return;
            }
            
        }
    }
}

-(void) handleURL:(NSURL*)url {
    [self handle:[WKSchemaRequest url:url]];
}

-(NSString*) category {
    return @"schema.handlers";
}

@end
