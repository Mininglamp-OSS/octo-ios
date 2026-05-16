//
//  WKConversationPasswordVM.m
//  WuKongBase
//
//  Created by tt on 2020/10/30.
//

#import "WKConversationPasswordVM.h"
#import "WKMD5Util.h"
@interface WKConversationPasswordVM ()

@property(nonatomic,copy) NSString *loginPwd;
@property(nonatomic,copy) NSString *chatPwd;
@property(nonatomic,copy) NSString *rechatPwd;
@end

@implementation WKConversationPasswordVM

- (NSArray<NSDictionary *> *)tableSectionMaps {
    __weak typeof(self) weakSelf = self;
    return @[
        @{
            @"height":@(15.0f),
            @"items":@[
                    @{
                        @"class":WKLabelModel.class,
                        @"text":LLang(@"验证您的登录密码"),
                        @"textColor": [WKApp shared].config.defaultTextColor,
                        @"font": [[WKApp shared].config appFontOfSize:24.0f],
                        @"center":@(true),
                    },
            ],
        },
        @{
            @"height":@(10.0f),
            @"items":@[
                    @{
                        @"class":WKLabelModel.class,
                        @"text":LLang(@"请确认您的登录密码后，再设定6位数字的聊天密码"),
                        @"textColor": [WKApp shared].config.defaultTextColor,
                        @"font": [[WKApp shared].config appFontOfSize:12.0f],
                        @"center":@(true),
                    },
            ],
        },
        @{
            @"height":@(60.0f),
            @"items":@[
                    @{
                        @"class":WKTextFieldItemModel.class,
                        @"placeholder":[NSString stringWithFormat:LLang(@"请输入%@登录密码"),[WKApp shared].config.appName],
                        @"showBottomLine":@(true),
                        @"password":@(true),
                        @"onChange": ^(NSString *value) {
                            weakSelf.loginPwd = value;
                        }
                    },
            ],
        },
        @{
            @"height":@(0.01f),
            @"items":@[
                    @{
                        @"class":WKTextFieldItemModel.class,
                        @"placeholder":LLang(@"请输入6位数字聊天密码"),
                        @"showBottomLine":@(true),
                        @"maxLen":@(6),
                        @"password":@(true),
                        @"keyboardType": @(UIKeyboardTypeNumberPad),
                        @"onChange": ^(NSString *value) {
                            weakSelf.chatPwd = value;
                        }
                    },
            ],
        },
        @{
            @"height":@(0.01f),
            @"items":@[
                    @{
                        @"class":WKTextFieldItemModel.class,
                        @"placeholder":LLang(@"请输入6位数字聊天密码"),
                        @"showBottomLine":@(true),
                        @"maxLen":@(6),
                        @"password":@(true),
                        @"keyboardType": @(UIKeyboardTypeNumberPad),
                        @"onChange": ^(NSString *value) {
                            weakSelf.rechatPwd = value;
                        }
                    },
            ],
        },
        @{
            @"height":@(40.0f),
            @"items":@[
                    @{
                        @"class":WKButtonItemModel2.class,
                        @"title": LLang(@"确认"),
                        @"onPressed":^{
                            [weakSelf setChatPwd];
                        }
                    },
            ],
        },
    ];
}

-(void) setChatPwd {
    
    if(!self.loginPwd || [self.loginPwd isEqualToString:@""]) {
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"登录密码不能为空！")];
        return;
    }
    if(!self.chatPwd || [self.chatPwd isEqualToString:@""]) {
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"聊天密码不能为空！")];
        return;
    }
    if(![self.chatPwd isEqualToString:self.rechatPwd]) {
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"两次密码输入不一致！")];
        return;
    }
    
    [[WKNavigationManager shared].topViewController.view showHUD];
    
    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] POST:@"user/chatpwd" parameters:@{
        @"login_pwd":self.loginPwd?:@"",
        @"chat_pwd": [self digestPwd:self.chatPwd]?:@"",
    }].then(^{
        [WKApp shared].loginInfo.extra[@"chat_pwd"] = [weakSelf digestPwd:weakSelf.chatPwd];
        [[WKApp shared].loginInfo save];
        
        [[WKNavigationManager shared].topViewController.view hideHud];
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
        
        if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(conversationPasswordVMFinished:)]) {
            [weakSelf.delegate conversationPasswordVMFinished:weakSelf];
        }
        
    }).catch(^(NSError *error){
        [[WKNavigationManager shared].topViewController.view switchHUDError:error.domain];
    });
}

-(NSString*) digestPwd:(NSString*)pwd {
    return [WKMD5Util md5HexDigest:[NSString stringWithFormat:@"%@%@",pwd,[WKApp shared].loginInfo.uid]];
}

@end
