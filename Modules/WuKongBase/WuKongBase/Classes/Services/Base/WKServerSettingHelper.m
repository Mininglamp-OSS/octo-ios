//
//  WKServerSettingHelper.m
//  WuKongBase
//
//  服务器地址设置弹窗
//

#import "WKServerSettingHelper.h"
#import "WKServerConfig.h"
#import "WKLoginInfo.h"
#import "WKSpaceModel.h"
#import <MBProgressHUD/MBProgressHUD.h>

@implementation WKServerSettingHelper

+ (void)showServerSettingAlertInViewController:(UIViewController *)vc {
    NSArray<NSDictionary *> *history = [WKServerConfig serverHistory];
    if (history.count > 0) {
        // 有历史记录，显示历史列表 + 输入新地址入口
        [self showHistorySheetInViewController:vc history:history];
    } else {
        // 无历史记录，直接显示输入弹窗
        [self showInputAlertInViewController:vc];
    }
}

#pragma mark - 历史服务器列表

+ (void)showHistorySheetInViewController:(UIViewController *)vc history:(NSArray<NSDictionary *> *)history {
    NSString *currentIP = [WKServerConfig serverIP];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"服务器设置"
                                                                  message:@"选择历史服务器或输入新地址"
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSDictionary *entry in history) {
        NSString *ip = entry[@"ip"];
        BOOL httpsOn = [entry[@"https"] boolValue];
        NSString *scheme = httpsOn ? @"https" : @"http";
        NSString *label = entry[@"label"];
        NSString *displayAddr;
        if (label && label.length > 0) {
            displayAddr = [NSString stringWithFormat:@"%@ (%@://%@)", label, scheme, ip];
        } else {
            displayAddr = [NSString stringWithFormat:@"%@://%@", scheme, ip];
        }

        // 当前正在使用的服务器加标记
        BOOL isCurrent = [ip isEqualToString:currentIP];
        NSString *title = isCurrent ? [NSString stringWithFormat:@"✓ %@", displayAddr] : displayAddr;

        UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *act) {
            if (isCurrent) {
                // 已经是当前服务器，不需要切换
                return;
            }
            [self switchToServerIP:ip httpsOn:httpsOn inViewController:vc];
        }];
        [sheet addAction:action];
    }

    // 输入新地址
    UIAlertAction *newAction = [UIAlertAction actionWithTitle:@"输入新地址"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        [self showInputAlertInViewController:vc];
    }];
    [sheet addAction:newAction];

    // 管理历史记录（删除用户手动添加的，预设地址保留）
    NSArray *presetIPs = [[WKServerConfig presetServers] valueForKey:@"ip"];
    BOOL hasUserAdded = NO;
    for (NSDictionary *entry in history) {
        if (![presetIPs containsObject:entry[@"ip"]]) {
            hasUserAdded = YES;
            break;
        }
    }
    if (hasUserAdded) {
        UIAlertAction *manageAction = [UIAlertAction actionWithTitle:@"清除历史记录"
                                                              style:UIAlertActionStyleDestructive
                                                            handler:^(UIAlertAction *action) {
            [self showClearHistoryConfirmInViewController:vc];
        }];
        [sheet addAction:manageAction];
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    [sheet addAction:cancelAction];

    // iPad 兼容
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = vc.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(vc.view.bounds.size.width / 2, vc.view.bounds.size.height / 2, 0, 0);
    }

    [vc presentViewController:sheet animated:YES completion:nil];
}

+ (void)showClearHistoryConfirmInViewController:(UIViewController *)vc {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清除历史记录"
                                                                  message:@"确定要清除所有历史服务器记录吗？当前服务器设置不受影响。"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"清除"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WKServerHistory"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [vc presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 切换到历史服务器

+ (void)switchToServerIP:(NSString *)ip httpsOn:(BOOL)httpsOn inViewController:(UIViewController *)vc {
    [self testServerIP:ip httpsOn:httpsOn inViewController:vc];
}

#pragma mark - 手动输入新地址

+ (void)showInputAlertInViewController:(UIViewController *)vc {
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

/// 解析用户输入，支持多种格式
+ (void)parseAndTestInput:(NSString *)input inViewController:(UIViewController *)vc {
    NSString *ip;
    BOOL httpsOn;

    if ([input.lowercaseString hasPrefix:@"http://"] || [input.lowercaseString hasPrefix:@"https://"]) {
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
        // 用户只输入了 IP/域名（可能带端口），默认 HTTPS
        ip = input;
        httpsOn = YES;
    }

    [self testServerIP:ip httpsOn:httpsOn inViewController:vc];
}

#pragma mark - 测试连接

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
                // 连接成功，清除旧服务器的登录数据后保存并重启
                [[WKLoginInfo shared] clear];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentSpaceId"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [[WKSpaceModel shared] invalidateCache];

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
