//
//  WKModuleVC.m
//  WuKongBase
//
//  Created by tt on 2023/2/23.
//

#import "WKModuleVC.h"

@interface WKModuleVC ()

@end

@implementation WKModuleVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKModuleVM new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (NSString *)langTitle {
    // 改用 langTitle hook —— base class 切语言时会自动刷 nav title
    return LLang(@"功能模块");
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if(self.viewModel.settingChange) {
        [WKAlertUtil alert:LLang(@"开启或关闭模块需要重启，是否重启？") buttonsStatement:@[LLang(@"否"), LLang(@"是")] chooseBlock:^(NSInteger buttonIdx) {
            if(buttonIdx == 1) {
                exit(0);
            }
        }];
    }
}

@end
