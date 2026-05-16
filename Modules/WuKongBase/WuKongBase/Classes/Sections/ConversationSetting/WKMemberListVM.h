//
//  WKMemberListVM.h
//  WuKongBase
//
//  Created by tt on 2022/8/31.
//

#import "WKBaseVM.h"
#import "WKContactsSelectVC.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKUserOnlineResp.h"
NS_ASSUME_NONNULL_BEGIN

@protocol WKMemberListVMDelegate <NSObject>

-(void) reload;

@end

@interface WKMemberListVM : WKBaseVM

@property(nonatomic,weak) id<WKMemberListVMDelegate> delegate;

@property(nonatomic,strong) WKChannel *channel;
@property(nonatomic,strong) NSArray<NSString*> *headerTitles;
@property(nonatomic,strong) NSArray<NSArray<WKChannelMember*>*> *items;

@property(nonatomic,strong) NSMutableSet<WKChannelMember*> *selectedMembers; // 被选中的成员

@property(nonatomic,copy) NSString *keyword;

@property(nonatomic,assign) BOOL loading;

@property(nonatomic,assign) BOOL showSelf; // 是否显示自己
@property(nonatomic,strong) NSArray<NSString*> *hiddenUsers; // 不显示的用户

@property(nonatomic,strong) NSMutableArray<WKUserOnlineResp*> *onlineMembers; // 在线成员

-(void) didLoad;

-(void) didMore:(void(^)(BOOL more))moreBlock;

-(BOOL) isChecked:(WKChannelMember*)member;

-(void) makeChecked:(WKChannelMember*)member;

-(WKChannelMember*) memberFromSelecteds:(NSString*)uid;

-(WKUserOnlineResp*) onlineMember:(NSString*)uid;

@end

NS_ASSUME_NONNULL_END
