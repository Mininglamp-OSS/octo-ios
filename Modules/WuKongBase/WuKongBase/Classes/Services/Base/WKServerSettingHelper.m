//
//  WKServerSettingHelper.m
//  WuKongBase
//
//  服务器地址设置弹窗
//

#import "WKServerSettingHelper.h"
#import "WKServerConfig.h"
#import <MBProgressHUD/MBProgressHUD.h>

@implementation WKServerSettingHelper

+ (void)showServerSettingAlertInViewController:(UIViewController *)vc {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"服务器设置"
                                                                  message:@"输入服务器地址，修改后需重启App生效"
                                                           preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"如 http://192.168.1.100:3000";
        textField.text = [self currentDisplayAddress];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.keyboardType = UIKeyboardTypeURL;
    }];

    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确认并重启"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction *action) {
        NSString *input = [alert.textFields[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (input.length > 0) {
            [self parseAndTestInput:input inViewController:vc];
        }
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [alert addAction:confirmAction];
    [alert addAction:cancelAction];

    [vc presentViewController:alert animated:YES completion:nil];
}

/// 将当前保存的配置还原为显示地址
+ (NSString *)currentDisplayAddress {
    NSString *ip = [WKServerConfig serverIP];
    BOOL httpsOn = [WKServerConfig httpsOn];
    NSString *scheme = httpsOn ? @"https" : @"http";
    return [NSString stringWithFormat:@"%@://%@", scheme, ip];
}

/// 解析用户输入，支持多种格式：
/// - 完整URL: http://192.168.1.100:3000
/// - 带端口IP: 192.168.1.100:3000
/// - 纯域名: api-test.example.com
/// - 纯IP: 192.168.1.100
+ (void)parseAndTestInput:(NSString *)input inViewController:(UIViewController *)vc {
    NSString *ip;
    BOOL httpsOn;

    if ([input.lowercaseString hasPrefix:@"http://"] || [input.lowercaseString hasPrefix:@"https://"]) {
        // 用户输入了完整 URL，解析协议和地址
        NSURL *parsedURL = [NSURL URLWithString:input];
        if (!parsedURL || !parsedURL.host) {
            [self showFailAlertInViewController:vc input:input message:@"地址格式不正确，请检查输入"];
            return;
        }
        httpsOn = [parsedURL.scheme.lowercaseString isEqualToString:@"https"];
        if (parsedURL.port) {
            ip = [NSString stringWithFormat:@"%@:%@", parsedURL.host, parsedURL.port];
        } else {
            ip = parsedURL.host;
        }
    } else {
        // 用户只输入了 IP/域名（可能带端口），默认 HTTP
        ip = input;
        httpsOn = NO;
    }

    [self testServerIP:ip httpsOn:httpsOn inViewController:vc];
}

+ (void)testServerIP:(NSString *)ip httpsOn:(BOOL)httpsOn inViewController:(UIViewController *)vc {
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:vc.view animated:YES];
    hud.label.text = @"正在测试服务器连接...";

    NSString *scheme = httpsOn ? @"https" : @"http";
    NSString *urlString = [NSString stringWithFormat:@"%@://%@/api/v1/health", scheme, ip];
    NSURL *url = [NSURL URLWithString:urlString];

    if (!url) {
        [hud hideAnimated:YES];
        [self showFailAlertInViewController:vc input:[NSString stringWithFormat:@"%@://%@", scheme, ip] message:@"服务器地址格式不正确"];
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                          cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                      timeoutInterval:10];
    request.HTTPMethod = @"GET";

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud hideAnimated:YES];

            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (error == nil && httpResponse && httpResponse.statusCode < 500) {
                // 连接成功，保存并重启
                [WKServerConfig saveServerIP:ip httpsOn:httpsOn];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    exit(0);
                });
            } else {
                NSString *msg = error.localizedDescription ?: [NSString stringWithFormat:@"服务器返回错误(%ld)", (long)httpResponse.statusCode];
                [self showFailAlertInViewController:vc input:[NSString stringWithFormat:@"%@://%@", scheme, ip] message:msg];
            }
        });
    }];
    [task resume];
}

+ (void)showFailAlertInViewController:(UIViewController *)vc input:(NSString *)input message:(NSString *)message {
    UIAlertController *failAlert = [UIAlertController alertControllerWithTitle:@"连接失败"
                                                                      message:[NSString stringWithFormat:@"无法连接到服务器：%@\n\n%@", input, message]
                                                               preferredStyle:UIAlertControllerStyleAlert];

    [failAlert addAction:[UIAlertAction actionWithTitle:@"重新设置"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
        [self showServerSettingAlertInViewController:vc];
    }]];

    [failAlert addAction:[UIAlertAction actionWithTitle:@"取消"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];

    [vc presentViewController:failAlert animated:YES completion:nil];
}

@end
