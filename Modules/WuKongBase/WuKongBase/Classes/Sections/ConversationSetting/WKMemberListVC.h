//
//  WKMemberListVC.h
//  WuKongBase
//
//  Created by tt on 2022/8/31.
//

#import "WKBaseVC.h"
#import "WKMemberListVM.h"
#import <WuKongIMSDK/WuKongIMSDK.h>




NS_ASSUME_NONNULL_BEGIN

// 完成选择
typedef void (^MembersFinishedSelect)(NSArray<NSString*>* uids);

@interface WKMemberListVC : WKBaseVC<WKMemberListVM*>

@property(nonatomic,strong) WKChannel *channel;

@property(nonatomic,assign) BOOL edit; // 是否开启编辑模式

@property(nonatomic,strong) NSArray<NSString*> *disableUsers; // 被禁止选择的用户
@property(nonatomic,strong) NSArray<NSString*> *hiddenUsers; // 不显示的用户

/**
 完成选择
 */
@property(nonatomic,copy) MembersFinishedSelect onFinishedSelect;

@end

NS_ASSUME_NONNULL_END
