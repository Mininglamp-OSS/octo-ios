//
//  WKMyGroupListVM.h
//  WuKongContacts
//
//  Created by tt on 2020/7/16.
//

#import <WuKongBase/WuKongBase.h>
@class WKMyGroupResp;
NS_ASSUME_NONNULL_BEGIN

@interface WKMyGroupListVM : WKBaseTableVM

@property(nonatomic,strong) NSArray<WKMyGroupResp*>* groups;

@end

@interface WKMyGroupResp : WKModel

@property(nonatomic,copy) NSString *groupNo;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,copy) NSString *remark;
@property(nonatomic,copy,readonly) NSString *displayName;



@end

NS_ASSUME_NONNULL_END
