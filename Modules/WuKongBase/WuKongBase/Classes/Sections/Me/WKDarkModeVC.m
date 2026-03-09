//
//  WKDarkModeVC.m
//  WuKongBase
//
//  Created by tt on 2020/12/11.
//

#import "WKDarkModeVC.h"

@interface WKDarkModeVC ()

@end

@implementation WKDarkModeVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKDarkModeVM new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (NSString *)langTitle {
    return LLang(@"深色模式");
}

@end
