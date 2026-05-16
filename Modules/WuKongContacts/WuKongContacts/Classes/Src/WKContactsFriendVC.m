//
//  WKContactsFriendVC.m
//  WuKongContacts
//
//  Created by tt on 2021/9/22.
//

#import "WKContactsFriendVC.h"
#import <Contacts/Contacts.h>
#import "WKContacts.h"
#import "WKContactsFriendCell.h"
#import "WKContactsFriendVM.h"
#import <MessageUI/MessageUI.h>
#import <WuKongBase/LBXPermissionSetting.h>
#import "WKContactsFriendDB.h"

@interface WKContactsFriendVC ()<WKContactsFriendCellDelegate,MFMessageComposeViewControllerDelegate>

@property(nonatomic,strong) WKContactsFriendVM *vm;

@property(nonatomic,strong) NSMutableArray<WKContactsFriendModel*> *contactList;

@end

@implementation WKContactsFriendVC

- (void)viewDidLoad {
    
    self.mode = WKContactsModeSingle;
    self.vm = [WKContactsFriendVM new];
    
    [super viewDidLoad];
    
    [self requestAuthorization];
    
    self.title = LLang(@"通讯录好友");
   
    
    [self.tableView registerClass:WKContactsFriendCell.class forCellReuseIdentifier:[WKContactsFriendCell cellId]];
    
    
}


// 重写空的requestData ，使其不去请求应用好友数据
-(void) requestData {
    
}

-(void) requestAuthorization {
    __weak typeof(self) weakSelf = self;
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    if(status == CNAuthorizationStatusNotDetermined) { // 判断当前的授权状态是否是用户还未选择的状态
        CNContactStore *store = [CNContactStore new];
            [store requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
                if (granted)
                {
                    WKLogDebug(@"授权成功!");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf getContacts];
                    });
                    
                }
                else
                {
                    WKLogWarn(@"授权失败!");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[WKNavigationManager shared] popViewControllerAnimated:YES];
                    });
                    
                }
            }];
    }
    
    if (status == CNAuthorizationStatusAuthorized) {
        [self getContacts];
        return;
    }
    
    // 判断当前的授权状态
    if (status != CNAuthorizationStatusAuthorized && status != CNAuthorizationStatusNotDetermined)
    {
        [LBXPermissionSetting showAlertToDislayPrivacySettingWithTitle:LLangW(@"提示",weakSelf) msg:LLang(@"您的通讯录暂未允许访问，是否前往设置") cancel:LLangW(@"取消",weakSelf) setting:LLangW(@"设置",weakSelf)];
        return;
    }
    
}

-(void) loadContacts {
    CNContactStore *contactStore = [CNContactStore new];
    NSArray *keys = @[ CNContactPhoneNumbersKey, CNContactGivenNameKey, CNContactFamilyNameKey];
    CNContactFetchRequest *request = [[CNContactFetchRequest alloc] initWithKeysToFetch:keys];
    
    __weak typeof(self) weakSelf  = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [contactStore enumerateContactsWithFetchRequest:request error:nil usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
            // 获取姓名
            NSString *firstName = contact.familyName;
            NSString *lastName = contact.givenName;
            
            NSString *name = [NSString stringWithFormat:@"%@%@",firstName?:@"",lastName?:@""];
           

            // 获取电话号码
            for (CNLabeledValue *labeledValue in contact.phoneNumbers)
            {
                 CNPhoneNumber *phoneValue = labeledValue.value;
                 NSString *phoneNumber = phoneValue.stringValue;
                 phoneNumber = [phoneNumber stringByReplacingOccurrencesOfString:@"-" withString:@""];
                phoneNumber = [phoneNumber stringByReplacingOccurrencesOfString:@" " withString:@""];
                phoneNumber = [phoneNumber stringByReplacingOccurrencesOfString:@"+" withString:@"00"];
                
                if([name isEqualToString:@""]) {
                    name = phoneNumber;
                }
                WKContactsFriendModel *contactModel = [WKContactsFriendModel new];
                contactModel.name = name;
                contactModel.phone = phoneNumber;
                [weakSelf.contactList addObject:contactModel];
            }
          
        }];
    });
    
}

// 上传联系人
-(AnyPromise*) uploadContacts {
    NSMutableArray<WKContactsFriendModel*> *needUploads = [NSMutableArray array];
   NSArray<WKContactsFriendDBModel*> *dbModels = [[WKContactsFriendDB shared] queryAll];
    
        
        for (WKContactsFriendModel *friendModel in self.contactList) {
            bool exist = false;
            if(dbModels && dbModels.count>0) {
                for (WKContactsFriendDBModel *dbModel in dbModels) {
                    if(friendModel.phone && ![friendModel.phone isEqualToString:@""] && [friendModel.phone isEqualToString:dbModel.phone]) {
                        exist = true;
                        break;
                    }
                }
            }
            if(!exist) {
                [needUploads addObject:friendModel];
            }
        }

    __weak typeof(self) weakSelf = self;
    
    if(needUploads.count==0) {
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
            resolver(nil);
        }];
    }
    return [self.vm requestUpload:needUploads].then(^{
        NSMutableArray<WKContactsFriendDBModel*> *dbModels = [NSMutableArray array];
        for (WKContactsFriendModel *friendModel in needUploads) {
            WKContactsFriendDBModel *dbModel = [WKContactsFriendDBModel new];
            dbModel.name = friendModel.name;
            dbModel.phone = friendModel.phone;
            [dbModels addObject:dbModel];
        }
        [[WKContactsFriendDB shared] save:dbModels];
    }).catch(^(NSError *error){
        [weakSelf.view showHUDWithHide:error.domain];
    });
}

-(void) getContacts {
    
    [self loadContacts];
    
    __weak typeof(self) weakSelf = self;
    [self.view showHUD];
    [self uploadContacts].then(^{
         [weakSelf.vm requestMaillist].then(^(NSArray<WKContactsFriendResp*> *items){
             [weakSelf.view hideHud];
             if(items && items.count>0) {
                 for (WKContactsFriendResp *friendResp in items) {
                     for (WKContactsFriendModel *friendModel in self.contactList) {
                         if(friendModel.phone && ![friendModel.phone isEqualToString:@""] && [friendModel.phone isEqualToString:friendResp.phone]) {
                             friendModel.isFriend = friendResp.isFriend;
                             friendModel.vercode = friendResp.vercode;
                             friendModel.phone = friendResp.phone;
                             friendModel.uid = friendResp.uid;
                         }
                     }
                 }
                 
             }
             [weakSelf parseData:weakSelf.contactList];
         }).catch(^(NSError*error){
             [weakSelf.view hideHud];
             [weakSelf.view showHUDWithHide:error.domain];
         });

    });
}

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKContactsFriendCell *cell = (WKContactsFriendCell*)[super tableView:tableView cellForRowAtIndexPath:indexPath];
    cell.delegate = self;
    return cell;
}

// 重写父类搜索
-(void) searchTextChange:(NSString*)text {
    NSArray *data;
    if([text isEqualToString:@""]) {
        data = self.contactList;
    }else {
        data = [self.contactList filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name CONTAINS[c] %@ or phone CONTAINS[c] %@",text,text]];
    }
    
    [self parseData:data];
}

- (NSMutableArray<WKContactsFriendModel *> *)contactList {
    if(!_contactList) {
        _contactList = [NSMutableArray array];
    }
    return _contactList;
}



-(void) contactsFriendCell:(WKContactsFriendCell*)cell action:(WKContactsFriendModel*)model {
    
    if(!model.vercode || [model.vercode isEqualToString:@""]) {
        [self invite:model];
        return;
    }
    
    if(!model.isFriend && model.vercode && ![ model.vercode isEqualToString:@""]) {
        [self addFriend:model];
        return;
    }
    
}

-(void) invite:(WKContactsFriendModel*)model {
    if( [MFMessageComposeViewController canSendText]) {
        MFMessageComposeViewController * controller = [[MFMessageComposeViewController alloc] init];
        controller.recipients = @[model.phone];//发送短信的号码，数组形式入参
        controller.navigationBar.tintColor = [UIColor redColor];
        controller.messageComposeDelegate = self;
        controller.body = [WKApp shared].config.inviteMsg; //此处的body就是短信将要发生的内容
        [self presentViewController:controller animated:YES completion:nil];
    }
}

-(void) addFriend:(WKContactsFriendModel*)model {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:LLang(@"你需要发送验证码申请，等对方通过") preferredStyle:UIAlertControllerStyleAlert];
    //增加确定按钮；
    __weak typeof(self) weakSelf = self;
    //增加取消按钮；
    [alertController addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleDefault handler:nil]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:LLang(@"确定") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *remarkFD = alertController.textFields.firstObject;
        [weakSelf.vm applyFriend:model.uid remark:remarkFD.text vercode:model.vercode].then(^{
            [weakSelf.view showHUDWithHide:LLang(@"发送成功！")];
        }).catch(^(NSError *err){
            [weakSelf.view showHUDWithHide:err.domain];
        });
        
    }]];
   
    //定义第一个输入框；
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = [NSString stringWithFormat:LLang(@"我是%@"),[WKApp shared].loginInfo.extra[@"name"]];
    }];
    [self.view.lim_viewController presentViewController:alertController animated:true completion:nil];
}


#pragma mark -- MFMessageComposeViewControllerDelegate

-(void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result {
    [self dismissViewControllerAnimated:YES completion:nil];
    switch (result) {
        case MessageComposeResultSent:
            //信息传送成功
            break;
        case MessageComposeResultFailed:
            //信息传送失败
            break;
        case MessageComposeResultCancelled:
            //信息被用户取消传送
            break;
        default:
            break;
    }
}


@end
