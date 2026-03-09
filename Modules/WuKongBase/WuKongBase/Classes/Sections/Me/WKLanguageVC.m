//
//  WKLanguageVC.m
//  WuKongBase
//
//  Created by tt on 2020/12/25.
//

#import "WKLanguageVC.h"

@interface WKLanguageVC ()

@end

@implementation WKLanguageVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKLanguageVM new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (NSString *)langTitle {
    return LLang(@"多语言");
}


@end
