//
//  WKAlertUtil.m
//  WuKongBase
//
//  Created by tt on 2020/1/30.
//

#import "WKAlertUtil.h"
#import "WKNavigationManager.h"
#import "WuKongBase.h"
@implementation WKAlertUtil

+(void) alert:(NSString*)msg {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:msg preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:LLang(@"好的") style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:okAction];
    
    [[WKNavigationManager shared].topViewController presentViewController:alertController animated:YES completion:nil];
}

+(void) alert:(NSString*)msg title:(NSString*)title{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:LLang(@"好的") style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:okAction];
    
    [[WKNavigationManager shared].topViewController presentViewController:alertController animated:YES completion:nil];
}

+(void) alert:(NSString*)msg buttonsStatement:(NSArray<NSString*>*)arrayItems chooseBlock:(void (^)(NSInteger buttonIdx))block{
     NSMutableArray* argsArray = [[NSMutableArray alloc] initWithArray:arrayItems];
     UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"" message:msg preferredStyle:UIAlertControllerStyleAlert];
    for (int i = 0; i < [argsArray count]; i++)
    {
        UIAlertActionStyle style =  (0 == i)? UIAlertActionStyleCancel: UIAlertActionStyleDefault;
        // Create the actions.
        UIAlertAction *action = [UIAlertAction actionWithTitle:[argsArray objectAtIndex:i] style:style handler:^(UIAlertAction *action) {
            if (block) {
                       block(i);
            }
        }];
        [alertController addAction:action];
    }
                  
    [[WKNavigationManager shared].topViewController presentViewController:alertController animated:YES completion:nil];
}

+(void) alert:(NSString*)msg targetVC:(UIViewController*)targetVC buttonsStatement:(NSArray<NSString*>*)arrayItems chooseBlock:(void (^)(NSInteger buttonIdx))block{
     NSMutableArray* argsArray = [[NSMutableArray alloc] initWithArray:arrayItems];
     UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"" message:msg preferredStyle:UIAlertControllerStyleAlert];
    for (int i = 0; i < [argsArray count]; i++)
    {
        UIAlertActionStyle style =  (0 == i)? UIAlertActionStyleCancel: UIAlertActionStyleDefault;
        // Create the actions.
        UIAlertAction *action = [UIAlertAction actionWithTitle:[argsArray objectAtIndex:i] style:style handler:^(UIAlertAction *action) {
            if (block) {
                       block(i);
            }
        }];
        [alertController addAction:action];
    }
                  
    [targetVC presentViewController:alertController animated:YES completion:nil];
}

@end
