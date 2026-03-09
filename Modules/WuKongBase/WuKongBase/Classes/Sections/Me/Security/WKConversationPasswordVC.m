//
//  WKConversationPasswordVC.m
//  WuKongBase
//
//  Created by tt on 2020/10/30.
//

#import "WKConversationPasswordVC.h"
#import "WKConversationPasswordVM.h"
@interface WKConversationPasswordVC ()<WKConversationPasswordVMDelegate>

@end

@implementation WKConversationPasswordVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKConversationPasswordVM new];
        self.viewModel.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (NSString *)langTitle {
    return LLang(@"聊天密码");
}

#pragma mark -- WKConversationPasswordVMDelegate

- (void)conversationPasswordVMFinished:(WKConversationPasswordVM *)vm {
    if(self.onFinish) {
        self.onFinish();
    }
}

@end
