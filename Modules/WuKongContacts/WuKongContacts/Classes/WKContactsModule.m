//
//  WKContactsModule.m
//  WuKongContacts
//
//  Created by tt on 2019/12/7.
//

#import "WKContactsModule.h"
#import "WKContactsSync.h"
#import "WKContactsAddVC.h"
#import "WKUserInfoVC.h"
#import "WKContactsFriendRequestVC.h"
#import "WKMyGroupListVC.h"
#import "WKOrgMembersListVC.h"
#import "WKBotListVC.h"
#import "WKAllGroupListVC.h"
@WKModule(WKContactsModule)

@interface WKContactsModule ()<WKChannelManagerDelegate>

@end

@implementation WKContactsModule


-(NSString*) moduleId {
    return @"WuKongContacts";
}

// 模块初始化
- (void)moduleInit:(WKModuleContext*)context{
    NSLog(@"【WuKongContacts】模块初始化！");
    
    __weak typeof(self) weakSelf = self;
    // 联系人同步
    [self setMethod:WKPOINT_SYNC_CONTACTS handler:^id _Nullable(id  _Nonnull param) {
        return [[WKContactsSync alloc] init];
    } category:WKPOINT_CATEGORY_SYNC];
    
    
     // 显示添加联系人界面
    [[WKApp shared] setMethod:WKPOINT_CONVERSATION_ADDCONTACTS handler:^id _Nullable(id  _Nonnull param) {
        WKContactsAddVC *vc = [WKContactsAddVC new];
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
        return nil;
    }];
    
    
    // 提供联系人选择的数据
    [self setMethod:WKPOINT_CONTACTS_SELECT_DATA handler:^id _Nullable(id  _Nonnull param) {
//        NSArray<WKDBContactsModel*> *contactsList = [[WKDBContacts shared] queryVaild];
        NSArray<WKChannelInfo*> *channelInfos = [[WKChannelInfoDB shared] queryChannelInfosWithStatusAndFollow:WKChannelStatusNormal follow:WKChannelInfoFollowFriend];
        NSMutableArray *items = [NSMutableArray array];
        if(channelInfos) {
            for (WKChannelInfo *channelInfo in channelInfos) {
                if(channelInfo.channel.channelType != WK_PERSON) {
                    continue;
                }
                WKContactsSelect *contacts = [[WKContactsSelect alloc] init];
                contacts.uid =channelInfo.channel.channelId;
                contacts.name = channelInfo.name;
                contacts.displayName =channelInfo.displayName;
                contacts.avatar = [WKAvatarUtil getAvatar:channelInfo.channel.channelId];
                [items addObject:contacts];
            }
        }
        return items;
    }];
    
    
    // 新朋友item
    [self setMethod:@"contacts.header.newFriend" handler:^id _Nullable(id  _Nonnull param) {
        WKContactsHeaderItem *item = [WKContactsHeaderItem initWithSid:WK_CONTACTS_HEADER_ITEM_NEWFRIEND title:LLangW(@"新的朋友",weakSelf) icon:@"Contacts/Index/FriendNew" moduleID:[weakSelf moduleId] onClick:^{
            [[WKContactsManager shared] markAllFriendRequestToReaded]; // 好友请求标记为已读
            // 跳转
            [[WKNavigationManager shared] pushViewController:[WKContactsFriendRequestVC new] animated:YES];
        }];
        int count = [[WKContactsManager shared] getFriendRequestUnreadCount];
        if(count>0) {
            item.badgeValue = [NSString stringWithFormat:@"%d", [[WKContactsManager shared] getFriendRequestUnreadCount]];
        }
        
        return item;
    } category:WKPOINT_CATEGORY_CONTACTSITEM sort:9000];
    
    // 保存的群item
       [self setMethod:@"contacts.header.groupSave" handler:^id _Nullable(id  _Nonnull param) {
           WKContactsHeaderItem *item = [WKContactsHeaderItem initWithSid:WK_CONTACTS_HEADER_ITEM_NEWFRIEND title:LLangW(@"保存的群聊",weakSelf) icon:@"Contacts/Index/GroupSave" moduleID:[weakSelf moduleId] onClick:^{
               // 跳转
               [[WKNavigationManager shared] pushViewController:[WKMyGroupListVC new] animated:YES];
           }];
           return item;
       } category:WKPOINT_CATEGORY_CONTACTSITEM sort:8000];

    // 组织内联系人item
    [self setMethod:@"contacts.header.orgMembers" handler:^id _Nullable(id  _Nonnull param) {
        WKContactsHeaderItem *item = [WKContactsHeaderItem initWithSid:@"orgMembers" title:LLangW(@"组织内联系人",weakSelf) icon:@"Contacts/Index/OrgMembers" moduleID:[weakSelf moduleId] onClick:^{
            [[WKNavigationManager shared] pushViewController:[WKOrgMembersListVC new] animated:YES];
        }];
        return item;
    } category:WKPOINT_CATEGORY_CONTACTSITEM sort:7000];

    // Bot item
    [self setMethod:@"contacts.header.bot" handler:^id _Nullable(id  _Nonnull param) {
        WKContactsHeaderItem *item = [WKContactsHeaderItem initWithSid:@"bot" title:LLangW(@"AI",weakSelf) icon:@"Contacts/Index/Bot" moduleID:[weakSelf moduleId] onClick:^{
            [[WKNavigationManager shared] pushViewController:[WKBotListVC new] animated:YES];
        }];
        return item;
    } category:WKPOINT_CATEGORY_CONTACTSITEM sort:6000];

    // 我的群组item
    [self setMethod:@"contacts.header.allGroups" handler:^id _Nullable(id  _Nonnull param) {
        WKContactsHeaderItem *item = [WKContactsHeaderItem initWithSid:@"allGroups" title:LLangW(@"我的群组",weakSelf) icon:@"Contacts/Index/AllGroups" moduleID:[weakSelf moduleId] onClick:^{
            [[WKNavigationManager shared] pushViewController:[WKAllGroupListVC new] animated:YES];
        }];
        return item;
    } category:WKPOINT_CATEGORY_CONTACTSITEM sort:5000];


}

// 模块启动
-(BOOL) moduleDidFinishLaunching:(WKModuleContext *)context{

    
    return true;
}

- (void)moduleDidDatabaseLoad:(WKModuleContext *)context {
    // 初始化db
    [[WKDBMigration shared] migrateDatabase:[self resourceBundle]];
}

@end
