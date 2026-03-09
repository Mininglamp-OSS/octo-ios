//
//  WKAuthWebView.m
//  WuKongLogin
//
//  Created by tt on 2023/6/12.
//

#import "WKAuthWebViewVC.h"
#import "WKLoginVM.h"
@interface WKAuthWebViewVC ()

@property(nonatomic,strong) NSTimer *timer;

@end

@implementation WKAuthWebViewVC


- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self startCheckAuthStatus:self.authcode];
}


-(void) startCheckAuthStatus:(NSString*)authcode {
    __weak typeof(self) weakSelf = self;
    [WKAPIClient.sharedClient GET:@"user/thirdlogin/authstatus" parameters:@{
        @"authcode": authcode,
    }].then(^(NSDictionary *resultDict){
       NSInteger status =  [resultDict[@"status"] integerValue];
        if(status == 1) {
            NSDictionary *dataDict = resultDict[@"result"];
            [weakSelf login:dataDict];
        }else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf startCheckAuthStatus:authcode];
            });
           
        }
    }).catch(^(NSError *error){
        [weakSelf.view showHUDWithHide:error.domain];
    });
}

-(void) login:(NSDictionary*)dataDict {
    WKLoginResp *resp = (WKLoginResp*)[WKLoginResp fromMap:dataDict type:ModelMapTypeAPI];
    [WKLoginVM handleLoginData:resp isSave:YES];
    [[WKApp shared] invoke:WKPOINT_LOGIN_SUCCESS param:nil];
}


@end
