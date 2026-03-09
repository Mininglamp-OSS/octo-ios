//
//  WKLoginPhoneCheckVM.m
//  WuKongLogin
//
//  Created by tt on 2020/10/26.
//

#import "WKLoginPhoneCheckVM.h"
#import "WKLoginVM.h"
@interface WKLoginPhoneCheckVM ()

@property(nonatomic,copy) NSString *code;

@end

@implementation WKLoginPhoneCheckVM

- (NSArray<NSDictionary *> *)tableSectionMaps {
    
    __weak typeof(self) weakSelf = self;
    return @[
        @{
            @"height":WKSectionHeight,
            @"items": @[
                    @{
                        @"class": WKLabelModel.class,
                        @"text": [NSString stringWithFormat:LLang(@"我们已给你的手机号码%@发送了一条验证码短信。"),self.phone],
                        @"font": [[WKApp shared].config appFontOfSize:16.0f],
                    }
            ]
        },
        @{
            @"height":WKSectionHeight,
            @"items": @[
                    @{
                        @"class": WKSMSCodeItemModel.class,
                        @"sendBtnTitle":self.sendBtnTitle?:@"",
                        @"disable": @(self.sendBtnDisable),
                        @"onChange":^(NSString*value){
                            weakSelf.code = value;
                        },
                        @"onSend":^{
                            if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(loginPhoneCheckVMDidSend:)]) {
                                [weakSelf.delegate loginPhoneCheckVMDidSend:weakSelf];
                            }
                        }
                    }
            ]
        },
        @{
            @"height":@(40.0f),
            @"items": @[
                    @{
                        @"class": WKButtonItemModel2.class,
                        @"title":LLang(@"确认"),
                        @"onPressed":^{
                            if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(loginPhoneCheckVMDidOk:)]) {
                                [weakSelf.delegate loginPhoneCheckVMDidOk:weakSelf];
                            }
                        }
                    }
            ]
        }
    ];
}


-(AnyPromise*) sendLoginCheckCode:(NSString*)uid {
    return [[WKAPIClient sharedClient] POST:@"user/sms/login_check_phone" parameters:@{
        @"uid":uid?:@"",
    }];
}


- (AnyPromise *)loginCheckPhone:(NSString *)uid code:(NSString *)code {
    return [[WKAPIClient sharedClient] POST:@"user/login/check_phone" parameters:@{
        @"uid": uid?:@"",
        @"code": code?:@"",
    } model:WKLoginResp.class];
}

- (NSString *)sendBtnTitle {
    if(!_sendBtnTitle) {
        return LLang(@"发送");
    }
    return _sendBtnTitle;
}

- (NSString *)getCode {
    return self.code;
}

@end
