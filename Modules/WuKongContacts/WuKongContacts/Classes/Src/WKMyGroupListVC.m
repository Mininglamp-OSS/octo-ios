//
//  WKMyGroupListVC.m
//  WuKongContacts
//
//  Created by tt on 2020/7/16.
//

#import "WKMyGroupListVC.h"

@interface WKMyGroupListVC ()

@property(nonatomic,strong) UIButton *groupCreateBtn;

@end

@implementation WKMyGroupListVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKMyGroupListVM new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.navigationBar setRightView:self.groupCreateBtn];
}

- (UIButton *)groupCreateBtn {
    if(!_groupCreateBtn) {
        _groupCreateBtn = [[UIButton alloc] init];
        [_groupCreateBtn setTitle:LLang(@"新建群聊") forState:UIControlStateNormal];
        [_groupCreateBtn setTitleColor:[WKApp shared].config.navBarButtonColor forState:UIControlStateNormal];
        [_groupCreateBtn sizeToFit];
        [_groupCreateBtn addTarget:self action:@selector(groupCreatePressed) forControlEvents:UIControlEventTouchUpInside];
        [[_groupCreateBtn titleLabel] setFont:[[WKApp shared].config appFontOfSize:14.0f]];
    }
    return _groupCreateBtn;
}

-(void) groupCreatePressed {
    [[WKApp shared] invoke:WKPOINT_CONVERSATION_STARTCHAT param:nil];
}

- (NSString *)langTitle {
    
    return LLang(@"保存的群聊");
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return YES;
}


-(UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {

    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
        
    WKMyGroupResp *groupResp = self.viewModel.groups[indexPath.row];
    if(groupResp) {
        [[WKChannelSettingManager shared] group:groupResp.groupNo save:NO];
    }
}

@end
