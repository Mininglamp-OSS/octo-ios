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
    self.title = LLang(@"功能模块");
   
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if(self.viewModel.settingChange) {
        [WKAlertUtil alert:@"开启或关闭模块需要重启，是否重启？" buttonsStatement:@[@"否",@"是"] chooseBlock:^(NSInteger buttonIdx) {
            if(buttonIdx == 1) {
                exit(0);
            }
        }];
    }
}

@end
