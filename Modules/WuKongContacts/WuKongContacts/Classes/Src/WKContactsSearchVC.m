//
//  WKContactsSearchVC.m
//  WuKongContacts
//
//  Created by tt on 2020/6/22.
//

#import "WKContactsSearchVC.h"
#import "WKContactsVM.h"
#import "WKMeInfoVC.h"
#define searchBarHeight 36.0f
@interface WKContactsSearchVC ()<UITextFieldDelegate>
@property(nonatomic,strong) UIView *searchBarView;
@property(nonatomic,strong) UITextField *searchBarInput;
@end

@implementation WKContactsSearchVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKContactsVM new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationBar addSubview:self.searchBarView];
    [self.searchBarView addSubview:self.searchBarInput];
    
    [self.searchBarInput becomeFirstResponder];
    
}


- (UITextField *)searchBarInput {
    if(!_searchBarInput) {
        _searchBarInput = [[UITextField alloc] initWithFrame:CGRectMake(26.0f, 0.0f, self.searchBarView.lim_width - 26.0f, searchBarHeight)];
        _searchBarInput.placeholder = LLang(@"搜索");
        _searchBarInput.returnKeyType = UIReturnKeySearch;
        _searchBarInput.delegate = self;
      //  [_searchBarInput addTarget:self action:@selector(textFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];
        
    }
    return _searchBarInput;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
}

- (UIView *)searchBarView {
    if(!_searchBarView) {
        CGFloat statusHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
        _searchBarView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.lim_width - 70.0f, searchBarHeight)];
        _searchBarView.lim_left = 45.0f;
        [_searchBarView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        _searchBarView.layer.masksToBounds = YES;
        _searchBarView.layer.cornerRadius = 4.0f;
        _searchBarView.lim_top = (self.navigationBar.lim_height-statusHeight)/2.0f - _searchBarView.lim_height/2.0f + statusHeight;
        
        UIImageView *iconImgView = [[UIImageView alloc] initWithImage: [self imageName:@"Contacts/Others/Search"]];
        iconImgView.frame = CGRectMake(6.0f, 0.0f, 16.0f, 16.0f);
        iconImgView.lim_top = _searchBarView.lim_height/2.0f - iconImgView.lim_height/2.0f;
        [_searchBarView addSubview:iconImgView];
    }
    return _searchBarView;
}
#pragma mark -- 事件

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    __weak typeof(self) weakSelf = self;
    [self.viewModel searchFriend:textField.text].then(^(WKUserSearchResp *resp){
        if(!resp.exist) {
            [weakSelf.view showMsg:LLang(@"用户不存在！")];
            return;
        }
        [[WKApp shared] invoke:WKPOINT_USER_INFO param:@{@"uid":resp.user.uid,@"vercode":resp.user.vercode?:@""}];
    });
    return YES;
}
// 重写返回事件
-(void) backPressed {
    [[WKNavigationManager shared] popViewControllerAnimated:NO];
}

#pragma mark -- 其他


-(UIImage*) imageName:(NSString*)name {
    return [[WKApp shared] loadImage:name moduleID:@"WuKongContacts"];
}

@end
